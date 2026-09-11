import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/core/constants/india_locations.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';

class CountryOption {
  const CountryOption({required this.id, required this.name});

  final String id;
  final String name;
}

class LocationRepository {
  LocationRepository({Dio? dio, SharedPreferences? preferences})
    : _dio = dio ?? Dio(),
      _preferences = preferences;

  static const String apiBaseUrl = String.fromEnvironment(
    'LOCATION_API_BASE_URL',
    defaultValue: '',
  );
  static const Duration _cacheLifetime = Duration(days: 7);
  static const List<CountryOption> countries = <CountryOption>[
    CountryOption(id: 'IN', name: 'India'),
  ];

  final Dio _dio;
  final SharedPreferences? _preferences;

  List<String> searchStates(String query, {String countryId = 'IN'}) {
    if (countryId != 'IN') return const <String>[];
    final normalized = query.trim().toLowerCase();
    return kIndianStates
        .where((state) => normalized.isEmpty || state.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  List<IndianCityOption> searchCities({
    required String state,
    String query = '',
  }) {
    final normalized = query.trim().toLowerCase();
    return (kIndianCitiesByState[state] ?? const <IndianCityOption>[])
        .where((option) =>
            normalized.isEmpty || option.city.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  Future<List<StandardAddress>> lookupPincode(String pincode) async {
    final normalized = pincode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) return const <StandardAddress>[];
    final cached = await _readCache(normalized);
    if (cached != null) return cached;

    final remote = await _lookupBackend(normalized);
    if (remote.isNotEmpty) {
      await _writeCache(normalized, remote);
      return remote;
    }

    final local = kAllIndianCityOptions
        .where((option) => option.pincode == normalized)
        .map(
          (option) => StandardAddress(
            stateName: option.state,
            cityName: option.city,
            district: option.city,
            pincode: option.pincode,
            source: 'local-catalog',
          ),
        )
        .toList(growable: false);
    if (local.isNotEmpty) await _writeCache(normalized, local);
    return local;
  }

  Future<List<StandardAddress>> _lookupBackend(String pincode) async {
    if (apiBaseUrl.isEmpty) return const <StandardAddress>[];
    try {
      final response = await _dio.get<dynamic>(
        '${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/api/locations/pincode/$pincode',
        options: Options(
          headers: const <String, String>{'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final body = response.data;
      final rawLocations = body is Map
          ? body['locations']
          : body;
      if (rawLocations is! List) return const <StandardAddress>[];
      return rawLocations.whereType<Map>().map((raw) {
        return StandardAddress.fromMap(Map<String, dynamic>.from(raw));
      }).toList(growable: false);
    } catch (_) {
      return const <StandardAddress>[];
    }
  }

  Future<List<StandardAddress>?> _readCache(String pincode) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final encoded = preferences.getString('location_cache_v1_$pincode');
    if (encoded == null) return null;
    try {
      final payload = jsonDecode(encoded) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(payload['savedAt']?.toString() ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _cacheLifetime) {
        await preferences.remove('location_cache_v1_$pincode');
        return null;
      }
      return (payload['locations'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((raw) => StandardAddress.fromMap(Map<String, dynamic>.from(raw)))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    String pincode,
    List<StandardAddress> locations,
  ) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      'location_cache_v1_$pincode',
      jsonEncode(<String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'locations': locations.map((location) => location.toMap()).toList(),
      }),
    );
  }
}