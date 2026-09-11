import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/location/standard_address.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_item.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/sales/models/sales_item.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/features/services/smart_invoice_engine.dart';
import 'package:chirag_accounting/shared/widgets/address_location_form.dart';

/// Which accounting treatment this workspace instance should apply.
/// The Invoice Intelligence Engine (OCR + SmartInvoiceEngine) is shared
/// between both voucher types; only persistence differs.
enum InvoiceWorkspaceVoucherType { sales, purchase }

enum _FieldStatus { verified, review, attention, neutral }

extension on _FieldStatus {
  Color get color {
    switch (this) {
      case _FieldStatus.verified:
        return const Color(0xFF2E7D32);
      case _FieldStatus.review:
        return const Color(0xFFF9A825);
      case _FieldStatus.attention:
        return const Color(0xFFC62828);
      case _FieldStatus.neutral:
        return const Color(0xFF90A4AE);
    }
  }

  IconData get icon {
    switch (this) {
      case _FieldStatus.verified:
        return Icons.check_circle;
      case _FieldStatus.review:
        return Icons.warning_rounded;
      case _FieldStatus.attention:
        return Icons.error_rounded;
      case _FieldStatus.neutral:
        return Icons.circle_outlined;
    }
  }
}

_FieldStatus _statusForConfidence(double confidence, {bool hasValue = true}) {
  if (!hasValue) return _FieldStatus.attention;
  if (confidence >= 0.85) return _FieldStatus.verified;
  if (confidence >= 0.55) return _FieldStatus.review;
  return _FieldStatus.attention;
}

class _WorkspaceLineItem {
  _WorkspaceLineItem({
    required this.id,
    String name = '',
    String hsn = '',
    String unit = 'Nos',
    String qty = '1',
    String rate = '0',
    String discount = '0',
    String gst = '18',
    this.confidence = 1,
  }) : nameCtrl = TextEditingController(text: name),
       hsnCtrl = TextEditingController(text: hsn),
       unitCtrl = TextEditingController(text: unit),
       qtyCtrl = TextEditingController(text: qty),
       rateCtrl = TextEditingController(text: rate),
       discountCtrl = TextEditingController(text: discount),
       gstCtrl = TextEditingController(text: gst);

  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController hsnCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController discountCtrl;
  final TextEditingController gstCtrl;
  double confidence;

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get rate => double.tryParse(rateCtrl.text.trim()) ?? 0;
  double get discount => double.tryParse(discountCtrl.text.trim()) ?? 0;
  double get gstPercentage => double.tryParse(gstCtrl.text.trim()) ?? 0;
  double get taxableValue => (quantity * rate) - discount;
  double get gstAmount => taxableValue * gstPercentage / 100;
  double get lineTotal => taxableValue + gstAmount;

  void dispose() {
    nameCtrl.dispose();
    hsnCtrl.dispose();
    unitCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    discountCtrl.dispose();
    gstCtrl.dispose();
  }
}

class InvoiceIntelligenceWorkspaceScreen extends StatefulWidget {
  const InvoiceIntelligenceWorkspaceScreen({
    super.key,
    required this.voucherType,
  });

  final InvoiceWorkspaceVoucherType voucherType;

  @override
  State<InvoiceIntelligenceWorkspaceScreen> createState() =>
      _InvoiceIntelligenceWorkspaceScreenState();
}

