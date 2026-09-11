import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/services/api_client.dart';

class GstComplianceResult {
  const GstComplianceResult({
    required this.operation,
    required this.message,
    required this.data,
  });

  final String operation;
  final String message;
  final dynamic data;
}

class GstComplianceService {
  GstComplianceService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<GstComplianceResult> execute({
    required String operation,
    required String gstin,
    required String returnPeriod,
    String? clientId,
  }) async {
    final response = await _dio.post<dynamic>(
      '/gst/compliance/$operation',
      data: <String, dynamic>{
        'gstin': gstin.trim().toUpperCase(),
        'ret_period': returnPeriod.trim(),
        'clientId': ?clientId,
      },
    );
    final body = response.data;
    final map = body is Map ? Map<String, dynamic>.from(body) : null;
    return GstComplianceResult(
      operation: operation,
      message: map?['message']?.toString() ?? '$operation completed.',
      data: body,
    );
  }
}
