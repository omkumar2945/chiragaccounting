import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/constants/india_locations.dart';

class PincodeLookupResult {
  final String state;
  final String city;
  final String pincode;
  final String source;

  const PincodeLookupResult({
    required this.state,
    required this.city,
    required this.pincode,
    required this.source,
  });
}

class PincodeLookupService {
  PincodeLookupService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _endpoint = 'https://api.postalpincode.in/pincode';

  Future<PincodeLookupResult?> lookup(String pincode) async {
    final normalizedPincode = pincode.trim();
    if (!_isValidPincode(normalizedPincode)) {
      return null;
    }

    final localMatch = findIndianCityByPincode(normalizedPincode);

    final liveMatch = await _lookupPostalApi(normalizedPincode);
    if (liveMatch != null) {
      return liveMatch;
    }

    if (localMatch == null) {
      return null;
    }

    return PincodeLookupResult(
      state: localMatch.state,
      city: localMatch.city,
      pincode: localMatch.pincode,
      source: 'local-catalog',
    );
  }

  bool _isValidPincode(String pincode) {
    return RegExp(r'^\d{6}$').hasMatch(pincode);
  }

  Future<PincodeLookupResult?> _lookupPostalApi(String pincode) async {
    try {
      final response = await _dio.get<dynamic>(
        '$_endpoint/$pincode',
        options: Options(
          headers: const {'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final body = response.data;
      if (body is! List || body.isEmpty) {
        return null;
      }

      final payload = body.first;
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final status = (payload['Status'] ?? '').toString().trim();
      if (status.toLowerCase() != 'success') {
        return null;
      }

      final offices = payload['PostOffice'];
      if (offices is! List || offices.isEmpty) {
        return null;
      }

      final firstOffice = offices.first;
      if (firstOffice is! Map<String, dynamic>) {
        return null;
      }

      final state =
          (firstOffice['State'] ?? firstOffice['state'] ?? '').toString().trim();
      final city = (firstOffice['District'] ??
              firstOffice['district'] ??
              firstOffice['Block'] ??
              firstOffice['Name'] ??
              '')
          .toString()
          .trim();

      if (state.isEmpty || city.isEmpty) {
        return null;
      }

      return PincodeLookupResult(
        state: state,
        city: city,
        pincode: pincode,
        source: 'postal-api',
      );
    } catch (_) {
      return null;
    }
  }
}