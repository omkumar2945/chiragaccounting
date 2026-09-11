import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/inbox/services/universal_inbox_service.dart';

class UniversalInboxScreen extends StatelessWidget {
  const UniversalInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<UniversalInboxService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Universal Inbox (${inbox.unreadCount})'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: inbox.markAllRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: inbox.items.length,
        itemBuilder: (context, index) {
          final item = inbox.items[index];
          return ListTile(
            leading: Icon(
              item.isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
              color: item.isRead ? Colors.grey : Colors.blue,
            ),
            title: Text(item.title),
            subtitle: Text(
              '${item.message}\n${DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt)}',
            ),
            isThreeLine: true,
            trailing: Text(item.channel),
            onTap: () => context.read<UniversalInboxService>().markRead(item.id),
          );
        },
      ),
    );
  }
}
