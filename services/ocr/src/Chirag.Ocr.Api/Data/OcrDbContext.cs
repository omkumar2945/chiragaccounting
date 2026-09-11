using Chirag.Ocr.Api.Domain;
using Chirag.Ocr.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Chirag.Ocr.Api.Data;

public sealed class OcrDocument
{
    public Guid Id { get; set; }
    public required string ClientId { get; set; }
    public required string AssignedAccountantId { get; set; }
    public required string OriginalFileName { get; set; }
    public required string StoredFileName { get; set; }
    public required string ContentType { get; set; }
    public required string Sha256 { get; set; }
    public bool ExactDuplicate { get; set; }
    public Guid BatchId { get; set; }
    public VoucherType? RequestedVoucherType { get; set; }
    public DocumentStatus Status { get; set; } = DocumentStatus.Uploaded;
    public VoucherType? VoucherType { get; set; }
    public decimal Confidence { get; set; }
    public string? DraftJson { get; set; }
    public string? FailureReason { get; set; }
    public int ProcessingAttempts { get; set; }
    public string? ExistingVoucherId { get; set; }
    public DateTimeOffset UploadedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class OcrAuditLog
{
    public long Id { get; set; }
    public Guid DocumentId { get; set; }
    public required string ClientId { get; set; }
    public required string ActorId { get; set; }
    public required string Action { get; set; }
    public required string DetailJson { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class OcrDbContext(DbContextOptions<OcrDbContext> options) : DbContext(options)
{
    public DbSet<OcrDocument> Documents => Set<OcrDocument>();
    public DbSet<OcrAuditLog> AuditLogs => Set<OcrAuditLog>();
    public DbSet<AccountingMaster> AccountingMasters => Set<AccountingMaster>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<OcrDocument>().HasIndex(document => new { document.ClientId, document.Status });
        modelBuilder.Entity<OcrDocument>().HasIndex(document => new { document.ClientId, document.Sha256 });
        modelBuilder.Entity<OcrDocument>().Property(document => document.Status).HasConversion<string>();
        modelBuilder.Entity<OcrDocument>().Property(document => document.VoucherType).HasConversion<string>();
        modelBuilder.Entity<OcrDocument>().Property(document => document.RequestedVoucherType).HasConversion<string>();
        modelBuilder.Entity<OcrDocument>().Property(document => document.UploadedAt)
            .HasConversion(value => value.ToUnixTimeMilliseconds(), value => DateTimeOffset.FromUnixTimeMilliseconds(value));
        modelBuilder.Entity<OcrDocument>().Property(document => document.UpdatedAt)
            .HasConversion(value => value.ToUnixTimeMilliseconds(), value => DateTimeOffset.FromUnixTimeMilliseconds(value));
        modelBuilder.Entity<OcrAuditLog>().HasIndex(log => new { log.ClientId, log.DocumentId, log.CreatedAt });
        modelBuilder.Entity<OcrAuditLog>().Property(log => log.CreatedAt)
            .HasConversion(value => value.ToUnixTimeMilliseconds(), value => DateTimeOffset.FromUnixTimeMilliseconds(value));
        modelBuilder.Entity<AccountingMaster>().HasIndex(master =>
            new { master.ClientId, master.Kind, master.NormalizedName }).IsUnique();
        modelBuilder.Entity<AccountingMaster>().Property(master => master.Kind).HasConversion<string>();
        modelBuilder.Entity<AccountingMaster>().Property(master => master.CreatedAt)
            .HasConversion(value => value.ToUnixTimeMilliseconds(), value => DateTimeOffset.FromUnixTimeMilliseconds(value));
    }
}