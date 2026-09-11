import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';

class TimelineApiService {
  TimelineApiService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<OperationTimelineEvent>> fetchTimeline({
    required String businessId,
    String? clientId,
  }) async {
    if (ApiConstants.useMockApi) return const <OperationTimelineEvent>[];

    final response = await _dio.get<List<dynamic>>(
      '/timeline',
      queryParameters: <String, dynamic>{
        'businessId': businessId,
        if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      },
    );

    final data = response.data ?? const <dynamic>[];
    return data.whereType<Map>().map((value) {
      final map = Map<String, dynamic>.from(value);
      return OperationTimelineEvent(
        title: map['title']?.toString() ?? '',
        detail: map['detail']?.toString() ?? '',
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
        clientName: map['clientName']?.toString() ?? '',
        source: map['source']?.toString() ?? '',
        severity: OperationSeverity.values.firstWhere(
          (s) => s.name == map['severity']?.toString(),
          orElse: () => OperationSeverity.info,
        ),
      );
    }).toList(growable: false);
  }

  Future<void> pushTimeline({
    required String businessId,
    required List<OperationTimelineEvent> events,
  }) async {
    if (ApiConstants.useMockApi || events.isEmpty) return;

    final payload = events
        .map((event) => <String, dynamic>{
              'title': event.title,
              'detail': event.detail,
              'timestamp': event.timestamp.toIso8601String(),
              'clientName': event.clientName,
              'source': event.source,
              'severity': event.severity.name,
            })
        .toList(growable: false);

    await _dio.post<void>(
      '/timeline/bulk-upsert',
      data: <String, dynamic>{
        'businessId': businessId,
        'events': payload,
      },
    );
  }
}
