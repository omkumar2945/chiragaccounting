import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';

class TimelinePersistenceService {
  static const String _timelineKey = 'v4.timeline.events';

  Future<List<OperationTimelineEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timelineKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <OperationTimelineEvent>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .map(_fromMap)
          .toList(growable: false);
    } catch (_) {
      return const <OperationTimelineEvent>[];
    }
  }

  Future<void> saveEvents(List<OperationTimelineEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final data = events.map(_toMap).toList(growable: false);
    await prefs.setString(_timelineKey, jsonEncode(data));
  }

  Map<String, dynamic> _toMap(OperationTimelineEvent event) {
    return <String, dynamic>{
      'title': event.title,
      'detail': event.detail,
      'timestamp': event.timestamp.toIso8601String(),
      'clientName': event.clientName,
      'source': event.source,
      'severity': event.severity.name,
    };
  }

  OperationTimelineEvent _fromMap(Map<String, dynamic> map) {
    return OperationTimelineEvent(
      title: map['title']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      clientName: map['clientName']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      severity: OperationSeverity.values.firstWhere(
        (value) => value.name == map['severity']?.toString(),
        orElse: () => OperationSeverity.info,
      ),
    );
  }
}
