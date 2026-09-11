import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/integrations/integration_adapter.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class EmailIntegrationAdapter implements IntegrationAdapter {
  EmailIntegrationAdapter({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  @override
  String get id => 'email';

  @override
  String get name => 'Email API';

  @override
  Future<IntegrationHealth> health() async {
    try {
      final response = await _dio.get<void>('/integrations/email/health');
      return IntegrationHealth(
        status: response.statusCode == 200 ? 'UP' : 'DEGRADED',
        message: 'Email integration healthy',
      );
    } catch (_) {
      return const IntegrationHealth(status: 'DOWN', message: 'Email integration unreachable');
    }
  }

  @override
  Future<Map<String, dynamic>> execute({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/integrations/email/$action',
      data: payload,
    );
    return response.data ?? const <String, dynamic>{};
  }
}
