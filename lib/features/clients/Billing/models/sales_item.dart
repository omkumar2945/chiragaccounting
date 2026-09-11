import 'dart:convert';

/// Represents a line item inside a sales invoice.
class SalesItem {
  final String id;
  final String name;
  final double unitPrice;
  final int quantity;
  final double discount;

  const SalesItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0.0,
  });

  /// Computes the subtotal of the item (unit price * quantity) before any discount.
  double get subtotal => unitPrice * quantity;

  /// Computes the total price of the item after applying the discount.
  double get total => subtotal - discount;

  /// Creates a copy of this [SalesItem] but with the given fields replaced with new values.
  SalesItem copyWith({
    String? id,
    String? name,
    double? unitPrice,
    int? quantity,
    double? discount,
  }) {
    return SalesItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
    );
  }

  /// Converts this [SalesItem] into a Map representation.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'discount': discount,
    };
  }

  /// Creates a [SalesItem] from a Map representation.
  factory SalesItem.fromMap(Map<String, dynamic> map) {
    return SalesItem(
      id: map['id'] as String,
      name: map['name'] as String,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this [SalesItem] to a JSON string.
  String toJson() => json.encode(toMap());

  /// Creates a [SalesItem] from a JSON string.
  factory SalesItem.fromJson(String source) =>
      SalesItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SalesItem(id: $id, name: $name, unitPrice: $unitPrice, quantity: $quantity, discount: $discount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SalesItem &&
        other.id == id &&
        other.name == name &&
        other.unitPrice == unitPrice &&
        other.quantity == quantity &&
        other.discount == discount;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        unitPrice.hashCode ^
        quantity.hashCode ^
        discount.hashCode;
  }
}
