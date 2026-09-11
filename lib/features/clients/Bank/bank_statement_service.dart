import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/clients/Bank/bank_statement_analyzer.dart';

class BankStatementHistoryEntry {
  final String id;
  final String sourceName;
  final DateTime importedAt;
  final BankStatementFormat format;
  final List<BankStatementSuggestion> suggestions;

  const BankStatementHistoryEntry({
    required this.id,
    required this.sourceName,
    required this.importedAt,
    required this.format,
    required this.suggestions,
  });

  BankStatementHistoryEntry copyWith({
    String? id,
    String? sourceName,
    DateTime? importedAt,
    BankStatementFormat? format,
    List<BankStatementSuggestion>? suggestions,
  }) {
    return BankStatementHistoryEntry(
      id: id ?? this.id,
      sourceName: sourceName ?? this.sourceName,
      importedAt: importedAt ?? this.importedAt,
      format: format ?? this.format,
      suggestions: suggestions ?? this.suggestions,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'sourceName': sourceName,
      'importedAt': importedAt.toIso8601String(),
      'format': format.storageValue,
      'suggestions': suggestions
          .map((item) => item.toMap())
          .toList(growable: false),
    };
  }

  factory BankStatementHistoryEntry.fromMap(Map<String, dynamic> map) {
    final rawSuggestions =
        (map['suggestions'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(growable: false);

    return BankStatementHistoryEntry(
      id: (map['id'] ?? '').toString(),
      sourceName: (map['sourceName'] ?? 'Statement').toString(),
      importedAt:
          DateTime.tryParse((map['importedAt'] ?? '').toString()) ??
          DateTime.now(),
      format: BankStatementFormatExtension.fromStorage(
        (map['format'] ?? '').toString(),
      ),
      suggestions: rawSuggestions
          .map(BankStatementSuggestion.fromMap)
          .toList(growable: false),
    );
  }
}

class BankStatementService {
  static const String _historyKey = 'bank_statement_history_v1';
  static const String _rulesKey = 'bank_statement_rules_v1';

  Future<List<BankStatementHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <BankStatementHistoryEntry>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <BankStatementHistoryEntry>[];

    final entries = decoded
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .map(BankStatementHistoryEntry.fromMap)
        .toList(growable: false);

    entries.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return entries;
  }

  Future<BankStatementHistoryEntry> saveHistoryEntry({
    required String sourceName,
    required BankStatementFormat format,
    required List<BankStatementSuggestion> suggestions,
  }) async {
    final entry = BankStatementHistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sourceName: sourceName,
      importedAt: DateTime.now(),
      format: format,
      suggestions: suggestions,
    );

    final history = await loadHistory();
    final updated = <BankStatementHistoryEntry>[entry, ...history];
    await _saveHistory(updated);
    return entry;
  }

  Future<void> updateHistoryEntry(BankStatementHistoryEntry entry) async {
    final history = await loadHistory();
    final updated = history
        .map((item) => item.id == entry.id ? entry : item)
        .toList(growable: false);
    await _saveHistory(updated);
  }

  Future<List<BankRecurringRule>> loadRecurringRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rulesKey);
    if (raw == null || raw.trim().isEmpty) return const <BankRecurringRule>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <BankRecurringRule>[];

    return decoded
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .map(BankRecurringRule.fromMap)
        .toList(growable: false);
  }

  Future<void> upsertRecurringRulesFromSuggestions(
    List<BankStatementSuggestion> suggestions,
  ) async {
    final rules = await loadRecurringRules();
    final ruleByPattern = <String, BankRecurringRule>{
      for (final rule in rules)
        if (rule.patternKey.trim().isNotEmpty) rule.patternKey.trim(): rule,
    };

    for (final suggestion in suggestions) {
      if (suggestion.patternKey.trim().isEmpty) continue;
      ruleByPattern[suggestion.patternKey.trim()] = BankRecurringRule(
        patternKey: suggestion.patternKey.trim(),
        ledgerName: suggestion.suggestedLedger.trim(),
        category: suggestion.category,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _rulesKey,
      jsonEncode(
        ruleByPattern.values
            .map((item) => item.toMap())
            .toList(growable: false),
      ),
    );
  }

  Future<void> _saveHistory(List<BankStatementHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(entries.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
