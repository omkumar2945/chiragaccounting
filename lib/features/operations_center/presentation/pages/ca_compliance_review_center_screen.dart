import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/ca_workspace/presentation/pages/ca_team_workspace_screen.dart';
import 'package:chirag_accounting/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/compat/screens/client_reports_screen_compat.dart';
import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';
import 'package:chirag_accounting/features/reports/presentation/pages/quick_provisional_report_screen.dart';
import 'package:chirag_accounting/shared/widgets/profile/profile_avatar_menu.dart';
import 'package:chirag_accounting/shared/widgets/session_logout_button.dart';

class CaComplianceReviewCenterScreen extends StatelessWidget {
  const CaComplianceReviewCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<OperationsCenterService>().snapshot;

    Widget kpi(String title) {
      final value = (snapshot.metrics[title] ?? 0).toString();
      return Card(
        child: ListTile(
          title: Text(title),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CA Compliance Review Center'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
            icon: const Icon(Icons.dashboard_outlined),
          ),
          IconButton(
            tooltip: 'CA Team Workspace',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CaTeamWorkspaceScreen()),
            ),
            icon: const Icon(Icons.groups_outlined),
          ),
          IconButton(
            tooltip: 'Reports & Analytics',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ClientReportsScreen(),
              ),
            ),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Provisional Reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const QuickProvisionalReportScreen(),
              ),
            ),
            icon: const Icon(Icons.auto_graph_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientSettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const ProfileAvatarMenu(showDashboardOption: false),
          const SessionLogoutButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Today Filings and Review Queue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          kpi('GST Returns Due'),
          kpi('Income Tax Due'),
          kpi('ROC Due'),
          kpi('TDS Returns'),
          kpi('Pending Filing'),
          kpi('Pending Approvals'),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Includes: GST, Income Tax, ROC, Notices, Appeals, Pending Client Documents, Approval Queue, Digital Signature Queue, Compliance Calendar.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
