import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/accounting/accounting_policy_service.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workbench_screen.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/accountant/presentation/pages/ocr_module_screen.dart';
import 'package:chirag_accounting/features/accountant/presentation/widgets/accountant_dashboard_view.dart';
import 'package:chirag_accounting/features/accountant/services/accountant_performance_service.dart';
import 'package:chirag_accounting/features/accountant/services/accountant_profile_service.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/tally_sync_management_screen.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/business_templates/presentation/pages/client_accounting_workspace_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/gst_workbench/presentation/pages/accountant_gst_workbench_screen.dart';
import 'package:chirag_accounting/features/gst_operations/presentation/pages/gst_document_operations_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/my_work_queue_screen.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_dashboard_screen.dart';
import 'package:chirag_accounting/features/workflow/models/universal_status.dart';
import 'package:chirag_accounting/features/tasks/models/work_queue_bucket.dart';
import 'package:chirag_accounting/features/tasks/models/work_task.dart';
import 'package:chirag_accounting/features/tasks/services/task_engine_service.dart';
import 'package:chirag_accounting/shared/widgets/session_logout_button.dart';

class AccountantDashboardScreen extends StatefulWidget {
  const AccountantDashboardScreen({super.key});

  @override
  State<AccountantDashboardScreen> createState() =>
      _AccountantDashboardScreenState();
}

class _AccountantDashboardScreenState extends State<AccountantDashboardScreen> {
  bool _showWorkHistory = false;

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openProfileEditor(AccountantProfile profile) async {
    final name = TextEditingController(text: profile.fullName);
    final email = TextEditingController(text: profile.email);
    final mobile = TextEditingController(text: profile.mobile);
    final designation = TextEditingController(text: profile.designation);
    String resumePath = profile.resumePath;
    String kycPath = profile.kycDocumentPath;
    String photoPath = profile.photoPath;
    String photoBase64 = profile.photoBase64;

    Future<void> pickResume(StateSetter setDialog) async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['pdf', 'doc', 'docx'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.trim().isEmpty) return;
      setDialog(() => resumePath = path);
    }

