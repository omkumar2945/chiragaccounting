import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/features/dashboard/controllers/dashboard_controller.dart';
import 'package:chirag_accounting/features/dashboard/models/notification_model.dart';

class NotificationsPanelSheet extends StatelessWidget {
  const NotificationsPanelSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardController>(
      builder: (context, controller, _) {
        final notifications = controller.notifications;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          builder: (context, scrollCtrl) => Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (controller.unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${controller.unreadCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: controller.markAllRead,
                      child: const Text('Mark all read',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Text('No notifications',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) =>
                            _NotificationTile(n: notifications[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel n;

  const _NotificationTile({required this.n});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: n.isRead ? null : const Color(0xFFE8EAF6),
      leading: CircleAvatar(
        backgroundColor: _typeColor(n.type).withValues(alpha: 0.15),
        child: Icon(_typeIcon(n.type), color: _typeColor(n.type), size: 20),
      ),
      title: Text(
        n.title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.message, style: const TextStyle(fontSize: 12)),
          Text(
            _timeAgo(n.createdAt),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () =>
          context.read<DashboardController>().markNotificationRead(n.id),
    );
  }

  static Color _typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.gstDue:
        return Colors.red;
      case NotificationType.tdsDue:
        return Colors.orange;
      case NotificationType.pendingBills:
        return Colors.amber;
      case NotificationType.bankReconciliation:
        return Colors.blue;
      case NotificationType.subscriptionExpiry:
        return Colors.purple;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  static IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.gstDue:
        return Icons.receipt_long;
      case NotificationType.tdsDue:
        return Icons.account_balance;
      case NotificationType.pendingBills:
        return Icons.pending_actions;
      case NotificationType.bankReconciliation:
        return Icons.sync;
      case NotificationType.subscriptionExpiry:
        return Icons.card_membership;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
