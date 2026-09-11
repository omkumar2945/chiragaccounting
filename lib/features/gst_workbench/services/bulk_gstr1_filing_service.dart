import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/services/api_client.dart';

class BulkGstr1FilingRequest {
  const BulkGstr1FilingRequest({
    required this.clientId,
    required this.gstin,
    required this.returnPeriod,
  });

  final String clientId;
  final String gstin;
  final String returnPeriod;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientId': clientId,
    'gstin': gstin.trim().toUpperCase(),
    'returnPeriod': returnPeriod,
    'payload': const <String, dynamic>{},
  };
}

class BulkGstr1FilingResult {
  const BulkGstr1FilingResult({
    required this.clientId,
    required this.gstin,
    required this.returnPeriod,
    required this.status,
    this.error,
  });

  final String clientId;
  final String gstin;
  final String returnPeriod;
  final String status;
  final String? error;

  bool get isFiled => status == 'filed';
}

class BulkGstr1FilingService {
  BulkGstr1FilingService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<BulkGstr1FilingResult>> fileReturns(
    List<BulkGstr1FilingRequest> requests,
  ) async {
    final response = await _dio.post<dynamic>(
      '/gst/gstr1/bulk-file',
      data: <String, dynamic>{
        'returns': requests.map((request) => request.toJson()).toList(),
      },
    );
    final body = response.data;
    final values = body is Map && body['results'] is List
        ? body['results'] as List
        : const <dynamic>[];
    return values
        .whereType<Map>()
        .map((value) {
          final result = Map<String, dynamic>.from(value);
          return BulkGstr1FilingResult(
            clientId: result['clientId']?.toString() ?? '',
            gstin: result['gstin']?.toString() ?? '',
            returnPeriod: result['returnPeriod']?.toString() ?? '',
            status: result['status']?.toString() ?? 'failed',
            error: result['error']?.toString(),
          );
        })
        .toList(growable: false);
  }
}
