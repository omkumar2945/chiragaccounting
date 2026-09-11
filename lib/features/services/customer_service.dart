import 'package:flutter/foundation.dart';
import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/core/events/event_types.dart';
import '../customers/models/customer.dart';
import 'ledger_service.dart';

class CustomerService extends ChangeNotifier {
  final List<Customer> _customers = [];

  String _normalizeValue(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _normalizeCode(String value) {
    return value.trim().toUpperCase();
  }

  String _normalizeDigits(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  String nextCustomerCode() {
    var maxSequence = 0;
    final pattern = RegExp(r'^CUSTID:(\d+)$');

    for (final customer in _customers) {
      final match = pattern.firstMatch(customer.customerCode.trim().toUpperCase());
      if (match == null) continue;
      final sequence = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (sequence > maxSequence) {
        maxSequence = sequence;
      }
    }

    return 'CUSTID:${(maxSequence + 1).toString().padLeft(5, '0')}';
  }

  /// Get all customers
  List<Customer> get customers => List.unmodifiable(_customers);

  /// Get total customers count
  int get totalCustomers => _customers.length;

  /// Get active customers count
  int get activeCustomers => _customers.where((c) => c.isActive).length;

  /// Get total credit limit
  double get totalCreditLimit {
    return _customers.fold(0.0, (sum, customer) => sum + customer.creditLimit);
  }

  /// Add new customer
  void addCustomer(Customer customer) {
    final validationError = validateCustomerForSave(customer);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    _customers.add(customer);
    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.customerCreated,
        module: 'client',
        action: 'created',
        entityType: 'customer',
        entityId: customer.id,
        clientId: customer.customerName,
        role: 'admin',
        payload: <String, dynamic>{
          'clientName': customer.customerName,
          'customerCode': customer.customerCode,
          'summary': 'Customer ${customer.customerName} created',
        },
      ),
    );
    notifyListeners();
  }

  /// Update existing customer
  void updateCustomer(String customerId, Customer updatedCustomer) {
    final validationError = validateCustomerForSave(
      updatedCustomer,
      customerId,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      _customers[index] = updatedCustomer;
      AppEventBus.instance.publish(
        AppEvent.create(
          eventType: EventTypes.customerUpdated,
          module: 'client',
          action: 'updated',
          entityType: 'customer',
          entityId: updatedCustomer.id,
          clientId: updatedCustomer.customerName,
          role: 'admin',
          payload: <String, dynamic>{
            'clientName': updatedCustomer.customerName,
            'customerCode': updatedCustomer.customerCode,
            'summary': 'Customer ${updatedCustomer.customerName} updated',
          },
        ),
      );
      notifyListeners();
    }
  }

  /// Delete customer
  void deleteCustomer(String customerId) {
    Customer? existing;
    for (final customer in _customers) {
      if (customer.id == customerId) {
        existing = customer;
        break;
      }
    }
    _customers.removeWhere((c) => c.id == customerId);
    if (existing != null) {
      AppEventBus.instance.publish(
        AppEvent.create(
          eventType: EventTypes.customerDeleted,
          module: 'client',
          action: 'deleted',
          entityType: 'customer',
          entityId: customerId,
          clientId: existing.customerName,
          role: 'admin',
          payload: <String, dynamic>{
            'clientName': existing.customerName,
            'customerCode': existing.customerCode,
            'summary': 'Customer ${existing.customerName} deleted',
          },
        ),
      );
    }
    notifyListeners();
  }

  /// Get customer by ID
  Customer? getCustomerById(String customerId) {
    try {
      return _customers.firstWhere((c) => c.id == customerId);
    } catch (e) {
      return null;
    }
  }

  /// Search customers by name or email
  List<Customer> searchCustomers(String query) {
    if (query.isEmpty) {
      return _customers;
    }

    final lowerQuery = query.toLowerCase();
    return _customers
        .where((customer) =>
            customer.customerName.toLowerCase().contains(lowerQuery) ||
            customer.email.toLowerCase().contains(lowerQuery) ||
            customer.mobileNumber.contains(query))
        .toList();
  }

  /// Get customers by type
  List<Customer> getCustomersByType(String type) {
    return _customers.where((c) => c.customerCode.contains(type)).toList();
  }

  /// Get active customers only
  List<Customer> getActiveCustomers() {
    return _customers.where((c) => c.isActive).toList();
  }

