import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchableDropdownFormField<T> extends StatelessWidget {
  const SearchableDropdownFormField({
    super.key,
    required this.items,
    required this.itemLabelBuilder,
    required this.onChanged,
    this.value,
    this.decoration,
    this.hintText,
    this.validator,
    this.autovalidateMode,
    this.dialogTitle,
    this.onCreate,
    this.createLabel,
  });

  final List<T> items;
  final String Function(T item) itemLabelBuilder;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final InputDecoration? decoration;
  final String? hintText;
  final FormFieldValidator<T>? validator;
  final AutovalidateMode? autovalidateMode;
  final String? dialogTitle;
  final VoidCallback? onCreate;
  final String? createLabel;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (field) {
        final enabled = onChanged != null;
        final selectedText = field.value == null
            ? null
            : itemLabelBuilder(field.value as T);

        final effectiveDecoration = (decoration ?? const InputDecoration())
            .copyWith(
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
              enabled: enabled,
            );

        Future<void> openPicker() async {
          if (!enabled) return;
          final picked = await _showSearchDialog<T>(
            context,
            title:
                dialogTitle ?? effectiveDecoration.labelText ?? 'Select option',
            items: items,
            selected: field.value,
            itemLabelBuilder: itemLabelBuilder,
            onCreate: onCreate,
            createLabel: createLabel,
          );
          if (picked == null) return;
          field.didChange(picked);
          onChanged?.call(picked);
        }

        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.f4): _OpenSelectionIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _OpenSelectionIntent: CallbackAction<_OpenSelectionIntent>(
                onInvoke: (_) {
                  openPicker();
                  return null;
                },
              ),
            },
            child: FocusableActionDetector(
              child: InkWell(
                onTap: enabled ? openPicker : null,
                child: InputDecorator(
                  decoration: effectiveDecoration,
                  isEmpty: selectedText == null || selectedText.isEmpty,
                  child: Text(
                    selectedText ?? hintText ?? 'Select',
                    style: TextStyle(
                      color: selectedText == null
                          ? Colors.black54
                          : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoveSelectionIntent extends Intent {
  const _MoveSelectionIntent(this.delta);
  final int delta;
}

class _SubmitSelectionIntent extends Intent {
  const _SubmitSelectionIntent();
}

class _OpenSelectionIntent extends Intent {
  const _OpenSelectionIntent();
}

Future<T?> _showSearchDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required T? selected,
  required String Function(T item) itemLabelBuilder,
  VoidCallback? onCreate,
  String? createLabel,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final searchCtrl = TextEditingController();
      var query = '';
      var highlightedIndex = 0;

      List<T> filteredItems() {
        final normalized = query.trim().toLowerCase();
        final list = normalized.isEmpty
            ? items
            : items
                  .where(
                    (item) => itemLabelBuilder(
                      item,
                    ).toLowerCase().contains(normalized),
                  )
                  .toList(growable: false);
        return list;
      }

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = filteredItems();
          if (filtered.isEmpty) {
            highlightedIndex = 0;
          } else if (highlightedIndex >= filtered.length) {
            highlightedIndex = filtered.length - 1;
          }

          void move(int delta) {
            if (filtered.isEmpty) return;
            setDialogState(() {
              final next = highlightedIndex + delta;
              if (next < 0) {
                highlightedIndex = 0;
              } else if (next >= filtered.length) {
                highlightedIndex = filtered.length - 1;
              } else {
                highlightedIndex = next;
              }
            });
          }

          void submit() {
            if (filtered.isEmpty) return;
            Navigator.of(context).pop(filtered[highlightedIndex]);
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 380,
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.arrowDown):
                      _MoveSelectionIntent(1),
                  SingleActivator(LogicalKeyboardKey.arrowUp):
                      _MoveSelectionIntent(-1),
                  SingleActivator(LogicalKeyboardKey.enter):
                      _SubmitSelectionIntent(),
                  SingleActivator(LogicalKeyboardKey.numpadEnter):
                      _SubmitSelectionIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _MoveSelectionIntent: CallbackAction<_MoveSelectionIntent>(
                      onInvoke: (intent) {
                        move(intent.delta);
                        return null;
                      },
                    ),
                    _SubmitSelectionIntent:
                        CallbackAction<_SubmitSelectionIntent>(
                          onInvoke: (intent) {
                            submit();
                            return null;
                          },
                        ),
                  },
                  child: Focus(
                    autofocus: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search by keyword',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              query = value;
                              highlightedIndex = 0;
                            });
                          },
                          onSubmitted: (_) => submit(),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Text('No matching option found.'),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, index) {
                                    final item = filtered[index];
                                    final label = itemLabelBuilder(item);
                                    final highlighted =
                                        index == highlightedIndex;
                                    final isSelected = selected == item;
                                    return ListTile(
                                      dense: true,
                                      selected: highlighted,
                                      tileColor: highlighted
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : null,
                                      leading: Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 18,
                                      ),
                                      title: Text(label),
                                      onTap: () =>
                                          Navigator.of(context).pop(item),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              if (onCreate != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCreate();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(createLabel ?? 'Create'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}
