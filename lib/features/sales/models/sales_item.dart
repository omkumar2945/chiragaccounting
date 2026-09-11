import 'package:flutter/foundation.dart';

@immutable
class SalesItem {
  final String id;

  /// Product Details
  final String productName;
  final String description;
  final String hsnCode;
  final String unit;
  final bool isCharge;
  final String accountingLedger;
  final Map<String, String> attributes;

  /// Quantity & Price
  final double quantity;
  final double rate;
  final double discount;

  /// GST
  final double gstPercentage;

  const SalesItem({
    required this.id,
    required this.productName,
    this.description = '',
    required this.hsnCode,
    required this.unit,
    this.isCharge = false,
    this.accountingLedger = '',
    this.attributes = const <String, String>{},
    required this.quantity,
    required this.rate,
    this.discount = 0,
    this.gstPercentage = 18,
  });

  /// Before GST
  double get taxableAmount {
    final amount = quantity * rate;
    return amount - discount;
  }

  /// GST Amount
  double get gstAmount {
    return taxableAmount * gstPercentage / 100;
  }

  /// CGST
  double get cgst {
    return gstAmount / 2;
  }

  /// SGST
  double get sgst {
    return gstAmount / 2;
  }

  /// IGST
  double get igst {
    return gstAmount;
  }

  /// Final Amount
  double get totalAmount {
    return taxableAmount + gstAmount;
  }

  SalesItem copyWith({
    String? id,
    String? productName,
    String? description,
    String? hsnCode,
    String? unit,
    bool? isCharge,
    String? accountingLedger,
    Map<String, String>? attributes,
    double? quantity,
    double? rate,
    double? discount,
    double? gstPercentage,
  }) {
    return SalesItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      hsnCode: hsnCode ?? this.hsnCode,
      unit: unit ?? this.unit,
      isCharge: isCharge ?? this.isCharge,
      accountingLedger: accountingLedger ?? this.accountingLedger,
      attributes: attributes ?? this.attributes,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      discount: discount ?? this.discount,
      gstPercentage: gstPercentage ?? this.gstPercentage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productName': productName,
      'description': description,
      'hsnCode': hsnCode,
      'unit': unit,
      'isCharge': isCharge,
      'accountingLedger': accountingLedger,
      if (attributes.isNotEmpty) 'attributes': attributes,
      'quantity': quantity,
      'rate': rate,
      'discount': discount,
      'gstPercentage': gstPercentage,
    };
  }

  factory SalesItem.fromMap(Map<String, dynamic> map) {
    return SalesItem(
      id: map['id'] ?? '',
      productName: map['productName'] ?? '',
      description: map['description'] ?? '',
      hsnCode: map['hsnCode'] ?? '',
      unit: map['unit'] ?? '',
      isCharge: map['isCharge'] as bool? ?? false,
      accountingLedger: map['accountingLedger'] ?? '',
      attributes: map['attributes'] is Map
          ? Map<String, String>.from(map['attributes'] as Map)
          : const <String, String>{},
      quantity: (map['quantity'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      gstPercentage: (map['gstPercentage'] ?? 18).toDouble(),
    );
  }

  @override
  String toString() {
    return 'SalesItem(productName: $productName, quantity: $quantity, rate: $rate)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
