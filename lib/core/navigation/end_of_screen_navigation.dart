import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class EndOfScreenNavigationController extends ChangeNotifier {
  final List<_NavigationRegistration> _registrations =
      <_NavigationRegistration>[];
  String _previousLabel = 'Previous Menu';
  String _nextLabel = 'Next Screen';
  VoidCallback? _onPrevious;
  VoidCallback? _onNext;

  String get previousLabel => _previousLabel;
  String get nextLabel => _nextLabel;
  bool get hasPrevious => _onPrevious != null;
  bool get hasNext => _onNext != null;
  bool get hasActiveRegistration => _registrations.isNotEmpty;

  void configure({
    String previousLabel = 'Previous Menu',
    String nextLabel = 'Next Screen',
    VoidCallback? onPrevious,
    VoidCallback? onNext,
  }) {
    _previousLabel = previousLabel;
    _nextLabel = nextLabel;
    _onPrevious = onPrevious;
    _onNext = onNext;
    _notifyListenersSafely();
  }

  void register(
    Object owner, {
    String previousLabel = 'Previous Menu',
    String nextLabel = 'Next Screen',
    VoidCallback? onPrevious,
    VoidCallback? onNext,
  }) {
    _registrations.removeWhere((entry) => identical(entry.owner, owner));
    _registrations.add(
      _NavigationRegistration(
        owner: owner,
        previousLabel: previousLabel,
        nextLabel: nextLabel,
        onPrevious: onPrevious,
        onNext: onNext,
      ),
    );
    _applyRegistration(_registrations.last);
  }

  void unregister(Object owner) {
    _registrations.removeWhere((entry) => identical(entry.owner, owner));
    if (_registrations.isEmpty) {
      clear();
    } else {
      _applyRegistration(_registrations.last);
    }
  }

  void clear() {
    _previousLabel = 'Previous Menu';
    _nextLabel = 'Next Screen';
    _onPrevious = null;
    _onNext = null;
    _notifyListenersSafely();
  }

  void previous() => _onPrevious?.call();

  void next() => _onNext?.call();

  void _applyRegistration(_NavigationRegistration registration) {
    _previousLabel = registration.previousLabel;
    _nextLabel = registration.nextLabel;
    _onPrevious = registration.onPrevious;
    _onNext = registration.onNext;
    _notifyListenersSafely();
  }

  void _notifyListenersSafely() {
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.idle ||
        schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}

class _NavigationRegistration {
  const _NavigationRegistration({
    required this.owner,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final Object owner;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
}

class EndOfScreenNavigationScope extends StatefulWidget {
  const EndOfScreenNavigationScope({
    super.key,
    required this.controller,
    required this.child,
    this.previousLabel = 'Previous Menu',
    this.nextLabel = 'Next Screen',
    this.onPrevious,
    this.onNext,
  });

  final EndOfScreenNavigationController controller;
  final Widget child;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<EndOfScreenNavigationScope> createState() =>
      _EndOfScreenNavigationScopeState();
}

class _EndOfScreenNavigationScopeState
    extends State<EndOfScreenNavigationScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _configure());
  }

  @override
  void didUpdateWidget(covariant EndOfScreenNavigationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previousLabel != widget.previousLabel ||
        oldWidget.nextLabel != widget.nextLabel ||
        oldWidget.onPrevious != widget.onPrevious ||
        oldWidget.onNext != widget.onNext) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _configure());
    }
  }

  void _configure() {
    if (!mounted) return;
    widget.controller.register(
      this,
      previousLabel: widget.previousLabel,
      nextLabel: widget.nextLabel,
      onPrevious: widget.onPrevious,
      onNext: widget.onNext,
    );
  }

  @override
  void dispose() {
    widget.controller.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
