import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/constants/feature_flags.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';

import 'package:chirag_accounting/features/products/models/product.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_item.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/add_sales_invoice_screen.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/features/vendors/models/vendor.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';
import 'package:chirag_accounting/shared/widgets/address_location_form.dart';

enum PurchaseLaunchMode { standard, manual, ocr, image, pdf }

class AddPurchaseBillScreen extends StatefulWidget {
  final ParsedInvoiceData? prefillParsedData;
  final OcrDocumentAnalysis? prefillAnalysis;
  final bool autoEntryMode;
  final PurchaseLaunchMode initialLaunchMode;

  const AddPurchaseBillScreen({
    super.key,
    this.prefillParsedData,
    this.prefillAnalysis,
    this.autoEntryMode = false,
    this.initialLaunchMode = PurchaseLaunchMode.standard,
  });

  @override
  State<AddPurchaseBillScreen> createState() => _AddPurchaseBillScreenState();
}

class _PurchaseRow {
  _PurchaseRow({
    String productName = '',
    String hsnCode = '',
    String qty = '1',
    String rate = '',
  }) : productNameCtrl = TextEditingController(text: productName),
       hsnCodeCtrl = TextEditingController(text: hsnCode),
       qtyCtrl = TextEditingController(text: qty),
       rateCtrl = TextEditingController(text: rate);

  final TextEditingController productNameCtrl;
  final TextEditingController hsnCodeCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;

