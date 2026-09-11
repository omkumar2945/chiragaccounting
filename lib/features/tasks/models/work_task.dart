import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/features/workflow/models/universal_status.dart';

enum WorkQueueBucket {
  pendingOcr,
  waitingClient,
  waitingAccountant,
  waitingCa,
  waitingAuditor,
  waitingApproval,
  completedToday,
  overdue,
  escalated,
}

@immutable
class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    required this.clientName,
    required this.entityType,
    required this.entityId,
    required this.owner,
    required this.reviewer,
    required this.dueDate,
    required this.status,
    required this.bucket,
    required this.slaHours,
    required this.createdAt,
    this.dependencies = const <String>[],
    this.attachments = const <String>[],
    this.comments = const <String>[],
    this.remarks = '',
  });

  final String id;
  final String title;
  final String clientName;
  final String entityType;
  final String entityId;
  final String owner;
  final String reviewer;
  final DateTime dueDate;
  final UniversalStatus status;
  final WorkQueueBucket bucket;
  final int slaHours;
  final DateTime createdAt;
  final List<String> dependencies;
  final List<String> attachments;
  final List<String> comments;
  final String remarks;

  WorkTask copyWith({
    UniversalStatus? status,
    WorkQueueBucket? bucket,
    DateTime? dueDate,
    String? owner,
    String? reviewer,
    String? remarks,
    List<String>? dependencies,
    List<String>? attachments,
    List<String>? comments,
  }) {
    return WorkTask(
      id: id,
      title: title,
      clientName: clientName,
      entityType: entityType,
      entityId: entityId,
      owner: owner ?? this.owner,
      reviewer: reviewer ?? this.reviewer,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      bucket: bucket ?? this.bucket,
      slaHours: slaHours,
      createdAt: createdAt,
      dependencies: dependencies ?? this.dependencies,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'clientName': clientName,
      'entityType': entityType,
      'entityId': entityId,
      'owner': owner,
      'reviewer': reviewer,
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'bucket': bucket.name,
      'slaHours': slaHours,
      'createdAt': createdAt.toIso8601String(),
      'dependencies': dependencies,
      'attachments': attachments,
      'comments': comments,
      'remarks': remarks,
    };
  }

  factory WorkTask.fromMap(Map<String, dynamic> map) {
    return WorkTask(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      entityType: map['entityType']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      owner: map['owner']?.toString() ?? '',
      reviewer: map['reviewer']?.toString() ?? '',
      dueDate: DateTime.tryParse(map['dueDate']?.toString() ?? '') ?? DateTime.now(),
      status: UniversalStatus.values.firstWhere(
        (value) => value.name == map['status']?.toString(),
        orElse: () => UniversalStatus.draft,
      ),
      bucket: WorkQueueBucket.values.firstWhere(
        (value) => value.name == map['bucket']?.toString(),
        orElse: () => WorkQueueBucket.waitingAccountant,
      ),
      slaHours: int.tryParse(map['slaHours']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      dependencies: (map['dependencies'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      attachments: (map['attachments'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      comments: (map['comments'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      remarks: map['remarks']?.toString() ?? '',
    );
  }
}
