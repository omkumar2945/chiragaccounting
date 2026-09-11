import 'package:flutter/foundation.dart';

import 'industry_master_pack.dart';
import 'models/product.dart';

class InventoryUnitConversionRule {
  final String fromUnit;
  final double multiplierToBase;

  const InventoryUnitConversionRule({
    required this.fromUnit,
    required this.multiplierToBase,
  });
}

class InventoryUnitGroup {
  final String groupName;
  final String baseUnit;
  final List<String> productIds;
  final List<InventoryUnitConversionRule> conversionRules;

  const InventoryUnitGroup({
    required this.groupName,
    required this.baseUnit,
    this.productIds = const [],
    this.conversionRules = const [],
  });

  InventoryUnitGroup copyWith({
    String? groupName,
    String? baseUnit,
    List<String>? productIds,
    List<InventoryUnitConversionRule>? conversionRules,
  }) {
    return InventoryUnitGroup(
      groupName: groupName ?? this.groupName,
      baseUnit: baseUnit ?? this.baseUnit,
      productIds: productIds ?? this.productIds,
      conversionRules: conversionRules ?? this.conversionRules,
    );
  }
}

class ProductService extends ChangeNotifier {
  final List<Product> _products = [];
  final List<String> _categories = [];
  final Map<String, InventoryUnitGroup> _unitGroups = {};
  final Map<String, String> _productToGroup = {};

