import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/models/tally_sync_settings.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class TallySyncManagementScreen extends StatefulWidget {
  const TallySyncManagementScreen({super.key});

  @override
  State<TallySyncManagementScreen> createState() =>
      _TallySyncManagementScreenState();
}

class _TallySyncManagementScreenState extends State<TallySyncManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _endpointController = TextEditingController();
  final _companyController = TextEditingController();

  String? _selectedClientId;
  bool _enabled = false;
  bool _autoSyncEnabled = false;
  final Map<TallySyncModule, TallySyncDirection> _moduleDirections =
      <TallySyncModule, TallySyncDirection>{};
  bool _allowTallyDeletions = false;
  bool _confirmBeforeManualSync = true;
  DateTime? _fromDate;
  DateTime? _toDate;
  int _intervalMinutes = 15;
  TallySyncDirection _direction = TallySyncDirection.chiragToTally;
  TallyConflictPolicy _masterPolicy = TallyConflictPolicy.skipDuplicate;
  TallyConflictPolicy _voucherPolicy = TallyConflictPolicy.skipDuplicate;
  bool _saving = false;
  bool _syncing = false;
  bool _testingConnection = false;

  List<String> _enteredCompanyNames() => _companyController.text
      .split(RegExp(r'[,\n]'))
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList(growable: false);

  @override
  void dispose() {
    _endpointController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  List<UserModel> _visibleClients(
    AdminUserService directory,
    UserModel? currentUser,
  ) {
    final clients =
        directory.users
            .where((user) => user.role.isClient && user.isActive)
            .toList(growable: false)
          ..sort((left, right) => left.firmName.compareTo(right.firmName));
    if (currentUser?.role != UserRole.accountant) return clients;
    return clients
        .where(
          (client) =>
              directory.accountingAccessFor(client.id).assignedAccountantId ==
              currentUser!.id,
        )
        .toList(growable: false);
  }

  void _selectClient(String clientId, AdminUserService directory) {
    final settings = directory.tallySyncFor(clientId);
    setState(() {
      _selectedClientId = clientId;
      _endpointController.text = settings.endpoint;
      _companyController.text = settings.selectedCompanyNames.join('\n');
      _enabled = settings.enabled;
      _autoSyncEnabled = settings.autoSyncEnabled;
      _moduleDirections
        ..clear()
        ..addEntries(
          TallySyncModule.values
              .where(
                (module) =>
                    settings.effectiveModuleDirections.containsKey(module.name),
              )
              .map(
                (module) => MapEntry(
                  module,
                  settings.effectiveModuleDirections[module.name]!,
                ),
              ),
        );
      _allowTallyDeletions = settings.allowTallyDeletions;
      _confirmBeforeManualSync = settings.confirmBeforeManualSync;
      _fromDate = settings.fromDate;
      _toDate = settings.toDate;
      _intervalMinutes = settings.intervalMinutes;
      _direction = settings.direction;
      _masterPolicy = settings.masterConflictPolicy;
      _voucherPolicy = settings.voucherConflictPolicy;
    });
    _loadHistory(clientId);
  }

  Future<void> _loadHistory(String clientId) async {
    try {
      await context.read<AdminUserService>().loadTallySyncHistory(clientId);
    } catch (_) {}
  }

  TallySyncSettings _settings(AdminUserService directory) {
    final clientId = _selectedClientId!;
    final current = directory.tallySyncFor(clientId);
    bool includesGroup(TallySyncModuleGroup group) =>
        _moduleDirections.keys.any((module) => module.group == group);
    return current.copyWith(
      enabled: _enabled,
      autoSyncEnabled: _autoSyncEnabled,
      endpoint: _endpointController.text,
      companyName: _enteredCompanyNames().firstOrNull ?? '',
      companyNames: _enteredCompanyNames(),
      direction: _direction,
      masterConflictPolicy: _masterPolicy,
      voucherConflictPolicy: _voucherPolicy,
      syncMasters: includesGroup(TallySyncModuleGroup.masters),
      syncVouchers: includesGroup(TallySyncModuleGroup.vouchers),
      syncInventory: includesGroup(TallySyncModuleGroup.inventory),
      moduleDirections: <String, TallySyncDirection>{
        for (final entry in _moduleDirections.entries)
          entry.key.name: entry.value,
      },
      allowTallyDeletions: _allowTallyDeletions,
      confirmBeforeManualSync: _confirmBeforeManualSync,
      fromDate: _fromDate,
      clearFromDate: _fromDate == null,
      toDate: _toDate,
      clearToDate: _toDate == null,
      intervalMinutes: _intervalMinutes,
    );
  }

  Future<bool> _save({bool showSuccess = true}) async {
    if (_selectedClientId == null ||
        _formKey.currentState?.validate() != true) {
      return false;
    }
    setState(() => _saving = true);
    try {
      await context.read<AdminUserService>().configureTallySync(
        _settings(context.read<AdminUserService>()),
      );
      if (!mounted) return false;
      if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tally Sync settings saved.')),
        );
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectDate({required bool from}) async {
    final initialDate = from
        ? _fromDate ?? DateTime(DateTime.now().year, 4, 1)
        : _toDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
    });
  }

  Future<bool> _confirmTransfer(
    TallySyncSettings settings, {
    required bool initialImport,
  }) async {
    if (!settings.confirmBeforeManualSync) return true;
    final direction = initialImport
        ? TallySyncDirection.tallyToChirag.displayName
        : settings.direction.displayName;
    final dateRange = settings.fromDate == null
        ? 'All available dates'
        : '${DateFormat('dd MMM yyyy').format(settings.fromDate!)} to ${DateFormat('dd MMM yyyy').format(settings.toDate!)}';
    final selectedModules = TallySyncModule.values
        .where(
          (module) =>
              settings.effectiveModuleDirections.containsKey(module.name),
        )
        .map((module) => module.displayName)
        .join(', ');
    final selectedCompanies = settings.selectedCompanyNames.join(', ');
    return await showMovableDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              initialImport ? 'Confirm Initial Import' : 'Confirm Tally Sync',
            ),
            content: Text(
              'Companies: $selectedCompanies\nDirection: $direction\nDate range: $dateRange\nData selected: $selectedModules\n\nReview these details before transferring data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(initialImport ? 'Import from Tally' : 'Start Sync'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runSync({bool initialImport = false}) async {
    if (_selectedClientId == null) return;
    if (!await _save(showSuccess: false)) return;
    if (!mounted) return;
    final saved = context.read<AdminUserService>().tallySyncFor(
      _selectedClientId!,
    );
    if (!saved.enabled) return;
    if (!await _confirmTransfer(saved, initialImport: initialImport)) return;

    setState(() => _syncing = true);
    try {
      final directory = context.read<AdminUserService>();
      if (initialImport) {
        await directory.runInitialTallyImport(_selectedClientId!);
      } else {
        await directory.runTallySync(_selectedClientId!);
      }
      await _loadHistory(_selectedClientId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialImport
                ? 'Initial Tally import completed successfully.'
                : 'Tally Sync completed successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tally Sync could not run: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _testConnection() async {
    if (_selectedClientId == null) return;
    if (!await _save(showSuccess: false) || !mounted) return;
    setState(() => _testingConnection = true);
    try {
      await context.read<AdminUserService>().testTallyConnection(
        _selectedClientId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TallyPrime connected and all companies verified.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<AdminUserService>();
    final currentUser = context.watch<AuthController>().currentUser;
    final clients = _visibleClients(directory, currentUser);
    if (_selectedClientId != null &&
        !clients.any((client) => client.id == _selectedClientId)) {
      _selectedClientId = null;
    }
    final selectedSettings = _selectedClientId == null
        ? null
        : directory.tallySyncFor(_selectedClientId!);
    final selectedHistory = _selectedClientId == null
        ? const <TallySyncHistoryEntry>[]
        : directory.tallySyncHistoryFor(_selectedClientId!);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Tally Sync'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: clients.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  currentUser?.role == UserRole.accountant
                      ? 'No clients are assigned to this accountant. Assign a client in Admin > Client Accounting Access.'
                      : 'No active client companies are available for Tally Sync.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SearchableDropdownFormField<UserModel>(
                    value: clients
                        .where((client) => client.id == _selectedClientId)
                        .firstOrNull,
                    items: clients,
                    itemLabelBuilder: (client) => client.firmName.trim().isEmpty
                        ? client.name
                        : client.firmName,
                    dialogTitle: 'Select Client Company',
                    hintText: 'Select a client company',
                    decoration: const InputDecoration(
                      labelText: 'Client Company',
                      prefixIcon: Icon(Icons.apartment_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'Select a client' : null,
                    onChanged: (value) {
                      if (value != null) _selectClient(value.id, directory);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_selectedClientId == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Select a client company to configure its Tally connection and synchronization rules.',
                        ),
                      ),
                    )
                  else ...[
                    const Text(
                      'Tally Prime Integration Center',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Control imports, exports, and two-way synchronization for each client company.',
                      style: TextStyle(color: Color(0xFF526175)),
                    ),
                    const SizedBox(height: 14),
                    _statusCard(selectedSettings!),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Connection',
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFB8D1F5)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.desktop_windows_outlined, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Local connector: keep TallyPrime open on this Windows PC, load the company, and enable its HTTP Server on port 9000. Test the connection before the first transfer.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Tally Sync'),
                          subtitle: const Text(
                            'Allow this client company to exchange data with Tally.',
                          ),
                          value: _enabled,
                          onChanged: (value) =>
                              setState(() => _enabled = value),
                        ),
                        TextFormField(
                          controller: _endpointController,
                          decoration: const InputDecoration(
                            labelText: 'Tally HTTP Endpoint',
                            hintText: 'http://127.0.0.1:9000',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final uri = Uri.tryParse(value?.trim() ?? '');
                            if (uri == null ||
                                !uri.hasScheme ||
                                (uri.scheme != 'http' &&
                                    uri.scheme != 'https')) {
                              return 'Enter a valid HTTP or HTTPS endpoint';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _companyController,
                          decoration: const InputDecoration(
                            labelText: 'Tally Company Names',
                            hintText: 'One company per line',
                            helperText:
                                'Select multiple companies by entering one per line or separating names with commas.',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 2,
                          maxLines: 4,
                          validator: (_) =>
                              _enabled && _enteredCompanyNames().isEmpty
                              ? 'Select at least one company when sync is enabled'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed:
                                _saving ||
                                    _syncing ||
                                    _testingConnection ||
                                    !_enabled
                                ? null
                                : _testConnection,
                            icon: _testingConnection
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cable_outlined),
                            label: Text(
                              _testingConnection
                                  ? 'Testing...'
                                  : 'Test Tally Connection',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Tally Pull & Sync Rules',
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFB7DCC2)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.download_outlined, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'For pulling data from Tally into Chirag, select the From Date and To Date below, then choose the masters, inventory, and voucher types to pull.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<TallySyncDirection>(
                          value: _direction,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Direction',
                            border: OutlineInputBorder(),
                          ),
                          items: TallySyncDirection.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.displayName),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _direction = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Date Range',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'This range is applied to voucher data pulled from Tally. Masters are pulled as current records.',
                          style: TextStyle(
                            color: Color(0xFF526175),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _selectDate(from: true),
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                _fromDate == null
                                    ? 'From Date'
                                    : 'From ${DateFormat('dd MMM yyyy').format(_fromDate!)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _selectDate(from: false),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                _toDate == null
                                    ? 'To Date'
                                    : 'To ${DateFormat('dd MMM yyyy').format(_toDate!)}',
                              ),
                            ),
                            if (_fromDate != null || _toDate != null)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _fromDate = null;
                                  _toDate = null;
                                }),
                                icon: const Icon(Icons.clear),
                                label: const Text('All Dates'),
                              ),
                          ],
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Confirm before manual transfer'),
                          subtitle: const Text(
                            'Show direction and date range for approval before data is sent or imported.',
                          ),
                          value: _confirmBeforeManualSync,
                          onChanged: (value) => setState(
                            () => _confirmBeforeManualSync = value ?? true,
                          ),
                        ),
                        _moduleGroup(
                          title: 'Accounting Masters',
                          subtitle: 'Groups, ledgers, GST, and cost structures',
                          group: TallySyncModuleGroup.masters,
                        ),
                        const SizedBox(height: 12),
                        _moduleGroup(
                          title: 'Inventory Masters',
                          subtitle: 'Stock items, stock groups, and units',
                          group: TallySyncModuleGroup.inventory,
                        ),
                        const SizedBox(height: 12),
                        _moduleGroup(
                          title: 'Voucher Synchronization',
                          subtitle:
                              'Choose import, export, or two-way rights for each voucher type',
                          group: TallySyncModuleGroup.vouchers,
                        ),
                        DropdownButtonFormField<TallyConflictPolicy>(
                          value: _masterPolicy,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Master Duplicate Rule',
                            border: OutlineInputBorder(),
                          ),
                          items: TallyConflictPolicy.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.displayName),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _masterPolicy = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<TallyConflictPolicy>(
                          value: _voucherPolicy,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Voucher Duplicate Rule',
                            border: OutlineInputBorder(),
                          ),
                          items: TallyConflictPolicy.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.displayName),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _voucherPolicy = value);
                            }
                          },
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Allow Tally deletions'),
                          subtitle: const Text(
                            'Keep disabled unless deletion propagation is explicitly required.',
                          ),
                          value: _allowTallyDeletions,
                          onChanged: (value) => setState(
                            () => _allowTallyDeletions = value ?? false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Automatic Sync',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Automatic Sync'),
                          subtitle: Text(
                            selectedSettings.hasCompletedInitialSync
                                ? 'Run automatically at the selected interval.'
                                : 'Available after the first successful manual sync.',
                          ),
                          value: _autoSyncEnabled,
                          onChanged: selectedSettings.hasCompletedInitialSync
                              ? (value) =>
                                    setState(() => _autoSyncEnabled = value)
                              : null,
                        ),
                        DropdownButtonFormField<int>(
                          value: _intervalMinutes,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Interval',
                            border: OutlineInputBorder(),
                          ),
                          items: const <int>[5, 15, 30, 60]
                              .map(
                                (minutes) => DropdownMenuItem(
                                  value: minutes,
                                  child: Text('$minutes minutes'),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _intervalMinutes = value);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (!selectedSettings.hasCompletedInitialSync) ...[
                      _section(
                        title: 'Pull Selected Data from Tally',
                        children: [
                          const Text(
                            'Pull only the selected data and date range from Tally into Chirag. This action never sends Chirag data to Tally and does not enable automatic sync.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _saving || _syncing || !_enabled
                                ? null
                                : () => _runSync(initialImport: true),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(
                              _syncing ? 'Importing...' : 'Pull Selected Data',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving || _syncing ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save Settings'),
                        ),
                        FilledButton.icon(
                          onPressed:
                              _saving ||
                                  _syncing ||
                                  !_enabled ||
                                  !selectedSettings.hasCompletedInitialSync
                              ? null
                              : () => _runSync(),
                          icon: _syncing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(_syncing ? 'Syncing...' : 'Sync Now'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _syncHistorySection(selectedHistory),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _statusCard(TallySyncSettings settings) {
    final color = switch (settings.status) {
      TallySyncStatus.success => Colors.green,
      TallySyncStatus.failed => Colors.red,
      TallySyncStatus.syncing => Colors.orange,
      TallySyncStatus.ready => Colors.blue,
      TallySyncStatus.notConnected => Colors.grey,
    };
    final label = switch (settings.status) {
      TallySyncStatus.notConnected => 'Not connected',
      TallySyncStatus.ready => 'Ready for first sync',
      TallySyncStatus.syncing => 'Sync in progress',
      TallySyncStatus.success => 'Connected',
      TallySyncStatus.failed => 'Last sync failed',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 28,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusMetric(
              icon: Icons.sync,
              label: 'Connection',
              value: label,
              color: color,
            ),
            _statusMetric(
              icon: Icons.apartment_outlined,
              label: 'Tally Companies',
              value: settings.selectedCompanyNames.isEmpty
                  ? 'Not configured'
                  : settings.selectedCompanyNames.join(', '),
            ),
            _statusMetric(
              icon: Icons.swap_horiz,
              label: 'Default Direction',
              value: settings.direction.displayName,
            ),
            _statusMetric(
              icon: Icons.schedule_outlined,
              label: 'Last Sync',
              value: settings.lastSyncAt == null
                  ? 'Never'
                  : DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(settings.lastSyncAt!),
            ),
            if (settings.lastError.isNotEmpty)
              SizedBox(
                width: 360,
                child: Text(
                  settings.lastError,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _syncHistorySection(List<TallySyncHistoryEntry> history) {
    return _section(
      title: 'Sync History',
      children: [
        if (history.isEmpty)
          const Text('No synchronization runs recorded yet.')
        else
          for (final entry in history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.failed
                    ? Icons.error_outline
                    : entry.warnings.isNotEmpty
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                color: entry.failed
                    ? Colors.red
                    : entry.warnings.isNotEmpty
                    ? Colors.orange
                    : Colors.green,
              ),
              title: Text(
                '${entry.companyName} | ${entry.direction}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                entry.failed
                    ? entry.errorMessage
                    : 'Imported ${entry.imported} | Exported ${entry.exported}${entry.warnings.isEmpty ? '' : ' | ${entry.warnings.length} warning(s)'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: entry.failed
                  ? IconButton(
                      tooltip: 'Retry sync',
                      onPressed: _syncing ? null : () => _runSync(),
                      icon: const Icon(Icons.refresh),
                    )
                  : Text(
                      DateFormat('dd MMM\nhh:mm a').format(entry.startedAt),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11),
                    ),
            ),
      ],
    );
  }

  Widget _statusMetric({
    required IconData icon,
    required String label,
    required String value,
    Color color = const Color(0xFF0A3A86),
  }) {
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF65758B),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleGroup({
    required String title,
    required String subtitle,
    required TallySyncModuleGroup group,
  }) {
    final modules = TallySyncModule.values
        .where((module) => module.group == group)
        .toList(growable: false);
    final selectedCount = modules.where(_moduleDirections.containsKey).length;
    final allSelected = selectedCount == modules.length;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD8E1EC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: allSelected,
            tristate: selectedCount > 0 && !allSelected,
            onChanged: (selected) => setState(() {
              if (selected ?? false) {
                for (final module in modules) {
                  _moduleDirections.putIfAbsent(module, () => _direction);
                }
              } else {
                _moduleDirections.removeWhere(
                  (module, _) => module.group == group,
                );
              }
            }),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(subtitle),
            secondary: Text('$selectedCount/${modules.length}'),
          ),
          const Divider(height: 1),
          for (final module in modules) _moduleRule(module),
        ],
      ),
    );
  }

  Widget _moduleRule(TallySyncModule module) {
    final selected = _moduleDirections.containsKey(module);
    return LayoutBuilder(
      builder: (context, constraints) {
        final checkbox = Checkbox(
          value: selected,
          onChanged: (enabled) => setState(() {
            if (enabled ?? false) {
              _moduleDirections[module] = _direction;
            } else {
              _moduleDirections.remove(module);
            }
          }),
        );
        final direction = DropdownButton<TallySyncDirection>(
          value: selected ? _moduleDirections[module] : _direction,
          isExpanded: true,
          onChanged: selected
              ? (value) {
                  if (value != null) {
                    setState(() => _moduleDirections[module] = value);
                  }
                }
              : null,
          items: TallySyncDirection.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    value.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
        );
        if (constraints.maxWidth < 480) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
            child: Row(
              children: [
                checkbox,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(module.displayName),
                      const SizedBox(height: 2),
                      direction,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              checkbox,
              Expanded(child: Text(module.displayName)),
              SizedBox(width: 190, child: direction),
            ],
          ),
        );
      },
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
