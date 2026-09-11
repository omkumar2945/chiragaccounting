import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/ca_workspace/services/ca_workspace_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';

class CaTeamWorkspaceScreen extends StatefulWidget {
  const CaTeamWorkspaceScreen({super.key});

  @override
  State<CaTeamWorkspaceScreen> createState() => _CaTeamWorkspaceScreenState();
}

class _CaTeamWorkspaceScreenState extends State<CaTeamWorkspaceScreen> {
  final _staffNameCtrl = TextEditingController();
  final _staffEmailCtrl = TextEditingController();
  final _staffMobileCtrl = TextEditingController();
  final _assignNoteCtrl = TextEditingController();

  UserRole _staffRole = UserRole.dataEntryOperator;
  String _selectedClientId = '';
  String _selectedStaffUserId = '';
  bool _creatingStaff = false;

  @override
  void dispose() {
    _staffNameCtrl.dispose();
    _staffEmailCtrl.dispose();
    _staffMobileCtrl.dispose();
    _assignNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Session not available.')),
      );
    }

    final workspace = context.watch<CaWorkspaceService>();
    final staff = workspace.staffForCa(currentUser.id);
    final assignments = workspace.assignmentsForCa(currentUser.id);
    final clients = context
        .watch<CustomerService>()
        .customers
        .where((entry) => entry.customerName.trim().isNotEmpty)
        .toList(growable: false)
      ..sort(
        (a, b) =>
            a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase()),
      );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CA Team Workspace'),
          actions: [
            IconButton(
              tooltip: 'Print assignment summary',
              onPressed: assignments.isEmpty
                  ? null
                  : () => _printAssignmentSummary(
                      caName: currentUser.name,
                      assignments: assignments,
                    ),
              icon: const Icon(Icons.print_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.group_add_outlined), text: 'Staff Login'),
              Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'Assign'),
              Tab(icon: Icon(Icons.verified_outlined), text: 'Verify & Submit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStaffTab(currentUser.id, staff),
            _buildAssignTab(
              caUserId: currentUser.id,
              staff: staff,
              clients: clients,
              assignments: assignments,
            ),
            _buildVerifyTab(assignments: assignments),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTab(String caUserId, List<CaStaffMember> staff) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Career with Chirag: Build your CA team, create staff login IDs, and scale client delivery with fast delegation.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _staffNameCtrl,
                  decoration: const InputDecoration(labelText: 'Staff Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _staffEmailCtrl,
                  decoration: const InputDecoration(labelText: 'Staff Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _staffMobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Staff Mobile'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  initialValue: _staffRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.dataEntryOperator,
                      child: Text('Data Entry Operator'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.accountant,
                      child: Text('Accountant'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.checker,
                      child: Text('Checker'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _staffRole = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _creatingStaff
                        ? null
                        : () => _createStaffLogin(caUserId),
                    icon: _creatingStaff
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_outlined),
                    label: Text(
                      _creatingStaff ? 'Creating...' : 'Create Staff Login',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'My Staff Team',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (staff.isEmpty)
          const Card(
            child: ListTile(title: Text('No staff logins created yet.')),
          ),
        for (final member in staff)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(member.name),
              subtitle: Text(
                '${member.role.displayName}\n${member.email} | ${member.mobile}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  Widget _buildAssignTab({
    required String caUserId,
    required List<CaStaffMember> staff,
    required List<dynamic> clients,
    required List<CaClientAssignment> assignments,
  }) {
    final selectedClient = clients.where((entry) => entry.id == _selectedClientId);
    final selectedStaff = staff.where((entry) => entry.userId == _selectedStaffUserId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedClientId.isEmpty ? null : _selectedClientId,
                  decoration: const InputDecoration(labelText: 'Assign Client'),
                  isExpanded: true,
                  items: clients
                      .map<DropdownMenuItem<String>>(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.id,
                          child: Text(entry.customerName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _selectedClientId = value ?? ''),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStaffUserId.isEmpty
                      ? null
                      : _selectedStaffUserId,
                  decoration: const InputDecoration(labelText: 'To Staff User'),
                  isExpanded: true,
                  items: staff
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.userId,
                          child: Text('${entry.name} (${entry.role.displayName})'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _selectedStaffUserId = value ?? ''),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _assignNoteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Assignment Notes (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: clients.isEmpty || staff.isEmpty
                        ? null
                        : () => _assignClient(
                            caUserId,
                            selectedClient.isEmpty ? null : selectedClient.first,
                            selectedStaff.isEmpty ? null : selectedStaff.first,
                          ),
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('Assign Client to Staff'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Current Client Assignments',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (assignments.isEmpty)
          const Card(
            child: ListTile(title: Text('No assignments created yet.')),
          ),
        for (final assignment in assignments)
          Card(
            child: ListTile(
              leading: const Icon(Icons.work_history_outlined),
              title: Text(assignment.clientName),
              subtitle: Text('Staff: ${assignment.staffName}'),
              trailing: Chip(label: Text(_statusLabel(assignment.status))),
            ),
          ),
      ],
    );
  }

  Widget _buildVerifyTab({required List<CaClientAssignment> assignments}) {
    final assignedCount = assignments
      .where((entry) => entry.status == CaAssignmentStatus.assigned)
      .length;
    final submittedCount = assignments
      .where((entry) => entry.status == CaAssignmentStatus.staffSubmitted)
      .length;
    final verifiedCount = assignments
      .where((entry) =>
        entry.status == CaAssignmentStatus.caVerifiedSubmitted)
      .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Verification flow: Assigned -> Staff Submitted -> CA Verified & Submitted',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assignment Summary Report',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Assigned: $assignedCount')),
                    Chip(label: Text('Staff Submitted: $submittedCount')),
                    Chip(label: Text('CA Verified: $verifiedCount')),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: assignments.isEmpty
                      ? null
                      : () => _printAssignmentSummary(
                            caName:
                                context.read<AuthController>().currentUser?.name ??
                                    'CA User',
                            assignments: assignments,
                          ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Print CA Assignment Report'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (assignments.isEmpty)
          const Card(
            child: ListTile(title: Text('No verification items available.')),
          ),
        for (final assignment in assignments)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Assigned Staff: ${assignment.staffName}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(_statusLabel(assignment.status))),
                      if (assignment.status == CaAssignmentStatus.assigned)
                        OutlinedButton(
                          onPressed: () => _changeStatus(
                            assignment.id,
                            CaAssignmentStatus.staffSubmitted,
                          ),
                          child: const Text('Mark Staff Submitted'),
                        ),
                      if (assignment.status ==
                          CaAssignmentStatus.staffSubmitted)
                        FilledButton(
                          onPressed: () => _changeStatus(
                            assignment.id,
                            CaAssignmentStatus.caVerifiedSubmitted,
                          ),
                          child: const Text('CA Verify & Submit'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _createStaffLogin(String caUserId) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final name = _staffNameCtrl.text.trim();
    final email = _staffEmailCtrl.text.trim();
    final mobile = _staffMobileCtrl.text.trim();
    if (name.isEmpty || email.isEmpty || mobile.isEmpty) {
      _snack('Enter staff name, email and mobile.');
      return;
    }

    setState(() => _creatingStaff = true);
    try {
      final admin = context.read<AdminUserService>();
      final credentials = await admin.createUser(
        name: name,
        email: email,
        mobile: mobile,
        firmId: user.firmId,
        firmName: user.firmName,
        role: _staffRole,
        actorUserId: user.id,
        actorRole: user.role.name,
      );
      await context.read<CaWorkspaceService>().registerStaffMember(
        caUserId: caUserId,
        userId: credentials.userId,
        name: name,
        email: email,
        mobile: mobile,
        role: _staffRole,
      );

      if (!mounted) return;
      _staffNameCtrl.clear();
      _staffEmailCtrl.clear();
      _staffMobileCtrl.clear();
      final credentialTemplate = _buildCredentialTemplate(
        staffName: name,
        userId: credentials.userId,
        temporaryPassword: credentials.temporaryPassword,
      );
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Staff Login Created'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User ID: ${credentials.userId}\n'
                  'Temporary Password: ${credentials.temporaryPassword}\n\n'
                  'Share these credentials with your staff.',
                ),
                const SizedBox(height: 12),
                Text(
                  credentialTemplate,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _copyCredentialsTemplate(
                channelLabel: 'WhatsApp',
                staffName: name,
                userId: credentials.userId,
                temporaryPassword: credentials.temporaryPassword,
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp Template'),
            ),
            TextButton.icon(
              onPressed: () => _copyCredentialsTemplate(
                channelLabel: 'SMS',
                staffName: name,
                userId: credentials.userId,
                temporaryPassword: credentials.temporaryPassword,
              ),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('SMS Template'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _creatingStaff = false);
      }
    }
  }

  Future<void> _assignClient(
    String caUserId,
    dynamic client,
    CaStaffMember? staff,
  ) async {
    if (client == null || staff == null) {
      _snack('Select both client and staff first.');
      return;
    }

    try {
      await context.read<CaWorkspaceService>().assignClient(
        caUserId: caUserId,
        clientId: client.id.toString(),
        clientName: client.customerName.toString(),
        staffUserId: staff.userId,
        staffName: staff.name,
        note: _assignNoteCtrl.text,
      );
      _assignNoteCtrl.clear();
      _snack('Client assigned to ${staff.name}.');
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _changeStatus(
    String assignmentId,
    CaAssignmentStatus status,
  ) async {
    try {
      await context.read<CaWorkspaceService>().updateAssignmentStatus(
        assignmentId: assignmentId,
        status: status,
      );
      _snack('Assignment updated: ${_statusLabel(status)}');
    } catch (error) {
      _snack(error.toString());
    }
  }

  String _statusLabel(CaAssignmentStatus status) {
    switch (status) {
      case CaAssignmentStatus.assigned:
        return 'Assigned';
      case CaAssignmentStatus.staffSubmitted:
        return 'Staff Submitted';
      case CaAssignmentStatus.caVerifiedSubmitted:
        return 'CA Verified & Submitted';
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildCredentialTemplate({
    required String staffName,
    required String userId,
    required String temporaryPassword,
  }) {
    return 'Hello $staffName,\n'
        'Your Chirag Accounting staff login is ready.\n'
        'User ID: $userId\n'
        'Temporary Password: $temporaryPassword\n'
        'Please login and change password after first sign-in.\n'
        'Regards, Chirag Associates';
  }

  Future<void> _copyCredentialsTemplate({
    required String channelLabel,
    required String staffName,
    required String userId,
    required String temporaryPassword,
  }) async {
    final text = _buildCredentialTemplate(
      staffName: staffName,
      userId: userId,
      temporaryPassword: temporaryPassword,
    );
    await Clipboard.setData(ClipboardData(text: text));
    _snack('$channelLabel template copied. Paste and send in one click.');
  }

  Future<void> _printAssignmentSummary({
    required String caName,
    required List<CaClientAssignment> assignments,
  }) async {
    if (assignments.isEmpty) {
      _snack('No assignments available to print.');
      return;
    }

    final bytes = _buildAssignmentSummaryPdf(
      caName: caName,
      assignments: assignments,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'CA-Assignment-Summary-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}',
    );
  }

  Uint8List _buildAssignmentSummaryPdf({
    required String caName,
    required List<CaClientAssignment> assignments,
  }) {
    final assignedCount = assignments
        .where((entry) => entry.status == CaAssignmentStatus.assigned)
        .length;
    final submittedCount = assignments
        .where((entry) => entry.status == CaAssignmentStatus.staffSubmitted)
        .length;
    final verifiedCount = assignments
        .where((entry) =>
            entry.status == CaAssignmentStatus.caVerifiedSubmitted)
        .length;

    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;

    final heading =
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final body = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final bodyBold =
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);

    double y = 20;
    graphics.drawString('CA Assignment Summary Report', heading,
        bounds: const Rect.fromLTWH(0, 0, 520, 24));
    y += 28;
    graphics.drawString('CA: $caName', bodyBold,
        bounds: Rect.fromLTWH(0, y, 260, 16));
    graphics.drawString(
      'Printed: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      body,
      bounds: Rect.fromLTWH(260, y, 260, 16),
    );
    y += 20;
    graphics.drawString(
      'Total: ${assignments.length} | Assigned: $assignedCount | Staff Submitted: $submittedCount | CA Verified: $verifiedCount',
      body,
      bounds: Rect.fromLTWH(0, y, 520, 16),
    );
    y += 24;

    final grid = PdfGrid();
    grid.columns.add(count: 5);
    final header = grid.headers.add(1)[0];
    header.cells[0].value = 'Client';
    header.cells[1].value = 'Staff';
    header.cells[2].value = 'Status';
    header.cells[3].value = 'Updated';
    header.cells[4].value = 'Notes';

    for (final assignment in assignments) {
      final row = grid.rows.add();
      row.cells[0].value = assignment.clientName;
      row.cells[1].value = assignment.staffName;
      row.cells[2].value = _statusLabel(assignment.status);
      row.cells[3].value =
          DateFormat('dd MMM yyyy').format(assignment.updatedAt);
      row.cells[4].value = assignment.note.trim().isEmpty
          ? '-'
          : assignment.note.trim();
    }

    grid.style = PdfGridStyle(
      font: body,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );
    grid.draw(page: page, bounds: Rect.fromLTWH(0, y, 520, 0));

    final bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }
}
