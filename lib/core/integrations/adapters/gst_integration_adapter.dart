import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/integrations/integration_adapter.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class GstIntegrationAdapter implements IntegrationAdapter {
  GstIntegrationAdapter({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  @override
  String get id => 'gst';

  @override
  String get name => 'GST API';

  @override
  Future<IntegrationHealth> health() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<Map<String, dynamic>>('/gstzen/status');
      stopwatch.stop();
      final data = response.data ?? const <String, dynamic>{};
      final configured = data['configured'] == true;
      final accountEmail = data['accountEmail']?.toString().trim() ?? '';
      return IntegrationHealth(
        status: configured ? 'UP' : 'DOWN',
        message: configured
            ? 'GSTZen active for $accountEmail'
            : 'Configure the GSTZen activated email and token on the backend.',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      stopwatch.stop();
      return IntegrationHealth(
        status: 'DOWN',
        message: 'GSTZen integration unreachable',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> execute({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    const endpoints = <String, String>{
      'generate-einvoice': '/gstzen/einvoice/generate',
      'cancel-einvoice': '/gstzen/einvoice/cancel',
      'get-einvoice': '/gstzen/einvoice/get',
      'generate-eway-bill': '/gstzen/eway-bill/generate',
      'cancel-eway-bill': '/gstzen/eway-bill/cancel',
      'create-eway-bill': '/gstzen/eway-bill/create',
      'cancel-standalone-eway-bill': '/gstzen/eway-bill/standalone/cancel',
      'update-eway-bill-part-b': '/gstzen/eway-bill/update-part-b',
      'update-eway-bill-transporter': '/gstzen/eway-bill/update-transporter',
      'get-eway-bill': '/gstzen/eway-bill/get',
      'generate-consolidated-eway-bill':
          '/gstzen/eway-bill/consolidated/generate',
      'get-consolidated-eway-bill': '/gstzen/eway-bill/consolidated/get',
      'extend-eway-bill': '/gstzen/eway-bill/extend',
      'initiate-eway-bill-multi-vehicle':
          '/gstzen/eway-bill/multi-vehicle/initiate',
      'add-eway-bill-multi-vehicle': '/gstzen/eway-bill/multi-vehicle/add',
      'change-eway-bill-multi-vehicle':
          '/gstzen/eway-bill/multi-vehicle/change',
      'close-eway-bill': '/gstzen/eway-bill/close',
      'get-eway-bill-transporter-view': '/gstzen/eway-bill/transporter-view',
      'get-eway-bill-transporter-state-view':
          '/gstzen/eway-bill/transporter-state-view',
      'get-eway-bill-transporter-gstin-view':
          '/gstzen/eway-bill/transporter-gstin-view',
    };
    final endpoint = endpoints[action];
    if (endpoint == null) {
      throw ArgumentError.value(action, 'action', 'Unsupported GSTZen action');
    }
    final requestPayload = Map<String, dynamic>.from(payload);
    const gstinActions = <String>{
      'create-eway-bill',
      'cancel-standalone-eway-bill',
      'update-eway-bill-part-b',
      'update-eway-bill-transporter',
      'get-eway-bill',
      'generate-consolidated-eway-bill',
      'get-consolidated-eway-bill',
      'extend-eway-bill',
      'initiate-eway-bill-multi-vehicle',
      'add-eway-bill-multi-vehicle',
      'change-eway-bill-multi-vehicle',
      'close-eway-bill',
    };
    final gstin =
        (gstinActions.contains(action)
                ? requestPayload.remove('gstin') ?? requestPayload['fromGstin']
                : requestPayload['gstin'])
            .toString()
            .trim()
            .toUpperCase();
    if (gstinActions.contains(action) && gstin.isEmpty) {
      throw ArgumentError('GSTIN is required for $action');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: requestPayload,
      options: gstinActions.contains(action)
          ? Options(headers: <String, String>{'X-GSTIN': gstin})
          : null,
    );
    return response.data ?? const <String, dynamic>{};
  }
}
