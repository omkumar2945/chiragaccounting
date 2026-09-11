import 'package:flutter/material.dart';

Future<T?> showMovableDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Alignment initialAlignment = Alignment.center,
  Size? initialSize,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    builder: (dialogContext) {
      final child = builder(dialogContext);
      return MovableResizableDialog(
        initialAlignment: initialAlignment,
        initialSize: initialSize ?? _recommendedInitialSize(child),
        child: child,
      );
    },
  );
}

Size _recommendedInitialSize(Widget child) {
  if (child is AlertDialog) {
    final content = child.content;
    final actionCount = child.actions?.length ?? 0;
    final textLength = _dialogTextLength(content);
    if (content is SizedBox) {
      final width = content.width;
      final height = content.height;
      if (width != null || height != null) {
        return Size(
          (width ?? 420) + 96,
          (height ?? 260) + 180 + (actionCount > 3 ? 48 : 0),
        );
      }
    }
    if (_containsTextInput(content)) {
      return Size(520, actionCount > 2 ? 460 : 420);
    }
    if (content == null || content is Text || content is SelectableText) {
      final width = textLength > 180 ? 500.0 : 420.0;
      final estimatedLines = (textLength / (width == 420 ? 44 : 58)).ceil();
      final actionRows = actionCount > 3 ? 2 : 1;
      return Size(
        width,
        (190 + estimatedLines * 20 + actionRows * 48)
            .clamp(220, 420)
            .toDouble(),
      );
    }
    return const Size(620, 560);
  }
  if (child is SimpleDialog) {
    final optionCount = child.children?.length ?? 0;
    return Size(440, (140 + optionCount * 56).clamp(220, 560).toDouble());
  }
  if (child is Dialog) return const Size(620, 560);
  return const Size(560, 500);
}

int _dialogTextLength(Widget? widget) {
  if (widget is Text) return widget.data?.length ?? 0;
  if (widget is SelectableText) return widget.data?.length ?? 0;
  return 0;
}

bool _containsTextInput(Widget? widget) {
  return widget is TextField || widget is TextFormField;
}

class MovableResizableDialog extends StatefulWidget {
  const MovableResizableDialog({
    super.key,
    required this.child,
    this.initialAlignment = Alignment.center,
    this.initialSize,
  });

  final Widget child;
  final Alignment initialAlignment;
  final Size? initialSize;

  @override
  State<MovableResizableDialog> createState() => _MovableResizableDialogState();
}

class _MovableResizableDialogState extends State<MovableResizableDialog> {
  static const double _minimumWidth = 280;
  static const double _minimumHeight = 160;
  static const double _visibleEdge = 72;
  static const double _windowMargin = 16;
  static const double _titleBarHeight = 40;
  static const BorderRadius _windowRadius = BorderRadius.all(
    Radius.circular(8),
  );

  Offset _offset = Offset.zero;
  Size? _size;
  bool _positioned = false;
  final GlobalKey _windowKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = (constraints.maxWidth - _windowMargin).clamp(
          0.0,
          double.infinity,
        );
        final maxHeight = (constraints.maxHeight - _windowMargin).clamp(
          0.0,
          double.infinity,
        );
        final minimumWidth = maxWidth < _minimumWidth
            ? maxWidth
            : _minimumWidth;
        final minimumHeight = maxHeight < _minimumHeight
            ? maxHeight
            : _minimumHeight;
        final requestedSize = _size ?? widget.initialSize;
        final currentSize = requestedSize == null
            ? null
            : _boundedSize(
                requestedSize,
                minWidth: minimumWidth,
                minHeight: minimumHeight,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              );
        final measuredSize = currentSize ?? _measuredWindowSize();
        if (!_positioned && measuredSize != null) {
          _offset = _initialOffset(
            viewport: constraints.biggest,
            dialogSize: measuredSize,
          );
          _positioned = true;
        } else if (!_positioned) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_positioned) setState(() {});
          });
        }
        final effectiveSize = measuredSize ?? Size.zero;
        _offset = _boundedOffset(
          _offset,
          viewport: constraints.biggest,
          dialogSize: effectiveSize,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Transform.translate(
                offset: _offset,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: currentSize?.width ?? minimumWidth,
                    maxWidth: currentSize?.width ?? maxWidth.clamp(0, 640),
                    minHeight: currentSize?.height ?? minimumHeight,
                    maxHeight: currentSize?.height ?? maxHeight.clamp(0, 600),
                  ),
                  child: Stack(
                    key: _windowKey,
                    children: [
                      Material(
                        key: const ValueKey<String>('movable_dialog_window'),
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 18,
                        shadowColor: Colors.black.withValues(alpha: 0.28),
                        surfaceTintColor: Colors.transparent,
                        borderRadius: _windowRadius,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: currentSize == null
                              ? MainAxisSize.min
                              : MainAxisSize.max,
                          children: [
                            _DialogTitleBar(
                              onPanUpdate: (details) {
                                setState(() {
                                  _offset = _boundedOffset(
                                    _offset + details.delta,
                                    viewport: constraints.biggest,
                                    dialogSize: effectiveSize,
                                  );
                                });
                              },
                            ),
                            Flexible(
                              fit: currentSize == null
                                  ? FlexFit.loose
                                  : FlexFit.tight,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dialogTheme: const DialogThemeData(
                                    backgroundColor: Colors.transparent,
                                    surfaceTintColor: Colors.transparent,
                                    elevation: 0,
                                    insetPadding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: widget.child,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _ResizeHandle(
                          tooltip: 'Resize dialog',
                          onPanUpdate: (details) {
                            setState(() {
                              _size = _boundedSize(
                                Size(
                                  effectiveSize.width + details.delta.dx,
                                  effectiveSize.height + details.delta.dy,
                                ),
                                minWidth: minimumWidth,
                                minHeight: minimumHeight,
                                maxWidth: maxWidth,
                                maxHeight: maxHeight,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Size? _measuredWindowSize() {
    final renderBox = _windowKey.currentContext?.findRenderObject();
    return renderBox is RenderBox && renderBox.hasSize ? renderBox.size : null;
  }

  Offset _initialOffset({required Size viewport, required Size dialogSize}) {
    return Offset(
      (viewport.width - dialogSize.width) * widget.initialAlignment.x / 2,
      (viewport.height - dialogSize.height) * widget.initialAlignment.y / 2,
    );
  }

  Size _boundedSize(
    Size value, {
    required double minWidth,
    required double minHeight,
    required double maxWidth,
    required double maxHeight,
  }) {
    return Size(
      value.width.clamp(minWidth, maxWidth),
      value.height.clamp(minHeight, maxHeight),
    );
  }

  Offset _boundedOffset(
    Offset value, {
    required Size viewport,
    required Size dialogSize,
  }) {
    final horizontalLimit =
        ((viewport.width + dialogSize.width) / 2) - _visibleEdge;
    final verticalLimit =
        ((viewport.height + dialogSize.height) / 2) - _visibleEdge;
    return Offset(
      value.dx.clamp(-horizontalLimit, horizontalLimit),
      value.dy.clamp(-verticalLimit, verticalLimit),
    );
  }
}

class _DialogTitleBar extends StatelessWidget {
  const _DialogTitleBar({required this.onPanUpdate});

  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Move dialog',
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          child: Container(
            height: _MovableResizableDialogState._titleBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 19,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Move window',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.tooltip, required this.onPanUpdate});

  final String tooltip;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
              ),
            ),
            child: Icon(
              Icons.open_in_full,
              size: 17,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
