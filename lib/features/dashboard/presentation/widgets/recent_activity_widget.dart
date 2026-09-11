import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chirag_accounting/features/dashboard/models/activity_model.dart';

class RecentActivityWidget extends StatelessWidget {
  final List<ActivityModel> activities;

  const RecentActivityWidget({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text(
            'Recent Activities',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 12),
          ...activities.map((a) => _ActivityTile(activity: a)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityModel activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(activity.type);
    final formatted = NumberFormat('#,##,##0', 'en_IN').format(activity.amount);
    final timeAgo = _timeAgo(activity.timestamp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon(activity.type), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  activity.subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$formatted',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: activity.type == ActivityType.receipt ||
                          activity.type == ActivityType.sale
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              Text(timeAgo,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  static Color _typeColor(ActivityType type) {
    switch (type) {
      case ActivityType.sale:
        return Colors.green;
      case ActivityType.purchase:
        return Colors.orange;
      case ActivityType.receipt:
        return Colors.teal;
      case ActivityType.payment:
        return Colors.red;
      case ActivityType.bank:
        return Colors.blue;
      case ActivityType.gst:
        return Colors.purple;
    }
  }

  static IconData _typeIcon(ActivityType type) {
    switch (type) {
      case ActivityType.sale:
        return Icons.point_of_sale;
      case ActivityType.purchase:
        return Icons.shopping_cart_outlined;
      case ActivityType.receipt:
        return Icons.payments_outlined;
      case ActivityType.payment:
        return Icons.send_outlined;
      case ActivityType.bank:
        return Icons.account_balance_outlined;
      case ActivityType.gst:
        return Icons.receipt_long_outlined;
    }
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
