using Chirag.Ocr.Api.Domain;
using Chirag.Ocr.Api.Services;

namespace Chirag.Ocr.Tests;

public sealed class DraftValidatorTests
{
    [Fact]
    public void BalancedDraftWithExistingLedgersIsValid()
    {
        var result = DraftValidator.Validate(CreateDraft());

        Assert.True(result.IsValid);
        Assert.Equal(1180m, result.DebitTotal);
        Assert.Equal(result.DebitTotal, result.CreditTotal);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public void UnbalancedDraftIsBlocked()
    {
        var draft = CreateDraft() with
        {
            Lines = [new(Guid.NewGuid(), "purchase", "Purchase", 1000m, 0m, 1m)]
        };

        var result = DraftValidator.Validate(draft);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, issue => issue.Code == "UNBALANCED");
    }

    [Fact]
    public void MissingLedgerIdIsBlockedToPreventAutomaticLedgerCreation()
    {
        var draft = CreateDraft() with
        {
            Lines = [
                new(Guid.NewGuid(), null, "Purchase", 1180m, 0m, 0.5m),
                new(Guid.NewGuid(), "supplier", "Supplier", 0m, 1180m, 1m)]
        };

        var result = DraftValidator.Validate(draft);

        Assert.False(result.IsValid);
        Assert.False(result.LedgersValid);
        Assert.Contains(result.Errors, issue => issue.Code == "LEDGER_REQUIRED");
    }

    [Fact]
    public void GstMismatchAndDuplicateRemainVisibleWarnings()
    {
        var draft = CreateDraft() with { TotalAmount = 1200m, Confidence = 0.6m };

        var result = DraftValidator.Validate(draft, duplicateSuspected: true);

        Assert.True(result.IsValid);
        Assert.False(result.GstValid);
        Assert.Contains(result.Warnings, issue => issue.Code == "GST_TOTAL_MISMATCH");
        Assert.Contains(result.Warnings, issue => issue.Code == "LOW_CONFIDENCE");
        Assert.Contains(result.Warnings, issue => issue.Code == "POSSIBLE_DUPLICATE");
    }

    [Fact]
    public void InvalidGstinAndConflictingTaxTreatmentRequireReview()
    {
        var draft = CreateDraft() with { Gstin = "INVALID", Igst = 180m, TotalAmount = 1360m };

        var result = DraftValidator.Validate(draft);

        Assert.Contains(result.Warnings, issue => issue.Code == "GSTIN_INVALID");
        Assert.Contains(result.Warnings, issue => issue.Code == "GST_TREATMENT_CONFLICT");
    }

    [Fact]
    public void DueDateBeforeVoucherDateRequiresReview()
    {
        var draft = CreateDraft() with { DueDate = new DateOnly(2026, 8, 1) };

        var result = DraftValidator.Validate(draft);

        Assert.Contains(result.Warnings, issue => issue.Code == "DUE_DATE_BEFORE_INVOICE");
    }

    private static AccountingDraft CreateDraft() => new(
        VoucherType.Purchase,
        new DateOnly(2026, 8, 29),
        "supplier",
        "ABC Traders",
        "458",
        1000m,
        90m,
        90m,
        0m,
        1180m,
        "Being purchase invoice 458.",
        0.98m,
        [
            new(Guid.NewGuid(), "purchase", "Purchase", 1000m, 0m, 0.98m),
            new(Guid.NewGuid(), "input-cgst", "Input CGST", 90m, 0m, 0.98m),
            new(Guid.NewGuid(), "input-sgst", "Input SGST", 90m, 0m, 0.98m),
            new(Guid.NewGuid(), "supplier", "ABC Traders", 0m, 1180m, 0.99m)
        ],
        []);
}

