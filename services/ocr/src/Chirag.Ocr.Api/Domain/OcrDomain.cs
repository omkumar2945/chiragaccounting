using System.Text.Json.Serialization;
using Chirag.Ocr.Api.Services;

namespace Chirag.Ocr.Api.Domain;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum DocumentStatus
{
    Uploaded, Processing, OcrCompleted, AiClassified, DraftCreated, NeedsReview,
    Ready, Confirmed, Saved, Error, Duplicate, Rejected, NeedsInformation,
    Reprocessing, ApiFailure, Approved, Posted, Completed
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum VoucherType
{
    Sales, Purchase, Receipt, Payment, Contra, Journal, CreditNote, DebitNote,
    Expense, AssetPurchase, BankReceipt, BankPayment, Other
}

public sealed record SourceReference(int Page, decimal X, decimal Y, decimal Width, decimal Height, decimal Confidence, string Method);
public sealed record ExtractedField(string Name, string? OcrValue, string? FinalValue, SourceReference? Source);
public sealed record VoucherLine(Guid Id, string? LedgerId, string LedgerName, decimal Debit, decimal Credit, decimal Confidence);
public sealed record InvoiceItem(
    string? Description, string? HsnSac, decimal? Quantity, string? Unit, decimal? Rate,
    decimal? Discount, decimal? TaxableValue, decimal? GstRate, decimal? Total, SourceReference? Source);
public sealed record AccountingDraft(
    VoucherType VoucherType, DateOnly? Date, string? PartyLedgerId, string? PartyName,
    string? DocumentNumber, decimal? TaxableAmount, decimal? Cgst, decimal? Sgst,
    decimal? Igst, decimal? TotalAmount, string Narration, decimal Confidence,
    IReadOnlyList<VoucherLine> Lines, IReadOnlyList<ExtractedField> Fields,
    DateOnly? DueDate = null, string? ReferenceNumber = null, string? Gstin = null,
    string? Pan = null, string? PlaceOfSupply = null, bool? ReverseCharge = null,
    decimal? Utgst = null, decimal? Cess = null, decimal? Discount = null,
    decimal? OtherCharges = null, decimal? RoundOff = null, decimal? Tds = null,
    decimal? Tcs = null, string? PaymentMethod = null, string? BankName = null,
    string? PaymentReference = null, string? ClassificationExplanation = null,
    IReadOnlyList<InvoiceItem>? Items = null,
    IReadOnlyList<MasterSuggestion>? MasterSuggestions = null);
public sealed record ValidationIssue(string Code, string Message, string? Field = null);
public sealed record ValidationResult(
    bool IsValid, IReadOnlyList<ValidationIssue> Errors, IReadOnlyList<ValidationIssue> Warnings,
    decimal DebitTotal, decimal CreditTotal, bool DuplicateSuspected, bool GstValid, bool LedgersValid);

public static class DraftValidator
{
    public static ValidationResult Validate(AccountingDraft draft, bool duplicateSuspected = false)
    {
        var errors = new List<ValidationIssue>();
        var warnings = new List<ValidationIssue>();
        var debit = draft.Lines.Sum(line => line.Debit);
        var credit = draft.Lines.Sum(line => line.Credit);

        if (draft.Date is null) errors.Add(new("DATE_REQUIRED", "Voucher date is required.", "date"));
        if (draft.Lines.Count == 0) errors.Add(new("LINES_REQUIRED", "At least one accounting line is required.", "lines"));
        if (draft.Lines.Any(line => string.IsNullOrWhiteSpace(line.LedgerId)))
            errors.Add(new("LEDGER_REQUIRED", "Every accounting line must use an existing ledger.", "lines"));
        if (debit != credit) errors.Add(new("UNBALANCED", "Total debit must equal total credit.", "lines"));
        if (debit <= 0) errors.Add(new("AMOUNT_REQUIRED", "Voucher amount must be greater than zero.", "lines"));

        var calculatedTotal = (draft.TaxableAmount ?? 0) + (draft.Cgst ?? 0) + (draft.Sgst ?? 0) +
            (draft.Igst ?? 0) + (draft.Utgst ?? 0) + (draft.Cess ?? 0) + (draft.OtherCharges ?? 0) +
            (draft.RoundOff ?? 0) - (draft.Discount ?? 0) - (draft.Tds ?? 0) + (draft.Tcs ?? 0);
        var gstValid = draft.TotalAmount is null || Math.Abs(calculatedTotal - draft.TotalAmount.Value) <= 1m;
        if (!gstValid) warnings.Add(new("GST_TOTAL_MISMATCH", "Taxable value and tax do not match the document total.", "totalAmount"));
        if (!string.IsNullOrWhiteSpace(draft.Gstin) && !System.Text.RegularExpressions.Regex.IsMatch(
                draft.Gstin, "^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$", System.Text.RegularExpressions.RegexOptions.IgnoreCase))
            warnings.Add(new("GSTIN_INVALID", "GSTIN format requires review.", "gstin"));
        if ((draft.Igst ?? 0) > 0 && ((draft.Cgst ?? 0) > 0 || (draft.Sgst ?? 0) > 0 || (draft.Utgst ?? 0) > 0))
            warnings.Add(new("GST_TREATMENT_CONFLICT", "IGST and CGST/SGST/UTGST should not normally be applied together.", "igst"));
        if (draft.DueDate < draft.Date)
            warnings.Add(new("DUE_DATE_BEFORE_INVOICE", "Due date is earlier than the voucher date.", "dueDate"));
        if (draft.Lines.Any(line => line.Debit < 0 || line.Credit < 0) || draft.TotalAmount < 0)
            warnings.Add(new("NEGATIVE_VALUE", "Negative accounting values require review."));
        if (draft.Items?.Any(item => item.Quantity < 0 || item.Rate < 0 || item.Total < 0) == true)
            warnings.Add(new("ABNORMAL_ITEM_VALUE", "One or more item values are negative.", "items"));
        if (draft.Confidence < 0.70m) warnings.Add(new("LOW_CONFIDENCE", "Low confidence fields require manual confirmation."));
        if (duplicateSuspected) warnings.Add(new("POSSIBLE_DUPLICATE", "A possible duplicate document already exists."));

        return new(errors.Count == 0, errors, warnings, debit, credit, duplicateSuspected,
            gstValid, !errors.Any(issue => issue.Code == "LEDGER_REQUIRED"));
    }
}