import 'package:chirag_accounting/features/roles/models/hierarchical_permission_model.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

class HierarchicalPermissionEvaluator {
  const HierarchicalPermissionEvaluator({this.profile});

  final HierarchicalPermissionProfile? profile;

  PermissionLevel resolveModulePermission(UserRole role, AppModule module) {
    var resolved = PermissionMatrix.getPermission(role, module);

    if (profile == null) {
      return resolved;
    }

    for (final override in profile!.orderedOverrides) {
      final overrideLevel = override.moduleLevels[module];
      if (overrideLevel != null) {
        resolved = overrideLevel;
      }
    }

    return resolved;
  }

  bool canAccessModule(UserRole role, AppModule module) {
    return resolveModulePermission(role, module) != PermissionLevel.none;
  }

  bool canEditModule(UserRole role, AppModule module) {
    final level = resolveModulePermission(role, module);
    return level == PermissionLevel.full || level == PermissionLevel.limited;
  }

  bool hasFullModuleAccess(UserRole role, AppModule module) {
    return resolveModulePermission(role, module) == PermissionLevel.full;
  }

  bool hasScreenAction(
    UserRole role,
    AppModule module,
    String screenKey,
    PermissionAction action,
  ) {
    if (!canAccessModule(role, module)) {
      return false;
    }

    if (profile == null) {
      return _defaultActionByLevel(resolveModulePermission(role, module), action);
    }

    Set<PermissionAction>? latest;
    for (final override in profile!.orderedOverrides) {
      final actions = override.screenActions[screenKey];
      if (actions != null) {
        latest = actions;
      }
    }

    if (latest == null) {
      return _defaultActionByLevel(resolveModulePermission(role, module), action);
    }

    return latest.contains(action);
  }

  bool hasBankingPermission(UserRole role, BankingPermission permission) {
    var allowed = PermissionMatrix.hasBankingPermission(role, permission);

    if (profile == null) {
      return allowed;
    }

    for (final override in profile!.orderedOverrides) {
      if (override.deniedBanking.contains(permission)) {
        allowed = false;
      }
      if (override.allowedBanking.contains(permission)) {
        allowed = true;
      }
    }

    return allowed;
  }

  Set<BankingPermission> bankingPermissions(UserRole role) {
    final resolved = <BankingPermission>{};
    for (final permission in BankingPermission.values) {
      if (hasBankingPermission(role, permission)) {
        resolved.add(permission);
      }
    }
    return resolved;
  }

  bool hasReportPermission(UserRole role, ReportPermission permission) {
    var allowed = PermissionMatrix.hasReportPermission(role, permission);

    if (profile == null) {
      return allowed;
    }

    for (final override in profile!.orderedOverrides) {
      if (override.deniedReports.contains(permission)) {
        allowed = false;
      }
      if (override.allowedReports.contains(permission)) {
        allowed = true;
      }
    }

    return allowed;
  }

  Set<ReportPermission> reportPermissions(UserRole role) {
    final resolved = <ReportPermission>{};
    for (final permission in ReportPermission.values) {
      if (hasReportPermission(role, permission)) {
        resolved.add(permission);
      }
    }
    return resolved;
  }

  bool _defaultActionByLevel(PermissionLevel level, PermissionAction action) {
    switch (level) {
      case PermissionLevel.none:
        return false;
      case PermissionLevel.view:
        return action == PermissionAction.view ||
            action == PermissionAction.print ||
            action == PermissionAction.exportExcel ||
            action == PermissionAction.exportPdf ||
            action == PermissionAction.share ||
            action == PermissionAction.email ||
            action == PermissionAction.whatsapp;
      case PermissionLevel.limited:
        return action != PermissionAction.delete &&
            action != PermissionAction.lock &&
            action != PermissionAction.unlock;
      case PermissionLevel.full:
        return true;
    }
  }
}
