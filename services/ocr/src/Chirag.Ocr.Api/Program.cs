using System.Text.Json;
using System.Text.Json.Serialization;
using Chirag.Ocr.Api.Data;
using Chirag.Ocr.Api.Domain;
using Chirag.Ocr.Api.Security;
using Chirag.Ocr.Api.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
builder.Services.ConfigureHttpJsonOptions(options => options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddDbContext<OcrDbContext>(options => options.UseSqlite(
    builder.Configuration.GetConnectionString("Ocr") ?? "Data Source=App_Data/ocr.db"));
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentActor, CurrentActor>();
builder.Services.AddScoped<DocumentStorage>();
builder.Services.AddScoped<IOcrExtractor, LocalDocumentExtractor>();
builder.Services.AddScoped<IAccountingVoucherGateway, UnconfiguredAccountingVoucherGateway>();
builder.Services.AddSingleton<OcrJobQueue>();
builder.Services.AddHostedService<OcrWorker>();

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddAuthentication("Development")
        .AddScheme<AuthenticationSchemeOptions, DevelopmentAuthenticationHandler>("Development", _ => { });
}
else
{
    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.Audience = builder.Configuration["Authentication:Audience"];
    });
}
builder.Services.AddAuthorization();

var app = builder.Build();
Directory.CreateDirectory(Path.Combine(app.Environment.ContentRootPath, "App_Data"));
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<OcrDbContext>();
    await db.Database.MigrateAsync();
    var storage = scope.ServiceProvider.GetRequiredService<DocumentStorage>();
    var classifiedDocuments = await db.Documents.Where(document => document.VoucherType != null).ToListAsync();
    foreach (var document in classifiedDocuments)
        storage.MoveToVoucherFolder(document, document.VoucherType!.Value);
    await db.SaveChangesAsync();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
app.UseDefaultFiles();
app.UseStaticFiles();
app.UseAuthentication();
app.UseAuthorization();

var api = app.MapGroup("/ocr").RequireAuthorization();

api.MapPost("/upload", async (HttpRequest request, ICurrentActor actor, OcrDbContext db,
    DocumentStorage storage, OcrJobQueue queue, CancellationToken cancellationToken) =>
{
    if (!request.HasFormContentType) return Results.BadRequest(new { error = "multipart/form-data is required." });
    var form = await request.ReadFormAsync(cancellationToken);
    if (form.Files.Count == 0) return Results.BadRequest(new { error = "At least one file is required." });
    var batchId = Guid.NewGuid();
    var requestedVoucherType = Enum.TryParse<VoucherType>(form["voucherType"], true, out var parsedVoucherType)
        ? parsedVoucherType
        : (VoucherType?)null;
    var uploaded = new List<object>();

    foreach (var file in form.Files)
    {
        try
        {
            var (storedName, hash) = await storage.SaveAsync(actor.ClientId, file, cancellationToken);
            var duplicate = await db.Documents.AnyAsync(document => document.ClientId == actor.ClientId && document.Sha256 == hash, cancellationToken);
            var document = new OcrDocument
            {
                Id = Guid.NewGuid(), ClientId = actor.ClientId, AssignedAccountantId = actor.AccountantId,
                OriginalFileName = Path.GetFileName(file.FileName), StoredFileName = storedName,
                ContentType = file.ContentType, Sha256 = hash, ExactDuplicate = duplicate,
                BatchId = batchId, RequestedVoucherType = requestedVoucherType,
                Status = duplicate ? DocumentStatus.Duplicate : DocumentStatus.Uploaded
            };
            db.Documents.Add(document);
            db.AuditLogs.Add(new OcrAuditLog { DocumentId = document.Id, ClientId = actor.ClientId,
                ActorId = actor.AccountantId, Action = "Uploaded",
                DetailJson = JsonSerializer.Serialize(new { document.OriginalFileName, ExactDuplicate = duplicate }) });
            await db.SaveChangesAsync(cancellationToken);
            if (!duplicate) await queue.EnqueueAsync(document.Id, cancellationToken);
            uploaded.Add(new { document.Id, document.OriginalFileName, document.Status, document.BatchId, document.RequestedVoucherType });
        }
        catch (InvalidDataException exception)
        {
            uploaded.Add(new { FileName = Path.GetFileName(file.FileName), Status = "Rejected", Error = exception.Message });
        }
    }
    return Results.Accepted(value: uploaded);
}).DisableAntiforgery();

