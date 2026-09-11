import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workspace_screen.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/tasks/models/work_task.dart';
import 'package:chirag_accounting/features/tasks/services/task_engine_service.dart';
import 'package:chirag_accounting/features/workflow/models/universal_status.dart';

class MyWorkQueueScreen extends StatelessWidget {
  const MyWorkQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskEngineService>().tasks;
    final reviewJobs = context
        .watch<WorkbenchQueueService>()
        .reviewJobs
        .toList(growable: false)
      ..sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
    final reviewQueueIds = reviewJobs.map((job) => job.id).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Work Queue'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WorkQueueBucket.values.map((bucket) {
              final count = tasks.where((task) => task.bucket == bucket).length;
              return Chip(label: Text('${_bucketLabel(bucket)}: $count'));
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'AI Verification Queue',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(label: Text('${reviewJobs.length} pending')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (reviewJobs.isEmpty)
                    const Text('No documents pending AI verification.')
                  else
                    ...reviewJobs.asMap().entries.take(5).map((entry) {
                      final index = entry.key;
                      final job = entry.value;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(job.shortName),
                        subtitle: Text(
                          '${job.queueBucketLabel} | ${job.status.label}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiWorkspaceScreen(
                                jobId: job.id,
                                reviewQueue: reviewQueueIds,
                                reviewIndex: index,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('No tasks in queue yet.'),
              ),
            )
          else
            ...tasks.map((task) => Card(
                  child: ListTile(
                    title: Text(task.title),
                    subtitle: Text(
                      '${task.clientName} | ${task.status.displayName} | Due ${task.dueDate}',
                    ),
                  ),
                )),
        ],
      ),
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
}
