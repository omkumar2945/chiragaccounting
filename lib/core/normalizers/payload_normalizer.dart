import 'package:chirag_accounting/core/normalizers/normalized_dto.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';

class PayloadNormalizer {
  const PayloadNormalizer();

  NormalizedDto normalizeSalesInvoice(SalesInvoice invoice) {
    return NormalizedDto(
      id: invoice.id,
      module: 'sales',
      type: 'sales_invoice',
      status: invoice.status.name,
      amount: invoice.grandTotal,
      partyName: invoice.customerName,
      createdAt: invoice.invoiceDate,
      meta: <String, dynamic>{
        'invoiceNumber': invoice.invoiceNumber,
        'paymentStatus': invoice.paymentStatus.name,
      },
    );
  }

  NormalizedDto normalizePurchaseBill(PurchaseBill bill) {
    return NormalizedDto(
      id: bill.id,
      module: 'purchase',
      type: 'purchase_bill',
      status: bill.paymentStatus.name,
      amount: bill.grandTotal,
      partyName: bill.vendorName,
      createdAt: bill.billDate,
      meta: <String, dynamic>{
        'billNumber': bill.billNumber,
        'entryMode': bill.mode.name,
      },
    );
  }
}
