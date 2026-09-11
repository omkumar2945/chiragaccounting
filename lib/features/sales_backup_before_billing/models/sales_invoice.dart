import 'sales_item.dart';

enum InvoiceStatus { draft, pending, paid, cancelled }

enum SalesInvoiceType { sales, tax }

enum InvoicePaymentStatus { fullyPaid, partiallyPaid, credit }

enum SalesPostingStatus {
  draft,
  pendingReview,
  posted,
  locked,
  correctionRequested,
  correctionRejected,
  corrected,
}

extension SalesInvoiceTypeExtension on SalesInvoiceType {
  String get displayName {
    switch (this) {
      case SalesInvoiceType.sales:
        return 'Sales Invoice';
      case SalesInvoiceType.tax:
        return 'Tax Invoice';
    }
  }
}

extension InvoiceStatusExtension on InvoiceStatus {
  String get displayName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class SalesInvoice {
  final String id;
  final String createdByUserId;
  final bool createdByClient;
  final SalesInvoiceType invoiceType;

  /// Invoice Details
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String sellerName;
  final String sellerAddress;
  final String sellerGstin;
  final String sellerPan;

  /// Customer Details
  final String customerName;
  final String customerMobile;
  final String customerEmail;
  final String gstNumber;
  final String panNumber;

  /// Address
  final String billingAddress;
  final String shippingAddress;
  final String shippingCustomerName;
  final String placeOfSupply;

  /// Items
  final List<SalesItem> items;

  /// Status
  final InvoiceStatus status;
  final SalesPostingStatus postingStatus;

  /// Notes
  final String notes;

  /// Payment workflow
  final InvoicePaymentStatus paymentStatus;
  final double receivedAmount;
  final double outstandingAmount;
  final String paymentMode;
  final String paymentReference;
  final DateTime? paymentDate;

  /// Posting lifecycle
  final DateTime? postedAt;
  final bool lockedAfterPosting;
  final String correctionRequestReason;
  final String correctionRequestedBy;
  final DateTime? correctionRequestedAt;
  final DateTime? correctionResolvedAt;

  /// Supporting attachments saved with the invoice
  final List<String> attachmentPaths;

  // ── Reference Details ──────────────────────────────────────────────────────
  final String paymentTerms;
  final String poNumber;
  final String poDate;
  final String projectName;
  final String referenceNumber;

  // ── Transport / E-Way Bill ──────────────────────────────────────────────────
  final String transportMode; // Road / Rail / Air / Ship
  final String transporterName;
  final String transporterGstin;
  final String transportDocNo;
  final String transportDate;
  final String vehicleNumber;
  final String vehicleType; // Regular / Over Dimensional Cargo
  final String distanceKm;
  final String ewayBillNo;
  final String ewayBillDate;

  // ── E-Invoice (IRP / GST Portal) ───────────────────────────────────────────
  final bool eInvoiceApplicable;
  final String irn;
  final String ackNo;
  final DateTime? ackDate;
  final String qrCodeData;

  // ── Shipping toggle & round-off ─────────────────────────────────────────────
  final bool shipToDifferent;
  final double roundOff;

  const SalesInvoice({
    required this.id,
    this.createdByUserId = '',
    this.createdByClient = false,
    this.invoiceType = SalesInvoiceType.sales,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    this.sellerName = '',
    this.sellerAddress = '',
    this.sellerGstin = '',
    this.sellerPan = '',
    required this.customerName,
    required this.items,
    this.customerMobile = '',
    this.customerEmail = '',
    this.gstNumber = '',
    this.panNumber = '',
    this.billingAddress = '',
    this.shippingAddress = '',
    this.shippingCustomerName = '',
    this.placeOfSupply = '',
    this.status = InvoiceStatus.draft,
    this.postingStatus = SalesPostingStatus.draft,
    this.notes = '',
    this.paymentStatus = InvoicePaymentStatus.credit,
    this.receivedAmount = 0,
    this.outstandingAmount = 0,
    this.paymentMode = '',
    this.paymentReference = '',
    this.paymentDate,
    this.postedAt,
    this.lockedAfterPosting = false,
    this.correctionRequestReason = '',
    this.correctionRequestedBy = '',
    this.correctionRequestedAt,
    this.correctionResolvedAt,
    this.paymentTerms = '',
    this.poNumber = '',
    this.poDate = '',
    this.projectName = '',
    this.referenceNumber = '',
    this.transportMode = '',
    this.transporterName = '',
    this.transporterGstin = '',
    this.transportDocNo = '',
    this.transportDate = '',
    this.vehicleNumber = '',
    this.vehicleType = 'Regular',
    this.distanceKm = '',
    this.ewayBillNo = '',
    this.ewayBillDate = '',
    this.eInvoiceApplicable = false,
    this.irn = '',
    this.ackNo = '',
    this.ackDate,
    this.qrCodeData = '',
    this.shipToDifferent = false,
    this.roundOff = 0,
    this.attachmentPaths = const [],
  });

  /// Total Before GST
  double get taxableAmount {
    return items.fold(0, (sum, item) => sum + item.taxableAmount);
  }

  /// Total GST
  double get totalGST {
    return items.fold(0, (sum, item) => sum + item.gstAmount);
  }

  /// CGST
  double get totalCGST {
    return items.fold(0, (sum, item) => sum + item.cgst);
  }

  /// SGST
  double get totalSGST {
    return items.fold(0, (sum, item) => sum + item.sgst);
  }

  /// IGST
  double get totalIGST {
    return items.fold(0, (sum, item) => sum + item.igst);
  }

  /// Grand Total (before round-off)
  double get grandTotal {
    return taxableAmount + totalGST;
  }

  /// Grand Total adjusted with round-off
  double get adjustedTotal => grandTotal + roundOff;

  SalesInvoice copyWith({
    String? id,
    SalesInvoiceType? invoiceType,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? customerName,
    String? customerMobile,
    String? customerEmail,
    String? gstNumber,
    String? panNumber,
    String? billingAddress,
    String? shippingAddress,
    String? placeOfSupply,
    List<SalesItem>? items,
    InvoiceStatus? status,
    SalesPostingStatus? postingStatus,
    String? notes,
    InvoicePaymentStatus? paymentStatus,
    double? receivedAmount,
    double? outstandingAmount,
    String? paymentMode,
    String? paymentReference,
    DateTime? paymentDate,
    DateTime? postedAt,
    bool? lockedAfterPosting,
    String? correctionRequestReason,
    String? correctionRequestedBy,
    DateTime? correctionRequestedAt,
    DateTime? correctionResolvedAt,
    List<String>? attachmentPaths,
    bool? eInvoiceApplicable,
    String? irn,
    String? ackNo,
    DateTime? ackDate,
    String? qrCodeData,
    bool? shipToDifferent,
    double? roundOff,
  }) {
    return SalesInvoice(
      id: id ?? this.id,
      invoiceType: invoiceType ?? this.invoiceType,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      customerEmail: customerEmail ?? this.customerEmail,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      items: items ?? this.items,
      status: status ?? this.status,
      postingStatus: postingStatus ?? this.postingStatus,
      notes: notes ?? this.notes,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentDate: paymentDate ?? this.paymentDate,
      postedAt: postedAt ?? this.postedAt,
      lockedAfterPosting: lockedAfterPosting ?? this.lockedAfterPosting,
      correctionRequestReason:
          correctionRequestReason ?? this.correctionRequestReason,
      correctionRequestedBy:
          correctionRequestedBy ?? this.correctionRequestedBy,
      correctionRequestedAt:
          correctionRequestedAt ?? this.correctionRequestedAt,
      correctionResolvedAt: correctionResolvedAt ?? this.correctionResolvedAt,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      eInvoiceApplicable: eInvoiceApplicable ?? this.eInvoiceApplicable,
      irn: irn ?? this.irn,
      ackNo: ackNo ?? this.ackNo,
      ackDate: ackDate ?? this.ackDate,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      shipToDifferent: shipToDifferent ?? this.shipToDifferent,
      roundOff: roundOff ?? this.roundOff,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceType': invoiceType.name,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': invoiceDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'customerName': customerName,
      'customerMobile': customerMobile,
      'customerEmail': customerEmail,
      'gstNumber': gstNumber,
      'panNumber': panNumber,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'placeOfSupply': placeOfSupply,
      'status': status.name,
      'postingStatus': postingStatus.name,
      'notes': notes,
      'paymentStatus': paymentStatus.name,
      'receivedAmount': receivedAmount,
      'outstandingAmount': outstandingAmount,
      'paymentMode': paymentMode,
      'paymentReference': paymentReference,
      'paymentDate': paymentDate?.toIso8601String(),
      'postedAt': postedAt?.toIso8601String(),
      'lockedAfterPosting': lockedAfterPosting,
      'correctionRequestReason': correctionRequestReason,
      'correctionRequestedBy': correctionRequestedBy,
      'correctionRequestedAt': correctionRequestedAt?.toIso8601String(),
      'correctionResolvedAt': correctionResolvedAt?.toIso8601String(),
      'attachmentPaths': attachmentPaths,
      'items': items.map((e) => e.toMap()).toList(),
      'eInvoiceApplicable': eInvoiceApplicable,
      'irn': irn,
      'ackNo': ackNo,
      'ackDate': ackDate?.toIso8601String(),
      'qrCodeData': qrCodeData,
      'shipToDifferent': shipToDifferent,
      'roundOff': roundOff,
    };
  }

  factory SalesInvoice.fromMap(Map<String, dynamic> map) {
    return SalesInvoice(
      id: map['id'] ?? '',
      invoiceType: SalesInvoiceType.values.firstWhere(
        (value) => value.name == map['invoiceType'],
        orElse: () => SalesInvoiceType.sales,
      ),
      invoiceNumber: map['invoiceNumber'] ?? '',
      invoiceDate: DateTime.parse(map['invoiceDate']),
      dueDate: DateTime.parse(map['dueDate']),
      customerName: map['customerName'] ?? '',
      customerMobile: map['customerMobile'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      gstNumber: map['gstNumber'] ?? '',
      panNumber: map['panNumber'] ?? '',
      billingAddress: map['billingAddress'] ?? '',
      shippingAddress: map['shippingAddress'] ?? '',
      placeOfSupply: map['placeOfSupply'] ?? '',
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      postingStatus: SalesPostingStatus.values.firstWhere(
        (value) => value.name == map['postingStatus'],
        orElse: () =>
            InvoiceStatus.values.firstWhere(
                  (status) => status.name == map['status'],
                  orElse: () => InvoiceStatus.draft,
                ) ==
                InvoiceStatus.pending
            ? SalesPostingStatus.pendingReview
            : SalesPostingStatus.draft,
      ),
      notes: map['notes'] ?? '',
      paymentStatus: InvoicePaymentStatus.values.firstWhere(
        (value) => value.name == map['paymentStatus'],
        orElse: () => InvoicePaymentStatus.credit,
      ),
      receivedAmount: (map['receivedAmount'] ?? 0).toDouble(),
      outstandingAmount: (map['outstandingAmount'] ?? 0).toDouble(),
      paymentMode: map['paymentMode'] ?? '',
      paymentReference: map['paymentReference'] ?? '',
      paymentDate: map['paymentDate'] == null
          ? null
          : DateTime.tryParse(map['paymentDate'] as String),
      postedAt: map['postedAt'] == null
          ? null
          : DateTime.tryParse(map['postedAt'] as String),
      lockedAfterPosting: map['lockedAfterPosting'] as bool? ?? false,
      correctionRequestReason: map['correctionRequestReason']?.toString() ?? '',
      correctionRequestedBy: map['correctionRequestedBy']?.toString() ?? '',
      correctionRequestedAt: map['correctionRequestedAt'] == null
          ? null
          : DateTime.tryParse(map['correctionRequestedAt'] as String),
      correctionResolvedAt: map['correctionResolvedAt'] == null
          ? null
          : DateTime.tryParse(map['correctionResolvedAt'] as String),
      attachmentPaths: (map['attachmentPaths'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => SalesItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      eInvoiceApplicable: map['eInvoiceApplicable'] as bool? ?? false,
      irn: map['irn']?.toString() ?? '',
      ackNo: map['ackNo']?.toString() ?? '',
      ackDate: map['ackDate'] == null
          ? null
          : DateTime.tryParse(map['ackDate'] as String),
      qrCodeData: map['qrCodeData']?.toString() ?? '',
      shipToDifferent: map['shipToDifferent'] as bool? ?? false,
      roundOff: (map['roundOff'] ?? 0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'SalesInvoice(invoiceNumber: $invoiceNumber, customer: $customerName)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesInvoice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