  String _normalizeValue(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  List<Product> get products => List.unmodifiable(_products);

  List<InventoryUnitGroup> get unitGroups =>
      List.unmodifiable(_unitGroups.values.toList(growable: false));

  int get totalProducts => _products.length;

  Product upsertImportedProduct({
    required String productName,
    String hsnCode = '',
    String unit = 'Nos',
    String category = 'Imported',
    double purchaseRate = 0,
    double salesRate = 0,
    double openingStock = 0,
    double gstPercentage = 18,
    String? preferredCode,
  }) {
    final normalizedName = _normalizeValue(productName);
    final normalizedHsn = _normalizeValue(hsnCode);

    Product? existing;
    if (normalizedName.isNotEmpty && normalizedHsn.isNotEmpty) {
      existing = _products.where((p) {
        return _normalizeValue(p.productName) == normalizedName &&
            _normalizeValue(p.hsnCode) == normalizedHsn;
      }).cast<Product?>().firstOrNull;
    }
    existing ??= _products.where((p) {
      return _normalizeValue(p.productName) == normalizedName;
    }).cast<Product?>().firstOrNull;

    if (existing != null) {
      final updated = existing.copyWith(
        hsnCode: hsnCode.trim().isEmpty ? existing.hsnCode : hsnCode.trim(),
        unit: unit.trim().isEmpty ? existing.unit : unit.trim(),
        category: category.trim().isEmpty ? existing.category : category.trim(),
        purchaseRate: purchaseRate > 0 ? purchaseRate : existing.purchaseRate,
        salesRate: salesRate > 0 ? salesRate : existing.salesRate,
        openingStock: openingStock > 0
            ? existing.openingStock + openingStock
            : existing.openingStock,
        gstPercentage: gstPercentage > 0 ? gstPercentage : existing.gstPercentage,
      );
      updateProduct(existing.id, updated);
      return updated;
    }

    String nextCode() {
      if (preferredCode != null && preferredCode.trim().isNotEmpty) {
        final candidate = preferredCode.trim();
        if (!isProductCodeExists(candidate)) return candidate;
      }

      var max = 0;
      final regex = RegExp(r'^IMP-(\d+)$');
      for (final p in _products) {
        final match = regex.firstMatch(p.productCode.trim());
        if (match == null) continue;
        final value = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (value > max) max = value;
      }
      return 'IMP-${(max + 1).toString().padLeft(4, '0')}';
    }

    final created = Product(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      productCode: nextCode(),
      productName: productName.trim(),
      category: category.trim().isEmpty ? 'Imported' : category.trim(),
      description: 'Imported from existing software/supplier',
      hsnCode: hsnCode.trim(),
      gstPercentage: gstPercentage > 0 ? gstPercentage : 18,
      unit: unit.trim().isEmpty ? 'Nos' : unit.trim(),
      purchaseRate: purchaseRate,
      salesRate: salesRate,
      openingStock: openingStock,
      minimumStock: 0,
      isActive: true,
    );
    addProduct(created);
    return created;
  }

  void configureUnitGroup({
    required String groupName,
    required String baseUnit,
    required List<String> productIds,
    List<InventoryUnitConversionRule> conversionRules = const [],
  }) {
    final key = groupName.trim().toLowerCase();
    if (key.isEmpty || baseUnit.trim().isEmpty || productIds.isEmpty) {
      return;
    }

    final existing = _unitGroups[key];
    final mergedProductIds = {
      ...?existing?.productIds,
      ...productIds,
    }.toList(growable: false);

    final mergedRules = <String, InventoryUnitConversionRule>{
      for (final rule in existing?.conversionRules ?? const <InventoryUnitConversionRule>[]) rule.fromUnit.toLowerCase(): rule,
      for (final rule in conversionRules) rule.fromUnit.toLowerCase(): rule,
    };

    _unitGroups[key] = InventoryUnitGroup(
      groupName: groupName.trim(),
      baseUnit: baseUnit.trim(),
      productIds: mergedProductIds,
      conversionRules: mergedRules.values.toList(growable: false),
    );

    for (final productId in mergedProductIds) {
      _productToGroup[productId] = key;
    }
    notifyListeners();
  }

  InventoryUnitGroup? groupForProduct(String productId) {
    final key = _productToGroup[productId];
    if (key == null) return null;
    return _unitGroups[key];
  }

  double? convertToBaseUnit(String productId, double quantity, String unit) {
    final group = groupForProduct(productId);
    if (group == null) return null;

    final normalizedUnit = unit.trim().toLowerCase();
    if (normalizedUnit == group.baseUnit.trim().toLowerCase()) {
      return quantity;
    }

    final rule = group.conversionRules.where((r) {
      return r.fromUnit.trim().toLowerCase() == normalizedUnit;
    }).cast<InventoryUnitConversionRule?>().firstOrNull;

    if (rule == null || rule.multiplierToBase <= 0) return null;
    return quantity * rule.multiplierToBase;
  }

  // ── Category management ──────────────────────────────────────────────────

  /// All categories: union of custom categories + those found in products.
  List<String> get allCategories {
    final fromProducts =
        _products.map((p) => p.category).where((c) => c.isNotEmpty).toSet();
    final merged = {..._categories, ...fromProducts}.toList();
    merged.sort();
    return merged;
  }

  void addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _categories.contains(trimmed)) return;
    _categories.add(trimmed);
    notifyListeners();
  }

  void deleteCategory(String name) {
    _categories.remove(name);
    notifyListeners();
  }

  void addProduct(Product product) {
    final validationError = validateProductForSave(product);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    _products.add(product);
    notifyListeners();
  }

  void updateProduct(String productId, Product updatedProduct) {
    final validationError = validateProductForSave(
      updatedProduct,
      productId,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final index = _products.indexWhere(
      (product) => product.id == productId,
    );

    if (index != -1) {
      _products[index] = updatedProduct;
      notifyListeners();
    }
  }

  void deleteProduct(String productId) {
    _products.removeWhere(
      (product) => product.id == productId,
    );

    notifyListeners();
  }

  Product? getProductById(String productId) {
    try {
      return _products.firstWhere(
        (product) => product.id == productId,
      );
    } catch (_) {
      return null;
    }
  }

  List<Product> searchProducts(String keyword) {
    final query = keyword.toLowerCase();

    return _products.where((product) {
      return product.productName.toLowerCase().contains(query) ||
          product.hsnCode.toLowerCase().contains(query) ||
          product.productCode.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);
    }).toList();
  }

  Product? findByBarcodeOrCode(String code) {
    final normalized = _normalizeValue(code);
    if (normalized.isEmpty) return null;

    try {
      return _products.firstWhere((product) {
        return _normalizeValue(product.barcode) == normalized ||
            _normalizeValue(product.productCode) == normalized;
      });
    } catch (_) {
      return null;
    }
  }

  List<Product> filterByCategory(String category) {
    if (category.isEmpty) return products;
    return _products
        .where((product) => product.category == category)
        .toList();
  }

  List<Product> filterActiveProducts() {
    return _products.where(
      (product) => product.isActive,
    ).toList();
  }

  void clearProducts() {
    _products.clear();
    notifyListeners();
  }

  bool isProductCodeExists(String code, [String? excludeProductId]) {
    final normalizedCode = _normalizeValue(code);
    if (normalizedCode.isEmpty) return false;

    return _products.any(
      (p) =>
          _normalizeValue(p.productCode) == normalizedCode &&
          (excludeProductId == null || p.id != excludeProductId),
    );
  }

  bool isExactProductNameExists(String name, [String? excludeProductId]) {
    final normalizedName = _normalizeValue(name);
    if (normalizedName.isEmpty) return false;

    return _products.any(
      (p) =>
          _normalizeValue(p.productName) == normalizedName &&
          (excludeProductId == null || p.id != excludeProductId),
    );
  }

  bool isHsnNameCombinationExists(
    String hsnCode,
    String productName, [
    String? excludeProductId,
  ]) {
    final normalizedHsn = _normalizeValue(hsnCode);
    final normalizedName = _normalizeValue(productName);
    if (normalizedHsn.isEmpty || normalizedName.isEmpty) return false;

    return _products.any(
      (p) =>
          _normalizeValue(p.hsnCode) == normalizedHsn &&
          _normalizeValue(p.productName) == normalizedName &&
          (excludeProductId == null || p.id != excludeProductId),
    );
  }

  List<Product> findSimilarNames(String name, [String? excludeProductId]) {
    final normalizedName = _normalizeValue(name);
    if (normalizedName.isEmpty) return [];

    return _products
        .where(
          (p) =>
              _normalizeValue(p.productName).contains(normalizedName) &&
              (excludeProductId == null || p.id != excludeProductId),
        )
        .toList();
  }

  String? validateProductForSave(Product product, [String? excludeProductId]) {
    if (isProductCodeExists(product.productCode, excludeProductId)) {
      return 'Duplicate product code is not allowed.';
    }

    final hsnCode = product.hsnCode.trim();
    if (hsnCode.isNotEmpty &&
        isHsnNameCombinationExists(hsnCode, product.productName, excludeProductId)) {
      return 'Duplicate product is not allowed for the same HSN + product name.';
    }

    if (hsnCode.isEmpty &&
        isExactProductNameExists(product.productName, excludeProductId)) {
      return 'Duplicate product name is not allowed when HSN is blank.';
    }

    return null;
  }

  Map<String, dynamic> checkDuplicates(Product product, [String? excludeProductId]) {
    return {
      'productCodeExists': isProductCodeExists(product.productCode, excludeProductId),
      'exactNameExists': isExactProductNameExists(product.productName, excludeProductId),
      'hsnNameExists': isHsnNameCombinationExists(
        product.hsnCode,
        product.productName,
        excludeProductId,
      ),
      'nameWarnings': findSimilarNames(product.productName, excludeProductId),
    };
  }

  Product? findIdentityMatch(Product product, [String? excludeProductId]) {
    final productCode = _normalizeValue(product.productCode);
    final productName = _normalizeValue(product.productName);
    final hsnCode = _normalizeValue(product.hsnCode);

    if (productCode.isNotEmpty) {
      for (final p in _products) {
        if (_normalizeValue(p.productCode) == productCode &&
            (excludeProductId == null || p.id != excludeProductId)) {
          return p;
        }
      }
    }

    if (productName.isNotEmpty && hsnCode.isNotEmpty) {
      for (final p in _products) {
        if (_normalizeValue(p.productName) == productName &&
            _normalizeValue(p.hsnCode) == hsnCode &&
            (excludeProductId == null || p.id != excludeProductId)) {
          return p;
        }
      }
    }

    if (productName.isNotEmpty) {
      for (final p in _products) {
        if (_normalizeValue(p.productName) == productName &&
            (excludeProductId == null || p.id != excludeProductId)) {
          return p;
        }
      }
    }

    return null;
  }

  String _nextIndustryProductCode(String industryKey) {
    final compact = industryKey
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final prefix = compact.length >= 3
        ? compact.substring(0, 3)
        : compact.padRight(3, 'X');
    final pattern = RegExp('^' + prefix + r'-(\d+)$');
    var maxSequence = 0;

    for (final product in _products) {
      final match = pattern.firstMatch(product.productCode.trim());
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (value > maxSequence) {
        maxSequence = value;
      }
    }

    return '$prefix-${(maxSequence + 1).toString().padLeft(4, '0')}';
  }

  int installIndustryPack(IndustryMasterPack pack) {
    var inserted = 0;
    for (final item in pack.products) {
      addCategory(item.category);

      final existing = _products.where((product) {
        return _normalizeValue(product.productName) ==
                _normalizeValue(item.name) &&
            _normalizeValue(product.hsnCode) == _normalizeValue(item.hsnCode);
      }).cast<Product?>().firstOrNull;

      if (existing != null) {
        continue;
      }

      final product = Product(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productCode: _nextIndustryProductCode(pack.key),
        productName: item.name,
        category: item.category,
        description: '${pack.label} starter pack',
        hsnCode: item.hsnCode,
        gstPercentage: item.gstPercentage,
        unit: item.unit,
        isActive: true,
      );

      final validationError = validateProductForSave(product);
      if (validationError != null) {
        continue;
      }

      _products.add(product);
      inserted++;
    }

    if (inserted > 0) {
      notifyListeners();
    }

    return inserted;
  }

  /// Sample Data
  void loadDemoProducts() {
    if (_products.isNotEmpty) return;

    _products.addAll([
      Product(
        id: "P001",
        productCode: "TG-001",
        productName: "10mm Toughened Glass",
        hsnCode: "70071900",
        category: "Glass",
        description: "10mm toughened safety glass, clear",
        unit: "Sq. Ft.",
        purchaseRate: 850,
        salesRate: 1000,
        gstPercentage: 18,
        openingStock: 100,
        minimumStock: 10,
        isActive: true,
      ),
      Product(
        id: "P002",
        productCode: "TG-002",
        productName: "12mm Toughened Glass",
        hsnCode: "70071900",
        category: "Glass",
        description: "12mm toughened safety glass, clear",
        unit: "Sq. Ft.",
        purchaseRate: 1100,
        salesRate: 1300,
        gstPercentage: 18,
        openingStock: 80,
        minimumStock: 10,
        isActive: true,
      ),
    ]);

    notifyListeners();
  }
}

extension _NullableIterableFirst<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}