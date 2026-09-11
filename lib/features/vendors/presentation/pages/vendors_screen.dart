import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/features/vendors/presentation/pages/add_vendor_screen.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, VendorService service, String vendorId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vendor?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              service.deleteVendor(vendorId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddVendorScreen()),
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Vendor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer<VendorService>(
          builder: (context, service, child) {
            final vendors = service.searchVendors(_searchCtrl.text);
            return Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, code, mobile, GSTIN...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _statCard(Icons.storefront_outlined, 'Total', '${vendors.length}', Colors.teal)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard(Icons.verified_user_outlined, 'Active', '${vendors.where((v) => v.isActive).length}', Colors.green)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: vendors.isEmpty
                      ? const Center(child: Text('No vendors found', style: TextStyle(color: Colors.black54)))
                      : ListView.builder(
                          itemCount: vendors.length,
                          itemBuilder: (context, index) {
                            final vendor = vendors[index];
                            final subtitleLines = [
                              if (vendor.mobileNumber.isNotEmpty) vendor.mobileNumber,
                              if (vendor.gstNumber.isNotEmpty) 'GSTIN: ${vendor.gstNumber}',
                              if (vendor.email.isNotEmpty) vendor.email,
                            ];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.shade100,
                                  child: Text(
                                    vendor.vendorName.isNotEmpty ? vendor.vendorName[0].toUpperCase() : 'V',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(vendor.vendorName.isEmpty ? 'Unnamed vendor' : vendor.vendorName),
                                subtitle: Text(subtitleLines.join('\n')),
                                isThreeLine: subtitleLines.length > 1,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddVendorScreen(initialVendor: vendor),
                                        ),
                                      );
                                    } else if (value == 'delete') {
                                      _confirmDelete(context, service, vendor.id);
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
          },
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
