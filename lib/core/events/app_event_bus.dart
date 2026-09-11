import 'dart:async';

import 'package:chirag_accounting/core/events/app_event.dart';

class AppEventBus {
  AppEventBus._();

  static final AppEventBus instance = AppEventBus._();

  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get stream => _controller.stream;

  Stream<AppEvent> ofType(String eventType) {
    return _controller.stream.where((event) => event.eventType == eventType);
  }

  void publish(AppEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }
}
