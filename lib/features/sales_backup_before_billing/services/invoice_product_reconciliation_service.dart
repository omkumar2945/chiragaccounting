import 'package:chirag_accounting/features/products/models/product.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/sales/presentation/widgets/product_selector.dart';

class InvoiceProductReconciliationResult {
  const InvoiceProductReconciliationResult({
    required this.matched,
    required this.created,
    required this.errors,
    required this.completed,
  });

  final int matched;
  final int created;
  final List<String> errors;
  final bool completed;
}

class InvoiceProductReconciliationService {
  Future<InvoiceProductReconciliationResult> reconcile({
    required List<ProductRow> rows,
    required ProductService productService,
  }) async {
    var matched = 0;
    var created = 0;
    final errors = <String>[];

    for (final row in rows) {
      final name = (row.productName ?? '').trim();
      if (name.isEmpty) {
        errors.add('Missing product name in one row.');
        continue;
      }

      final existing = _findByNameOrCode(productService.products, row);
      if (existing != null) {
        row.productCode = existing.productCode;
        row.hsnCode = (row.hsnCode ?? '').trim().isEmpty ? existing.hsnCode : row.hsnCode;
        row.unit = (row.unit ?? '').trim().isEmpty ? existing.unit : row.unit;
        row.gstPercentage = row.gstPercentage <= 0 ? existing.gstPercentage : row.gstPercentage;
        row.taxCodeVerified = true;
        matched += 1;
        continue;
      }

      final product = Product(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productCode: row.productCode.trim().isEmpty
            ? 'PRD-${DateTime.now().microsecondsSinceEpoch}'
            : row.productCode.trim(),
        productName: name,
        description: row.description,
        hsnCode: row.hsnCode ?? '',
        gstPercentage: row.gstPercentage <= 0 ? 18 : row.gstPercentage,
        unit: (row.unit ?? '').trim().isEmpty ? 'Nos' : row.unit!.trim(),
        salesRate: row.rate,
        isActive: true,
      );

      try {
        productService.addProduct(product);
        row.productCode = product.productCode;
        row.taxCodeVerified = (row.hsnCode ?? '').trim().isNotEmpty;
        created += 1;
      } catch (error) {
        errors.add('Could not create product "$name": $error');
      }
    }

    return InvoiceProductReconciliationResult(
      matched: matched,
      created: created,
      errors: errors,
      completed: errors.isEmpty,
    );
  }

  Product? _findByNameOrCode(List<Product> products, ProductRow row) {
    final code = row.productCode.trim().toLowerCase();
    final name = (row.productName ?? '').trim().toLowerCase();

    for (final product in products) {
      if (code.isNotEmpty && product.productCode.trim().toLowerCase() == code) {
        return product;
      }
      if (name.isNotEmpty && product.productName.trim().toLowerCase() == name) {
        return product;
      }
    }

    return null;
  }
}
