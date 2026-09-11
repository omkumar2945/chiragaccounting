import 'package:chirag_accounting/core/location/standard_address.dart';

enum OrganizationStatus { active, inactive, archived }

class AdminCompany {
  const AdminCompany({
    required this.id,
    required this.name,
    required this.legalName,
    required this.createdAt,
    this.gstin = '',
    this.pan = '',
    this.currencyCode = 'INR',
    this.status = OrganizationStatus.active,
  });

  final String id;
  final String name;
  final String legalName;
  final String gstin;
  final String pan;
  final String currencyCode;
  final OrganizationStatus status;
  final DateTime createdAt;

  AdminCompany copyWith({
    String? name,
    String? legalName,
    String? gstin,
    String? pan,
    String? currencyCode,
    OrganizationStatus? status,
  }) {
    return AdminCompany(
      id: id,
      name: name ?? this.name,
      legalName: legalName ?? this.legalName,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      currencyCode: currencyCode ?? this.currencyCode,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'legalName': legalName,
        'gstin': gstin,
        'pan': pan,
        'currencyCode': currencyCode,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AdminCompany.fromMap(Map<String, dynamic> map) {
    return AdminCompany(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      legalName: map['legalName']?.toString() ?? '',
      gstin: map['gstin']?.toString() ?? '',
      pan: map['pan']?.toString() ?? '',
      currencyCode: map['currencyCode']?.toString() ?? 'INR',
      status: _organizationStatusFrom(map['status']),
      createdAt: _dateTimeFrom(map['createdAt']),
    );
  }
}

class AdminBranch {
  const AdminBranch({
    required this.id,
    required this.companyId,
    required this.name,
    this.code = '',
    this.address = '',
    this.location,
    this.status = OrganizationStatus.active,
  });

  final String id;
  final String companyId;
  final String name;
  final String code;
  final String address;
  final StandardAddress? location;
  final OrganizationStatus status;

  AdminBranch copyWith({
    String? name,
    String? code,
    String? address,
    StandardAddress? location,
    OrganizationStatus? status,
  }) {
    return AdminBranch(
      id: id,
      companyId: companyId,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      location: location ?? this.location,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'companyId': companyId,
        'name': name,
        'code': code,
        'address': address,
        if (location != null) 'location': location!.toMap(),
        'status': status.name,
      };

  factory AdminBranch.fromMap(Map<String, dynamic> map) {
    return AdminBranch(
      id: map['id']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      location: map['location'] is Map
          ? StandardAddress.fromMap(
              Map<String, dynamic>.from(map['location'] as Map),
            )
          : null,
      status: _organizationStatusFrom(map['status']),
    );
  }
}

class AdminDepartment {
  const AdminDepartment({
    required this.id,
    required this.companyId,
    required this.branchId,
    required this.name,
    this.code = '',
    this.managerUserId = '',
    this.status = OrganizationStatus.active,
  });

  final String id;
  final String companyId;
  final String branchId;
  final String name;
  final String code;
  final String managerUserId;
  final OrganizationStatus status;

  AdminDepartment copyWith({
    String? name,
    String? code,
    String? managerUserId,
    OrganizationStatus? status,
  }) {
    return AdminDepartment(
      id: id,
      companyId: companyId,
      branchId: branchId,
      name: name ?? this.name,
      code: code ?? this.code,
      managerUserId: managerUserId ?? this.managerUserId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'companyId': companyId,
        'branchId': branchId,
        'name': name,
        'code': code,
        'managerUserId': managerUserId,
        'status': status.name,
      };

  factory AdminDepartment.fromMap(Map<String, dynamic> map) {
    return AdminDepartment(
      id: map['id']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      branchId: map['branchId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      managerUserId: map['managerUserId']?.toString() ?? '',
      status: _organizationStatusFrom(map['status']),
    );
  }
}

OrganizationStatus _organizationStatusFrom(Object? value) {
  return OrganizationStatus.values.firstWhere(
    (status) => status.name == value?.toString(),
    orElse: () => OrganizationStatus.active,
  );
}

DateTime _dateTimeFrom(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
