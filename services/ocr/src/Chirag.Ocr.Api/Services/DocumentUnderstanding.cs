using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Chirag.Ocr.Api.Data;
using Chirag.Ocr.Api.Domain;
using Tesseract;
using UglyToad.PdfPig;

namespace Chirag.Ocr.Api.Services;

public sealed record ClassificationResult(VoucherType VoucherType, decimal Confidence, string Explanation);

public static partial class DocumentClassifier
{
    private static readonly (VoucherType Type, string[] Terms)[] Rules =
    [
        (VoucherType.CreditNote, ["credit note", "sales return"]),
        (VoucherType.DebitNote, ["debit note", "purchase return"]),
        (VoucherType.Contra, ["cash withdrawal", "cash deposit", "self cheque", "internal transfer"]),
        (VoucherType.BankReceipt, ["bank receipt", "amount credited", "credit advice"]),
        (VoucherType.BankPayment, ["bank payment", "amount debited", "debit advice"]),
        (VoucherType.Receipt, ["receipt voucher", "cash receipt", "payment received", "received from"]),
        (VoucherType.Payment, ["payment voucher", "paid to", "supplier payment", "cash payment"]),
        (VoucherType.AssetPurchase, ["fixed asset", "machinery", "motor vehicle", "computer equipment", "furniture"]),
        (VoucherType.Expense, ["electricity bill", "telephone bill", "internet bill", "rent invoice", "professional fees", "travel expense"]),
        (VoucherType.Journal, ["journal voucher", "depreciation", "provision", "adjustment entry", "rectification"]),
        (VoucherType.Purchase, ["purchase invoice", "vendor bill", "supplier invoice", "bill from"]),
        (VoucherType.Sales, ["sales invoice", "customer invoice", "invoice to", "bill to"])
    ];

    public static ClassificationResult Classify(string text, string fileName, VoucherType? requestedType = null)
    {
        if (requestedType is not null)
            return new(requestedType.Value, 1m, "Voucher type applied to this upload batch by the accountant.");

        var content = $"{fileName} {text}".ToLowerInvariant().Replace('_', ' ').Replace('-', ' ');
        var match = Rules
            .Select(rule => new { rule.Type, Matches = rule.Terms.Count(content.Contains), Terms = rule.Terms.Where(content.Contains).ToArray() })
            .OrderByDescending(candidate => candidate.Matches)
            .FirstOrDefault(candidate => candidate.Matches > 0);

        return match is null
            ? new(VoucherType.Other, 0.35m, "No reliable voucher-type phrase was detected.")
            : new(match.Type, Math.Min(0.98m, 0.72m + (match.Matches - 1) * 0.1m), $"Detected: {string.Join(", ", match.Terms)}.");
    }
}

public sealed class LocalDocumentExtractor(IWebHostEnvironment environment, ILogger<LocalDocumentExtractor> logger) : IOcrExtractor
{
    public Task<AccountingDraft?> ExtractAsync(OcrDocument document, string absolutePath, CancellationToken cancellationToken) =>
        Task.Run<AccountingDraft?>(() => Extract(document, absolutePath), cancellationToken);

