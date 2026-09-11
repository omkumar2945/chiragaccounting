import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/integrations/integration_adapter.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class WhatsAppIntegrationAdapter implements IntegrationAdapter {
  WhatsAppIntegrationAdapter({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  @override
  String get id => 'whatsapp';

  @override
  String get name => 'WhatsApp API';

  @override
  Future<IntegrationHealth> health() async {
    try {
      final response = await _dio.get<void>('/integrations/whatsapp/health');
      return IntegrationHealth(
        status: response.statusCode == 200 ? 'UP' : 'DEGRADED',
        message: 'WhatsApp integration healthy',
      );
    } catch (_) {
      return const IntegrationHealth(status: 'DOWN', message: 'WhatsApp integration unreachable');
    }
  }

  @override
  Future<Map<String, dynamic>> execute({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/integrations/whatsapp/$action',
      data: payload,
    );
    return response.data ?? const <String, dynamic>{};
  }
}
