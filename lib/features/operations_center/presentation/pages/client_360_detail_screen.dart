import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

class Client360DetailScreen extends StatelessWidget {
  const Client360DetailScreen({
    super.key,
    required this.clientName,
  });

  final String clientName;

  @override
  Widget build(BuildContext context) {
    final opsService = context.watch<OperationsCenterService>();
    final salesService = context.watch<SalesService>();
    final events = opsService.timelineForClient(clientName);
    final invoices = salesService.invoices
        .where((invoice) => invoice.customerName.trim().toLowerCase() == clientName.trim().toLowerCase())
        .toList(growable: false);

    final health = _healthScore(invoices);
    final compliance = _complianceScore(invoices);
    final accounting = _accountingScore(invoices);
    final upload = _uploadScore(invoices);
    final response = _responseScore(events);
    final risk = _riskLabel(invoices);
    final overall = ((health + compliance + accounting + upload + response) / 5).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('Client 360 - $clientName'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _scoreCard(
            health: health,
            compliance: compliance,
            accounting: accounting,
            upload: upload,
            response: response,
            overall: overall,
            risk: risk,
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Timeline Feed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (events.isEmpty)
                    const Text('No timeline events found for this client yet.')
                  else
                    ...events.map((event) => _eventTile(event)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCard({
    required int health,
    required int compliance,
    required int accounting,
    required int upload,
    required int response,
    required int overall,
    required String risk,
  }) {
    Widget scoreChip(String label, String value) {
      return Chip(label: Text('$label $value'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Health Snapshot',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                scoreChip('Health', '$health%'),
                scoreChip('Compliance', '$compliance%'),
                scoreChip('Accounting', '$accounting%'),
                scoreChip('Uploads', '$upload%'),
                scoreChip('Response', '$response%'),
                scoreChip('Overall', '$overall%'),
                scoreChip('Risk', risk),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: overall / 100),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(OperationTimelineEvent event) {
    final color = switch (event.severity) {
      OperationSeverity.info => Colors.blue,
      OperationSeverity.success => Colors.green,
      OperationSeverity.warning => Colors.orange,
      OperationSeverity.critical => Colors.red,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(event.detail),
                Text(
                  '${DateFormat('dd MMM yyyy, hh:mm a').format(event.timestamp)} - ${event.source}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _healthScore(List<SalesInvoice> invoices) {
    if (invoices.isEmpty) return 75;
    final paid = invoices.where((i) => i.status == InvoiceStatus.paid).length;
    return ((paid / invoices.length) * 100).round().clamp(40, 100);
  }

  int _complianceScore(List<SalesInvoice> invoices) {
    if (invoices.isEmpty) return 80;
    final withGst = invoices.where((i) => i.gstNumber.trim().isNotEmpty).length;
    return ((withGst / invoices.length) * 100).round().clamp(50, 100);
  }

  int _accountingScore(List<SalesInvoice> invoices) {
    if (invoices.isEmpty) return 78;
    final draft = invoices.where((i) => i.status == InvoiceStatus.draft).length;
    final score = 100 - ((draft / invoices.length) * 100).round();
    return score.clamp(40, 100);
  }

  int _uploadScore(List<SalesInvoice> invoices) {
    if (invoices.isEmpty) return 70;
    final withAttachment = invoices.where((i) => i.attachmentPaths.isNotEmpty).length;
    return ((withAttachment / invoices.length) * 100).round().clamp(30, 100);
  }

  int _responseScore(List<OperationTimelineEvent> events) {
    final warningEvents = events
        .where((e) => e.severity == OperationSeverity.warning || e.severity == OperationSeverity.critical)
        .length;
    return (100 - warningEvents * 5).clamp(45, 100);
  }

  String _riskLabel(List<SalesInvoice> invoices) {
    final highOutstanding = invoices
        .where((i) => i.outstandingAmount > i.grandTotal * 0.7)
        .length;
    if (highOutstanding >= 3) return 'HIGH';
    if (highOutstanding >= 1) return 'MEDIUM';
    return 'LOW';
  }
}