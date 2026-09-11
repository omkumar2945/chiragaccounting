import 'dart:ui';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:chirag_accounting/features/billing_print_setup/models/billing_print_setup_models.dart';
import 'package:chirag_accounting/features/billing_print_setup/services/billing_print_setup_service.dart';
import '../sales/models/sales_invoice.dart';

class InvoiceDocumentService {
  static Future<Uint8List> buildSalesInvoicePdf(SalesInvoice invoice) async {
    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final headingFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final dateFmt = DateFormat('dd-MM-yyyy');

    double y = 20;

    graphics.drawString('TAX INVOICE', titleFont, bounds: const Rect.fromLTWH(0, 0, 500, 24));
    y += 28;

    graphics.drawString('Invoice No: ${invoice.invoiceNumber}', bodyFont, bounds: Rect.fromLTWH(0, y, 250, 16));
    graphics.drawString('Invoice Date: ${dateFmt.format(invoice.invoiceDate)}', bodyFont, bounds: Rect.fromLTWH(260, y, 250, 16));
    y += 16;
    graphics.drawString('Due Date: ${dateFmt.format(invoice.dueDate)}', bodyFont, bounds: Rect.fromLTWH(260, y, 250, 16));
    y += 24;

    graphics.drawString('Customer Details', headingFont, bounds: Rect.fromLTWH(0, y, 250, 16));
    y += 16;
    graphics.drawString(invoice.customerName, bodyFont, bounds: Rect.fromLTWH(0, y, 500, 16));
    y += 14;
    if (invoice.customerMobile.isNotEmpty) {
      graphics.drawString('Mobile: ${invoice.customerMobile}', bodyFont, bounds: Rect.fromLTWH(0, y, 250, 16));
      y += 14;
    }
    if (invoice.gstNumber.isNotEmpty) {
      graphics.drawString('GSTIN: ${invoice.gstNumber}', bodyFont, bounds: Rect.fromLTWH(0, y, 250, 16));
      y += 14;
    }
    if (invoice.billingAddress.isNotEmpty) {
      graphics.drawString('Address: ${invoice.billingAddress}', bodyFont, bounds: Rect.fromLTWH(0, y, 500, 28));
      y += 24;
    }

    y += 8;
    graphics.drawLine(PdfPen(PdfColor(200, 200, 200)), Offset(0, y), Offset(520, y));
    y += 8;

    graphics.drawString('Item', headingFont, bounds: Rect.fromLTWH(0, y, 170, 16));
    graphics.drawString('HSN', headingFont, bounds: Rect.fromLTWH(172, y, 60, 16));
    graphics.drawString('Qty', headingFont, bounds: Rect.fromLTWH(236, y, 40, 16));
    graphics.drawString('Rate', headingFont, bounds: Rect.fromLTWH(280, y, 70, 16));
    graphics.drawString('GST%', headingFont, bounds: Rect.fromLTWH(355, y, 40, 16));
    graphics.drawString('Amount', headingFont, bounds: Rect.fromLTWH(400, y, 110, 16));
    y += 16;

    graphics.drawLine(PdfPen(PdfColor(220, 220, 220)), Offset(0, y), Offset(520, y));
    y += 6;

    for (final item in invoice.items) {
      final rowAmount = item.totalAmount;
      graphics.drawString(item.productName, bodyFont, bounds: Rect.fromLTWH(0, y, 170, 24));
      graphics.drawString(item.hsnCode, bodyFont, bounds: Rect.fromLTWH(172, y, 60, 24));
      graphics.drawString(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), bodyFont, bounds: Rect.fromLTWH(236, y, 40, 24));
      graphics.drawString(item.rate.toStringAsFixed(2), bodyFont, bounds: Rect.fromLTWH(280, y, 70, 24));
      graphics.drawString(item.gstPercentage.toStringAsFixed(2), bodyFont, bounds: Rect.fromLTWH(355, y, 40, 24));
      graphics.drawString(currency.format(rowAmount), bodyFont, bounds: Rect.fromLTWH(400, y, 110, 24));
      y += 22;

      if (y > 730) {
        final newPage = document.pages.add();
        y = 20;
        newPage.graphics.drawString('TAX INVOICE (cont.)', headingFont, bounds: Rect.fromLTWH(0, y, 250, 16));
        y += 20;
      }
    }

    y += 8;
    graphics.drawLine(PdfPen(PdfColor(220, 220, 220)), Offset(0, y), Offset(520, y));
    y += 10;

    graphics.drawString('Taxable Amount: ${currency.format(invoice.taxableAmount)}', bodyFont, bounds: Rect.fromLTWH(300, y, 220, 16));
    y += 14;
    graphics.drawString('Total GST: ${currency.format(invoice.totalGST)}', bodyFont, bounds: Rect.fromLTWH(300, y, 220, 16));
    y += 14;
    graphics.drawString('Grand Total: ${currency.format(invoice.grandTotal)}', headingFont, bounds: Rect.fromLTWH(300, y, 220, 18));
    y += 20;

    if (invoice.notes.isNotEmpty) {
      graphics.drawString('Notes: ${invoice.notes}', bodyFont, bounds: Rect.fromLTWH(0, y, 520, 40));
      y += 28;
    }

    graphics.drawString(
      'E-Way Draft: Party=${invoice.customerName}, GSTIN=${invoice.gstNumber}, Invoice=${invoice.invoiceNumber}, Date=${dateFmt.format(invoice.invoiceDate)}, Value=${invoice.grandTotal.toStringAsFixed(2)}',
      PdfStandardFont(PdfFontFamily.helvetica, 8),
      bounds: Rect.fromLTWH(0, y, 520, 32),
    );

    final bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<void> printSalesInvoice(SalesInvoice invoice) async {
    final bytes = await buildSalesInvoicePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Sales-Invoice-${invoice.invoiceNumber}',
    );
  }

  static Future<void> shareSalesInvoicePdf(SalesInvoice invoice) async {
    final bytes = await buildSalesInvoicePdf(invoice);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Sales-Invoice-${invoice.invoiceNumber}.pdf',
    );
  }

  static Future<void> printSalesInvoiceWithSetup(
    SalesInvoice invoice, {
    required BillingPrintSetupService setupService,
    required InvoicePrintResolution resolution,
  }) async {
    final bytes = await setupService.renderInvoicePdf(
      invoice,
      resolution: resolution,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Sales-Invoice-${invoice.invoiceNumber}',
    );
  }

  static Future<void> shareSalesInvoicePdfWithSetup(
    SalesInvoice invoice, {
    required BillingPrintSetupService setupService,
    required InvoicePrintResolution resolution,
  }) async {
    final bytes = await setupService.renderInvoicePdf(
      invoice,
      resolution: resolution,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Sales-Invoice-${invoice.invoiceNumber}.pdf',
    );
  }
}
