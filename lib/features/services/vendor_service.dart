import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/location/standard_address.dart';

import '../vendors/models/vendor.dart';

class VendorService extends ChangeNotifier {
  final List<Vendor> _vendors = [];

  List<Vendor> get vendors => List.unmodifiable(_vendors);

  int get totalVendors => _vendors.length;

  int get activeVendors => _vendors.where((v) => v.isActive).length;

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _sanitizeMobile(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String nextVendorCode() {
    var maxSequence = 0;
    final pattern = RegExp(r'^VEND-(\d+)$');
    for (final vendor in _vendors) {
      final match = pattern.firstMatch(vendor.vendorCode.trim());
      if (match == null) continue;
      final seq = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (seq > maxSequence) {
        maxSequence = seq;
      }
    }
    return 'VEND-${(maxSequence + 1).toString().padLeft(4, '0')}';
  }

  Vendor? findIdentityMatch({
    required String name,
    String gstNumber = '',
    String mobileNumber = '',
    String? excludeVendorId,
  }) {
    final normalizedName = _normalize(name);
    final normalizedGstin = gstNumber.trim().toUpperCase();
    final normalizedMobile = _sanitizeMobile(mobileNumber);

    if (normalizedGstin.isNotEmpty) {
      for (final vendor in _vendors) {
        if (vendor.gstNumber.trim().toUpperCase() == normalizedGstin &&
            (excludeVendorId == null || vendor.id != excludeVendorId)) {
          return vendor;
        }
      }
    }

    if (normalizedMobile.isNotEmpty) {
      for (final vendor in _vendors) {
        if (_sanitizeMobile(vendor.mobileNumber) == normalizedMobile &&
            (excludeVendorId == null || vendor.id != excludeVendorId)) {
          return vendor;
        }
      }
    }

    if (normalizedName.isNotEmpty) {
      for (final vendor in _vendors) {
        if (_normalize(vendor.vendorName) == normalizedName &&
            (excludeVendorId == null || vendor.id != excludeVendorId)) {
          return vendor;
        }
      }
    }

    return null;
  }

  String? validateVendorForSave(Vendor vendor, [String? excludeVendorId]) {
    final matched = findIdentityMatch(
      name: vendor.vendorName,
      gstNumber: vendor.gstNumber,
      mobileNumber: vendor.mobileNumber,
      excludeVendorId: excludeVendorId,
    );

    if (matched != null) {
      return 'Duplicate vendor is not allowed. Existing match: ${matched.vendorName}';
    }

    return null;
  }

  void addVendor(Vendor vendor) {
    final validationError = validateVendorForSave(vendor);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }
    _vendors.add(vendor);
    notifyListeners();
  }

  void updateVendor(String vendorId, Vendor updatedVendor) {
    final validationError = validateVendorForSave(updatedVendor, vendorId);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final index = _vendors.indexWhere((v) => v.id == vendorId);
    if (index != -1) {
      _vendors[index] = updatedVendor;
      notifyListeners();
    }
  }

  void deleteVendor(String vendorId) {
    _vendors.removeWhere((v) => v.id == vendorId);
    notifyListeners();
  }

  Vendor? getVendorById(String vendorId) {
    try {
      return _vendors.firstWhere((v) => v.id == vendorId);
    } catch (_) {
      return null;
    }
  }

  List<Vendor> searchVendors(String query) {
    if (query.trim().isEmpty) return _vendors;
    final normalized = query.toLowerCase().trim();
    return _vendors
        .where((vendor) {
          return vendor.vendorName.toLowerCase().contains(normalized) ||
              vendor.vendorCode.toLowerCase().contains(normalized) ||
              vendor.mobileNumber.contains(query) ||
              vendor.email.toLowerCase().contains(normalized) ||
              vendor.gstNumber.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  void clearAllVendors() {
    _vendors.clear();
    notifyListeners();
  }

  Vendor resolveOrCreateVendor({
    required String name,
    String gstNumber = '',
    String mobileNumber = '',
    String email = '',
    String billingAddress = '',
    StandardAddress? billingLocation,
    String ledgerGroup = 'Sundry Creditors',
    double openingBalance = 0,
  }) {
    final existing = findIdentityMatch(
      name: name,
      gstNumber: gstNumber,
      mobileNumber: mobileNumber,
    );
    if (existing != null) {
      final updated = existing.copyWith(
        vendorName: name.trim(),
        gstNumber: gstNumber.trim().toUpperCase(),
        mobileNumber: mobileNumber.trim(),
        email: email.trim(),
        billingAddress: billingAddress.trim(),
        billingLocation: billingLocation ?? existing.billingLocation,
        ledgerGroup: ledgerGroup.trim().isEmpty
            ? existing.ledgerGroup
            : ledgerGroup.trim(),
        openingBalance: openingBalance,
      );
      updateVendor(existing.id, updated);
      return updated;
    }

    final vendor = Vendor(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      vendorCode: nextVendorCode(),
      vendorName: name.trim(),
      gstNumber: gstNumber.trim().toUpperCase(),
      mobileNumber: mobileNumber.trim(),
      email: email.trim(),
      billingAddress: billingAddress.trim(),
      billingLocation: billingLocation,
      ledgerGroup: ledgerGroup.trim().isEmpty
          ? 'Sundry Creditors'
          : ledgerGroup.trim(),
      openingBalance: openingBalance,
      isActive: true,
    );

    addVendor(vendor);
    return vendor;
  }
}
