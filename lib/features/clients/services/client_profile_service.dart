import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

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
          firmRegistrationCertificatePath ??
          this.firmRegistrationCertificatePath,
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

  factory ClientProfileData.fromAuthoritativeJson(
    Map<String, dynamic> json, {
    ClientProfileData? localOnlyData,
  }) {
    final client = _asMap(json['client']);
    final profile = _asMap(json['profile']);
    final location = profile['registeredLocation'];
    return ClientProfileData(
      clientId: _readString(client, 'id'),
      name: _readString(client, 'name'),
      email: _readString(client, 'email'),
      mobile: _readString(client, 'mobile'),
      firmName: _readString(client, 'firmName'),
      gstin: _readString(profile, 'gstin'),
      pan: _readString(profile, 'pan'),
      aadhaar: _readString(profile, 'aadhaar'),
      address: _readString(profile, 'address'),
      city: _readString(profile, 'city'),
      state: _readString(profile, 'state'),
      pincode: _readString(profile, 'pincode'),
      country: _readString(profile, 'country', fallback: 'India'),
      registeredLocation: location is Map
          ? StandardAddress.fromMap(Map<String, dynamic>.from(location))
          : null,
      logoPath: localOnlyData?.logoPath ?? '',
      logoDataBase64: _readString(profile, 'logoDataBase64'),
      logoFileName: _readString(profile, 'logoFileName'),
      invoiceFormat: _readString(profile, 'invoiceFormat', fallback: 'Classic'),
      gstCertificatePath: localOnlyData?.gstCertificatePath ?? '',
      panCardPath: localOnlyData?.panCardPath ?? '',
      aadhaarCardPath: localOnlyData?.aadhaarCardPath ?? '',
      caMembershipCertificatePath:
          localOnlyData?.caMembershipCertificatePath ?? '',
      copCertificatePath: localOnlyData?.copCertificatePath ?? '',
      firmRegistrationCertificatePath:
          localOnlyData?.firmRegistrationCertificatePath ?? '',
      authorityLetterPath: localOnlyData?.authorityLetterPath ?? '',
      lastUpdatedAt: DateTime.tryParse(_readString(profile, 'lastUpdatedAt')),
    );
  }

  Map<String, dynamic> toAuthoritativeProfilePatch() {
    final patch = <String, dynamic>{};
    void addText(String key, String value) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) patch[key] = normalized;
    }

    addText('name', name);
    addText('firmName', firmName);
    addText('gstin', gstin.toUpperCase());
    addText('pan', pan.toUpperCase());
    addText('aadhaar', aadhaar);
    addText('address', address);
    addText('city', city);
    addText('state', state);
    addText('pincode', pincode);
    addText('country', country);
    addText('logoFileName', logoFileName);
    addText('logoDataBase64', logoDataBase64);
    addText('invoiceFormat', invoiceFormat);
    if (registeredLocation != null) {
      patch['registeredLocation'] = registeredLocation!.toMap();
    }
    return patch;
  }

  static Map<String, dynamic> _asMap(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  static String _readString(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) {
    final value = json[key];
    return value == null ? fallback : value.toString();
  }
}

class ClientProfileService {
  ClientProfileService({
    SharedPreferences? preferences,
    Dio? dio,
    bool? useRemoteApi,
  }) : _preferences = preferences,
       _dio = dio ?? ApiClient.dio,
       _useRemoteApi = useRemoteApi ?? !ApiConstants.useMockApi;

  static String _legacyProfileKey(String clientId) =>
      'client_profile_$clientId';
  static String _authoritativeCacheKey(String clientId) =>
      'client_profile_authoritative_cache_v1_$clientId';

  final SharedPreferences? _preferences;
  final Dio _dio;
  final bool _useRemoteApi;

  Future<ClientProfileData?> load(
    String clientId, {
    bool useAuthoritativeClientApi = false,
  }) async {
    final preferences = await _getPreferences();
    final legacy = _decodeProfile(
      preferences.getString(_legacyProfileKey(clientId)),
    );
    final cachedAuthoritative = _decodeProfile(
      preferences.getString(_authoritativeCacheKey(clientId)),
    );
    if (!useAuthoritativeClientApi || !_useRemoteApi) return legacy;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.clientAuthoritative(clientId),
      );
      final authoritative = ClientProfileData.fromAuthoritativeJson(
        _responseData(response),
        localOnlyData: legacy ?? cachedAuthoritative,
      );
      await _cacheAuthoritative(preferences, authoritative);
      return authoritative;
    } on DioException {
      return cachedAuthoritative ?? legacy;
    }
  }

  Future<void> save(
    ClientProfileData profile, {
    bool useAuthoritativeClientApi = false,
  }) async {
    final preferences = await _getPreferences();
    final payload = profile.copyWith(lastUpdatedAt: DateTime.now());
    if (!useAuthoritativeClientApi || !_useRemoteApi) {
      await preferences.setString(
        _legacyProfileKey(profile.clientId),
        jsonEncode(payload.toJson()),
      );
      return;
    }

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiConstants.clientProfile(profile.clientId),
        data: payload.toAuthoritativeProfilePatch(),
      );
      final authoritative = ClientProfileData.fromAuthoritativeJson(
        _responseData(response),
        localOnlyData: payload,
      );
      await _cacheAuthoritative(preferences, authoritative);
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<SharedPreferences> _getPreferences() async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<void> _cacheAuthoritative(
    SharedPreferences preferences,
    ClientProfileData profile,
  ) => preferences.setString(
    _authoritativeCacheKey(profile.clientId),
    jsonEncode(profile.toJson()),
  );

  ClientProfileData? _decodeProfile(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? ClientProfileData.fromJson(Map<String, dynamic>.from(decoded))
          : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _responseData(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException(
      'The server returned an invalid client profile.',
    );
  }
}
