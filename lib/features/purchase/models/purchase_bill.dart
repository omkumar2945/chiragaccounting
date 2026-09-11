import 'purchase_item.dart';

import 'package:chirag_accounting/core/location/standard_address.dart';

enum PurchaseEntryMode { manual, upload }

enum PurchasePaymentStatus { fullyPaid, partiallyPaid, credit }

class PurchaseBill {
  final String id;
  final String billNumber;
  final DateTime billDate;
  final String vendorName;
  final String vendorGstin;
  final String vendorAddress;
  final StandardAddress? vendorLocation;
  final PurchaseEntryMode mode;
  final List<PurchaseItem> items;
  final String notes;
  final List<String> attachmentPaths;
  final PurchasePaymentStatus paymentStatus;
  final double paidAmount;
  final double outstandingAmount;
  final String paymentMode;
  final String paymentReference;
  final DateTime? paymentDate;

  const PurchaseBill({
    required this.id,
    required this.billNumber,
    required this.billDate,
    required this.vendorName,
    this.vendorGstin = '',
    this.vendorAddress = '',
    this.vendorLocation,
    required this.mode,
    required this.items,
    this.notes = '',
    this.attachmentPaths = const [],
    this.paymentStatus = PurchasePaymentStatus.credit,
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.paymentMode = '',
    this.paymentReference = '',
    this.paymentDate,
  });

  double get grandTotal => items.fold(0, (sum, item) => sum + item.lineTotal);
}
