import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/roles/services/permission_service.dart';

class RoleController extends ChangeNotifier {
  PermissionService? _permissionService;

  PermissionService? get permissionService => _permissionService;

  void setUser(UserModel? user) {
    _permissionService = user != null ? PermissionService(user) : null;
    notifyListeners();
  }

  bool canAccess(AppModule module) =>
      _permissionService?.canAccess(module) ?? false;

  bool canEdit(AppModule module) =>
      _permissionService?.canEdit(module) ?? false;

  bool get isAdmin => _permissionService?.isAdmin ?? false;

  List<AppModule> get accessibleModules =>
      _permissionService?.accessibleModules ?? [];

    Set<BankingPermission> get bankingPermissions =>
      _permissionService?.bankingPermissions ?? const <BankingPermission>{};

    bool canBank(BankingPermission permission) =>
      _permissionService?.canBank(permission) ?? false;

      Set<ReportPermission> get reportPermissions =>
        _permissionService?.reportPermissions ?? const <ReportPermission>{};

      bool canReport(ReportPermission permission) =>
        _permissionService?.canReport(permission) ?? false;
}
