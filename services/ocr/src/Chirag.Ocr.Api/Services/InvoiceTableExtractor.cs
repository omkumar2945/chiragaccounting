using System.Globalization;
using System.Text.RegularExpressions;
using Chirag.Ocr.Api.Domain;

namespace Chirag.Ocr.Api.Services;

public static partial class InvoiceTableExtractor
{
    public static IReadOnlyList<InvoiceItem> Extract(string text, SourceReference source)
    {
        var lines = text.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .Select(line => MultiSpace().Replace(line.Trim(), " "))
            .Where(line => line.Length > 0)
            .ToArray();
        var headerIndex = Array.FindIndex(lines, IsItemHeader);
        if (headerIndex < 0) return [];

        var items = new List<InvoiceItem>();
        foreach (var line in lines.Skip(headerIndex + 1).Take(60))
        {
            if (StopRow().IsMatch(line)) break;
            var item = ParseRow(line, source);
            if (item is not null) items.Add(item);
        }
        return items;
    }

    private static bool IsItemHeader(string line)
    {
        var normalized = line.ToUpperInvariant();
        return HeaderDescription().IsMatch(normalized) && HeaderQuantity().IsMatch(normalized) &&
            HeaderAmount().IsMatch(normalized);
    }

    private static InvoiceItem? ParseRow(string line, SourceReference source)
    {
        var tokens = line.Split(' ', StringSplitOptions.RemoveEmptyEntries).ToList();
        if (tokens.Count < 4) return null;
        if (Regex.IsMatch(tokens[0], @"^\d+[.)]?$")) tokens.RemoveAt(0);
        if (tokens.Count < 4 || !TryAmount(tokens[^1], out var amount)) return null;
        tokens.RemoveAt(tokens.Count - 1);
        if (!TryAmount(tokens[^1], out var rate)) return null;
        tokens.RemoveAt(tokens.Count - 1);

        string? unit = null;
        if (tokens.Count > 0 && Regex.IsMatch(tokens[^1], @"^[A-Za-z]{1,8}$"))
        {
            unit = tokens[^1];
            tokens.RemoveAt(tokens.Count - 1);
        }
        if (tokens.Count == 0 || !TryAmount(tokens[^1], out var quantity)) return null;
        tokens.RemoveAt(tokens.Count - 1);

        string? hsnSac = null;
        if (tokens.Count > 1 && Regex.IsMatch(tokens[^1], @"^\d{4,8}$"))
        {
            hsnSac = tokens[^1];
            tokens.RemoveAt(tokens.Count - 1);
        }
        var description = string.Join(' ', tokens).Trim(' ', '-', ':');
        if (description.Length < 2 || !description.Any(char.IsLetter)) return null;

        var expected = quantity * rate;
        var confidence = Math.Abs(expected - amount) <= Math.Max(1m, amount * 0.01m) ? source.Confidence : source.Confidence * 0.75m;
        return new(description, hsnSac, quantity, unit, rate, null, amount, null, amount,
            source with { Confidence = confidence, Method = $"{source.Method} + semantic table" });
    }

    private static bool TryAmount(string value, out decimal amount) => decimal.TryParse(
        value.Replace(",", string.Empty).Replace("₹", string.Empty), NumberStyles.Number,
        CultureInfo.InvariantCulture, out amount);

    [GeneratedRegex(@"\b(DESCRIPTION|PARTICULARS?|ITEM|PRODUCT)\b")]
    private static partial Regex HeaderDescription();
    [GeneratedRegex(@"\b(QTY|QUANTITY)\b")]
    private static partial Regex HeaderQuantity();
    [GeneratedRegex(@"\b(AMOUNT|VALUE|TOTAL)\b")]
    private static partial Regex HeaderAmount();
    [GeneratedRegex(@"^(?:SUB\s*TOTAL|TAXABLE|CGST|SGST|IGST|CESS|DISCOUNT|FREIGHT|ROUND|GRAND\s*TOTAL|TOTAL\b)", RegexOptions.IgnoreCase)]
    private static partial Regex StopRow();
    [GeneratedRegex(@"\s+")]
    private static partial Regex MultiSpace();
}