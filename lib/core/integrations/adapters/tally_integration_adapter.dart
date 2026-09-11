import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/integrations/integration_adapter.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class TallyIntegrationAdapter implements IntegrationAdapter {
  TallyIntegrationAdapter({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  @override
  String get id => 'tally';

  @override
  String get name => 'Tally Prime';

  @override
  Future<IntegrationHealth> health() async {
    try {
      final response = await _dio.get<void>('/integrations/tally/health');
      return IntegrationHealth(
        status: response.statusCode == 200 ? 'UP' : 'DEGRADED',
        message: 'Tally integration healthy',
      );
    } catch (error) {
      return IntegrationHealth(
        status: 'DOWN',
        message: 'Tally integration unreachable: $error',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> execute({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/integrations/tally/$action',
        data: payload,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      return <String, dynamic>{
        'accepted': true,
        'message': 'Tally request accepted',
        'payload': jsonEncode(payload),
      };
    } catch (error) {
      return <String, dynamic>{
        'accepted': false,
        'message': error.toString(),
      };
    }
  }
}
