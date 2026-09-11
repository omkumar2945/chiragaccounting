import 'package:flutter/foundation.dart';

@immutable
class AppEvent {
  const AppEvent({
    required this.eventId,
    required this.correlationId,
    required this.tenantId,
    required this.eventType,
    required this.module,
    required this.action,
    required this.version,
    required this.clientId,
    required this.businessId,
    required this.entityType,
    required this.entityId,
    required this.performedBy,
    required this.role,
    required this.timestamp,
    required this.priority,
    required this.payload,
  });

  final String eventId;
  final String correlationId;
  final String tenantId;
  final String eventType;
  final String module;
  final String action;
  final String version;
  final String clientId;
  final String businessId;
  final String entityType;
  final String entityId;
  final String performedBy;
  final String role;
  final DateTime timestamp;
  final String priority;
  final Map<String, dynamic> payload;

  factory AppEvent.create({
    required String eventType,
    required String entityType,
    required String entityId,
    String correlationId = '',
    String tenantId = 'default-tenant',
    String module = 'general',
    String action = 'changed',
    String version = '1.0',
    String clientId = '',
    String businessId = 'chirag-main',
    String performedBy = 'system',
    String role = 'system',
    String priority = 'normal',
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    final now = DateTime.now().toUtc();
    final tick = now.microsecondsSinceEpoch;
    return AppEvent(
      eventId: 'evt-$tick-${eventType.hashCode.abs()}',
      correlationId: correlationId.isEmpty ? 'corr-$tick' : correlationId,
      tenantId: tenantId,
      eventType: eventType,
      module: module,
      action: action,
      version: version,
      clientId: clientId,
      businessId: businessId,
      entityType: entityType,
      entityId: entityId,
      performedBy: performedBy,
      role: role,
      timestamp: now,
      priority: priority,
      payload: payload,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'eventId': eventId,
      'correlationId': correlationId,
      'tenantId': tenantId,
      'eventType': eventType,
      'module': module,
      'action': action,
      'version': version,
      'clientId': clientId,
      'businessId': businessId,
      'entityType': entityType,
      'entityId': entityId,
      'performedBy': performedBy,
      'role': role,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority,
      'payload': payload,
    };
  }
}
