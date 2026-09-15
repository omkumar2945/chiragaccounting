import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:chirag_accounting/core/constants/import_template_content.dart';
import 'package:chirag_accounting/core/utils/file_download.dart';
import 'package:chirag_accounting/features/compat/screens/client_data_exchange_screen_compat.dart';
import '../../../services/customer_service.dart';
import 'add_customer_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    this.initialSearchQuery = '',
    this.activeFilter,
  });

  final String initialSearchQuery;
  final bool? activeFilter;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearchQuery;
  }

  void _openAddCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
    );
  }

  void _openImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientDataExchangeScreen()),
    );
  }

  Future<void> _saveTemplateFile({
    required String fileName,
    required String content,
    String extension = 'csv',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));

    try {
      await downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: extension == 'csv' ? 'text/csv;charset=utf-8' : 'application/json',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template downloaded: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _downloadCustomerDebtorsTemplate() async {
    await _saveTemplateFile(
      fileName: 'customer_debtors_import_template.csv',
      content: ImportTemplateContent.customerDebtorsCsv,
    );
  }

  Future<void> _downloadAllLedgersTemplate() async {
    await _saveTemplateFile(
      fileName: 'all_ledgers_mixed_import_template.csv',
      content: ImportTemplateContent.allLedgersMixedCsv,
    );
  }

  Future<void> _downloadVendorCreditorsTemplate() async {
    await _saveTemplateFile(
      fileName: 'vendor_creditors_import_template.csv',
      content: ImportTemplateContent.vendorCreditorsCsv,
    );
  }

  Future<void> _downloadInventoryCsvTemplate() async {
    await _saveTemplateFile(
      fileName: 'inventory_import_template.csv',
      content: ImportTemplateContent.inventoryCsv,
    );
  }

  Future<void> _downloadInventoryJsonTemplate() async {
    await _saveTemplateFile(
      fileName: 'inventory_import_template.json',
      content: ImportTemplateContent.inventoryJson,
      extension: 'json',
    );
  }

  Widget _buildRightActionPanel() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openAddCustomer,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Customer'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openImport,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import Data'),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Templates',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fill format:\n'
              'Ledger: ledger_name, ledger_group, mobile, email, gstin, pan, opening_balance\n'
              'Product: product_name, hsn, unit, opening_stock, purchase_rate, sales_rate, category',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _downloadCustomerDebtorsTemplate,
                  child: const Text('Customer Debtors CSV (Detailed)'),
                ),
                OutlinedButton(
                  onPressed: _downloadAllLedgersTemplate,
                  child: const Text('All Ledgers Mixed CSV (Detailed)'),
                ),
                OutlinedButton(
                  onPressed: _downloadVendorCreditorsTemplate,
                  child: const Text('Vendor Creditors CSV (Detailed)'),
                ),
                OutlinedButton(
                  onPressed: _downloadInventoryCsvTemplate,
                  child: const Text('Inventory CSV (Detailed)'),
                ),
                OutlinedButton(
                  onPressed: _downloadInventoryJsonTemplate,
                  child: const Text('Inventory JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context, CustomerService service, String customerId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete customer?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                service.deleteCustomer(customerId);
                Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: MediaQuery.of(context).size.width < 1000
          ? FloatingActionButton.extended(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Customer'),
              onPressed: _openAddCustomer,
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer<CustomerService>(
          builder: (context, customerService, child) {
            final width = MediaQuery.of(context).size.width;
            final showRightPanel = width >= 1000;
            var customers = customerService.searchCustomers(_searchController.text);
            if (widget.activeFilter != null) {
              customers = customers
                  .where((customer) => customer.isActive == widget.activeFilter)
                  .toList(growable: false);
            }
            final totalCustomers = customers.length;
            final activeCustomers = customers.where((customer) => customer.isActive).length;
            final creditLimit = customers.fold<double>(0, (sum, customer) => sum + customer.creditLimit);

            final mainContent = Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(Icons.people, 'Total', totalCustomers.toString(), Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(Icons.person_outline, 'Active', activeCustomers.toString(), Colors.green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(Icons.trending_up, 'Credit Limit', '₹${creditLimit.toStringAsFixed(0)}', Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Expanded(
                  child: customers.isEmpty
                      ? const Center(
                          child: Text(
                            'No customers match your search.',
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: customers.length,
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    customer.customerName.isNotEmpty ? customer.customerName[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(customer.customerName.isNotEmpty ? customer.customerName : 'Unnamed customer'),
                                subtitle: Text(
                                  [customer.email, customer.mobileNumber].where((value) => value.isNotEmpty).join('\n'),
                                ),
                                isThreeLine: [customer.email, customer.mobileNumber].where((value) => value.isNotEmpty).length > 1,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddCustomerScreen(initialCustomer: customer),
                                        ),
                                      );
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(context, customerService, customer.id);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );

                  if (!showRightPanel) {
                    return mainContent;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: mainContent),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: _buildRightActionPanel(),
                        ),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