    private AccountingDraft Extract(OcrDocument document, string absolutePath)
    {
        var (text, extractionConfidence, method) = document.ContentType.Contains("pdf", StringComparison.OrdinalIgnoreCase)
            ? ExtractPdf(absolutePath)
            : ExtractImage(absolutePath);
        var classification = DocumentClassifier.Classify(text, document.OriginalFileName, document.RequestedVoucherType);
        var source = new SourceReference(1, 0, 0, 1, 1, extractionConfidence, method);
        var number = MatchValue(text, @"(?im)\b(?:invoice|bill|receipt|voucher|credit\s*note|debit\s*note)\s*(?:no\.?|number|#)\s*[:.-]?\s*([a-z0-9][a-z0-9/-]{1,30})");
        var dateText = MatchValue(text, @"(?im)\b(?:invoice\s*date|bill\s*date|date)\s*[:.-]?\s*(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})");
        var date = ParseDate(dateText);
        var dueDateText = MatchValue(text, @"(?im)\bdue\s*date\s*[:.-]?\s*(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})");
        var dueDate = ParseDate(dueDateText);
        var reference = MatchValue(text, @"(?im)\b(?:reference|ref(?:erence)?\s*no\.?|order\s*no\.?)\s*[:#.-]?\s*([a-z0-9][a-z0-9/-]{1,40})");
        var gstin = MatchValue(text, @"(?im)\bgstin\s*[:.-]?\s*([0-9]{2}[a-z]{5}[0-9]{4}[a-z][1-9a-z]z[0-9a-z])");
        var pan = MatchValue(text, @"(?im)\bpan\s*[:.-]?\s*([a-z]{5}[0-9]{4}[a-z])");
        var placeOfSupply = MatchValue(text, @"(?im)\bplace\s*of\s*supply\s*[:.-]?\s*([^\r\n]{2,60})");
        var taxable = MatchAmount(text, @"(?im)\b(?:taxable\s*(?:value|amount)|subtotal)\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var cgst = MatchAmount(text, @"(?im)\bcgst(?:\s*@?\s*\d+(?:\.\d+)?%)?\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var sgst = MatchAmount(text, @"(?im)\bsgst(?:\s*@?\s*\d+(?:\.\d+)?%)?\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var igst = MatchAmount(text, @"(?im)\bigst(?:\s*@?\s*\d+(?:\.\d+)?%)?\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var utgst = MatchAmount(text, @"(?im)\butgst(?:\s*@?\s*\d+(?:\.\d+)?%)?\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var cess = MatchAmount(text, @"(?im)\bcess\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var discount = MatchAmount(text, @"(?im)\bdiscount\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var otherCharges = MatchAmount(text, @"(?im)\b(?:other\s*charges|freight)\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var roundOff = MatchSignedAmount(text, @"(?im)\bround(?:ing)?[\s-]*off\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([+-]?[\d,]+(?:\.\d{1,2})?)");
        var tds = MatchAmount(text, @"(?im)\btds\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var tcs = MatchAmount(text, @"(?im)\btcs\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var total = MatchAmount(text, @"(?im)\b(?:grand\s*total|invoice\s*total|net\s*amount|amount\s*due|total\s*amount)\s*(?:[:=-]\s*)?(?:₹|rs\.?)?\s*([\d,]+(?:\.\d{1,2})?)");
        var party = ExtractParty(text, classification.VoucherType);
        var paymentMethod = MatchValue(text, @"(?im)\b(cash|upi|cheque|card|neft|rtgs|imps)\b");
        var paymentReference = MatchValue(text, @"(?im)\b(?:utr|transaction|cheque)\s*(?:no\.?|number|id|reference|#)?\s*[:.-]?\s*([a-z0-9][a-z0-9/-]{3,40})");
        var bankName = MatchValue(text, @"(?im)\b((?:hdfc|icici|axis|state\s*bank\s*of\s*india|sbi|kotak|yes|indusind|bank\s*of\s*baroda)\s*bank)\b");
        var reverseCharge = Regex.IsMatch(text, @"(?im)reverse\s*charge\s*[:.-]?\s*(?:yes|applicable)") ? true : (bool?)null;
        var confidence = Math.Min(extractionConfidence, classification.Confidence);
        var items = InvoiceTableExtractor.Extract(text, source);
        var fields = BuildFields(party, number, dateText, dueDateText, reference, gstin, pan, placeOfSupply,
            taxable, cgst, sgst, igst, utgst, cess, discount, otherCharges, roundOff, tds, tcs, total,
            paymentMethod, paymentReference, bankName, source);

        return new AccountingDraft(
            classification.VoucherType,
            date,
            null,
            party,
            number,
            taxable,
            cgst,
            sgst,
            igst,
            total,
            BuildNarration(classification.VoucherType, number, date),
            confidence,
            BuildSuggestedLines(classification.VoucherType, taxable, cgst, sgst, igst, total),
            fields,
            DueDate: dueDate,
            ReferenceNumber: reference,
            Gstin: gstin,
            Pan: pan,
            PlaceOfSupply: placeOfSupply,
            ReverseCharge: reverseCharge,
            Utgst: utgst,
            Cess: cess,
            Discount: discount,
            OtherCharges: otherCharges,
            RoundOff: roundOff,
            Tds: tds,
            Tcs: tcs,
            PaymentMethod: paymentMethod,
            BankName: bankName,
            PaymentReference: paymentReference,
            ClassificationExplanation: classification.Explanation,
            Items: items);
    }

    private (string Text, decimal Confidence, string Method) ExtractImage(string path)
    {
        var tessdata = Path.Combine(environment.ContentRootPath, "tessdata");
        using var engine = new TesseractEngine(tessdata, "eng", EngineMode.Default);
        using var image = Pix.LoadFromFile(path);
        using var page = engine.Process(image, PageSegMode.Auto);
        var confidence = Math.Clamp((decimal)page.GetMeanConfidence(), 0m, 1m);
        return (page.GetText() ?? string.Empty, confidence, "Tesseract OCR");
    }

    private (string Text, decimal Confidence, string Method) ExtractPdf(string path)
    {
        try
        {
            using var document = PdfDocument.Open(path);
            var text = new StringBuilder();
            foreach (var page in document.GetPages()) text.AppendLine(page.Text);
            if (text.Length == 0) return (string.Empty, 0m, "PDF text extraction");
            return (text.ToString(), 0.98m, "Embedded PDF text");
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "PDF text extraction failed for {Path}", path);
            return (string.Empty, 0m, "PDF text extraction failed");
        }
    }

    private static IReadOnlyList<ExtractedField> BuildFields(
        string? party, string? number, string? date, string? dueDate, string? reference, string? gstin,
        string? pan, string? placeOfSupply, decimal? taxable, decimal? cgst, decimal? sgst, decimal? igst,
        decimal? utgst, decimal? cess, decimal? discount, decimal? otherCharges, decimal? roundOff,
        decimal? tds, decimal? tcs, decimal? total, string? paymentMethod, string? paymentReference,
        string? bankName, SourceReference source)
    {
        var fields = new List<ExtractedField>();
        Add("PartyName", party);
        Add("DocumentNumber", number);
        Add("Date", date);
        Add("DueDate", dueDate);
        Add("ReferenceNumber", reference);
        Add("GSTIN", gstin);
        Add("PAN", pan);
        Add("PlaceOfSupply", placeOfSupply);
        Add("TaxableAmount", taxable?.ToString(CultureInfo.InvariantCulture));
        Add("CGST", cgst?.ToString(CultureInfo.InvariantCulture));
        Add("SGST", sgst?.ToString(CultureInfo.InvariantCulture));
        Add("IGST", igst?.ToString(CultureInfo.InvariantCulture));
        Add("UTGST", utgst?.ToString(CultureInfo.InvariantCulture));
        Add("Cess", cess?.ToString(CultureInfo.InvariantCulture));
        Add("Discount", discount?.ToString(CultureInfo.InvariantCulture));
        Add("OtherCharges", otherCharges?.ToString(CultureInfo.InvariantCulture));
        Add("RoundOff", roundOff?.ToString(CultureInfo.InvariantCulture));
        Add("TDS", tds?.ToString(CultureInfo.InvariantCulture));
        Add("TCS", tcs?.ToString(CultureInfo.InvariantCulture));
        Add("TotalAmount", total?.ToString(CultureInfo.InvariantCulture));
        Add("PaymentMethod", paymentMethod);
        Add("PaymentReference", paymentReference);
        Add("BankName", bankName);
        return fields;

        void Add(string name, string? value)
        {
            if (value is not null) fields.Add(new(name, value, value, source));
        }
    }

    private static IReadOnlyList<VoucherLine> BuildSuggestedLines(
        VoucherType type, decimal? taxable, decimal? cgst, decimal? sgst, decimal? igst, decimal? total)
    {
        total ??= (taxable ?? 0) + (cgst ?? 0) + (sgst ?? 0) + (igst ?? 0);
        if (total <= 0) return [];
        var amount = total.Value;
        var baseAmount = taxable ?? Math.Max(0, amount - (cgst ?? 0) - (sgst ?? 0) - (igst ?? 0));
        return type switch
        {
            VoucherType.Sales => InvoiceLines(isSales: true),
            VoucherType.Purchase => InvoiceLines(isSales: false),
            VoucherType.Expense => [Suggested("Expense (select existing)", amount, 0), Suggested("Vendor (select existing)", 0, amount)],
            VoucherType.AssetPurchase => [Suggested("Fixed Asset (select existing)", amount, 0), Suggested("Supplier (select existing)", 0, amount)],
            VoucherType.Receipt or VoucherType.BankReceipt => [Suggested("Cash / Bank (select existing)", amount, 0), Suggested("Party (select existing)", 0, amount)],
            VoucherType.Payment or VoucherType.BankPayment => [Suggested("Party / Expense (select existing)", amount, 0), Suggested("Cash / Bank (select existing)", 0, amount)],
            VoucherType.CreditNote => [Suggested("Sales Return (select existing)", amount, 0), Suggested("Customer (select existing)", 0, amount)],
            VoucherType.DebitNote => [Suggested("Supplier (select existing)", amount, 0), Suggested("Purchase Return (select existing)", 0, amount)],
            VoucherType.Contra => [Suggested("Destination Cash / Bank", amount, 0), Suggested("Source Cash / Bank", 0, amount)],
            _ => []
        };

        static VoucherLine Suggested(string name, decimal debit, decimal credit) => new(Guid.NewGuid(), null, name, debit, credit, 0.5m);

        IReadOnlyList<VoucherLine> InvoiceLines(bool isSales)
        {
            var lines = new List<VoucherLine>
            {
                Suggested(isSales ? "Customer (select existing)" : "Purchase (select existing)", isSales ? amount : baseAmount, 0)
            };
            if (!isSales && cgst > 0) lines.Add(Suggested("Input CGST (select existing)", cgst.Value, 0));
            if (!isSales && sgst > 0) lines.Add(Suggested("Input SGST (select existing)", sgst.Value, 0));
            if (!isSales && igst > 0) lines.Add(Suggested("Input IGST (select existing)", igst.Value, 0));
            if (isSales)
            {
                lines.Add(Suggested("Sales (select existing)", 0, baseAmount));
                if (cgst > 0) lines.Add(Suggested("Output CGST (select existing)", 0, cgst.Value));
                if (sgst > 0) lines.Add(Suggested("Output SGST (select existing)", 0, sgst.Value));
                if (igst > 0) lines.Add(Suggested("Output IGST (select existing)", 0, igst.Value));
            }
            else
            {
                lines.Add(Suggested("Supplier (select existing)", 0, amount));
            }
            return lines;
        }
    }

    private static string? ExtractParty(string text, VoucherType type)
    {
        var pattern = type == VoucherType.Sales
            ? @"(?im)^\s*(?:bill\s*to|customer(?:\s*name)?)\s*[:.-]?\s*([^\r\n]{2,80})"
            : @"(?im)^\s*(?:supplier|vendor|bill\s*from)\s*[:.-]?\s*([^\r\n]{2,80})";
        return MatchValue(text, pattern);
    }

    private static string BuildNarration(VoucherType type, string? number, DateOnly? date)
    {
        var details = new[] { number is null ? null : $"no. {number}", date is null ? null : $"dated {date:dd-MM-yyyy}" };
        return $"Being {type.ToString().ToLowerInvariant()} document {string.Join(" ", details.Where(value => value is not null))}.".Replace("  ", " ");
    }

    private static string? MatchValue(string text, string pattern) => Regex.Match(text, pattern).Groups is { Count: > 1 } groups && groups[1].Success
        ? groups[1].Value.Trim() : null;

    private static decimal? MatchAmount(string text, string pattern)
    {
        var value = MatchValue(text, pattern)?.Replace(",", string.Empty);
        return decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var amount) ? amount : null;
    }

    private static decimal? MatchSignedAmount(string text, string pattern)
    {
        var value = MatchValue(text, pattern)?.Replace(",", string.Empty);
        return decimal.TryParse(value, NumberStyles.Number | NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var amount) ? amount : null;
    }

    private static DateOnly? ParseDate(string? value)
    {
        string[] formats = ["d-M-yyyy", "dd-MM-yyyy", "d/M/yyyy", "dd/MM/yyyy", "d.M.yyyy", "dd.MM.yyyy", "d-M-yy", "d/M/yy"];
        return DateOnly.TryParseExact(value, formats, CultureInfo.InvariantCulture, DateTimeStyles.None, out var date) ? date : null;
    }
}