public sealed class DocumentClassifierTests
{
    [Theory]
    [InlineData("SALES INVOICE Bill To: ABC Limited", "scan.png", VoucherType.Sales)]
    [InlineData("PURCHASE INVOICE Supplier Invoice", "scan.png", VoucherType.Purchase)]
    [InlineData("RECEIPT VOUCHER Payment received from ABC", "scan.png", VoucherType.Receipt)]
    [InlineData("PAYMENT VOUCHER Paid to supplier", "scan.png", VoucherType.Payment)]
    [InlineData("GST CREDIT NOTE", "scan.png", VoucherType.CreditNote)]
    [InlineData("GST DEBIT NOTE", "scan.png", VoucherType.DebitNote)]
    public void DetectsVoucherTypeFromDocumentText(string text, string fileName, VoucherType expected)
    {
        var result = DocumentClassifier.Classify(text, fileName);

        Assert.Equal(expected, result.VoucherType);
        Assert.True(result.Confidence >= 0.72m);
    }

    [Fact]
    public void AccountantBatchTypeOverridesAmbiguousDocuments()
    {
        var result = DocumentClassifier.Classify("TAX INVOICE", "page-1.jpg", VoucherType.Purchase);

        Assert.Equal(VoucherType.Purchase, result.VoucherType);
        Assert.Equal(1m, result.Confidence);
    }

    [Fact]
    public void AmbiguousTaxInvoiceIsNotSilentlyAssumedToBePurchaseOrSales()
    {
        var result = DocumentClassifier.Classify("TAX INVOICE", "scan.jpg");

        Assert.Equal(VoucherType.Other, result.VoucherType);
        Assert.True(result.Confidence < 0.70m);
    }
}

public sealed class MasterMatcherTests
{
    [Fact]
    public void PunctuationAndCaseDifferencesMatchExistingMaster()
    {
        var master = new AccountingMaster
        {
            Id = Guid.NewGuid(), ClientId = "client-a", Kind = MasterKind.Ledger,
            Name = "A.B. Traders", NormalizedName = MasterMatcher.Normalize("A.B. Traders")
        };

        var result = MasterMatcher.Suggest(MasterKind.Ledger, "ab traders", [master]);

        Assert.False(result.RequiresCreation);
        Assert.Equal(master.Id, result.MasterId);
        Assert.True(result.ExactMatch);
    }

    [Fact]
    public void UnknownProductProducesCreationSuggestionWithoutCreatingIt()
    {
        var result = MasterMatcher.Suggest(MasterKind.Product, "Brake Cable", [], hsnSac: "8714", unit: "Nos");

        Assert.True(result.RequiresCreation);
        Assert.Null(result.MasterId);
        Assert.Equal("Brake Cable", result.SuggestedName);
        Assert.Equal("8714", result.HsnSac);
    }
}

public sealed class InvoiceTableExtractorTests
{
    private static readonly SourceReference Source = new(1, 0, 0, 1, 1, 0.9m, "test OCR");

    [Fact]
    public void ExtractsMultipleRowsFromSemanticInvoiceTable()
    {
        const string text = """
            SL DESCRIPTION HSN QTY UNIT RATE AMOUNT
            1 Brake Cable 8714 2 Nos 150.00 300.00
            2 Engine Oil 2710 1 Ltr 450.00 450.00
            Taxable Value 750.00
            """;

        var items = InvoiceTableExtractor.Extract(text, Source);

        Assert.Collection(items,
            first =>
            {
                Assert.Equal("Brake Cable", first.Description);
                Assert.Equal("8714", first.HsnSac);
                Assert.Equal(2m, first.Quantity);
                Assert.Equal(300m, first.Total);
            },
            second =>
            {
                Assert.Equal("Engine Oil", second.Description);
                Assert.Equal("2710", second.HsnSac);
                Assert.Equal(450m, second.Total);
            });
    }

    [Fact]
    public void DoesNotGuessRowsWithoutRecognizableHeaders()
    {
        var items = InvoiceTableExtractor.Extract("Brake Cable 2 Nos 150 300", Source);

        Assert.Empty(items);
    }
}