// AI Missing Masters Center Screen
//
// ONE screen to create all missing masters across ALL jobs.
// NOT popup-per-invoice. Master-wise, not invoice-wise.
//
// ┌────────────────────────────────────────────────────────────┐
// │  AI Found New Masters                                      │
// ├────────────────────────────────────────────────────────────┤
// │  New Customers    3    New Suppliers  2                    │
// │  New Products    15    New Ledgers    1                    │
// ├────────────────────────────────────────────────────────────┤
// │  Products                                                  │
// │  12MM TG CLEAR      appears in 38 invoices   [Create]     │
// │  8MM CLEAR          appears in 22 invoices   [Create]     │
// │  6MM LAMI           appears in 5  invoices   [Merge]      │
// └────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';

class AiMissingMastersCenterScreen extends StatefulWidget {
  const AiMissingMastersCenterScreen({super.key});

  @override
  State<AiMissingMastersCenterScreen> createState() =>
      _AiMissingMastersCenterScreenState();
}

class _AiMissingMastersCenterScreenState
    extends State<AiMissingMastersCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const List<_MasterType> _types = [
    _MasterType('All', null, Icons.list_alt_outlined),
    _MasterType('Customer', 'customer', Icons.person_outlined),
    _MasterType('Supplier', 'supplier', Icons.business_outlined),
    _MasterType('Product', 'product', Icons.inventory_2_outlined),
    _MasterType('Ledger', 'ledger',
        Icons.account_balance_wallet_outlined),
    _MasterType('HSN', 'hsn', Icons.tag_outlined),
    _MasterType('Unit', 'unit', Icons.straighten_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _types.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<WorkbenchQueueService>();
    final allMasters = svc.globalMissingMasters;
    final unresolved = allMasters.where((m) => !m.resolved).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Missing Masters Center',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(
              '${unresolved.length} new master${unresolved.length == 1 ? '' : 's'} to create',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummaryBar(svc),
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              labelColor: const Color(0xFF1A237E),
              indicatorColor: const Color(0xFF1A237E),
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 12),
              tabs: _types.map((t) {
                final count = t.type == null
                    ? unresolved.length
                    : unresolved
                        .where((m) => m.type == t.type)
                        .length;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 14),
                      const SizedBox(width: 4),
                      Text(t.label),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Master list
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _types.map((t) {
                final filtered = t.type == null
                    ? allMasters
                    : allMasters
                        .where((m) => m.type == t.type)
                        .toList();
                return _MasterList(
                  masters: filtered,
                  onResolve: (master, name) =>
                      svc.resolveMissingMaster(master, name),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(WorkbenchQueueService svc) {
    const types = ['customer', 'supplier', 'product', 'ledger'];
    const labels = ['Customers', 'Suppliers', 'Products', 'Ledgers'];
    const colors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(types.length, (i) {
          final count = svc.countByType(types[i]);
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: i < types.length - 1 ? 10 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colors[i].withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: colors[i].withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: colors[i],
                      ),
                    ),
                    Text(
                      'New\n${labels[i]}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.black45),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MasterList extends StatelessWidget {
  final List<GlobalMissingMaster> masters;
  final void Function(GlobalMissingMaster, String) onResolve;

  const _MasterList({required this.masters, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    if (masters.isEmpty) {
      return const Center(
        child: Text(
          'No new masters in this category.',
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: masters.length,
      itemBuilder: (_, i) => _MasterCard(
        master: masters[i],
        onResolve: (name) => onResolve(masters[i], name),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MasterCard extends StatefulWidget {
  final GlobalMissingMaster master;
  final void Function(String resolvedName) onResolve;

  const _MasterCard({required this.master, required this.onResolve});

  @override
  State<_MasterCard> createState() => _MasterCardState();
}

class _MasterCardState extends State<_MasterCard> {
  bool _expanded = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.master.suggestedName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.master;
    final typeColor = _typeColor(m.type);

    if (m.resolved) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.displayLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Text(
              'Created  ·  ${m.jobIds.length} invoice${m.jobIds.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: typeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: typeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.suggestedName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        if (m.extra.isNotEmpty)
                          Text(
                            m.extra,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black38),
                          ),
                      ],
                    ),
                  ),
                  // Appears in N invoices
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Appears in',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black38),
                      ),
                      Text(
                        '${m.jobIds.length} invoice${m.jobIds.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // Expanded actions
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 16),
                  Text(
                    'Creating "${m.suggestedName}" will apply to all '
                    '${m.jobIds.length} invoice${m.jobIds.length == 1 ? '' : 's'} automatically.',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name to create',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixText: m.type,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: typeColor,
                            minimumSize: const Size(0, 42),
                          ),
                          onPressed: () {
                            final name = _nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            widget.onResolve(name);
                            setState(() => _expanded = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '"$name" created and applied to ${m.jobIds.length} invoice${m.jobIds.length == 1 ? '' : 's'}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            'Create & Apply to All  (${m.jobIds.length})',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          foregroundColor: Colors.blueGrey,
                        ),
                        onPressed: () =>
                            setState(() => _expanded = false),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'customer':
        return Colors.blue;
      case 'supplier':
        return Colors.teal;
      case 'product':
        return Colors.orange;
      case 'ledger':
        return Colors.purple;
      case 'hsn':
        return Colors.indigo;
      case 'unit':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MasterType {
  final String label;
  final String? type;
  final IconData icon;

  const _MasterType(this.label, this.type, this.icon);
}
