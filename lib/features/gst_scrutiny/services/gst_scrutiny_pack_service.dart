import 'dart:io';

import 'package:chirag_accounting/core/integrations/integration_hub_service.dart';
import 'package:chirag_accounting/features/gst_scrutiny/services/gst_scrutiny_service.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';

class GstScrutinyPackResult {
  const GstScrutinyPackResult({
    required this.savedPath,
    required this.summary,
  });

  final String savedPath;
  final String summary;
}

class GstScrutinyPackService {
  const GstScrutinyPackService();

  Future<GstScrutinyPackResult> export({
    required GstScrutinyCase scrutinyCase,
    required String clientName,
    required DateTime from,
    required DateTime to,
    required Set<String> voucherTypes,
    required List<SalesInvoice> salesInvoices,
    required List<PurchaseBill> purchaseBills,
  }) async {
    final selectedSales = salesInvoices.where((invoice) {
      final d = invoice.invoiceDate;
      return voucherTypes.contains('sales') && !d.isBefore(from) && !d.isAfter(to);
    }).toList(growable: false);

    final selectedPurchases = purchaseBills.where((bill) {
      final d = bill.billDate;
      return voucherTypes.contains('purchase') && !d.isBefore(from) && !d.isAfter(to);
    }).toList(growable: false);

    final folder = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}chirag_scrutiny_packs');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }

    final file = File('${folder.path}${Platform.pathSeparator}${scrutinyCase.noticeNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_pack.txt');

    final content = StringBuffer()
      ..writeln('Client: $clientName')
      ..writeln('Notice: ${scrutinyCase.noticeNumber}')
      ..writeln('Section: ${scrutinyCase.section}')
      ..writeln('Tax Period: ${scrutinyCase.taxPeriod}')
      ..writeln('Range: ${from.toIso8601String()} to ${to.toIso8601String()}')
      ..writeln()
      ..writeln('Sales vouchers (${selectedSales.length})');

    for (final invoice in selectedSales) {
      content.writeln(
        '- ${invoice.invoiceNumber} | ${invoice.customerName} | ${invoice.grandTotal.toStringAsFixed(2)}',
      );
    }

    content
      ..writeln()
      ..writeln('Purchase vouchers (${selectedPurchases.length})');

    for (final bill in selectedPurchases) {
      content.writeln(
        '- ${bill.billNumber} | ${bill.vendorName} | ${bill.grandTotal.toStringAsFixed(2)}',
      );
    }

    content
      ..writeln()
      ..writeln('Reply Draft')
      ..writeln(scrutinyCase.reply.body);

    await file.writeAsString(content.toString());

    return GstScrutinyPackResult(
      savedPath: file.path,
      summary: 'Sales: ${selectedSales.length}, Purchase: ${selectedPurchases.length}',
    );
  }

  Future<void> email({
    required IntegrationHubService integrationHub,
    required GstScrutinyCase scrutinyCase,
    required GstScrutinyPackResult pack,
  }) async {
    final recipient = scrutinyCase.officerEmail.trim();
    if (recipient.isEmpty) {
      throw Exception('Officer email is missing for this case.');
    }

    await integrationHub.execute(
      adapterId: 'email',
      action: 'send',
      payload: <String, dynamic>{
        'to': recipient,
        'subject': 'Reply: ${scrutinyCase.noticeNumber}',
        'body': scrutinyCase.reply.body,
        'attachmentPath': pack.savedPath,
      },
    );
  }
}
