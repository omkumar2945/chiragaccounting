import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

class PermissionService {
  final UserModel? _currentUser;

  PermissionService(this._currentUser);

  bool canAccess(AppModule module) {
    if (_currentUser == null) return false;
    return PermissionMatrix.canAccess(_currentUser.role, module);
  }

  bool canEdit(AppModule module) {
    if (_currentUser == null) return false;
    return PermissionMatrix.canEdit(_currentUser.role, module);
  }

  bool hasFullAccess(AppModule module) {
    if (_currentUser == null) return false;
    return PermissionMatrix.hasFullAccess(_currentUser.role, module);
  }

  PermissionLevel getPermissionLevel(AppModule module) {
    if (_currentUser == null) return PermissionLevel.none;
    return PermissionMatrix.getPermission(_currentUser.role, module);
  }

  bool get isAdmin =>
      _currentUser?.role == UserRole.superAdmin ||
      _currentUser?.role == UserRole.firmAdmin ||
      _currentUser?.role == UserRole.admin ||
      _currentUser?.role == UserRole.businessOwner;

  List<AppModule> get accessibleModules {
    if (_currentUser == null) return [];
    return AppModule.values.where((m) => canAccess(m)).toList();
  }

  Set<BankingPermission> get bankingPermissions {
    if (_currentUser == null) return const <BankingPermission>{};
    return PermissionMatrix.getBankingPermissions(_currentUser.role);
  }

  bool canBank(BankingPermission permission) {
    if (_currentUser == null) return false;
    return PermissionMatrix.hasBankingPermission(_currentUser.role, permission);
  }

  Set<ReportPermission> get reportPermissions {
    if (_currentUser == null) return const <ReportPermission>{};
    return PermissionMatrix.getReportPermissions(_currentUser.role);
  }

  bool canReport(ReportPermission permission) {
    if (_currentUser == null) return false;
    return PermissionMatrix.hasReportPermission(_currentUser.role, permission);
  }
}
