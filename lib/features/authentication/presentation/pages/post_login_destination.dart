import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/accountant/presentation/pages/accountant_dashboard_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/admin_panel_screen.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/auditor_command_center_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/ca_compliance_review_center_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/manager_operations_center_screen.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/uni_desk/presentation/pages/uni_desk_screen.dart';

enum PostLoginExperience {
  admin,
  accountant,
  auditor,
  complianceReviewer,
  manager,
  uniDesk,
  dashboard,
}

PostLoginExperience resolvePostLoginExperience({
  required UserRole? role,
  bool openAdminPanel = false,
  bool openUniDesk = false,
}) {
  if (openUniDesk) return PostLoginExperience.uniDesk;
  if (openAdminPanel) return PostLoginExperience.admin;

  return switch (role) {
    UserRole.superAdmin || UserRole.admin => PostLoginExperience.admin,
    UserRole.accountant => PostLoginExperience.accountant,
    UserRole.partner || UserRole.firmAdmin => PostLoginExperience.auditor,
    UserRole.checker => PostLoginExperience.complianceReviewer,
    UserRole.manager => PostLoginExperience.manager,
    _ => PostLoginExperience.dashboard,
  };
}

class PostLoginDestination extends StatelessWidget {
  const PostLoginDestination({
    super.key,
    this.openAdminPanel = false,
    this.openUniDesk = false,
  });

  final bool openAdminPanel;
  final bool openUniDesk;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthController>().currentUser?.role;
    final experience = resolvePostLoginExperience(
      role: role,
      openAdminPanel: openAdminPanel,
      openUniDesk: openUniDesk,
    );

    return switch (experience) {
      PostLoginExperience.admin => const AdminPanelScreen(),
      PostLoginExperience.accountant => const AccountantDashboardScreen(),
      PostLoginExperience.auditor => const AuditorCommandCenterScreen(),
      PostLoginExperience.complianceReviewer =>
        const CaComplianceReviewCenterScreen(),
      PostLoginExperience.manager => const ManagerOperationsCenterScreen(),
      PostLoginExperience.uniDesk => const UniDeskScreen(),
      PostLoginExperience.dashboard => const DashboardScreen(),
    };
  }
}
