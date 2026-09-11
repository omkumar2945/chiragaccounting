import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/compat/screens/client_data_exchange_screen_compat.dart';
import 'package:chirag_accounting/features/products/industry_master_pack.dart';
import 'package:chirag_accounting/features/products/industry_setup_service.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/billing_print_setup/services/billing_print_setup_service.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/add_sales_invoice_screen.dart';
import 'package:chirag_accounting/features/services/invoice_document_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class SalesScreen extends StatefulWidget {
  final String initialSearchQuery;
  final bool readOnlyAuditMode;
  final InvoiceStatus? initialStatus;

  const SalesScreen({
    super.key,
    this.initialSearchQuery = '',
    this.readOnlyAuditMode = false,
    this.initialStatus,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  static const List<String> _externalSoftwareOptions = <String>[
    'Tally',
    'BUSY',
    'Marg ERP',
    'Vyapar',
    'Zoho Books',
    'Excel',
  ];

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final IndustrySetupService _industrySetupService = IndustrySetupService();
  InvoiceStatus? _selectedStatus;
  String _selectedIndustryLabel = '';
  BillingMethod _selectedBillingMethod = BillingMethod.inApp;
  String _selectedSoftware = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery);
    _searchFocusNode = FocusNode();
    _selectedStatus = widget.initialStatus;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureIndustrySetup();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthController>().currentUser;
    final canReviewCorrections =
        currentUser != null && !currentUser.role.isClient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: widget.readOnlyAuditMode
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Invoice'),
              onPressed: _showInvoiceTypePicker,
            ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search invoice number/customer...',
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
                  child: SearchableDropdownFormField<InvoiceStatus?>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status Filter',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: <InvoiceStatus?>[null, ...InvoiceStatus.values],
                    itemLabelBuilder: (status) =>
                        status == null ? 'All' : status.displayName,
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
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
                  icon: Icons.storefront_outlined,
                  title: 'Business Setup',
                  subtitle: _selectedIndustryLabel.isEmpty
                      ? 'Install industry starter data'
                      : 'Industry: $_selectedIndustryLabel',
                  color: Colors.purple,
                  onTap: _showBusinessSetupDialog,
                ),
                _actionButton(
                  icon: _selectedBillingMethod == BillingMethod.inApp
                      ? Icons.point_of_sale
                      : _selectedBillingMethod == BillingMethod.manual
                      ? Icons.document_scanner_outlined
                      : Icons.import_export,
                  title: 'Preferred Billing Flow',
                  subtitle: _billingMethodSubtitle(),
                  color: Colors.cyan,
                  onTap: _openPreferredBillingFlow,
                ),
                _actionButton(
                  icon: Icons.add_business_outlined,
                  title: 'New Invoice',
                  subtitle: 'Create a sales invoice',
                  color: Colors.blue,
                  onTap: () => _openInvoiceEntry(),
                ),
                _actionButton(
                  icon: Icons.edit_note,
                  title: 'Manual Entry',
                  subtitle: 'Type invoice details directly',
                  color: Colors.indigo,
                  onTap: () =>
                      _openInvoiceEntry(entryMode: SalesEntryMode.manual),
                ),
                _actionButton(
                  icon: Icons.document_scanner_outlined,
                  title: 'OCR Upload',
                  subtitle: 'Import from image or PDF',
                  color: Colors.teal,
                  onTap: () => _openInvoiceEntry(entryMode: SalesEntryMode.ocr),
                ),
                _actionButton(
                  icon: Icons.search,
                  title: 'Search',
                  subtitle: 'Jump to invoice search',
                  color: Colors.green,
                  onTap: _focusSearch,
                ),
                _actionButton(
                  icon: Icons.format_list_bulleted,
                  title: 'Invoice List',
                  subtitle: 'Show all sales invoices',
                  color: Colors.brown,
                  onTap: _resetFilters,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<SalesService>(
                builder: (context, salesService, child) {
                  var invoices = salesService.searchInvoicesByType(
                    _searchController.text,
                    SalesInvoiceType.sales,
                  );
                  if (_selectedStatus != null) {
                    invoices = invoices
                        .where((invoice) => invoice.status == _selectedStatus)
                        .toList();
                  }
                  invoices = invoices.reversed.toList(growable: false);

                  final totalAmount = invoices.fold<double>(
                    0,
                    (sum, invoice) => sum + invoice.grandTotal,
                  );

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              title: 'Invoices',
                              value: invoices.length.toString(),
                              color: Colors.blue,
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
                            'Recent Sales Invoices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: invoices.isEmpty
                            ? const Center(
                                child: Text(
                                  'No sales invoices found. Use quick actions to create or upload one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: invoices.length,
                                itemBuilder: (context, index) {
                                  final invoice = invoices[index];
                                  return Card(
                                    elevation: 3,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: const Icon(Icons.receipt),
                                      ),
                                      title: Text(
                                        'Invoice #${invoice.invoiceNumber}',
                                      ),
                                      subtitle: Text(
                                        '${invoice.customerName}\n₹ ${invoice.grandTotal.toStringAsFixed(2)}\nPosting: ${_postingStatusLabel(invoice.postingStatus)}',
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
                                              invoice.status.displayName,
                                            ),
                                            backgroundColor: _statusColor(
                                              invoice.status,
                                            ),
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Chip(
                                            label: Text(
                                              _postingStatusLabel(
                                                invoice.postingStatus,
                                              ),
                                            ),
                                            backgroundColor:
                                                _postingStatusColor(
                                                  invoice.postingStatus,
                                                ),
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'view') {
                                                _showInvoiceDetails(invoice);
                                              }
                                              if (value == 'print') {
                                                final setupService = context
                                                    .read<
                                                      BillingPrintSetupService
                                                    >();
                                                final resolution = setupService
                                                    .resolveForInvoice(invoice);
                                                if (resolution == null) {
                                                  await InvoiceDocumentService.printSalesInvoice(
                                                    invoice,
                                                  );
                                                } else {
                                                  await InvoiceDocumentService.printSalesInvoiceWithSetup(
                                                    invoice,
                                                    setupService: setupService,
                                                    resolution: resolution,
                                                  );
                                                }
                                              }
                                              if (value == 'pdf') {
                                                final setupService = context
                                                    .read<
                                                      BillingPrintSetupService
                                                    >();
                                                final resolution = setupService
                                                    .resolveForInvoice(invoice);
                                                if (resolution == null) {
                                                  await InvoiceDocumentService.shareSalesInvoicePdf(
                                                    invoice,
                                                  );
                                                } else {
                                                  await InvoiceDocumentService.shareSalesInvoicePdfWithSetup(
                                                    invoice,
                                                    setupService: setupService,
                                                    resolution: resolution,
                                                  );
                                                }
                                              }
                                              if (value == 'eway') {
                                                _showEwayDraft(invoice);
                                              }
                                              if (value == 'delete') {
                                                _confirmDeleteInvoice(
                                                  invoice.id,
                                                );
                                              }
                                              if (value ==
                                                  'approve_correction') {
                                                _approveCorrection(invoice);
                                              }
                                              if (value ==
                                                  'reject_correction') {
                                                _rejectCorrection(invoice);
                                              }
                                            },
                                            itemBuilder: (context) {
                                              final items =
                                                  <PopupMenuEntry<String>>[
                                                    const PopupMenuItem(
                                                      value: 'view',
                                                      child: Text('View'),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'print',
                                                      child: Text(
                                                        'Print Invoice',
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'pdf',
                                                      child: Text('Share PDF'),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'eway',
                                                      child: Text(
                                                        'E-Way Draft',
                                                      ),
                                                    ),
                                                  ];

                                              if (!widget.readOnlyAuditMode) {
                                                items.add(
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete'),
                                                  ),
                                                );

                                                if (canReviewCorrections &&
                                                    invoice.postingStatus ==
                                                        SalesPostingStatus
                                                            .correctionRequested) {
                                                  items.addAll(const <
                                                    PopupMenuEntry<String>
                                                  >[
                                                    PopupMenuDivider(),
                                                    PopupMenuItem(
                                                      value:
                                                          'approve_correction',
                                                      child: Text(
                                                        'Approve Correction',
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value:
                                                          'reject_correction',
                                                      child: Text(
                                                        'Reject Correction',
                                                      ),
                                                    ),
                                                  ]);
                                                }
                                              }

                                              return items;
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

  Future<void> _ensureIndustrySetup() async {
    final setupState = await _industrySetupService.loadState();
    if (!mounted) return;

    setState(() {
      _selectedIndustryLabel = setupState.selectedIndustryLabel;
      _selectedBillingMethod = setupState.billingMethod;
      _selectedSoftware = setupState.selectedSoftware;
    });

    final productService = context.read<ProductService>();
    final shouldPrompt =
        !setupState.initialized || productService.products.isEmpty;
    if (shouldPrompt) {
      await _showBusinessSetupDialog(forceOpen: true);
    }
  }

  Future<void> _showBusinessSetupDialog({bool forceOpen = false}) async {
    final currentSelection = await _industrySetupService.loadState();
    if (!mounted) return;

    String selectedKey = currentSelection.selectedIndustryKey;
    BillingMethod selectedBillingMethod = currentSelection.billingMethod;
    String selectedSoftware = currentSelection.selectedSoftware;

    if (selectedKey.isEmpty) {
      selectedKey = IndustryMasterPacks.packs.first.key;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !forceOpen,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Welcome to Chirag Accounting'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 1: Select your business type',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownFormField<String>(
                      value: selectedKey,
                      decoration: const InputDecoration(
                        labelText: 'Business Industry',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: IndustryMasterPacks.packs
                          .map((pack) => pack.key)
                          .toList(growable: false),
                      itemLabelBuilder: (key) {
                        final pack = IndustryMasterPacks.packs.firstWhere(
                          (p) => p.key == key,
                        );
                        return pack.label;
                      },
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedKey = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Step 2: Select billing method',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<BillingMethod>(
                      value: BillingMethod.inApp,
                      groupValue: selectedBillingMethod,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Bill inside Chirag Accounting'),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedBillingMethod = value;
                        });
                      },
                    ),
                    RadioListTile<BillingMethod>(
                      value: BillingMethod.manual,
                      groupValue: selectedBillingMethod,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Manual Billing (Paper/Printed/Excel)'),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedBillingMethod = value;
                        });
                      },
                    ),
                    RadioListTile<BillingMethod>(
                      value: BillingMethod.otherSoftware,
                      groupValue: selectedBillingMethod,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Other Software'),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedBillingMethod = value;
                        });
                      },
                    ),
                    if (selectedBillingMethod == BillingMethod.otherSoftware)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SearchableDropdownFormField<String>(
                          value: selectedSoftware.isEmpty
                              ? null
                              : selectedSoftware,
                          decoration: const InputDecoration(
                            labelText: 'Select Software',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _externalSoftwareOptions,
                          itemLabelBuilder: (software) => software,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSoftware = value ?? '';
                            });
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Step 3: Install business template',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This installs Product Categories, Product Master, HSN/SAC, GST, Units, Ledger Groups, Voucher Types, Invoice Design, Reports, and Dashboard Widgets.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!forceOpen)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Install Business Template'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final pack = IndustryMasterPacks.byKey(selectedKey);
    if (pack == null) return;

    if (selectedBillingMethod == BillingMethod.otherSoftware &&
        selectedSoftware.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select software before proceeding.')),
      );
      return;
    }

    final productService = context.read<ProductService>();
    final insertedCount = productService.installIndustryPack(pack);
    await _industrySetupService.saveSelection(
      industryKey: pack.key,
      industryLabel: pack.label,
      billingMethod: selectedBillingMethod,
      selectedSoftware: selectedSoftware,
    );

    if (!mounted) return;
    setState(() {
      _selectedIndustryLabel = pack.label;
      _selectedBillingMethod = selectedBillingMethod;
      _selectedSoftware = selectedSoftware;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          insertedCount > 0
              ? 'Installed ${pack.label} template with $insertedCount products. Billing flow: ${selectedBillingMethod.label}${selectedSoftware.isNotEmpty ? ' ($selectedSoftware)' : ''}.'
              : '${pack.label} template already present. Billing flow saved as ${selectedBillingMethod.label}${selectedSoftware.isNotEmpty ? ' ($selectedSoftware)' : ''}.',
        ),
      ),
    );
  }

  String _billingMethodSubtitle() {
    switch (_selectedBillingMethod) {
      case BillingMethod.inApp:
        return 'Bill inside Chirag Accounting';
      case BillingMethod.manual:
        return 'Upload/scan manual invoice';
      case BillingMethod.otherSoftware:
        return _selectedSoftware.isEmpty
            ? 'Import from external software'
            : 'Import from $_selectedSoftware';
    }
  }

  void _openPreferredBillingFlow() {
    switch (_selectedBillingMethod) {
      case BillingMethod.inApp:
        _openInvoiceEntry(entryMode: SalesEntryMode.standard);
        return;
      case BillingMethod.manual:
        _openInvoiceEntry(entryMode: SalesEntryMode.ocr);
        return;
      case BillingMethod.otherSoftware:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientDataExchangeScreen(initialTabIndex: 0),
          ),
        );
        return;
    }
  }

  void _showInvoiceTypePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: Colors.blue),
              title: const Text('Sales Invoice'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSalesInvoiceScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.orange),
              title: const Text('Tax Invoice'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSalesInvoiceScreen(
                      invoiceType: SalesInvoiceType.tax,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openInvoiceEntry({
    SalesInvoiceType invoiceType = SalesInvoiceType.sales,
    SalesEntryMode entryMode = SalesEntryMode.standard,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSalesInvoiceScreen(
          invoiceType: invoiceType,
          initialEntryMode: entryMode,
        ),
      ),
    );
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _showInvoiceDetails(SalesInvoice invoice) {
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
                'Invoice #${invoice.invoiceNumber}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Customer: ${invoice.customerName}'),
              Text('Date: ${invoice.invoiceDate.toString().split(' ').first}'),
              Text('Due: ${invoice.dueDate.toString().split(' ').first}'),
              Text('Items: ${invoice.items.length}'),
              Text('Total: ₹ ${invoice.grandTotal.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteInvoice(String invoiceId) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Invoice'),
          content: const Text('Are you sure you want to delete this invoice?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                context.read<SalesService>().deleteInvoice(invoiceId);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEwayDraft(SalesInvoice invoice) {
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
              const Text(
                'E-Way Bill Draft Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text('Invoice: ${invoice.invoiceNumber}'),
              Text('Date: ${invoice.invoiceDate.toString().split(' ').first}'),
              Text('Party: ${invoice.customerName}'),
              Text(
                'GSTIN: ${invoice.gstNumber.isEmpty ? '-' : invoice.gstNumber}',
              ),
              Text(
                'Place of Supply: ${invoice.placeOfSupply.isEmpty ? '-' : invoice.placeOfSupply}',
              ),
              Text(
                'Taxable Value: ${invoice.taxableAmount.toStringAsFixed(2)}',
              ),
              Text('Total GST: ${invoice.totalGST.toStringAsFixed(2)}'),
              Text('Invoice Value: ${invoice.grandTotal.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
            ],
          ),
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

  Color _statusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.pending:
        return Colors.orange;
      case InvoiceStatus.cancelled:
        return Colors.red;
      case InvoiceStatus.draft:
        return Colors.blueGrey;
    }
  }

  String _postingStatusLabel(SalesPostingStatus status) {
    switch (status) {
      case SalesPostingStatus.draft:
        return 'Draft';
      case SalesPostingStatus.pendingReview:
        return 'Pending Review';
      case SalesPostingStatus.posted:
        return 'Posted';
      case SalesPostingStatus.locked:
        return 'Locked';
      case SalesPostingStatus.correctionRequested:
        return 'Correction Requested';
      case SalesPostingStatus.correctionRejected:
        return 'Correction Rejected';
      case SalesPostingStatus.corrected:
        return 'Corrected';
    }
  }

  Color _postingStatusColor(SalesPostingStatus status) {
    switch (status) {
      case SalesPostingStatus.draft:
        return Colors.blueGrey;
      case SalesPostingStatus.pendingReview:
        return Colors.orange;
      case SalesPostingStatus.posted:
        return Colors.teal;
      case SalesPostingStatus.locked:
        return Colors.indigo;
      case SalesPostingStatus.correctionRequested:
        return Colors.deepOrange;
      case SalesPostingStatus.correctionRejected:
        return Colors.red;
      case SalesPostingStatus.corrected:
        return Colors.green;
    }
  }

  void _approveCorrection(SalesInvoice invoice) {
    final user = context.read<AuthController>().currentUser;
    context.read<SalesService>().approveInvoiceCorrection(
      invoice.id,
      actorRole: user?.role.name ?? 'accountant',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Correction approved for invoice ${invoice.invoiceNumber}.',
        ),
      ),
    );
  }

  Future<void> _rejectCorrection(SalesInvoice invoice) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Correction'),
          content: TextField(
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejection reason is required.')),
      );
      return;
    }

    final user = context.read<AuthController>().currentUser;
    context.read<SalesService>().rejectInvoiceCorrection(
      invoice.id,
      actorRole: user?.role.name ?? 'accountant',
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Correction rejected for invoice ${invoice.invoiceNumber}.',
        ),
      ),
    );
  }
}
