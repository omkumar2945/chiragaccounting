import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:archive/archive.dart';
import 'package:chirag_accounting/features/customers/models/customer.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/features/vendors/models/vendor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chirag_accounting/features/clients/services/file_bytes_reader.dart';
import 'package:chirag_accounting/features/clients/services/file_text_reader.dart';
import 'package:xml/xml.dart';

class InventoryImportRow {
  final String name;
  final String hsn;
  final String unit;
  final double stock;
  final double purchaseRate;
  final double salesRate;
  final String category;

  const InventoryImportRow({
    required this.name,
    this.hsn = '',
    this.unit = 'Nos',
    this.stock = 0,
    this.purchaseRate = 0,
    this.salesRate = 0,
    this.category = 'Imported',
  });
}

class LedgerImportRow {
  final String ledgerName;
  final String ledgerGroup;
  final String mobile;
  final String email;
  final String gstin;
  final String pan;
  final double openingBalance;

  const LedgerImportRow({
    required this.ledgerName,
    this.ledgerGroup = 'Sundry Debtors',
    this.mobile = '',
    this.email = '',
    this.gstin = '',
    this.pan = '',
    this.openingBalance = 0,
  });
}

enum LedgerImportTarget { debtors, creditors, allLedgers }

extension LedgerImportTargetExtension on LedgerImportTarget {
  String get displayName {
    switch (this) {
      case LedgerImportTarget.debtors:
        return 'Debtors';
      case LedgerImportTarget.creditors:
        return 'Creditors';
      case LedgerImportTarget.allLedgers:
        return 'All Ledgers';
    }
  }
}

class ImportSummary {
  final int processed;
  final int created;
  final int updated;
  final List<String> warnings;

  const ImportSummary({
    required this.processed,
    required this.created,
    required this.updated,
    this.warnings = const [],
  });
}

class SupplierHandshakeToken {
  final String token;
  final String supplierAccountId;
  final String clientAccountId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const SupplierHandshakeToken({
    required this.token,
    required this.supplierAccountId,
    required this.clientAccountId,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ClientDataExchangeService {
  static final Map<String, List<InventoryImportRow>> _liveSupplierCatalog = {
    'admin@chiragca.com': const [
      InventoryImportRow(
        name: 'Tempered Clear Glass 10mm',
        hsn: '70071900',
        unit: 'Sq. Ft.',
        stock: 180,
        purchaseRate: 900,
        salesRate: 1080,
        category: 'Live Supplier Catalog',
      ),
      InventoryImportRow(
        name: 'Tempered Clear Glass 12mm',
        hsn: '70071900',
        unit: 'Sq. Ft.',
        stock: 140,
        purchaseRate: 1120,
        salesRate: 1310,
        category: 'Live Supplier Catalog',
      ),
    ],
    'partner@chiragca.com': const [
      InventoryImportRow(
        name: 'Architectural Mirror Panel',
        hsn: '70099100',
        unit: 'Nos',
        stock: 65,
        purchaseRate: 1200,
        salesRate: 1490,
        category: 'Live Supplier Catalog',
      ),
    ],
  };

  String _permissionKey(String vendorId) =>
      'supplier_pull_permission_$vendorId';

  String _sameSystemKey(String vendorId) => 'supplier_same_system_$vendorId';

  String _tokenKey(String token) => 'supplier_handshake_token_$token';

  final String _tokenCharset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<bool> getSupplierPermission(String vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionKey(vendorId)) ?? false;
  }

  Future<void> setSupplierPermission(String vendorId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionKey(vendorId), value);
  }

  Future<bool> getSupplierSameSystem(String vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sameSystemKey(vendorId)) ?? false;
  }

