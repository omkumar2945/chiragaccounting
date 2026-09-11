import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';

class ClientDocumentsScreen extends StatelessWidget {
  const ClientDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final clientId = user?.id;
    final allJobs = context.watch<WorkbenchQueueService>().allJobs;
    final jobs = allJobs
        .where((job) => (job.clientId ?? '').trim().isNotEmpty)
        .where((job) => job.clientId == clientId)
        .toList(growable: false)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    final active = jobs.where((job) => job.status.isActive).length;
    final completed = jobs
        .where((job) => job.status == WorkbenchJobStatus.completed)
        .length;
    final failed = jobs.where((job) => job.status == WorkbenchJobStatus.error).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Client Documents')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Pending: $active')),
              Chip(label: Text('Completed: $completed')),
              Chip(label: Text('Error: $failed')),
            ],
          ),
          const SizedBox(height: 12),
          if (jobs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No uploads yet. Start from Client Uploads and files will appear here in real time.',
                ),
              ),
            )
          else
            ...jobs.map(
              (job) => Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(job.shortName),
                  subtitle: Text(
                    '${job.queueBucketLabel} | ${job.status.label}',
                  ),
                  trailing: Text(_timeLabel(job.uploadedAt)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
