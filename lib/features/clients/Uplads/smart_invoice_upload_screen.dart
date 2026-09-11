// Smart Invoice Upload Screen – V2
//
// Layout (matches the V2 specification):
//   ┌──────────────────────────────────────────────────────────────┐
//   │  Upload Document  [Camera] [Image] [PDF] [Drag & Drop]       │
//   ├──────────────────────────────────────────────────────────────┤
//   │  AI Status  Reading Document ▶ Duplicate Check ▶ ... Ready   │
//   ├───────────────────────────────┬──────────────────────────────┤
//   │  Invoice Form (left)          │  Invoice Preview (right)     │
//   ├───────────────────────────────┴──────────────────────────────┤
//   │  AI Reason Panel + Confidence Scores                         │
//   ├──────────────────────────────────────────────────────────────┤
//   │  Missing Masters Panel (➕ one-click create)                 │
//   ├──────────────────────────────────────────────────────────────┤
//   │  Save Validation Panel                                       │
//   └──────────────────────────────────────────────────────────────┘

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/add_sales_invoice_screen.dart';
import 'package:chirag_accounting/features/purchase/presentation/pages/add_purchase_bill_screen.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/smart_invoice_engine.dart';
import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/features/products/product_service.dart';

// ─────────────────────────────────────────────────────────────────────────────

class SmartInvoiceUploadScreen extends StatefulWidget {
  final Uint8List? initialFileBytes;
  final String? initialFilePath;
  final String? initialFileName;

  const SmartInvoiceUploadScreen({
    super.key,
    this.initialFileBytes,
    this.initialFilePath,
    this.initialFileName,
  });

  @override
  State<SmartInvoiceUploadScreen> createState() =>
      _SmartInvoiceUploadScreenState();
}

