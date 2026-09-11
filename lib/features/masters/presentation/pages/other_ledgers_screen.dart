import 'package:flutter/material.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

enum OtherLedgerMode {
  create,
  view,
  edit,
}

class OtherLedgersScreen extends StatefulWidget {
  final OtherLedgerMode initialMode;

  const OtherLedgersScreen({
    super.key,
    this.initialMode = OtherLedgerMode.view,
  });

  @override
  State<OtherLedgersScreen> createState() => _OtherLedgersScreenState();
}

class _OtherLedgersScreenState extends State<OtherLedgersScreen> {
  static const List<String> _ledgerCategories = [
    'Sundry Debtors',
    'Sundry Creditors',
    'Direct Expenses',
    'Indirect Expenses',
    'Duties & Taxes',
    'Investments',
    'Suspense Account',
    'Capital Account',
    'Cash-in-Hand',
    'Bank Accounts',
    'Loans',
    'Income',
    'Others',
  ];

  final List<Map<String, String>> _ledgers = <Map<String, String>>[
    {'name': 'Cash Account', 'group': 'Cash-in-Hand'},
    {'name': 'SBI Current A/c', 'group': 'Bank Accounts'},
    {'name': 'Input CGST', 'group': 'Duties & Taxes'},
  ];

  late OtherLedgerMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  String get _title {
    switch (_mode) {
      case OtherLedgerMode.create:
        return 'Other Ledgers - Create';
      case OtherLedgerMode.view:
        return 'Other Ledgers - View';
      case OtherLedgerMode.edit:
        return 'Other Ledgers - Edit';
    }
  }

  Future<void> _showLedgerDialog({Map<String, String>? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    String selectedGroup = existing?['group'] ?? _ledgerCategories.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Create Ledger' : 'Edit Ledger'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Ledger Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SearchableDropdownFormField<String>(
              value: selectedGroup,
              decoration: const InputDecoration(
                labelText: 'Ledger Group',
                border: OutlineInputBorder(),
              ),
              items: _ledgerCategories,
              itemLabelBuilder: (group) => group,
              onChanged: (value) {
                if (value != null) {
                  selectedGroup = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                final item = {'name': name, 'group': selectedGroup};
                if (index == null) {
                  _ledgers.add(item);
                } else {
                  _ledgers[index] = item;
                }
              });
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Ledger created' : 'Ledger updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<OtherLedgerMode>(
            icon: const Icon(Icons.tune),
            onSelected: (mode) => setState(() => _mode = mode),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: OtherLedgerMode.create,
                child: Text('Create Mode'),
              ),
              PopupMenuItem(
                value: OtherLedgerMode.view,
                child: Text('View Mode'),
              ),
              PopupMenuItem(
                value: OtherLedgerMode.edit,
                child: Text('Edit Mode'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _mode == OtherLedgerMode.create
          ? FloatingActionButton.extended(
              onPressed: _showLedgerDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Ledger'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ledgerCategories
                    .map(
                      (group) => Chip(
                        label: Text(group),
                        backgroundColor: Colors.indigo.shade50,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_ledgers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No other ledgers available.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ..._ledgers.asMap().entries.map((entry) {
              final index = entry.key;
              final ledger = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: const Icon(Icons.book_outlined, color: Colors.indigo),
                  ),
                  title: Text(ledger['name'] ?? ''),
                  subtitle: Text(ledger['group'] ?? ''),
                  trailing: _mode == OtherLedgerMode.edit
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showLedgerDialog(
                            existing: ledger,
                            index: index,
                          ),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
