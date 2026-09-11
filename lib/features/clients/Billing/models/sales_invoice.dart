import 'dart:convert';
import 'package:meta/meta.dart';
import 'sales_item.dart';

/// Status of a sales invoice.
enum InvoiceStatus {
  draft('Draft'),
  sent('Sent'),
  paid('Paid'),
  overdue('Overdue'),
  cancelled('Cancelled');

  final String displayName;
  const InvoiceStatus(this.displayName);
}

/// Represents a complete Sales Invoice.
@immutable
class SalesInvoice {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final String? customerEmail;
  final DateTime date;
  final DateTime dueDate;
  final List<SalesItem> items;
  final InvoiceStatus status;
  final double taxRate; // e.g. 0.15 for 15% tax

  const SalesInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    this.customerEmail,
    required this.date,
    required this.dueDate,
    required this.items,
    this.status = InvoiceStatus.draft,
    this.taxRate = 0.0,
  });

  /// Computes the sum of all invoice line item totals.
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);

  /// Computes the tax amount on the subtotal.
  double get taxAmount => subtotal * taxRate;

  /// Computes the final grand total (subtotal + tax amount).
  double get totalAmount => subtotal + taxAmount;

  /// Helper to check if an invoice is overdue based on current system time.
  bool get isOverdue {
    if (status == InvoiceStatus.paid || status == InvoiceStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(dueDate);
  }

  /// Creates a copy of this [SalesInvoice] with the specified fields replaced.
  SalesInvoice copyWith({
    String? id,
    String? invoiceNumber,
    String? customerName,
    String? customerEmail,
    DateTime? date,
    DateTime? dueDate,
    List<SalesItem>? items,
    InvoiceStatus? status,
    double? taxRate,
  }) {
    return SalesInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      status: status ?? this.status,
      taxRate: taxRate ?? this.taxRate,
    );
  }

  /// Converts this [SalesInvoice] to a Map representation.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'date': date.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'status': status.name,
      'taxRate': taxRate,
    };
  }

  /// Creates a [SalesInvoice] from a Map representation.
  factory SalesInvoice.fromMap(Map<String, dynamic> map) {
    return SalesInvoice(
      id: map['id'] as String,
      invoiceNumber: map['invoiceNumber'] as String,
      customerName: map['customerName'] as String,
      customerEmail: map['customerEmail'] as String?,
      date: DateTime.parse(map['date'] as String),
      dueDate: DateTime.parse(map['dueDate'] as String),
      items: (map['items'] as List<dynamic>)
          .map((item) => SalesItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InvoiceStatus.draft,
      ),
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this [SalesInvoice] to a JSON string.
  String toJson() => json.encode(toMap());

  /// Creates a [SalesInvoice] from a JSON string.
  factory SalesInvoice.fromJson(String source) =>
      SalesInvoice.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SalesInvoice(id: $id, invoiceNumber: $invoiceNumber, customerName: $customerName, customerEmail: $customerEmail, date: $date, dueDate: $dueDate, items: $items, status: $status, taxRate: $taxRate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SalesInvoice &&
        other.id == id &&
        other.invoiceNumber == invoiceNumber &&
        other.customerName == customerName &&
        other.customerEmail == customerEmail &&
        other.date == date &&
        other.dueDate == dueDate &&
        _listEquals(other.items, items) &&
        other.status == status &&
        other.taxRate == taxRate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        invoiceNumber.hashCode ^
        customerName.hashCode ^
        customerEmail.hashCode ^
        date.hashCode ^
        dueDate.hashCode ^
        items.hashCode ^
        status.hashCode ^
        taxRate.hashCode;
  }

  // Helper method for deep list equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
