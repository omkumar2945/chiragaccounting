import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';

class ManagerOperationsCenterScreen extends StatelessWidget {
  const ManagerOperationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<OperationsCenterService>().snapshot;

    Widget metric(String title) {
      final value = (snapshot.metrics[title] ?? 0).toString();
      return Card(
        child: ListTile(
          title: Text(title),
          trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Operations Center'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Operational Control', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          metric('Waiting Accountant'),
          metric('Waiting Approval'),
          metric('Overdue'),
          metric('Escalated'),
          metric('Pending Filing'),
          metric('Today Collections (L)'),
          metric('Outstanding (L)'),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Manager view excludes bookkeeping details and prioritizes workload, delays, quality, capacity, escalations, revenue, and collections.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
