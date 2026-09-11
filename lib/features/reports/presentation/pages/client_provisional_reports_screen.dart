import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/reports/services/client_provisional_report_service.dart';

class ClientProvisionalReportsScreen extends StatelessWidget {
  const ClientProvisionalReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = context.watch<AuthController>().currentUser;
    if (client == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Provisional Reports')),
      body: FutureBuilder<List<ClientProvisionalReport>>(
        future: const ClientProvisionalReportService().reportsForClient(client.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? const <ClientProvisionalReport>[];
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Your CA has not finalized a provisional report yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ReportCard(report: reports[index]),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ClientProvisionalReport report;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd MMM yyyy').format(report.finalizedAt ?? report.createdAt);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.verified_outlined, color: Colors.green),
        title: Text('Finalized projection - $date'),
        subtitle: Text(
          'Prepared by ${report.preparedBy} | Growth ${report.growthPercent.toStringAsFixed(1)}%',
        ),
        children: report.projections
            .map(
              (year) => ListTile(
                title: Text(year.label),
                subtitle: Text(
                  'Income ${currency.format(year.totalIncome)} | Assets ${currency.format(year.totalAssets)}',
                ),
                trailing: Text('PAT\n${currency.format(year.netProfit)}', textAlign: TextAlign.end),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}