import 'package:flutter/material.dart';

class AppLifecycleStateKeeper extends StatefulWidget {
  const AppLifecycleStateKeeper({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleStateKeeper> createState() =>
      _AppLifecycleStateKeeperState();
}

class _AppLifecycleStateKeeperState extends State<AppLifecycleStateKeeper>
    with WidgetsBindingObserver {
  FocusNode? _savedFocusNode;
  TextEditingController? _savedController;
  TextSelection? _savedSelection;
  bool _isSuspended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_isSuspended) {
          _isSuspended = true;
          _captureEditingState();
        }
      case AppLifecycleState.resumed:
        if (_isSuspended) {
          _isSuspended = false;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreEditingState(),
          );
        }
    }
  }

  void _captureEditingState() {
    final focusNode = FocusManager.instance.primaryFocus;
    final editableState = focusNode?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (focusNode == null || editableState == null) return;

    _savedFocusNode = focusNode;
    _savedController = editableState.widget.controller;
    _savedSelection = editableState.widget.controller.selection;
  }

  void _restoreEditingState() {
    final focusNode = _savedFocusNode;
    final controller = _savedController;
    final selection = _savedSelection;
    _clearEditingState();

    if (!mounted ||
        focusNode == null ||
        focusNode.context == null ||
        !focusNode.canRequestFocus ||
        controller == null ||
        selection == null ||
        !selection.isValid) {
      return;
    }

    final textLength = controller.text.length;
    controller.selection = TextSelection(
      baseOffset: selection.baseOffset.clamp(0, textLength),
      extentOffset: selection.extentOffset.clamp(0, textLength),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
    focusNode.requestFocus();
  }

  void _clearEditingState() {
    _savedFocusNode = null;
    _savedController = null;
    _savedSelection = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
