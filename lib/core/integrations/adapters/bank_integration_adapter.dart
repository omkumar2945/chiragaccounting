import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/integrations/integration_adapter.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class BankIntegrationAdapter implements IntegrationAdapter {
  BankIntegrationAdapter({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  @override
  String get id => 'bank';

  @override
  String get name => 'Bank API';

  @override
  Future<IntegrationHealth> health() async {
    try {
      final response = await _dio.get<void>('/integrations/bank/health');
      return IntegrationHealth(
        status: response.statusCode == 200 ? 'UP' : 'DEGRADED',
        message: 'Bank integration healthy',
      );
    } catch (_) {
      return const IntegrationHealth(status: 'DOWN', message: 'Bank integration unreachable');
    }
  }

  @override
  Future<Map<String, dynamic>> execute({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/integrations/bank/$action',
      data: payload,
    );
    return response.data ?? const <String, dynamic>{};
  }
}
