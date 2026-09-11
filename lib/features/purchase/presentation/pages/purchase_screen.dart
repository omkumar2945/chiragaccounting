import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/purchase/presentation/pages/add_purchase_bill_screen.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({
    super.key,
    this.initialSearchQuery = '',
    this.initialMode,
  });

  final String initialSearchQuery;
  final PurchaseEntryMode? initialMode;

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  PurchaseEntryMode? _selectedMode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery);
    _searchFocusNode = FocusNode();
    _selectedMode = widget.initialMode;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPurchaseBillScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search bill number/vendor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SearchableDropdownFormField<PurchaseEntryMode?>(
                    value: _selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Entry Filter',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      null,
                      PurchaseEntryMode.manual,
                      PurchaseEntryMode.upload,
                    ],
                    itemLabelBuilder: (mode) {
                      if (mode == null) return 'All';
                      return mode == PurchaseEntryMode.manual
                          ? 'Manual Entry'
                          : 'Upload Entry';
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedMode = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton(
                  icon: Icons.add_business_outlined,
                  title: 'New Purchase',
                  subtitle: 'Create a purchase bill',
                  color: Colors.orange,
                  onTap: () => _openPurchaseEntry(),
                ),
                _actionButton(
                  icon: Icons.edit_note,
                  title: 'Manual Entry',
                  subtitle: 'Type bill details directly',
                  color: Colors.deepOrange,
                  onTap: () =>
                      _openPurchaseEntry(launchMode: PurchaseLaunchMode.manual),
                ),
                _actionButton(
                  icon: Icons.document_scanner_outlined,
                  title: 'OCR Upload',
                  subtitle: 'Import from camera, image, or PDF',
                  color: Colors.teal,
                  onTap: () =>
                      _openPurchaseEntry(launchMode: PurchaseLaunchMode.ocr),
                ),
                _actionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Upload PDF',
                  subtitle: 'Open OCR with a purchase PDF',
                  color: Colors.redAccent,
                  onTap: () =>
                      _openPurchaseEntry(launchMode: PurchaseLaunchMode.pdf),
                ),
                _actionButton(
                  icon: Icons.image_outlined,
                  title: 'Upload Image',
                  subtitle: 'Open OCR with a bill image',
                  color: Colors.green,
                  onTap: () =>
                      _openPurchaseEntry(launchMode: PurchaseLaunchMode.image),
                ),
                _actionButton(
                  icon: Icons.search,
                  title: 'Search',
                  subtitle: 'Jump to bill search',
                  color: Colors.brown,
                  onTap: _focusSearch,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<PurchaseService>(
                builder: (context, purchaseService, _) {
                  final query = _searchController.text.trim().toLowerCase();
                  var bills = purchaseService.bills
                      .where((bill) {
                        if (query.isEmpty) {
                          return true;
                        }
                        return bill.billNumber.toLowerCase().contains(query) ||
                            bill.vendorName.toLowerCase().contains(query);
                      })
                      .toList(growable: false);

                  if (_selectedMode != null) {
                    bills = bills
                        .where((bill) => bill.mode == _selectedMode)
                        .toList(growable: false);
                  }

                  bills = bills.reversed.toList(growable: false);
                  final totalAmount = bills.fold<double>(
                    0,
                    (sum, bill) => sum + bill.grandTotal,
                  );

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              title: 'Bills',
                              value: bills.length.toString(),
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              title: 'Filtered Value',
                              value: '₹ ${totalAmount.toStringAsFixed(2)}',
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text(
                            'Recent Purchase Bills',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: bills.isEmpty
                            ? const Center(
                                child: Text(
                                  'No purchase bills found. Use quick actions to create or upload one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: bills.length,
                                itemBuilder: (context, index) {
                                  final bill = bills[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.orange.shade100,
                                        child: const Icon(
                                          Icons.receipt_long,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      title: Text('Bill #${bill.billNumber}'),
                                      subtitle: Text(
                                        '${bill.vendorName}\n₹ ${bill.grandTotal.toStringAsFixed(2)}',
                                      ),
                                      isThreeLine: true,
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Chip(
                                            label: Text(
                                              bill.mode ==
                                                      PurchaseEntryMode.manual
                                                  ? 'Manual'
                                                  : 'Upload',
                                            ),
                                            backgroundColor:
                                                bill.mode ==
                                                    PurchaseEntryMode.manual
                                                ? Colors.blue
                                                : Colors.orange,
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'view') {
                                                _showBillDetails(bill);
                                              }
                                              if (value == 'delete') {
                                                _confirmDeleteBill(bill.id);
                                              }
                                            },
                                            itemBuilder: (context) {
                                              return [
                                                const PopupMenuItem(
                                                  value: 'view',
                                                  child: Text('View'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete'),
                                                ),
                                              ];
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPurchaseEntry({
    PurchaseLaunchMode launchMode = PurchaseLaunchMode.standard,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPurchaseBillScreen(initialLaunchMode: launchMode),
      ),
    );
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedMode = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _showBillDetails(PurchaseBill bill) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bill #${bill.billNumber}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Vendor: ${bill.vendorName}'),
              Text('Date: ${bill.billDate.toString().split(' ').first}'),
              Text(
                'Mode: ${bill.mode == PurchaseEntryMode.manual ? 'Manual Entry' : 'Upload Entry'}',
              ),
              Text('Items: ${bill.items.length}'),
              Text('Total: ₹ ${bill.grandTotal.toStringAsFixed(2)}'),
              if (bill.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Notes: ${bill.notes}'),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteBill(String billId) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Purchase Bill'),
          content: const Text(
            'Are you sure you want to delete this purchase bill?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                context.read<PurchaseService>().deleteBill(billId);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final buttonWidth = MediaQuery.sizeOf(context).width < 420 ? 150.0 : 170.0;
    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
