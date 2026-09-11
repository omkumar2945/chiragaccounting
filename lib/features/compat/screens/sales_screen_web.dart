import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/sales_screen.dart'
    as sales;

class SalesScreen extends StatelessWidget {
  final String initialSearchQuery;
  final bool readOnlyAuditMode;

  const SalesScreen({
    super.key,
    this.initialSearchQuery = '',
    this.readOnlyAuditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return sales.SalesScreen(
      initialSearchQuery: initialSearchQuery,
      readOnlyAuditMode: readOnlyAuditMode,
    );
  }
}