class _InvoiceIntelligenceWorkspaceScreenState
    extends State<InvoiceIntelligenceWorkspaceScreen> {
  late InvoiceWorkspaceVoucherType _voucherType;
  final _ocrService = InvoiceOcrService();
  final _engine = SmartInvoiceEngine();
  final _imagePicker = ImagePicker();
  final _transformController = TransformationController();

  Uint8List? _fileBytes;
  String _fileName = '';
  bool _isPdf = false;

  bool _isProcessing = false;
  SmartInvoiceStage _stage = SmartInvoiceStage.idle;
  ParsedInvoiceData? _parsed;
  SmartInvoiceResult? _smart;
  bool _saving = false;

  int _quarterTurns = 0;
  double _zoom = 1.0;

  final _invoiceNoCtrl = TextEditingController();
  final _invoiceDateCtrl = TextEditingController();
  final _partyNameCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _billingAddress = AddressFormController();
  final _shippingAddress = AddressFormController();
  final _paymentTermsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _roundOffCtrl = TextEditingController(text: '0');

  final List<_WorkspaceLineItem> _items = [];

  @override
  void initState() {
    super.initState();
    _voucherType = widget.voucherType;
    _invoiceDateCtrl.text = _dateToText(DateTime.now());
    _items.add(_WorkspaceLineItem(id: _newId()));
  }

  @override
  void dispose() {
    _transformController.dispose();
    _invoiceNoCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _partyNameCtrl.dispose();
    _gstinCtrl.dispose();
    _billingAddress.dispose();
    _shippingAddress.dispose();
    _paymentTermsCtrl.dispose();
    _notesCtrl.dispose();
    _roundOffCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _isSales => _voucherType == InvoiceWorkspaceVoucherType.sales;

  String get _title => _isSales ? 'Sales Voucher' : 'Purchase Voucher';

  String _dateToText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ── Upload / Capture ────────────────────────────────────────────────────

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('Could not read the selected file.', isError: true);
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    await _loadDocument(bytes, fileName: file.name, isPdf: ext == 'pdf');
  }

  Future<void> _captureFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      _showSnack('Captured image was empty.', isError: true);
      return;
    }
    await _loadDocument(bytes, fileName: image.name, isPdf: false);
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      _showSnack('Selected image was empty.', isError: true);
      return;
    }
    await _loadDocument(bytes, fileName: image.name, isPdf: false);
  }

  Future<void> _loadDocument(
    Uint8List bytes, {
    required String fileName,
    required bool isPdf,
  }) async {
    setState(() {
      _fileBytes = bytes;
      _fileName = fileName;
      _isPdf = isPdf;
      _isProcessing = true;
      _stage = SmartInvoiceStage.readingDocument;
      _quarterTurns = 0;
      _zoom = 1.0;
    });
    _transformController.value = Matrix4.identity();
    await _runIntelligence(bytes, fileName: fileName);
  }

  Future<void> _runIntelligence(
    Uint8List bytes, {
    required String fileName,
  }) async {
    try {
      final parsed = await _ocrService.extractStructuredInvoiceData(
        bytes,
        fileName: fileName,
      );
      if (parsed == null) {
        setState(() => _isProcessing = false);
        _showSnack(
          'Could not extract data automatically. Please enter details manually.',
          isError: true,
        );
        return;
      }
      final ocrText = parsed.rawText.trim().isNotEmpty
          ? parsed.rawText
          : _synthesizeTextFromParsed(parsed);
      final result = await _engine.run(
        ocrText,
        onStage: (stage) {
          if (mounted) setState(() => _stage = stage);
        },
      );
      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _smart = result;
        _isProcessing = false;
        _populateFromParsed(parsed, result);
        if (result.detectedKind == OcrDocumentKind.purchaseBill) {
          _voucherType = InvoiceWorkspaceVoucherType.purchase;
        } else if (result.detectedKind == OcrDocumentKind.salesInvoice) {
          _voucherType = InvoiceWorkspaceVoucherType.sales;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack(
        'Automatic extraction failed. You can still enter details manually.',
        isError: true,
      );
    }
  }

  String _synthesizeTextFromParsed(ParsedInvoiceData parsed) {
    return [
      parsed.partyName,
      parsed.gstin,
      parsed.billNumber,
      parsed.billDate,
      parsed.totalAmount.toString(),
    ].join('\n');
  }

  void _populateFromParsed(ParsedInvoiceData parsed, SmartInvoiceResult smart) {
    _invoiceNoCtrl.text = parsed.billNumber;
    if (parsed.billDate.trim().isNotEmpty) {
      _invoiceDateCtrl.text = parsed.billDate;
    }
    _partyNameCtrl.text = parsed.partyName;
    _gstinCtrl.text = parsed.gstin;
    _billingAddress.addressLine1.text = parsed.partyAddress;
    _shippingAddress.addressLine1.text = parsed.partyAddress;

    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    if (parsed.items.isEmpty) {
      _items.add(_WorkspaceLineItem(id: _newId(), confidence: 0));
    } else {
      for (final item in parsed.items) {
        _items.add(
          _WorkspaceLineItem(
            id: _newId(),
            name: item.name,
            hsn: item.hsnCode,
            unit: item.unit.isEmpty ? 'Nos' : item.unit,
            qty: item.quantity == 0 ? '1' : item.quantity.toString(),
            rate: item.rate.toString(),
            gst: item.gstPercentage == 0
                ? '18'
                : item.gstPercentage.toString(),
            confidence: item.confidence == 0
                ? parsed.extractionConfidence
                : item.confidence,
          ),
        );
      }
    }
  }

  String _newId() =>
      'ln_${DateTime.now().microsecondsSinceEpoch}_${_items.length}';

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ── Confidence helpers ──────────────────────────────────────────────────

  double _confidenceFor(String field) {
    final parsed = _parsed;
    if (parsed == null) return 1;
    return parsed.confidenceFor(field, fallback: parsed.extractionConfidence);
  }

  int get _flaggedFieldCount {
    if (_parsed == null) return 0;
    var count = 0;
    final checks = <MapEntry<String, TextEditingController>>[
      MapEntry('billNumber', _invoiceNoCtrl),
      MapEntry('billDate', _invoiceDateCtrl),
      MapEntry('partyName', _partyNameCtrl),
      MapEntry('gstin', _gstinCtrl),
    ];
    for (final check in checks) {
      final status = _statusForConfidence(
        _confidenceFor(check.key),
        hasValue: check.value.text.trim().isNotEmpty,
      );
      if (status != _FieldStatus.verified) count++;
    }
    final total = _smart?.taxResult;
    if (total != null && !total.taxCalcMatch) count++;
    if (_smart?.duplicateResult.isDuplicate == true) count++;
    return count;
  }

  // ── Totals ──────────────────────────────────────────────────────────────

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + (item.quantity * item.rate));
  double get _itemDiscount =>
      _items.fold(0.0, (sum, item) => sum + item.discount);
  double get _taxableValue =>
      _items.fold(0.0, (sum, item) => sum + item.taxableValue);
  double get _totalGst =>
      _items.fold(0.0, (sum, item) => sum + item.gstAmount);
  double get _roundOff => double.tryParse(_roundOffCtrl.text.trim()) ?? 0;
  double get _grandTotal => _taxableValue + _totalGst + _roundOff;

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          '$_title  •  Invoice # ${_invoiceNoCtrl.text.isEmpty ? '—' : _invoiceNoCtrl.text}',
        ),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _confirmAndSave,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _buildWorkspace(),
    );
  }

  Widget _buildWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final dataPanel = _buildDataEntryPanel();
        final docPanel = _buildDocumentPanel();
        if (!wide) {
          return Column(
            children: [
              SizedBox(height: 320, child: docPanel),
              const Divider(height: 1),
              Expanded(child: dataPanel),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 6, child: dataPanel),
            const VerticalDivider(width: 1),
            Expanded(flex: 4, child: docPanel),
          ],
        );
      },
    );
  }

  // ── Document panel (40%) ─────────────────────────────────────────────────

  Widget _buildDocumentPanel() {
    final hasRealBytes = _fileBytes != null && _fileBytes!.isNotEmpty;
    return Container(
      color: const Color(0xFFECEFF1),
      child: Column(
        children: [
          Expanded(
            child: !hasRealBytes
                ? _buildUploadPanel()
                : _isPdf
                ? _buildPdfPreview()
                : _buildImagePreview(),
          ),
          if (hasRealBytes) _buildDocumentToolbar(),
        ],
      ),
    );
  }

  Widget _buildUploadPanel() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Color(0xFF0A3A86),
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload Original Invoice',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A3A86),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'PDF, photo or scan. Printed and handwritten invoices are '
              'supported — fields are auto-mapped into the form on the left.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF486581), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _pickFromFiles,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload File'),
                ),
                OutlinedButton.icon(
                  onPressed: _captureFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Scan / Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPreview() {
    return Transform.rotate(
      angle: _quarterTurns * 1.5708,
      child: PdfPreview(
        build: (_) async => _fileBytes!,
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        useActions: false,
      ),
    );
  }

  Widget _buildImagePreview() {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.5,
      maxScale: 4,
      child: Center(
        child: RotatedBox(
          quarterTurns: _quarterTurns,
          child: Transform.scale(
            scale: _zoom,
            child: Image.memory(_fileBytes!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            onPressed: () =>
                setState(() => _zoom = (_zoom - 0.2).clamp(0.4, 3.0)),
          ),
          Text('${(_zoom * 100).round()}%'),
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            onPressed: () =>
                setState(() => _zoom = (_zoom + 0.2).clamp(0.4, 3.0)),
          ),
          IconButton(
            tooltip: 'Rotate',
            icon: const Icon(Icons.rotate_right),
            onPressed: () =>
                setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
          ),
          IconButton(
            tooltip: 'Fit / Reset',
            icon: const Icon(Icons.fit_screen_outlined),
            onPressed: () {
              _transformController.value = Matrix4.identity();
              setState(() => _zoom = 1.0);
            },
          ),
          IconButton(
            tooltip: 'View full page',
            icon: const Icon(Icons.fullscreen),
            onPressed: _openFullPage,
          ),
        ],
      ),
    );
  }

  void _openFullPage() {
    if (_fileBytes == null || _fileBytes!.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: _isPdf
              ? PdfPreview(
                  build: (_) async => _fileBytes!,
                  allowPrinting: false,
                  allowSharing: false,
                  useActions: false,
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.memory(_fileBytes!, fit: BoxFit.contain),
                ),
        ),
      ),
    );
  }

  // ── Data entry panel (60%) ───────────────────────────────────────────────

  Widget _buildDataEntryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isProcessing) _buildProcessingBanner(),
        if (!_isProcessing && _flaggedFieldCount > 0) _buildVerificationBanner(),
        if (!_isProcessing &&
            _smart != null &&
            _smart!.duplicateResult.isDuplicate)
          _buildDuplicateBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _sectionBasic(),
              const SizedBox(height: 10),
              _sectionItems(),
              const SizedBox(height: 10),
              _sectionTax(),
              const SizedBox(height: 10),
              _sectionAccounting(),
              const SizedBox(height: 10),
              _sectionAdditional(),
              const SizedBox(height: 16),
              _buildActionRow(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE3F2FD),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(_stage.label, style: const TextStyle(color: Color(0xFF0D47A1))),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF6C00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_flaggedFieldCount field${_flaggedFieldCount == 1 ? '' : 's'} require verification.',
              style: const TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFEBEE),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Color(0xFFC62828)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Possible duplicate invoice detected. Please verify before saving.',
              style: TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = true,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD9E2F2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: const Color(0xFF0A3A86)),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A3A86),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: children,
        ),
      ),
    );
  }

  Widget _sectionBasic() {
    return _sectionCard(
      title: 'Basic Details',
      icon: Icons.description_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _verifiedField(
                label: _isSales ? 'Customer Name' : 'Supplier Name',
                controller: _partyNameCtrl,
                confidence: _confidenceFor('partyName'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _verifiedField(
                label: 'GSTIN',
                controller: _gstinCtrl,
                confidence: _confidenceFor('gstin'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _verifiedField(
                label: 'Invoice No.',
                controller: _invoiceNoCtrl,
                confidence: _confidenceFor('billNumber'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _verifiedField(
                label: 'Invoice Date',
                controller: _invoiceDateCtrl,
                confidence: _confidenceFor('billDate'),
                readOnly: true,
                onTap: _pickDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AddressLocationForm(
          controller: _billingAddress,
          title: 'Billing Address',
        ),
        const SizedBox(height: 10),
        AddressLocationForm(
          controller: _shippingAddress,
          title: 'Shipping Address',
          sameAsController: _billingAddress,
        ),
      ],
    );
  }

  Widget _sectionItems() {
    return _sectionCard(
      title: 'Items (${_items.length})',
      icon: Icons.shopping_bag_outlined,
      children: [
        for (final item in _items) _buildItemRow(item),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(
              () => _items.add(_WorkspaceLineItem(id: _newId(), confidence: 1)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(_WorkspaceLineItem item) {
    final status = _statusForConfidence(
      item.confidence,
      hasValue: item.nameCtrl.text.trim().isNotEmpty,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.icon, size: 16, color: status.color),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: item.nameCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Item name',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                icon: const Icon(Icons.close, size: 18),
                onPressed: _items.length == 1
                    ? null
                    : () => setState(() {
                        item.dispose();
                        _items.remove(item);
                      }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _plainField(label: 'HSN/SAC', controller: item.hsnCtrl),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _plainField(label: 'Unit', controller: item.unitCtrl),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _plainField(
                  label: 'Qty',
                  controller: item.qtyCtrl,
                  number: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _plainField(
                  label: 'Rate',
                  controller: item.rateCtrl,
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _plainField(
                  label: 'Discount',
                  controller: item.discountCtrl,
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _plainField(
                  label: 'GST %',
                  controller: item.gstCtrl,
                  number: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Amount: ₹${item.lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A3A86),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTax() {
    return _sectionCard(
      title: 'Tax Summary',
      icon: Icons.receipt_outlined,
      initiallyExpanded: false,
      children: [
        _taxRow('Subtotal', _subtotal),
        _taxRow('Item Discount', -_itemDiscount),
        _taxRow('Taxable Value', _taxableValue),
        _taxRow('Total GST (CGST+SGST/IGST)', _totalGst),
        Row(
          children: [
            const Expanded(child: Text('Round Off')),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _roundOffCtrl,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Grand Total',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '₹${_grandTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A3A86),
                fontSize: 16,
              ),
            ),
          ],
        ),
        if (_smart?.taxResult.taxCalcMatch == false)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '⚠ Extracted tax amounts do not match calculated tax. Please verify.',
              style: TextStyle(color: Color(0xFFEF6C00)),
            ),
          ),
      ],
    );
  }

  Widget _taxRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('₹${value.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _sectionAccounting() {
    final suggestion = _smart?.ledgerSuggestion;
    return _sectionCard(
      title: 'Accounting',
      icon: Icons.account_balance_outlined,
      initiallyExpanded: false,
      children: [
        if (suggestion != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suggested ledger: ${suggestion.ledgerName} (${suggestion.group}) '
                    '• ${(suggestion.confidence * 100).round()}% confidence',
                    style: const TextStyle(color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            _isSales
                ? 'Sales account / GST output ledger will be applied automatically.'
                : 'Purchase account / GST input ledger will be applied automatically.',
            style: const TextStyle(color: Colors.black54),
          ),
        const SizedBox(height: 10),
        Text(
          'Party Ledger: ${_partyNameCtrl.text.isEmpty ? '—' : _partyNameCtrl.text}',
        ),
      ],
    );
  }

  Widget _sectionAdditional() {
    return _sectionCard(
      title: 'Additional Details',
      icon: Icons.more_horiz,
      initiallyExpanded: false,
      children: [
        _verifiedField(
          label: 'Payment Terms',
          controller: _paymentTermsCtrl,
          confidence: 1,
        ),
        const SizedBox(height: 10),
        _verifiedField(
          label: 'Notes',
          controller: _notesCtrl,
          confidence: 1,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: _isProcessing || _fileBytes == null || _fileBytes!.isEmpty
              ? null
              : () => _runIntelligence(_fileBytes!, fileName: _fileName),
          icon: const Icon(Icons.refresh),
          label: const Text('Verify Again'),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _saveVoucher(asDraft: true),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Draft'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _confirmAndSave,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirm & Save'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
          ),
        ),
      ],
    );
  }

  Widget _plainField({
    required String label,
    required TextEditingController controller,
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(isDense: true, labelText: label),
    );
  }

  Widget _verifiedField({
    required String label,
    required TextEditingController controller,
    required double confidence,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final status = _statusForConfidence(
      confidence,
      hasValue: controller.text.trim().isNotEmpty,
    );
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        suffixIcon: Icon(status.icon, color: status.color, size: 20),
      ),
    );
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_invoiceDateCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _invoiceDateCtrl.text = _dateToText(picked));
    }
  }

  // ── Validation & save ────────────────────────────────────────────────────

  List<String> _hardErrors() {
    final errors = <String>[];
    if (_invoiceNoCtrl.text.trim().isEmpty) errors.add('Invoice number is required.');
    if (DateTime.tryParse(_invoiceDateCtrl.text.trim()) == null) {
      errors.add('Invoice date is invalid.');
    }
    if (_partyNameCtrl.text.trim().isEmpty) {
      errors.add(_isSales ? 'Customer name is required.' : 'Supplier name is required.');
    }
    if (_items.isEmpty || _items.every((i) => i.nameCtrl.text.trim().isEmpty)) {
      errors.add('At least one item is required.');
    }
    return errors;
  }

  List<String> _softWarnings() {
    final warnings = <String>[];
    final gstin = _gstinCtrl.text.trim();
    if (gstin.isNotEmpty &&
        !RegExp(r'^[0-9]{2}[A-Z0-9]{10}[0-9][A-Z][0-9A-Z]$').hasMatch(gstin)) {
      warnings.add('GSTIN format looks unusual — please double check.');
    }
    final total = _parsed?.totalAmount ?? 0;
    if (total > 0 && (_grandTotal - total).abs() > (total * 0.01 + 2)) {
      warnings.add(
        'Computed total (₹${_grandTotal.toStringAsFixed(2)}) does not match '
        'the invoice total (₹${total.toStringAsFixed(2)}).',
      );
    }
    if (_smart?.taxResult.taxCalcMatch == false) {
      warnings.add('Extracted tax amount does not match the calculated tax.');
    }
    if (_smart?.duplicateResult.isDuplicate == true) {
      warnings.add('This invoice looks similar to one already recorded (possible duplicate).');
    }
    return warnings;
  }

  Future<void> _confirmAndSave() async {
    final errors = _hardErrors();
    if (errors.isNotEmpty) {
      await _showIssuesDialog('Fix required before saving', errors, blocking: true);
      return;
    }
    final warnings = _softWarnings();
    if (warnings.isNotEmpty) {
      final proceed = await _showIssuesDialog(
        'Please verify before saving',
        warnings,
        blocking: false,
      );
      if (proceed != true) return;
    }
    await _saveVoucher(asDraft: false);
  }

  Future<bool?> _showIssuesDialog(
    String title,
    List<String> issues, {
    required bool blocking,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final issue in issues)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        blocking ? Icons.error_outline : Icons.warning_amber_rounded,
                        size: 18,
                        color: blocking
                            ? const Color(0xFFC62828)
                            : const Color(0xFFEF6C00),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(issue)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: blocking
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Proceed Anyway'),
                ),
              ],
      ),
    );
  }

  Future<void> _saveVoucher({required bool asDraft}) async {
    if (!asDraft) {
      final errors = _hardErrors();
      if (errors.isNotEmpty) {
        await _showIssuesDialog('Fix required before saving', errors, blocking: true);
        return;
      }
    }
    final addressValidation = validateAddressTaxIdentity(
      address: _billingAddress.value,
      gstin: _gstinCtrl.text,
    );
    if (!addressValidation.isValid) {
      _showSnack(addressValidation.message, isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final invoiceDate =
          DateTime.tryParse(_invoiceDateCtrl.text.trim()) ?? DateTime.now();
      if (_isSales) {
        final salesService = context.read<SalesService>();
        final invoice = SalesInvoice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          createdByClient: true,
          invoiceNumber: _invoiceNoCtrl.text.trim().isEmpty
              ? salesService.generateNextInvoiceNumber()
              : _invoiceNoCtrl.text.trim(),
          invoiceDate: invoiceDate,
          dueDate: invoiceDate.add(const Duration(days: 30)),
          customerName: _partyNameCtrl.text.trim(),
          gstNumber: _gstinCtrl.text.trim(),
          billingAddress: _billingAddress.value.enteredAddress,
          shippingAddress: _shippingAddress.value.enteredAddress,
          billingLocation: _billingAddress.value,
          shippingLocation: _shippingAddress.value,
          placeOfSupply: _billingAddress.value.stateName,
          paymentTerms: _paymentTermsCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          roundOff: _roundOff,
          status: asDraft ? InvoiceStatus.draft : InvoiceStatus.pending,
          postingStatus: asDraft
              ? SalesPostingStatus.draft
              : SalesPostingStatus.pendingReview,
          items: _items
              .where((i) => i.nameCtrl.text.trim().isNotEmpty)
              .map(
                (i) => SalesItem(
                  id: i.id,
                  productName: i.nameCtrl.text.trim(),
                  hsnCode: i.hsnCtrl.text.trim(),
                  unit: i.unitCtrl.text.trim().isEmpty ? 'Nos' : i.unitCtrl.text.trim(),
                  quantity: i.quantity,
                  rate: i.rate,
                  discount: i.discount,
                  gstPercentage: i.gstPercentage,
                ),
              )
              .toList(),
        );
        salesService.addInvoice(invoice);
      } else {
        final purchaseService = context.read<PurchaseService>();
        final bill = PurchaseBill(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          billNumber: _invoiceNoCtrl.text.trim().isEmpty
              ? purchaseService.nextBillNumber()
              : _invoiceNoCtrl.text.trim(),
          billDate: invoiceDate,
          vendorName: _partyNameCtrl.text.trim(),
          vendorGstin: _gstinCtrl.text.trim(),
          vendorAddress: _billingAddress.value.enteredAddress,
          vendorLocation: _billingAddress.value,
          mode: PurchaseEntryMode.upload,
          notes: _notesCtrl.text.trim(),
          items: _items
              .where((i) => i.nameCtrl.text.trim().isNotEmpty)
              .map(
                (i) => PurchaseItem(
                  id: i.id,
                  productName: i.nameCtrl.text.trim(),
                  hsnCode: i.hsnCtrl.text.trim(),
                  unit: i.unitCtrl.text.trim().isEmpty ? 'Nos' : i.unitCtrl.text.trim(),
                  quantity: i.quantity,
                  rate: i.rate,
                  gstPercentage: i.gstPercentage,
                ),
              )
              .toList(),
        );
        purchaseService.addBill(bill);
      }
      if (!mounted) return;
      _showSnack(
        asDraft ? 'Voucher saved as draft.' : 'Voucher saved and sent for posting.',
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