  void dispose() {
    productNameCtrl.dispose();
    hsnCodeCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

class _AddPurchaseBillScreenState extends State<AddPurchaseBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _billNumberCtrl;
  late TextEditingController _billDateCtrl;
  final _vendorNameCtrl = TextEditingController();
  final _vendorMobileCtrl = TextEditingController();
  final _vendorGstinCtrl = TextEditingController();
  final _vendorAddress = AddressFormController();
  final _notesCtrl = TextEditingController();
  final _uploadDataCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController(text: '0');
  final _paymentReferenceCtrl = TextEditingController();
  final _paymentDateCtrl = TextEditingController();
  List<String> _attachmentPaths = [];
  final _imagePicker = ImagePicker();
  final _ocrService = InvoiceOcrService();
  bool _isParsingUpload = false;
  bool _requiresVerification = false;
  bool _ocrVerified = false;
  OcrDocumentAnalysis? _lastDocumentAnalysis;
  bool _initialLaunchHandled = false;
  PurchasePaymentStatus _purchasePaymentStatus = PurchasePaymentStatus.credit;
  String _purchasePaymentMode = 'Cash';

  PurchaseEntryMode _entryMode = PurchaseEntryMode.manual;
  final List<_PurchaseRow> _rows = [_PurchaseRow()];

  bool get _isAccountantUploadRestricted {
    return false;
  }

  bool _ensureClientUploadedSourceOnly() {
    return true;
  }

  @override
  void initState() {
    super.initState();
    final purchaseService = context.read<PurchaseService>();
    _billNumberCtrl = TextEditingController(
      text: purchaseService.nextBillNumber(),
    );
    _billDateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    _paymentDateCtrl.text = _billDateCtrl.text;
    _entryMode =
        widget.initialLaunchMode == PurchaseLaunchMode.standard ||
            widget.initialLaunchMode == PurchaseLaunchMode.manual
        ? PurchaseEntryMode.manual
        : PurchaseEntryMode.upload;
    if (_isAccountantUploadRestricted &&
        _entryMode == PurchaseEntryMode.upload) {
      _entryMode = PurchaseEntryMode.manual;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (widget.prefillParsedData != null) {
        if (!mounted) return;
        _applyParsedData(widget.prefillParsedData!);
        setState(() {
          _lastDocumentAnalysis = widget.prefillAnalysis;
        });

        if (widget.autoEntryMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Auto-entry applied: Purchase form prefilled from upload.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      await _maybeLaunchInitialFlow();
    });
  }

  @override
  void dispose() {
    _billNumberCtrl.dispose();
    _billDateCtrl.dispose();
    _vendorNameCtrl.dispose();
    _vendorMobileCtrl.dispose();
    _vendorGstinCtrl.dispose();
    _vendorAddress.dispose();
    _notesCtrl.dispose();
    _uploadDataCtrl.dispose();
    _paidAmountCtrl.dispose();
    _paymentReferenceCtrl.dispose();
    _paymentDateCtrl.dispose();
    _ocrService.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _applyParsedData(ParsedInvoiceData parsed) {
    final parsedRows = parsed.items
        .map(
          (item) => _PurchaseRow(
            productName: item.name,
            hsnCode: item.hsnCode,
            qty: item.quantity.toStringAsFixed(
              item.quantity.truncateToDouble() == item.quantity ? 0 : 2,
            ),
            rate: item.rate.toStringAsFixed(
              item.rate.truncateToDouble() == item.rate ? 0 : 2,
            ),
          ),
        )
        .toList(growable: false);

    setState(() {
      if (parsed.partyName.isNotEmpty) {
        _vendorNameCtrl.text = parsed.partyName;
      }
      final normalizedMobile = normalizeIndianMobile(parsed.mobile);
      if (normalizedMobile.isNotEmpty) {
        _vendorMobileCtrl.text = normalizedMobile;
      }
      if (parsed.gstin.isNotEmpty) {
        _vendorGstinCtrl.text = parsed.gstin;
      }
      if (parsed.billNumber.isNotEmpty) {
        _billNumberCtrl.text = parsed.billNumber;
      }
      if (parsed.billDate.isNotEmpty) {
        _billDateCtrl.text = parsed.billDate;
      }

      _uploadDataCtrl.text = parsed.rawText;
      for (final row in _rows) {
        row.dispose();
      }
      _rows
        ..clear()
        ..addAll(parsedRows.isEmpty ? [_PurchaseRow()] : parsedRows);
      _requiresVerification = true;
      _ocrVerified = false;
    });
  }

  String _buildOcrInsights(
    ParsedInvoiceData parsed,
    OcrDocumentAnalysis analysis,
  ) {
    final validation = _ocrService.validateParsedData(parsed);
    final purchaseService = context.read<PurchaseService>();
    final duplicates = _ocrService.detectDuplicates(
      parsed: parsed,
      existing: purchaseService.bills
          .map(
            (bill) => InvoiceFingerprint(
              referenceNumber: bill.billNumber,
              partyName: bill.vendorName,
              gstin: bill.vendorGstin,
              billDate: bill.billDate.toIso8601String().split('T').first,
              totalAmount: bill.grandTotal,
            ),
          )
          .toList(growable: false),
    );

    final notes = <String>[];
    if (validation.needsReview) {
      final warningPreview = validation.warnings.take(2).join(', ');
      notes.add(
        'AI validation ${(validation.confidence * 100).round()}%${warningPreview.isNotEmpty ? ': $warningPreview' : ''}',
      );
    }

    if (duplicates.hasDuplicates) {
      final best = duplicates.matches.first;
      notes.add(
        'Possible duplicate ${best.candidate.referenceNumber} (${(best.score * 100).round()}%)',
      );
    }

    final detected = _documentKindLabel(analysis.kind);
    notes.add(
      'Detected type: $detected (${(analysis.confidence * 100).round()}%)',
    );

    return notes.join(' | ');
  }

  String _documentKindLabel(OcrDocumentKind kind) {
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

  bool _isPurchaseCompatible(OcrDocumentKind kind) {
    return kind == OcrDocumentKind.purchaseBill ||
        kind == OcrDocumentKind.unknown;
  }

  VoucherType? _voucherTypeForDocument(OcrDocumentKind kind) {
    switch (kind) {
      case OcrDocumentKind.paymentVoucher:
      case OcrDocumentKind.chequeGiven:
        return VoucherType.payment;
      case OcrDocumentKind.receiptVoucher:
      case OcrDocumentKind.chequeReceived:
        return VoucherType.receipt;
      case OcrDocumentKind.creditNote:
        return VoucherType.creditNote;
      case OcrDocumentKind.debitNote:
        return VoucherType.debitNote;
      default:
        return null;
    }
  }

  Future<void> _handleMismatchedPurchaseDocument(
    OcrDocumentAnalysis analysis,
  ) async {
    final detected = _documentKindLabel(analysis.kind);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload routed to safer module'),
        content: Text(
          'Detected "$detected" document. To keep data accurate, this file is not auto-applied in Purchase module.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (analysis.kind == OcrDocumentKind.salesInvoice)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSalesInvoiceScreen(),
                  ),
                );
              },
              child: const Text('Open Sales'),
            ),
          if (FeatureFlags.bankingEnabled &&
              _voucherTypeForDocument(analysis.kind) != null)
            ElevatedButton(
              onPressed: () {
                final voucherType = _voucherTypeForDocument(analysis.kind)!;
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ClientBankScreen(initialVoucherType: voucherType),
                  ),
                );
              },
              child: const Text('Open Banking Voucher'),
            ),
        ],
      ),
    );
  }

  Future<void> _parseInvoiceFile(File file, {required bool isPdf}) async {
    setState(() => _isParsingUpload = true);
    try {
      final extractedText = isPdf
          ? await _ocrService.extractTextFromPdf(file)
          : await _ocrService.extractTextFromImage(file);

      final parsed = _ocrService.parseInvoiceText(extractedText);
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isPurchaseCompatible(analysis.kind)) {
        setState(() {
          _uploadDataCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
        });
        await _handleMismatchedPurchaseDocument(analysis);
        return;
      }

      _applyParsedData(parsed);
      setState(() => _lastDocumentAnalysis = analysis);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Invoice parsed: ${parsed.items.length} item(s) found' : 'Text extracted, fill remaining fields manually'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _scanFromCamera() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;
    if (!isUsableLocalFilePath(image.path)) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Captured image bytes are empty.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await _parseImageBytes(bytes, sourceName: 'purchase_camera.jpg');
      return;
    }
    await _parseInvoiceFile(File(image.path), isPdf: false);
  }

  Future<void> _pickImageFromGallery() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;
    if (!isUsableLocalFilePath(image.path)) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected image bytes are empty.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await _parseImageBytes(bytes, sourceName: 'purchase_gallery.jpg');
      return;
    }
    await _parseInvoiceFile(File(image.path), isPdf: false);
  }

  Future<void> _pickMultipleImagesFromGallery() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    setState(() => _isParsingUpload = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final files = result.files
          .map((item) => item.path)
          .whereType<String>()
          .where(isUsableLocalFilePath)
          .map(File.new)
          .toList(growable: false);

      String extractedText;
      if (files.isNotEmpty) {
        extractedText = await _ocrService.extractTextFromImages(files);
      } else {
        final imageBytes = result.files
            .map((item) => item.bytes)
            .whereType<Uint8List>()
            .where((bytes) => bytes.isNotEmpty)
            .toList(growable: false);
        final fileNames = result.files
            .map(
              (item) => item.name.trim().isEmpty
                  ? 'purchase_upload.jpg'
                  : item.name.trim(),
            )
            .toList(growable: false);

        if (imageBytes.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No usable image path or bytes found for OCR.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        extractedText = await _ocrService.extractTextFromImagesBytes(
          imageBytes,
          fileNames: fileNames,
        );
      }

      final parsed = _ocrService.parseInvoiceText(extractedText);
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isPurchaseCompatible(analysis.kind)) {
        setState(() {
          _uploadDataCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
        });
        await _handleMismatchedPurchaseDocument(analysis);
        return;
      }

      _applyParsedData(parsed);
      setState(() => _lastDocumentAnalysis = analysis);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Batch OCR parsed: ${parsed.items.length} item(s) found' : 'Batch OCR text extracted, fill remaining fields manually'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse batch images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _pickPdfAndParse() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path;
    if (path != null && isUsableLocalFilePath(path)) {
      await _parseInvoiceFile(File(path), isPdf: true);
      return;
    }

    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read PDF bytes from selected file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isParsingUpload = true);
    try {
      final extractedText = await _ocrService.extractTextFromPdfBytes(bytes);
      final parsed = _ocrService.parseInvoiceText(extractedText);
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isPurchaseCompatible(analysis.kind)) {
        setState(() {
          _uploadDataCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
        });
        await _handleMismatchedPurchaseDocument(analysis);
        return;
      }

      _applyParsedData(parsed);
      setState(() => _lastDocumentAnalysis = analysis);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Invoice parsed: ${parsed.items.length} item(s) found' : 'Text extracted, fill remaining fields manually'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _parseImageBytes(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    setState(() => _isParsingUpload = true);
    try {
      final extractedText = await _ocrService.extractTextFromImageBytes(
        bytes,
        fileName: sourceName,
      );
      final parsed = _ocrService.parseInvoiceText(extractedText);
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isPurchaseCompatible(analysis.kind)) {
        setState(() {
          _uploadDataCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
        });
        await _handleMismatchedPurchaseDocument(analysis);
        return;
      }

      _applyParsedData(parsed);
      setState(() => _lastDocumentAnalysis = analysis);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Invoice parsed: ${parsed.items.length} item(s) found' : 'Text extracted, fill remaining fields manually'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _maybeLaunchInitialFlow() async {
    if (_initialLaunchHandled || !mounted) {
      return;
    }
    _initialLaunchHandled = true;

    if (widget.prefillParsedData != null) {
      return;
    }

    if (_isAccountantUploadRestricted) {
      return;
    }

    switch (widget.initialLaunchMode) {
      case PurchaseLaunchMode.standard:
      case PurchaseLaunchMode.manual:
        return;
      case PurchaseLaunchMode.ocr:
        await _showUploadSourcePicker();
        return;
      case PurchaseLaunchMode.image:
        await _pickImageFromGallery();
        return;
      case PurchaseLaunchMode.pdf:
        await _pickPdfAndParse();
        return;
    }
  }

  Future<void> _showUploadSourcePicker() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Scan Camera'),
                subtitle: const Text('Capture a purchase invoice'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _scanFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Pick Image'),
                subtitle: const Text('Choose a purchase invoice image'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.collections_outlined),
                title: const Text('Pick Multi Images'),
                subtitle: const Text('Combine multiple purchase invoice pages'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickMultipleImagesFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Pick PDF'),
                subtitle: const Text('Import a purchase invoice PDF'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickPdfAndParse();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAttachments() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .map((item) => item.path)
        .whereType<String>()
        .where(isUsableLocalFilePath)
        .toList(growable: false);

    if (paths.isEmpty) return;

    setState(() {
      _attachmentPaths = <String>{
        ..._attachmentPaths,
        ...paths,
      }.toList(growable: false);
    });
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ctrl.text = picked.toIso8601String().split('T').first;
    }
  }

  String _nextProductCode(ProductService service) {
    var maxSequence = 0;
    final pattern = RegExp(r'^PROD-(\d+)$');
    for (final product in service.products) {
      final match = pattern.firstMatch(product.productCode.trim());
      if (match == null) continue;
      final seq = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (seq > maxSequence) {
        maxSequence = seq;
      }
    }
    return 'PROD-${(maxSequence + 1).toString().padLeft(4, '0')}';
  }

  Product _resolveOrCreateProduct({
    required ProductService productService,
    required String productName,
    required String hsnCode,
    required double rate,
  }) {
    final probe = Product(
      id: 'probe',
      productCode: '',
      productName: productName,
      hsnCode: hsnCode,
      salesRate: rate,
      purchaseRate: rate,
    );

    final existing = productService.findIdentityMatch(probe);
    if (existing != null) {
      return existing;
    }

    final product = Product(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      productCode: _nextProductCode(productService),
      productName: productName,
      hsnCode: hsnCode,
      purchaseRate: rate,
      salesRate: rate,
      isActive: true,
    );

    productService.addProduct(product);
    return product;
  }

  Vendor _resolveOrCreateVendor(VendorService vendorService) {
    return vendorService.resolveOrCreateVendor(
      name: _vendorNameCtrl.text.trim(),
      gstNumber: _vendorGstinCtrl.text.trim(),
      mobileNumber: normalizeIndianMobile(_vendorMobileCtrl.text),
      billingAddress: _vendorAddress.value.enteredAddress,
      billingLocation: _vendorAddress.value,
    );
  }

  Future<void> _showQuickAddVendorDialog() async {
    final nameCtrl = TextEditingController(text: _vendorNameCtrl.text.trim());
    final mobileCtrl = TextEditingController(
      text: _vendorMobileCtrl.text.trim(),
    );
    final gstCtrl = TextEditingController(text: _vendorGstinCtrl.text.trim());

    final created = await showDialog<Vendor>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Vendor (+)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Vendor Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: indianMobileInputFormatters(),
                decoration: const InputDecoration(labelText: 'Mobile'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gstCtrl,
                decoration: const InputDecoration(labelText: 'GSTIN'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final vendorService = context.read<VendorService>();
                final vendor = vendorService.resolveOrCreateVendor(
                  name: nameCtrl.text.trim(),
                  gstNumber: gstCtrl.text.trim(),
                  mobileNumber: normalizeIndianMobile(mobileCtrl.text),
                );
                Navigator.pop(context, vendor);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    mobileCtrl.dispose();
    gstCtrl.dispose();

    if (created == null) return;
    setState(() {
      _vendorNameCtrl.text = created.vendorName;
      _vendorMobileCtrl.text = created.mobileNumber;
      _vendorGstinCtrl.text = created.gstNumber;
      _vendorAddress.setValue(
        created.billingLocation ??
            StandardAddress.fromLegacy(address: created.billingAddress),
      );
    });
  }

  Future<void> _showQuickAddProductDialog(_PurchaseRow row) async {
    final nameCtrl = TextEditingController(
      text: row.productNameCtrl.text.trim(),
    );
    final hsnCtrl = TextEditingController(text: row.hsnCodeCtrl.text.trim());
    final rateCtrl = TextEditingController(text: row.rateCtrl.text.trim());

    final created = await showDialog<Product>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Product (+)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: hsnCtrl,
                decoration: const InputDecoration(labelText: 'HSN Code'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rateCtrl,
                decoration: const InputDecoration(labelText: 'Rate'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final productService = context.read<ProductService>();
                final product = _resolveOrCreateProduct(
                  productService: productService,
                  productName: nameCtrl.text.trim(),
                  hsnCode: hsnCtrl.text.trim(),
                  rate: double.tryParse(rateCtrl.text.trim()) ?? 0,
                );
                Navigator.pop(context, product);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    hsnCtrl.dispose();
    rateCtrl.dispose();

    if (created == null) return;
    setState(() {
      row.productNameCtrl.text = created.productName;
      row.hsnCodeCtrl.text = created.hsnCode;
      if (row.rateCtrl.text.trim().isEmpty) {
        row.rateCtrl.text = created.purchaseRate.toStringAsFixed(2);
      }
    });
  }

  double get _purchaseGrandTotal {
    return _rows.fold<double>(0, (sum, row) {
      final qty = double.tryParse(row.qtyCtrl.text.trim()) ?? 0;
      final rate = double.tryParse(row.rateCtrl.text.trim()) ?? 0;
      return sum + (qty * rate);
    });
  }

  double get _paidAmountValue {
    return double.tryParse(_paidAmountCtrl.text.trim()) ?? 0;
  }

  double get _purchaseOutstanding {
    final value = _purchaseGrandTotal - _paidAmountValue;
    return value < 0 ? 0 : value;
  }

  void _onPurchasePaymentStatusChanged(PurchasePaymentStatus value) {
    setState(() {
      _purchasePaymentStatus = value;
      final total = _purchaseGrandTotal;
      if (value == PurchasePaymentStatus.fullyPaid) {
        _paidAmountCtrl.text = total.toStringAsFixed(2);
      } else if (value == PurchasePaymentStatus.credit) {
        _paidAmountCtrl.text = '0';
      }
    });
  }

  void _mockUploadFill() {
    if (!_ensureClientUploadedSourceOnly()) return;
    final raw = _uploadDataCtrl.text.trim();
    if (raw.isEmpty) {
      _uploadDataCtrl.text =
          'vendor=ABC Traders;mobile=9876543210;gst=29ABCDE1234F1Z5;items=Steel Rod|7214|10|250,Paint Bucket|3209|4|500';
    }

    final payload = _uploadDataCtrl.text.trim();
    final segments = payload.split(';');
    final map = <String, String>{};
    for (final segment in segments) {
      final pair = segment.split('=');
      if (pair.length == 2) {
        map[pair.first.trim().toLowerCase()] = pair.last.trim();
      }
    }

    final itemsRaw = map['items'] ?? '';
    final parsedRows = <_PurchaseRow>[];
    for (final itemRaw in itemsRaw.split(',')) {
      final parts = itemRaw.split('|');
      if (parts.length < 4) continue;
      parsedRows.add(
        _PurchaseRow(
          productName: parts[0].trim(),
          hsnCode: parts[1].trim(),
          qty: parts[2].trim(),
          rate: parts[3].trim(),
        ),
      );
    }

    if (parsedRows.isEmpty) {
      parsedRows.add(_PurchaseRow());
    }

    setState(() {
      _vendorNameCtrl.text = map['vendor'] ?? _vendorNameCtrl.text;
      _vendorMobileCtrl.text = map['mobile'] ?? _vendorMobileCtrl.text;
      _vendorGstinCtrl.text = map['gst'] ?? _vendorGstinCtrl.text;
      for (final row in _rows) {
        row.dispose();
      }
      _rows
        ..clear()
        ..addAll(parsedRows);
    });
  }

  void _savePurchase() {
    if (!_formKey.currentState!.validate()) return;

    if (_vendorNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vendor name is required')));
      return;
    }

    final hasInvalidItem = _rows.any((row) {
      final name = row.productNameCtrl.text.trim();
      final qty = double.tryParse(row.qtyCtrl.text.trim()) ?? 0;
      final rate = double.tryParse(row.rateCtrl.text.trim()) ?? 0;
      return name.isEmpty || qty <= 0 || rate <= 0;
    });

    if (hasInvalidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Each item must have product, qty and rate'),
        ),
      );
      return;
    }

    if (_requiresVerification && !_ocrVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please verify uploaded data and tick confirmation before saving',
          ),
        ),
      );
      return;
    }

    if (_lastDocumentAnalysis != null &&
        !_isPurchaseCompatible(_lastDocumentAnalysis!.kind)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Detected ${_documentKindLabel(_lastDocumentAnalysis!.kind)}. Use related module for accurate posting.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final purchaseService = context.read<PurchaseService>();
    final duplicate = purchaseService.findByBillNumber(
      _billNumberCtrl.text.trim(),
    );
    if (duplicate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Duplicate bill detected: ${duplicate.billNumber} already exists for ${duplicate.vendorName}.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final vendorService = context.read<VendorService>();
      final productService = context.read<ProductService>();

      if (_paidAmountValue < 0 || _paidAmountValue > _purchaseGrandTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paid amount must be between 0 and bill total.'),
          ),
        );
        return;
      }

      final vendor = _resolveOrCreateVendor(vendorService);

      final items = _rows.map((row) {
        final product = _resolveOrCreateProduct(
          productService: productService,
          productName: row.productNameCtrl.text.trim(),
          hsnCode: row.hsnCodeCtrl.text.trim(),
          rate: double.tryParse(row.rateCtrl.text.trim()) ?? 0,
        );

        return PurchaseItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          productName: product.productName,
          hsnCode: product.hsnCode,
          quantity: double.tryParse(row.qtyCtrl.text.trim()) ?? 0,
          rate: double.tryParse(row.rateCtrl.text.trim()) ?? 0,
        );
      }).toList();

      final bill = PurchaseBill(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        billNumber: _billNumberCtrl.text.trim(),
        billDate: DateTime.parse(_billDateCtrl.text),
        vendorName: vendor.vendorName,
        vendorGstin: vendor.gstNumber,
        vendorAddress: _vendorAddress.value.enteredAddress,
        vendorLocation: _vendorAddress.value,
        mode: _entryMode,
        items: items,
        notes: _notesCtrl.text.trim(),
        attachmentPaths: _attachmentPaths,
        paymentStatus: _purchasePaymentStatus,
        paidAmount: _paidAmountValue,
        outstandingAmount: _purchaseGrandTotal - _paidAmountValue,
        paymentMode: _purchasePaymentMode,
        paymentReference: _paymentReferenceCtrl.text.trim(),
        paymentDate: _paymentDateCtrl.text.trim().isEmpty
            ? null
            : DateTime.tryParse(_paymentDateCtrl.text.trim()),
      );

      purchaseService.addBill(bill);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase ${bill.billNumber} saved. Vendor/product auto-linked.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Validation failed: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving purchase: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = context.watch<VendorService>().vendors;
    final products = context.watch<ProductService>().products;
    final isAccountantUploadRestricted = _isAccountantUploadRestricted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchase Bill'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<PurchaseEntryMode>(
                segments: [
                  ButtonSegment(
                    value: PurchaseEntryMode.manual,
                    label: Text('Manual Entry'),
                  ),
                  if (!isAccountantUploadRestricted)
                    ButtonSegment(
                      value: PurchaseEntryMode.upload,
                      label: Text('Upload Entry'),
                    ),
                ],
                selected: {_entryMode},
                onSelectionChanged: (v) => setState(() => _entryMode = v.first),
              ),
              if (isAccountantUploadRestricted) ...[
                const SizedBox(height: 8),
                const Text(
                  'Accountant can process only client-uploaded documents from queue.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 14),
              if (_entryMode == PurchaseEntryMode.upload) ...[
                TextFormField(
                  controller: _uploadDataCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Extracted OCR Text',
                    hintText:
                        'Camera/Gallery/PDF OCR text appears here for review',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isParsingUpload ? null : _scanFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Scan Camera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isParsingUpload
                          ? null
                          : _pickImageFromGallery,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Pick Image'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isParsingUpload
                          ? null
                          : _pickMultipleImagesFromGallery,
                      icon: const Icon(Icons.collections_outlined),
                      label: const Text('Pick Multi Images'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isParsingUpload ? null : _pickPdfAndParse,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Pick PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isParsingUpload ? null : _mockUploadFill,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Use Demo Data'),
                    ),
                  ],
                ),
                if (_isParsingUpload) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  const Text(
                    'Reading invoice text (with scanned-PDF OCR fallback)...',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 8),
                if (_requiresVerification) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _ocrVerified = true),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Tick Correct'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _ocrVerified = false),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Data'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _ocrVerified
                        ? 'Marked as verified. You can now save.'
                        : 'If OCR data is not correct, edit fields then click Tick Correct.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _ocrVerified
                          ? Colors.green.shade700
                          : Colors.black54,
                    ),
                  ),
                ] else
                  const Text(
                    'Upload an invoice to enable Tick Correct / Edit Data actions.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                const SizedBox(height: 12),
              ],
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<PurchasePaymentStatus>(
                        segments: const [
                          ButtonSegment(
                            value: PurchasePaymentStatus.fullyPaid,
                            label: Text('Fully Paid'),
                          ),
                          ButtonSegment(
                            value: PurchasePaymentStatus.partiallyPaid,
                            label: Text('Partially Paid'),
                          ),
                          ButtonSegment(
                            value: PurchasePaymentStatus.credit,
                            label: Text('Credit'),
                          ),
                        ],
                        selected: {_purchasePaymentStatus},
                        onSelectionChanged: (selection) {
                          _onPurchasePaymentStatusChanged(selection.first);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _paidAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount Paid',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Outstanding: Rs. ${_purchaseOutstanding.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      SearchableDropdownFormField<String>(
                        value: _purchasePaymentMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode',
                          border: OutlineInputBorder(),
                        ),
                        items: const ['Cash', 'Bank', 'UPI', 'Cheque', 'NEFT'],
                        itemLabelBuilder: (value) => value,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _purchasePaymentMode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _paymentReferenceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Payment Reference',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _paymentDateCtrl,
                        readOnly: true,
                        onTap: () => _pickDate(_paymentDateCtrl),
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextFormField(
                controller: _billNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bill Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _billDateCtrl,
                readOnly: true,
                onTap: () => _pickDate(_billDateCtrl),
                decoration: const InputDecoration(
                  labelText: 'Bill Date',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Vendor Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showQuickAddVendorDialog,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add vendor (+)',
                  ),
                ],
              ),
              Autocomplete<Vendor>(
                displayStringForOption: (v) => v.vendorName,
                optionsBuilder: (text) {
                  final q = text.text.trim().toLowerCase();
                  if (q.isEmpty) return vendors;
                  return vendors.where(
                    (v) =>
                        v.vendorName.toLowerCase().contains(q) ||
                        v.vendorCode.toLowerCase().contains(q) ||
                        v.gstNumber.toLowerCase().contains(q) ||
                        v.mobileNumber.contains(q),
                  );
                },
                onSelected: (v) {
                  setState(() {
                    _vendorNameCtrl.text = v.vendorName;
                    _vendorMobileCtrl.text = v.mobileNumber;
                    _vendorGstinCtrl.text = v.gstNumber;
                    _vendorAddress.setValue(
                      v.billingLocation ??
                          StandardAddress.fromLegacy(address: v.billingAddress),
                    );
                  });
                },
                fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
                  ctrl.text = _vendorNameCtrl.text;
                  return TextFormField(
                    controller: ctrl,
                    focusNode: focusNode,
                    onChanged: (value) => _vendorNameCtrl.text = value,
                    decoration: const InputDecoration(
                      labelText: 'Vendor Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Vendor is required'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _vendorMobileCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vendor Mobile',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: indianMobileInputFormatters(),
                validator: validateIndianMobile,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _vendorGstinCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vendor GSTIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              AddressLocationForm(
                controller: _vendorAddress,
                title: 'Vendor Address',
              ),
              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._rows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Autocomplete<Product>(
                                displayStringForOption: (p) => p.productName,
                                optionsBuilder: (text) {
                                  final q = text.text.trim().toLowerCase();
                                  if (q.isEmpty) return products;
                                  return products.where(
                                    (p) =>
                                        p.productName.toLowerCase().contains(
                                          q,
                                        ) ||
                                        p.productCode.toLowerCase().contains(
                                          q,
                                        ) ||
                                        p.hsnCode.toLowerCase().contains(q),
                                  );
                                },
                                onSelected: (p) {
                                  row.productNameCtrl.text = p.productName;
                                  row.hsnCodeCtrl.text = p.hsnCode;
                                  if (row.rateCtrl.text.trim().isEmpty) {
                                    row.rateCtrl.text = p.purchaseRate
                                        .toStringAsFixed(2);
                                  }
                                  setState(() {});
                                },
                                fieldViewBuilder:
                                    (
                                      context,
                                      ctrl,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      ctrl.text = row.productNameCtrl.text;
                                      return TextFormField(
                                        controller: ctrl,
                                        focusNode: focusNode,
                                        onChanged: (value) =>
                                            row.productNameCtrl.text = value,
                                        decoration: const InputDecoration(
                                          labelText: 'Product Name',
                                          border: OutlineInputBorder(),
                                        ),
                                      );
                                    },
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showQuickAddProductDialog(row),
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Add product (+)',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: row.hsnCodeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'HSN',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: row.qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: row.rateCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Rate',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            if (_rows.length > 1)
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    final removed = _rows.removeAt(index);
                                    removed.dispose();
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _rows.add(_PurchaseRow())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supporting Images / PDF',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickAttachments,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Attach Manual Files'),
                          ),
                          if (_attachmentPaths.isNotEmpty)
                            Chip(
                              label: Text(
                                '${_attachmentPaths.length} file(s) attached',
                              ),
                            ),
                        ],
                      ),
                      if (_attachmentPaths.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _attachmentPaths
                              .map(
                                (path) => Chip(
                                  label: Text(File(path).uri.pathSegments.last),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _savePurchase,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Purchase Bill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
