using System.Text.RegularExpressions;
using Chirag.Ocr.Api.Domain;

namespace Chirag.Ocr.Api.Services;

public enum MasterKind { Ledger, Product }

public sealed class AccountingMaster
{
    public Guid Id { get; set; }
    public required string ClientId { get; set; }
    public MasterKind Kind { get; set; }
    public required string Name { get; set; }
    public required string NormalizedName { get; set; }
    public string? GroupName { get; set; }
    public string? Gstin { get; set; }
    public string? HsnSac { get; set; }
    public string? Unit { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed record MasterSuggestion(
    Guid? MasterId, MasterKind Kind, string DetectedName, string SuggestedName,
    decimal Confidence, bool ExactMatch, bool RequiresCreation, string? GroupName = null,
    string? Gstin = null, string? HsnSac = null, string? Unit = null);

public sealed record CreateMasterRequest(
    MasterKind Kind, string Name, string? GroupName = null, string? Gstin = null,
    string? HsnSac = null, string? Unit = null, Guid? DocumentId = null);

public static class DraftMasterResolver
{
    public static AccountingDraft Resolve(AccountingDraft draft, IEnumerable<AccountingMaster> availableMasters)
    {
        var masters = availableMasters.ToArray();
        var suggestions = new List<MasterSuggestion>();
        var partyLedgerId = draft.PartyLedgerId;
        var partyName = draft.PartyName;

        if (!string.IsNullOrWhiteSpace(partyName))
        {
            var party = MasterMatcher.Suggest(MasterKind.Ledger, partyName, masters, gstin: draft.Gstin,
                groupName: draft.VoucherType == VoucherType.Sales ? "Sundry Debtors" : "Sundry Creditors");
            suggestions.Add(party);
            if (!party.RequiresCreation && party.Confidence >= 0.85m)
            {
                partyLedgerId = party.MasterId?.ToString();
                partyName = party.SuggestedName;
            }
        }

        var lines = draft.Lines.Select(line =>
        {
            var suggestion = MasterMatcher.Suggest(MasterKind.Ledger, line.LedgerName, masters,
                groupName: SuggestLedgerGroup(line.LedgerName));
            suggestions.Add(suggestion);
            return !suggestion.RequiresCreation && suggestion.Confidence >= 0.85m
                ? line with { LedgerId = suggestion.MasterId?.ToString(), LedgerName = suggestion.SuggestedName, Confidence = suggestion.Confidence }
                : line;
        }).ToArray();

        foreach (var item in draft.Items ?? [])
        {
            if (string.IsNullOrWhiteSpace(item.Description)) continue;
            suggestions.Add(MasterMatcher.Suggest(MasterKind.Product, item.Description, masters,
                hsnSac: item.HsnSac, unit: item.Unit));
        }

        return draft with
        {
            PartyLedgerId = partyLedgerId,
            PartyName = partyName,
            Lines = lines,
            MasterSuggestions = suggestions
                .GroupBy(suggestion => new { suggestion.Kind, Name = MasterMatcher.Normalize(suggestion.DetectedName) })
                .Select(group => group.OrderByDescending(suggestion => suggestion.Confidence).First())
                .ToArray()
        };
    }

    private static string SuggestLedgerGroup(string name)
    {
        var normalized = name.ToUpperInvariant();
        if (normalized.Contains("CGST") || normalized.Contains("SGST") || normalized.Contains("IGST") || normalized.Contains("CESS"))
            return normalized.Contains("INPUT") ? "Duties & Taxes - Input" : "Duties & Taxes - Output";
        if (normalized.Contains("BANK")) return "Bank Accounts";
        if (normalized.Contains("CASH")) return "Cash-in-Hand";
        if (normalized.Contains("SALE")) return "Sales Accounts";
        if (normalized.Contains("PURCHASE")) return "Purchase Accounts";
        if (normalized.Contains("EXPENSE") || normalized.Contains("FREIGHT") || normalized.Contains("CHARGE")) return "Indirect Expenses";
        return "Sundry Creditors / Debtors";
    }
}

public static partial class MasterMatcher
{
    public static MasterSuggestion Suggest(
        MasterKind kind, string detectedName, IEnumerable<AccountingMaster> masters,
        string? gstin = null, string? hsnSac = null, string? unit = null, string? groupName = null)
    {
        var normalized = Normalize(detectedName);
        var candidates = masters.Where(master => master.Kind == kind && master.IsActive).ToArray();
        var gstinMatch = string.IsNullOrWhiteSpace(gstin) ? null : candidates.FirstOrDefault(master =>
            string.Equals(master.Gstin, gstin, StringComparison.OrdinalIgnoreCase));
        var exact = gstinMatch ?? candidates.FirstOrDefault(master => master.NormalizedName == normalized);
        if (exact is not null)
            return Existing(exact, detectedName, gstinMatch is not null ? 1m : 0.99m, true);

        var closest = candidates
            .Select(master => new { Master = master, Score = Similarity(normalized, master.NormalizedName) })
            .OrderByDescending(candidate => candidate.Score)
            .FirstOrDefault();
        if (closest is not null && closest.Score >= 0.62m)
            return Existing(closest.Master, detectedName, closest.Score, false);

        return new(null, kind, detectedName.Trim(), detectedName.Trim(), 0m, false, true,
            groupName, gstin, hsnSac, unit);
    }

    public static string Normalize(string value) => NonAlphaNumeric().Replace(value.ToUpperInvariant(), string.Empty);

    private static MasterSuggestion Existing(AccountingMaster master, string detectedName, decimal confidence, bool exact) =>
        new(master.Id, master.Kind, detectedName.Trim(), master.Name, confidence, exact, false,
            master.GroupName, master.Gstin, master.HsnSac, master.Unit);

    private static decimal Similarity(string left, string right)
    {
        if (left.Length == 0 || right.Length == 0) return 0m;
        var distance = LevenshteinDistance(left, right);
        return Math.Round(1m - (decimal)distance / Math.Max(left.Length, right.Length), 3);
    }

    private static int LevenshteinDistance(string left, string right)
    {
        var costs = Enumerable.Range(0, right.Length + 1).ToArray();
        for (var leftIndex = 1; leftIndex <= left.Length; leftIndex++)
        {
            var previous = costs[0];
            costs[0] = leftIndex;
            for (var rightIndex = 1; rightIndex <= right.Length; rightIndex++)
            {
                var current = costs[rightIndex];
                costs[rightIndex] = Math.Min(
                    Math.Min(costs[rightIndex] + 1, costs[rightIndex - 1] + 1),
                    previous + (left[leftIndex - 1] == right[rightIndex - 1] ? 0 : 1));
                previous = current;
            }
        }
        return costs[right.Length];
    }

    [GeneratedRegex("[^A-Z0-9]")]
    private static partial Regex NonAlphaNumeric();
}