class _SmartInvoiceUploadScreenState extends State<SmartInvoiceUploadScreen>
    with SingleTickerProviderStateMixin {
  // ── OCR & engine ──
  final InvoiceOcrService _ocrService = InvoiceOcrService();

  // ── State ──
  SmartInvoiceStage _currentStage = SmartInvoiceStage.idle;
  SmartInvoiceResult? _result;
  String? _errorMsg;
  bool _isBusy = false;

  // ── File ──
  // ignore: unused_field
  String? _filePath;
  // ignore: unused_field
  Uint8List? _fileBytes;
  String _fileName = '';

  // ── Pipeline stage log ──
  final List<SmartInvoiceStage> _completedStages = [];

  // ── Tab controller for side-by-side on narrow screens ──
  late final TabController _tabController;

  // ── Form controllers (prefilled after analysis) ──
  final _invoiceNoCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Handle initial file passed from external context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFileBytes != null &&
          widget.initialFileBytes!.isNotEmpty) {
        _runPipeline(
          bytes: widget.initialFileBytes,
          path: widget.initialFilePath,
          name: widget.initialFileName ?? 'upload',
        );
      } else if (isUsableLocalFilePath(widget.initialFilePath)) {
        _runPipeline(
          path: widget.initialFilePath,
          name: widget.initialFileName ?? 'upload',
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ocrService.dispose();
    _invoiceNoCtrl.dispose();
    _dateCtrl.dispose();
    _partyCtrl.dispose();
    _gstinCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pipeline
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _runPipeline({
    String? path,
    Uint8List? bytes,
    String? name,
  }) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _result = null;
      _errorMsg = null;
      _currentStage = SmartInvoiceStage.readingDocument;
      _completedStages.clear();
    });

    try {
      // ── Step 1: OCR ──
      final fileName = (name ?? '').trim().isNotEmpty ? name! : 'upload';
      final ext = _ext(fileName);
      String ocrText;

      if (isUsableLocalFilePath(path)) {
        final file = File(path!);
        ocrText = ext == 'pdf'
            ? await _ocrService.extractTextFromPdf(file, maxPagesToScan: 8, rasterDpi: 220)
            : await _ocrService.extractTextFromImage(file);
      } else if (bytes != null && bytes.isNotEmpty) {
        ocrText = ext == 'pdf'
            ? await _ocrService.extractTextFromPdfBytes(bytes, maxPagesToScan: 8, rasterDpi: 220)
            : await _ocrService.extractTextFromImageBytes(bytes, fileName: fileName);
      } else {
        throw Exception('No file data available for OCR.');
      }

      // ── Step 2: Build engine with live master data ──
      final engine = _buildEngine();

      // ── Step 3: Run all 12 stages ──
      final result = await engine.run(ocrText, onStage: (stage) {
        if (mounted) {
          setState(() {
            if (!_completedStages.contains(_currentStage) &&
                _currentStage != SmartInvoiceStage.idle &&
                _currentStage != SmartInvoiceStage.error) {
              _completedStages.add(_currentStage);
            }
            _currentStage = stage;
          });
        }
      });

      // ── Step 4: Prefill form ──
      _prefillForm(result.parsedData);

      setState(() {
        _result = result;
        _isBusy = false;
        _filePath = path;
        _fileBytes = bytes;
        _fileName = fileName;
        if (!_completedStages.contains(SmartInvoiceStage.confidenceCalc)) {
          _completedStages.add(SmartInvoiceStage.confidenceCalc);
        }
        _currentStage = SmartInvoiceStage.ready;
      });
    } catch (e) {
      setState(() {
        _isBusy = false;
        _currentStage = SmartInvoiceStage.error;
        _errorMsg = e.toString();
      });
    }
  }

  SmartInvoiceEngine _buildEngine() {
    try {
      final customerSvc = context.read<CustomerService>();
      final vendorSvc = context.read<VendorService>();
      final productSvc = context.read<ProductService>();

      return SmartInvoiceEngine(
        companyGstins: const [], // populated via profile screen when available
        customerNames: customerSvc.customers
            .map((c) => c.customerName)
            .toList(),
        customerGstins: customerSvc.customers
            .map((c) => c.gstNumber)
            .where((g) => g.isNotEmpty)
            .toList(),
        vendorNames: vendorSvc.vendors.map((v) => v.vendorName).toList(),
        vendorGstins: vendorSvc.vendors
            .map((v) => v.gstNumber)
            .where((g) => g.isNotEmpty)
            .toList(),
        productMasterNames:
            productSvc.products.map((p) => p.productName).toList(),
      );
    } catch (_) {
      return SmartInvoiceEngine();
    }
  }

  void _prefillForm(ParsedInvoiceData data) {
    _invoiceNoCtrl.text = data.billNumber;
    _dateCtrl.text = data.billDate;
    _partyCtrl.text = data.partyName;
    _gstinCtrl.text = data.gstin;
    _amountCtrl.text =
        data.totalAmount > 0 ? data.totalAmount.toStringAsFixed(2) : '';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // File Pickers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    if (!mounted) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _runPipeline(
        path: kIsWeb ? null : picked.path,
        bytes: bytes,
        name: picked.name,
      );
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      await _runPipeline(
        path: f.path,
        bytes: f.bytes,
        name: f.name,
      );
    } catch (e) {
      _showError('Image pick error: $e');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      await _runPipeline(
        path: f.path,
        bytes: f.bytes,
        name: f.name,
      );
    } catch (e) {
      _showError('PDF pick error: $e');
    }
  }

  Future<void> _pickAny() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      await _runPipeline(
        path: f.path,
        bytes: f.bytes,
        name: f.name,
      );
    } catch (e) {
      _showError('File pick error: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation to entry screens
  // ─────────────────────────────────────────────────────────────────────────

  void _openEntryScreen() {
    final r = _result;
    if (r == null) return;
    final parsed = r.parsedData;
    final analysis = OcrDocumentAnalysis(
      kind: r.detectedKind,
      confidence: r.confidence.overall,
      signals: r.classificationReasons,
    );

    switch (r.detectedKind) {
      case OcrDocumentKind.salesInvoice:
      case OcrDocumentKind.creditNote:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddSalesInvoiceScreen(
              prefillParsedData: parsed,
              prefillAnalysis: analysis,
              autoEntryMode: true,
            ),
          ),
        );
        break;
      case OcrDocumentKind.purchaseBill:
      case OcrDocumentKind.debitNote:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddPurchaseBillScreen(
              prefillParsedData: parsed,
              prefillAnalysis: analysis,
              autoEntryMode: true,
            ),
          ),
        );
        break;
      default:
        _showError('Please open the appropriate module manually for this document type.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _ext(String name) {
    final idx = name.lastIndexOf('.');
    if (idx < 0 || idx >= name.length - 1) return '';
    return name.substring(idx + 1).toLowerCase();
  }

  String _kindLabel(OcrDocumentKind kind) {
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return 'Sales Invoice';
      case OcrDocumentKind.purchaseBill:
        return 'Purchase Bill';
      case OcrDocumentKind.creditNote:
        return 'Credit Note';
      case OcrDocumentKind.debitNote:
        return 'Debit Note';
      case OcrDocumentKind.chequeGiven:
        return 'Cheque Given';
      case OcrDocumentKind.chequeReceived:
        return 'Cheque Received';
      case OcrDocumentKind.paymentVoucher:
        return 'Payment Voucher';
      case OcrDocumentKind.receiptVoucher:
        return 'Receipt Voucher';
      case OcrDocumentKind.unknown:
        return 'Unknown';
    }
  }

  Color _confidenceColor(double c) {
    if (c >= 0.95) return Colors.green;
    if (c >= 0.75) return Colors.orange;
    return Colors.red;
  }

  String _pct(double c) => '${(c * 100).round()}%';

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Invoice Upload'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUploadArea(),
            const SizedBox(height: 16),
            _buildAiStatusPanel(),
            if (_result != null) ...[
              const SizedBox(height: 16),
              wide ? _buildSideBySideWide() : _buildSideBySideNarrow(),
              const SizedBox(height: 16),
              _buildAiReasonPanel(),
              const SizedBox(height: 16),
              _buildConfidencePanel(),
              if (_result!.duplicateResult.isDuplicate) ...[
                const SizedBox(height: 16),
                _buildDuplicateWarning(),
              ],
              if (_result!.missingMasters.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildMissingMastersPanel(),
              ],
              const SizedBox(height: 16),
              _buildSaveValidationPanel(),
            ],
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Upload Area ──────────────────────────────────────────────────────────

  Widget _buildUploadArea() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Document',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _uploadBtn(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: _isBusy ? null : _pickCamera,
                  color: const Color(0xFF1A237E),
                ),
                _uploadBtn(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onTap: _isBusy ? null : _pickImage,
                  color: const Color(0xFF0D47A1),
                ),
                _uploadBtn(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  onTap: _isBusy ? null : _pickPdf,
                  color: const Color(0xFFB71C1C),
                ),
                _uploadBtn(
                  icon: Icons.upload_file_outlined,
                  label: 'Browse / Drop',
                  onTap: _isBusy ? null : _pickAny,
                  color: const Color(0xFF1B5E20),
                ),
              ],
            ),
            if (_fileName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _fileName,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _uploadBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: onTap == null ? Colors.grey.shade300 : color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  // ── AI Status Panel ──────────────────────────────────────────────────────

  static const List<SmartInvoiceStage> _pipelineStages = [
    SmartInvoiceStage.readingDocument,
    SmartInvoiceStage.duplicateCheck,
    SmartInvoiceStage.qrDetection,
    SmartInvoiceStage.classification,
    SmartInvoiceStage.gstValidation,
    SmartInvoiceStage.masterMatching,
    SmartInvoiceStage.productMatching,
    SmartInvoiceStage.ledgerSuggestion,
    SmartInvoiceStage.taxValidation,
    SmartInvoiceStage.confidenceCalc,
    SmartInvoiceStage.ready,
  ];

  Widget _buildAiStatusPanel() {
    if (_currentStage == SmartInvoiceStage.idle && _result == null) {
      return const SizedBox.shrink();
    }
    return Card(
      color: const Color(0xFFF3F4F6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF1A237E)),
                const SizedBox(width: 8),
                const Text(
                  'AI Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Spacer(),
                if (_isBusy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _pipelineStages.map((stage) {
                final isDone = _completedStages.contains(stage) ||
                    _currentStage == SmartInvoiceStage.ready;
                final isCurrent =
                    _currentStage == stage && _isBusy;
                return _stageChip(
                  label: stage.label,
                  isDone: isDone,
                  isCurrent: isCurrent,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageChip({
    required String label,
    required bool isDone,
    required bool isCurrent,
  }) {
    Color bg;
    Color fg;
    if (isDone) {
      bg = const Color(0xFF1B5E20);
      fg = Colors.white;
    } else if (isCurrent) {
      bg = const Color(0xFF1A237E);
      fg = Colors.white;
    } else {
      bg = const Color(0xFFE0E0E0);
      fg = Colors.black54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDone)
            const Icon(Icons.check, size: 12, color: Colors.white)
          else if (isCurrent)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            ),
          if (isDone || isCurrent) const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: fg)),
        ],
      ),
    );
  }

  // ── Side-by-side: Wide ───────────────────────────────────────────────────

  Widget _buildSideBySideWide() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildFormPanel()),
          const SizedBox(width: 16),
          Expanded(child: _buildPreviewPanel()),
        ],
      ),
    );
  }

  Widget _buildSideBySideNarrow() {
    final height = MediaQuery.sizeOf(context).height;
    final tabViewHeight = (height * 0.62).clamp(360.0, 620.0);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A237E),
          indicatorColor: const Color(0xFF1A237E),
          tabs: const [
            Tab(text: 'Invoice Form'),
            Tab(text: 'Preview'),
          ],
        ),
        SizedBox(
          height: tabViewHeight,
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(child: _buildFormPanel()),
              SingleChildScrollView(child: _buildPreviewPanel()),
            ],
          ),
        ),
      ],
    );
  }

  // ── Form Panel ───────────────────────────────────────────────────────────

  Widget _buildFormPanel() {
    final r = _result!;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Form',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _formRow('Invoice No.', _invoiceNoCtrl,
                check: r.parsedData.billNumber.isNotEmpty),
            _formRow('Date', _dateCtrl,
                check: r.parsedData.billDate.isNotEmpty),
            _formRow('Party', _partyCtrl,
                check: r.partyMatch != null && !r.partyMatch!.isNewMaster,
                warn: r.partyMatch?.isNewMaster == true),
            _formRow('GSTIN', _gstinCtrl,
                check: r.gstResult.formatValid),
            _formRow('Total Amount', _amountCtrl,
                check: r.parsedData.totalAmount > 0),
            const SizedBox(height: 6),
            _buildMatchConfidencePanel(r),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: _openEntryScreen,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                'Open ${_kindLabel(r.detectedKind)} Entry',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formRow(
    String label,
    TextEditingController ctrl, {
    bool check = false,
    bool warn = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            check
                ? Icons.check_circle
                : warn
                    ? Icons.warning_amber_rounded
                    : Icons.radio_button_unchecked,
            color: check
                ? Colors.green
                : warn
                    ? Colors.orange
                    : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchConfidencePanel(SmartInvoiceResult r) {
    final partyConfidence = r.partyMatch?.confidence ?? 0;
    final productAvg = r.productMatches.isEmpty
        ? 0.0
        : r.productMatches
                .map((p) => p.confidence)
                .reduce((a, b) => a + b) /
            r.productMatches.length;
    final duplicateScore = r.duplicateResult.score;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Match Quality',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _matchBadge(
              label: 'Party Match',
              score: partyConfidence,
              suffix: r.partyMatch == null
                  ? 'Not found'
                  : (r.partyMatch!.isNewMaster ? 'New' : 'Existing'),
            ),
            _matchBadge(
              label: 'Item Match',
              score: productAvg,
              suffix: '${r.productMatches.length} item(s)',
            ),
            _matchBadge(
              label: 'Duplicate Risk',
              score: duplicateScore,
              suffix: r.duplicateResult.isDuplicate ? 'Possible duplicate' : 'Clear',
              invertScale: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _matchBadge({
    required String label,
    required double score,
    required String suffix,
    bool invertScale = false,
  }) {
    final value = invertScale ? (1 - score).clamp(0.0, 1.0) : score;
    final color = _matchBandColor(value);
    final pct = '${(score * 100).round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '$pct • $suffix',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _matchBandColor(double value) {
    if (value >= 0.95) return Colors.green;
    if (value >= 0.80) return Colors.orange;
    return Colors.red;
  }

  // ── Preview Panel ────────────────────────────────────────────────────────

  Widget _buildPreviewPanel() {
    final r = _result!;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Preview',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            _previewRow('Document', _kindLabel(r.detectedKind)),
            if (r.parsedData.billNumber.isNotEmpty)
              _previewRow('Invoice No.', r.parsedData.billNumber),
            if (r.parsedData.billDate.isNotEmpty)
              _previewRow('Date', r.parsedData.billDate),
            if (r.parsedData.partyName.isNotEmpty)
              _previewRow('Party', r.parsedData.partyName),
            if (r.parsedData.gstin.isNotEmpty)
              _previewRow('GSTIN', r.parsedData.gstin),
            if (r.gstResult.detectedSellerGstin.isNotEmpty)
              _previewRow('Seller GSTIN', r.gstResult.detectedSellerGstin),
            if (r.parsedData.totalAmount > 0)
              _previewRow('Total',
                  '₹ ${r.parsedData.totalAmount.toStringAsFixed(2)}'),
            if (r.taxResult.extractedCgst > 0)
              _previewRow(
                  'CGST', '₹ ${r.taxResult.extractedCgst.toStringAsFixed(2)}'),
            if (r.taxResult.extractedSgst > 0)
              _previewRow(
                  'SGST', '₹ ${r.taxResult.extractedSgst.toStringAsFixed(2)}'),
            if (r.taxResult.extractedIgst > 0)
              _previewRow(
                  'IGST', '₹ ${r.taxResult.extractedIgst.toStringAsFixed(2)}'),
            if (r.qrIrnValue != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.qr_code, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'IRN: ${r.qrIrnValue!.substring(0, r.qrIrnValue!.length.clamp(0, 20))}...',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (r.parsedData.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(),
              const Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              ...r.parsedData.items.take(5).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${item.name}  ×${item.quantity}  @ ₹${item.rate.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
              if (r.parsedData.items.length > 5)
                Text(
                  '+${r.parsedData.items.length - 5} more items',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    final labelWidth = MediaQuery.sizeOf(context).width < 420 ? 88.0 : 110.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Reason Panel ──────────────────────────────────────────────────────

  Widget _buildAiReasonPanel() {
    final r = _result!;
    return Card(
      elevation: 1,
      color: const Color(0xFFF8F9FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.indigo.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  color: Color(0xFF1A237E),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Reason',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _reasonRow('Classification', _kindLabel(r.detectedKind), Colors.indigo),
            _reasonRow('Reason', r.detectionReason, Colors.black87),
            if (r.qrIrnValue != null)
              _reasonRow('QR / IRN', 'Verified', Colors.green),
            if (r.partyMatch != null && !r.partyMatch!.isNewMaster)
              _reasonRow(
                'Party',
                '${r.partyMatch!.matchedName} – Exists',
                Colors.green,
              ),
            if (r.gstResult.sellerGstinBelongsToCompany ||
                r.gstResult.buyerGstinBelongsToCompany)
              _reasonRow(
                'GST',
                r.gstResult.sellerGstinBelongsToCompany
                    ? 'Seller GST belongs to your company'
                    : 'Buyer GST belongs to your company',
                Colors.teal,
              ),
            if (r.ledgerSuggestion != null)
              _reasonRow(
                'Ledger',
                '${r.ledgerSuggestion!.ledgerName} – ${r.ledgerSuggestion!.reason}',
                Colors.blueGrey,
              ),
            for (final reason in r.classificationReasons.take(3))
              _reasonRow('Signal', reason, Colors.grey.shade700),
          ],
        ),
      ),
    );
  }

  Widget _reasonRow(String label, String value, Color valueColor) {
    final labelWidth = MediaQuery.sizeOf(context).width < 420 ? 82.0 : 100.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confidence Panel ─────────────────────────────────────────────────────

  Widget _buildConfidencePanel() {
    final c = _result!.confidence;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Confidence',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _confChip('Invoice', c.invoice),
                _confChip('Customer', c.customer),
                _confChip('Products', c.products),
                _confChip('GST', c.gst),
                _confChip('Total', c.total),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall: ${_pct(c.overall)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _confidenceColor(c.overall),
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: c.overall,
                        backgroundColor: Colors.grey.shade200,
                        color: _confidenceColor(c.overall),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _verificationBadge(_result!.verificationLevel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _confChip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _confidenceColor(value).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _confidenceColor(value).withValues(alpha: 0.40)),
      ),
      child: Column(
        children: [
          Text(
            _pct(value),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _confidenceColor(value),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _verificationBadge(SmartVerificationLevel level) {
    String label;
    Color color;
    IconData icon;
    switch (level) {
      case SmartVerificationLevel.autoVerified:
        label = 'Auto-Verified';
        color = Colors.green;
        icon = Icons.verified;
        break;
      case SmartVerificationLevel.reviewRequired:
        label = 'Review Required';
        color = Colors.orange;
        icon = Icons.rate_review_outlined;
        break;
      case SmartVerificationLevel.manualRequired:
        label = 'Manual Verify';
        color = Colors.red;
        icon = Icons.person_outlined;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Duplicate Warning ────────────────────────────────────────────────────

  Widget _buildDuplicateWarning() {
    final d = _result!.duplicateResult;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Possible Duplicate',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange),
                ),
                Text(
                  'Already uploaded${d.matchedDate != null ? " on ${d.matchedDate}" : ""}${d.matchedInvoiceNumber != null ? " · Invoice ${d.matchedInvoiceNumber}" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Missing Masters Panel ────────────────────────────────────────────────

  Widget _buildMissingMastersPanel() {
    final r = _result!;
    return Card(
      elevation: 1,
      color: const Color(0xFFFFFDE7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFFFF176)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text(
                  'New Masters Found',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...r.missingMasters.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.type.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m.suggestedName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (m.extra.isNotEmpty)
                      Text(
                        m.extra,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A237E),
                        side: const BorderSide(color: Color(0xFF1A237E)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showCreateMasterDialog(m),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Create', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMasterDialog(SmartMissingMaster master) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create ${master.type.toUpperCase()}'),
        content: Text(
          'Creating ${master.type}: "${master.suggestedName}"'
          '${master.extra.isNotEmpty ? "\n${master.extra}" : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to create master screen based on type.
              _openEntryScreen();
            },
            child: const Text('Open Entry Screen'),
          ),
        ],
      ),
    );
  }

  // ── Save Validation Panel ────────────────────────────────────────────────

  Widget _buildSaveValidationPanel() {
    final r = _result!;
    final checks = <_ValidationCheck>[
      _ValidationCheck(
        'Invoice',
        r.parsedData.billNumber.isNotEmpty && r.parsedData.billDate.isNotEmpty,
      ),
      _ValidationCheck('GST', r.gstResult.formatValid),
      _ValidationCheck('Duplicate', !r.duplicateResult.isDuplicate),
      _ValidationCheck('Products', r.parsedData.items.isNotEmpty),
      _ValidationCheck('Ledger', r.ledgerSuggestion != null),
      _ValidationCheck('Tax', r.taxResult.taxCalcMatch || r.taxResult.extractedTotal > 0),
      _ValidationCheck(
        'Customer',
        r.partyMatch != null && !r.partyMatch!.isNewMaster,
      ),
    ];
    final allPass = checks.every((c) => c.pass);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save Validation',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: checks
                  .map(
                    (c) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c.pass ? Icons.check_circle : Icons.cancel_outlined,
                          color: c.pass ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(c.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            if (r.taxResult.warnings.isNotEmpty)
              ...r.taxResult.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          w,
                          style: const TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    allPass ? const Color(0xFF1B5E20) : Colors.grey,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: allPass ? _openEntryScreen : null,
              icon: Icon(
                allPass ? Icons.save_outlined : Icons.lock_outline,
                size: 18,
              ),
              label: Text(
                allPass ? 'Save Invoice' : 'Fix Issues Before Saving',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error card ───────────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg ?? 'An unexpected error occurred.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ValidationCheck {
  final String label;
  final bool pass;
  const _ValidationCheck(this.label, this.pass);
}
