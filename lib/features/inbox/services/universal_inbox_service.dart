import 'dart:async';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/features/inbox/models/inbox_item.dart';
import 'package:chirag_accounting/features/inbox/services/universal_inbox_api_service.dart';

class UniversalInboxService extends ChangeNotifier {
  UniversalInboxService({UniversalInboxApiService? apiService})
      : _apiService = apiService ?? UniversalInboxApiService() {
    _sub = AppEventBus.instance.stream.listen(_onEvent);
  }

  final UniversalInboxApiService _apiService;
  final List<InboxItem> _items = <InboxItem>[];
  late final StreamSubscription<AppEvent> _sub;

  List<InboxItem> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((item) => !item.isRead).length;

  void markRead(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(isRead: true);
    notifyListeners();
  }

  void markAllRead() {
    for (var i = 0; i < _items.length; i += 1) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
    if (!ApiConstants.useMockApi) {
      _apiService.markAllRead(businessId: 'chirag-main', userId: 'system');
    }
    notifyListeners();
  }

  void _onEvent(AppEvent event) {
    final item = InboxItem(
      id: event.eventId,
      title: event.eventType,
      message: event.payload['summary']?.toString() ?? '${event.entityType} updated',
      channel: event.module,
      createdAt: event.timestamp.toLocal(),
      referenceType: event.entityType,
      referenceId: event.entityId,
    );
    _items.insert(0, item);
    if (_items.length > 500) {
      _items.removeRange(500, _items.length);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
