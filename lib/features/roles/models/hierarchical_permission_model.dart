import 'package:chirag_accounting/features/roles/models/permission_model.dart';

/// Action-level permissions used at screen granularity.
enum PermissionAction {
  view,
  add,
  edit,
  delete,
  print,
  exportExcel,
  exportPdf,
  import,
  approve,
  reject,
  cancel,
  reopen,
  lock,
  unlock,
  share,
  email,
  whatsapp,
  apiAccess,
}

/// A scope-level override (company/branch/department/role/user).
class PermissionScopeOverride {
  const PermissionScopeOverride({
    required this.scopeId,
    this.moduleLevels = const <AppModule, PermissionLevel>{},
    this.screenActions = const <String, Set<PermissionAction>>{},
    this.allowedBanking = const <BankingPermission>{},
    this.deniedBanking = const <BankingPermission>{},
    this.allowedReports = const <ReportPermission>{},
    this.deniedReports = const <ReportPermission>{},
  });

  final String scopeId;
  final Map<AppModule, PermissionLevel> moduleLevels;
  final Map<String, Set<PermissionAction>> screenActions;
  final Set<BankingPermission> allowedBanking;
  final Set<BankingPermission> deniedBanking;
  final Set<ReportPermission> allowedReports;
  final Set<ReportPermission> deniedReports;
}

/// Runtime permission profile attached to user session.
///
/// Precedence order for overrides:
/// company -> branch -> department -> role -> user
class HierarchicalPermissionProfile {
  const HierarchicalPermissionProfile({
    required this.companyId,
    required this.branchId,
    required this.departmentId,
    required this.roleId,
    required this.userId,
    this.companyOverride,
    this.branchOverride,
    this.departmentOverride,
    this.roleOverride,
    this.userOverride,
  });

  final String companyId;
  final String branchId;
  final String departmentId;
  final String roleId;
  final String userId;

  final PermissionScopeOverride? companyOverride;
  final PermissionScopeOverride? branchOverride;
  final PermissionScopeOverride? departmentOverride;
  final PermissionScopeOverride? roleOverride;
  final PermissionScopeOverride? userOverride;

  List<PermissionScopeOverride> get orderedOverrides => <PermissionScopeOverride>[
      ?companyOverride,
      ?branchOverride,
      ?departmentOverride,
      ?roleOverride,
      ?userOverride,
      ];
}
