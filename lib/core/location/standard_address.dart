class StandardAddress {
  const StandardAddress({
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.countryId = 'IN',
    this.countryName = 'India',
    this.stateId = '',
    this.stateName = '',
    this.cityId = '',
    this.cityName = '',
    this.district = '',
    this.pincode = '',
    this.locality = '',
    this.postOffice = '',
    this.latitude,
    this.longitude,
    this.source = 'manual',
  });

  final String addressLine1;
  final String addressLine2;
  final String countryId;
  final String countryName;
  final String stateId;
  final String stateName;
  final String cityId;
  final String cityName;
  final String district;
  final String pincode;
  final String locality;
  final String postOffice;
  final double? latitude;
  final double? longitude;
  final String source;

  String get enteredAddress => <String>[
    addressLine1,
    addressLine2,
    locality,
    cityName,
    district == cityName ? '' : district,
    stateName,
    pincode,
    countryName,
  ].where((value) => value.trim().isNotEmpty).join(', ');

  bool get isEmpty =>
      addressLine1.trim().isEmpty &&
      cityName.trim().isEmpty &&
      stateName.trim().isEmpty &&
      pincode.trim().isEmpty;

  StandardAddress copyWith({
    String? addressLine1,
    String? addressLine2,
    String? countryId,
    String? countryName,
    String? stateId,
    String? stateName,
    String? cityId,
    String? cityName,
    String? district,
    String? pincode,
    String? locality,
    String? postOffice,
    double? latitude,
    double? longitude,
    String? source,
  }) {
    return StandardAddress(
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      locality: locality ?? this.locality,
      postOffice: postOffice ?? this.postOffice,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'countryId': countryId,
    'countryName': countryName,
    'stateId': stateId,
    'stateName': stateName,
    'cityId': cityId,
    'cityName': cityName,
    'district': district,
    'pincode': pincode,
    'locality': locality,
    'postOffice': postOffice,
    'latitude': latitude,
    'longitude': longitude,
    'source': source,
  };

  factory StandardAddress.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StandardAddress();
    return StandardAddress(
      addressLine1: map['addressLine1']?.toString() ?? '',
      addressLine2: map['addressLine2']?.toString() ?? '',
      countryId: map['countryId']?.toString() ?? 'IN',
      countryName: map['countryName']?.toString() ?? 'India',
      stateId: map['stateId']?.toString() ?? '',
      stateName: map['stateName']?.toString() ?? '',
      cityId: map['cityId']?.toString() ?? '',
      cityName: map['cityName']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '',
      locality: map['locality']?.toString() ?? '',
      postOffice: map['postOffice']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      source: map['source']?.toString() ?? 'manual',
    );
  }

  factory StandardAddress.fromLegacy({
    required String address,
    String state = '',
    String city = '',
    String pincode = '',
    String country = 'India',
  }) {
    return StandardAddress(
      addressLine1: address,
      countryId: country.toLowerCase() == 'india' ? 'IN' : '',
      countryName: country,
      stateName: state,
      cityName: city,
      district: city,
      pincode: pincode,
      source: 'legacy',
    );
  }
}

class AddressValidationResult {
  const AddressValidationResult({
    required this.isValid,
    this.message = '',
  });

  final bool isValid;
  final String message;
}

const Map<String, String> kIndianGstStateCodes = <String, String>{
  'jammu and kashmir': '01',
  'himachal pradesh': '02',
  'punjab': '03',
  'chandigarh': '04',
  'uttarakhand': '05',
  'haryana': '06',
  'delhi': '07',
  'rajasthan': '08',
  'uttar pradesh': '09',
  'bihar': '10',
  'sikkim': '11',
  'arunachal pradesh': '12',
  'nagaland': '13',
  'manipur': '14',
  'mizoram': '15',
  'tripura': '16',
  'meghalaya': '17',
  'assam': '18',
  'west bengal': '19',
  'jharkhand': '20',
  'odisha': '21',
  'chhattisgarh': '22',
  'madhya pradesh': '23',
  'gujarat': '24',
  'dadra and nagar haveli and daman and diu': '26',
  'maharashtra': '27',
  'andhra pradesh': '28',
  'karnataka': '29',
  'goa': '30',
  'lakshadweep': '31',
  'kerala': '32',
  'tamil nadu': '33',
  'puducherry': '34',
  'andaman and nicobar islands': '35',
  'telangana': '36',
  'andhra pradesh (new)': '37',
  'ladakh': '38',
  'other territory': '97',
};

AddressValidationResult validateAddressTaxIdentity({
  required StandardAddress address,
  String gstin = '',
  String pan = '',
}) {
  final normalizedGstin = gstin.trim().toUpperCase();
  final normalizedPan = pan.trim().toUpperCase();
  if (normalizedGstin.isNotEmpty &&
      !RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
          .hasMatch(normalizedGstin)) {
    return const AddressValidationResult(
      isValid: false,
      message: 'Enter a valid 15-character GSTIN.',
    );
  }
  if (normalizedPan.isNotEmpty &&
      !RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(normalizedPan)) {
    return const AddressValidationResult(
      isValid: false,
      message: 'Enter a valid 10-character PAN.',
    );
  }
  if (normalizedGstin.isNotEmpty && address.countryId == 'IN') {
    final expectedCode = kIndianGstStateCodes[address.stateName
        .trim()
        .toLowerCase()];
    if (expectedCode != null && !normalizedGstin.startsWith(expectedCode)) {
      return AddressValidationResult(
        isValid: false,
        message:
            'GSTIN state code must be $expectedCode for ${address.stateName}.',
      );
    }
  }
  if (address.countryId == 'IN' &&
      address.pincode.isNotEmpty &&
      !RegExp(r'^\d{6}$').hasMatch(address.pincode)) {
    return const AddressValidationResult(
      isValid: false,
      message: 'Indian pincode must contain 6 digits.',
    );
  }
  return const AddressValidationResult(isValid: true);
}