  Future<void> setSupplierSameSystem(String vendorId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sameSystemKey(vendorId), value);
  }

  Future<SupplierHandshakeToken?> getHandshakeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tokenKey(token.trim()));
    if (raw == null || raw.trim().isEmpty) return null;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    final issued = DateTime.tryParse((json['issuedAt'] as String?) ?? '');
    final expires = DateTime.tryParse((json['expiresAt'] as String?) ?? '');
    if (issued == null || expires == null) return null;

    return SupplierHandshakeToken(
      token: (json['token'] as String?) ?? '',
      supplierAccountId: (json['supplierAccountId'] as String?) ?? '',
      clientAccountId: (json['clientAccountId'] as String?) ?? '',
      issuedAt: issued,
      expiresAt: expires,
    );
  }

  Future<SupplierHandshakeToken> issueHandshakeToken({
    required String supplierAccountId,
    required String clientAccountId,
    required bool supplierPermissionGranted,
    int ttlMinutes = 30,
  }) async {
    if (!supplierPermissionGranted) {
      throw Exception('Supplier permission required to issue sync token.');
    }

    final token = _generateToken();
    final issued = DateTime.now();
    final expires = issued.add(Duration(minutes: ttlMinutes));
    final payload = {
      'token': token,
      'supplierAccountId': supplierAccountId.trim().toLowerCase(),
      'clientAccountId': clientAccountId.trim().toLowerCase(),
      'issuedAt': issued.toIso8601String(),
      'expiresAt': expires.toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey(token), jsonEncode(payload));

    return SupplierHandshakeToken(
      token: token,
      supplierAccountId: supplierAccountId.trim().toLowerCase(),
      clientAccountId: clientAccountId.trim().toLowerCase(),
      issuedAt: issued,
      expiresAt: expires,
    );
  }

  Future<bool> validateHandshakeToken({
    required String token,
    required String supplierAccountId,
    required String clientAccountId,
  }) async {
    final resolved = await getHandshakeToken(token.trim());
    if (resolved == null) return false;
    if (resolved.isExpired) return false;

    final supplierOk =
        resolved.supplierAccountId == supplierAccountId.trim().toLowerCase();
    final clientOk =
        resolved.clientAccountId == clientAccountId.trim().toLowerCase();
    return supplierOk && clientOk;
  }

  Future<ImportSummary> importInventoryFromFile({
    required String filePath,
    required ProductService productService,
    String unitGroupName = '',
    String baseUnit = 'Nos',
    Map<String, double> conversionRules = const {},
  }) async {
    final ext = _extension(filePath);
    if (_isExcelExtension(ext)) {
      final bytes = await readBinaryFile(filePath);
      return importInventoryFromBytes(
        sourceName: filePath,
        bytes: bytes,
        productService: productService,
        unitGroupName: unitGroupName,
        baseUnit: baseUnit,
        conversionRules: conversionRules,
      );
    }

    final text = await readTextFile(filePath);
    return importInventoryFromText(
      sourceName: filePath,
      text: text,
      productService: productService,
      unitGroupName: unitGroupName,
      baseUnit: baseUnit,
      conversionRules: conversionRules,
    );
  }

  Future<ImportSummary> importInventoryFromBytes({
    required String sourceName,
    required Uint8List bytes,
    required ProductService productService,
    String unitGroupName = '',
    String baseUnit = 'Nos',
    Map<String, double> conversionRules = const {},
  }) async {
    final ext = _extension(sourceName);
    if (_isExcelExtension(ext)) {
      final rows = _parseInventoryRowsFromGrid(_spreadsheetRows(bytes));
      return _applyInventoryImportRows(
        rows: rows,
        extension: ext,
        productService: productService,
        unitGroupName: unitGroupName,
        baseUnit: baseUnit,
        conversionRules: conversionRules,
      );
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    return importInventoryFromText(
      sourceName: sourceName,
      text: text,
      productService: productService,
      unitGroupName: unitGroupName,
      baseUnit: baseUnit,
      conversionRules: conversionRules,
    );
  }

  Future<ImportSummary> importInventoryFromText({
    required String sourceName,
    required String text,
    required ProductService productService,
    String unitGroupName = '',
    String baseUnit = 'Nos',
    Map<String, double> conversionRules = const {},
  }) async {
    final ext = _extension(sourceName);
    final rows = _parseInventoryRows(text: text, extension: ext);

    return _applyInventoryImportRows(
      rows: rows,
      extension: ext,
      productService: productService,
      unitGroupName: unitGroupName,
      baseUnit: baseUnit,
      conversionRules: conversionRules,
    );
  }

  ImportSummary _applyInventoryImportRows({
    required List<InventoryImportRow> rows,
    required String extension,
    required ProductService productService,
    String unitGroupName = '',
    String baseUnit = 'Nos',
    Map<String, double> conversionRules = const {},
  }) {

    var created = 0;
    var updated = 0;
    final importedProductIds = <String>[];

    for (final row in rows) {
      final before = _containsProduct(productService, row.name, row.hsn);

      final product = productService.upsertImportedProduct(
        productName: row.name,
        hsnCode: row.hsn,
        unit: row.unit,
        openingStock: row.stock,
        purchaseRate: row.purchaseRate,
        salesRate: row.salesRate,
        category: row.category,
      );

      importedProductIds.add(product.id);

      if (!before) {
        created++;
      } else {
        updated++;
      }
    }

    if (unitGroupName.trim().isNotEmpty && importedProductIds.isNotEmpty) {
      final rules = conversionRules.entries
          .where((e) => e.key.trim().isNotEmpty && e.value > 0)
          .map(
            (e) => InventoryUnitConversionRule(
              fromUnit: e.key.trim(),
              multiplierToBase: e.value,
            ),
          )
          .toList(growable: false);

      productService.configureUnitGroup(
        groupName: unitGroupName.trim(),
        baseUnit: baseUnit.trim().isEmpty ? 'Nos' : baseUnit.trim(),
        productIds: importedProductIds,
        conversionRules: rules,
      );
    }

    return ImportSummary(
      processed: rows.length,
      created: created,
      updated: updated,
      warnings: _inventoryTemplateHint(extension),
    );
  }

  Future<ImportSummary> importLedgerFromFile({
    required String filePath,
    required CustomerService customerService,
    required VendorService vendorService,
    LedgerImportTarget target = LedgerImportTarget.debtors,
  }) async {
    final ext = _extension(filePath);
    if (_isExcelExtension(ext)) {
      final bytes = await readBinaryFile(filePath);
      return importLedgerFromBytes(
        sourceName: filePath,
        bytes: bytes,
        customerService: customerService,
        vendorService: vendorService,
        target: target,
      );
    }

    final text = await readTextFile(filePath);
    return importLedgerFromText(
      sourceName: filePath,
      text: text,
      customerService: customerService,
      vendorService: vendorService,
      target: target,
    );
  }

  Future<ImportSummary> importLedgerFromBytes({
    required String sourceName,
    required Uint8List bytes,
    required CustomerService customerService,
    required VendorService vendorService,
    LedgerImportTarget target = LedgerImportTarget.debtors,
  }) async {
    final ext = _extension(sourceName);
    if (_isExcelExtension(ext)) {
      final rows = _parseLedgerRowsFromGrid(_spreadsheetRows(bytes));
      return _applyLedgerImportRows(
        rows: rows,
        extension: ext,
        customerService: customerService,
        vendorService: vendorService,
        target: target,
      );
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    return importLedgerFromText(
      sourceName: sourceName,
      text: text,
      customerService: customerService,
      vendorService: vendorService,
      target: target,
    );
  }

  Future<ImportSummary> importLedgerFromText({
    required String sourceName,
    required String text,
    required CustomerService customerService,
    required VendorService vendorService,
    LedgerImportTarget target = LedgerImportTarget.debtors,
  }) async {
    final ext = _extension(sourceName);
    final rows = _parseLedgerRows(text: text, extension: ext);

    return _applyLedgerImportRows(
      rows: rows,
      extension: ext,
      customerService: customerService,
      vendorService: vendorService,
      target: target,
    );
  }

  ImportSummary _applyLedgerImportRows({
    required List<LedgerImportRow> rows,
    required String extension,
    required CustomerService customerService,
    required VendorService vendorService,
    LedgerImportTarget target = LedgerImportTarget.debtors,
  }) {

    var created = 0;
    var updated = 0;

    for (final row in rows) {
      final normalizedMobile = normalizeIndianMobile(row.mobile);
      final resolvedTarget = _resolveLedgerTarget(target, row);
      switch (resolvedTarget) {
        case LedgerImportTarget.creditors:
          final existing = vendorService.findIdentityMatch(
            name: row.ledgerName,
            gstNumber: row.gstin,
            mobileNumber: normalizedMobile,
          );

          if (existing != null) {
            vendorService.updateVendor(
              existing.id,
              existing.copyWith(
                vendorName: row.ledgerName,
                mobileNumber: normalizedMobile.isEmpty
                    ? existing.mobileNumber
                    : normalizedMobile,
                email: row.email.isEmpty ? existing.email : row.email,
                gstNumber: row.gstin.isEmpty ? existing.gstNumber : row.gstin,
                billingAddress: existing.billingAddress,
                ledgerGroup: row.ledgerGroup.isEmpty
                    ? existing.ledgerGroup
                    : row.ledgerGroup,
                openingBalance: row.openingBalance,
              ),
            );
            updated++;
          } else {
            vendorService.addVendor(
              Vendor(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                vendorCode: vendorService.nextVendorCode(),
                vendorName: row.ledgerName,
                mobileNumber: normalizedMobile,
                email: row.email,
                gstNumber: row.gstin,
                billingAddress: '',
                ledgerGroup: row.ledgerGroup.isEmpty
                    ? 'Sundry Creditors'
                    : row.ledgerGroup,
                openingBalance: row.openingBalance,
                isActive: true,
              ),
            );
            created++;
          }
          break;
        case LedgerImportTarget.debtors:
        case LedgerImportTarget.allLedgers:
          final existing = customerService.findIdentityMatch(
            row.ledgerName,
            gstNumber: row.gstin,
            mobileNumber: normalizedMobile,
          );

          if (existing != null) {
            customerService.updateCustomer(
              existing.id,
              existing.copyWith(
                customerName: row.ledgerName,
                companyName: row.ledgerName,
                ledgerGroup: row.ledgerGroup.isEmpty
                    ? existing.ledgerGroup
                    : row.ledgerGroup,
                mobileNumber: normalizedMobile.isEmpty
                    ? existing.mobileNumber
                    : normalizedMobile,
                email: row.email.isEmpty ? existing.email : row.email,
                gstNumber: row.gstin.isEmpty ? existing.gstNumber : row.gstin,
                panNumber: row.pan.isEmpty ? existing.panNumber : row.pan,
                openingBalance: row.openingBalance,
              ),
            );
            updated++;
          } else {
            customerService.addCustomer(
              Customer(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                customerCode: _nextLedgerCode(
                  customerService.customers.length + 1,
                ),
                customerName: row.ledgerName,
                companyName: row.ledgerName,
                mobileNumber: normalizedMobile,
                email: row.email,
                gstNumber: row.gstin,
                panNumber: row.pan,
                ledgerGroup: row.ledgerGroup.isEmpty
                    ? 'Sundry Debtors'
                    : row.ledgerGroup,
                openingBalance: row.openingBalance,
                isActive: true,
              ),
            );
            created++;
          }
          break;
      }
    }

    return ImportSummary(
      processed: rows.length,
      created: created,
      updated: updated,
      warnings: _ledgerTemplateHint(extension),
    );
  }

  Future<ImportSummary> pullSupplierInventory({
    required Vendor vendor,
    required bool supplierPermissionGranted,
    required bool supplierUsesChiragSystem,
    required ProductService productService,
    required VendorService vendorService,
    String supplierAccountId = '',
    String handshakeToken = '',
    String clientAccountId = '',
    String unitGroupName = '',
    String baseUnit = 'Nos',
  }) async {
    if (!supplierPermissionGranted) {
      return const ImportSummary(
        processed: 0,
        created: 0,
        updated: 0,
        warnings: ['Supplier permission required before pulling inventory.'],
      );
    }

    final rows = supplierUsesChiragSystem
        ? await _pullLiveRows(
            vendor: vendor,
            supplierAccountId: supplierAccountId,
            handshakeToken: handshakeToken,
            clientAccountId: clientAccountId,
          )
        : _buildManualSupplierRows(vendor);

    var created = 0;
    var updated = 0;
    final productIds = <String>[];

    for (final row in rows) {
      final before = _containsProduct(productService, row.name, row.hsn);

      final product = productService.upsertImportedProduct(
        productName: row.name,
        hsnCode: row.hsn,
        unit: row.unit,
        openingStock: row.stock,
        purchaseRate: row.purchaseRate,
        salesRate: row.salesRate,
        category: 'Supplier-${vendor.vendorName}',
      );
      productIds.add(product.id);

      if (!before) {
        created++;
      } else {
        updated++;
      }
    }

    if (unitGroupName.trim().isNotEmpty && productIds.isNotEmpty) {
      productService.configureUnitGroup(
        groupName: unitGroupName,
        baseUnit: baseUnit,
        productIds: productIds,
      );
    }

    final isKnownVendor =
        vendorService.getVendorById(vendor.id) != null ||
        vendor.vendorName.isNotEmpty;

    final hints = <String>[];
    if (supplierUsesChiragSystem) {
      hints.add('Auto-pull mode used: supplier appears on same Chirag system.');
    } else {
      hints.add('Manual pull mode used from supplier shared catalog.');
    }
    if (!isKnownVendor) {
      hints.add('Supplier is not saved in vendor master yet.');
    }

    return ImportSummary(
      processed: rows.length,
      created: created,
      updated: updated,
      warnings: hints,
    );
  }

  Future<List<InventoryImportRow>> _pullLiveRows({
    required Vendor vendor,
    required String supplierAccountId,
    required String handshakeToken,
    required String clientAccountId,
  }) async {
    final accountId = supplierAccountId.trim().toLowerCase();
    if (accountId.isEmpty) {
      throw Exception('Supplier Chirag account ID is required for live sync.');
    }
    if (handshakeToken.trim().isEmpty) {
      throw Exception('Handshake token is required for live sync.');
    }
    if (clientAccountId.trim().isEmpty) {
      throw Exception('Client account ID is required for token verification.');
    }

    final valid = await validateHandshakeToken(
      token: handshakeToken,
      supplierAccountId: accountId,
      clientAccountId: clientAccountId,
    );
    if (!valid) {
      throw Exception('Invalid or expired supplier handshake token.');
    }

    final rows = _liveSupplierCatalog[accountId];
    if (rows == null || rows.isEmpty) {
      return _buildAutoSupplierRows(vendor);
    }
    return rows;
  }

  List<InventoryImportRow> _parseInventoryRows({
    required String text,
    required String extension,
  }) {
    if (extension == 'json') {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((e) => _inventoryFromMap((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      }
      return const [];
    }

    return _parseInventoryRowsFromGrid(_csvRows(text));
  }

  List<InventoryImportRow> _parseInventoryRowsFromGrid(List<List<String>> rows) {
    if (rows.isEmpty) return const [];

    final header = rows.first.map(_normalizeKey).toList(growable: false);
    final dataRows = rows.skip(1);

    return dataRows
        .map((cols) {
          final category = _readByHeader(
            header: header,
            cols: cols,
            keys: const ['category', 'group'],
          );

          return InventoryImportRow(
            name: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['name', 'product_name', 'item_name'],
            ),
            hsn: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['hsn', 'hsn_code'],
            ),
            unit: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['unit', 'uom'],
            ),
            stock: _toDouble(
              _readByHeader(
                header: header,
                cols: cols,
                keys: const ['stock', 'opening_stock', 'qty'],
              ),
            ),
            purchaseRate: _toDouble(
              _readByHeader(
                header: header,
                cols: cols,
                keys: const ['purchase_rate', 'buy_rate'],
              ),
            ),
            salesRate: _toDouble(
              _readByHeader(
                header: header,
                cols: cols,
                keys: const ['sales_rate', 'sell_rate'],
              ),
            ),
            category: category.isEmpty ? 'Imported' : category,
          );
        })
        .where((r) => r.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<LedgerImportRow> _parseLedgerRows({
    required String text,
    required String extension,
  }) {
    if (extension == 'json') {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((e) => _ledgerFromMap((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      }
      return const [];
    }

    return _parseLedgerRowsFromGrid(_csvRows(text));
  }

  List<LedgerImportRow> _parseLedgerRowsFromGrid(List<List<String>> rows) {
    if (rows.isEmpty) return const [];

    final header = rows.first.map(_normalizeKey).toList(growable: false);
    final dataRows = rows.skip(1);

    return dataRows
        .map((cols) {
          return LedgerImportRow(
            ledgerName: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['ledger_name', 'name', 'party_name'],
            ),
            ledgerGroup: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['ledger_group', 'group'],
            ),
            mobile: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['mobile', 'phone'],
            ),
            email: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['email'],
            ),
            gstin: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['gstin', 'gst_number'],
            ).toUpperCase(),
            pan: _readByHeader(
              header: header,
              cols: cols,
              keys: const ['pan', 'pan_number'],
            ).toUpperCase(),
            openingBalance: _toDouble(
              _readByHeader(
                header: header,
                cols: cols,
                keys: const ['opening_balance', 'balance'],
              ),
            ),
          );
        })
        .where((r) => r.ledgerName.trim().isNotEmpty)
        .toList(growable: false);
  }

  InventoryImportRow _inventoryFromMap(Map<String, dynamic> map) {
    return InventoryImportRow(
      name: (map['name'] ?? map['product_name'] ?? '').toString(),
      hsn: (map['hsn'] ?? map['hsn_code'] ?? '').toString(),
      unit: (map['unit'] ?? map['uom'] ?? 'Nos').toString(),
      stock: _toDouble((map['stock'] ?? map['opening_stock'] ?? 0).toString()),
      purchaseRate: _toDouble(
        (map['purchase_rate'] ?? map['buy_rate'] ?? 0).toString(),
      ),
      salesRate: _toDouble(
        (map['sales_rate'] ?? map['sell_rate'] ?? 0).toString(),
      ),
      category: (map['category'] ?? map['group'] ?? 'Imported').toString(),
    );
  }

  LedgerImportRow _ledgerFromMap(Map<String, dynamic> map) {
    return LedgerImportRow(
      ledgerName: (map['ledger_name'] ?? map['name'] ?? map['party_name'] ?? '')
          .toString(),
      ledgerGroup: (map['ledger_group'] ?? map['group'] ?? 'Sundry Debtors')
          .toString(),
      mobile: (map['mobile'] ?? map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      gstin: (map['gstin'] ?? map['gst_number'] ?? '').toString().toUpperCase(),
      pan: (map['pan'] ?? map['pan_number'] ?? '').toString().toUpperCase(),
      openingBalance: _toDouble(
        (map['opening_balance'] ?? map['balance'] ?? 0).toString(),
      ),
    );
  }

  LedgerImportTarget _resolveLedgerTarget(
    LedgerImportTarget target,
    LedgerImportRow row,
  ) {
    switch (target) {
      case LedgerImportTarget.debtors:
        return LedgerImportTarget.debtors;
      case LedgerImportTarget.creditors:
        return LedgerImportTarget.creditors;
      case LedgerImportTarget.allLedgers:
        return _isCreditorLedger(row)
            ? LedgerImportTarget.creditors
            : LedgerImportTarget.debtors;
    }
  }

  bool _isCreditorLedger(LedgerImportRow row) {
    final text = '${row.ledgerName} ${row.ledgerGroup}'.toLowerCase();
    const creditorHints = [
      'creditor',
      'creditors',
      'payable',
      'supplier',
      'vendor',
      'trade payable',
      'sundry creditor',
    ];
    return creditorHints.any(text.contains);
  }

  List<InventoryImportRow> _buildAutoSupplierRows(Vendor vendor) {
    return [
      InventoryImportRow(
        name: '${vendor.vendorName} Standard Sheet',
        hsn: '70071900',
        unit: 'Sq. Ft.',
        stock: 120,
        purchaseRate: 920,
        salesRate: 1100,
        category: 'Supplier-${vendor.vendorName}',
      ),
      InventoryImportRow(
        name: '${vendor.vendorName} Premium Sheet',
        hsn: '70072190',
        unit: 'Sq. Ft.',
        stock: 85,
        purchaseRate: 1180,
        salesRate: 1380,
        category: 'Supplier-${vendor.vendorName}',
      ),
    ];
  }

  List<InventoryImportRow> _buildManualSupplierRows(Vendor vendor) {
    return [
      InventoryImportRow(
        name: '${vendor.vendorName} Supplier Item 1',
        hsn: '70080000',
        unit: 'Nos',
        stock: 40,
        purchaseRate: 500,
        salesRate: 620,
        category: 'Supplier-${vendor.vendorName}',
      ),
      InventoryImportRow(
        name: '${vendor.vendorName} Supplier Item 2',
        hsn: '70031210',
        unit: 'Nos',
        stock: 65,
        purchaseRate: 730,
        salesRate: 860,
        category: 'Supplier-${vendor.vendorName}',
      ),
    ];
  }

  String _nextLedgerCode(int sequence) =>
      'LED-${sequence.toString().padLeft(4, '0')}';

  String _extension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx < 0 || idx >= path.length - 1) return '';
    return path.substring(idx + 1).toLowerCase();
  }

  double _toDouble(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  String _normalizeKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  bool _containsProduct(
    ProductService productService,
    String name,
    String hsn,
  ) {
    final normalizedName = _normalizeKey(name);
    final normalizedHsn = _normalizeKey(hsn);
    return productService.products.any((p) {
      final sameName = _normalizeKey(p.productName) == normalizedName;
      if (!sameName) return false;
      if (normalizedHsn.isEmpty) return true;
      return _normalizeKey(p.hsnCode) == normalizedHsn;
    });
  }

  List<List<String>> _csvRows(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final delimiter = line.contains('\t') ? '\t' : ',';
          return line
              .split(delimiter)
              .map((c) => c.trim())
              .toList(growable: false);
        })
        .toList(growable: false);
  }

  List<List<String>> _spreadsheetRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    if (archive.isEmpty) return const [];

    final sharedStrings = _xlsxSharedStrings(archive);
    final sheetPath = _xlsxFirstSheetPath(archive);
    if (sheetPath == null) return const [];

    final sheetXml = _archiveFileText(archive, sheetPath);
    if (sheetXml == null || sheetXml.trim().isEmpty) return const [];

    final doc = XmlDocument.parse(sheetXml);
    final rows = <List<String>>[];

    for (final rowNode in doc.findAllElements('row')) {
      final row = <String>[];
      for (final cell in rowNode.findElements('c')) {
        final reference = cell.getAttribute('r') ?? '';
        final colIndex = _xlsxColIndexFromRef(reference);
        if (colIndex < 0) continue;
        while (row.length <= colIndex) {
          row.add('');
        }
        row[colIndex] = _xlsxCellValue(cell, sharedStrings);
      }

      final compacted = _trimTrailingEmpty(row);
      if (compacted.any((value) => value.isNotEmpty)) {
        rows.add(compacted);
      }
    }

    return rows;
  }

  List<String> _xlsxSharedStrings(Archive archive) {
    final xml = _archiveFileText(archive, 'xl/sharedStrings.xml');
    if (xml == null || xml.trim().isEmpty) return const [];

    final doc = XmlDocument.parse(xml);
    return doc.findAllElements('si').map((si) {
      final tNodes = si.findAllElements('t');
      if (tNodes.isEmpty) return '';
      return tNodes.map((t) => t.innerText).join().trim();
    }).toList(growable: false);
  }

  String? _xlsxFirstSheetPath(Archive archive) {
    final workbookXml = _archiveFileText(archive, 'xl/workbook.xml');
    if (workbookXml == null || workbookXml.trim().isEmpty) {
      final fallback = archive.files
          .where((f) => f.name.startsWith('xl/worksheets/sheet'))
          .map((f) => f.name)
          .toList(growable: false)
        ..sort();
      return fallback.isEmpty ? null : fallback.first;
    }

    final relXml = _archiveFileText(archive, 'xl/_rels/workbook.xml.rels');
    final relMap = <String, String>{};
    if (relXml != null && relXml.trim().isNotEmpty) {
      final relDoc = XmlDocument.parse(relXml);
      for (final rel in relDoc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id == null || target == null || target.trim().isEmpty) continue;
        var resolved = target.replaceAll('\\', '/');
        if (!resolved.startsWith('xl/')) {
          resolved = 'xl/$resolved';
        }
        relMap[id] = resolved;
      }
    }

    final wbDoc = XmlDocument.parse(workbookXml);
    final sheets = wbDoc.findAllElements('sheet').toList(growable: false);
    if (sheets.isEmpty) return null;

    final relId =
      sheets.first.getAttribute(
        'id',
        namespaceUri:
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      ) ??
        sheets.first.getAttribute('r:id');
    if (relId != null && relMap.containsKey(relId)) {
      return relMap[relId];
    }

    final fallback = archive.files
        .where((f) => f.name.startsWith('xl/worksheets/sheet'))
        .map((f) => f.name)
        .toList(growable: false)
      ..sort();
    return fallback.isEmpty ? null : fallback.first;
  }

  String _xlsxCellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t') ?? '';

    if (type == 'inlineStr') {
      final inlineText = cell.findElements('is').expand((n) => n.findAllElements('t'));
      return inlineText.map((n) => n.innerText).join().trim();
    }

    final vNode = cell.findElements('v').isEmpty ? null : cell.findElements('v').first;
    final raw = vNode?.innerText.trim() ?? '';
    if (raw.isEmpty) return '';

    if (type == 's') {
      final index = int.tryParse(raw);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        return '';
      }
      return sharedStrings[index];
    }

    return raw;
  }

  int _xlsxColIndexFromRef(String ref) {
    if (ref.trim().isEmpty) return -1;

    final match = RegExp(r'([A-Za-z]+)').firstMatch(ref);
    if (match == null) return -1;
    final letters = match.group(1)?.toUpperCase() ?? '';
    if (letters.isEmpty) return -1;

    var index = 0;
    for (final code in letters.codeUnits) {
      final value = code - 64;
      if (value < 1 || value > 26) return -1;
      index = index * 26 + value;
    }
    return index - 1;
  }

  String? _archiveFileText(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null || file.isFile == false) return null;

    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  List<String> _trimTrailingEmpty(List<String> row) {
    var end = row.length;
    while (end > 0 && row[end - 1].trim().isEmpty) {
      end--;
    }
    if (end == row.length) return row;
    return row.take(end).toList(growable: false);
  }

  String _readByHeader({
    required List<String> header,
    required List<String> cols,
    required List<String> keys,
  }) {
    for (final key in keys) {
      final index = header.indexOf(_normalizeKey(key));
      if (index >= 0 && index < cols.length) {
        return cols[index].trim();
      }
    }
    return '';
  }

  bool _isExcelExtension(String extension) {
    return extension == 'xlsx' || extension == 'xls' || extension == 'xlsm';
  }

  List<String> _inventoryTemplateHint(String extension) {
    return const [
      'Supported direct formats: CSV, TSV, JSON, TXT, XLSX.',
      'Inventory headers: name, hsn, unit, stock, purchase_rate, sales_rate, category.',
    ];
  }

  List<String> _ledgerTemplateHint(String extension) {
    return const [
      'Supported direct formats: CSV, TSV, JSON, TXT, XLSX.',
      'Ledger headers: ledger_name, ledger_group, mobile, email, gstin, pan, opening_balance.',
    ];
  }

  String _generateToken() {
    final rand = Random.secure();
    final chars = List.generate(10, (_) {
      final idx = rand.nextInt(_tokenCharset.length);
      return _tokenCharset[idx];
    }).join();
    return 'SYNC-$chars';
  }
}