api.MapGet("/documents", async (ICurrentActor actor, OcrDbContext db, DocumentStatus? status, VoucherType? voucherType,
    string? clientId, string? search, int page = 1, int pageSize = 50, CancellationToken cancellationToken = default) =>
{
    var query = AccessibleDocuments(db, actor).AsNoTracking();
    if (!string.IsNullOrWhiteSpace(clientId)) query = query.Where(document => document.ClientId == clientId);
    if (status is not null) query = query.Where(document => document.Status == status);
    if (voucherType is not null) query = query.Where(document => document.VoucherType == voucherType);
    if (!string.IsNullOrWhiteSpace(search)) query = query.Where(document =>
        document.OriginalFileName.Contains(search) || (document.DraftJson != null && document.DraftJson.Contains(search)));
    return Results.Ok(await query.OrderByDescending(document => document.UploadedAt)
        .Skip((Math.Max(page, 1) - 1) * Math.Clamp(pageSize, 1, 100))
        .Take(Math.Clamp(pageSize, 1, 100)).ToListAsync(cancellationToken));
});

api.MapGet("/folders", async (ICurrentActor actor, OcrDbContext db, string? search, CancellationToken cancellationToken) =>
{
    var documents = AccessibleDocuments(db, actor).AsNoTracking();
    if (!string.IsNullOrWhiteSpace(search))
        documents = documents.Where(document => document.ClientId.Contains(search));
    var rows = await documents.GroupBy(document => new { document.ClientId, document.VoucherType })
        .Select(group => new { group.Key.ClientId, group.Key.VoucherType, Count = group.Count() })
        .ToListAsync(cancellationToken);
    return Results.Ok(rows.GroupBy(row => row.ClientId).Select(client => new
    {
        ClientId = client.Key,
        Total = client.Sum(row => row.Count),
        Folders = Enum.GetValues<VoucherType>().Select(voucherType => new
        {
            VoucherType = voucherType,
            Name = DocumentStorage.VoucherFolder(voucherType),
            Count = client.Where(row => row.VoucherType == voucherType).Sum(row => row.Count)
        }).OrderBy(folder => folder.Name)
    }).OrderBy(client => client.ClientId));
});

api.MapGet("/documents/{id:guid}", async (Guid id, ICurrentActor actor, OcrDbContext db, CancellationToken cancellationToken) =>
    await AccessibleDocuments(db, actor).AsNoTracking().SingleOrDefaultAsync(document => document.Id == id, cancellationToken)
        is { } document ? Results.Ok(document) : Results.NotFound());

api.MapGet("/documents/{id:guid}/file", async (Guid id, ICurrentActor actor, OcrDbContext db,
    DocumentStorage storage, CancellationToken cancellationToken) =>
{
    var document = await AccessibleDocuments(db, actor).AsNoTracking().SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    return document is null ? Results.NotFound() : Results.File(storage.GetPath(document), document.ContentType, enableRangeProcessing: true);
});

api.MapPost("/process/{id:guid}", async (Guid id, ICurrentActor actor, OcrDbContext db, OcrJobQueue queue, CancellationToken cancellationToken) =>
{
    var document = await AccessibleDocuments(db, actor).SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (document is null) return Results.NotFound();
    if (document.ProcessingAttempts >= 3) return Results.Conflict(new { error = "Safe retry limit reached. Review the failure before trying again." });
    document.Status = DocumentStatus.Reprocessing;
    document.FailureReason = null;
    document.UpdatedAt = DateTimeOffset.UtcNow;
    db.AuditLogs.Add(new OcrAuditLog { DocumentId = id, ClientId = actor.ClientId, ActorId = actor.AccountantId,
        Action = "ReprocessingRequested", DetailJson = JsonSerializer.Serialize(new { document.ProcessingAttempts }) });
    await db.SaveChangesAsync(cancellationToken);
    await queue.EnqueueAsync(id, cancellationToken);
    return Results.Accepted();
});

api.MapPut("/documents/{id:guid}/draft", async (Guid id, AccountingDraft draft, ICurrentActor actor, OcrDbContext db, CancellationToken cancellationToken) =>
{
    var document = await AccessibleDocuments(db, actor).SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (document is null) return Results.NotFound();
    document.DraftJson = JsonSerializer.Serialize(draft);
    document.VoucherType = draft.VoucherType;
    document.Confidence = draft.Confidence;
    var validation = DraftValidator.Validate(draft, document.ExactDuplicate);
    document.Status = validation.IsValid && draft.Confidence >= 0.95m && !validation.DuplicateSuspected
        ? DocumentStatus.Ready
        : DocumentStatus.NeedsReview;
    document.UpdatedAt = DateTimeOffset.UtcNow;
    db.AuditLogs.Add(new OcrAuditLog { DocumentId = id, ClientId = actor.ClientId, ActorId = actor.AccountantId,
        Action = "DraftUpdated", DetailJson = JsonSerializer.Serialize(new { Draft = draft, Validation = validation }) });
    await db.SaveChangesAsync(cancellationToken);
    return Results.Ok(validation);
});

