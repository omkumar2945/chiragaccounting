import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/services/client_data_exchange_service.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/features/vendors/models/vendor.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class ClientDataExchangeScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? initialInventoryFilePath;
  final Uint8List? initialInventoryFileBytes;
  final String? initialInventorySourceName;
  final String? initialLedgerFilePath;
  final Uint8List? initialLedgerFileBytes;
  final String? initialLedgerSourceName;
  final LedgerImportTarget? initialLedgerImportTarget;

  const ClientDataExchangeScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialInventoryFilePath,
    this.initialInventoryFileBytes,
    this.initialInventorySourceName,
    this.initialLedgerFilePath,
    this.initialLedgerFileBytes,
    this.initialLedgerSourceName,
    this.initialLedgerImportTarget,
  });

  @override
  State<ClientDataExchangeScreen> createState() =>
      _ClientDataExchangeScreenState();
}

class _ClientDataExchangeScreenState extends State<ClientDataExchangeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final ClientDataExchangeService _exchange = ClientDataExchangeService();

  String _inventoryFilePath = '';
  Uint8List? _inventoryFileBytes;
  String _inventorySourceName = '';
  String _ledgerFilePath = '';
  Uint8List? _ledgerFileBytes;
  String _ledgerSourceName = '';
  bool _busy = false;
  ImportSummary? _lastSummary;
  LedgerImportTarget _ledgerImportTarget = LedgerImportTarget.allLedgers;

  final _groupNameCtrl = TextEditingController();
  final _baseUnitCtrl = TextEditingController(text: 'Nos');
  final _conversionRulesCtrl = TextEditingController();
  final _supplierAccountCtrl = TextEditingController();
  final _supplierTokenCtrl = TextEditingController();

  Vendor? _selectedVendor;
  bool _supplierPermissionGranted = false;
  bool _supplierUsesChiragSystem = false;

  Future<void> _loadSupplierFlags(Vendor vendor) async {
    final permission = await _exchange.getSupplierPermission(vendor.id);
    final sameSystem = await _exchange.getSupplierSameSystem(vendor.id);
    if (!mounted) return;
    setState(() {
      _supplierPermissionGranted = permission;
      _supplierUsesChiragSystem = sameSystem;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final initial = widget.initialTabIndex.clamp(0, 2);
    _tabCtrl.index = initial;

    if ((widget.initialInventoryFilePath ?? '').trim().isNotEmpty ||
        widget.initialInventoryFileBytes != null) {
      _inventoryFilePath = widget.initialInventoryFilePath?.trim() ?? '';
      _inventoryFileBytes = widget.initialInventoryFileBytes;
      _inventorySourceName =
          widget.initialInventorySourceName?.trim().isNotEmpty == true
          ? widget.initialInventorySourceName!.trim()
          : 'inventory_import';
    }

    if ((widget.initialLedgerFilePath ?? '').trim().isNotEmpty ||
        widget.initialLedgerFileBytes != null) {
      _ledgerFilePath = widget.initialLedgerFilePath?.trim() ?? '';
      _ledgerFileBytes = widget.initialLedgerFileBytes;
      _ledgerSourceName = widget.initialLedgerSourceName?.trim().isNotEmpty ==
              true
          ? widget.initialLedgerSourceName!.trim()
          : 'ledger_import';
    }

    if (widget.initialLedgerImportTarget != null) {
      _ledgerImportTarget = widget.initialLedgerImportTarget!;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _groupNameCtrl.dispose();
    _baseUnitCtrl.dispose();
    _conversionRulesCtrl.dispose();
    _supplierAccountCtrl.dispose();
    _supplierTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile({required bool forInventory}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'csv',
        'tsv',
        'txt',
        'json',
        'xlsx',
        'xls',
        'xlsm',
      ],
    );

    if (!mounted || result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path ?? '';
    final bytes = await picked.readAsBytes();
    final sourceName = picked.name.trim().isEmpty
        ? 'import.csv'
        : picked.name.trim();
    final canUsePath = _isUsableLocalPath(path);

    if (!canUsePath && bytes.isEmpty) {
      _showMsg('Could not read selected file. Please choose another file.');
      return;
    }

    if (forInventory) {
      setState(() {
        _inventoryFilePath = path;
        _inventoryFileBytes = bytes;
        _inventorySourceName = sourceName;
        _lastSummary = null;
      });
      return;
    }

    setState(() {
      _ledgerFilePath = path;
      _ledgerFileBytes = bytes;
      _ledgerSourceName = sourceName;
      _lastSummary = null;
    });
  }

  Future<void> _importInventoryFromBytes({
    required Uint8List bytes,
    required String sourceName,
  }) async {
    final products = context.read<ProductService>();
    setState(() => _busy = true);

    try {
      final summary = await _exchange.importInventoryFromBytes(
        sourceName: sourceName,
        bytes: bytes,
        productService: products,
        unitGroupName: _groupNameCtrl.text.trim(),
        baseUnit: _baseUnitCtrl.text.trim().isEmpty
            ? 'Nos'
            : _baseUnitCtrl.text.trim(),
        conversionRules: _parseRules(_conversionRulesCtrl.text),
      );
      if (!mounted) return;
      setState(() => _lastSummary = summary);
      _showMsg('Inventory import finished: ${summary.processed} rows.');
    } catch (e) {
      _showMsg('Inventory import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importLedgerFromBytes({
    required Uint8List bytes,
    required String sourceName,
  }) async {
    final customers = context.read<CustomerService>();
    final vendors = context.read<VendorService>();
    setState(() => _busy = true);

    try {
      final summary = await _exchange.importLedgerFromBytes(
        sourceName: sourceName,
        bytes: bytes,
        customerService: customers,
        vendorService: vendors,
        target: _ledgerImportTarget,
      );
      if (!mounted) return;
      setState(() => _lastSummary = summary);
      _showMsg('Ledger import finished: ${summary.processed} rows.');
    } catch (e) {
      _showMsg('Ledger import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importInventory() async {
    final hasLocalPath = _isUsableLocalPath(_inventoryFilePath);
    if (!hasLocalPath && _inventoryFileBytes == null) {
      _showMsg('Please choose inventory file first.');
      return;
    }

    if (!hasLocalPath && _inventoryFileBytes != null) {
      await _importInventoryFromBytes(
        bytes: _inventoryFileBytes!,
        sourceName: _inventorySourceName,
      );
      return;
    }

    final products = context.read<ProductService>();
    setState(() => _busy = true);

    try {
      final summary = await _exchange.importInventoryFromFile(
        filePath: _inventoryFilePath,
        productService: products,
        unitGroupName: _groupNameCtrl.text.trim(),
        baseUnit: _baseUnitCtrl.text.trim().isEmpty
            ? 'Nos'
            : _baseUnitCtrl.text.trim(),
        conversionRules: _parseRules(_conversionRulesCtrl.text),
      );
      if (!mounted) return;
      setState(() => _lastSummary = summary);
      _showMsg('Inventory import finished: ${summary.processed} rows.');
    } catch (e) {
      _showMsg('Inventory import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importLedger() async {
    final hasLocalPath = _isUsableLocalPath(_ledgerFilePath);
    if (!hasLocalPath && _ledgerFileBytes == null) {
      _showMsg('Please choose ledger file first.');
      return;
    }

    if (!hasLocalPath && _ledgerFileBytes != null) {
      await _importLedgerFromBytes(
        bytes: _ledgerFileBytes!,
        sourceName: _ledgerSourceName,
      );
      return;
    }

    final customers = context.read<CustomerService>();
    final vendors = context.read<VendorService>();
    setState(() => _busy = true);

    try {
      final summary = await _exchange.importLedgerFromFile(
        filePath: _ledgerFilePath,
        customerService: customers,
        vendorService: vendors,
        target: _ledgerImportTarget,
      );
      if (!mounted) return;
      setState(() => _lastSummary = summary);
      _showMsg('Ledger import finished: ${summary.processed} rows.');
    } catch (e) {
      _showMsg('Ledger import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pullSupplierInventory() async {
    final vendor = _selectedVendor;
    if (vendor == null) {
      _showMsg('Please select supplier first.');
      return;
    }

    final usesChirag =
        _supplierUsesChiragSystem || _autoDetectSameSystem(vendor);
    final clientAccountId = _clientAccountId();

    final products = context.read<ProductService>();
    final vendors = context.read<VendorService>();

    setState(() => _busy = true);
    try {
      final summary = await _exchange.pullSupplierInventory(
        vendor: vendor,
        supplierPermissionGranted: _supplierPermissionGranted,
        supplierUsesChiragSystem: usesChirag,
        productService: products,
        vendorService: vendors,
        supplierAccountId: _supplierAccountCtrl.text.trim(),
        handshakeToken: _supplierTokenCtrl.text.trim(),
        clientAccountId: clientAccountId,
        unitGroupName: _groupNameCtrl.text.trim().isEmpty
            ? '${vendor.vendorName} Inventory'
            : _groupNameCtrl.text.trim(),
        baseUnit: _baseUnitCtrl.text.trim().isEmpty
            ? 'Nos'
            : _baseUnitCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _lastSummary = summary);
      _showMsg('Supplier pull completed: ${summary.processed} rows.');
    } catch (e) {
      _showMsg('Supplier pull failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issueHandshakeToken() async {
    final supplierAccountId = _supplierAccountCtrl.text.trim().toLowerCase();
    if (supplierAccountId.isEmpty) {
      _showMsg('Enter supplier Chirag account ID first.');
      return;
    }
    if (!_supplierPermissionGranted) {
      _showMsg('Enable supplier permission first.');
      return;
    }

    setState(() => _busy = true);
    try {
      final token = await _exchange.issueHandshakeToken(
        supplierAccountId: supplierAccountId,
        clientAccountId: _clientAccountId(),
        supplierPermissionGranted: _supplierPermissionGranted,
      );
      if (!mounted) return;
      setState(() => _supplierTokenCtrl.text = token.token);
      _showMsg(
        'Handshake token issued. Share this token between Chirag accounts.',
      );
    } catch (e) {
      _showMsg('Token issue failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validateHandshakeToken() async {
    final supplierAccountId = _supplierAccountCtrl.text.trim().toLowerCase();
    final token = _supplierTokenCtrl.text.trim();
    if (supplierAccountId.isEmpty || token.isEmpty) {
      _showMsg('Enter supplier account ID and token first.');
      return;
    }

    final valid = await _exchange.validateHandshakeToken(
      token: token,
      supplierAccountId: supplierAccountId,
      clientAccountId: _clientAccountId(),
    );

    _showMsg(
      valid
          ? 'Handshake token is valid. Live sync is allowed.'
          : 'Invalid or expired token. Please request a new one.',
    );
  }

  String _clientAccountId() {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return '';
    if (user.email.trim().isNotEmpty) return user.email.trim().toLowerCase();
    return user.id.trim().toLowerCase();
  }

  bool _autoDetectSameSystem(Vendor vendor) {
    final email = vendor.email.toLowerCase();
    return email.endsWith('@chiragca.com') || email.contains('chirag');
  }

  Map<String, double> _parseRules(String raw) {
    final out = <String, double>{};
    final chunks = raw.split(',');
    for (final chunk in chunks) {
      final parts = chunk.split('=');
      if (parts.length != 2) continue;
      final unit = parts.first.trim();
      final factor = double.tryParse(parts.last.trim());
      if (unit.isEmpty || factor == null || factor <= 0) continue;
      out[unit] = factor;
    }
    return out;
  }

  bool _isUsableLocalPath(String path) {
    return isUsableLocalFilePath(path);
  }

  String _inventoryDisplayName() {
    if (_inventorySourceName.trim().isNotEmpty) {
      return _inventorySourceName;
    }
    if (_isUsableLocalPath(_inventoryFilePath)) {
      return _inventoryFilePath;
    }
    return _inventoryFileBytes == null
        ? 'No file selected'
        : 'Selected file ready to import';
  }

  String _ledgerDisplayName() {
    if (_ledgerSourceName.trim().isNotEmpty) {
      return _ledgerSourceName;
    }
    if (_isUsableLocalPath(_ledgerFilePath)) {
      return _ledgerFilePath;
    }
    return _ledgerFileBytes == null
        ? 'No file selected'
        : 'Selected file ready to import';
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final vendors = context.watch<VendorService>().vendors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Data Exchange'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Import Inventory'),
            Tab(text: 'Import Ledger'),
            Tab(text: 'Supplier Pull'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabCtrl,
            children: [_inventoryTab(), _ledgerTab(), _supplierTab(vendors)],
          ),
          if (_busy)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _inventoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Import inventory from existing software in CSV/TSV/TXT/JSON/XLSX.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _pickFile(forInventory: true),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Choose Inventory File'),
        ),
        const SizedBox(height: 8),
        Text(_inventoryDisplayName(), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 16),
        TextField(
          controller: _groupNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Inventory Group Name',
            hintText: 'Example: Tiles Master Group',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _baseUnitCtrl,
          decoration: const InputDecoration(
            labelText: 'Base Unit',
            hintText: 'Example: Nos or Kg',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _conversionRulesCtrl,
          decoration: const InputDecoration(
            labelText: 'Unit Conversion Rules',
            hintText: 'Example: Box=12,Packet=24',
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _busy ? null : _importInventory,
          icon: const Icon(Icons.playlist_add_check_circle_outlined),
          label: const Text('Import Inventory Now'),
        ),
        const SizedBox(height: 16),
        _summaryCard(),
      ],
    );
  }

  Widget _ledgerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Import ledgers/party master from old software. Choose whether the file contains debtors, creditors, or a mixed chart of accounts.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 10),
        SearchableDropdownFormField<LedgerImportTarget>(
          value: _ledgerImportTarget,
          decoration: const InputDecoration(
            labelText: 'Ledger Import Type',
            border: OutlineInputBorder(),
          ),
          items: LedgerImportTarget.values,
          itemLabelBuilder: (target) => target.displayName,
          onChanged: _busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _ledgerImportTarget = value);
                },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _pickFile(forInventory: false),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Choose Ledger File'),
        ),
        const SizedBox(height: 8),
        Text(_ledgerDisplayName(), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _busy ? null : _importLedger,
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('Import Ledger / Debtors / Creditors'),
        ),
        const SizedBox(height: 16),
        _summaryCard(),
      ],
    );
  }

  Widget _supplierTab(List<Vendor> vendors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pull supplier inventory (Name + HSN + Unit) into your system when supplier grants permission.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        SearchableDropdownFormField<Vendor>(
          value: _selectedVendor,
          decoration: const InputDecoration(labelText: 'Select Supplier'),
          items: vendors,
          itemLabelBuilder: (v) => '${v.vendorName} (${v.vendorCode})',
          onChanged: _busy
              ? null
              : (value) async {
                  if (value == null) return;
                  setState(() {
                    _selectedVendor = value;
                    if (value.email.trim().isNotEmpty) {
                      _supplierAccountCtrl.text = value.email
                          .trim()
                          .toLowerCase();
                    }
                  });
                  await _loadSupplierFlags(value);
                },
        ),
        if (vendors.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No supplier found. Add suppliers in Vendor module first.',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Supplier Permission Granted'),
          subtitle: const Text('Required before pull is allowed.'),
          value: _supplierPermissionGranted,
          onChanged: _busy
              ? null
              : (v) async {
                  final vendor = _selectedVendor;
                  if (vendor == null) return;
                  setState(() => _supplierPermissionGranted = v);
                  await _exchange.setSupplierPermission(vendor.id, v);
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Supplier Uses Chirag System'),
          subtitle: const Text('If yes, auto pull mode will be used.'),
          value: _supplierUsesChiragSystem,
          onChanged: _busy
              ? null
              : (v) async {
                  final vendor = _selectedVendor;
                  if (vendor == null) return;
                  setState(() => _supplierUsesChiragSystem = v);
                  await _exchange.setSupplierSameSystem(vendor.id, v);
                },
        ),
        if (_supplierUsesChiragSystem ||
            (_selectedVendor != null &&
                _autoDetectSameSystem(_selectedVendor!))) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _supplierAccountCtrl,
            decoration: const InputDecoration(
              labelText: 'Supplier Chirag Account ID',
              hintText: 'Example: admin@chiragca.com',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _issueHandshakeToken,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Issue Handshake Token'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _validateHandshakeToken,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Validate Token'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _supplierTokenCtrl,
            decoration: const InputDecoration(
              labelText: 'Supplier Handshake Token',
              hintText: 'Example: SYNC-XXXXXXXXXX',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Live sync requires: permission + supplier account ID + valid handshake token.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _busy ? null : _pullSupplierInventory,
          icon: const Icon(Icons.sync_alt_outlined),
          label: const Text('Pull Supplier Inventory'),
        ),
        const SizedBox(height: 16),
        _summaryCard(),
      ],
    );
  }

  Widget _summaryCard() {
    final summary = _lastSummary;
    if (summary == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Operation Summary',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Processed: ${summary.processed}'),
            Text('Created: ${summary.created}'),
            Text('Updated: ${summary.updated}'),
            if (summary.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Notes',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...summary.warnings.map((w) => Text('- $w')),
            ],
          ],
        ),
      ),
    );
  }
}
