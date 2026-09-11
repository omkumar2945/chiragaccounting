import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/vouchers/presentation/models/voucher_entry_type.dart';

class VoucherShortcutShell extends StatelessWidget {
  const VoucherShortcutShell({
    super.key,
    required this.currentType,
    required this.onSelected,
    required this.child,
  });

  final VoucherEntryType currentType;
  final ValueChanged<VoucherEntryType> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
