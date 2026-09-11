import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/constants/import_template_content.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/hr/services/hr_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';

class HrManagementScreen extends StatefulWidget {
  const HrManagementScreen({super.key});

  @override
  State<HrManagementScreen> createState() => _HrManagementScreenState();
}

class _HrManagementScreenState extends State<HrManagementScreen> {
  final Set<String> _selectedCandidateIds = <String>{};
  final TextEditingController _bulkCandidateController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  HiringStage? _stageFilter;
  RecruitmentStatus? _statusFilter;
  String _roleFilter = 'All';

  @override
  void dispose() {
    _bulkCandidateController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('HR & Hiring'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Chirag Staff'),
            Tab(icon: Icon(Icons.person_search_outlined), text: 'Hiring'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Download candidate template',
            onPressed: () => _downloadCandidateTemplate(context),
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            tooltip: 'Upload employee file',
            onPressed: () => _uploadEmployeesFromFile(context),
            icon: const Icon(Icons.badge_outlined),
          ),
          IconButton(
            tooltip: 'Upload candidates file',
            onPressed: () => _uploadCandidatesFromFile(context),
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Add candidate',
            onPressed: () => _addCandidate(context),
            icon: const Icon(Icons.person_add_alt_outlined),
          ),
        ],
      ),
      body: TabBarView(children: [_staffTab(context), _hiringTab(context)]),
    ),
  );

  Widget _staffTab(BuildContext context) {
    final staff = context
        .watch<AdminUserService>()
        .users
        .where((user) => user.role.isStaff)
        .toList(growable: false);
    final employeeRecords = context.watch<HrService>().employees;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          children: [
            Chip(label: Text('Staff ${staff.length}')),
            Chip(label: Text('Employee DB ${employeeRecords.length}')),
            Chip(
              label: Text(
                'Active ${staff.where((user) => user.isActive).length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _uploadEmployeesFromFile(context),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload Employee File (CSV/JSON)'),
          ),
        ),
        if (staff.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Text(
                'No Chirag staff accounts. Hire a candidate to create one.',
              ),
            ),
          ),
        for (final user in staff)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                ),
              ),
              title: Text(user.name),
              subtitle: Text(
                '${user.role.displayName}\n${user.email} | ${user.mobile}',
              ),
              isThreeLine: true,
              trailing: Chip(
                label: Text(user.isActive ? 'Active' : 'Disabled'),
              ),
            ),
          ),
        if (employeeRecords.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Saved Employee Records (Future Requirement Pool)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final employee in employeeRecords)
            Card(
              child: ListTile(
                leading: const Icon(Icons.work_outline),
                title: Text(employee.name),
                subtitle: Text(
                  '${employee.position} | ${employee.department}\n${employee.email} | ${employee.mobile}',
                ),
                isThreeLine: true,
                trailing: Chip(label: Text(employee.currentStatus)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _hiringTab(BuildContext context) {
    final service = context.watch<HrService>();
    final allCandidates = service.candidates;
    final filteredCandidates = allCandidates
        .where(_matchesFilters)
        .toList(growable: false);
    final selectedCandidates = filteredCandidates
        .where((candidate) => _selectedCandidateIds.contains(candidate.id))
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _uploadCandidatesFromFile(context),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Candidates File'),
            ),
            OutlinedButton.icon(
              onPressed: () => _bulkAddCandidates(context),
              icon: const Icon(Icons.playlist_add_outlined),
              label: const Text('Add Multiple Candidates'),
            ),
            OutlinedButton.icon(
              onPressed: () => _downloadCandidateTemplate(context),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Download Template'),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _roleFilter,
                decoration: const InputDecoration(
                  labelText: 'Role filter',
                  isDense: true,
                ),
                items: _candidateRoleOptions()
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _roleFilter = value);
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<HiringStage?>(
                initialValue: _stageFilter,
                decoration: const InputDecoration(
                  labelText: 'Stage filter',
                  isDense: true,
                ),
                items: <DropdownMenuItem<HiringStage?>>[
                  const DropdownMenuItem<HiringStage?>(
                    value: null,
                    child: Text('All stages'),
                  ),
                  ...HiringStage.values.map(
                    (stage) => DropdownMenuItem<HiringStage?>(
                      value: stage,
                      child: Text(_stageLabel(stage)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _stageFilter = value),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<RecruitmentStatus?>(
                initialValue: _statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status filter',
                  isDense: true,
                ),
                items: <DropdownMenuItem<RecruitmentStatus?>>[
                  const DropdownMenuItem<RecruitmentStatus?>(
                    value: null,
                    child: Text('All status'),
                  ),
                  ...RecruitmentStatus.values.map(
                    (status) => DropdownMenuItem<RecruitmentStatus?>(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
            ),
            TextButton.icon(
              onPressed: filteredCandidates.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _selectedCandidateIds
                          ..clear()
                          ..addAll(
                            filteredCandidates.map((candidate) => candidate.id),
                          );
                      });
                    },
              icon: const Icon(Icons.done_all_outlined),
              label: const Text('Select filtered'),
            ),
            TextButton.icon(
              onPressed: _selectedCandidateIds.isEmpty
                  ? null
                  : () => setState(_selectedCandidateIds.clear),
              icon: const Icon(Icons.clear_outlined),
              label: const Text('Clear selection'),
            ),
            ...HiringStage.values.map(
              (stage) => Chip(
                label: Text(
                  '${_stageLabel(stage)} ${allCandidates.where((item) => item.stage == stage).length}',
                ),
              ),
            ),
            Chip(
              label: Text(
                'Active ${allCandidates.where((item) => item.status == RecruitmentStatus.active).length}',
              ),
            ),
            Chip(
              label: Text(
                'Inactive ${allCandidates.where((item) => item.status == RecruitmentStatus.inactive).length}',
              ),
            ),
          ],
        ),
        if (selectedCandidates.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFE8F0FE),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selectedCandidates.length} candidates selected for role-wise hiring message.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _sendHiringMessage(
                      context,
                      selectedCandidates,
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send Message'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (filteredCandidates.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Text('No hiring candidates.'),
            ),
          ),
        for (final candidate in filteredCandidates)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _selectedCandidateIds.contains(candidate.id),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedCandidateIds.add(candidate.id);
                            } else {
                              _selectedCandidateIds.remove(candidate.id);
                            }
                          });
                        },
                      ),
                      const Icon(Icons.person_outline, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${candidate.position} | ${candidate.mobile} | ${candidate.email}',
                            ),
                            Text(
                              'Applied ${DateFormat('dd MMM yyyy').format(candidate.appliedAt)}${candidate.notes.isEmpty ? '' : '\n${candidate.notes}'}',
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text(
                              candidate.status == RecruitmentStatus.active
                                  ? 'Active'
                                  : 'Inactive',
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (candidate.stage != HiringStage.hired)
                            FilledButton.icon(
                              onPressed: () => _hire(context, candidate),
                              icon: const Icon(Icons.how_to_reg_outlined),
                              label: const Text('Hire'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<HiringStage>(
                          initialValue: candidate.stage,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Stage',
                            isDense: true,
                          ),
                          items: HiringStage.values
                              .map(
                                (stage) => DropdownMenuItem(
                                  value: stage,
                                  child: Text(
                                    _stageLabel(stage),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: candidate.stage == HiringStage.hired
                              ? null
                              : (stage) {
                                  if (stage != null &&
                                      stage != HiringStage.hired) {
                                    context.read<HrService>().changeStage(
                                      candidate.id,
                                      stage,
                                    );
                                  }
                                },
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<RecruitmentStatus>(
                          initialValue: candidate.status,
                          decoration: const InputDecoration(
                            labelText: 'Recruitment',
                            isDense: true,
                          ),
                          items: RecruitmentStatus.values
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(_statusLabel(status)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (status) {
                            if (status != null) {
                              context.read<HrService>().updateRecruitmentStatus(
                                candidate.id,
                                status,
                              );
                            }
                          },
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editCandidate(context, candidate),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (service.candidateMessages.isNotEmpty)
          const Text(
            'Hiring Message Log',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        for (final record in service.candidateMessages)
          Card(
            child: ListTile(
              leading: const Icon(Icons.mark_email_read_outlined),
              title: Text(
                '${record.channel.toUpperCase()} • ${record.recipientNames.length} recipients',
              ),
              subtitle: Text(
                '${DateFormat('dd MMM yyyy, hh:mm a').format(record.sentAt)}\nRole: ${record.roleFilter} | Stage: ${record.stageFilter}\n${record.message}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  bool _matchesFilters(HiringCandidate candidate) {
    if (_stageFilter != null && candidate.stage != _stageFilter) {
      return false;
    }
    if (_statusFilter != null && candidate.status != _statusFilter) {
      return false;
    }
    if (_roleFilter != 'All' && _candidateRole(candidate) != _roleFilter) {
      return false;
    }
    return true;
  }

  static String _candidateRole(HiringCandidate candidate) {
    final position = candidate.position.toLowerCase();
    if (position.contains('account') ||
        position.contains('gst') ||
        position.contains('tax')) {
      return 'Accounting';
    }
    if (position.contains('audit') ||
        position.contains('checker') ||
        position.contains('review')) {
      return 'Audit';
    }
    if (position.contains('hr') || position.contains('recruit')) {
      return 'HR';
    }
    if (position.contains('sales') || position.contains('business')) {
      return 'Sales';
    }
    return 'Other';
  }

  List<String> _candidateRoleOptions() => <String>[
    'All',
    'Accounting',
    'Audit',
    'HR',
    'Sales',
    'Other',
  ];

  static String _statusLabel(RecruitmentStatus status) =>
      status.name[0].toUpperCase() + status.name.substring(1);

  Future<void> _downloadCandidateTemplate(BuildContext context) async {
    const fileName = 'hiring_candidate_import_template.csv';
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Save Hiring Candidate Template',
        fileName: fileName,
        bytes: Uint8List.fromList(
          utf8.encode(ImportTemplateContent.hiringCandidatesCsv),
        ),
        type: FileType.custom,
        allowedExtensions: const <String>['csv'],
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiring template downloaded.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template download failed: $error')),
      );
    }
  }

  Future<void> _bulkAddCandidates(BuildContext context) async {
    _bulkCandidateController.text = ImportTemplateContent.hiringCandidatesCsv;
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add multiple candidates'),
        content: SizedBox(
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste CSV rows with the template header. The position column is used for role-wise filtering.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bulkCandidateController,
                minLines: 12,
                maxLines: 18,
                decoration: const InputDecoration(
                  labelText: 'Candidate CSV',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _bulkCandidateController.text = ImportTemplateContent.hiringCandidatesCsv;
            },
            child: const Text('Load Template'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Import rows'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;

    final csv = _bulkCandidateController.text.trim();
    if (csv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste candidate rows before importing.')),
      );
      return;
    }

    try {
      final summary = await context.read<HrService>().importCandidatesFromFile(
        fileName: 'hiring_candidate_import_template.csv',
        bytes: utf8.encode(csv),
      );
      if (!context.mounted) return;
      _showImportSummary(
        context,
        title: 'Multiple Candidate Import Complete',
        summary: summary,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _sendHiringMessage(
    BuildContext context,
    List<HiringCandidate> selectedCandidates,
  ) async {
    _messageController.text =
        'Shortlisted for the next hiring filter. Please reply with availability.';
    String channel = 'sms';
    final confirmed = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Send hiring message'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected candidates: ${selectedCandidates.length}'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  decoration: const InputDecoration(labelText: 'Channel'),
                  items: const [
                    DropdownMenuItem(value: 'sms', child: Text('SMS')),
                    DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                    DropdownMenuItem(value: 'email', child: Text('Email')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => channel = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final record = await context.read<HrService>().sendCandidateMessage(
        candidateIds: selectedCandidates.map((candidate) => candidate.id),
        message: _messageController.text,
        channel: channel,
        roleFilter: _roleFilter,
        stageFilter: _stageFilter == null ? 'All' : _stageFilter!.name,
      );
      if (!context.mounted) return;
      setState(() => _selectedCandidateIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message queued for ${record.recipientIds.length} candidates.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  static String _stageLabel(HiringStage stage) =>
      stage.name[0].toUpperCase() + stage.name.substring(1);

  static Future<void> _editCandidate(
    BuildContext context,
    HiringCandidate candidate,
  ) async {
    final department = TextEditingController(text: candidate.department);
    final salaryExpectation = TextEditingController(
      text: candidate.salaryExpectation,
    );
    final notes = TextEditingController(text: candidate.notes);
    final joinDate = TextEditingController(
      text: candidate.expectedJoinDate == null
          ? ''
          : DateFormat('dd MMM yyyy').format(candidate.expectedJoinDate!),
    );
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recruitment details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: department,
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
                TextField(
                  controller: salaryExpectation,
                  decoration: const InputDecoration(
                    labelText: 'Salary expectation',
                  ),
                ),
                TextField(
                  controller: joinDate,
                  decoration: const InputDecoration(
                    labelText: 'Expected join date',
                  ),
                ),
                TextField(
                  controller: notes,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      try {
        final parsedJoinDate = joinDate.text.trim().isEmpty
            ? null
            : DateFormat('dd MMM yyyy').tryParse(joinDate.text.trim());
        await context.read<HrService>().updateCandidateDetails(
          candidateId: candidate.id,
          department: department.text.trim(),
          salaryExpectation: salaryExpectation.text.trim(),
          expectedJoinDate: parsedJoinDate,
          notes: notes.text.trim(),
        );
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    department.dispose();
    salaryExpectation.dispose();
    notes.dispose();
    joinDate.dispose();
  }

  static Future<void> _hire(
    BuildContext context,
    HiringCandidate candidate,
  ) async {
    final role = candidate.position.toLowerCase().contains('account')
        ? UserRole.accountant
        : UserRole.checker;
    try {
      final credentials = await context.read<AdminUserService>().createUser(
        name: candidate.name,
        email: candidate.email,
        mobile: candidate.mobile,
        firmId: 'chirag-associates',
        firmName: 'Chirag Associates',
        role: role,
      );
      if (context.mounted) {
        await context.read<HrService>().markHired(
          candidate.id,
          credentials.userId,
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  static Future<void> _addCandidate(BuildContext context) async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final position = TextEditingController();
    final notes = TextEditingController();
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add hiring candidate'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Candidate name',
                  ),
                ),
                TextField(
                  controller: mobile,
                  decoration: const InputDecoration(labelText: 'Mobile'),
                ),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: position,
                  decoration: const InputDecoration(labelText: 'Position'),
                ),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
            child: const Text('Add candidate'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await context.read<HrService>().addCandidate(
          name: name.text,
          mobile: mobile.text,
          email: email.text,
          position: position.text,
          notes: notes.text,
        );
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    name.dispose();
    mobile.dispose();
    email.dispose();
    position.dispose();
    notes.dispose();
  }

  Future<void> _uploadCandidatesFromFile(BuildContext context) async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'json'],
      withData: true,
    );
    if (selected == null || selected.files.isEmpty || !context.mounted) return;

    final file = selected.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read file data.')),
      );
      return;
    }

    try {
      final summary = await context.read<HrService>().importCandidatesFromFile(
        fileName: file.name,
        bytes: bytes,
      );
      if (!context.mounted) return;
      _showImportSummary(
        context,
        title: 'Candidate Import Complete',
        summary: summary,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _uploadEmployeesFromFile(BuildContext context) async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'json'],
      withData: true,
    );
    if (selected == null || selected.files.isEmpty || !context.mounted) return;

    final file = selected.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read file data.')),
      );
      return;
    }

    try {
      final summary = await context.read<HrService>().importEmployeesFromFile(
        fileName: file.name,
        bytes: bytes,
      );
      if (!context.mounted) return;
      _showImportSummary(
        context,
        title: 'Employee Import Complete',
        summary: summary,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showImportSummary(
    BuildContext context, {
    required String title,
    required HrImportSummary summary,
  }) async {
    await showMovableDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total rows: ${summary.totalRows}'),
              Text('Imported: ${summary.importedRows}'),
              Text('Skipped: ${summary.skippedRows}'),
              if (summary.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Row-level issues',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    itemCount: summary.errors.length,
                    itemBuilder: (_, index) => Text(summary.errors[index]),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}