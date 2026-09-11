import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/core/location/standard_address.dart';

class ClientProfileData {
  final String clientId;
  final String name;
  final String email;
  final String mobile;
  final String firmName;
  final String gstin;
  final String pan;
  final String aadhaar;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final StandardAddress? registeredLocation;
  final String logoPath;
  final String logoDataBase64;
  final String logoFileName;
  final String invoiceFormat;
  final String gstCertificatePath;
  final String panCardPath;
  final String aadhaarCardPath;
  final String caMembershipCertificatePath;
  final String copCertificatePath;
  final String firmRegistrationCertificatePath;
  final String authorityLetterPath;
  final DateTime? lastUpdatedAt;

  const ClientProfileData({
    required this.clientId,
    this.name = '',
    this.email = '',
    this.mobile = '',
    this.firmName = '',
    this.gstin = '',
    this.pan = '',
    this.aadhaar = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.country = 'India',
    this.registeredLocation,
    this.logoPath = '',
    this.logoDataBase64 = '',
    this.logoFileName = '',
    this.invoiceFormat = 'Classic',
    this.gstCertificatePath = '',
    this.panCardPath = '',
    this.aadhaarCardPath = '',
    this.caMembershipCertificatePath = '',
    this.copCertificatePath = '',
    this.firmRegistrationCertificatePath = '',
    this.authorityLetterPath = '',
    this.lastUpdatedAt,
  });

  ClientProfileData copyWith({
    String? clientId,
    String? name,
    String? email,
    String? mobile,
    String? firmName,
    String? gstin,
    String? pan,
    String? aadhaar,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? country,
    StandardAddress? registeredLocation,
    String? logoPath,
    String? logoDataBase64,
    String? logoFileName,
    String? invoiceFormat,
    String? gstCertificatePath,
    String? panCardPath,
    String? aadhaarCardPath,
    String? caMembershipCertificatePath,
    String? copCertificatePath,
    String? firmRegistrationCertificatePath,
    String? authorityLetterPath,
    DateTime? lastUpdatedAt,
  }) {
    return ClientProfileData(
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      firmName: firmName ?? this.firmName,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      aadhaar: aadhaar ?? this.aadhaar,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,
      registeredLocation: registeredLocation ?? this.registeredLocation,
      logoPath: logoPath ?? this.logoPath,
      logoDataBase64: logoDataBase64 ?? this.logoDataBase64,
      logoFileName: logoFileName ?? this.logoFileName,
      invoiceFormat: invoiceFormat ?? this.invoiceFormat,
      gstCertificatePath: gstCertificatePath ?? this.gstCertificatePath,
      panCardPath: panCardPath ?? this.panCardPath,
      aadhaarCardPath: aadhaarCardPath ?? this.aadhaarCardPath,
      caMembershipCertificatePath:
          caMembershipCertificatePath ?? this.caMembershipCertificatePath,
      copCertificatePath: copCertificatePath ?? this.copCertificatePath,
      firmRegistrationCertificatePath:
          firmRegistrationCertificatePath ?? this.firmRegistrationCertificatePath,
      authorityLetterPath: authorityLetterPath ?? this.authorityLetterPath,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'name': name,
        'email': email,
        'mobile': mobile,
        'firmName': firmName,
        'gstin': gstin,
        'pan': pan,
        'aadhaar': aadhaar,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': country,
        if (registeredLocation != null)
          'registeredLocation': registeredLocation!.toMap(),
        'logoPath': logoPath,
        'logoDataBase64': logoDataBase64,
        'logoFileName': logoFileName,
        'invoiceFormat': invoiceFormat,
        'gstCertificatePath': gstCertificatePath,
        'panCardPath': panCardPath,
        'aadhaarCardPath': aadhaarCardPath,
        'caMembershipCertificatePath': caMembershipCertificatePath,
        'copCertificatePath': copCertificatePath,
        'firmRegistrationCertificatePath': firmRegistrationCertificatePath,
        'authorityLetterPath': authorityLetterPath,
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      };

  factory ClientProfileData.fromJson(Map<String, dynamic> json) {
    return ClientProfileData(
      clientId: (json['clientId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      mobile: (json['mobile'] as String?) ?? '',
      firmName: (json['firmName'] as String?) ?? '',
      gstin: (json['gstin'] as String?) ?? '',
      pan: (json['pan'] as String?) ?? '',
      aadhaar: (json['aadhaar'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      pincode: (json['pincode'] as String?) ?? '',
      country: (json['country'] as String?) ?? 'India',
      registeredLocation: json['registeredLocation'] is Map
          ? StandardAddress.fromMap(
              Map<String, dynamic>.from(json['registeredLocation'] as Map),
            )
          : null,
      logoPath: (json['logoPath'] as String?) ?? '',
      logoDataBase64: (json['logoDataBase64'] as String?) ?? '',
      logoFileName: (json['logoFileName'] as String?) ?? '',
      invoiceFormat: (json['invoiceFormat'] as String?) ?? 'Classic',
      gstCertificatePath: (json['gstCertificatePath'] as String?) ?? '',
      panCardPath: (json['panCardPath'] as String?) ?? '',
      aadhaarCardPath: (json['aadhaarCardPath'] as String?) ?? '',
        caMembershipCertificatePath:
          (json['caMembershipCertificatePath'] as String?) ?? '',
        copCertificatePath: (json['copCertificatePath'] as String?) ?? '',
        firmRegistrationCertificatePath:
          (json['firmRegistrationCertificatePath'] as String?) ?? '',
        authorityLetterPath: (json['authorityLetterPath'] as String?) ?? '',
      lastUpdatedAt: json['lastUpdatedAt'] == null
          ? null
          : DateTime.tryParse(json['lastUpdatedAt'] as String),
    );
  }
}

class ClientProfileService {
  static String _profileKey(String clientId) => 'client_profile_$clientId';

  Future<ClientProfileData?> load(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey(clientId));
    if (raw == null || raw.trim().isEmpty) return null;
    return ClientProfileData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ClientProfileData profile) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = profile.copyWith(lastUpdatedAt: DateTime.now());
    await prefs.setString(_profileKey(profile.clientId), jsonEncode(payload.toJson()));
  }
}
