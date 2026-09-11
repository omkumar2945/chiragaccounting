// AI Batch Processing Screen
//
// Shown when user uploads 2+ files.
// Never opens individual invoice forms.
// Shows bulk progress and routes to review queue for exceptions only.
//
// ┌────────────────────────────────────────────────────────┐
// │  AI Processing Center                                  │
// ├────────────────────────────────────────────────────────┤
// │  125 Documents uploaded                                │
// │  [Start AI Processing]                                 │
// ├────────────────────────────────────────────────────────┤
// │  Processing... ████████████░░░░░░  98 / 125           │
// ├────────────────────────────────────────────────────────┤
// │  ✅ 118 Ready    ⚠ 5 Need Review    ❌ 2 Failed        │
// ├────────────────────────────────────────────────────────┤
// │  [Save All Ready (118)]  [Review Exceptions (5)]       │
// │  [Missing Masters Center]                              │
// └────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_review_queue_screen.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_missing_masters_screen.dart';

class AiBatchProcessingScreen extends StatelessWidget {
  final String batchId;

  const AiBatchProcessingScreen({super.key, required this.batchId});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<WorkbenchQueueService>();
    final stats = svc.batchStats(batchId);
    final jobs = svc.batchJobs(batchId);
    final isProcessing = stats.processing > 0 || stats.inbox > 0;
    final doneCount = stats.ready + stats.failed + stats.review;
    final progress = stats.total > 0 ? doneCount / stats.total : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text(
          'AI Processing Center',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (svc.globalMissingMasters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('${svc.globalMissingMasters.where((m) => !m.resolved).length}'),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Missing Masters',
                  onPressed: () => _openMissingMasters(context),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Upload Summary ──────────────────────────────────────────────
            _UploadSummaryCard(total: stats.total, batchId: batchId),
            const SizedBox(height: 16),

            // ── Progress Bar ─────────────────────────────────────────────────
            if (stats.total > 0) ...[
              _ProgressCard(
                progress: progress,
                processed: doneCount,
                total: stats.total,
                isProcessing: isProcessing,
              ),
              const SizedBox(height: 16),
            ],

            // ── Results Cards ────────────────────────────────────────────────
            if (doneCount > 0) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  if (compact) {
                    return Column(
                      children: [
                        _ResultCard(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          label: 'Ready',
                          count: stats.ready,
                          subtitle: 'Auto-approved',
                        ),
                        const SizedBox(height: 12),
                        _ResultCard(
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange,
                          label: 'Need Review',
                          count: stats.review,
                          subtitle: 'Exceptions',
                        ),
                        const SizedBox(height: 12),
                        _ResultCard(
                          icon: Icons.cancel_outlined,
                          color: Colors.red,
                          label: 'Failed',
                          count: stats.failed,
                          subtitle: 'OCR / parse error',
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: _ResultCard(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          label: 'Ready',
                          count: stats.ready,
                          subtitle: 'Auto-approved',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ResultCard(
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange,
                          label: 'Need Review',
                          count: stats.review,
                          subtitle: 'Exceptions',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ResultCard(
                          icon: Icons.cancel_outlined,
                          color: Colors.red,
                          label: 'Failed',
                          count: stats.failed,
                          subtitle: 'OCR / parse error',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // ── Action Buttons ───────────────────────────────────────────────
            if (!isProcessing && stats.total > 0) ...[
              if (stats.ready > 0)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    svc.saveBatchReady(batchId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${stats.ready} invoices saved to accounting'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.done_all, size: 20),
                  label: Text(
                    'Save All Ready  (${stats.ready})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 12),
              if (stats.review > 0 || stats.failed > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 1.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AiReviewQueueScreen(batchId: batchId),
                    ),
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 20),
                  label: Text(
                    'Review Exceptions  (${stats.review + stats.failed})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 12),
              if (svc.globalMissingMasters
                  .where((m) => !m.resolved)
                  .isNotEmpty)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber.shade700,
                    side: BorderSide(
                        color: Colors.amber.shade700, width: 1.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openMissingMasters(context),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: Text(
                    'Missing Masters Center  (${svc.globalMissingMasters.where((m) => !m.resolved).length})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // ── AI Stats ─────────────────────────────────────────────────────
            _AiStatsBar(svc: svc),
            const SizedBox(height: 20),

            // ── Document List ────────────────────────────────────────────────
            if (jobs.isNotEmpty) ...[
              Text(
                'Documents (${jobs.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...jobs.map((job) => _BatchJobRow(job: job)),
            ],
          ],
        ),
      ),
    );
  }

  void _openMissingMasters(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiMissingMastersCenterScreen(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UploadSummaryCard extends StatelessWidget {
  final int total;
  final String batchId;

  const _UploadSummaryCard({required this.total, required this.batchId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.upload_file_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total Documents',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
                const Text(
                  'Uploaded to AI Processing Center',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome, color: Colors.white70, size: 28),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final double progress;
  final int processed;
  final int total;
  final bool isProcessing;

  const _ProgressCard({
    required this.progress,
    required this.processed,
    required this.total,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isProcessing) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ] else
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  isProcessing
                      ? 'AI Processing...'
                      : 'Processing Complete',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '$processed / $total',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: isProcessing
                  ? const Color(0xFF1A237E)
                  : Colors.green,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()}% complete',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final String subtitle;

  const _ResultCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.black38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AiStatsBar extends StatelessWidget {
  final WorkbenchQueueService svc;

  const _AiStatsBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _statMini('Accuracy',
                '${svc.totalProcessed > 0 ? ((svc.totalProcessed - svc.errorsFound) / svc.totalProcessed * 100).round() : 100}%',
                Colors.indigo)),
        const SizedBox(width: 8),
        Expanded(
            child: _statMini(
                'Duplicates', '${svc.duplicatesPrevented}', Colors.orange)),
        const SizedBox(width: 8),
        Expanded(
            child: _statMini(
                'New Masters', '${svc.globalMissingMasters.length}', Colors.teal)),
        const SizedBox(width: 8),
        Expanded(
            child: _statMini(
                'Time Saved',
                '${(svc.totalProcessed * 3.2 / 60).toStringAsFixed(1)}h',
                Colors.green)),
      ],
    );
  }

  Widget _statMini(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black38),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BatchJobRow extends StatelessWidget {
  final WorkbenchJob job;

  const _BatchJobRow({required this.job});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    switch (job.status) {
      case WorkbenchJobStatus.approved:
      case WorkbenchJobStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case WorkbenchJobStatus.verification:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case WorkbenchJobStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case WorkbenchJobStatus.processing:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              job.shortName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (job.reviewReason != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                job.reviewReason!,
                style: const TextStyle(fontSize: 10, color: Colors.orange),
              ),
            )
          else if (job.result != null)
            Text(
              job.documentTypeLabel,
              style: const TextStyle(fontSize: 10, color: Colors.black38),
            ),
          if (job.status == WorkbenchJobStatus.processing)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
