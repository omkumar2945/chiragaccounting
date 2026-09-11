import 'package:flutter/foundation.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';

@immutable
class Customer {
  final String id;

  /// Basic Details
  final String customerCode;
  final String customerName;
  final String companyName;

  /// Contact Details
  final String mobileNumber;
  final String alternateMobile;
  final String email;

  /// Tax Details
  final String taxPreference;
  final String gstNumber;
  final String panNumber;

  /// Address
  final String billingAddress;
  final String shippingAddress;
  final String state;
  final String city;
  final String pinCode;
  final String country;
  final StandardAddress? billingLocation;
  final StandardAddress? shippingLocation;

  /// Ledger Details
  final String ledgerGroup;
  final double openingBalance;
  final double creditLimit;

  /// Status
  final bool isActive;

  const Customer({
    required this.id,
    required this.customerCode,
    required this.customerName,
    this.companyName = '',
    this.mobileNumber = '',
    this.alternateMobile = '',
    this.email = '',
    this.taxPreference = 'GST Registered',
    this.gstNumber = '',
    this.panNumber = '',
    this.billingAddress = '',
    this.shippingAddress = '',
    this.state = '',
    this.city = '',
    this.pinCode = '',
    this.country = 'India',
    this.billingLocation,
    this.shippingLocation,
    this.ledgerGroup = 'Sundry Debtors',
    this.openingBalance = 0,
    this.creditLimit = 0,
    this.isActive = true,
  });

  Customer copyWith({
    String? id,
    String? customerCode,
    String? customerName,
    String? companyName,
    String? mobileNumber,
    String? alternateMobile,
    String? email,
    String? taxPreference,
    String? gstNumber,
    String? panNumber,
    String? billingAddress,
    String? shippingAddress,
    String? state,
    String? city,
    String? pinCode,
    String? country,
    StandardAddress? billingLocation,
    StandardAddress? shippingLocation,
    String? ledgerGroup,
    double? openingBalance,
    double? creditLimit,
    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      customerName: customerName ?? this.customerName,
      companyName: companyName ?? this.companyName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      alternateMobile: alternateMobile ?? this.alternateMobile,
      email: email ?? this.email,
      taxPreference: taxPreference ?? this.taxPreference,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      state: state ?? this.state,
      city: city ?? this.city,
      pinCode: pinCode ?? this.pinCode,
      country: country ?? this.country,
      billingLocation: billingLocation ?? this.billingLocation,
      shippingLocation: shippingLocation ?? this.shippingLocation,
      ledgerGroup: ledgerGroup ?? this.ledgerGroup,
      openingBalance: openingBalance ?? this.openingBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerCode': customerCode,
      'customerName': customerName,
      'companyName': companyName,
      'mobileNumber': mobileNumber,
      'alternateMobile': alternateMobile,
      'email': email,
      'taxPreference': taxPreference,
      'gstNumber': gstNumber,
      'panNumber': panNumber,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'state': state,
      'city': city,
      'pinCode': pinCode,
      'country': country,
      if (billingLocation != null) 'billingLocation': billingLocation!.toMap(),
      if (shippingLocation != null)
        'shippingLocation': shippingLocation!.toMap(),
      'ledgerGroup': ledgerGroup,
      'openingBalance': openingBalance,
      'creditLimit': creditLimit,
      'isActive': isActive,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      customerCode: map['customerCode'] ?? '',
      customerName: map['customerName'] ?? '',
      companyName: map['companyName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      alternateMobile: map['alternateMobile'] ?? '',
      email: map['email'] ?? '',
      taxPreference: map['taxPreference'] ?? 'GST Registered',
      gstNumber: map['gstNumber'] ?? '',
      panNumber: map['panNumber'] ?? '',
      billingAddress: map['billingAddress'] ?? '',
      shippingAddress: map['shippingAddress'] ?? '',
      state: map['state'] ?? '',
      city: map['city'] ?? '',
      pinCode: map['pinCode'] ?? '',
      country: map['country'] ?? 'India',
      billingLocation: map['billingLocation'] is Map
          ? StandardAddress.fromMap(
              Map<String, dynamic>.from(map['billingLocation'] as Map),
            )
          : null,
      shippingLocation: map['shippingLocation'] is Map
          ? StandardAddress.fromMap(
              Map<String, dynamic>.from(map['shippingLocation'] as Map),
            )
          : null,
      ledgerGroup: map['ledgerGroup'] ?? 'Sundry Debtors',
      openingBalance: (map['openingBalance'] ?? 0).toDouble(),
      creditLimit: (map['creditLimit'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}