  /// Update customer status
  void updateCustomerStatus(String customerId, bool isActive) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      _customers[index] = _customers[index].copyWith(isActive: isActive);
      notifyListeners();
    }
  }

  /// Get customers with outstanding balance
  List<Customer> getCustomersWithBalance() {
    return _customers.where((c) => c.openingBalance > 0).toList();
  }

  /// Clear all customers
  void clearAllCustomers() {
    _customers.clear();
    notifyListeners();
  }

  /// Check if customer email exists
  bool isEmailExists(String email, [String? excludeCustomerId]) {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) return false;

    return _customers.any((c) =>
      _normalizeEmail(c.email) == normalizedEmail &&
      (excludeCustomerId == null || c.id != excludeCustomerId));
  }

  /// Check if customer code exists
  bool isCustomerCodeExists(String code, [String? excludeCustomerId]) {
    final normalizedCode = _normalizeCode(code);
    if (normalizedCode.isEmpty) return false;

    return _customers.any((c) =>
      _normalizeCode(c.customerCode) == normalizedCode &&
        (excludeCustomerId == null || c.id != excludeCustomerId));
  }

  bool isExactCustomerNameExists(String name, [String? excludeCustomerId]) {
    final normalizedName = _normalizeValue(name);
    if (normalizedName.isEmpty) return false;

    return _customers.any((c) =>
        _normalizeValue(c.customerName) == normalizedName &&
        (excludeCustomerId == null || c.id != excludeCustomerId));
  }

  /// ──────────────────────────────────────────────────────────────────────
  /// DUPLICATE RESTRICTIONS & IDENTITY MANAGEMENT
  /// ──────────────────────────────────────────────────────────────────────

  /// ❌ GSTIN - Strict: One GSTIN = One customer
  bool isGstinExists(String gstin, [String? excludeCustomerId]) {
    final normalizedGstin = _normalizeCode(gstin);
    if (normalizedGstin.isEmpty) return false;
    return _customers.any((c) =>
      _normalizeCode(c.gstNumber) == normalizedGstin &&
      (excludeCustomerId == null || c.id != excludeCustomerId));
  }

  /// ❌ PAN - Strict: One PAN = One customer (optional field)
  bool isPanExists(String pan, [String? excludeCustomerId]) {
    final normalizedPan = _normalizeCode(pan);
    if (normalizedPan.isEmpty) return false;
    return _customers.any((c) =>
      _normalizeCode(c.panNumber) == normalizedPan &&
      (excludeCustomerId == null || c.id != excludeCustomerId));
  }

  /// ⚠️ Mobile - Warning: Check for duplicate mobile numbers
  List<Customer> findDuplicatesByMobile(String mobile, [String? excludeCustomerId]) {
    final normalizedMobile = _normalizeDigits(mobile);
    if (normalizedMobile.isEmpty) return [];
    return _customers
      .where((c) =>
        (_normalizeDigits(c.mobileNumber) == normalizedMobile ||
          _normalizeDigits(c.alternateMobile) == normalizedMobile) &&
        (excludeCustomerId == null || c.id != excludeCustomerId))
        .toList();
  }

  /// ⚠️ Email - Warning: Check for duplicate emails
  List<Customer> findDuplicatesByEmail(String email, [String? excludeCustomerId]) {
    final lowerEmail = _normalizeEmail(email);
    if (lowerEmail.isEmpty) return [];
    return _customers
      .where((c) =>
        _normalizeEmail(c.email) == lowerEmail &&
        (excludeCustomerId == null || c.id != excludeCustomerId))
        .toList();
  }

  /// ⚠️ Name - Warning: Check for similar customer names
  List<Customer> findSimilarNames(String name, [String? excludeCustomerId]) {
    if (name.isEmpty) return [];
    final lowerName = name.toLowerCase();
    return _customers
        .where((c) => 
            c.customerName.toLowerCase().contains(lowerName) && 
            (excludeCustomerId == null || c.id != excludeCustomerId))
        .toList();
  }

  /// ❌ Name + City - Strict: Prevent accidental duplicate (configurable)
  bool isNameCityCombinationExists(String name, String city, [String? excludeCustomerId]) {
    if (name.isEmpty || city.isEmpty) return false;
    return _customers.any((c) => 
        _normalizeValue(c.customerName) == _normalizeValue(name) && 
        _normalizeValue(c.city) == _normalizeValue(city) && 
        (excludeCustomerId == null || c.id != excludeCustomerId));
  }

  String? validateCustomerForSave(
    Customer customer, [
    String? excludeCustomerId,
  ]) {
    final customerCode = customer.customerCode.trim();
    if (customerCode.isNotEmpty &&
        isCustomerCodeExists(customerCode, excludeCustomerId)) {
      return 'Duplicate customer code is not allowed. This code already exists.';
    }

    final gstin = customer.gstNumber.trim().toUpperCase();
    if (gstin.isNotEmpty && isGstinExists(gstin, excludeCustomerId)) {
      return 'Duplicate GSTIN is not allowed. This GST number already exists.';
    }

    final pan = customer.panNumber.trim().toUpperCase();
    if (pan.isNotEmpty && isPanExists(pan, excludeCustomerId)) {
      return 'Duplicate PAN is not allowed. This PAN number already exists.';
    }

    final mobile = _normalizeDigits(customer.mobileNumber);
    if (mobile.isNotEmpty && findDuplicatesByMobile(customer.mobileNumber, excludeCustomerId).isNotEmpty) {
      return 'Duplicate mobile number is not allowed. This contact number already exists.';
    }

    final alternateMobile = _normalizeDigits(customer.alternateMobile);
    if (alternateMobile.isNotEmpty && findDuplicatesByMobile(customer.alternateMobile, excludeCustomerId).isNotEmpty) {
      return 'Duplicate alternate mobile number is not allowed. This contact number already exists.';
    }

    final email = _normalizeEmail(customer.email);
    if (email.isNotEmpty && isEmailExists(email, excludeCustomerId)) {
      return 'Duplicate email is not allowed. This contact email already exists.';
    }

    if (
        gstin.isEmpty &&
        isExactCustomerNameExists(customer.customerName, excludeCustomerId)) {
      return 'Duplicate customer name is not allowed when GST number is blank.';
    }

    return null;
  }

  /// Get all duplicate issues for a customer (returns map of check type → findings)
  Map<String, dynamic> checkDuplicates(
    Customer customer, [
    String? excludeCustomerId,
  ]) {
    return {
      'gstinExists': isGstinExists(customer.gstNumber, excludeCustomerId),
      'panExists': isPanExists(customer.panNumber, excludeCustomerId),
      'mobileWarnings': findDuplicatesByMobile(customer.mobileNumber, excludeCustomerId),
      'emailWarnings': findDuplicatesByEmail(customer.email, excludeCustomerId),
      'nameWarnings': findSimilarNames(customer.customerName, excludeCustomerId),
      'exactNameExists':
          isExactCustomerNameExists(customer.customerName, excludeCustomerId),
      'nameCityCombinationExists':
          isNameCityCombinationExists(customer.customerName, customer.city, excludeCustomerId),
    };
  }

  Customer? findIdentityMatch(
    String name, {
    String gstNumber = '',
    String mobileNumber = '',
    String? excludeCustomerId,
  }) {
    final normalizedName = _normalizeValue(name);
    final normalizedGstin = gstNumber.trim().toUpperCase();
    final normalizedMobile = mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (normalizedGstin.isNotEmpty) {
      for (final customer in _customers) {
        if (customer.gstNumber.trim().toUpperCase() == normalizedGstin &&
            (excludeCustomerId == null || customer.id != excludeCustomerId)) {
          return customer;
        }
      }
    }

    if (normalizedMobile.isNotEmpty) {
      for (final customer in _customers) {
        final mobile = customer.mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');
        final altMobile = customer.alternateMobile.replaceAll(RegExp(r'[^0-9]'), '');
        if ((mobile == normalizedMobile || altMobile == normalizedMobile) &&
            (excludeCustomerId == null || customer.id != excludeCustomerId)) {
          return customer;
        }
      }
    }

    if (normalizedName.isNotEmpty) {
      for (final customer in _customers) {
        if (_normalizeValue(customer.customerName) == normalizedName &&
            (excludeCustomerId == null || customer.id != excludeCustomerId)) {
          return customer;
        }
      }
    }

    return null;
  }

  Customer addCustomerWithLedger(Customer customer, [LedgerService? ledgerService]) {
    addCustomer(customer);
    ledgerService
        ?.ensureCustomerLedger(
          customerName: customer.customerName,
          ledgerGroup: customer.ledgerGroup,
        )
        .catchError((_) {});
    return customer;
  }
}
