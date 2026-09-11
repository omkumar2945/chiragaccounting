import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class RealtimeGatewayService {
  RealtimeGatewayService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  final Map<String, StreamController<Map<String, dynamic>>> _channels =
      <String, StreamController<Map<String, dynamic>>>{};

  StreamSubscription<List<int>>? _sseSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  RealtimeScope? _activeScope;
  final Set<String> _desiredChannels = <String>{};
  bool _connected = false;

  bool get isConnected => _connected;

  Stream<Map<String, dynamic>> subscribe(String channel) {
    _desiredChannels.add(channel);
    final controller = _channels.putIfAbsent(
      channel,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
    return controller.stream;
  }

  Stream<Map<String, dynamic>> subscribeScoped({
    required RealtimeTopic topic,
    required RealtimeScope scope,
  }) {
    _activeScope = scope;
    final channel = '${topic.value}.${scope.businessId}.${scope.role}.${scope.userId}';
    return subscribe(channel);
  }

  Future<void> connect({RealtimeScope? scope}) async {
    _activeScope = scope ?? _activeScope;
    if (_connected || ApiConstants.useMockApi) return;
    try {
      final channels = _desiredChannels.toList(growable: false);
      final response = await _dio.get<ResponseBody>(
        '/realtime/sse',
        queryParameters: <String, dynamic>{
          if (_activeScope != null) 'tenantId': _activeScope!.tenantId,
          if (_activeScope != null) 'businessId': _activeScope!.businessId,
          if (_activeScope != null) 'userId': _activeScope!.userId,
          if (_activeScope != null) 'role': _activeScope!.role,
          if (channels.isNotEmpty) 'channels': channels.join(','),
        },
        options: Options(responseType: ResponseType.stream),
      );
      final body = response.data;
      if (body == null) return;

      _connected = true;
      _reconnectAttempt = 0;
      _sseSubscription = body.stream.listen(
        _onChunk,
        onError: (_) {
          _connected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void publishLocal(String channel, Map<String, dynamic> message) {
    final controller = _channels[channel];
    if (controller == null || controller.isClosed) return;
    controller.add(message);
  }

  void _onChunk(List<int> chunk) {
    final text = utf8.decode(chunk);
    final lines = const LineSplitter().convert(text);
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payloadText = trimmed.substring(5).trim();
      if (payloadText.isEmpty || payloadText == '[DONE]') continue;
      try {
        final payload = jsonDecode(payloadText);
        if (payload is! Map<String, dynamic>) continue;
        final channel = payload['channel']?.toString();
        if (channel == null || channel.isEmpty) continue;
        publishLocal(channel, payload);
      } catch (_) {
        // Ignore malformed chunk and continue.
      }
    }
  }

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _sseSubscription?.cancel();
    for (final controller in _channels.values) {
      await controller.close();
    }
    _channels.clear();
    _connected = false;
  }

  void _scheduleReconnect() {
    if (ApiConstants.useMockApi) return;
    _reconnectTimer?.cancel();
    final backoffSeconds = math.min(30, math.pow(2, _reconnectAttempt).toInt());
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 10);
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      connect();
    });
  }
}

enum RealtimeTopic {
  dashboardUpdates('dashboard.updates'),
  clientEvents('client.events'),
  salesEvents('sales.events'),
  complianceEvents('compliance.events'),
  auditEvents('audit.events');

  const RealtimeTopic(this.value);
  final String value;
}

class RealtimeScope {
  const RealtimeScope({
    required this.tenantId,
    required this.businessId,
    required this.userId,
    required this.role,
  });

  final String tenantId;
  final String businessId;
  final String userId;
  final String role;
}
