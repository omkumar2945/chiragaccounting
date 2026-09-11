import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/gst_workbench/services/bulk_gstr1_filing_service.dart';
import 'package:chirag_accounting/features/gst_workbench/services/gst_compliance_service.dart';

class AccountantGstWorkbenchScreen extends StatefulWidget {
  const AccountantGstWorkbenchScreen({super.key});

  @override
  State<AccountantGstWorkbenchScreen> createState() =>
      _AccountantGstWorkbenchScreenState();
}

class _AccountantGstWorkbenchScreenState
    extends State<AccountantGstWorkbenchScreen> {
  static const _navy = Color(0xFF142033);
  static const _blue = Color(0xFF155EEF);
  static const _border = Color(0xFFDDE3EC);
  static const _canvas = Color(0xFFF3F6FA);

  static const _sections = <_GstSection>[
    _GstSection('GST Dashboard', Icons.dashboard_outlined),
    _GstSection('Client GSTIN Manager', Icons.business_outlined),
    _GstSection('Return Calendar', Icons.calendar_month_outlined),
    _GstSection('GSTR-1', Icons.receipt_long_outlined),
    _GstSection('GSTR-1A', Icons.edit_note_outlined),
    _GstSection('GSTR-3B', Icons.calculate_outlined),
    _GstSection('GSTR-2A', Icons.download_outlined),
    _GstSection('GSTR-2B', Icons.fact_check_outlined),
    _GstSection('IMS / Purchase Matching', Icons.rule_folder_outlined),
    _GstSection('Purchase Pull', Icons.cloud_download_outlined),
    _GstSection('B2B Reconciliation', Icons.compare_arrows_outlined),
    _GstSection('B2C Reconciliation', Icons.compare_outlined),
    _GstSection('ITC Reconciliation', Icons.account_balance_wallet_outlined),
    _GstSection('Sales Reconciliation', Icons.point_of_sale_outlined),
    _GstSection('Credit/Debit Note Reconciliation', Icons.note_alt_outlined),
    _GstSection('GSTR-9', Icons.event_note_outlined),
    _GstSection('GSTR-9C', Icons.verified_outlined),
    _GstSection('Other GST Returns', Icons.library_books_outlined),
    _GstSection('Bulk Push', Icons.cloud_upload_outlined),
    _GstSection('Bulk Pull', Icons.downloading_outlined),
    _GstSection('Filing Queue', Icons.queue_outlined),
    _GstSection('Filed Returns', Icons.task_alt_outlined),
    _GstSection('GST Notices / Communications', Icons.notifications_outlined),
    _GstSection('GST Reports', Icons.analytics_outlined),
    _GstSection('GST Audit Log', Icons.history_outlined),
    _GstSection('GST Settings', Icons.settings_outlined),
  ];

  static const _clients = <_ClientContext>[
    _ClientContext(
      id: 'client-abc',
      name: 'ABC PRIVATE LIMITED',
      gstin: '27ABCDE1234F1Z5',
      state: 'Maharashtra',
    ),
    _ClientContext(
      id: 'client-xyz',
      name: 'XYZ TRADING LLP',
      gstin: '24AAACX4321D1Z8',
      state: 'Gujarat',
    ),
    _ClientContext(
      id: 'client-pqr',
      name: 'PQR INDUSTRIES',
      gstin: '29AAECP6789L1Z2',
      state: 'Karnataka',
    ),
  ];

  static const _queue = <_QueueRow>[
    _QueueRow('ABC Pvt Ltd', '27ABCDE1234F1Z5', 'GSTR-1', 'Aug-26', 'Ready'),
    _QueueRow(
      'XYZ Trading LLP',
      '24AAACX4321D1Z8',
      'GSTR-3B',
      'Aug-26',
      'Mismatch',
    ),
    _QueueRow(
      'PQR Industries',
      '29AAECP6789L1Z2',
      'GSTR-2B',
      'Aug-26',
      'Pulled',
    ),
    _QueueRow('ABC Pvt Ltd', '27ABCDE1234F1Z5', 'GSTR-3B', 'Jul-26', 'Filed'),
  ];

  String _selectedSection = _sections.first.label;
  String _financialYear = '2026-27';
  String _period = 'Aug-2026';
  String _returnType = 'All Returns';
  _ClientContext _client = _clients.first;
  final BulkGstr1FilingService _bulkGstr1FilingService =
      BulkGstr1FilingService();
  final GstComplianceService _gstComplianceService = GstComplianceService();
  final Set<String> _selectedBulkClientIds = <String>{};
  final Map<String, BulkGstr1FilingResult> _bulkFilingResults =
      <String, BulkGstr1FilingResult>{};
  bool _isBulkFiling = false;
  bool _isRunningComplianceOperation = false;
  String? _complianceMessage;

  static const Map<String, _ComplianceModule>
  _complianceModules = <String, _ComplianceModule>{
    'Client GSTIN Manager': _ComplianceModule(
      operation: 'return-status',
      actionLabel: 'Check GST Return Status',
      description: 'Fetch the selected client GSTIN return status from GSTZen.',
    ),
    'Return Calendar': _ComplianceModule(
      operation: 'return-status',
      actionLabel: 'Refresh Return Calendar',
      description:
          'Load the selected client return status and filing calendar.',
    ),
    'GSTR-1': _ComplianceModule(
      operation: 'gstr1-download',
      actionLabel: 'Fetch GSTR-1',
      description: 'Download the selected client GSTR-1 data for review.',
    ),
    'GSTR-1A': _ComplianceModule(
      operation: 'gstr1a-download',
      actionLabel: 'Fetch GSTR-1A',
      description: 'Download the selected client GSTR-1A data for review.',
    ),
    'GSTR-3B': _ComplianceModule(
      operation: 'gstr3b-summary',
      actionLabel: 'Fetch GSTR-3B Summary',
      description: 'Load the GSTZen GSTR-3B summary for the selected client.',
    ),
    'GSTR-2A': _ComplianceModule(
      operation: 'gstr2-b2b',
      actionLabel: 'Fetch GSTR-2A B2B',
      description: 'Load supplier B2B invoices available from GSTZen.',
    ),
    'GSTR-2B': _ComplianceModule(
      operation: 'gstr2-2b',
      actionLabel: 'Fetch GSTR-2B',
      description: 'Load the selected client GSTR-2B data for matching.',
    ),
    'IMS / Purchase Matching': _ComplianceModule(
      operation: 'ims',
      actionLabel: 'Fetch IMS',
      description: 'Load Invoice Management System data for purchase matching.',
    ),
    'Purchase Pull': _ComplianceModule(
      operation: 'post-purchase-data',
      actionLabel: 'Sync Purchase Data',
      description: 'Synchronize selected client purchase data through GSTZen.',
      requiresConfirmation: true,
    ),
    'B2B Reconciliation': _ComplianceModule(
      operation: 'reconciliation-status',
      actionLabel: 'Check B2B Reconciliation',
      description: 'Retrieve the current GSTZen reconciliation status.',
    ),
    'B2C Reconciliation': _ComplianceModule(
      operation: 'reconciliation-status',
      actionLabel: 'Check B2C Reconciliation',
      description: 'Retrieve the current GSTZen reconciliation status.',
    ),
    'ITC Reconciliation': _ComplianceModule(
      operation: 'reconciliation-status',
      actionLabel: 'Check ITC Reconciliation',
      description: 'Retrieve the current GSTZen reconciliation status.',
    ),
    'Sales Reconciliation': _ComplianceModule(
      operation: 'reconciliation-status',
      actionLabel: 'Check Sales Reconciliation',
      description: 'Retrieve the current GSTZen reconciliation status.',
    ),
    'Credit/Debit Note Reconciliation': _ComplianceModule(
      operation: 'reconciliation-status',
      actionLabel: 'Check Note Reconciliation',
      description: 'Retrieve the current GSTZen reconciliation status.',
    ),
    'Bulk Pull': _ComplianceModule(
      operation: 'gstr1-download',
      actionLabel: 'Pull Selected GSTIN',
      description:
          'Pull GST return data for the selected client before review.',
    ),
    'Filing Queue': _ComplianceModule(
      operation: 'return-status',
      actionLabel: 'Refresh Filing Status',
      description: 'Refresh the selected client filing status from GSTZen.',
    ),
    'Filed Returns': _ComplianceModule(
      operation: 'return-status',
      actionLabel: 'Fetch Filed Returns',
      description: 'Retrieve filed-return status for the selected client.',
    ),
    'GST Reports': _ComplianceModule(
      operation: 'reconciliation-status',
      actionLabel: 'Refresh GST Report Data',
      description: 'Load current GSTZen reconciliation data for reporting.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return Column(
            children: [
              _contextBar(wide),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) _sectionNavigation(),
                    Expanded(
                      child: _selectedSection == 'GST Dashboard'
                          ? _dashboard()
                          : _selectedSection == 'Bulk Push'
                          ? _bulkGstr1FilingWorkspace()
                          : _complianceModules.containsKey(_selectedSection)
                          ? _complianceWorkspace(
                              _complianceModules[_selectedSection]!,
                            )
                          : _modulePlaceholder(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contextBar(bool wide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: _blue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GST-PORTAL WORK',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Multi-client compliance and filing command center',
                      style: TextStyle(color: Color(0xFF667085), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (wide) _clientSwitcher(),
            ],
          ),
          if (!wide) ...[
            const SizedBox(height: 10),
            _clientSwitcher(),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('gst-mobile-section-selector'),
              initialValue: _selectedSection,
              isExpanded: true,
              decoration: _inputDecoration('Module'),
              items: [
                for (final section in _sections)
                  DropdownMenuItem(
                    value: section.label,
                    child: Text(section.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedSection = value);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _clientSwitcher() {
    return SizedBox(
      width: 310,
      child: DropdownButtonFormField<String>(
        key: const ValueKey('gst-client-switcher'),
        initialValue: _client.id,
        isExpanded: true,
        decoration: _inputDecoration('Client'),
        items: [
          for (final client in _clients)
            DropdownMenuItem(
              value: client.id,
              child: Text(client.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _client = _clients.firstWhere((client) => client.id == value);
          });
        },
      ),
    );
  }

  Widget _sectionNavigation() {
    return Container(
      width: 230,
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text(
              'GST WORK MODULES',
              style: TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final section in _sections)
            Material(
              color: _selectedSection == section.label
                  ? const Color(0xFFE8F0FF)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: ListTile(
                key: ValueKey('gst-section-${section.label}'),
                dense: true,
                minLeadingWidth: 22,
                horizontalTitleGap: 8,
                leading: Icon(
                  section.icon,
                  size: 18,
                  color: _selectedSection == section.label
                      ? _blue
                      : const Color(0xFF667085),
                ),
                title: Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: _selectedSection == section.label
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _selectedSection == section.label ? _blue : _navy,
                  ),
                ),
                onTap: () => setState(() => _selectedSection = section.label),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dashboard() {
    return ListView(
      key: const ValueKey('gst-dashboard-content'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
      children: [
        Text(
          '${_client.name} | ${_client.gstin} | ${_client.state}',
          key: const ValueKey('gst-active-context'),
          style: const TextStyle(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _filters(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 5
                : constraints.maxWidth >= 700
                ? 3
                : 2;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: const [
                _Kpi('Total Clients', '125', Color(0xFF155EEF)),
                _Kpi('GSTINs', '139', Color(0xFF155EEF)),
                _Kpi('Returns Due', '18', Color(0xFFF79009)),
                _Kpi('Returns Prepared', '42', Color(0xFF0E9384)),
                _Kpi('Pending Review', '7', Color(0xFFF79009)),
                _Kpi('Returns Filed', '104', Color(0xFF039855)),
                _Kpi('Nil Returns', '9', Color(0xFF667085)),
                _Kpi('Late Returns', '3', Color(0xFFD92D20)),
                _Kpi('B2B Mismatch', '37', Color(0xFFD92D20)),
                _Kpi('Purchase Mismatch', '21', Color(0xFFD92D20)),
                _Kpi('ITC Difference', 'INR 1.26 L', Color(0xFFD92D20)),
                _Kpi('Tax Payable', 'INR 4.82 L', Color(0xFFB54708)),
                _Kpi('ITC Available', 'INR 8.14 L', Color(0xFF039855)),
              ].map((item) => SizedBox(width: width, child: item)).toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        _quickActions(),
        const SizedBox(height: 14),
        _workQueue(),
      ],
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filter(
          'Financial Year',
          _financialYear,
          const ['2025-26', '2026-27'],
          (value) => setState(() => _financialYear = value),
        ),
        _filter('Return Period', _period, const [
          'Jul-2026',
          'Aug-2026',
          'Sep-2026',
        ], (value) => setState(() => _period = value)),
        _filter('Return Type', _returnType, const [
          'All Returns',
          'GSTR-1',
          'GSTR-3B',
          'GSTR-2B',
        ], (value) => setState(() => _returnType = value)),
        _readOnlyFilter('GSTIN', _client.gstin),
        _readOnlyFilter('State', _client.state),
        _readOnlyFilter('Status', 'All Statuses'),
      ],
    );
  }

  Widget _filter(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return SizedBox(
      width: 168,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: _inputDecoration(label),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Widget _readOnlyFilter(String label, String value) {
    return SizedBox(
      width: 168,
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _border),
      ),
    );
  }

  Widget _quickActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => setState(() => _selectedSection = 'Bulk Pull'),
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const Text('BULK PULL'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _selectedSection = 'B2B Reconciliation'),
            icon: const Icon(Icons.compare_arrows_outlined, size: 18),
            label: const Text('BULK RECONCILE'),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _selectedSection = 'Bulk Push'),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('BULK PUSH'),
          ),
        ],
      ),
    );
  }

  Widget _workQueue() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Text(
              'GST RETURN WORK QUEUE',
              style: TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              'Portal data is staged for review and does not overwrite books.',
              style: TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('Client')),
                DataColumn(label: Text('GSTIN')),
                DataColumn(label: Text('Return')),
                DataColumn(label: Text('Period')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: [for (final row in _queue) _queueRow(row)],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _queueRow(_QueueRow row) {
    final color = switch (row.status) {
      'Filed' => const Color(0xFF039855),
      'Ready' || 'Pulled' => const Color(0xFF155EEF),
      _ => const Color(0xFFD92D20),
    };
    return DataRow(
      cells: [
        DataCell(Text(row.client)),
        DataCell(Text(row.gstin)),
        DataCell(Text(row.returnType)),
        DataCell(Text(row.period)),
        DataCell(
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(row.status, style: TextStyle(color: color)),
            ],
          ),
        ),
        DataCell(
          TextButton(
            onPressed: () => setState(() => _selectedSection = 'Filing Queue'),
            child: Text(row.status == 'Mismatch' ? 'Resolve' : 'Review'),
          ),
        ),
      ],
    );
  }

  Widget _modulePlaceholder() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _selectedSection,
          style: const TextStyle(
            color: _navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_client.name} | ${_client.gstin} | $_period',
          key: const ValueKey('gst-module-context'),
          style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          color: Colors.white,
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This module is connected to the shared GST workspace context. Operational API and reviewed workflow actions are delivered in the module phase defined in the implementation plan.',
                  style: TextStyle(color: Color(0xFF475467), height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runComplianceOperation(_ComplianceModule module) async {
    if (module.requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${module.actionLabel}?'),
          content: const Text(
            'This action sends data to GSTZen for the selected client. Continue only after review.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isRunningComplianceOperation = true;
      _complianceMessage = null;
    });
    try {
      final result = await _gstComplianceService.execute(
        operation: module.operation,
        gstin: _client.gstin,
        returnPeriod: _period,
        clientId: _client.id,
      );
      if (!mounted) return;
      setState(() => _complianceMessage = result.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _complianceMessage = 'GSTZen request failed: $error');
    } finally {
      if (mounted) setState(() => _isRunningComplianceOperation = false);
    }
  }

  Widget _complianceWorkspace(_ComplianceModule module) {
    return ListView(
      key: ValueKey('gst-compliance-${module.operation}'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _selectedSection,
          style: const TextStyle(
            color: _navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_client.name} | ${_client.gstin} | $_period',
          style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module.description,
                style: const TextStyle(color: Color(0xFF475467)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: ValueKey('gstzen-${module.operation}-action'),
                onPressed: _isRunningComplianceOperation
                    ? null
                    : () => _runComplianceOperation(module),
                icon: _isRunningComplianceOperation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
                label: Text(
                  _isRunningComplianceOperation
                      ? 'Contacting GSTZen...'
                      : module.actionLabel,
                ),
              ),
              if (_complianceMessage != null) ...[
                const SizedBox(height: 14),
                SelectableText(
                  _complianceMessage!,
                  style: const TextStyle(color: Color(0xFF344054)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<_BulkFilingClient> _bulkFilingClients(BuildContext context) {
    final adminUsers = context.watch<AdminUserService>();
    return adminUsers.users
        .where((user) => user.role.isClient && user.isActive)
        .map((user) {
          final compliance = adminUsers.complianceFor(user.id);
          return _BulkFilingClient(
            id: user.id,
            name: user.firmName.trim().isNotEmpty ? user.firmName : user.name,
            gstin: compliance.gstin.trim().toUpperCase(),
          );
        })
        .where((client) => RegExp(r'^[0-9A-Z]{15}$').hasMatch(client.gstin))
        .toList(growable: false);
  }

  Future<void> _fileSelectedGstr1Returns(
    List<_BulkFilingClient> clients,
  ) async {
    final selectedClients = clients
        .where((client) => _selectedBulkClientIds.contains(client.id))
        .toList(growable: false);
    if (selectedClients.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('File selected GSTR-1 returns?'),
        content: Text(
          '${selectedClients.length} client return(s) for $_period will be sent to the GST portal. Each client result will be recorded separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('File Returns'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBulkFiling = true);
    try {
      final results = await _bulkGstr1FilingService.fileReturns([
        for (final client in selectedClients)
          BulkGstr1FilingRequest(
            clientId: client.id,
            gstin: client.gstin,
            returnPeriod: _period,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        for (final result in results) {
          _bulkFilingResults[result.clientId] = result;
        }
        _selectedBulkClientIds.clear();
      });
      final filedCount = results.where((result) => result.isFiled).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$filedCount of ${results.length} GSTR-1 return(s) filed.',
          ),
          backgroundColor: filedCount == results.length
              ? const Color(0xFF039855)
              : const Color(0xFFB54708),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk filing could not be started: $error'),
          backgroundColor: const Color(0xFFD92D20),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBulkFiling = false);
    }
  }

  Widget _bulkGstr1FilingWorkspace() {
    final clients = _bulkFilingClients(context);
    return ListView(
      key: const ValueKey('bulk-gstr1-filing-workspace'),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Bulk GSTR-1 Filing',
          style: TextStyle(
            color: _navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Select prepared client returns and file them together. Filing status is returned separately for every GSTIN.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.white,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextFormField(
                  initialValue: _period,
                  decoration: _inputDecoration('Return Period'),
                  onChanged: (value) => setState(() => _period = value.trim()),
                ),
              ),
              Text('${_selectedBulkClientIds.length} selected'),
              FilledButton.icon(
                key: const ValueKey('bulk-gstr1-file-selected'),
                onPressed: _isBulkFiling || _selectedBulkClientIds.isEmpty
                    ? null
                    : () => _fileSelectedGstr1Returns(clients),
                icon: _isBulkFiling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isBulkFiling ? 'Filing...' : 'File Selected GSTR-1',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (clients.isEmpty)
          const _EmptyBulkFilingState()
        else
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Select')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('GSTIN')),
                  DataColumn(label: Text('Return')),
                  DataColumn(label: Text('Result')),
                ],
                rows: [for (final client in clients) _bulkFilingRow(client)],
              ),
            ),
          ),
      ],
    );
  }

  DataRow _bulkFilingRow(_BulkFilingClient client) {
    final result = _bulkFilingResults[client.id];
    final statusColor = result == null
        ? const Color(0xFF667085)
        : result.isFiled
        ? const Color(0xFF039855)
        : const Color(0xFFD92D20);
    final status = result == null
        ? 'Ready'
        : result.isFiled
        ? 'Filed'
        : result.error ?? 'Failed';
    return DataRow(
      cells: [
        DataCell(
          Checkbox(
            value: _selectedBulkClientIds.contains(client.id),
            onChanged: _isBulkFiling
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _selectedBulkClientIds.add(client.id);
                    } else {
                      _selectedBulkClientIds.remove(client.id);
                    }
                  }),
          ),
        ),
        DataCell(Text(client.name)),
        DataCell(Text(client.gstin)),
        const DataCell(Text('GSTR-1')),
        DataCell(Text(status, style: TextStyle(color: statusColor))),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFDDE3EC))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GstSection {
  const _GstSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ClientContext {
  const _ClientContext({
    required this.id,
    required this.name,
    required this.gstin,
    required this.state,
  });

  final String id;
  final String name;
  final String gstin;
  final String state;
}

class _QueueRow {
  const _QueueRow(
    this.client,
    this.gstin,
    this.returnType,
    this.period,
    this.status,
  );

  final String client;
  final String gstin;
  final String returnType;
  final String period;
  final String status;
}

class _ComplianceModule {
  const _ComplianceModule({
    required this.operation,
    required this.actionLabel,
    required this.description,
    this.requiresConfirmation = false,
  });

  final String operation;
  final String actionLabel;
  final String description;
  final bool requiresConfirmation;
}

class _BulkFilingClient {
  const _BulkFilingClient({
    required this.id,
    required this.name,
    required this.gstin,
  });

  final String id;
  final String name;
  final String gstin;
}

class _EmptyBulkFilingState extends StatelessWidget {
  const _EmptyBulkFilingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: const Text(
        'No active client has a configured GSTIN. Add each client GSTIN in Admin Client Compliance before starting bulk GSTR-1 filing.',
        style: TextStyle(color: Color(0xFF667085)),
      ),
    );
  }
}