api.MapPost("/validate/{id:guid}", async (Guid id, ICurrentActor actor, OcrDbContext db, CancellationToken cancellationToken) =>
{
    var document = await AccessibleDocuments(db, actor).AsNoTracking().SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (document?.DraftJson is null) return Results.BadRequest(new { error = "Document has no accounting draft." });
    return Results.Ok(DraftValidator.Validate(JsonSerializer.Deserialize<AccountingDraft>(document.DraftJson)!, document.ExactDuplicate));
});

api.MapPost("/confirm/{id:guid}", async (Guid id, ICurrentActor actor, OcrDbContext db,
    IAccountingVoucherGateway gateway, CancellationToken cancellationToken) =>
{
    var document = await AccessibleDocuments(db, actor).SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (document?.DraftJson is null) return Results.BadRequest(new { error = "Document has no accounting draft." });
    var draft = JsonSerializer.Deserialize<AccountingDraft>(document.DraftJson)!;
    var validation = DraftValidator.Validate(draft, document.ExactDuplicate);
    if (!validation.IsValid) return Results.ValidationProblem(validation.Errors.ToDictionary(issue => issue.Code, issue => new[] { issue.Message }));
    try
    {
        document.ExistingVoucherId = await gateway.CreateVoucherAsync(actor.ClientId, draft, id, cancellationToken);
        document.Status = DocumentStatus.Saved;
        document.UpdatedAt = DateTimeOffset.UtcNow;
        db.AuditLogs.Add(new OcrAuditLog { DocumentId = id, ClientId = actor.ClientId, ActorId = actor.AccountantId,
            Action = "ConfirmedAndSaved", DetailJson = JsonSerializer.Serialize(new { document.ExistingVoucherId }) });
        await db.SaveChangesAsync(cancellationToken);
        return Results.Ok(new { document.ExistingVoucherId, document.Status });
    }
    catch (InvalidOperationException exception)
    {
        return Results.Problem(exception.Message, statusCode: StatusCodes.Status503ServiceUnavailable);
    }
});

api.MapPost("/reject/{id:guid}", async (Guid id, ICurrentActor actor, OcrDbContext db, CancellationToken cancellationToken) =>
{
    var document = await AccessibleDocuments(db, actor).SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (document is null) return Results.NotFound();
    document.Status = DocumentStatus.Rejected;
    document.UpdatedAt = DateTimeOffset.UtcNow;
    db.AuditLogs.Add(new OcrAuditLog { DocumentId = id, ClientId = actor.ClientId, ActorId = actor.AccountantId,
        Action = "Rejected", DetailJson = "{}" });
    await db.SaveChangesAsync(cancellationToken);
    return Results.NoContent();
});

api.MapGet("/audit/{id:guid}", async (Guid id, ICurrentActor actor, OcrDbContext db, CancellationToken cancellationToken) =>
{
    if (!await AccessibleDocuments(db, actor).AnyAsync(document => document.Id == id, cancellationToken)) return Results.NotFound();
    return Results.Ok(await db.AuditLogs.AsNoTracking().Where(log => log.DocumentId == id && log.ClientId == actor.ClientId)
        .OrderBy(log => log.CreatedAt).ToListAsync(cancellationToken));
});

api.MapGet("/masters", async (MasterKind? kind, string? search, ICurrentActor actor, OcrDbContext db,
    CancellationToken cancellationToken) =>
{
    var query = db.AccountingMasters.AsNoTracking()
        .Where(master => master.ClientId == actor.ClientId && master.IsActive);
    if (kind is not null) query = query.Where(master => master.Kind == kind);
    if (!string.IsNullOrWhiteSpace(search))
    {
        var normalized = MasterMatcher.Normalize(search);
        query = query.Where(master => master.NormalizedName.Contains(normalized));
    }
    return Results.Ok(await query.OrderBy(master => master.Name).Take(50).ToListAsync(cancellationToken));
});

