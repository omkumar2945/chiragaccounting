import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:chirag_accounting/core/utils/file_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/reports/services/client_provisional_report_service.dart';
import 'package:chirag_accounting/features/reports/services/provisional_report_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

class QuickProvisionalReportScreen extends StatefulWidget {
  const QuickProvisionalReportScreen({super.key});

  @override
  State<QuickProvisionalReportScreen> createState() =>
      _QuickProvisionalReportScreenState();
}

class _QuickProvisionalReportScreenState
    extends State<QuickProvisionalReportScreen> {
  final ProvisionalReportService _service = const ProvisionalReportService();
  final InvoiceOcrService _ocr = InvoiceOcrService();

  final _turnoverCtrl = TextEditingController(text: '0');
  final _otherIncomeCtrl = TextEditingController(text: '0');
  final _cogsCtrl = TextEditingController(text: '0');
  final _operatingExpensesCtrl = TextEditingController(text: '0');
  final _depreciationCtrl = TextEditingController(text: '0');
  final _interestCtrl = TextEditingController(text: '0');
  final _taxRateCtrl = TextEditingController(text: '25');

  final _currentAssetsCtrl = TextEditingController(text: '0');
  final _fixedAssetsCtrl = TextEditingController(text: '0');
  final _currentLiabilitiesCtrl = TextEditingController(text: '0');
  final _longTermLiabilitiesCtrl = TextEditingController(text: '0');
  final _equityCtrl = TextEditingController(text: '0');

  final _cfoCtrl = TextEditingController(text: '0');
  final _cfiCtrl = TextEditingController(text: '0');
  final _cffCtrl = TextEditingController(text: '0');

  final _commandCtrl = TextEditingController(text: '12');
  final _searchCtrl = TextEditingController();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  FinancialProjectionReport? _report;
  String _uploadedSource = '';
  bool _processingUpload = false;
  bool _exporting = false;
  _ProjectionView _view = _ProjectionView.all;
  String? _selectedClientId;
  String? _submittedClientId;
  String _status =
      'Upload previous statement (PDF/image/text) or fill values manually, then enter growth % command (e.g., 15).';

  @override
  void dispose() {
    _turnoverCtrl.dispose();
    _otherIncomeCtrl.dispose();
    _cogsCtrl.dispose();
    _operatingExpensesCtrl.dispose();
    _depreciationCtrl.dispose();
    _interestCtrl.dispose();
    _taxRateCtrl.dispose();
    _currentAssetsCtrl.dispose();
    _fixedAssetsCtrl.dispose();
    _currentLiabilitiesCtrl.dispose();
    _longTermLiabilitiesCtrl.dispose();
    _equityCtrl.dispose();
    _cfoCtrl.dispose();
    _cfiCtrl.dispose();
    _cffCtrl.dispose();
    _commandCtrl.dispose();
    _searchCtrl.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = context
      .watch<AdminUserService>()
      .users
      .where((user) => user.isActive && user.role == UserRole.client)
      .toList(growable: false);
    final selectedClient = clients
      .where((client) => client.id == _selectedClientId)
      .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Provisional Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advanced Provisional Financial Projection',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Step 1: Upload previous statement PDF/image/text (or fill fields manually).\n'
                    'Step 2: Enter growth % command (example: 18).\n'
                    'Step 3: Generate 3-year projections with P&L, Balance Sheet and Cash Flow preview, filters and download options.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _processingUpload ? null : _uploadAndAnalyze,
                        icon: _processingUpload
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(
                          _processingUpload
                              ? 'Analyzing...'
                              : 'Upload Previous File/PDF',
                        ),
                      ),
                      if (_uploadedSource.isNotEmpty)
                        Chip(label: Text('Source: $_uploadedSource')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedClient?.id,
                    decoration: const InputDecoration(
                      labelText: 'Client for this provisional report',
                      border: OutlineInputBorder(),
                    ),
                    items: clients
                        .map(
                          (client) => DropdownMenuItem<String>(
                            value: client.id,
                            child: Text(client.firmName.isEmpty ? client.name : client.firmName),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: clients.isEmpty
                        ? null
                        : (clientId) => setState(() {
                            _selectedClientId = clientId;
                            _submittedClientId = null;
                          }),
                  ),
                  if (clients.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Add an active client before preparing a client report.'),
                    ),
                  const SizedBox(height: 12),
                  _sectionTitle('Profit & Loss Base'),
                  const SizedBox(height: 8),
                  _numberField(_turnoverCtrl, 'Turnover / Sales'),
                  _numberField(_otherIncomeCtrl, 'Other Income'),
                  _numberField(_cogsCtrl, 'Cost of Goods Sold / Purchase'),
                  _numberField(_operatingExpensesCtrl, 'Operating Expenses'),
                  _numberField(_depreciationCtrl, 'Depreciation'),
                  _numberField(_interestCtrl, 'Interest / Finance Cost'),
                  _numberField(_taxRateCtrl, 'Tax Rate %', suffix: '%'),
                  const SizedBox(height: 10),
                  _sectionTitle('Balance Sheet Base'),
                  const SizedBox(height: 8),
                  _numberField(_currentAssetsCtrl, 'Current Assets'),
                  _numberField(_fixedAssetsCtrl, 'Fixed Assets'),
                  _numberField(_currentLiabilitiesCtrl, 'Current Liabilities'),
                  _numberField(_longTermLiabilitiesCtrl, 'Long-Term Liabilities'),
                  _numberField(_equityCtrl, 'Opening Equity / Capital'),
                  const SizedBox(height: 10),
                  _sectionTitle('Cash Flow Base'),
                  const SizedBox(height: 8),
                  _numberField(_cfoCtrl, 'Cash Flow from Operating Activities'),
                  _numberField(_cfiCtrl, 'Cash Flow from Investing Activities'),
                  _numberField(_cffCtrl, 'Cash Flow from Financing Activities'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commandCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Growth % Command for next years',
                      hintText: 'Example: 15',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _generate,
                        icon: const Icon(Icons.flash_on_outlined),
                        label: const Text('Generate 3-Year Projection'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _report == null ? null : _copyDraft,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copy Draft Summary'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _report == null || _exporting ? null : _downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Download PDF'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _report == null || _exporting ? null : _downloadJson,
                        icon: const Icon(Icons.code_outlined),
                        label: const Text('Download JSON'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _report == null || selectedClient == null
                            ? null
                            : () => _submitForClient(selectedClient),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Submit for Finalization'),
                      ),
                      FilledButton.icon(
                        onPressed: selectedClient == null ||
                                _submittedClientId != selectedClient.id
                            ? null
                            : () => _finalizeForClient(selectedClient),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Finalize for Client'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      color: _report == null ? Colors.black87 : Colors.green[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_report != null) ...[
            const SizedBox(height: 12),
            _buildSummary(_report!),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 12),
            _buildProjectionTable(_report!),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    String prefix = 'Rs. ',
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          suffixText: suffix.isEmpty ? null : suffix,
        ),
      ),
    );
  }

  Widget _buildSummary(FinancialProjectionReport report) {
    final latest = report.projections.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Chip(label: Text('Growth ${report.growthPercent.toStringAsFixed(1)}%')),
            Chip(label: Text('Base Turnover ${_currency.format(report.base.turnover)}')),
            Chip(label: Text('Year ${report.years} Net Profit ${_currency.format(latest.netProfit)}')),
            Chip(label: Text('Year ${report.years} Total Assets ${_currency.format(latest.totalAssets)}')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<_ProjectionView>(
                value: _view,
                decoration: const InputDecoration(
                  labelText: 'Preview View',
                  border: OutlineInputBorder(),
                ),
                items: _ProjectionView.values
                    .map(
                      (item) => DropdownMenuItem<_ProjectionView>(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _view = value);
                },
              ),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Search line item',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionTable(FinancialProjectionReport report) {
    final showPnl = _view == _ProjectionView.all || _view == _ProjectionView.pnl;
    final showBalance =
        _view == _ProjectionView.all || _view == _ProjectionView.balanceSheet;
    final showCash = _view == _ProjectionView.all || _view == _ProjectionView.cashFlow;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Projected Financial Statements (3 Years)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (showPnl)
              _statementTable(
                title: 'Profit & Loss Preview',
                rows: _lineRows(
                  report,
                  <_LineDef>[
                    _LineDef('Turnover', (y) => y.turnover),
                    _LineDef('Other Income', (y) => y.otherIncome),
                    _LineDef('Total Income', (y) => y.totalIncome),
                    _LineDef('Cost of Goods Sold', (y) => y.costOfGoodsSold),
                    _LineDef('Operating Expenses', (y) => y.operatingExpenses),
                    _LineDef('EBITDA', (y) => y.ebitda),
                    _LineDef('Depreciation', (y) => y.depreciation),
                    _LineDef('Interest', (y) => y.interest),
                    _LineDef('Profit Before Tax', (y) => y.profitBeforeTax),
                    _LineDef('Tax Expense', (y) => y.taxExpense),
                    _LineDef('Net Profit', (y) => y.netProfit),
                  ],
                ),
              ),
            if (showBalance)
              _statementTable(
                title: 'Balance Sheet Preview',
                rows: _lineRows(
                  report,
                  <_LineDef>[
                    _LineDef('Current Assets', (y) => y.currentAssets),
                    _LineDef('Fixed Assets', (y) => y.fixedAssets),
                    _LineDef('Total Assets', (y) => y.totalAssets),
                    _LineDef('Current Liabilities', (y) => y.currentLiabilities),
                    _LineDef('Long-Term Liabilities', (y) => y.longTermLiabilities),
                    _LineDef('Total Liabilities', (y) => y.totalLiabilities),
                    _LineDef('Closing Equity', (y) => y.equityClosing),
                  ],
                ),
              ),
            if (showCash)
              _statementTable(
                title: 'Cash Flow Preview',
                rows: _lineRows(
                  report,
                  <_LineDef>[
                    _LineDef('Operating Cash Flow', (y) => y.cashFlowOperating),
                    _LineDef('Investing Cash Flow', (y) => y.cashFlowInvesting),
                    _LineDef('Financing Cash Flow', (y) => y.cashFlowFinancing),
                    _LineDef('Net Cash Flow', (y) => y.netCashFlow),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_StatementRow> _lineRows(
    FinancialProjectionReport report,
    List<_LineDef> defs,
  ) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return defs
        .where((entry) {
          if (query.isEmpty) return true;
          return entry.label.toLowerCase().contains(query);
        })
        .map(
          (entry) => _StatementRow(
            label: entry.label,
            values: report.projections
                .map((projection) => entry.pick(projection))
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Widget _statementTable({
    required String title,
    required List<_StatementRow> rows,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            const Text('No line item matches current filter.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Line Item')),
                  DataColumn(label: Text('Year 1')),
                  DataColumn(label: Text('Year 2')),
                  DataColumn(label: Text('Year 3')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.label)),
                          DataCell(Text(_currency.format(row.values[0]))),
                          DataCell(Text(_currency.format(row.values[1]))),
                          DataCell(Text(_currency.format(row.values[2]))),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _uploadAndAnalyze() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'png', 'jpg', 'jpeg', 'txt'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _status = 'Uploaded file is empty.');
      return;
    }

    setState(() {
      _processingUpload = true;
      _status = 'Analyzing previous file...';
    });

    try {
      final ext = file.extension?.toLowerCase() ?? '';
      final text = await _extractText(file.name, ext, bytes);
      final parsed = _service.parseFinancialStatementText(text);
      _setBaseFromParsed(parsed);
      setState(() {
        _uploadedSource = file.name;
        _status =
            'File analyzed. Review values and enter growth % to generate 3-year projection.';
      });
    } catch (error) {
      setState(() {
        _status = 'Unable to analyze uploaded file: $error';
      });
    } finally {
      setState(() => _processingUpload = false);
    }
  }

  Future<String> _extractText(String fileName, String ext, Uint8List bytes) async {
    if (ext == 'pdf') {
      return _ocr.extractTextFromPdfBytes(bytes, maxPagesToScan: 12, rasterDpi: 220);
    }
    if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
      return _ocr.extractTextFromImageBytes(bytes, fileName: fileName);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  void _setBaseFromParsed(FinancialStatementBase parsed) {
    _turnoverCtrl.text = parsed.turnover.toStringAsFixed(0);
    _otherIncomeCtrl.text = parsed.otherIncome.toStringAsFixed(0);
    _cogsCtrl.text = parsed.costOfGoodsSold.toStringAsFixed(0);
    _operatingExpensesCtrl.text = parsed.operatingExpenses.toStringAsFixed(0);
    _depreciationCtrl.text = parsed.depreciation.toStringAsFixed(0);
    _interestCtrl.text = parsed.interest.toStringAsFixed(0);
    _taxRateCtrl.text = parsed.taxRatePercent.toStringAsFixed(2);
    _currentAssetsCtrl.text = parsed.currentAssets.toStringAsFixed(0);
    _fixedAssetsCtrl.text = parsed.fixedAssets.toStringAsFixed(0);
    _currentLiabilitiesCtrl.text = parsed.currentLiabilities.toStringAsFixed(0);
    _longTermLiabilitiesCtrl.text = parsed.longTermLiabilities.toStringAsFixed(0);
    _equityCtrl.text = parsed.equityOpening.toStringAsFixed(0);
    _cfoCtrl.text = parsed.cashFlowOperating.toStringAsFixed(0);
    _cfiCtrl.text = parsed.cashFlowInvesting.toStringAsFixed(0);
    _cffCtrl.text = parsed.cashFlowFinancing.toStringAsFixed(0);
  }

  void _generate() {
    try {
      final command = _service.parseQuickCommand(_commandCtrl.text);
      final base = FinancialStatementBase(
        turnover: _asDouble(_turnoverCtrl.text),
        otherIncome: _asDouble(_otherIncomeCtrl.text),
        costOfGoodsSold: _asDouble(_cogsCtrl.text),
        operatingExpenses: _asDouble(_operatingExpensesCtrl.text),
        depreciation: _asDouble(_depreciationCtrl.text),
        interest: _asDouble(_interestCtrl.text),
        taxRatePercent: _asDouble(_taxRateCtrl.text),
        currentAssets: _asDouble(_currentAssetsCtrl.text),
        fixedAssets: _asDouble(_fixedAssetsCtrl.text),
        currentLiabilities: _asDouble(_currentLiabilitiesCtrl.text),
        longTermLiabilities: _asDouble(_longTermLiabilitiesCtrl.text),
        equityOpening: _asDouble(_equityCtrl.text),
        cashFlowOperating: _asDouble(_cfoCtrl.text),
        cashFlowInvesting: _asDouble(_cfiCtrl.text),
        cashFlowFinancing: _asDouble(_cffCtrl.text),
      );

      final report = _service.generateFinancialProjection(
        base: base,
        command: command,
      );

      setState(() {
        _report = report;
        _status =
            'Generated using ${command.growthPercent.toStringAsFixed(1)}% command for 3-year P&L + Balance Sheet + Cash Flow projection.';
      });
    } catch (error) {
      setState(() {
        _report = null;
        _status = error.toString();
      });
    }
  }

  Future<void> _submitForClient(UserModel client) async {
    final report = _report;
    if (report == null) return;
    final preparedBy = context.read<AuthController>().currentUser?.name ?? 'CA';
    await const ClientProvisionalReportService().submit(
      clientId: client.id,
      clientName: client.firmName.isEmpty ? client.name : client.firmName,
      preparedBy: preparedBy,
      report: report,
    );
    if (!mounted) return;
    setState(() {
      _submittedClientId = client.id;
      _status = 'Submitted for finalization. Review the projection, then finalize it for ${client.name}.';
    });
  }

  Future<void> _finalizeForClient(UserModel client) async {
    await const ClientProvisionalReportService().finalizeLatestForClient(client.id);
    if (!mounted) return;
    setState(() {
      _submittedClientId = null;
      _status = 'Finalized. ${client.name} can now view this report in Client Login > Provisional Reports.';
    });
  }

  double _asDouble(String text) {
    return double.tryParse(text.trim().replaceAll(',', '')) ?? 0;
  }

  void _reset() {
    setState(() {
      _turnoverCtrl.text = '0';
      _otherIncomeCtrl.text = '0';
      _cogsCtrl.text = '0';
      _operatingExpensesCtrl.text = '0';
      _depreciationCtrl.text = '0';
      _interestCtrl.text = '0';
      _taxRateCtrl.text = '25';
      _currentAssetsCtrl.text = '0';
      _fixedAssetsCtrl.text = '0';
      _currentLiabilitiesCtrl.text = '0';
      _longTermLiabilitiesCtrl.text = '0';
      _equityCtrl.text = '0';
      _cfoCtrl.text = '0';
      _cfiCtrl.text = '0';
      _cffCtrl.text = '0';
      _commandCtrl.text = '12';
      _searchCtrl.clear();
      _report = null;
      _uploadedSource = '';
      _view = _ProjectionView.all;
      _status =
          'Upload previous statement (PDF/image/text) or fill values manually, then enter growth % command (e.g., 15).';
    });
  }

  Future<void> _copyDraft() async {
    final report = _report;
    if (report == null) return;
    final rows = report.projections
        .map(
          (row) =>
              '${row.label}: Revenue ${_currency.format(row.totalIncome)}, '
              'PBT ${_currency.format(row.profitBeforeTax)}, '
              'PAT ${_currency.format(row.netProfit)}, '
              'Assets ${_currency.format(row.totalAssets)}, '
              'Liabilities ${_currency.format(row.totalLiabilities)}, '
              'Net Cash ${_currency.format(row.netCashFlow)}',
        )
        .join('\n');
    final text =
        'Quick Provisional Financial Projection\n'
        'Growth Command: ${report.growthPercent.toStringAsFixed(1)}%\n'
        'Base Turnover: ${_currency.format(report.base.turnover)}\n'
        'Base Income (incl other): ${_currency.format(report.base.turnover + report.base.otherIncome)}\n'
        'Base Assets: ${_currency.format(report.base.currentAssets + report.base.fixedAssets)}\n\n'
        '$rows';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft copied for client documentation.')),
    );
  }

  Future<void> _downloadJson() async {
    final report = _report;
    if (report == null) return;
    setState(() => _exporting = true);
    try {
      final payload = <String, dynamic>{
        'growthPercent': report.growthPercent,
        'years': report.years,
        'base': <String, dynamic>{
          'turnover': report.base.turnover,
          'otherIncome': report.base.otherIncome,
          'costOfGoodsSold': report.base.costOfGoodsSold,
          'operatingExpenses': report.base.operatingExpenses,
          'depreciation': report.base.depreciation,
          'interest': report.base.interest,
          'taxRatePercent': report.base.taxRatePercent,
          'currentAssets': report.base.currentAssets,
          'fixedAssets': report.base.fixedAssets,
          'currentLiabilities': report.base.currentLiabilities,
          'longTermLiabilities': report.base.longTermLiabilities,
          'equityOpening': report.base.equityOpening,
          'cashFlowOperating': report.base.cashFlowOperating,
          'cashFlowInvesting': report.base.cashFlowInvesting,
          'cashFlowFinancing': report.base.cashFlowFinancing,
        },
        'projection': report.projections
            .map(
              (y) => <String, dynamic>{
                'label': y.label,
                'turnover': y.turnover,
                'otherIncome': y.otherIncome,
                'totalIncome': y.totalIncome,
                'costOfGoodsSold': y.costOfGoodsSold,
                'operatingExpenses': y.operatingExpenses,
                'ebitda': y.ebitda,
                'depreciation': y.depreciation,
                'interest': y.interest,
                'profitBeforeTax': y.profitBeforeTax,
                'taxExpense': y.taxExpense,
                'netProfit': y.netProfit,
                'currentAssets': y.currentAssets,
                'fixedAssets': y.fixedAssets,
                'totalAssets': y.totalAssets,
                'currentLiabilities': y.currentLiabilities,
                'longTermLiabilities': y.longTermLiabilities,
                'totalLiabilities': y.totalLiabilities,
                'equityClosing': y.equityClosing,
                'cashFlowOperating': y.cashFlowOperating,
                'cashFlowInvesting': y.cashFlowInvesting,
                'cashFlowFinancing': y.cashFlowFinancing,
                'netCashFlow': y.netCashFlow,
              },
            )
            .toList(growable: false),
      };

      await downloadFile(
        fileName:
            'quick_provisional_projection_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
        bytes: Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
        ),
        mimeType: 'application/json',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projection JSON exported.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _downloadPdf() async {
    final report = _report;
    if (report == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = _buildProjectionPdf(report);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'quick_provisional_projection_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projection PDF ready for download/share.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Uint8List _buildProjectionPdf(FinancialProjectionReport report) {
    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;

    final titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final heading =
        PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    double y = 18;
    graphics.drawString(
      'Quick Provisional Financial Projection',
      titleFont,
      bounds: const Rect.fromLTWH(0, 0, 520, 20),
    );
    y += 24;
    graphics.drawString(
      'Generated: $date | Growth: ${report.growthPercent.toStringAsFixed(1)}%',
      bodyFont,
      bounds: Rect.fromLTWH(0, y, 520, 16),
    );
    y += 20;

    graphics.drawString('Summary (PAT / Assets / Net Cash)', heading,
        bounds: Rect.fromLTWH(0, y, 520, 16));
    y += 16;
    for (final year in report.projections) {
      graphics.drawString(
        '${year.label}: PAT ${_currency.format(year.netProfit)}, Assets ${_currency.format(year.totalAssets)}, Net Cash ${_currency.format(year.netCashFlow)}',
        bodyFont,
        bounds: Rect.fromLTWH(0, y, 520, 16),
      );
      y += 14;
    }

    final bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }
}

enum _ProjectionView { all, pnl, balanceSheet, cashFlow }

extension on _ProjectionView {
  String get label {
    switch (this) {
      case _ProjectionView.all:
        return 'All Statements';
      case _ProjectionView.pnl:
        return 'Profit & Loss';
      case _ProjectionView.balanceSheet:
        return 'Balance Sheet';
      case _ProjectionView.cashFlow:
        return 'Cash Flow';
    }
  }
}

class _LineDef {
  const _LineDef(this.label, this.pick);

  final String label;
  final double Function(FinancialProjectionYear year) pick;
}

class _StatementRow {
  const _StatementRow({required this.label, required this.values});

  final String label;
  final List<double> values;
}
