import 'package:chirag_accounting/core/events/app_event.dart';

enum AdminAuditEntity {
  company,
  branch,
  department,
  user,
  roleAssignment,
  permissionPolicy,
  approvalPolicy,
  moduleActivation,
}

enum AdminAuditAction {
  created,
  updated,
  activated,
  deactivated,
  archived,
  assigned,
  revoked,
  passwordReset,
  locked,
  unlocked,
  forceLogout,
}

class AdminAuditEvent {
  AdminAuditEvent._();

  static AppEvent create({
    required String eventType,
    required AdminAuditEntity entity,
    required String entityId,
    required AdminAuditAction action,
    required String actorUserId,
    required String actorRole,
    required String companyId,
    String correlationId = '',
    String reason = '',
    Map<String, dynamic> before = const <String, dynamic>{},
    Map<String, dynamic> after = const <String, dynamic>{},
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return AppEvent.create(
      eventType: eventType,
      correlationId: correlationId,
      tenantId: companyId,
      module: 'admin',
      action: action.name,
      clientId: companyId,
      entityType: entity.name,
      entityId: entityId,
      performedBy: actorUserId,
      role: actorRole,
      priority: _priorityFor(action),
      payload: <String, dynamic>{
        'companyId': companyId,
        'reason': reason,
        'before': Map<String, dynamic>.unmodifiable(before),
        'after': Map<String, dynamic>.unmodifiable(after),
        'metadata': Map<String, dynamic>.unmodifiable(metadata),
      },
    );
  }

  static String _priorityFor(AdminAuditAction action) {
    switch (action) {
      case AdminAuditAction.archived:
      case AdminAuditAction.passwordReset:
      case AdminAuditAction.locked:
      case AdminAuditAction.forceLogout:
      case AdminAuditAction.revoked:
        return 'high';
      case AdminAuditAction.created:
      case AdminAuditAction.updated:
      case AdminAuditAction.activated:
      case AdminAuditAction.deactivated:
      case AdminAuditAction.assigned:
      case AdminAuditAction.unlocked:
        return 'normal';
    }
  }
}