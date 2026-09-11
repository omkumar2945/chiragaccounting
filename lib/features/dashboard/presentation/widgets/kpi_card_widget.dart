import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/dashboard/models/kpi_model.dart';

class KpiCardWidget extends StatelessWidget {
  final KpiModel kpi;

  const KpiCardWidget({super.key, required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kpiColor(kpi.type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _kpiIcon(kpi.type),
                  color: _kpiColor(kpi.type),
                  size: 20,
                ),
              ),
              const Spacer(),
              if (kpi.trend != null && kpi.trend != KpiTrend.neutral)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      kpi.trend == KpiTrend.up
                          ? Icons.trending_up
                          : Icons.trending_down,
                      size: 14,
                      color: kpi.trend == KpiTrend.up
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${kpi.trendPercent?.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kpi.trend == KpiTrend.up
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            kpi.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kpi.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (kpi.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              kpi.subtitle!,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  static Color _kpiColor(KpiType type) {
    switch (type) {
      case KpiType.sales:
        return Colors.green;
      case KpiType.purchase:
        return Colors.orange;
      case KpiType.cash:
        return Colors.teal;
      case KpiType.bank:
        return Colors.blue;
      case KpiType.gstPayable:
        return Colors.red;
      case KpiType.gstReceivable:
        return Colors.cyan;
      case KpiType.debtors:
        return Colors.purple;
      case KpiType.creditors:
        return Colors.deepOrange;
      case KpiType.profit:
        return Colors.indigo;
      case KpiType.clients:
        return Colors.pink;
      case KpiType.tasks:
        return Colors.amber;
    }
  }

  static IconData _kpiIcon(KpiType type) {
    switch (type) {
      case KpiType.sales:
        return Icons.point_of_sale;
      case KpiType.purchase:
        return Icons.shopping_cart_outlined;
      case KpiType.cash:
        return Icons.account_balance_wallet_outlined;
      case KpiType.bank:
        return Icons.account_balance_outlined;
      case KpiType.gstPayable:
        return Icons.receipt_long_outlined;
      case KpiType.gstReceivable:
        return Icons.receipt_outlined;
      case KpiType.debtors:
        return Icons.people_outline;
      case KpiType.creditors:
        return Icons.business_outlined;
      case KpiType.profit:
        return Icons.show_chart;
      case KpiType.clients:
        return Icons.groups_outlined;
      case KpiType.tasks:
        return Icons.task_alt_outlined;
    }
  }
}
