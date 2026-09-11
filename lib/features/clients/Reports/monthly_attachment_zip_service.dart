import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';

class MonthlyAttachmentZipResult {
  final int salesFileCount;
  final int purchaseFileCount;
  final int registerEntryCount;
  final String? savedPath;

  const MonthlyAttachmentZipResult({
    required this.salesFileCount,
    required this.purchaseFileCount,
    required this.registerEntryCount,
    this.savedPath,
  });
}

class MonthlyAttachmentZipService {
  Future<MonthlyAttachmentZipResult> exportMonth({
    required DateTime month,
    required List<SalesInvoice> salesInvoices,
    required List<PurchaseBill> purchaseBills,
  }) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    final monthLabel = DateFormat('yyyy_MM').format(monthStart);

    final archive = Archive();
    var salesFileCount = 0;
    var purchaseFileCount = 0;

    final registerLines = <String>[
      'Monthly Register - $monthLabel',
      '',
      'Sales Invoices',
    ];

    for (final invoice in salesInvoices.where((item) =>
        !item.invoiceDate.isBefore(monthStart) && !item.invoiceDate.isAfter(monthEnd))) {
      registerLines.add(
        '${invoice.invoiceNumber} | ${invoice.customerName} | ${DateFormat('yyyy-MM-dd').format(invoice.invoiceDate)} | Rs. ${invoice.grandTotal.toStringAsFixed(2)}',
      );

      for (final path in invoice.attachmentPaths) {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile('sales/${invoice.invoiceNumber}/${file.uri.pathSegments.last}', bytes.length, bytes),
        );
        salesFileCount++;
      }
    }

    registerLines
      ..add('')
      ..add('Purchase Bills');

    for (final bill in purchaseBills.where((item) =>
        !item.billDate.isBefore(monthStart) && !item.billDate.isAfter(monthEnd))) {
      registerLines.add(
        '${bill.billNumber} | ${bill.vendorName} | ${DateFormat('yyyy-MM-dd').format(bill.billDate)} | Rs. ${bill.grandTotal.toStringAsFixed(2)}',
      );

      for (final path in bill.attachmentPaths) {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile('purchase/${bill.billNumber}/${file.uri.pathSegments.last}', bytes.length, bytes),
        );
        purchaseFileCount++;
      }
    }

    final registerBytes = registerLines.join('\n').codeUnits;
    archive.addFile(
      ArchiveFile('register/monthly_register_$monthLabel.txt', registerBytes.length, registerBytes),
    );

    final encoder = ZipEncoder();
    final zipBytes = encoder.encode(archive);

    final homeDir = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final downloadsDir = Directory('$homeDir${Platform.pathSeparator}Downloads');
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }

    final savePath = '${downloadsDir.path}${Platform.pathSeparator}sales_purchase_register_$monthLabel.zip';
    await File(savePath).writeAsBytes(zipBytes, flush: true);

    return MonthlyAttachmentZipResult(
      salesFileCount: salesFileCount,
      purchaseFileCount: purchaseFileCount,
      registerEntryCount: salesInvoices.length + purchaseBills.length,
      savedPath: savePath,
    );
  }
}