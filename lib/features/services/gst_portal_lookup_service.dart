import 'package:dio/dio.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class GstTaxpayerProfile {
  final String gstin;
  final String legalName;
  final String tradeName;
  final String address;
  final String state;
  final String pincode;
  final String status;
  final String email;
  final String mobile;

  String get city {
    final parts = address.split(',');
    return parts.length > 1 ? parts[parts.length - 2].trim() : '';
  }

  const GstTaxpayerProfile({
    required this.gstin,
    required this.legalName,
    required this.tradeName,
    required this.address,
    required this.state,
    required this.pincode,
    required this.status,
    required this.email,
    required this.mobile,
  });
}

class GstPortalLookupResult {
  final GstTaxpayerProfile? profile;
  final String message;

  const GstPortalLookupResult({required this.profile, required this.message});
}

class GstPortalLookupService {
  GstPortalLookupService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<GstPortalLookupResult> fetchTaxpayerByGstin(String gstin) async {
    final normalized = gstin.trim().toUpperCase();

    if (!_isValidGstin(normalized)) {
      return const GstPortalLookupResult(
        profile: null,
        message: 'Enter a valid 15-character GSTIN',
      );
    }

    try {
      final response = await _dio.post<dynamic>(
        '/gstzen/gstin/validate',
        data: {'gstin': normalized},
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final payload = _extractPayload(response.data);
      if (payload == null) {
        return const GstPortalLookupResult(
          profile: null,
          message:
              'GST validation service did not return taxpayer details.',
        );
      }

      final profile = _parseProfile(payload, normalized);
      if (profile == null) {
        return const GstPortalLookupResult(
          profile: null,
          message:
              'GST details could not be parsed from the validation response. Try manual entry.',
        );
      }

      return GstPortalLookupResult(
        profile: profile,
        message: 'GST details fetched',
      );
    } catch (_) {
      return const GstPortalLookupResult(
        profile: null,
        message:
            'Unable to validate GSTIN right now. Continue with manual entry.',
      );
    }
  }

  bool _isValidGstin(String value) {
    final regExp = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{1}Z[A-Z0-9]{1}$',
    );
    return regExp.hasMatch(value);
  }

  Map<String, dynamic>? _extractPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      if (data['taxpayer'] is Map<String, dynamic>) {
        return data['taxpayer'] as Map<String, dynamic>;
      }
      return data;
    }

    return null;
  }

  GstTaxpayerProfile? _parseProfile(Map<String, dynamic> map, String gstin) {
    final legalName =
        (map['legalName'] ?? map['lgnm'] ?? map['legal_name'] ?? map['lgnm'] ?? '').toString();
    final tradeName =
        (map['tradeName'] ?? map['tradeNam'] ?? map['trade_name'] ?? map['trade_name'] ?? '')
            .toString();
    final address =
        (map['address'] ?? map['adr'] ?? map['principalPlace'] ?? '')
            .toString();
    final state = (map['state'] ?? map['stj'] ?? map['stateName'] ?? '')
        .toString();
    final pincode = (map['pincode'] ?? map['pncd'] ?? map['zip'] ?? '')
        .toString();
    final status = (map['status'] ?? map['sts'] ?? '').toString();
    final email = (map['email'] ?? map['em'] ?? '').toString();
    final mobile = (map['mobile'] ?? map['mob'] ?? '').toString();

    if (legalName.trim().isEmpty && tradeName.trim().isEmpty) {
      return null;
    }

    return GstTaxpayerProfile(
      gstin: gstin,
      legalName: legalName.trim(),
      tradeName: tradeName.trim(),
      address: address.trim(),
      state: state.trim(),
      pincode: pincode.trim(),
      status: status.trim(),
      email: email.trim(),
      mobile: mobile.trim(),
    );
  }
}
