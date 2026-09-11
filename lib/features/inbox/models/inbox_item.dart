import 'package:flutter/foundation.dart';

@immutable
class InboxItem {
  const InboxItem({
    required this.id,
    required this.title,
    required this.message,
    required this.channel,
    required this.createdAt,
    required this.referenceType,
    required this.referenceId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final String channel;
  final DateTime createdAt;
  final String referenceType;
  final String referenceId;
  final bool isRead;

  InboxItem copyWith({bool? isRead}) {
    return InboxItem(
      id: id,
      title: title,
      message: message,
      channel: channel,
      createdAt: createdAt,
      referenceType: referenceType,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
    );
  }
}
