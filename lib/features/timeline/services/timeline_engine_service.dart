import 'dart:async';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';
import 'package:chirag_accounting/features/timeline/services/timeline_api_service.dart';
import 'package:chirag_accounting/features/timeline/services/timeline_persistence_service.dart';

class TimelineEngineService extends ChangeNotifier {
  TimelineEngineService({
    TimelinePersistenceService? persistenceService,
    TimelineApiService? apiService,
  })  : _persistenceService = persistenceService ?? TimelinePersistenceService(),
        _apiService = apiService ?? TimelineApiService() {
    _restoreFromDisk();
    _sub = AppEventBus.instance.stream.listen(_onEvent);
    _syncTimer = Timer.periodic(const Duration(seconds: 18), (_) {
      _syncWithCloud();
    });
  }

  final TimelinePersistenceService _persistenceService;
  final TimelineApiService _apiService;
  final List<OperationTimelineEvent> _events = <OperationTimelineEvent>[];
  late final StreamSubscription<AppEvent> _sub;
  late final Timer _syncTimer;

  List<OperationTimelineEvent> get allEvents => List.unmodifiable(_events);

  List<OperationTimelineEvent> forClient(String clientName) {
    final key = clientName.trim().toLowerCase();
    return _events
        .where((event) => event.clientName.trim().toLowerCase() == key)
        .toList(growable: false);
  }

  void _onEvent(AppEvent event) {
    final clientName = _clientNameFromEvent(event);
    final timelineEvent = OperationTimelineEvent(
      title: _titleFromEvent(event),
      detail: event.payload['summary']?.toString() ?? _detailFromEvent(event),
      timestamp: event.timestamp.toLocal(),
      clientName: clientName,
      source: event.entityType,
      severity: _severityFromPriority(event.priority),
    );
    _events.insert(0, timelineEvent);
    if (_events.length > 1000) {
      _events.removeRange(1000, _events.length);
    }
    _persist();
    notifyListeners();
  }

  Future<void> _restoreFromDisk() async {
    final restored = await _persistenceService.loadEvents();
    if (restored.isEmpty) return;
    _events
      ..clear()
      ..addAll(restored);
    notifyListeners();
  }

  Future<void> _persist() async {
    await _persistenceService.saveEvents(_events);
  }

  Future<void> _syncWithCloud() async {
    if (ApiConstants.useMockApi) return;
    try {
      await _apiService.pushTimeline(
        businessId: 'chirag-main',
        events: _events.take(200).toList(growable: false),
      );
      final latest = await _apiService.fetchTimeline(businessId: 'chirag-main');
      if (latest.isNotEmpty) {
        _events
          ..clear()
          ..addAll(latest);
        notifyListeners();
        await _persist();
      }
    } catch (_) {
      // Retry on next timer.
    }
  }

  String _clientNameFromEvent(AppEvent event) {
    final payload = event.payload;
    return payload['clientName']?.toString() ??
        payload['vendorName']?.toString() ??
        event.clientId;
  }

  String _titleFromEvent(AppEvent event) {
    final type = event.eventType;
    if (type.contains('sales.invoice.created')) return 'Invoice Uploaded';
    if (type.contains('purchase.bill.created')) return 'Purchase Uploaded';
    if (type.contains('task.created')) return 'Task Created';
    if (type.contains('notification.created')) return 'Notification Created';
    if (type.contains('workflow.stage.changed')) return 'Workflow Stage Changed';
    return event.eventType;
  }

  String _detailFromEvent(AppEvent event) {
    return '${event.entityType} ${event.entityId}';
  }

  OperationSeverity _severityFromPriority(String priority) {
    final p = priority.toLowerCase();
    if (p == 'critical') return OperationSeverity.critical;
    if (p == 'high') return OperationSeverity.warning;
    return OperationSeverity.info;
  }

  @override
  void dispose() {
    _sub.cancel();
    _syncTimer.cancel();
    super.dispose();
  }
}
