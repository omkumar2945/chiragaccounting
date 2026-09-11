// AI Review Queue Screen – exceptions only
//
// Shows only the invoices that need human attention.
// 118 ready invoices are NOT shown here.
// User clicks "Review" → opens AiWorkspaceScreen for that ONE invoice.
// After fixing → taps "Next →" to jump to the next exception.
// Never "Save / Close / Open Next" separately.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workspace_screen.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

class AiReviewQueueScreen extends StatefulWidget {
  final String? batchId; // null = show all review jobs globally

  const AiReviewQueueScreen({super.key, this.batchId});

  @override
  State<AiReviewQueueScreen> createState() => _AiReviewQueueScreenState();
}

class _AiReviewQueueScreenState extends State<AiReviewQueueScreen> {
  String? _selectedClientId;
  ClientDocumentQueueBucket? _selectedBucket;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final directory = context.watch<AdminUserService>();
    final svc = context.watch<WorkbenchQueueService>();
    var jobs = widget.batchId != null
        ? svc.batchReviewJobs(widget.batchId!)
        : svc.reviewJobs;

    jobs = _applyAssignmentScope(jobs, auth.currentUser, directory);
    final availableClientIds = jobs
        .map((job) => job.clientId)
        .whereType<String>()
        .toSet();
    if (_selectedClientId != null &&
        !availableClientIds.contains(_selectedClientId)) {
      _selectedClientId = null;
    }

    if (_selectedClientId != null) {
      jobs = jobs
          .where((job) => job.clientId == _selectedClientId)
          .toList(growable: false);
    }
    if (_selectedBucket != null) {
      jobs = jobs
          .where((job) => job.queueBucket == _selectedBucket)
          .toList(growable: false);
    }

    final selectableClients = directory.users
        .where(
          (user) => user.role.isClient && availableClientIds.contains(user.id),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Queue',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              '${jobs.length} exception${jobs.length == 1 ? '' : 's'} need attention',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (jobs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${jobs.length} remaining',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: jobs.isEmpty
          ? _buildEmpty()
          : Column(
              children: [
                _buildFilters(selectableClients),
                // Summary header
                _buildSummaryHeader(jobs),
                // Exception list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: jobs.length,
                    itemBuilder: (ctx, i) => _ExceptionCard(
                      job: jobs[i],
                      clientLabel: _clientLabelFor(jobs[i], directory),
                      index: i,
                      totalCount: jobs.length,
                      onReview: () => _openWorkspace(context, svc, jobs, i),
                      onSkip: () => svc.archiveJob(jobs[i].id),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<WorkbenchJob> _applyAssignmentScope(
    List<WorkbenchJob> jobs,
    UserModel? currentUser,
    AdminUserService directory,
  ) {
    if (currentUser == null) return const <WorkbenchJob>[];

    final role = currentUser.role;
    final unrestricted =
        role == UserRole.superAdmin ||
        role == UserRole.admin ||
        role == UserRole.firmAdmin ||
        role == UserRole.partner ||
        role == UserRole.checker;
    if (unrestricted) return jobs;

    if (role.isClient) {
      return jobs
          .where(
            (job) => job.clientId != null && job.clientId == currentUser.id,
          )
          .toList(growable: false);
    }

    return jobs
        .where((job) {
          final assignedAccountantId = job.assignedAccountantId?.trim() ?? '';
          if (assignedAccountantId.isNotEmpty) {
            return assignedAccountantId == currentUser.id;
          }
          final clientId = job.clientId;
          if (clientId == null || clientId.trim().isEmpty) return false;
          final access = directory.accountingAccessFor(clientId);
          return access.assignedAccountantId == currentUser.id ||
              access.assignedCaId == currentUser.id;
        })
        .toList(growable: false);
  }

  String _clientLabelFor(WorkbenchJob job, AdminUserService directory) {
    final clientId = job.clientId;
    if (clientId == null || clientId.isEmpty) {
      return 'Client: Unassigned';
    }
    for (final user in directory.users) {
      if (user.id == clientId) {
        return 'Client: ${user.firmName}';
      }
    }
    return 'Client: $clientId';
  }

  Widget _buildFilters(List<UserModel> clients) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String?>(
              value: _selectedClientId,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Client',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All clients'),
                ),
                ...clients.map(
                  (client) => DropdownMenuItem<String?>(
                    value: client.id,
                    child: Text(client.firmName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedClientId = value),
            ),
          ),
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<ClientDocumentQueueBucket?>(
              value: _selectedBucket,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Voucher Type Queue',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<ClientDocumentQueueBucket?>>[
                const DropdownMenuItem<ClientDocumentQueueBucket?>(
                  value: null,
                  child: Text('All voucher queues'),
                ),
                ...ClientDocumentQueueBucket.values.map(
                  (bucket) => DropdownMenuItem<ClientDocumentQueueBucket?>(
                    value: bucket,
                    child: Text(bucket.displayName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedBucket = value),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedClientId = null;
                _selectedBucket = null;
              });
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No exceptions require review.\nAll invoices have been processed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(List<WorkbenchJob> jobs) {
    final byReason = <String, int>{};
    for (final job in jobs) {
      final reason = job.reviewReason ?? job.status.label;
      byReason[reason] = (byReason[reason] ?? 0) + 1;
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: byReason.entries.map((e) {
            final color = _reasonColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${e.value}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(e.key, style: TextStyle(fontSize: 11, color: color)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _reasonColor(String reason) {
    if (reason.contains('Duplicate')) return Colors.red;
    if (reason.contains('Missing')) return Colors.orange;
    if (reason.contains('GST') || reason.contains('Tax')) return Colors.purple;
    if (reason.contains('Confidence') || reason.contains('Low')) {
      return Colors.blueGrey;
    }
    return Colors.grey;
  }

  void _openWorkspace(
    BuildContext context,
    WorkbenchQueueService svc,
    List<WorkbenchJob> jobs,
    int index,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiWorkspaceScreen(
          jobId: jobs[index].id,
          reviewQueue: jobs.map((j) => j.id).toList(),
          reviewIndex: index,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExceptionCard extends StatelessWidget {
  final WorkbenchJob job;
  final String clientLabel;
  final int index;
  final int totalCount;
  final VoidCallback onReview;
  final VoidCallback onSkip;

  const _ExceptionCard({
    required this.job,
    required this.clientLabel,
    required this.index,
    required this.totalCount,
    required this.onReview,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final reason = job.reviewReason ?? job.status.label;
    final reasonColor = _reasonColor(reason);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: reasonColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Index badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.shortName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: reasonColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: reasonColor,
                          ),
                        ),
                      ),
                      if (job.result != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          job.documentTypeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (job.status == WorkbenchJobStatus.error &&
                      job.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        job.errorMessage!,
                        style: const TextStyle(fontSize: 10, color: Colors.red),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    clientLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: onReview,
                  child: const Text('Review →', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onSkip,
                  child: const Text('Skip', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _reasonColor(String reason) {
    if (reason.contains('Duplicate')) return Colors.red;
    if (reason.contains('Missing')) return Colors.orange;
    if (reason.contains('GST') || reason.contains('Tax')) return Colors.purple;
    if (reason.contains('Confidence') || reason.contains('Low')) {
      return Colors.blueGrey;
    }
    if (reason.contains('Error') || reason.contains('Failed')) {
      return Colors.red;
    }
    return Colors.grey;
  }
}
