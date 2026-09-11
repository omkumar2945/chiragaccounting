import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/clients/Bank/bank_statement_analyzer.dart';
import 'package:chirag_accounting/features/clients/Bank/bank_statement_service.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class BankStatementHistoryScreen extends StatefulWidget {
  final BankStatementService service;
  final String? initialEntryId;
  final Future<void> Function(List<BankStatementSuggestion>)? onPostSuggestions;

  const BankStatementHistoryScreen({
    super.key,
    required this.service,
    this.initialEntryId,
    this.onPostSuggestions,
  });

  @override
  State<BankStatementHistoryScreen> createState() =>
      _BankStatementHistoryScreenState();
}

class _BankStatementHistoryScreenState
    extends State<BankStatementHistoryScreen> {
  List<BankStatementHistoryEntry> _entries = <BankStatementHistoryEntry>[];
  BankStatementHistoryEntry? _selectedEntry;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.service.loadHistory();
    BankStatementHistoryEntry? selected;
    if (widget.initialEntryId != null) {
      selected = entries
          .where((item) => item.id == widget.initialEntryId)
          .cast<BankStatementHistoryEntry?>()
          .firstWhere((item) => item != null, orElse: () => null);
    }
    selected ??= entries.isNotEmpty ? entries.first : null;
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _selectedEntry = selected;
      _loading = false;
    });
  }

  Future<void> _editSuggestion(int index) async {
    final entry = _selectedEntry;
    if (entry == null) return;
    final suggestion = entry.suggestions[index];
    final ledgerCtrl = TextEditingController(text: suggestion.suggestedLedger);
    var category = suggestion.category;

    final updated = await showDialog<BankStatementSuggestion>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Correct Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                suggestion.description,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ledgerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ledger Allocation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SearchableDropdownFormField<StatementCategory>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: StatementCategory.values,
                itemLabelBuilder: (item) => item.label,
                onChanged: (value) {
                  if (value != null) category = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  suggestion.copyWith(
                    suggestedLedger: ledgerCtrl.text.trim(),
                    category: category,
                    recurringHint: suggestion.isRecurring
                        ? 'Saved rule applied after correction'
                        : suggestion.recurringHint,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    ledgerCtrl.dispose();
    if (updated == null) return;

    final updatedSuggestions = entry.suggestions.toList(growable: true);
    updatedSuggestions[index] = updated;
    final updatedEntry = entry.copyWith(suggestions: updatedSuggestions);
    await widget.service.updateHistoryEntry(updatedEntry);
    if (!mounted) return;
    setState(() {
      _selectedEntry = updatedEntry;
      _entries = _entries
          .map((item) => item.id == updatedEntry.id ? updatedEntry : item)
          .toList(growable: false);
    });
  }

  Future<void> _saveRecurringRules() async {
    final entry = _selectedEntry;
    if (entry == null) return;
    setState(() => _saving = true);
    await widget.service.upsertRecurringRulesFromSuggestions(entry.suggestions);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recurring rules saved from statement corrections.'),
      ),
    );
  }

  Future<void> _postSelectedEntry() async {
    final entry = _selectedEntry;
    if (entry == null || widget.onPostSuggestions == null) return;
    setState(() => _saving = true);
    await widget.service.upsertRecurringRulesFromSuggestions(entry.suggestions);
    await widget.onPostSuggestions!(entry.suggestions);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  Widget _buildHistoryList() {
    if (_entries.isEmpty) {
      return const Center(child: Text('No statement history available.'));
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final selected = _selectedEntry?.id == entry.id;
        return ListTile(
          selected: selected,
          selectedTileColor: const Color(0xFFE8F1FB),
          title: Text(
            entry.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${entry.format.label}\n${entry.importedAt.toIso8601String().split('T').first} • ${entry.suggestions.length} item(s)',
          ),
          isThreeLine: true,
          onTap: () {
            setState(() => _selectedEntry = entry);
          },
        );
      },
    );
  }

  Widget _buildReviewPanel() {
    if (_selectedEntry == null) {
      return const Center(child: Text('Select a statement to review.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedEntry!.sourceName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedEntry!.format.label} • ${_selectedEntry!.suggestions.length} transaction(s)',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _saveRecurringRules,
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Save Rules'),
              ),
              if (widget.onPostSuggestions != null)
                FilledButton.icon(
                  onPressed: _saving ? null : _postSelectedEntry,
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Post Vouchers'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _selectedEntry!.suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _selectedEntry!.suggestions[index];
                return ListTile(
                  title: Text(suggestion.description),
                  subtitle: Text(
                    'Ledger: ${suggestion.suggestedLedger}\nCategory: ${suggestion.category.label}${suggestion.isRecurring ? ' • ${suggestion.recurringHint}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${suggestion.isCredit ? '+' : '-'}Rs. ${suggestion.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: suggestion.isCredit
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _editSuggestion(index),
                        child: const Text(
                          'Correct',
                          style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Statement'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 840;
                final historyCard = Card(
                  margin: const EdgeInsets.all(12),
                  child: _buildHistoryList(),
                );
                final reviewCard = Card(
                  margin: EdgeInsets.fromLTRB(isCompact ? 12 : 0, 12, 12, 12),
                  child: _buildReviewPanel(),
                );

                if (isCompact) {
                  return Column(
                    children: [
                      SizedBox(height: 220, child: historyCard),
                      Expanded(child: reviewCard),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(width: 280, child: historyCard),
                    Expanded(child: reviewCard),
                  ],
                );
              },
            ),
    );
  }
}
