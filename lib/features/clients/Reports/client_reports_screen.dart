import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/clients/Reports/monthly_attachment_zip_service.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

enum _ClientReportId {
  salesRegister,
  purchaseRegister,
  gstSummary,
  outstanding,
  profitAndLoss,
}

class _ClientReportDefinition {
  const _ClientReportDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final _ClientReportId id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ReportRow {
  const _ReportRow({
    required this.id,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.type,
    required this.status,
    required this.date,
    required this.amount,
    this.taxable = 0,
    this.gst = 0,
    this.outstanding = 0,
    this.meta = const <String, String>{},
  });

  final String id;
  final String primaryLabel;
  final String secondaryLabel;
  final String type;
  final String status;
  final DateTime date;
  final double amount;
  final double taxable;
  final double gst;
  final double outstanding;
  final Map<String, String> meta;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'primaryLabel': primaryLabel,
      'secondaryLabel': secondaryLabel,
      'type': type,
      'status': status,
      'date': date.toIso8601String(),
      'amount': amount,
      'taxable': taxable,
      'gst': gst,
      'outstanding': outstanding,
      'meta': meta,
    };
  }
}

class ClientReportsScreen extends StatefulWidget {
  const ClientReportsScreen({super.key});

  @override
  State<ClientReportsScreen> createState() => _ClientReportsScreenState();
}

class _ClientReportsScreenState extends State<ClientReportsScreen> {
  final MonthlyAttachmentZipService _zipService = MonthlyAttachmentZipService();
  final TextEditingController _searchController = TextEditingController();

  DateTime _selectedFrom =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedTo =
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  _ClientReportId _selectedReport = _ClientReportId.salesRegister;
  bool _isExporting = false;

  String _salesStatusFilter = 'All';
  String _purchaseModeFilter = 'All';
  String _outstandingTypeFilter = 'All';
  String _gstNatureFilter = 'All';

  static const List<String> _salesStatusOptions = <String>[
    'All',
    'Draft',
    'Pending',
    'Paid',
    'Cancelled',
  ];

  static const List<String> _purchaseModeOptions = <String>[
    'All',
    'Manual',
    'Upload',
  ];

  static const List<String> _outstandingTypeOptions = <String>[
    'All',
    'Customer',
    'Vendor',
  ];

  static const List<String> _gstNatureOptions = <String>[
    'All',
    'Local',
    'Interstate',
  ];

