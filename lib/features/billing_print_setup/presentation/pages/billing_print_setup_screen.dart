import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/billing_print_setup/models/billing_print_setup_models.dart';
import 'package:chirag_accounting/features/billing_print_setup/services/billing_print_setup_service.dart';

class BillingPrintSetupScreen extends StatefulWidget {
  const BillingPrintSetupScreen({super.key});

  @override
  State<BillingPrintSetupScreen> createState() => _BillingPrintSetupScreenState();
}

class _BillingPrintSetupScreenState extends State<BillingPrintSetupScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  BillingProfileStatus? _filter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<BillingPrintSetupService>();
    final all = service.searchProfiles(_searchCtrl.text);
    final rows = _filter == null
        ? all
        : all.where((profile) => profile.status == _filter).toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Billing & Print Setup'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateProfileDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Billing Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search Client / Company',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _filterChip('All', null),
                _filterChip('Active', BillingProfileStatus.active),
                _filterChip('Pending Approval', BillingProfileStatus.pendingApproval),
                _filterChip('Locked', BillingProfileStatus.locked),
                _filterChip('Change Requested', BillingProfileStatus.changeRequested),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: rows.isEmpty
                    ? const Center(child: Text('No billing profiles yet.'))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Client')),
                            DataColumn(label: Text('Invoice Design')),
                            DataColumn(label: Text('Paper')),
                            DataColumn(label: Text('Printer')),
                            DataColumn(label: Text('Version')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: rows.map((profile) {
                            final printer = profile.defaultPrintProfile;
                            final paper = printer?.paperProfile.preset.name.toUpperCase() ?? '-';
                            return DataRow(cells: <DataCell>[
                              DataCell(Text(profile.clientName)),
                              DataCell(Text(profile.invoiceFormat.name)),
                              DataCell(Text(paper)),
                              DataCell(Text(printer?.printerName ?? '-')),
                              DataCell(Text('v${profile.version}')),
                              DataCell(Text(profile.status.name.toUpperCase())),
                              DataCell(
                                TextButton(
                                  onPressed: () => _openProfileDetails(context, profile),
                                  child: const Text('View'),
                                ),
                              ),
                            ]);
                          }).toList(growable: false),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, BillingProfileStatus? status) {
    final selected = _filter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
    );
  }

  Future<void> _openCreateProfileDialog(BuildContext context) async {
    final directory = context.read<AdminUserService>();
    final clients = directory.users.where((u) => u.role.isClient).toList(growable: false);
    String? clientId = clients.isNotEmpty ? clients.first.id : null;
    BillingBusinessType businessType = BillingBusinessType.retail;
    InvoicePrintFormat format = InvoicePrintFormat.a4Full;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Billing Profile'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      value: clientId,
                      decoration: const InputDecoration(labelText: 'Client / Company'),
                      items: clients
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.firmName.isEmpty ? c.name : c.firmName)))
                          .toList(growable: false),
                      onChanged: (value) => setStateDialog(() => clientId = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<BillingBusinessType>(
                      value: businessType,
                      decoration: const InputDecoration(labelText: 'Business Type'),
                      items: BillingBusinessType.values
                          .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                          .toList(growable: false),
                      onChanged: (value) => setStateDialog(() => businessType = value ?? businessType),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<InvoicePrintFormat>(
                      value: format,
                      decoration: const InputDecoration(labelText: 'Invoice Print Format'),
                      items: InvoicePrintFormat.values
                          .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                          .toList(growable: false),
                      onChanged: (value) => setStateDialog(() => format = value ?? format),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: clientId == null
                  ? null
                  : () {
                      final client = clients.firstWhere((c) => c.id == clientId);
                      context.read<BillingPrintSetupService>().createProfile(
                            clientId: client.id,
                            clientName: client.firmName.isEmpty ? client.name : client.firmName,
                            createdBy: 'admin',
                            businessType: businessType,
                            format: format,
                          );
                      Navigator.pop(context);
                    },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openProfileDetails(BuildContext context, BillingProfile profile) async {
    final changeReasonCtrl = TextEditingController();
    InvoicePrintFormat requestedFormat = profile.invoiceFormat;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Billing Profile: ${profile.clientName}'),
          content: StatefulBuilder(builder: (context, setStateDialog) {
            final service = context.watch<BillingPrintSetupService>();
            final refreshed = service.profiles.where((p) => p.id == profile.id).firstOrNull ?? profile;

            return SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Status: ${refreshed.status.name.toUpperCase()}'),
                    Text('Current Version: v${refreshed.version}'),
                    Text('Format: ${refreshed.invoiceFormat.name}'),
                    Text('Default Printer: ${refreshed.defaultPrintProfile?.printerName ?? '-'}'),
                    const Divider(),
                    const Text('Change Request', style: TextStyle(fontWeight: FontWeight.w700)),
                    DropdownButtonFormField<InvoicePrintFormat>(
                      value: requestedFormat,
                      items: InvoicePrintFormat.values
                          .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                          .toList(growable: false),
                      onChanged: (value) => setStateDialog(() => requestedFormat = value ?? requestedFormat),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: changeReasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        FilledButton.tonal(
                          onPressed: () {
                            if (changeReasonCtrl.text.trim().isEmpty) return;
                            context.read<BillingPrintSetupService>().requestChange(
                                  profileId: refreshed.id,
                                  requestedBy: 'client',
                                  reason: changeReasonCtrl.text.trim(),
                                  requestedFormat: requestedFormat,
                                );
                          },
                          child: const Text('Request Change'),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('Admin Approval', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: service.changeRequests
                          .where((r) => r.profileId == refreshed.id && r.status == BillingProfileStatus.pendingApproval)
                          .map((request) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text('Pending: ${request.requestedFormat.name}'),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () => context.read<BillingPrintSetupService>().approveChange(
                                          requestId: request.id,
                                          approvedBy: 'admin',
                                        ),
                                    child: const Text('Approve'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => context.read<BillingPrintSetupService>().rejectChange(
                                          requestId: request.id,
                                          rejectedBy: 'admin',
                                        ),
                                    child: const Text('Reject'),
                                  ),
                                ],
                              ))
                          .toList(growable: false),
                    ),
                    const Divider(),
                    const Text('Version History', style: TextStyle(fontWeight: FontWeight.w700)),
                    ...refreshed.profileVersions.reversed.map(
                      (version) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('v${version.version} - ${version.invoiceFormat.name}'),
                        subtitle: Text(
                          'Status: ${version.status.name} | ApprovedBy: ${version.approvedBy.isEmpty ? '-' : version.approvedBy}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
    changeReasonCtrl.dispose();
  }
}