api.MapPost("/masters", async (CreateMasterRequest request, ICurrentActor actor, OcrDbContext db,
    CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(request.Name))
        return Results.BadRequest(new { error = "Master name is required." });
    var normalized = MasterMatcher.Normalize(request.Name);
    var existing = await db.AccountingMasters.SingleOrDefaultAsync(master => master.ClientId == actor.ClientId &&
        master.Kind == request.Kind && master.NormalizedName == normalized, cancellationToken);
    if (existing is not null) return Results.Ok(existing);

    var master = new AccountingMaster
    {
        Id = Guid.NewGuid(), ClientId = actor.ClientId, Kind = request.Kind, Name = request.Name.Trim(),
        NormalizedName = normalized, GroupName = request.GroupName?.Trim(), Gstin = request.Gstin?.Trim(),
        HsnSac = request.HsnSac?.Trim(), Unit = request.Unit?.Trim()
    };
    db.AccountingMasters.Add(master);
    if (request.DocumentId is { } documentId && await AccessibleDocuments(db, actor)
        .AnyAsync(document => document.Id == documentId, cancellationToken))
    {
        db.AuditLogs.Add(new OcrAuditLog
        {
            DocumentId = documentId, ClientId = actor.ClientId, ActorId = actor.AccountantId,
            Action = $"{request.Kind}CreatedFromOcrSuggestion",
            DetailJson = JsonSerializer.Serialize(new { master.Id, master.Name, master.GroupName })
        });
    }
    await db.SaveChangesAsync(cancellationToken);
    return Results.Created($"/ocr/masters/{master.Id}", master);
});

api.MapGet("/dashboard", async (ICurrentActor actor, OcrDbContext db, CancellationToken cancellationToken) =>
{
    var documents = await AccessibleDocuments(db, actor).AsNoTracking()
        .Select(document => new { document.Status, document.Confidence, document.UploadedAt }).ToListAsync(cancellationToken);
    var today = DateTimeOffset.UtcNow.Date;
    return Results.Ok(new
    {
        Total = documents.Count,
        Today = documents.Count(document => document.UploadedAt.UtcDateTime.Date == today),
        New = documents.Count(document => document.Status == DocumentStatus.Uploaded),
        Processing = documents.Count(document => document.Status is DocumentStatus.Processing or DocumentStatus.Reprocessing),
        NeedsReview = documents.Count(document => document.Status is DocumentStatus.NeedsReview or DocumentStatus.NeedsInformation),
        Approved = documents.Count(document => document.Status is DocumentStatus.Approved or DocumentStatus.Ready),
        Posted = documents.Count(document => document.Status is DocumentStatus.Posted or DocumentStatus.Saved or DocumentStatus.Completed),
        Errors = documents.Count(document => document.Status is DocumentStatus.Error or DocumentStatus.ApiFailure),
        Duplicates = documents.Count(document => document.Status == DocumentStatus.Duplicate),
        AverageConfidence = documents.Count == 0 ? 0 : Math.Round(documents.Average(document => document.Confidence) * 100, 1)
    });
});

api.MapGet("/batches", async (ICurrentActor actor, OcrDbContext db, CancellationToken cancellationToken) =>
{
    var documents = await AccessibleDocuments(db, actor).AsNoTracking().ToListAsync(cancellationToken);
    return Results.Ok(documents.GroupBy(document => document.BatchId).Select(batch => new
    {
        BatchId = batch.Key,
        UploadedAt = batch.Max(document => document.UploadedAt),
        Total = batch.Count(),
        Processing = batch.Count(document => document.Status is DocumentStatus.Uploaded or DocumentStatus.Processing or DocumentStatus.Reprocessing),
        NeedsReview = batch.Count(document => document.Status == DocumentStatus.NeedsReview),
        Ready = batch.Count(document => document.Status == DocumentStatus.Ready),
        Errors = batch.Count(document => document.Status is DocumentStatus.Error or DocumentStatus.ApiFailure),
        Duplicates = batch.Count(document => document.Status == DocumentStatus.Duplicate)
    }).OrderByDescending(batch => batch.UploadedAt));
});

api.MapGet("/integrations", () => Results.Ok(new[]
{
    new { Provider = "Tesseract", Purpose = "Printed image OCR", Status = "Active", Mode = "Local", Cost = "No per-page charge" },
    new { Provider = "PdfPig", Purpose = "Embedded PDF text", Status = "Active", Mode = "Local", Cost = "No per-page charge" },
    new { Provider = "Handwriting provider", Purpose = "Handwriting and difficult scans", Status = "Not configured", Mode = "Replaceable adapter", Cost = "Provider dependent" },
    new { Provider = "Chirag Accounting", Purpose = "Ledger validation and voucher posting", Status = "Not configured", Mode = "IAccountingVoucherGateway", Cost = "Internal" },
    new { Provider = "Tally", Purpose = "Voucher and ledger synchronization", Status = "Not configured", Mode = "Future adapter", Cost = "Internal" }
}));

app.MapFallbackToFile("index.html");
app.Run();

static IQueryable<OcrDocument> AccessibleDocuments(OcrDbContext db, ICurrentActor actor) =>
    actor.Role == "Client"
        ? db.Documents.Where(document => document.ClientId == actor.ClientId)
        : db.Documents.Where(document => document.AssignedAccountantId == actor.AccountantId);

public partial class Program;
