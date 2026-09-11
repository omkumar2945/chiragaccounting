import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/integrations/integration_hub_service.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/gst_scrutiny/services/gst_scrutiny_pack_service.dart';
import 'package:chirag_accounting/features/gst_scrutiny/services/gst_scrutiny_service.dart';
import 'package:chirag_accounting/features/gst_library/presentation/pages/gst_library_screen.dart';
import 'package:chirag_accounting/features/gst_library/services/gst_library_service.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

class GstScrutinyCenterScreen extends StatefulWidget {
  const GstScrutinyCenterScreen({super.key});

  @override
  State<GstScrutinyCenterScreen> createState() =>
      _GstScrutinyCenterScreenState();
}

class _GstScrutinyCenterScreenState extends State<GstScrutinyCenterScreen> {
  String? _clientId;

  @override
  Widget build(BuildContext context) {
    final clients = context
        .watch<AdminUserService>()
        .users
        .where((user) => user.role.isClient)
        .toList(growable: false);
    if (_clientId != null && !clients.any((client) => client.id == _clientId)) {
      _clientId = null;
    }
    final selectedClient = _clientId == null
        ? null
        : clients.firstWhere((client) => client.id == _clientId);
    final cases = selectedClient == null
        ? const <GstScrutinyCase>[]
        : context.watch<GstScrutinyService>().casesFor(selectedClient.id);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F7),
      appBar: AppBar(
        title: const Text('GST Scrutiny / E-Scrutiny'),
        backgroundColor: const Color(0xFF174C4F),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: selectedClient == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _CreateScrutinyCaseScreen(client: selectedClient),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New notice'),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Officer notice preparation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          const Text(
            'Prepare point-wise replies, evidence reports and voucher soft-copy packs. Portal-source gaps remain visible until supplied.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _clientId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Client',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business_outlined),
            ),
            items: clients
                .map(
                  (client) => DropdownMenuItem(
                    value: client.id,
                    child: Text(
                      client.firmName.isEmpty ? client.name : client.firmName,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _clientId = value),
          ),
          const SizedBox(height: 18),
          if (selectedClient == null)
            const _MessagePanel(
              icon: Icons.apartment_outlined,
              message:
                  'Select a client to prepare or review a GST notice response.',
            )
          else if (cases.isEmpty)
            const _MessagePanel(
              icon: Icons.mark_email_unread_outlined,
              message: 'No GST scrutiny case exists for this client.',
            )
          else
            ...cases.reversed.map(
              (scrutinyCase) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Icon(
                    scrutinyCase.hasMissingSourceData
                        ? Icons.warning_amber_outlined
                        : Icons.fact_check_outlined,
                    color: scrutinyCase.hasMissingSourceData
                        ? Colors.orange.shade800
                        : Colors.green.shade700,
                  ),
                  title: Text(scrutinyCase.noticeNumber),
                  subtitle: Text(
                    '${scrutinyCase.section} | ${scrutinyCase.taxPeriod}\nDue ${DateFormat('dd MMM yyyy').format(scrutinyCase.dueDate)} | ${scrutinyCase.status.name}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ScrutinyCaseDetailScreen(
                        caseId: scrutinyCase.id,
                        client: selectedClient,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD9E2E3)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 38, color: const Color(0xFF467477)),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _CreateScrutinyCaseScreen extends StatefulWidget {
  const _CreateScrutinyCaseScreen({required this.client});

  final UserModel client;

  @override
  State<_CreateScrutinyCaseScreen> createState() =>
      _CreateScrutinyCaseScreenState();
}

class _CreateScrutinyCaseScreenState extends State<_CreateScrutinyCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notice = TextEditingController();
  final _section = TextEditingController(text: 'Section 61');
  final _period = TextEditingController();
  final _officerEmail = TextEditingController();
  final _queries = TextEditingController();
  DateTime _noticeDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  final Set<String> _portalSources = <String>{};
  final Set<String> _legalReferences = <String>{};
  bool _saving = false;

  static const Map<String, String> _sourceLabels = <String, String>{
    'tax-liability': 'GSTR-3B data',
    'itc-register': 'GSTR-2B data',
    'challan-summary': 'Challans',
    'electronic-ledgers': 'Electronic ledgers',
    'eway-einvoice': 'E-way / e-invoice data',
    'annual-reconciliation': 'Annual return data',
  };

  @override
  void dispose() {
    _notice.dispose();
    _section.dispose();
    _period.dispose();
    _officerEmail.dispose();
    _queries.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New GST Notice Case')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.client.firmName.isEmpty
                ? widget.client.name
                : widget.client.firmName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _field(_notice, 'Notice number'),
          _field(_section, 'Section / form'),
          _field(_period, 'Tax period'),
          _field(_officerEmail, 'GST officer email', required: false),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              if (compact) {
                return Column(
                  children: [
                    _dateButton('Notice date', _noticeDate, true),
                    const SizedBox(height: 10),
                    _dateButton('Reply due date', _dueDate, false),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _dateButton('Notice date', _noticeDate, true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateButton('Reply due date', _dueDate, false),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _queries,
            minLines: 5,
            maxLines: 9,
            decoration: const InputDecoration(
              labelText: 'Officer enquiries / discrepancies',
              helperText: 'Enter one query per line.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.trim().isEmpty ?? true
                ? 'Add at least one officer query.'
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            'GST portal sources available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _sourceLabels.entries
                .map(
                  (entry) => FilterChip(
                    label: Text(entry.value),
                    selected: _portalSources.contains(entry.key),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _portalSources.add(entry.key);
                      } else {
                        _portalSources.remove(entry.key);
                      }
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Legal references (${_legalReferences.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _selectLegalReference,
                      icon: const Icon(Icons.library_books_outlined),
                      label: const Text('Add from GST Library'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Legal references (${_legalReferences.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectLegalReference,
                    icon: const Icon(Icons.library_books_outlined),
                    label: const Text('Add from GST Library'),
                  ),
                ],
              );
            },
          ),
          if (_legalReferences.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _legalReferences
                  .map((id) {
                    final section = context
                        .read<GstLibraryService>()
                        .sectionById(id);
                    return InputChip(
                      label: Text(section?.displayName ?? id),
                      onDeleted: () =>
                          setState(() => _legalReferences.remove(id)),
                    );
                  })
                  .toList(growable: false),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _saving ? 'Preparing...' : 'Prepare reports and reply draft',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) =>
                value?.trim().isEmpty ?? true ? '$label is required.' : null
          : null,
    ),
  );

  Widget _dateButton(String label, DateTime value, bool noticeDate) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size(double.infinity, 52),
        ),
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2200),
            initialDate: value,
          );
          if (date == null) return;
          setState(() {
            if (noticeDate) {
              _noticeDate = date;
            } else {
              _dueDate = date;
            }
          });
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text('$label\n${DateFormat('dd MMM yyyy').format(value)}'),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<GstScrutinyService>().createCase(
        clientId: widget.client.id,
        noticeNumber: _notice.text,
        noticeDate: _noticeDate,
        section: _section.text,
        taxPeriod: _period.text,
        dueDate: _dueDate,
        officerEmail: _officerEmail.text,
        createdBy: context.read<AuthController>().currentUser?.id ?? 'admin',
        enquiryTexts: _queries.text.split('\n'),
        availablePortalSources: _portalSources,
        legalReferenceIds: _legalReferences.toList(growable: false),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectLegalReference() async {
    final referenceId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const GstLibraryScreen(selectionMode: true),
      ),
    );
    if (referenceId != null && mounted) {
      setState(() => _legalReferences.add(referenceId));
    }
  }
}

class _ScrutinyCaseDetailScreen extends StatelessWidget {
  const _ScrutinyCaseDetailScreen({required this.caseId, required this.client});

  final String caseId;
  final UserModel client;

  @override
  Widget build(BuildContext context) {
    final scrutinyCase = context
        .watch<GstScrutinyService>()
        .casesFor(client.id)
        .firstWhere((item) => item.id == caseId);
    return Scaffold(
      appBar: AppBar(
        title: Text(scrutinyCase.noticeNumber),
        actions: [
          IconButton(
            tooltip: 'Download preparation ZIP',
            icon: const Icon(Icons.download_outlined),
            onPressed: () =>
                _preparePack(context, scrutinyCase, sendEmail: false),
          ),
          IconButton(
            tooltip: 'Email reviewed reply and pack',
            icon: const Icon(Icons.send_outlined),
            onPressed: () =>
                _preparePack(context, scrutinyCase, sendEmail: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Officer enquiries',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...scrutinyCase.enquiries.map(
            (enquiry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: Text(enquiry.query),
              subtitle: Text(
                enquiry.response.isEmpty
                    ? 'Response pending review'
                    : enquiry.response,
              ),
            ),
          ),
          const Divider(height: 28),
          Text(
            'Requested reports',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...scrutinyCase.reports.map(
            (report) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                report.status == GstScrutinyReportStatus.ready
                    ? Icons.check_circle_outline
                    : Icons.cloud_upload_outlined,
                color: report.status == GstScrutinyReportStatus.ready
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
              title: Text(report.title),
              subtitle: report.sourceNote.isEmpty
                  ? null
                  : Text(report.sourceNote),
            ),
          ),
          if (scrutinyCase.legalReferenceIds.isNotEmpty) ...[
            const Divider(height: 28),
            Text(
              'GST Act references',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...scrutinyCase.legalReferenceIds.map((id) {
              final section = context.read<GstLibraryService>().sectionById(id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gavel_outlined),
                title: Text(section?.displayName ?? id),
                subtitle: Text(section?.summary ?? 'Reference unavailable.'),
              );
            }),
          ],
          const Divider(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Suggested notice reply',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Chip(label: Text(scrutinyCase.reply.status.name)),
              IconButton(
                tooltip: 'Review and approve reply',
                icon: const Icon(Icons.rate_review_outlined),
                onPressed: () => _reviewReply(context, scrutinyCase),
              ),
            ],
          ),
          SelectableText(scrutinyCase.reply.body),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _reviewReply(
    BuildContext context,
    GstScrutinyCase scrutinyCase,
  ) async {
    final controller = TextEditingController(text: scrutinyCase.reply.body);
    final reviewed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review notice reply'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: TextField(
            controller: controller,
            minLines: 12,
            maxLines: 20,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              helperText:
                  'Confirm facts, figures, legal position and referenced evidence.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Mark reviewed'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reviewed == null || !context.mounted) return;
    await context.read<GstScrutinyService>().reviewReply(
      caseId: scrutinyCase.id,
      reviewedBody: reviewed,
      reviewedBy: context.read<AuthController>().currentUser?.id ?? 'admin',
    );
  }

  Future<void> _preparePack(
    BuildContext context,
    GstScrutinyCase scrutinyCase, {
    required bool sendEmail,
  }) async {
    final options = await showDialog<_PackOptions>(
      context: context,
      builder: (_) => _PackOptionsDialog(
        initialFrom: scrutinyCase.noticeDate,
        initialTo: scrutinyCase.dueDate,
      ),
    );
    if (options == null || !context.mounted) return;
    try {
      const packService = GstScrutinyPackService();
      final result = await packService.export(
        scrutinyCase: scrutinyCase,
        clientName: client.firmName.isEmpty ? client.name : client.firmName,
        from: options.from,
        to: options.to,
        voucherTypes: options.voucherTypes,
        salesInvoices: context.read<SalesService>().invoices,
        purchaseBills: context.read<PurchaseService>().bills,
      );
      if (sendEmail) {
        await packService.email(
          integrationHub: context.read<IntegrationHubService>(),
          scrutinyCase: scrutinyCase,
          pack: result,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sendEmail
                ? 'Reviewed reply and preparation pack submitted to the email provider.'
                : 'Preparation ZIP saved: ${result.savedPath}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }
}

class _PackOptions {
  const _PackOptions({
    required this.from,
    required this.to,
    required this.voucherTypes,
  });

  final DateTime from;
  final DateTime to;
  final Set<String> voucherTypes;
}

class _PackOptionsDialog extends StatefulWidget {
  const _PackOptionsDialog({
    required this.initialFrom,
    required this.initialTo,
  });

  final DateTime initialFrom;
  final DateTime initialTo;

  @override
  State<_PackOptionsDialog> createState() => _PackOptionsDialogState();
}

class _PackOptionsDialogState extends State<_PackOptionsDialog> {
  late DateTime _from = widget.initialFrom;
  late DateTime _to = widget.initialTo;
  final Set<String> _types = <String>{'sales', 'purchase'};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Voucher soft-copy filter'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('From date'),
          trailing: Text(DateFormat('dd MMM yyyy').format(_from)),
          onTap: () => _pickDate(true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('To date'),
          trailing: Text(DateFormat('dd MMM yyyy').format(_to)),
          onTap: () => _pickDate(false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _types.contains('sales'),
          title: const Text('Sales vouchers'),
          onChanged: (value) => setState(() {
            value == true ? _types.add('sales') : _types.remove('sales');
          }),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _types.contains('purchase'),
          title: const Text('Purchase vouchers'),
          onChanged: (value) => setState(() {
            value == true ? _types.add('purchase') : _types.remove('purchase');
          }),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _types.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _PackOptions(
                  from: _from,
                  to: _to,
                  voucherTypes: Set.of(_types),
                ),
              ),
        child: const Text('Prepare pack'),
      ),
    ],
  );

  Future<void> _pickDate(bool from) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      initialDate: from ? _from : _to,
    );
    if (date == null) return;
    setState(() => from ? _from = date : _to = date);
  }
}
