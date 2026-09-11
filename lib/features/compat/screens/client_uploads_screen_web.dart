import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:chirag_accounting/core/constants/feature_flags.dart';
import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';
import 'package:chirag_accounting/features/clients/DataExchange/client_data_exchange_screen.dart';
import 'package:chirag_accounting/features/purchase/presentation/pages/add_purchase_bill_screen.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/add_sales_invoice_screen.dart';

class ClientUploadsScreen extends StatefulWidget {
  final bool autoPickOnOpen;
  final bool autoRouteAfterDetect;
  final String autoRouteSource;
  final String? initialFilePath;
  final Uint8List? initialFileBytes;
  final String? initialFileName;

  const ClientUploadsScreen({
    super.key,
    this.autoPickOnOpen = false,
    this.autoRouteAfterDetect = false,
    this.autoRouteSource = 'manual',
    this.initialFilePath,
    this.initialFileBytes,
    this.initialFileName,
  });

  @override
  State<ClientUploadsScreen> createState() => _ClientUploadsScreenState();
}

class _ClientUploadsScreenState extends State<ClientUploadsScreen> {
  String get _sourceName {
    final name = widget.initialFileName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final path = widget.initialFilePath?.trim() ?? '';
    if (path.isNotEmpty) {
      final segments = path.split(RegExp(r'[\\/]'));
      if (segments.isNotEmpty && segments.last.trim().isNotEmpty) {
        return segments.last.trim();
      }
    }
    return 'Selected attachment';
  }

  bool get _isPdf => _sourceName.toLowerCase().endsWith('.pdf');

  bool get _isSpreadsheet {
    final lower = _sourceName.toLowerCase();
    return lower.endsWith('.csv') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.xlsm') ||
        lower.endsWith('.json') ||
        lower.endsWith('.txt');
  }

  void _openSalesEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddSalesInvoiceScreen(autoEntryMode: true),
      ),
    );
  }

  void _openPurchaseEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddPurchaseBillScreen(autoEntryMode: true),
      ),
    );
  }

  void _openBankEntry(VoucherType voucherType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientBankScreen(initialVoucherType: voucherType),
      ),
    );
  }

  void _openInventoryImport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDataExchangeScreen(
          initialTabIndex: 0,
          initialInventoryFilePath: widget.initialFilePath,
          initialInventoryFileBytes: widget.initialFileBytes,
          initialInventorySourceName: _sourceName,
        ),
      ),
    );
  }

  void _openLedgerImport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDataExchangeScreen(
          initialTabIndex: 1,
          initialLedgerFilePath: widget.initialFilePath,
          initialLedgerFileBytes: widget.initialFileBytes,
          initialLedgerSourceName: _sourceName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPreviewBytes =
        widget.initialFileBytes != null && widget.initialFileBytes!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Client Uploads')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD8E2F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPdf
                          ? Icons.picture_as_pdf_outlined
                          : _isSpreadsheet
                          ? Icons.table_chart_outlined
                          : Icons.image_outlined,
                      color: Colors.blueGrey.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _sourceName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hasPreviewBytes
                      ? 'Attachment was received in the browser. OCR auto-detection is not available on web yet, but you can review the file and continue with the correct manual entry screen.'
                      : 'This upload was opened in the browser. OCR auto-detection is not available on web yet, but you can continue with the correct manual entry screen.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          if (hasPreviewBytes && !_isPdf) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final previewHeight =
                      (constraints.maxWidth * 0.55).clamp(180.0, 360.0);
                  return Image.memory(
                    widget.initialFileBytes!,
                    height: previewHeight,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Continue In',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _openSalesEntry,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('Sales Invoice'),
              ),
              FilledButton.icon(
                onPressed: _openPurchaseEntry,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Purchase Bill'),
              ),
              FilledButton.icon(
                onPressed: _openInventoryImport,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Inventory Import'),
              ),
              FilledButton.icon(
                onPressed: _openLedgerImport,
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Ledger Import'),
              ),
              FilledButton.icon(
                onPressed: FeatureFlags.bankingEnabled
                    ? () => _openBankEntry(VoucherType.payment)
                    : null,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Payment Voucher'),
              ),
              FilledButton.icon(
                onPressed: FeatureFlags.bankingEnabled
                    ? () => _openBankEntry(VoucherType.receipt)
                    : null,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Receipt Voucher'),
              ),
              FilledButton.icon(
                onPressed: FeatureFlags.bankingEnabled
                    ? () => _openBankEntry(VoucherType.creditNote)
                    : null,
                icon: const Icon(Icons.assignment_return_outlined),
                label: const Text('Credit Note'),
              ),
              FilledButton.icon(
                onPressed: FeatureFlags.bankingEnabled
                    ? () => _openBankEntry(VoucherType.debitNote)
                    : null,
                icon: const Icon(Icons.assignment_late_outlined),
                label: const Text('Debit Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
