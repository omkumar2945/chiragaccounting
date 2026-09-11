import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';

class OperationsMetricDetailScreen extends StatelessWidget {
  const OperationsMetricDetailScreen({
    super.key,
    required this.metricTitle,
    required this.value,
    required this.events,
  });

  final String metricTitle;
  final String value;
  final List<OperationTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(metricTitle),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Current Value'),
              subtitle: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Related Timeline Events',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (events.isEmpty)
                    const Text('No events available for this metric yet.')
                  else
                    ...events.map(_tile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(OperationTimelineEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.timeline, size: 18),
        title: Text(event.title),
        subtitle: Text(
          '${event.detail}\n${DateFormat('dd MMM yyyy, hh:mm a').format(event.timestamp)} - ${event.clientName}',
        ),
      ),
    );
  }
}