    Future<void> pickKyc(StateSetter setDialog) async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.trim().isEmpty) return;
      setDialog(() => kycPath = path);
    }

    Future<void> pickPhoto(StateSetter setDialog) async {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      if (picked.bytes == null || picked.bytes!.isEmpty) return;
      setDialog(() {
        photoPath = picked.path ?? photoPath;
        photoBase64 = base64Encode(picked.bytes!);
      });
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Accountant Profile'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: designation,
                    decoration: const InputDecoration(labelText: 'Designation'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mobile,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                  const SizedBox(height: 14),
                  _docTile(
                    title: 'Resume',
                    path: resumePath,
                    icon: Icons.description_outlined,
                    onPick: () => pickResume(setDialog),
                  ),
                  _docTile(
                    title: 'KYC Document',
                    path: kycPath,
                    icon: Icons.badge_outlined,
                    onPick: () => pickKyc(setDialog),
                  ),
                  _docTile(
                    title: 'Profile Photo',
                    path: photoPath,
                    icon: Icons.photo_camera_outlined,
                    onPick: () => pickPhoto(setDialog),
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
      ),
    );

    if (saved != true || !mounted) {
      name.dispose();
      email.dispose();
      mobile.dispose();
      designation.dispose();
      return;
    }

    final service = context.read<AccountantProfileService>();
    await service.saveProfile(
      profile.copyWith(
        fullName: name.text.trim(),
        designation: designation.text.trim().isEmpty
            ? 'Accountant'
            : designation.text.trim(),
        email: email.text.trim(),
        mobile: mobile.text.trim(),
        resumePath: resumePath,
        kycDocumentPath: kycPath,
        photoPath: photoPath,
        photoBase64: photoBase64,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accountant profile updated successfully.')),
    );

    name.dispose();
    email.dispose();
    mobile.dispose();
    designation.dispose();
  }

  Future<void> _openTargetsEditor(AccountantProfile profile) async {
    final taskTarget = TextEditingController(
      text: profile.target.monthlyTaskTarget.toString(),
    );
    final revenueTarget = TextEditingController(
      text: profile.target.monthlyRevenueTarget.toStringAsFixed(0),
    );
    final qualityTarget = TextEditingController(
      text: profile.target.clientSatisfactionTarget.toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Monthly Targets'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskTarget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Task completion target (count)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: revenueTarget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Revenue support target (INR)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qualityTarget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Client satisfaction target (%)',
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
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save Targets'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      taskTarget.dispose();
      revenueTarget.dispose();
      qualityTarget.dispose();
      return;
    }

    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final service = context.read<AccountantProfileService>();
    await service.updateTargets(
      userId: user.id,
      target: AccountantTargetProfile(
        monthlyTaskTarget:
            int.tryParse(taskTarget.text.trim()) ??
            profile.target.monthlyTaskTarget,
        monthlyRevenueTarget:
            double.tryParse(revenueTarget.text.trim()) ??
            profile.target.monthlyRevenueTarget,
        clientSatisfactionTarget:
            int.tryParse(qualityTarget.text.trim()) ??
            profile.target.clientSatisfactionTarget,
      ),
      fallbackName: user.name,
      fallbackEmail: user.email,
      fallbackMobile: user.mobile,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Targets updated.')));

    taskTarget.dispose();
    revenueTarget.dispose();
    qualityTarget.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not found. Please login again.')),
      );
    }

    final queue = context.watch<TaskEngineService>();
    final workbench = context.watch<WorkbenchQueueService?>();
    final accountingPolicy = context.watch<AccountingPolicyService?>();
    final profileService = context.watch<AccountantProfileService>();
    final profile = profileService.profileFor(
      userId: user.id,
      fallbackName: user.name,
      fallbackEmail: user.email,
      fallbackMobile: user.mobile,
    );
    final now = DateTime.now();
    final financialPeriod =
        accountingPolicy?.period ??
        AccountantPerformanceService.currentIndianFinancialYear(now);
    final performance = const AccountantPerformanceService().build(
      profile: profile,
      tasks: queue.tasks,
      period: financialPeriod,
      now: now,
      completedToday: queue.countByBucket(WorkQueueBucket.completedToday),
      overdueTasks: queue.countByBucket(WorkQueueBucket.overdue),
      escalatedTasks: queue.countByBucket(WorkQueueBucket.escalated),
    );

    return AccountantDashboardView(
      user: user,
      profile: profile,
      performance: performance,
      tasks: queue.tasks,
      countByBucket: queue.countByBucket,
      workbenchInbox: workbench?.inboxJobs.length ?? 0,
      workbenchProcessing: workbench?.processingJobs.length ?? 0,
      workbenchReview: workbench?.reviewJobs.length ?? 0,
      workbenchCompleted: workbench?.completedJobs.length ?? 0,
      showWorkHistory: _showWorkHistory,
      onWorkHistoryChanged: (value) {
        setState(() => _showWorkHistory = value);
      },
      onEditProfile: () => _openProfileEditor(profile),
      tallySyncBuilder: (_) => const TallySyncManagementScreen(),
      approvalsBuilder: (_) => const MyWorkQueueScreen(),
      voucherCheckBuilder: (_) => const VoucherEntryDashboardScreen(),
      workbenchBuilder: (_) => const AiWorkbenchScreen(),
      ocrBuilder: (_) => const OcrModuleScreen(),
      showGstWork: PermissionMatrix.canAccess(user.role, AppModule.gst),
      gstWorkBuilder: (_) => const AccountantGstWorkbenchScreen(
        key: ValueKey('accountant-gst-workbench'),
      ),
      itcReconciliationBuilder: (_) => const AccountantGstWorkbenchScreen(
        key: ValueKey('accountant-itc-reconciliation'),
        initialSection: 'ITC Reconciliation',
      ),
      eInvoiceBuilder: (_) => const GstDocumentOperationsScreen.eInvoice(),
      eWayBillBuilder: (_) => const GstDocumentOperationsScreen.eWayBill(),
      clientAccountingBuilder: (_) => const ClientAccountingWorkspaceScreen(),
      reportsBuilder: (_) => const ClientAccountingWorkspaceScreen(
        initialArea: ClientAccountingWorkspaceArea.reports,
      ),
      settingsBuilder: (_) => const ClientSettingsScreen(),
    );
  }

  Widget _buildLegacyDashboard(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not found. Please login again.')),
      );
    }

    final queue = context.watch<TaskEngineService>();
    final workbench = context.watch<WorkbenchQueueService?>();
    final profileService = context.watch<AccountantProfileService>();
    final profile = profileService.profileFor(
      userId: user.id,
      fallbackName: user.name,
      fallbackEmail: user.email,
      fallbackMobile: user.mobile,
    );

    final completedToday = queue.countByBucket(WorkQueueBucket.completedToday);
    final overdue = queue.countByBucket(WorkQueueBucket.overdue);
    final waitingClient = queue.countByBucket(WorkQueueBucket.waitingClient);
    final waitingCa = queue.countByBucket(WorkQueueBucket.waitingCa);
    final pendingApprovals = queue.countByBucket(
      WorkQueueBucket.waitingApproval,
    );
    final waitingAuditor = queue.countByBucket(WorkQueueBucket.waitingAuditor);
    final waitingAccountant = queue.countByBucket(
      WorkQueueBucket.waitingAccountant,
    );

    final activeWorkload = waitingClient + waitingCa + overdue;
    final monthlyTaskTarget = profile.target.monthlyTaskTarget.clamp(1, 100000);
    final taskProgress = (completedToday / monthlyTaskTarget).clamp(0.0, 1.0);

    final todayDone = queue.tasks
        .where((task) => task.bucket == WorkQueueBucket.completedToday)
        .toList(growable: false);
    final historyDone = queue.tasks
        .where(
          (task) =>
              task.status == UniversalStatus.completed ||
              task.status == UniversalStatus.archived,
        )
        .toList(growable: false);
    final workDoneTasks = _showWorkHistory ? historyDone : todayDone;

    final assignedToMe = queue.tasks
        .where((task) => task.owner == user.id)
        .toList(growable: false);
    final isWideLayout = MediaQuery.of(context).size.width >= 1100;

    final dashboardContent = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF0A3A86),
                  child: Text(
                    (profile.fullName.isEmpty ? user.name : profile.fullName)
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName.isEmpty ? user.name : profile.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        profile.designation,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(user.firmName, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openProfileEditor(profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Profile'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricCard(
              'Completed',
              '$completedToday',
              Icons.task_alt_outlined,
              const Color(0xFF2E7D32),
            ),
            _metricCard(
              'Active Workload',
              '$activeWorkload',
              Icons.work_history_outlined,
              const Color(0xFF1565C0),
            ),
            _metricCard(
              'Overdue',
              '$overdue',
              Icons.warning_amber_outlined,
              const Color(0xFFC62828),
            ),
            _metricCard(
              'Waiting Client',
              '$waitingClient',
              Icons.hourglass_bottom_outlined,
              const Color(0xFF6A1B9A),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TallySyncManagementScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.sync_alt_outlined),
                  label: const Text('Tally Sync'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyWorkQueueScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.approval_outlined),
                  label: const Text('Approvals'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Pending Approvals: $pendingApprovals',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _workflowCard(
          title: 'Pending Work Buckets',
          subtitle: 'All operational queues with current counts',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.pendingOcr),
                value: queue.countByBucket(WorkQueueBucket.pendingOcr),
                color: const Color(0xFF6A1B9A),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.waitingClient),
                value: waitingClient,
                color: const Color(0xFFEF6C00),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.waitingAccountant),
                value: waitingAccountant,
                color: const Color(0xFF0D47A1),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.waitingCa),
                value: waitingCa,
                color: const Color(0xFF1565C0),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.waitingAuditor),
                value: waitingAuditor,
                color: const Color(0xFF283593),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.waitingApproval),
                value: pendingApprovals,
                color: const Color(0xFF00796B),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.completedToday),
                value: completedToday,
                color: const Color(0xFF2E7D32),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.overdue),
                value: overdue,
                color: const Color(0xFFC62828),
              ),
              _miniStatChip(
                label: _bucketLabel(WorkQueueBucket.escalated),
                value: queue.countByBucket(WorkQueueBucket.escalated),
                color: const Color(0xFFAD1457),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Monthly Performance & Targets',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openTargetsEditor(profile),
                      icon: const Icon(Icons.tune),
                      label: const Text('Edit Targets'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Task Target: $completedToday / ${profile.target.monthlyTaskTarget}',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: taskProgress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Text(
                  'Revenue Support Target: INR ${profile.target.monthlyRevenueTarget.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Client Satisfaction Target: ${profile.target.clientSatisfactionTarget}%',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _workflowCard(
          title: 'Work Done',
          subtitle: _showWorkHistory
              ? 'Completed and archived history'
              : 'Completed today',
          trailing: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('Today')),
              ButtonSegment<bool>(value: true, label: Text('History')),
            ],
            selected: <bool>{_showWorkHistory},
            onSelectionChanged: (selection) {
              setState(() => _showWorkHistory = selection.first);
            },
          ),
          child: _taskList(
            tasks: workDoneTasks,
            emptyMessage: _showWorkHistory
                ? 'No completed work history available.'
                : 'No tasks completed today yet.',
          ),
        ),
        const SizedBox(height: 12),
        _workflowCard(
          title: 'Assigned To Me',
          subtitle: 'Tasks where owner is your user ID',
          child: _taskList(
            tasks: assignedToMe,
            emptyMessage: 'No tasks are currently assigned to your user ID.',
          ),
        ),
        const SizedBox(height: 12),
        _workflowCard(
          title: 'Upload Images & Document Queue',
          subtitle: 'Track upload processing and open AI workbench',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _uploadStat(
                      'Inbox',
                      workbench?.inboxJobs.length ?? 0,
                      const Color(0xFF5E35B1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _uploadStat(
                      'Processing',
                      workbench?.processingJobs.length ?? 0,
                      const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _uploadStat(
                      'Review',
                      workbench?.reviewJobs.length ?? 0,
                      const Color(0xFFEF6C00),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _uploadStat(
                      'Completed',
                      workbench?.completedJobs.length ?? 0,
                      const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AiWorkbenchScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Open Upload Workbench'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _workflowCard(
          title: 'OCR Module',
          subtitle: 'Original Chirag OCR entry workspace',
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _openScreen(const OcrModuleScreen()),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Open OCR Module'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _workflowCard(
          title: 'Entries Check',
          subtitle: 'Voucher entry queue and checks',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusPill(
                    'Waiting Accountant: $waitingAccountant',
                    const Color(0xFF0D47A1),
                  ),
                  _statusPill(
                    'Waiting Approval: $pendingApprovals',
                    const Color(0xFF00796B),
                  ),
                  _statusPill('Overdue: $overdue', const Color(0xFFC62828)),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VoucherEntryDashboardScreen(),
                  ),
                ),
                icon: const Icon(Icons.playlist_add_check_circle_outlined),
                label: const Text('Open Voucher Entries Check'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accounting Workflow',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TallySyncManagementScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.sync_alt_outlined),
                      label: const Text('Tally Sync Center'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyWorkQueueScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.approval_outlined),
                      label: const Text('Approval Queue'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCE3ED)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fact_check_outlined,
                        color: Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approvals in Queue: $pendingApprovals',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Review client and workflow approvals without leaving the dashboard.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _docStatus('Resume', profile.resumePath),
                _docStatus('KYC', profile.kycDocumentPath),
                _docStatus('Photo', profile.photoPath),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyWorkQueueScreen()),
          ),
          icon: const Icon(Icons.view_list_outlined),
          label: const Text('Open My Work Queue'),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Accountant Dashboard'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => _openProfileEditor(profile),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientSettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SessionLogoutButton(),
        ],
      ),
      body: isWideLayout
          ? Row(
              children: [
                Expanded(child: dashboardContent),
                Container(
                  width: 300,
                  margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: _rightSideMenu(
                    profile: profile,
                    pendingApprovals: pendingApprovals,
                    waitingAccountant: waitingAccountant,
                    waitingClient: waitingClient,
                    overdue: overdue,
                  ),
                ),
              ],
            )
          : dashboardContent,
    );
  }

  Widget _rightSideMenu({
    required AccountantProfile profile,
    required int pendingApprovals,
    required int waitingAccountant,
    required int waitingClient,
    required int overdue,
  }) {
    final alertCount = pendingApprovals + overdue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Options',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              profile.designation,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            _menuOptionTile(
              icon: Icons.sync_alt_outlined,
              label: 'Tally Sync Center',
              subtitle: 'Sync entries and monitor status',
              badge: null,
              onTap: () => _openScreen(const TallySyncManagementScreen()),
            ),
            _menuOptionTile(
              icon: Icons.approval_outlined,
              label: 'Approval Queue',
              subtitle: 'Review pending requests',
              badge: pendingApprovals,
              onTap: () => _openScreen(const MyWorkQueueScreen()),
            ),
            _menuOptionTile(
              icon: Icons.playlist_add_check_circle_outlined,
              label: 'Voucher Entries Check',
              subtitle: 'Open entries verification board',
              badge: waitingAccountant,
              onTap: () => _openScreen(const VoucherEntryDashboardScreen()),
            ),
            _menuOptionTile(
              icon: Icons.upload_file_outlined,
              label: 'Upload Workbench',
              subtitle: 'Process invoice and docs queue',
              badge: null,
              onTap: () => _openScreen(const AiWorkbenchScreen()),
            ),
            _menuOptionTile(
              icon: Icons.document_scanner_outlined,
              label: 'OCR Module',
              subtitle: 'Open the original OCR entry workspace',
              badge: null,
              onTap: () => _openScreen(const OcrModuleScreen()),
            ),
            _menuOptionTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              subtitle: 'Workspace and account settings',
              badge: null,
              onTap: () => _openScreen(const ClientSettingsScreen()),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCCDFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick alerts: $alertCount',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Waiting Client: $waitingClient',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Overdue: $overdue',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required int? badge,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDCE3ED)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF0A3A86)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null && badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A3A86),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE3ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _workflowCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _miniStatChip({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE3ED)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadStat(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _taskList({
    required List<WorkTask> tasks,
    required String emptyMessage,
  }) {
    if (tasks.isEmpty) {
      return Text(emptyMessage, style: const TextStyle(color: Colors.black54));
    }

    final visible = tasks.take(5).toList(growable: false);
    return Column(
      children: [
        for (final task in visible)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.task_alt_outlined),
            title: Text(task.title),
            subtitle: Text(
              '${task.clientName} • ${_bucketLabel(task.bucket)} • ${task.status.name}',
            ),
            trailing: Text(
              '${task.dueDate.day.toString().padLeft(2, '0')}/${task.dueDate.month.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (tasks.length > visible.length)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '+${tasks.length - visible.length} more task(s)',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }

  String _bucketLabel(WorkQueueBucket bucket) {
    switch (bucket) {
      case WorkQueueBucket.pendingOcr:
        return 'Pending OCR';
      case WorkQueueBucket.waitingClient:
        return 'Waiting Client';
      case WorkQueueBucket.waitingAccountant:
        return 'Waiting Accountant';
      case WorkQueueBucket.waitingCa:
        return 'Waiting CA';
      case WorkQueueBucket.waitingAuditor:
        return 'Waiting Auditor';
      case WorkQueueBucket.waitingApproval:
        return 'Waiting Approval';
      case WorkQueueBucket.completedToday:
        return 'Completed Today';
      case WorkQueueBucket.overdue:
        return 'Overdue';
      case WorkQueueBucket.escalated:
        return 'Escalated';
    }
  }

  Widget _docTile({
    required String title,
    required String path,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(path.trim().isEmpty ? 'Not uploaded' : path),
      trailing: OutlinedButton(
        onPressed: onPick,
        child: Text(path.trim().isEmpty ? 'Upload' : 'Replace'),
      ),
    );
  }

  Widget _docStatus(String label, String path) {
    final available = path.trim().isNotEmpty;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        available ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      ),
      title: Text(label),
      subtitle: Text(available ? 'Uploaded' : 'Pending upload'),
    );
  }
}
