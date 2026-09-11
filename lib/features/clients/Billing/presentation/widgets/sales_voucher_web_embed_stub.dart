import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

Widget buildSalesVoucherWebEmbed(
  String sourcePath, {
  required SalesService salesService,
  required PurchaseService purchaseService,
  VoidCallback? onOpenBusinessTemplate,
}) {
  return Center(
    child: Container(
      width: 520,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9E2F2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Voucher Billing System',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The full billing system is bundled for the web client at $sourcePath.',
            style: const TextStyle(color: Color(0xFF546E8A)),
          ),
        ],
      ),
    ),
  );
}
