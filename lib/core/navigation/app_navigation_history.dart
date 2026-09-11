import 'package:flutter/material.dart';

class AppNavigationHistory extends NavigatorObserver with ChangeNotifier {
  final List<_RouteEntry> _forwardEntries = <_RouteEntry>[];
  bool _isRestoringForwardRoute = false;
  bool _notificationScheduled = false;

  bool get canGoBack => navigator?.canPop() ?? false;
  bool get canGoForward => _forwardEntries.isNotEmpty;

  Future<void> goBack() async {
    await navigator?.maybePop();
  }

  Future<void> goForward() async {
    if (_forwardEntries.isEmpty || navigator == null) return;
    final entry = _forwardEntries.removeLast();
    _isRestoringForwardRoute = true;
    _notifyNavigationChanged();
    try {
      final routeResult = navigator!.push(entry.createRoute());
      _isRestoringForwardRoute = false;
      _notifyNavigationChanged();
      await routeResult;
    } finally {
      _isRestoringForwardRoute = false;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute && !_isRestoringForwardRoute) {
      _forwardEntries.clear();
    }
    _notifyNavigationChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is MaterialPageRoute<dynamic>) {
      _forwardEntries.add(_RouteEntry.fromRoute(route));
    }
    _notifyNavigationChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _notifyNavigationChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (!_isRestoringForwardRoute) {
      _forwardEntries.clear();
    }
    _notifyNavigationChanged();
  }

  void _notifyNavigationChanged() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      notifyListeners();
    });
  }
}

class _RouteEntry {
  const _RouteEntry({required this.builder, required this.settings});

  factory _RouteEntry.fromRoute(MaterialPageRoute<dynamic> route) {
    return _RouteEntry(builder: route.builder, settings: route.settings);
  }

  final WidgetBuilder builder;
  final RouteSettings settings;

  MaterialPageRoute<void> createRoute() {
    return MaterialPageRoute<void>(builder: builder, settings: settings);
  }
}
