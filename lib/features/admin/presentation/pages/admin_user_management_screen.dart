import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/constants/import_template_content.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/features/services/gst_portal_lookup_service.dart';
import 'package:chirag_accounting/features/services/pincode_lookup_service.dart';

import 'package:chirag_accounting/core/utils/xlsx_workbook_reader.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/client_permission_management_screen.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/client_360_detail_screen.dart';

enum AdminClientManagementAction { clientList, importList, onboardClient }

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({
    super.key,
    this.initialAction = AdminClientManagementAction.clientList,
    this.initialActiveFilter,
    this.embedded = false,
  });

  final AdminClientManagementAction initialAction;
  final bool? initialActiveFilter;
  final bool embedded;

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  String _query = '';
  bool? _activeFilter;
  bool _importing = false;
  bool _initialActionHandled = false;
  final Set<String> _selectedUserIds = <String>{};
  ClientAccountStatus? _clientStatusFilter;
  ClientLoginStatus? _loginStatusFilter;
  String? _accountantFilter;
  String? _caFilter;
  String? _gstStateFilter;
  String? _serviceFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialActiveFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminUserService>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AdminUserService>();
    if (service.isLoaded && !_initialActionHandled) {
      _initialActionHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialAction) {
          case AdminClientManagementAction.clientList:
            break;
          case AdminClientManagementAction.importList:
            _importClients();
          case AdminClientManagementAction.onboardClient:
            _openUserForm();
        }
      });
    }
    final clientRecords = service.users
        .where((user) => user.role.isClient)
        .toList(growable: false);
    final users = clientRecords
        .where((user) {
          final query = _query.toLowerCase();
          final compliance = service.complianceFor(user.id);
          final access = service.accountingAccessFor(user.id);
          final matchesQuery =
              query.isEmpty ||
              user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.mobile.contains(query) ||
              user.id.toLowerCase().contains(query) ||
              user.firmName.toLowerCase().contains(query) ||
              user.accountOrigin.displayName.toLowerCase().contains(query) ||
              compliance.gstin.toLowerCase().contains(query) ||
              compliance.pan.toLowerCase().contains(query) ||
              compliance.state.toLowerCase().contains(query) ||
              compliance.city.toLowerCase().contains(query) ||
              compliance.services.any(
                (service) => service.toLowerCase().contains(query),
              ) ||
              compliance.gstRegistrationType.displayName.toLowerCase().contains(
                query,
              );
          final matchesStatus =
              _activeFilter == null || user.isActive == _activeFilter;
          final matchesClientStatus =
              _clientStatusFilter == null ||
              user.clientStatus == _clientStatusFilter;
          final matchesLoginStatus =
              _loginStatusFilter == null ||
              user.loginStatus == _loginStatusFilter;
          final matchesAccountant =
              _accountantFilter == null ||
              access.assignedAccountantId == _accountantFilter;
          final matchesCa =
              _caFilter == null || access.assignedCaId == _caFilter;
          final matchesState =
              _gstStateFilter == null || compliance.state == _gstStateFilter;
          final matchesService =
              _serviceFilter == null ||
              compliance.services.contains(_serviceFilter);
          return matchesQuery &&
              matchesStatus &&
              matchesClientStatus &&
              matchesLoginStatus &&
              matchesAccountant &&
              matchesCa &&
              matchesState &&
              matchesService;
        })
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Chirag Associates Clients'),
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Refresh clients',
                  onPressed: () => context.read<AdminUserService>().load(),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Import client list',
                  onPressed: _importing ? null : _importClients,
                  icon: const Icon(Icons.upload_file_outlined),
                ),
                IconButton(
                  tooltip: 'Onboard client',
                  onPressed: () => _openUserForm(),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUserForm(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Onboard Client'),
      ),
      body: service.isLoaded
          ? _buildBody(users, clientRecords, service)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBody(
    List<UserModel> users,
    List<UserModel> clientRecords,
    AdminUserService service,
  ) {
    final active = clientRecords.where((user) => user.isActive).length;
    final disabled = clientRecords.length - active;
    final selfRegistered = clientRecords
        .where((user) => user.accountOrigin == AccountOrigin.selfRegistered)
        .length;
    final uploaded = clientRecords
        .where((user) => user.accountOrigin == AccountOrigin.imported)
        .length;
    final composition = clientRecords
        .where(
          (user) =>
              service.complianceFor(user.id).gstRegistrationType ==
              GstRegistrationType.composition,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(label: 'Total clients', value: '${clientRecords.length}'),
            _Metric(label: 'Active', value: '$active'),
            _Metric(label: 'Disabled', value: '$disabled'),
            _Metric(label: 'Self Registered', value: '$selfRegistered'),
            _Metric(label: 'Uploaded', value: '$uploaded'),
            _Metric(label: 'Composition', value: '$composition'),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD8E2F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search client ID, firm, contact, or mobile',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              SegmentedButton<bool?>(
                segments: const [
                  ButtonSegment<bool?>(value: null, label: Text('All')),
                  ButtonSegment<bool?>(value: true, label: Text('Active')),
                  ButtonSegment<bool?>(value: false, label: Text('Disabled')),
                ],
                selected: <bool?>{_activeFilter},
                onSelectionChanged: (selection) {
                  setState(() => _activeFilter = selection.first);
                },
              ),
              DropdownButton<ClientAccountStatus?>(
                value: _clientStatusFilter,
                hint: const Text('Onboarding Status'),
                items: <DropdownMenuItem<ClientAccountStatus?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Statuses'),
                  ),
                  ...ClientAccountStatus.values.map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.displayName),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _clientStatusFilter = value),
              ),
              DropdownButton<ClientLoginStatus?>(
                value: _loginStatusFilter,
                hint: const Text('Login Status'),
                items: <DropdownMenuItem<ClientLoginStatus?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Logins'),
                  ),
                  ...ClientLoginStatus.values.map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.displayName),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _loginStatusFilter = value),
              ),
              DropdownButton<String?>(
                value: _accountantFilter,
                hint: const Text('Accountant'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Accountants'),
                  ),
                  ...service.accountantAndCaUsers.map(
                    (user) => DropdownMenuItem(
                      value: user.id,
                      child: Text(user.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _accountantFilter = value),
              ),
              DropdownButton<String?>(
                value: _caFilter,
                hint: const Text('CA / Auditor'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(value: null, child: Text('All CAs')),
                  ...service.users
                      .where(
                        (user) =>
                            user.role == UserRole.firmAdmin ||
                            user.role == UserRole.checker,
                      )
                      .map(
                        (user) => DropdownMenuItem(
                          value: user.id,
                          child: Text(user.name),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => _caFilter = value),
              ),
              DropdownButton<String?>(
                value: _gstStateFilter,
                hint: const Text('GST State'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All States'),
                  ),
                  ..._filterOptions(
                    clientRecords.map(
                      (user) => service.complianceFor(user.id).state,
                    ),
                  ).map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setState(() => _gstStateFilter = value),
              ),
              DropdownButton<String?>(
                value: _serviceFilter,
                hint: const Text('Service Type'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Services'),
                  ),
                  ..._filterOptions(
                    clientRecords.expand(
                      (user) => service.complianceFor(user.id).services,
                    ),
                  ).map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setState(() => _serviceFilter = value),
              ),
              OutlinedButton.icon(
                onPressed: _importing ? null : _importClients,
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Client List'),
              ),
              FilledButton.icon(
                onPressed: () => _openUserForm(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Onboard Client'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            border: Border.all(color: const Color(0xFFBFDBFE)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client onboarding upload format',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Accepted files: CSV (.csv), Excel (.xlsx), and macro-enabled Excel (.xlsm).',
                    ),
                    Text(
                      'Required: client_name and at least one contact field (email or 10-digit mobile). Optional columns are included in the CSV template.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _downloadClientImportTemplate,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download CSV Template'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (users.isNotEmpty) ...[
          _buildSelectionBar(users),
          const SizedBox(height: 10),
        ],
        if (service.importIssues != null) ...[
          _ImportIssuesPanel(
            issues: service.importIssues!,
            onClear: service.clearImportIssues,
          ),
          const SizedBox(height: 10),
        ],
        if (users.isEmpty)
          const _EmptyUsers()
        else
          ...users.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildUserCard(UserModel user) {
    final service = context.read<AdminUserService>();
    final canManageAccountAccess = service.canManageAccountAccess(user.id);
    final compliance = service.complianceFor(user.id);
    final accountingAccess = service.accountingAccessFor(user.id);
    final assignedAccountant = service.accountantAndCaUsers
        .where((staff) => staff.id == accountingAccess.assignedAccountantId)
        .firstOrNull;
    final assignedCa = service.users
        .where((staff) => staff.id == accountingAccess.assignedCaId)
        .firstOrNull;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: _selectedUserIds.contains(user.id),
              onChanged: (selected) => setState(() {
                if (selected ?? false) {
                  _selectedUserIds.add(user.id);
                } else {
                  _selectedUserIds.remove(user.id);
                }
              }),
            ),
            CircleAvatar(
              backgroundColor: user.isActive
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              foregroundColor: user.isActive
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
              child: Icon(
                user.isActive
                    ? Icons.person_outline
                    : Icons.person_off_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      _StatusTag(isActive: user.isActive),
                      _ServiceTag(
                        label: user.clientStatus.displayName,
                        color: const Color(0xFF5D4037),
                      ),
                      _ServiceTag(
                        label: assignedCa == null
                            ? 'CA not assigned'
                            : 'CA: ${assignedCa.name}',
                        color: assignedCa == null
                            ? const Color(0xFF6D4C41)
                            : const Color(0xFF4527A0),
                      ),
                      _ServiceTag(
                        label: user.loginStatus.displayName,
                        color: const Color(0xFF37474F),
                      ),
                      _ServiceTag(
                        label: compliance.gstRegistrationType.displayName,
                        color:
                            compliance.gstRegistrationType ==
                                GstRegistrationType.composition
                            ? const Color(0xFFEF6C00)
                            : const Color(0xFF455A64),
                      ),
                      Text(
                        user.role.displayName,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      _ServiceTag(
                        label: user.accountOrigin.displayName,
                        color:
                            user.accountOrigin == AccountOrigin.selfRegistered
                            ? const Color(0xFF6A1B9A)
                            : user.accountOrigin == AccountOrigin.imported
                            ? const Color(0xFF00695C)
                            : const Color(0xFF0D47A1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Client ID: ${user.id}  |  ${user.firmName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    [
                      user.mobile,
                      user.email,
                    ].where((value) => value.isNotEmpty).join('  |  '),
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    'Last login: ${user.lastLoginAt == null ? 'Never' : _shortDate(user.lastLoginAt!)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (compliance.gstin.isNotEmpty)
                        Text(
                          'GSTIN: ${compliance.gstin}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (compliance.accountingEnabled)
                        const _ServiceTag(
                          label: 'Accounting',
                          color: Color(0xFF1565C0),
                        ),
                      if (compliance.gstEnabled)
                        const _ServiceTag(
                          label: 'GST',
                          color: Color(0xFF2E7D32),
                        ),
                      _ServiceTag(
                        label: assignedAccountant == null
                            ? 'Accountant not assigned'
                            : 'Assigned: ${assignedAccountant.name}',
                        color: assignedAccountant == null
                            ? const Color(0xFF6D4C41)
                            : const Color(0xFF00695C),
                      ),
                      _ServiceTag(
                        label: accountingAccess.canViewOlderHistory
                            ? 'Old reports published'
                            : 'History from ${_shortDate(accountingAccess.standardHistoryStartsOn)}',
                        color: accountingAccess.canViewOlderHistory
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF455A64),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Client actions',
              onSelected: (action) async {
                switch (action) {
                  case 'view':
                    await _showClientDetails(user);
                  case 'client360':
                    if (mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              Client360DetailScreen(clientName: user.firmName),
                        ),
                      );
                    }
                  case 'portal_permissions':
                    if (mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientPermissionManagementScreen(
                            initialClientId: user.id,
                          ),
                        ),
                      );
                    }
                  case 'edit':
                    await _openUserForm(user: user);
                  case 'status':
                    await _changeClientStatus(user);
                  case 'credentials':
                    await _sendCredentials(user, CredentialChannel.email);
                  case 'onboard':
                    await _onboardUsers(<String>[user.id]);
                  case 'send_email':
                    await _sendCredentials(user, CredentialChannel.email);
                  case 'send_sms':
                    await _sendCredentials(user, CredentialChannel.sms);
                  case 'accounting_access':
                    await _configureAccountingAccess(user);
                  case 'regenerate':
                    await _resetCredentials(user);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('View client details'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'client360',
                  child: ListTile(
                    leading: Icon(Icons.dashboard_customize_outlined),
                    title: Text('Open Client 360'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'portal_permissions',
                  child: ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('Portal & Permissions'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit profile'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (canManageAccountAccess) ...[
                  if (user.clientStatus ==
                          ClientAccountStatus.pendingApproval ||
                      user.clientStatus == ClientAccountStatus.notOnboarded)
                    const PopupMenuItem(
                      value: 'onboard',
                      child: ListTile(
                        leading: Icon(Icons.rocket_launch_outlined),
                        title: Text('Approve & Onboard'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  PopupMenuItem(
                    value: 'status',
                    child: ListTile(
                      leading: Icon(
                        user.isActive
                            ? Icons.person_off_outlined
                            : Icons.person_outlined,
                      ),
                      title: Text(
                        user.isActive ? 'Disable client' : 'Activate client',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'send_email',
                    enabled: user.isActive && user.email.isNotEmpty,
                    child: const ListTile(
                      leading: Icon(Icons.email_outlined),
                      title: Text('Send temporary password by Email'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'send_sms',
                    enabled: user.isActive && user.mobile.isNotEmpty,
                    child: const ListTile(
                      leading: Icon(Icons.sms_outlined),
                      title: Text('Send temporary password by SMS'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                const PopupMenuItem(
                  value: 'accounting_access',
                  child: ListTile(
                    leading: Icon(Icons.manage_history_outlined),
                    title: Text('Accounting access'),
                    subtitle: Text('Assign staff and publish old reports'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (canManageAccountAccess)
                  const PopupMenuItem(
                    value: 'regenerate',
                    child: ListTile(
                      leading: Icon(Icons.password_outlined),
                      title: Text('Generate new temporary password'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(List<UserModel> visibleUsers) {
    final selectedCount = _selectedUserIds.length;
    final allVisibleSelected = visibleUsers.every(
      (user) => _selectedUserIds.contains(user.id),
    );
    return Material(
      color: selectedCount == 0
          ? Colors.white
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Checkbox(
              value: allVisibleSelected,
              onChanged: (selected) => setState(() {
                if (selected ?? false) {
                  _selectedUserIds.addAll(visibleUsers.map((user) => user.id));
                } else {
                  _selectedUserIds.removeAll(
                    visibleUsers.map((user) => user.id),
                  );
                }
              }),
            ),
            Text(
              selectedCount == 0
                  ? 'Select All'
                  : 'Selected: $selectedCount Clients',
            ),
            if (selectedCount > 0) ...[
              FilledButton.icon(
                onPressed: () => _onboardUsers(_selectedUserIds),
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Onboard'),
              ),
              OutlinedButton(
                onPressed: () => _bulkSetActive(true),
                child: const Text('Activate'),
              ),
              OutlinedButton(
                onPressed: () => _bulkSetActive(false),
                child: const Text('Deactivate'),
              ),
              OutlinedButton(
                onPressed: () => _bulkSendCredentials(),
                child: const Text('Send Login'),
              ),
              OutlinedButton.icon(
                onPressed: () => _bulkAssignStaff(assignCa: false),
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Assign Accountant'),
              ),
              OutlinedButton.icon(
                onPressed: () => _bulkAssignStaff(assignCa: true),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Assign CA'),
              ),
              OutlinedButton.icon(
                onPressed: _bulkResetCredentials,
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Reset Password'),
              ),
              OutlinedButton.icon(
                onPressed: _exportSelectedClients,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export'),
              ),
              OutlinedButton.icon(
                onPressed: _archiveSelectedClients,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
              ),
              TextButton.icon(
                onPressed: _deleteSelectedClients,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
              ),
              TextButton(
                onPressed: () => setState(_selectedUserIds.clear),
                child: const Text('Clear Selection'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onboardUsers(Iterable<String> userIds) async {
    try {
      final generated = await context.read<AdminUserService>().onboardClients(
        userIds,
        actorUserId: _actorId,
        actorRole: _actorRole,
      );
      if (!mounted) return;
      setState(_selectedUserIds.clear);
      _snack(
        '${generated.length} client(s) onboarded. Use Send Login to deliver credentials.',
      );
    } on FormatException catch (error) {
      if (mounted) _snack(error.message, error: true);
    }
  }

  Future<void> _bulkSetActive(bool active) async {
    final service = context.read<AdminUserService>();
    var changed = 0;
    for (final userId in _selectedUserIds.toList()) {
      final user = service.users.where((item) => item.id == userId).firstOrNull;
      if (user == null || user.isActive == active) continue;
      try {
        await service.setActive(
          userId,
          active,
          actorUserId: _actorId,
          actorRole: _actorRole,
        );
        changed++;
      } on FormatException {
        continue;
      }
    }
    if (!mounted) return;
    setState(_selectedUserIds.clear);
    _snack('$changed client(s) ${active ? 'activated' : 'deactivated'}.');
  }

  Future<void> _bulkSendCredentials() async {
    final service = context.read<AdminUserService>();
    var queued = 0;
    for (final userId in _selectedUserIds.toList()) {
      final user = service.users.where((item) => item.id == userId).firstOrNull;
      if (user == null || !user.isActive) continue;
      final channel = user.mobile.isNotEmpty
          ? CredentialChannel.sms
          : CredentialChannel.email;
      final result = await service.sendCredentials(userId, channel);
      if (result.status != CredentialDeliveryStatus.failed) queued++;
    }
    if (!mounted) return;
    setState(_selectedUserIds.clear);
    _snack('Login credentials queued for $queued client(s).');
  }

  Future<void> _bulkAssignStaff({required bool assignCa}) async {
    final service = context.read<AdminUserService>();
    final staff = assignCa
        ? service.users
              .where(
                (user) =>
                    user.isActive &&
                    (user.role == UserRole.firmAdmin ||
                        user.role == UserRole.checker),
              )
              .toList(growable: false)
        : service.accountantAndCaUsers;
    if (staff.isEmpty) {
      _snack(
        'No eligible ${assignCa ? 'CA / Auditor' : 'Accountant'} is available.',
        error: true,
      );
      return;
    }
    final selectedStaffId = await showMovableDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(assignCa ? 'Assign CA / Auditor' : 'Assign Accountant'),
        children: staff
            .map(
              (user) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, user.id),
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.name),
                  subtitle: Text(user.role.displayName),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (selectedStaffId == null || !mounted) return;
    var assigned = 0;
    for (final userId in _selectedUserIds.toList()) {
      final current = service.accountingAccessFor(userId);
      try {
        await service.configureClientAccountingAccess(
          userId,
          assignedAccountantId: assignCa
              ? current.assignedAccountantId
              : selectedStaffId,
          assignedCaId: assignCa ? selectedStaffId : current.assignedCaId,
          oldAccountingApproved: current.oldAccountingApproved,
          reportsPublished: current.reportsPublished,
          auditEnabled: current.auditEnabled,
          financialStatementsEnabled: current.financialStatementsEnabled,
          reportSigningEnabled: current.reportSigningEnabled,
          bankProjectReportsEnabled: current.bankProjectReportsEnabled,
          staffDelegationEnabled: current.staffDelegationEnabled,
        );
        assigned++;
      } on FormatException {
        continue;
      }
    }
    if (!mounted) return;
    setState(_selectedUserIds.clear);
    _snack('$assigned client(s) assigned.');
  }

  Future<void> _bulkResetCredentials() async {
    final service = context.read<AdminUserService>();
    var reset = 0;
    for (final userId in _selectedUserIds.toList()) {
      try {
        await service.regenerateCredentials(
          userId,
          actorUserId: _actorId,
          actorRole: _actorRole,
        );
        reset++;
      } on FormatException {
        continue;
      }
    }
    if (!mounted) return;
    setState(_selectedUserIds.clear);
    _snack('$reset client password(s) reset. Use Send Login to deliver them.');
  }

  Future<void> _exportSelectedClients() async {
    final csv = context.read<AdminUserService>().exportClientsCsv(
      _selectedUserIds,
    );
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    _snack(
      '${_selectedUserIds.length} client record(s) exported as CSV to the clipboard.',
    );
  }

  Future<void> _archiveSelectedClients() async {
    if (!await _confirmBulkAction(
      title: 'Archive Selected Clients',
      message:
          'Archive ${_selectedUserIds.length} client(s)? Portal access will stop and records will be retained.',
      actionLabel: 'Archive',
    )) {
      return;
    }
    await context.read<AdminUserService>().archiveClients(
      _selectedUserIds,
      actorUserId: _actorId,
      actorRole: _actorRole,
    );
    if (!mounted) return;
    setState(_selectedUserIds.clear);
    _snack('Selected clients archived.');
  }

  Future<void> _deleteSelectedClients() async {
    if (!await _confirmBulkAction(
      title: 'Delete Selected Clients',
      message:
          'Permanently delete ${_selectedUserIds.length} client profile(s) and their local onboarding metadata? This cannot be undone.',
      actionLabel: 'Delete',
      destructive: true,
    )) {
      return;
    }
    await context.read<AdminUserService>().deleteClients(
      _selectedUserIds,
      actorUserId: _actorId,
      actorRole: _actorRole,
    );
    if (!mounted) return;
    setState(_selectedUserIds.clear);
    _snack('Selected client profiles deleted.');
  }

  Future<bool> _confirmBulkAction({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    return await showMovableDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      )
                    : null,
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  String get _actorId =>
      context.read<AuthController>().currentUser?.id ?? 'admin';

  String get _actorRole =>
      context.read<AuthController>().currentUser?.role.name ?? 'superAdmin';

  String _shortDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  List<String> _filterOptions(Iterable<String> values) {
    final options = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    options.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return options;
  }

  Future<void> _showClientDetails(UserModel user) async {
    final service = context.read<AdminUserService>();
    final compliance = service.complianceFor(user.id);
    final access = service.accountingAccessFor(user.id);
    final assignedAccountant = service.accountantAndCaUsers
        .where((staff) => staff.id == access.assignedAccountantId)
        .firstOrNull;
    final assignedCa = service.users
        .where((staff) => staff.id == access.assignedCaId)
        .firstOrNull;
    final workspace = service.workspaceFor(user.id);

    await showMovableDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Client Details'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Client name', value: user.name),
                _DetailRow(label: 'Company', value: user.firmName),
                _DetailRow(label: 'User ID', value: user.id),
                _DetailRow(label: 'Email', value: user.email),
                _DetailRow(label: 'Mobile', value: user.mobile),
                _DetailRow(
                  label: 'Account type',
                  value: user.accountOrigin.displayName,
                ),
                _DetailRow(
                  label: 'Status',
                  value: user.clientStatus.displayName,
                ),
                _DetailRow(
                  label: 'Login status',
                  value: user.loginStatus.displayName,
                ),
                _DetailRow(
                  label: 'Last login',
                  value: user.lastLoginAt == null
                      ? 'Never'
                      : _shortDate(user.lastLoginAt!),
                ),
                _DetailRow(
                  label: 'GST registration',
                  value: compliance.gstRegistrationType.displayName,
                ),
                _DetailRow(label: 'GSTIN', value: compliance.gstin),
                _DetailRow(label: 'PAN', value: compliance.pan),
                _DetailRow(label: 'State', value: compliance.state),
                _DetailRow(label: 'City', value: compliance.city),
                _DetailRow(
                  label: 'Services',
                  value: compliance.services.isEmpty
                      ? 'Not selected'
                      : compliance.services.join(', '),
                ),
                _DetailRow(
                  label: 'Accounting service',
                  value: compliance.accountingEnabled ? 'Enabled' : 'Disabled',
                ),
                _DetailRow(
                  label: 'GST service',
                  value: compliance.gstEnabled ? 'Enabled' : 'Disabled',
                ),
                _DetailRow(
                  label: 'Assigned Accountant / CA',
                  value: assignedAccountant?.name ?? 'Not assigned',
                ),
                _DetailRow(
                  label: 'Assigned CA / Auditor',
                  value: assignedCa?.name ?? 'Not assigned',
                ),
                _DetailRow(
                  label: 'Provisioned workspaces',
                  value: <String>[
                    if (workspace.client360Enabled) 'Client 360',
                    if (workspace.documentFolderEnabled) 'Documents',
                    if (workspace.complianceWorkspaceEnabled) 'Compliance',
                    if (workspace.accountingWorkspaceEnabled) 'Accounting',
                    if (workspace.aiWorkspaceEnabled) 'AI',
                    if (workspace.notificationSettingsEnabled) 'Notifications',
                  ].join(', '),
                ),
                _DetailRow(
                  label: 'Joined on',
                  value: _shortDate(access.joinedOn),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openUserForm(user: user);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _configureAccountingAccess(UserModel client) async {
    final service = context.read<AdminUserService>();
    final current = service.accountingAccessFor(client.id);
    final staff = service.accountantAndCaUsers;
    var accountantId = current.assignedAccountantId;
    var caId = current.assignedCaId;
    var oldAccountingApproved = current.oldAccountingApproved;
    var reportsPublished = current.reportsPublished;
    var auditEnabled = current.auditEnabled;
    var financialStatementsEnabled = current.financialStatementsEnabled;
    var reportSigningEnabled = current.reportSigningEnabled;
    var bankProjectReportsEnabled = current.bankProjectReportsEnabled;
    var staffDelegationEnabled = current.staffDelegationEnabled;

    final shouldSave = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Client Accounting Access'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('Joined: ${_shortDate(current.joinedOn)}'),
                  Text(
                    'Without special permission, reports are visible from ${_shortDate(current.standardHistoryStartsOn)}. Client-uploaded and self-billed data remains available.',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: accountantId.isEmpty ? null : accountantId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Accountant / CA',
                      prefixIcon: Icon(Icons.assignment_ind_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: staff
                        .map(
                          (user) => DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(
                              '${user.name} (${user.role.displayName})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: staff.isEmpty
                        ? null
                        : (value) => setDialogState(() {
                            accountantId = value ?? '';
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: caId.isEmpty ? null : caId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned CA / Auditor',
                      prefixIcon: Icon(Icons.fact_check_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: service.users
                        .where(
                          (user) =>
                              user.isActive &&
                              (user.role == UserRole.firmAdmin ||
                                  user.role == UserRole.checker),
                        )
                        .map(
                          (user) => DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(
                              '${user.name} (${user.role.displayName})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setDialogState(() => caId = value ?? ''),
                  ),
                  if (staff.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Create or activate an Accountant/Partner user before assigning old accounting work.',
                        style: TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Approve old accounting'),
                    subtitle: const Text(
                      'Allows assigned staff to prepare records older than the standard three-month window.',
                    ),
                    value: oldAccountingApproved,
                    onChanged: accountantId.isEmpty
                        ? null
                        : (value) => setDialogState(() {
                            oldAccountingApproved = value;
                            if (!value) reportsPublished = false;
                          }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish old reports to client'),
                    subtitle: const Text(
                      'Client login can view older history only after the admin publishes it.',
                    ),
                    value: reportsPublished,
                    onChanged: accountantId.isEmpty || !oldAccountingApproved
                        ? null
                        : (value) => setDialogState(() {
                            reportsPublished = value;
                          }),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'CA / Auditor Work Options',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Audit verification'),
                    value: auditEnabled,
                    onChanged: caId.isEmpty
                        ? null
                        : (value) => setDialogState(() => auditEnabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Smart financial statements'),
                    subtitle: const Text('Balance Sheet, P&L and schedules'),
                    value: financialStatementsEnabled,
                    onChanged: caId.isEmpty
                        ? null
                        : (value) => setDialogState(
                            () => financialStatementsEnabled = value,
                          ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CA signing and UDIN'),
                    value: reportSigningEnabled,
                    onChanged: caId.isEmpty
                        ? null
                        : (value) => setDialogState(
                            () => reportSigningEnabled = value,
                          ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bank provisional & project reports'),
                    subtitle: const Text(
                      'Allows three-year historical analysis and three-year CA-certified projections.',
                    ),
                    value: bankProjectReportsEnabled,
                    onChanged: caId.isEmpty
                        ? null
                        : (value) => setDialogState(
                            () => bankProjectReportsEnabled = value,
                          ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Delegate to CA staff'),
                    value: staffDelegationEnabled,
                    onChanged: caId.isEmpty
                        ? null
                        : (value) => setDialogState(
                            () => staffDelegationEnabled = value,
                          ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save Access'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true || !mounted) return;

    try {
      await service.configureClientAccountingAccess(
        client.id,
        assignedAccountantId: accountantId,
        assignedCaId: caId,
        oldAccountingApproved: oldAccountingApproved,
        reportsPublished: reportsPublished,
        auditEnabled: auditEnabled,
        financialStatementsEnabled: financialStatementsEnabled,
        reportSigningEnabled: reportSigningEnabled,
        bankProjectReportsEnabled: bankProjectReportsEnabled,
        staffDelegationEnabled: staffDelegationEnabled,
      );
      if (mounted) _snack('Client accounting access updated.');
    } on FormatException catch (error) {
      if (mounted) _snack(error.message, error: true);
    }
  }

  Future<void> _changeClientStatus(UserModel user) async {
    final activate = !user.isActive;
    final confirmed = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activate ? 'Reactivate Client' : 'Disable Client'),
        content: Text(
          activate
              ? 'Reactivate ${user.name} with the same client ID? Existing accounting books, invoices, vouchers, GST records, profiles, and history will carry forward.'
              : 'Disable ${user.name}? Login and new submissions will stop, but all accounting and GST records will be retained for audit and future reactivation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(activate ? 'Reactivate' : 'Disable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AdminUserService>().setActive(
      user.id,
      activate,
      actorUserId: _actorId,
      actorRole: _actorRole,
    );
  }

  Future<void> _openUserForm({UserModel? user}) async {
    final existingCompliance = user == null
        ? null
        : context.read<AdminUserService>().complianceFor(user.id);
    final name = TextEditingController(text: user?.name ?? '');
    final company = TextEditingController(text: user?.firmName ?? '');
    final mobile = TextEditingController(text: user?.mobile ?? '');
    final email = TextEditingController(text: user?.email ?? '');
    final gstin = TextEditingController(text: existingCompliance?.gstin ?? '');
    final pan = TextEditingController(text: existingCompliance?.pan ?? '');
    final state = TextEditingController(text: existingCompliance?.state ?? '');
    final city = TextEditingController(text: existingCompliance?.city ?? '');
    final pincode = TextEditingController(
      text: existingCompliance?.pincode ?? '',
    );
    final services = TextEditingController(
      text: existingCompliance?.services.join(', ') ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var role = user?.role ?? UserRole.client;
    var gstRegistrationType =
        existingCompliance?.gstRegistrationType ??
        GstRegistrationType.unregistered;
    var accountingMode =
        existingCompliance?.servicePeriodOn(DateTime.now()).accountingMode ??
        ClientAccountingMode.accountingOnly;
    var serviceEffectiveFrom = DateTime.now();
    var accountingEnabled = existingCompliance?.accountingEnabled ?? true;
    var gstEnabled = existingCompliance?.gstEnabled ?? false;

    final saved = await showMovableDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            user == null ? 'Create Client Profile' : 'Edit Client Profile',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Client name *',
                      ),
                      validator: (value) => value?.trim().isEmpty == true
                          ? 'Client name is required'
                          : null,
                    ),
                    TextFormField(
                      controller: company,
                      decoration: const InputDecoration(
                        labelText: 'Company / business name',
                      ),
                    ),
                    TextFormField(
                      controller: mobile,
                      decoration: const InputDecoration(labelText: 'Mobile'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: indianMobileInputFormatters(),
                      validator: validateIndianMobile,
                    ),
                    TextFormField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: validateEmailAddress,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<GstRegistrationType>(
                      initialValue: gstRegistrationType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'GST registration type',
                        border: OutlineInputBorder(),
                      ),
                      items: GstRegistrationType.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.displayName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          gstRegistrationType = value;
                          if (value == GstRegistrationType.unregistered) {
                            gstEnabled = false;
                          } else {
                            gstEnabled = true;
                          }
                        });
                      },
                    ),
                    if (gstRegistrationType !=
                        GstRegistrationType.unregistered) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: gstin,
                        decoration: const InputDecoration(
                          labelText: 'GSTIN *',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        validator: (value) {
                          if (gstRegistrationType ==
                              GstRegistrationType.unregistered) {
                            return null;
                          }
                          final normalized = value?.trim().toUpperCase() ?? '';
                          return RegExp(
                                r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$',
                              ).hasMatch(normalized)
                              ? null
                              : 'Enter a valid 15-character GSTIN';
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await GstPortalLookupService()
                                .fetchTaxpayerByGstin(gstin.text);
                            if (!context.mounted) return;
                            final profile = result.profile;
                            if (profile == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                              return;
                            }
                            setDialogState(() {
                              if (company.text.trim().isEmpty) {
                                company.text = profile.tradeName.isNotEmpty
                                    ? profile.tradeName
                                    : profile.legalName;
                              }
                              state.text = profile.state;
                              city.text = profile.city;
                              pincode.text = profile.pincode;
                              if (email.text.trim().isEmpty) {
                                email.text = profile.email;
                              }
                              if (mobile.text.trim().isEmpty) {
                                mobile.text = profile.mobile;
                              }
                            });
                          },
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('Fetch GST Details'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pan,
                      decoration: const InputDecoration(
                        labelText: 'PAN',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]'),
                        ),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        final normalized = value?.trim().toUpperCase() ?? '';
                        if (normalized.isEmpty) return null;
                        return RegExp(
                              r'^[A-Z]{5}[0-9]{4}[A-Z]$',
                            ).hasMatch(normalized)
                            ? null
                            : 'Enter a valid PAN';
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: state,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: city,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: pincode,
                            decoration: const InputDecoration(
                              labelText: 'Pincode',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (value) {
                              final normalized = value?.trim() ?? '';
                              if (normalized.isEmpty) return null;
                              return RegExp(r'^\d{6}$').hasMatch(normalized)
                                  ? null
                                  : 'Enter a valid 6-digit pincode';
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Fetch area from pincode',
                          onPressed: () async {
                            final result = await PincodeLookupService().lookup(
                              pincode.text,
                            );
                            if (!context.mounted) return;
                            if (result == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pincode area not found.'),
                                ),
                              );
                              return;
                            }
                            setDialogState(() {
                              state.text = result.state;
                              city.text = result.city;
                            });
                          },
                          icon: const Icon(Icons.location_searching_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: services,
                      decoration: const InputDecoration(
                        labelText: 'Services',
                        hintText: 'Accounting, GST, Payroll',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Maintain accounting records'),
                      value: accountingEnabled,
                      onChanged: (value) =>
                          setDialogState(() => accountingEnabled = value),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ClientAccountingMode>(
                      initialValue: accountingMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Client accounting maintenance',
                        border: OutlineInputBorder(),
                      ),
                      items: ClientAccountingMode.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.displayName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => accountingMode = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Service change effective from'),
                      subtitle: Text(_shortDate(serviceEffectiveFrom)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: serviceEffectiveFrom,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setDialogState(() => serviceEffectiveFrom = selected);
                        }
                      },
                    ),
                    const Text(
                      'Previous periods remain unchanged. The selected accounting mode and GST scheme apply from this date onward.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Maintain GST records'),
                      subtitle:
                          gstRegistrationType == GstRegistrationType.composition
                          ? const Text('Composition scheme compliance')
                          : null,
                      value: gstEnabled,
                      onChanged:
                          gstRegistrationType ==
                              GstRegistrationType.unregistered
                          ? null
                          : (value) => setDialogState(() => gstEnabled = value),
                    ),
                    DropdownButtonFormField<UserRole>(
                      initialValue: role,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Client role',
                        border: OutlineInputBorder(),
                      ),
                      items: UserRole.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.displayName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => role = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(user == null ? 'Create Profile' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final service = context.read<AdminUserService>();
    try {
      if (user == null) {
        await service.createUser(
          name: name.text,
          email: email.text,
          mobile: mobile.text,
          firmId: 'chirag-associates',
          firmName: company.text,
          role: role,
          gstRegistrationType: gstRegistrationType,
          gstin: gstin.text,
          pan: pan.text,
          state: state.text,
          city: city.text,
          pincode: pincode.text,
          services: services.text
              .split(RegExp(r'[,;|]'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
          accountingEnabled: accountingEnabled,
          accountingMode: accountingMode,
          serviceEffectiveFrom: serviceEffectiveFrom,
          gstEnabled: gstEnabled,
          actorUserId: _actorId,
          actorRole: _actorRole,
        );
        if (mounted) {
          _snack(
            'Client profile created as Not Onboarded. Select it and click Onboard to activate portal access.',
          );
        }
      } else {
        await service.updateUser(
          user.id,
          name: name.text,
          email: email.text,
          mobile: mobile.text,
          firmName: company.text,
          role: role,
          gstRegistrationType: gstRegistrationType,
          gstin: gstin.text,
          pan: pan.text,
          state: state.text,
          city: city.text,
          pincode: pincode.text,
          services: services.text
              .split(RegExp(r'[,;|]'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
          accountingEnabled: accountingEnabled,
          accountingMode: accountingMode,
          serviceEffectiveFrom: serviceEffectiveFrom,
          gstEnabled: gstEnabled,
          actorUserId: _actorId,
          actorRole: _actorRole,
        );
        if (mounted) _snack('Client profile updated.');
      }
    } on FormatException catch (error) {
      if (mounted) _snack(error.message, error: true);
    }
  }

  Future<void> _resetCredentials(UserModel user) async {
    final confirmed = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Client Password'),
        content: Text(
          'Generate a new temporary password for ${user.name}? The password will not be displayed. Send it using Email, SMS, or WhatsApp after reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AdminUserService>().regenerateCredentials(
        user.id,
        actorUserId: _actorId,
        actorRole: _actorRole,
      );
      if (mounted) {
        _snack('Temporary password generated. Use Send Login to deliver it.');
      }
    } on FormatException catch (error) {
      if (mounted) _snack(error.message, error: true);
    }
  }

  Future<void> _sendCredentials(
    UserModel user,
    CredentialChannel channel,
  ) async {
    final service = context.read<AdminUserService>();
    if (!user.isActive) {
      _snack(
        'Activate this client before sending login credentials.',
        error: true,
      );
      return;
    }

    var credentials = service.credentialsFor(user.id);
    if (credentials == null) {
      final shouldGenerate = await showMovableDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Generate New Temporary Password?'),
          content: Text(
            'The previous temporary password is not available. Generate a new password and send the User ID and password by ${channel.name.toUpperCase()}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Generate and Send'),
            ),
          ],
        ),
      );
      if (shouldGenerate != true || !mounted) return;
      credentials = await service.regenerateCredentials(
        user.id,
        actorUserId: _actorId,
        actorRole: _actorRole,
      );
    }

    if (!mounted) return;
    final destination = channel == CredentialChannel.email
        ? user.email
        : user.mobile;
    final confirmed = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send Temporary Password by ${channel.name.toUpperCase()}'),
        content: Text(
          'Send User ID ${credentials!.userId} and the temporary password to $destination?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: Icon(_channelIcon(channel)),
            label: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await service.sendCredentials(user.id, channel);
    if (!mounted) return;
    _snack(
      result.message,
      error: result.status == CredentialDeliveryStatus.failed,
    );
  }

  IconData _channelIcon(CredentialChannel channel) {
    switch (channel) {
      case CredentialChannel.email:
        return Icons.email_outlined;
      case CredentialChannel.sms:
        return Icons.sms_outlined;
      case CredentialChannel.whatsapp:
        return Icons.chat_outlined;
    }
  }

  Future<void> _downloadClientImportTemplate() async {
    const fileName = 'chirag_associates_client_user_import_template.csv';
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Save Client Onboarding Template',
        fileName: fileName,
        bytes: Uint8List.fromList(
          utf8.encode(ImportTemplateContent.clientUsersCsv),
        ),
        type: FileType.custom,
        allowedExtensions: const <String>['csv'],
      );
      if (mounted) _snack('Template downloaded: $fileName');
    } catch (error) {
      if (mounted) _snack('Template download failed: $error', error: true);
    }
  }

  Future<void> _importClients() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv', 'xlsx', 'xlsm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      const message = 'The selected file could not be read.';
      await context.read<AdminUserService>().recordImportFailure(
        file.name,
        message,
      );
      if (mounted) _snack(message, error: true);
      return;
    }

    List<List<String>> rows;
    String sourceLabel;
    try {
      final extension = file.extension?.toLowerCase() ?? '';
      if (extension == 'xlsx' || extension == 'xlsm') {
        final workbook = const XlsxWorkbookReader().read(bytes);
        final selected = await _selectWorksheet(workbook.sheets);
        if (selected == null || !mounted) return;
        rows = selected.rows;
        sourceLabel = '${file.name} - ${selected.name}';
      } else {
        final confirmed = await _confirmCsvImport(file.name);
        if (confirmed != true || !mounted) return;
        rows = _csvRows(utf8.decode(bytes, allowMalformed: true));
        sourceLabel = file.name;
      }
    } on FormatException catch (error) {
      await context.read<AdminUserService>().recordImportFailure(
        file.name,
        error.message,
      );
      if (mounted) _snack(error.message, error: true);
      return;
    } catch (error) {
      final message = 'Could not read workbook: $error';
      await context.read<AdminUserService>().recordImportFailure(
        file.name,
        message,
      );
      if (mounted) _snack(message, error: true);
      return;
    }

    setState(() => _importing = true);
    try {
      final summary = await context.read<AdminUserService>().importClientsRows(
        rows,
        source: sourceLabel,
        actorUserId: _actorId,
        actorRole: _actorRole,
      );
      if (!mounted) return;
      await showMovableDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Client Import Complete'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Source: $sourceLabel'),
                const SizedBox(height: 8),
                Text('Created: ${summary.created}'),
                Text('Updated: ${summary.updated}'),
                Text('Skipped: ${summary.skipped}'),
                if (summary.errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Rows requiring correction:'),
                  const SizedBox(height: 6),
                  ...summary.errors.take(8).map(Text.new),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      final message = 'Client import failed: $error';
      await context.read<AdminUserService>().recordImportFailure(
        sourceLabel,
        message,
      );
      if (mounted) _snack(message, error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<XlsxSheetData?> _selectWorksheet(List<XlsxSheetData> sheets) async {
    XlsxSheetData selected = sheets.first;
    return showMovableDialog<XlsxSheetData>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Worksheet to Upload'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheets.length == 1
                      ? 'Confirm the worksheet to import.'
                      : 'This workbook contains ${sheets.length} worksheets. Choose one before importing.',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<XlsxSheetData>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Worksheet',
                    border: OutlineInputBorder(),
                  ),
                  items: sheets
                      .map(
                        (sheet) => DropdownMenuItem(
                          value: sheet,
                          child: Text(
                            '${sheet.name} (${sheet.rows.length > 1 ? sheet.rows.length - 1 : 0} records)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selected = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: selected.rows.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload This Sheet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmCsvImport(String fileName) {
    return showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Client List Upload'),
        content: Text(
          '$fileName is a CSV file. CSV supports one data sheet only. Upload this client list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  List<List<String>> _csvRows(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    final value = StringBuffer();
    var inQuotes = false;

    void addValue() {
      row.add(value.toString());
      value.clear();
    }

    void addRow() {
      addValue();
      rows.add(row);
      row = <String>[];
    }

    for (var index = 0; index < csv.length; index++) {
      final char = csv[index];
      if (char == '"') {
        if (inQuotes && index + 1 < csv.length && csv[index + 1] == '"') {
          value.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        addValue();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && index + 1 < csv.length && csv[index + 1] == '\n') {
          index++;
        }
        addRow();
      } else {
        value.write(char);
      }
    }
    if (value.isNotEmpty || row.isNotEmpty) addRow();
    return rows;
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ImportIssuesPanel extends StatelessWidget {
  const _ImportIssuesPanel({required this.issues, required this.onClear});

  final AdminClientImportIssues issues;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final occurredAt = issues.occurredAt.toLocal().toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: const Color(0xFFEF6C00)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFE65100)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Client Import Issues (${issues.errors.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mark Reviewed'),
              ),
            ],
          ),
          Text(
            '${issues.source} | $occurredAt',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: issues.errors
                      .map(
                        (error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('- $error'),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'These issues remain visible after logout and the next login until marked reviewed.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'DISABLED',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ServiceTag extends StatelessWidget {
  const _ServiceTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value.trim().isEmpty ? 'Not provided' : value)),
        ],
      ),
    );
  }
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 52),
      child: Column(
        children: [
          Icon(Icons.group_off_outlined, size: 44, color: Colors.black38),
          SizedBox(height: 10),
          Text('No clients or users match this view.'),
        ],
      ),
    );
  }
}
