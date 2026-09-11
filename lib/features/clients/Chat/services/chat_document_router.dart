import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';
import 'package:chirag_accounting/features/clients/services/client_data_exchange_service.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';

enum ChatRouteTarget {
  salesInvoice,
  purchaseBill,
  bankVoucher,
  inventoryImport,
  ledgerImport,
  manualSelection,
}

class ChatRouteSuggestion {
  final ChatRouteTarget target;
  final String title;
  final String subtitle;
  final VoucherType? voucherType;
  final LedgerImportTarget? ledgerImportTarget;

  const ChatRouteSuggestion({
    required this.target,
    required this.title,
    required this.subtitle,
    this.voucherType,
    this.ledgerImportTarget,
  });
}

class ChatDocumentRouter {
  static const double lowConfidenceThreshold = 0.8;

  const ChatDocumentRouter();

  ChatRouteSuggestion suggest({
    required OcrDocumentAnalysis? analysis,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase();
    final ext = _extensionOf(lower);

    if (_isSpreadsheet(ext)) {
      if (_looksLikeInventory(lower)) {
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.inventoryImport,
          title: 'Inventory Import',
          subtitle: 'Spreadsheet looks like stock/item import data.',
        );
      }

      return const ChatRouteSuggestion(
        target: ChatRouteTarget.ledgerImport,
        title: 'Ledger Import',
        subtitle: 'Spreadsheet looks like ledger/statement style data.',
        ledgerImportTarget: LedgerImportTarget.allLedgers,
      );
    }

    final kind = analysis?.kind ?? OcrDocumentKind.unknown;
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.salesInvoice,
          title: 'Sales Invoice Entry',
          subtitle: 'Open Sales Invoice screen with detected values.',
        );
      case OcrDocumentKind.purchaseBill:
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.purchaseBill,
          title: 'Purchase Bill Entry',
          subtitle: 'Open Purchase Bill screen with detected values.',
        );
      case OcrDocumentKind.paymentVoucher:
      case OcrDocumentKind.chequeGiven:
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.bankVoucher,
          title: 'Payment Voucher Entry',
          subtitle: 'Open Banking voucher screen in Payment mode.',
          voucherType: VoucherType.payment,
        );
      case OcrDocumentKind.receiptVoucher:
      case OcrDocumentKind.chequeReceived:
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.bankVoucher,
          title: 'Receipt Voucher Entry',
          subtitle: 'Open Banking voucher screen in Receipt mode.',
          voucherType: VoucherType.receipt,
        );
      case OcrDocumentKind.creditNote:
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.bankVoucher,
          title: 'Credit Note Entry',
          subtitle: 'Open Banking voucher screen in Credit Note mode.',
          voucherType: VoucherType.creditNote,
        );
      case OcrDocumentKind.debitNote:
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.bankVoucher,
          title: 'Debit Note Entry',
          subtitle: 'Open Banking voucher screen in Debit Note mode.',
          voucherType: VoucherType.debitNote,
        );
      case OcrDocumentKind.unknown:
        return const ChatRouteSuggestion(
          target: ChatRouteTarget.manualSelection,
          title: 'Manual Selection Required',
          subtitle: 'Document type is unclear. Choose the destination screen.',
        );
    }
  }

  bool _isSpreadsheet(String extension) {
    return extension == 'csv' ||
        extension == 'xlsx' ||
        extension == 'xls' ||
        extension == 'xlsm' ||
        extension == 'json' ||
        extension == 'txt';
  }

  String _extensionOf(String lowerFileName) {
    final idx = lowerFileName.lastIndexOf('.');
    if (idx <= -1 || idx >= lowerFileName.length - 1) return '';
    return lowerFileName.substring(idx + 1);
  }

  bool _looksLikeInventory(String lowerFileName) {
    return lowerFileName.contains('inventory') ||
        lowerFileName.contains('stock') ||
        lowerFileName.contains('item') ||
        lowerFileName.contains('product');
  }
}