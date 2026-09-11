using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Json;
using System.Threading.Channels;
using Chirag.Ocr.Api.Data;
using Chirag.Ocr.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Chirag.Ocr.Api.Services;

public interface ICurrentActor { string ClientId { get; } string AccountantId { get; } string Role { get; } }

public sealed class CurrentActor(IHttpContextAccessor accessor) : ICurrentActor
{
    private ClaimsPrincipal User => accessor.HttpContext?.User ?? throw new UnauthorizedAccessException();
    public string ClientId => User.FindFirstValue("client_id") ?? throw new UnauthorizedAccessException("Missing client_id claim.");
    public string AccountantId => User.FindFirstValue(ClaimTypes.NameIdentifier) ?? throw new UnauthorizedAccessException("Missing subject claim.");
    public string Role => User.FindFirstValue(ClaimTypes.Role) ?? "Accountant";
}

public interface IOcrExtractor
{
    Task<AccountingDraft?> ExtractAsync(OcrDocument document, string absolutePath, CancellationToken cancellationToken);
}

public sealed class UnconfiguredOcrExtractor : IOcrExtractor
{
    public Task<AccountingDraft?> ExtractAsync(OcrDocument document, string absolutePath, CancellationToken cancellationToken) =>
        Task.FromResult<AccountingDraft?>(null);
}

public interface IAccountingVoucherGateway
{
    Task<string> CreateVoucherAsync(string clientId, AccountingDraft draft, Guid sourceDocumentId, CancellationToken cancellationToken);
}

public sealed class UnconfiguredAccountingVoucherGateway : IAccountingVoucherGateway
{
    public Task<string> CreateVoucherAsync(string clientId, AccountingDraft draft, Guid sourceDocumentId, CancellationToken cancellationToken) =>
        throw new InvalidOperationException("The Chirag accounting voucher gateway is not configured.");
}

public sealed class DocumentStorage(IWebHostEnvironment environment)
{
    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".pdf", ".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff" };
    private const long MaximumBytes = 25 * 1024 * 1024;

    public async Task<(string StoredName, string Hash)> SaveAsync(string clientId, IFormFile file, CancellationToken cancellationToken)
    {
        var extension = Path.GetExtension(file.FileName);
        if (!AllowedExtensions.Contains(extension)) throw new InvalidDataException("Unsupported file type. Upload PDF, PNG, JPEG, WebP, or TIFF.");
        if (file.Length is <= 0 or > MaximumBytes) throw new InvalidDataException("File must be between 1 byte and 25 MB.");

        var storedName = $"{Guid.NewGuid():N}{extension.ToLowerInvariant()}";
        var directory = Path.Combine(environment.ContentRootPath, "App_Data", "documents", SafeSegment(clientId));
        EnsureClientFolders(directory);
        var path = Path.Combine(directory, storedName);
        await using var target = File.Create(path);
        using var sha = SHA256.Create();
        await using var hashing = new CryptoStream(target, sha, CryptoStreamMode.Write);
        await file.CopyToAsync(hashing, cancellationToken);
        await hashing.FlushFinalBlockAsync(cancellationToken);
        return (storedName, Convert.ToHexString(sha.Hash!));
    }

    public string GetPath(OcrDocument document) => Path.Combine(
        environment.ContentRootPath, "App_Data", "documents", SafeSegment(document.ClientId), document.StoredFileName);

    public void MoveToVoucherFolder(OcrDocument document, VoucherType voucherType)
    {
        var source = GetPath(document);
        var folder = VoucherFolder(voucherType);
        var relativeName = Path.Combine(folder, Path.GetFileName(document.StoredFileName));
        var clientDirectory = Path.Combine(environment.ContentRootPath, "App_Data", "documents", SafeSegment(document.ClientId));
        EnsureClientFolders(clientDirectory);
        var destination = Path.Combine(clientDirectory, relativeName);
        if (string.Equals(source, destination, StringComparison.OrdinalIgnoreCase)) return;

        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        if (File.Exists(source) && !File.Exists(destination)) File.Move(source, destination);
        if (File.Exists(destination)) document.StoredFileName = relativeName;
    }

    public static string VoucherFolder(VoucherType voucherType) => voucherType switch
    {
        VoucherType.CreditNote => "credit-note",
        VoucherType.DebitNote => "debit-note",
        VoucherType.AssetPurchase => "fixed-asset",
        VoucherType.BankReceipt => "bank-receipt",
        VoucherType.BankPayment => "bank-payment",
        _ => voucherType.ToString().ToLowerInvariant()
    };

    private static void EnsureClientFolders(string clientDirectory)
    {
        Directory.CreateDirectory(clientDirectory);
        foreach (var voucherType in Enum.GetValues<VoucherType>())
            Directory.CreateDirectory(Path.Combine(clientDirectory, VoucherFolder(voucherType)));
    }

    private static string SafeSegment(string value) => string.Concat(value.Where(character => char.IsLetterOrDigit(character) || character is '-' or '_'));
}

