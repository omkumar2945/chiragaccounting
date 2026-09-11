import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/location/standard_address.dart';

@immutable
class Vendor {
  final String id;
  final String vendorCode;
  final String vendorName;
  final String mobileNumber;
  final String email;
  final String gstNumber;
  final String billingAddress;
  final StandardAddress? billingLocation;
  final String ledgerGroup;
  final double openingBalance;
  final bool isActive;

  const Vendor({
    required this.id,
    required this.vendorCode,
    required this.vendorName,
    this.mobileNumber = '',
    this.email = '',
    this.gstNumber = '',
    this.billingAddress = '',
    this.billingLocation,
    this.ledgerGroup = 'Sundry Creditors',
    this.openingBalance = 0,
    this.isActive = true,
  });

  Vendor copyWith({
    String? id,
    String? vendorCode,
    String? vendorName,
    String? mobileNumber,
    String? email,
    String? gstNumber,
    String? billingAddress,
    StandardAddress? billingLocation,
    String? ledgerGroup,
    double? openingBalance,
    bool? isActive,
  }) {
    return Vendor(
      id: id ?? this.id,
      vendorCode: vendorCode ?? this.vendorCode,
      vendorName: vendorName ?? this.vendorName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      billingAddress: billingAddress ?? this.billingAddress,
      billingLocation: billingLocation ?? this.billingLocation,
      ledgerGroup: ledgerGroup ?? this.ledgerGroup,
      openingBalance: openingBalance ?? this.openingBalance,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'vendorCode': vendorCode,
      'vendorName': vendorName,
      'mobileNumber': mobileNumber,
      'email': email,
      'gstNumber': gstNumber,
      'billingAddress': billingAddress,
      'ledgerGroup': ledgerGroup,
      'openingBalance': openingBalance,
      'isActive': isActive,
      if (billingLocation != null) 'billingLocation': billingLocation!.toMap(),
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      id: map['id'] ?? '',
      vendorCode: map['vendorCode'] ?? '',
      vendorName: map['vendorName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      email: map['email'] ?? '',
      gstNumber: map['gstNumber'] ?? '',
      billingAddress: map['billingAddress'] ?? '',
      billingLocation: map['billingLocation'] is Map
          ? StandardAddress.fromMap(
              Map<String, dynamic>.from(map['billingLocation'] as Map),
            )
          : null,
      ledgerGroup: map['ledgerGroup'] ?? 'Sundry Creditors',
      openingBalance: (map['openingBalance'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
    );
  }
}
