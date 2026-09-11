import 'package:flutter/foundation.dart';

@immutable
class Product {
  final String id;

  /// Product Details
  final String productCode;
  final String barcode;
  final String productName;
  final String category;
  final String description;

  /// Tax Details
  final String hsnCode;
  final double gstPercentage;

  /// Unit
  final String unit;

  /// Pricing
  final double purchaseRate;
  final double salesRate;

  /// Inventory
  final double openingStock;
  final double minimumStock;

  /// Status
  final bool isActive;

  const Product({
    required this.id,
    required this.productCode,
    this.barcode = '',
    required this.productName,
    this.category = '',
    this.description = '',
    this.hsnCode = '',
    this.gstPercentage = 18,
    this.unit = 'Nos',
    this.purchaseRate = 0,
    this.salesRate = 0,
    this.openingStock = 0,
    this.minimumStock = 0,
    this.isActive = true,
  });

  Product copyWith({
    String? id,
    String? productCode,
    String? barcode,
    String? productName,
    String? category,
    String? description,
    String? hsnCode,
    double? gstPercentage,
    String? unit,
    double? purchaseRate,
    double? salesRate,
    double? openingStock,
    double? minimumStock,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      description: description ?? this.description,
      hsnCode: hsnCode ?? this.hsnCode,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      unit: unit ?? this.unit,
      purchaseRate: purchaseRate ?? this.purchaseRate,
      salesRate: salesRate ?? this.salesRate,
      openingStock: openingStock ?? this.openingStock,
      minimumStock: minimumStock ?? this.minimumStock,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productCode': productCode,
      'barcode': barcode,
      'productName': productName,
      'category': category,
      'description': description,
      'hsnCode': hsnCode,
      'gstPercentage': gstPercentage,
      'unit': unit,
      'purchaseRate': purchaseRate,
      'salesRate': salesRate,
      'openingStock': openingStock,
      'minimumStock': minimumStock,
      'isActive': isActive,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      productCode: map['productCode'] ?? '',
      barcode: map['barcode'] ?? '',
      productName: map['productName'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      hsnCode: map['hsnCode'] ?? '',
      gstPercentage: (map['gstPercentage'] ?? 18).toDouble(),
      unit: map['unit'] ?? 'Nos',
      purchaseRate: (map['purchaseRate'] ?? 0).toDouble(),
      salesRate: (map['salesRate'] ?? 0).toDouble(),
      openingStock: (map['openingStock'] ?? 0).toDouble(),
      minimumStock: (map['minimumStock'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