  static const List<_ClientReportDefinition> _reportDefinitions =
      <_ClientReportDefinition>[
    _ClientReportDefinition(
      id: _ClientReportId.salesRegister,
      title: 'Sales Register',
      subtitle: 'Invoice-wise sales with tax and status',
      icon: Icons.receipt_long_outlined,
    ),
    _ClientReportDefinition(
      id: _ClientReportId.purchaseRegister,
      title: 'Purchase Register',
      subtitle: 'Vendor bills with mode and value',
      icon: Icons.inventory_2_outlined,
    ),
    _ClientReportDefinition(
      id: _ClientReportId.gstSummary,
      title: 'GST Summary',
      subtitle: 'CGST/SGST/IGST view from sales',
      icon: Icons.account_balance_outlined,
    ),
    _ClientReportDefinition(
      id: _ClientReportId.outstanding,
      title: 'Outstanding Report',
      subtitle: 'Pending receivable and payable balances',
      icon: Icons.pending_actions_outlined,
    ),
    _ClientReportDefinition(
      id: _ClientReportId.profitAndLoss,
      title: 'Profit & Loss Snapshot',
      subtitle: 'Net performance for selected period',
      icon: Icons.insights_outlined,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _selectedReportName {
    return _reportDefinitions
            .firstWhere((item) => item.id == _selectedReport)
            .title;
  }

  Future<void> _pickDate({required bool from}) async {
    final initialDate = from ? _selectedFrom : _selectedTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: from ? 'Select start date' : 'Select end date',
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _selectedFrom = picked;
      } else {
        _selectedTo = picked;
      }
    });
  }

  bool _isInRange(DateTime date) {
    return !date.isBefore(_selectedFrom) && !date.isAfter(_selectedTo);
  }

  bool _matchesQuery(String value) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return value.toLowerCase().contains(query);
  }

  String _gstNature(SalesInvoice invoice) {
    return invoice.totalIGST > 0 ? 'Interstate' : 'Local';
  }

  Iterable<SalesInvoice> _clientSales(
    SalesService salesService,
    UserModel? user,
  ) {
    if (user == null) return const <SalesInvoice>[];
    final clientName =
        user.firmName.trim().isNotEmpty ? user.firmName : user.name;
    return salesService.invoices.where((invoice) {
      return invoice.createdByUserId == user.id ||
          (invoice.createdByClient && invoice.createdByUserId.isEmpty) ||
          invoice.sellerName.trim().toLowerCase() == clientName.toLowerCase() ||
          invoice.customerName.trim().toLowerCase() == clientName.toLowerCase();
    });
  }

  Iterable<PurchaseBill> _clientPurchases(
    PurchaseService purchaseService,
    UserModel? user,
  ) {
    if (user == null) return const <PurchaseBill>[];
    final clientName =
        user.firmName.trim().isNotEmpty ? user.firmName : user.name;
    return purchaseService.bills.where((bill) {
      return bill.notes.contains(user.id) ||
          bill.vendorName.trim().toLowerCase() == clientName.toLowerCase();
    });
  }

  List<_ReportRow> _buildSalesRows(SalesService salesService) {
    final user = context.read<AuthController>().currentUser;
    return _clientSales(salesService, user).where((invoice) {
      if (!_isInRange(invoice.invoiceDate)) return false;
      if (_salesStatusFilter != 'All' &&
          invoice.status.displayName != _salesStatusFilter) {
        return false;
      }
      return _matchesQuery(
        '${invoice.invoiceNumber} ${invoice.customerName} ${invoice.gstNumber} ${invoice.status.displayName}',
      );
    }).map((invoice) {
      return _ReportRow(
        id: invoice.id,
        primaryLabel: invoice.invoiceNumber,
        secondaryLabel: invoice.customerName,
        type: 'Sales',
        status: invoice.status.displayName,
        date: invoice.invoiceDate,
        amount: invoice.grandTotal,
        taxable: invoice.taxableAmount,
        gst: invoice.totalGST,
        outstanding: invoice.outstandingAmount,
        meta: <String, String>{
          'GSTIN': invoice.gstNumber.isEmpty ? '-' : invoice.gstNumber,
          'Tax Nature': _gstNature(invoice),
          'Payment': invoice.paymentStatus.name,
        },
      );
    }).toList(growable: false);
  }

  List<_ReportRow> _buildPurchaseRows(PurchaseService purchaseService) {
    final user = context.read<AuthController>().currentUser;
    return _clientPurchases(purchaseService, user).where((bill) {
      if (!_isInRange(bill.billDate)) return false;
      if (_purchaseModeFilter != 'All' &&
          bill.mode.name.toLowerCase() != _purchaseModeFilter.toLowerCase()) {
        return false;
      }
      return _matchesQuery(
        '${bill.billNumber} ${bill.vendorName} ${bill.vendorGstin}',
      );
    }).map((bill) {
      return _ReportRow(
        id: bill.id,
        primaryLabel: bill.billNumber,
        secondaryLabel: bill.vendorName,
        type: 'Purchase',
        status: bill.mode.name,
        date: bill.billDate,
        amount: bill.grandTotal,
        outstanding: bill.outstandingAmount,
        meta: <String, String>{
          'GSTIN': bill.vendorGstin.isEmpty ? '-' : bill.vendorGstin,
          'Payment': bill.paymentStatus.name,
        },
      );
    }).toList(growable: false);
  }

  List<_ReportRow> _buildGstRows(SalesService salesService) {
    final user = context.read<AuthController>().currentUser;
    return _clientSales(salesService, user).where((invoice) {
      if (!_isInRange(invoice.invoiceDate)) return false;
      final nature = _gstNature(invoice);
      if (_gstNatureFilter != 'All' && nature != _gstNatureFilter) {
        return false;
      }
      return _matchesQuery(
        '${invoice.invoiceNumber} ${invoice.customerName} $nature',
      );
    }).map((invoice) {
      return _ReportRow(
        id: invoice.id,
        primaryLabel: invoice.invoiceNumber,
        secondaryLabel: invoice.customerName,
        type: 'GST',
        status: _gstNature(invoice),
        date: invoice.invoiceDate,
        amount: invoice.totalGST,
        taxable: invoice.taxableAmount,
        gst: invoice.totalGST,
        meta: <String, String>{
          'CGST': invoice.totalCGST.toStringAsFixed(2),
          'SGST': invoice.totalSGST.toStringAsFixed(2),
          'IGST': invoice.totalIGST.toStringAsFixed(2),
        },
      );
    }).toList(growable: false);
  }

  List<_ReportRow> _buildOutstandingRows(
    SalesService salesService,
    PurchaseService purchaseService,
  ) {
    final rows = <_ReportRow>[];
    final user = context.read<AuthController>().currentUser;

    if (_outstandingTypeFilter == 'All' ||
        _outstandingTypeFilter == 'Customer') {
      rows.addAll(
        _clientSales(salesService, user).where((invoice) {
          if (!_isInRange(invoice.invoiceDate)) return false;
          if (invoice.outstandingAmount <= 0) return false;
          return _matchesQuery(
            '${invoice.invoiceNumber} ${invoice.customerName}',
          );
        }).map((invoice) {
          return _ReportRow(
            id: invoice.id,
            primaryLabel: invoice.invoiceNumber,
            secondaryLabel: invoice.customerName,
            type: 'Customer Outstanding',
            status: invoice.status.displayName,
            date: invoice.invoiceDate,
            amount: invoice.outstandingAmount,
            outstanding: invoice.outstandingAmount,
            meta: <String, String>{
              'Original Invoice Value': invoice.grandTotal.toStringAsFixed(2),
            },
          );
        }),
      );
    }

    if (_outstandingTypeFilter == 'All' || _outstandingTypeFilter == 'Vendor') {
      rows.addAll(
        _clientPurchases(purchaseService, user).where((bill) {
          if (!_isInRange(bill.billDate)) return false;
          if (bill.outstandingAmount <= 0) return false;
          return _matchesQuery('${bill.billNumber} ${bill.vendorName}');
        }).map((bill) {
          return _ReportRow(
            id: bill.id,
            primaryLabel: bill.billNumber,
            secondaryLabel: bill.vendorName,
            type: 'Vendor Outstanding',
            status: bill.mode.name,
            date: bill.billDate,
            amount: bill.outstandingAmount,
            outstanding: bill.outstandingAmount,
            meta: <String, String>{
              'Original Bill Value': bill.grandTotal.toStringAsFixed(2),
            },
          );
        }),
      );
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  List<_ReportRow> _buildProfitAndLossRows(
    SalesService salesService,
    PurchaseService purchaseService,
  ) {
    final salesRows = _buildSalesRows(salesService);
    final purchaseRows = _buildPurchaseRows(purchaseService);

    final totalSales = salesRows.fold<double>(
      0,
      (sum, row) => sum + row.amount,
    );
    final totalPurchase = purchaseRows.fold<double>(
      0,
      (sum, row) => sum + row.amount,
    );
    final grossProfit = totalSales - totalPurchase;

    final periodDate = DateTime(_selectedFrom.year, _selectedFrom.month, 1);

    return <_ReportRow>[
      _ReportRow(
        id: 'pl_sales',
        primaryLabel: 'Total Sales',
        secondaryLabel: 'Sales register total for selected period',
        type: 'P&L',
        status: 'Income',
        date: periodDate,
        amount: totalSales,
      ),
      _ReportRow(
        id: 'pl_purchase',
        primaryLabel: 'Total Purchase',
        secondaryLabel: 'Purchase register total for selected period',
        type: 'P&L',
        status: 'Expense',
        date: periodDate,
        amount: totalPurchase,
      ),
      _ReportRow(
        id: 'pl_profit',
        primaryLabel: grossProfit >= 0 ? 'Net Profit' : 'Net Loss',
        secondaryLabel: 'Sales minus Purchase',
        type: 'P&L',
        status: grossProfit >= 0 ? 'Profit' : 'Loss',
        date: periodDate,
        amount: grossProfit,
      ),
    ];
  }

  List<_ReportRow> _buildRows() {
    final salesService = context.read<SalesService>();
    final purchaseService = context.read<PurchaseService>();

    switch (_selectedReport) {
      case _ClientReportId.salesRegister:
        return _buildSalesRows(salesService);
      case _ClientReportId.purchaseRegister:
        return _buildPurchaseRows(purchaseService);
      case _ClientReportId.gstSummary:
        return _buildGstRows(salesService);
      case _ClientReportId.outstanding:
        return _buildOutstandingRows(salesService, purchaseService);
      case _ClientReportId.profitAndLoss:
        return _buildProfitAndLossRows(salesService, purchaseService);
    }
  }

  Future<void> _exportMonthlyZip() async {
    setState(() => _isExporting = true);
    try {
      final user = context.read<AuthController>().currentUser;
      final salesInvoices = _clientSales(
        context.read<SalesService>(),
        user,
      ).toList(growable: false);
      final purchaseBills = _clientPurchases(
        context.read<PurchaseService>(),
        user,
      ).toList(growable: false);
      final result = await _zipService.exportMonth(
        month: DateTime(_selectedFrom.year, _selectedFrom.month, 1),
        salesInvoices: salesInvoices,
        purchaseBills: purchaseBills,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.savedPath == null
                ? 'ZIP export cancelled.'
                : 'ZIP saved: ${result.savedPath}',
          ),
          backgroundColor:
              result.savedPath == null ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export ZIP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportSelectedReport({
    required String format,
    required List<_ReportRow> rows,
  }) async {
    setState(() => _isExporting = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safeName = _selectedReportName
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(' ', '_');
      final file = File(
        '${directory.path}/report_${safeName}_$stamp.$format',
      );

      final payload = <String, dynamic>{
        'report': _selectedReportName,
        'periodFrom': DateFormat('yyyy-MM-dd').format(_selectedFrom),
        'periodTo': DateFormat('yyyy-MM-dd').format(_selectedTo),
        'filters': <String, String>{
          'search': _searchController.text.trim(),
          'salesStatus': _salesStatusFilter,
          'purchaseMode': _purchaseModeFilter,
          'outstandingType': _outstandingTypeFilter,
          'gstNature': _gstNatureFilter,
        },
        'rows': rows.map((row) => row.toJson()).toList(growable: false),
      };

      if (format == 'json') {
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload),
          flush: true,
        );
      } else if (format == 'xml') {
        final buffer = StringBuffer();
        buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
        buffer.writeln('<report name="${_xmlEscape(_selectedReportName)}">');
        buffer.writeln(
          '  <period from="${DateFormat('yyyy-MM-dd').format(_selectedFrom)}" to="${DateFormat('yyyy-MM-dd').format(_selectedTo)}" />',
        );
        for (final row in rows) {
          buffer.writeln('  <row>');
          buffer.writeln('    <id>${_xmlEscape(row.id)}</id>');
          buffer.writeln('    <primary>${_xmlEscape(row.primaryLabel)}</primary>');
          buffer.writeln('    <secondary>${_xmlEscape(row.secondaryLabel)}</secondary>');
          buffer.writeln('    <type>${_xmlEscape(row.type)}</type>');
          buffer.writeln('    <status>${_xmlEscape(row.status)}</status>');
          buffer.writeln(
            '    <date>${DateFormat('yyyy-MM-dd').format(row.date)}</date>',
          );
          buffer.writeln('    <amount>${row.amount.toStringAsFixed(2)}</amount>');
          buffer.writeln('    <taxable>${row.taxable.toStringAsFixed(2)}</taxable>');
          buffer.writeln('    <gst>${row.gst.toStringAsFixed(2)}</gst>');
          buffer.writeln(
            '    <outstanding>${row.outstanding.toStringAsFixed(2)}</outstanding>',
          );
          buffer.writeln('  </row>');
        }
        buffer.writeln('</report>');
        await file.writeAsString(buffer.toString(), flush: true);
      } else {
        final csv = StringBuffer();
        csv.writeln(
          'ID,Primary,Secondary,Type,Status,Date,Amount,Taxable,GST,Outstanding',
        );
        for (final row in rows) {
          csv.writeln(
            '${_csv(row.id)},${_csv(row.primaryLabel)},${_csv(row.secondaryLabel)},${_csv(row.type)},${_csv(row.status)},${DateFormat('yyyy-MM-dd').format(row.date)},${row.amount.toStringAsFixed(2)},${row.taxable.toStringAsFixed(2)},${row.gst.toStringAsFixed(2)},${row.outstanding.toStringAsFixed(2)}',
          );
        }

        if (format == 'pdf') {
          await file.writeAsString(
            'PDF output placeholder\n\nReport: $_selectedReportName\n\n${csv.toString()}',
            flush: true,
          );
        } else {
          await file.writeAsString(csv.toString(), flush: true);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${format.toUpperCase()} file: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Widget _reportCatalogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'All Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a report to open it in this same screen.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ..._reportDefinitions.map((report) {
              final selected = report.id == _selectedReport;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedReport = report.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE8F1FF)
                          : const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFD7E0ED),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(report.icon, color: const Color(0xFF0A2E5C)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                report.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReportSpecificFilters() {
    switch (_selectedReport) {
      case _ClientReportId.salesRegister:
        return <Widget>[
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _salesStatusFilter,
              decoration: const InputDecoration(
                labelText: 'Sales Status',
                border: OutlineInputBorder(),
              ),
              items: _salesStatusOptions
                  .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(growable: false),
              onChanged: (value) {
                setState(() => _salesStatusFilter = value ?? 'All');
              },
            ),
          ),
        ];
      case _ClientReportId.purchaseRegister:
        return <Widget>[
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _purchaseModeFilter,
              decoration: const InputDecoration(
                labelText: 'Purchase Mode',
                border: OutlineInputBorder(),
              ),
              items: _purchaseModeOptions
                  .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(growable: false),
              onChanged: (value) {
                setState(() => _purchaseModeFilter = value ?? 'All');
              },
            ),
          ),
        ];
      case _ClientReportId.gstSummary:
        return <Widget>[
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _gstNatureFilter,
              decoration: const InputDecoration(
                labelText: 'GST Nature',
                border: OutlineInputBorder(),
              ),
              items: _gstNatureOptions
                  .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(growable: false),
              onChanged: (value) {
                setState(() => _gstNatureFilter = value ?? 'All');
              },
            ),
          ),
        ];
      case _ClientReportId.outstanding:
        return <Widget>[
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _outstandingTypeFilter,
              decoration: const InputDecoration(
                labelText: 'Outstanding Type',
                border: OutlineInputBorder(),
              ),
              items: _outstandingTypeOptions
                  .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(growable: false),
              onChanged: (value) {
                setState(() => _outstandingTypeFilter = value ?? 'All');
              },
            ),
          ),
        ];
      case _ClientReportId.profitAndLoss:
        return const <Widget>[];
    }
  }

  Widget _reportWorkspaceCard(List<_ReportRow> rows) {
    final totalAmount = rows.fold<double>(0, (sum, row) => sum + row.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _selectedReportName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'This report opens and works in the current screen with filters and exports.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search in selected report',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _pickDate(from: true),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    'From ${DateFormat('dd MMM yyyy').format(_selectedFrom)}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(from: false),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    'To ${DateFormat('dd MMM yyyy').format(_selectedTo)}',
                  ),
                ),
                ..._buildReportSpecificFilters(),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportSelectedReport(format: 'pdf', rows: rows),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
                FilledButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportSelectedReport(format: 'xlsx', rows: rows),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Excel'),
                ),
                FilledButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportSelectedReport(format: 'xml', rows: rows),
                  icon: const Icon(Icons.data_object_outlined),
                  label: const Text('XML'),
                ),
                FilledButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportSelectedReport(format: 'json', rows: rows),
                  icon: const Icon(Icons.code_outlined),
                  label: const Text('JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () => _exportSelectedReport(format: 'csv', rows: rows),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('CSV'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('Rows: ${rows.length}')),
                Chip(label: Text('Amount: Rs ${totalAmount.toStringAsFixed(2)}')),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Report Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('No records found for current filters.'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F1FF),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Color(0xFF0A2E5C)),
                      ),
                    ),
                    title: Text('${row.primaryLabel} • ${row.secondaryLabel}'),
                    subtitle: Text(
                      '${row.type} • ${row.status} • ${DateFormat('dd MMM yyyy').format(row.date)}',
                    ),
                    trailing: Text(
                      'Rs ${row.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2E5C),
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

  @override
  Widget build(BuildContext context) {
    context.watch<SalesService>();
    context.watch<PurchaseService>();
    final rows = _buildRows();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Reports'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Export Monthly ZIP',
            onPressed: _isExporting ? null : _exportMonthlyZip,
            icon: const Icon(Icons.folder_zip_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1024;
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 360, child: _reportCatalogCard()),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _reportWorkspaceCard(rows),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _reportCatalogCard(),
              const SizedBox(height: 12),
              _reportWorkspaceCard(rows),
            ],
          );
        },
      ),
    );
  }
}