public sealed class OcrJobQueue
{
    private readonly Channel<Guid> _channel = Channel.CreateBounded<Guid>(new BoundedChannelOptions(500)
        { FullMode = BoundedChannelFullMode.Wait, SingleReader = false });
    public ValueTask EnqueueAsync(Guid documentId, CancellationToken cancellationToken) => _channel.Writer.WriteAsync(documentId, cancellationToken);
    public IAsyncEnumerable<Guid> ReadAllAsync(CancellationToken cancellationToken) => _channel.Reader.ReadAllAsync(cancellationToken);
}

public sealed class OcrWorker(IServiceScopeFactory scopeFactory, OcrJobQueue queue, ILogger<OcrWorker> logger) : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        Task.WhenAll(Enumerable.Range(0, 4).Select(_ => ConsumeAsync(stoppingToken)));

    private async Task ConsumeAsync(CancellationToken stoppingToken)
    {
        await foreach (var documentId in queue.ReadAllAsync(stoppingToken))
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<OcrDbContext>();
                var extractor = scope.ServiceProvider.GetRequiredService<IOcrExtractor>();
                var storage = scope.ServiceProvider.GetRequiredService<DocumentStorage>();
                var document = await db.Documents.SingleOrDefaultAsync(item => item.Id == documentId, stoppingToken);
                if (document is null || document.Status is DocumentStatus.Saved or DocumentStatus.Rejected or DocumentStatus.Processing) continue;
                document.Status = DocumentStatus.Processing;
                document.ProcessingAttempts++;
                document.FailureReason = null;
                document.UpdatedAt = DateTimeOffset.UtcNow;
                await db.SaveChangesAsync(stoppingToken);

                var draft = await extractor.ExtractAsync(document, storage.GetPath(document), stoppingToken);
                if (draft is null)
                {
                    document.Status = DocumentStatus.NeedsReview;
                    document.FailureReason = "OCR provider is not configured. Original retained for manual entry.";
                }
                else
                {
                    var masters = await db.AccountingMasters.AsNoTracking()
                        .Where(master => master.ClientId == document.ClientId && master.IsActive)
                        .ToListAsync(stoppingToken);
                    draft = DraftMasterResolver.Resolve(draft, masters);
                    document.DraftJson = JsonSerializer.Serialize(draft);
                    document.VoucherType = draft.VoucherType;
                    storage.MoveToVoucherFolder(document, draft.VoucherType);
                    document.Confidence = draft.Confidence;
                    document.Status = DraftValidator.Validate(draft).IsValid && draft.Confidence >= 0.95m
                        ? DocumentStatus.Ready : DocumentStatus.NeedsReview;
                }
                document.UpdatedAt = DateTimeOffset.UtcNow;
                db.AuditLogs.Add(new OcrAuditLog { DocumentId = document.Id, ClientId = document.ClientId,
                    ActorId = "system", Action = "ProcessingCompleted",
                    DetailJson = JsonSerializer.Serialize(new { document.Status, document.FailureReason }) });
                await db.SaveChangesAsync(stoppingToken);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                logger.LogError(exception, "OCR processing failed for document {DocumentId}", documentId);
                using var failureScope = scopeFactory.CreateScope();
                var failureDb = failureScope.ServiceProvider.GetRequiredService<OcrDbContext>();
                var failed = await failureDb.Documents.SingleOrDefaultAsync(item => item.Id == documentId, stoppingToken);
                if (failed is null) continue;
                failed.Status = DocumentStatus.ApiFailure;
                failed.FailureReason = exception.Message;
                failed.UpdatedAt = DateTimeOffset.UtcNow;
                failureDb.AuditLogs.Add(new OcrAuditLog
                {
                    DocumentId = failed.Id,
                    ClientId = failed.ClientId,
                    ActorId = "system",
                    Action = "ProcessingFailed",
                    DetailJson = JsonSerializer.Serialize(new { Error = exception.Message, failed.ProcessingAttempts })
                });
                await failureDb.SaveChangesAsync(stoppingToken);
            }
        }
    }
}