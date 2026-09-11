import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/business_templates/presentation/pages/business_template_setup_screen.dart';
import 'package:chirag_accounting/features/clients/Reports/client_reports_screen.dart';
import 'package:chirag_accounting/features/reports/presentation/pages/quick_provisional_report_screen.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

class ClientAccountingWorkspaceScreen extends StatefulWidget {
  const ClientAccountingWorkspaceScreen({
    this.initialArea = ClientAccountingWorkspaceArea.templates,
    super.key,
  });

  final ClientAccountingWorkspaceArea initialArea;

  @override
  State<ClientAccountingWorkspaceScreen> createState() =>
      _ClientAccountingWorkspaceScreenState();
}

enum ClientAccountingWorkspaceArea { templates, reports, provisionalReports }

class _ClientAccountingWorkspaceScreenState
    extends State<ClientAccountingWorkspaceScreen> {
  String? _selectedClientId;
  late ClientAccountingWorkspaceArea _selectedArea;

  @override
  void initState() {
    super.initState();
    _selectedArea = widget.initialArea;
  }

  bool _canManageTemplates(UserRole? role) =>
      role == UserRole.superAdmin ||
      role == UserRole.admin ||
      role == UserRole.firmAdmin;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final directory = context.watch<AdminUserService?>();
    final selfScoped =
        user?.role.isClient == true || user?.role.isBusinessOwner == true;
    final clients = selfScoped && user != null
        ? <UserModel>[user]
        : directory?.users
                  .where(
                    (candidate) =>
                        candidate.role.isClient && candidate.isActive,
                  )
                  .toList(growable: false) ??
              const <UserModel>[];
    final selectedClient = _selectedClient(clients);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Client Accounting Workspace'),
        backgroundColor: const Color(0xFF123C69),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Client scope',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF17324D),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Templates and reports open for the selected client account.',
            style: TextStyle(color: Color(0xFF60758A)),
          ),
          const SizedBox(height: 14),
          if (clients.isNotEmpty && !selfScoped)
            DropdownButtonFormField<String>(
              key: const ValueKey('client-accounting-client-selector'),
              initialValue: selectedClient?.id,
              decoration: const InputDecoration(
                labelText: 'Client',
                prefixIcon: Icon(Icons.business_outlined),
                border: OutlineInputBorder(),
              ),
              items: clients
                  .map(
                    (client) => DropdownMenuItem<String>(
                      value: client.id,
                      child: Text(
                        client.firmName.isEmpty ? client.name : client.firmName,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (clientId) =>
                  setState(() => _selectedClientId = clientId),
            )
          else if (selfScoped && user != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_outlined),
              title: Text(user.firmName.isEmpty ? user.name : user.firmName),
              subtitle: const Text('Current client account'),
            )
          else
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('No active clients available'),
              subtitle: Text('Add or activate a client in User Management.'),
            ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ClientAccountingWorkspaceArea>(
              key: const ValueKey('client-accounting-area-selector'),
              segments: const <ButtonSegment<ClientAccountingWorkspaceArea>>[
                ButtonSegment(
                  value: ClientAccountingWorkspaceArea.templates,
                  icon: Icon(Icons.dashboard_customize_outlined),
                  label: Text('Template'),
                ),
                ButtonSegment(
                  value: ClientAccountingWorkspaceArea.reports,
                  icon: Icon(Icons.analytics_outlined),
                  label: Text('Reports'),
                ),
                ButtonSegment(
                  value: ClientAccountingWorkspaceArea.provisionalReports,
                  icon: Icon(Icons.auto_graph_outlined),
                  label: Text('Provisional'),
                ),
              ],
              selected: <ClientAccountingWorkspaceArea>{_selectedArea},
              onSelectionChanged: (selection) {
                setState(() => _selectedArea = selection.first);
                _openArea(
                  selection.first,
                  selectedClient,
                  canManageTemplates: _canManageTemplates(user?.role),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _WorkspaceAction(
            icon: Icons.dashboard_customize_outlined,
            title: 'Universal Business Template',
            subtitle: _canManageTemplates(user?.role)
                ? 'Configure a client and generate a protected new version.'
                : 'View the client template. Changes require admin permission after activation.',
            onTap: selectedClient == null
                ? null
                : () => _openArea(
                    ClientAccountingWorkspaceArea.templates,
                    selectedClient,
                    canManageTemplates: _canManageTemplates(user?.role),
                  ),
          ),
          const SizedBox(height: 10),
          _WorkspaceAction(
            icon: Icons.analytics_outlined,
            title: 'Operational Reports',
            subtitle:
                'Sales, purchase, GST, outstanding and profit and loss reports.',
            onTap: selectedClient == null
                ? null
                : () => _openArea(
                    ClientAccountingWorkspaceArea.reports,
                    selectedClient,
                    canManageTemplates: _canManageTemplates(user?.role),
                  ),
          ),
          const SizedBox(height: 10),
          _WorkspaceAction(
            icon: Icons.auto_graph_outlined,
            title: 'Provisional Reports',
            subtitle: 'Projected profit and loss, balance sheet and cash flow.',
            onTap: selectedClient == null
                ? null
                : () => _openArea(
                    ClientAccountingWorkspaceArea.provisionalReports,
                    selectedClient,
                    canManageTemplates: _canManageTemplates(user?.role),
                  ),
          ),
        ],
      ),
    );
  }

  UserModel? _selectedClient(List<UserModel> clients) {
    if (clients.isEmpty) return null;
    final selectedId = _selectedClientId;
    if (selectedId == null) return clients.first;
    return clients.where((client) => client.id == selectedId).firstOrNull ??
        clients.first;
  }

  Future<void> _openArea(
    ClientAccountingWorkspaceArea area,
    UserModel? client, {
    required bool canManageTemplates,
  }) async {
    if (client == null) return;
    final child = switch (area) {
      ClientAccountingWorkspaceArea.templates => BusinessTemplateSetupScreen(
        clientId: client.id,
        clientName: client.firmName.isEmpty ? client.name : client.firmName,
        canManageExistingTemplate: canManageTemplates,
        hasVoucherEntries: !canManageTemplates,
      ),
      ClientAccountingWorkspaceArea.reports => const ClientReportsScreen(),
      ClientAccountingWorkspaceArea.provisionalReports =>
        const QuickProvisionalReportScreen(),
    };
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => child));
  }
}

class _WorkspaceAction extends StatelessWidget {
  const _WorkspaceAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(color: Color(0xFFD6E0EC)),
    ),
    child: ListTile(
      enabled: onTap != null,
      onTap: onTap,
      leading: Icon(icon, color: const Color(0xFF145DA0)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
