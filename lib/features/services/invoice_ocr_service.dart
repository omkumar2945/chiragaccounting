import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/services/ai_invoice_vision_service.dart';

enum ParsedInvoiceLineType { product, charge }

class _InvoiceItemTableLayout {
  final bool hasHsnColumn;
  final int quantityValueIndex;
  final int rateValueIndex;

  const _InvoiceItemTableLayout({
    this.hasHsnColumn = false,
    this.quantityValueIndex = 0,
    this.rateValueIndex = 1,
  });
}

class ParsedInvoiceItem {
  final String name;
  final String description;
  final String hsnCode;
  final String unit;
  final double quantity;
  final double rate;
  final double amount;
  final double gstPercentage;
  final double confidence;
  final ParsedInvoiceLineType lineType;
  final String suggestedLedger;

  const ParsedInvoiceItem({
    required this.name,
    this.description = '',
    this.hsnCode = '',
    this.unit = '',
    required this.quantity,
    required this.rate,
    this.amount = 0,
    this.gstPercentage = 0,
    this.confidence = 0,
    this.lineType = ParsedInvoiceLineType.product,
    this.suggestedLedger = '',
  });

  ParsedInvoiceItem copyWith({
    String? name,
    String? description,
    String? hsnCode,
    String? unit,
    double? quantity,
    double? rate,
    double? amount,
    double? gstPercentage,
    double? confidence,
  }) {
    return ParsedInvoiceItem(
      name: name ?? this.name,
      description: description ?? this.description,
      hsnCode: hsnCode ?? this.hsnCode,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      confidence: confidence ?? this.confidence,
      lineType: lineType,
      suggestedLedger: suggestedLedger,
    );
  }
}

class ParsedInvoiceData {
  final String partyName;
  final String gstin;
  final String partyAddress;
  final List<String> gstins;
  final String mobile;
  final String billNumber;
  final String billDate;
  final double taxableAmount;
  final double totalTax;
  final double totalAmount;
  final double extractionConfidence;
  final Map<String, double> fieldConfidences;
  final List<ParsedInvoiceItem> items;
  final String rawText;

  const ParsedInvoiceData({
    this.partyName = '',
    this.gstin = '',
    this.partyAddress = '',
    this.gstins = const [],
    this.mobile = '',
    this.billNumber = '',
    this.billDate = '',
    this.taxableAmount = 0,
    this.totalTax = 0,
    this.totalAmount = 0,
    this.extractionConfidence = 0,
    this.fieldConfidences = const {},
    this.items = const [],
    this.rawText = '',
  });

  double confidenceFor(String field, {double fallback = 0}) {
    return (fieldConfidences[field] ?? fallback).clamp(0, 1);
  }
}

class OcrValidationResult {
  final double confidence;
  final List<String> warnings;

  const OcrValidationResult({
    required this.confidence,
    this.warnings = const [],
  });

  bool get needsReview => confidence < 0.7 || warnings.isNotEmpty;
}

class InvoiceFingerprint {
  final String referenceNumber;
  final String partyName;
  final String gstin;
  final String billDate;
  final double totalAmount;

  const InvoiceFingerprint({
    required this.referenceNumber,
    this.partyName = '',
    this.gstin = '',
    this.billDate = '',
    this.totalAmount = 0,
  });
}

class DuplicateMatch {
  final InvoiceFingerprint candidate;
  final double score;
  final List<String> reasons;

  const DuplicateMatch({
    required this.candidate,
    required this.score,
    this.reasons = const [],
  });
}

class DuplicateDetectionResult {
  final List<DuplicateMatch> matches;

  const DuplicateDetectionResult({this.matches = const []});

  bool get hasDuplicates => matches.isNotEmpty;
}

enum OcrDocumentKind {
  salesInvoice,
  purchaseBill,
  creditNote,
  debitNote,
  chequeGiven,
  chequeReceived,
  paymentVoucher,
  receiptVoucher,
  unknown,
}

class OcrDocumentAnalysis {
  final OcrDocumentKind kind;
  final double confidence;
  final List<String> signals;

  const OcrDocumentAnalysis({
    required this.kind,
    required this.confidence,
    this.signals = const [],
  });
}

class InvoiceOcrService {
  static const String _cloudOcrEndpoint = String.fromEnvironment(
    'OCR_CLOUD_URL',
    defaultValue: 'https://api.ocr.space/parse/image',
  );
  static const String _cloudOcrApiKey = String.fromEnvironment(
    'OCR_CLOUD_API_KEY',
    // Backward compatibility for legacy configuration names.
    defaultValue: String.fromEnvironment(
      'GCV_API_KEY',
      defaultValue: 'helloworld',
    ),
  );

  TextRecognizer? _textRecognizer;
  final AiInvoiceVisionService _aiInvoiceVisionService =
      AiInvoiceVisionService();

  Future<String?> extractStructuredInvoiceText(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final parsed = await extractStructuredInvoiceData(
      bytes,
      fileName: fileName,
    );
    return parsed?.rawText;
  }

  Future<ParsedInvoiceData?> extractStructuredInvoiceData(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (bytes.isEmpty) return null;

    final aiPayload = await _aiInvoiceVisionService.readInvoice(
      bytes,
      fileName: fileName,
    );
    if (aiPayload != null) {
      final aiParsed = _parseAiVisionPayload(aiPayload);
      if (aiParsed != null) {
        return aiParsed;
      }
    }

    try {
      final response = await ApiClient.dio.post<dynamic>(
        ApiConstants.invoiceExtraction,
        data: FormData.fromMap({
          'document': MultipartFile.fromBytes(bytes, filename: fileName),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      final root = response.data;
      if (root is! Map<String, dynamic>) return null;
      final data = root['data'];
      if (data is! Map<String, dynamic>) return null;
      return parseStructuredInvoiceData(data);
    } on DioException {
      return null;
    }
  }

  ParsedInvoiceData? _parseAiVisionPayload(AiInvoiceVisionPayload payload) {
    final json = payload.json;
    final voucherType = _structuredString(json['voucher_type']).toLowerCase();
    final invoiceNumber = _structuredString(json['invoice_number']);
    final invoiceDate = _normalizeDate(_structuredString(json['invoice_date']));
    final supplierName = _structuredString(json['supplier_name']);
    final supplierGstin = _structuredString(
      json['supplier_gstin'],
    ).toUpperCase();
    final buyerName = _structuredString(json['buyer_name']);
    final buyerGstin = _structuredString(json['buyer_gstin']).toUpperCase();

    final isSalesVoucher = voucherType.contains('sale');
    final isPurchaseVoucher = voucherType.contains('purchase');

    final partyName = isSalesVoucher
        ? buyerName
        : isPurchaseVoucher
        ? supplierName
        : (supplierName.isNotEmpty ? supplierName : buyerName);
    final gstin = isSalesVoucher
        ? buyerGstin
        : isPurchaseVoucher
        ? supplierGstin
        : (supplierGstin.isNotEmpty ? supplierGstin : buyerGstin);

    final taxableAmount = _structuredNumber(json['taxable_amount']);
    final cgst = _structuredNumber(json['cgst']);
    final sgst = _structuredNumber(json['sgst']);
    final igst = _structuredNumber(json['igst']);
    final total = _structuredNumber(json['total']);
    final totalTax = cgst + sgst + igst;
    final confidence = _normalizedConfidence(json['confidence']);

    final mappedItems = <Map<String, dynamic>>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final description = _structuredString(item['description']);
        final qty = _structuredNumber(item['qty']);
        final rate = _structuredNumber(item['rate']);
        final amount = _structuredNumber(item['amount']);
        if (description.isEmpty && qty <= 0 && rate <= 0 && amount <= 0) {
          continue;
        }

        mappedItems.add({
          'name': description,
          'description': description,
          'unit': _structuredString(item['unit']),
          'quantity': qty,
          'rate': rate,
          'amount': amount,
          'gstPercentage': _structuredNumber(item['gst_rate']),
          'confidence': confidence,
        });
      }
    }

    final hasUsefulData =
        partyName.isNotEmpty ||
        gstin.isNotEmpty ||
        invoiceNumber.isNotEmpty ||
        invoiceDate.isNotEmpty ||
        total > 0 ||
        mappedItems.isNotEmpty;

    if (!hasUsefulData) {
      return null;
    }

    final fieldConfidence = <String, double>{
      'partyName': _presenceConfidence(partyName, confidence),
      'gstin': _presenceConfidence(gstin, confidence),
      'billNumber': _presenceConfidence(invoiceNumber, confidence),
      'billDate': _presenceConfidence(invoiceDate, confidence),
      'taxableAmount': taxableAmount > 0 ? confidence : 0,
      'totalTax': totalTax > 0 ? confidence : 0,
      'totalAmount': total > 0 ? confidence : 0,
      'items': mappedItems.isNotEmpty ? confidence : 0,
    };

    return parseStructuredInvoiceData({
      'partyName': partyName,
      'partyAddress': '',
      'gstin': gstin,
      'billNumber': invoiceNumber,
      'billDate': invoiceDate,
      'taxableAmount': taxableAmount,
      'totalTax': totalTax,
      'totalAmount': total,
      'confidence': confidence,
      'fieldConfidence': fieldConfidence,
      'items': mappedItems,
      'rawText': payload.modelText,
    });
  }

  double _normalizedConfidence(dynamic value) {
    final raw = _structuredNumber(value);
    if (raw <= 0) return 0;
    if (raw > 1) {
      return (raw / 100).clamp(0, 1);
    }
    return raw.clamp(0, 1);
  }

  double _presenceConfidence(String value, double confidence) {
    return value.trim().isEmpty ? 0 : confidence;
  }

  ParsedInvoiceData parseStructuredInvoiceData(Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = <ParsedInvoiceItem>[];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final name = _structuredString(item['name']);
        final quantity = _structuredNumber(item['quantity']);
        final rate = _structuredNumber(item['rate']);
        final amount = _structuredNumber(item['amount']);
        if (name.isEmpty || (quantity <= 0 && amount <= 0)) continue;
        items.add(
          ParsedInvoiceItem(
            name: name,
            description: _structuredString(item['description']),
            hsnCode: _structuredString(item['hsnCode']),
            unit: _structuredString(item['unit']),
            quantity: quantity > 0 ? quantity : 1,
            rate: rate > 0 ? rate : amount,
            amount: amount,
            gstPercentage: _structuredNumber(item['gstPercentage']),
            confidence: _structuredNumber(item['confidence']),
          ),
        );
      }
    }

    final gstin = _structuredString(data['gstin']).toUpperCase();
    final rawFieldConfidences = data['fieldConfidence'];
    final fieldConfidences = <String, double>{};
    if (rawFieldConfidences is Map) {
      for (final entry in rawFieldConfidences.entries) {
        fieldConfidences[entry.key.toString()] = _structuredNumber(entry.value);
      }
    }
    return ParsedInvoiceData(
      partyName: _structuredString(data['partyName']),
      partyAddress: _structuredString(data['partyAddress']),
      gstin: gstin,
      gstins: gstin.isEmpty ? const [] : [gstin],
      billNumber: _structuredString(data['billNumber']),
      billDate: _normalizeDate(_structuredString(data['billDate'])),
      taxableAmount: _structuredNumber(data['taxableAmount']),
      totalTax: _structuredNumber(data['totalTax']),
      totalAmount: _structuredNumber(data['totalAmount']),
      extractionConfidence: _structuredNumber(data['confidence']),
      fieldConfidences: fieldConfidences,
      items: items,
      rawText: _structuredInvoiceText(data),
    );
  }

  String _structuredString(dynamic value) => value?.toString().trim() ?? '';

  double _structuredNumber(dynamic value) {
    if (value is num) return value.toDouble();
    final normalized = value
        ?.toString()
        .replaceAll(RegExp(r'[^0-9.\-]'), '')
        .trim();
    return double.tryParse(normalized ?? '') ?? 0;
  }

  String _structuredInvoiceText(Map<String, dynamic> data) {
    final lines = <String>['Tax Invoice'];
    void add(String label, dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '0' && text != '0.0') {
        lines.add('$label: $text');
      }
    }

    add('Supplier', data['partyName']);
    add('GSTIN', data['gstin']);
    add('Invoice No', data['billNumber']);
    add('Invoice Date', data['billDate']);
    final items = data['items'];
    if (items is List) {
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        if (item is! Map) continue;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final hsn = item['hsnCode']?.toString().trim() ?? '';
        final quantity = item['quantity'] ?? 0;
        final rate = item['rate'] ?? 0;
        final amount = item['amount'] ?? 0;
        lines.add(
          '${index + 1} $name${hsn.isEmpty ? '' : ' $hsn'} $quantity Nos $rate $amount',
        );
      }
    }
    add('Taxable Amount', data['taxableAmount']);
    add('Total Tax', data['totalTax']);
    add('Grand Total', data['totalAmount']);
    return lines.join('\n');
  }

  bool get _supportsMlKit {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  TextRecognizer _recognizer() {
    if (!_supportsMlKit) {
      throw UnsupportedError(
        'Image OCR is available only on Android and iOS in this build.',
      );
    }

    try {
      return _textRecognizer ??= TextRecognizer();
    } on MissingPluginException {
      throw UnsupportedError(
        'OCR plugin is not available on this platform build.',
      );
    }
  }

  Future<String> extractTextFromImage(File file) async {
    String localText = '';
    if (_supportsMlKit) {
      final recognizer = _recognizer();
      final inputImage = InputImage.fromFilePath(file.path);
      try {
        final recognizedText = await recognizer.processImage(inputImage);
        localText = recognizedText.text.trim();
        if (_hasReliableInvoiceText(localText)) {
          return localText;
        }
      } on MissingPluginException {
        // Fallback to cloud OCR below.
      }
    }

    final imageBytes = await file.readAsBytes();
    final cloudText = await _extractTextUsingCloudOcr(
      imageBytes,
      fileName: _fileNameFromPath(file.path),
    );
    if (cloudText.trim().isNotEmpty) {
      return _invoiceTextQuality(cloudText) >= _invoiceTextQuality(localText)
          ? cloudText
          : localText;
    }
    if (localText.isNotEmpty) {
      return localText;
    }

    throw UnsupportedError(
      'Image OCR is not available on this platform/device and cloud OCR fallback returned no text.',
    );
  }

  Future<String> extractTextFromImageBytes(
    Uint8List bytes, {
    String fileName = 'upload_image.jpg',
  }) async {
    if (bytes.isEmpty) return '';
    final cloudText = await _extractTextUsingCloudOcr(
      bytes,
      fileName: fileName,
    );
    if (cloudText.trim().isNotEmpty) {
      return cloudText;
    }
    throw UnsupportedError(
      'Image OCR cloud fallback returned no text for the selected file.',
    );
  }

  Future<String> extractTextFromImages(List<File> files) async {
    if (files.isEmpty) return '';
    final chunks = <String>[];

    for (final file in files) {
      final text = await extractTextFromImage(file);
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        chunks.add(trimmed);
      }
    }

    return chunks.join('\n\n');
  }

  Future<String> extractTextFromImagesBytes(
    List<Uint8List> images, {
    List<String>? fileNames,
  }) async {
    if (images.isEmpty) return '';
    final chunks = <String>[];

    for (var i = 0; i < images.length; i++) {
      final bytes = images[i];
      if (bytes.isEmpty) continue;
      final name =
          fileNames != null &&
              i < fileNames.length &&
              fileNames[i].trim().isNotEmpty
          ? fileNames[i].trim()
          : 'upload_image_${i + 1}.jpg';
      final text = await extractTextFromImageBytes(bytes, fileName: name);
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        chunks.add(trimmed);
      }
    }

    return chunks.join('\n\n');
  }

  Future<String> extractTextFromPdf(
    File file, {
    int maxPagesToScan = 8,
    int rasterDpi = 220,
  }) async {
    final bytes = await file.readAsBytes();
    return extractTextFromPdfBytes(
      bytes,
      maxPagesToScan: maxPagesToScan,
      rasterDpi: rasterDpi,
    );
  }

  Future<String> extractTextFromPdfBytes(
    Uint8List bytes, {
    int maxPagesToScan = 8,
    int rasterDpi = 220,
  }) async {
    String selectableText = '';
    Object? selectableExtractionError;

    try {
      selectableText = _extractSelectableTextFromPdf(bytes).trim();
    } catch (e) {
      // Some PDFs (or parser edge-cases) throw at text extraction time.
      // Keep flowing and attempt image-based OCR fallback.
      selectableExtractionError = e;
    }

    if (_hasUsableText(selectableText)) {
      return selectableText;
    }

    if (!_supportsMlKit) {
      try {
        final cloudText = await _extractTextUsingCloudOcr(
          bytes,
          fileName: 'upload.pdf',
        );
        if (cloudText.trim().isNotEmpty) {
          return cloudText.trim();
        }
      } on UnsupportedError {
        // Preserve the more specific PDF fallback message below.
      }
      if (selectableExtractionError != null) {
        throw UnsupportedError(
          'PDF text extraction failed on this file (${selectableExtractionError.runtimeType}). '
          'Cloud OCR fallback did not return readable text.',
        );
      }
      throw UnsupportedError(
        'This PDF appears to be scanned and cloud OCR did not return readable text.',
      );
    }

    final scannedText = await _extractTextFromRasterizedPdf(
      bytes,
      maxPagesToScan: maxPagesToScan,
      rasterDpi: rasterDpi,
    );
    if (scannedText.trim().isNotEmpty) {
      return scannedText.trim();
    }

    return selectableText;
  }

  String _extractSelectableTextFromPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      return extractor.extractText();
    } finally {
      document.dispose();
    }
  }

  bool _hasUsableText(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length < 20) return false;
    return RegExp(r'[A-Za-z0-9]').hasMatch(cleaned);
  }

  bool _hasReliableInvoiceText(String text) {
    return _invoiceTextQuality(text) >= 5;
  }

  int _invoiceTextQuality(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.trim().isEmpty) return 0;

    var score = normalized.length >= 120 ? 2 : 0;
    if (RegExp(r'invoice|tax invoice|bill no').hasMatch(normalized)) score++;
    if (RegExp(r'gstin|cgst|sgst|igst').hasMatch(normalized)) score++;
    if (RegExp(r'grand total|net amount|total amount').hasMatch(normalized)) {
      score++;
    }
    if (RegExp(r'hsn|sac|qty|quantity|rate').hasMatch(normalized)) score++;
    if (extractGstins(text).isNotEmpty) score++;
    return score;
  }

  Future<String> _extractTextFromRasterizedPdf(
    Uint8List pdfBytes, {
    required int maxPagesToScan,
    required int rasterDpi,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('invoice_pdf_ocr_');
    final pageTexts = <String>[];
    var pageIndex = 0;

    try {
      await for (final page in Printing.raster(
        pdfBytes,
        dpi: rasterDpi.toDouble(),
      )) {
        if (pageIndex >= maxPagesToScan) {
          break;
        }

        final pngBytes = await page.toPng();
        if (pngBytes.isEmpty) {
          pageIndex++;
          continue;
        }

        final pageFile = File(
          '${tempDir.path}${Platform.pathSeparator}page_$pageIndex.png',
        );
        await pageFile.writeAsBytes(pngBytes, flush: true);

        final text = await extractTextFromImage(pageFile);
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          pageTexts.add(trimmed);
        }

        pageIndex++;
      }
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }

    return pageTexts.join('\n\n');
  }

  Future<String> _extractTextUsingCloudOcr(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final endpoint = _cloudOcrEndpoint.trim();
    final apiKey = _cloudOcrApiKey.trim();

    if (endpoint.isEmpty || apiKey.isEmpty) {
      throw UnsupportedError(
        'Cloud OCR is not configured. Set OCR_CLOUD_URL and OCR_CLOUD_API_KEY.',
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 40),
      ),
    );

    try {
      final formData = FormData.fromMap({
        'apikey': apiKey,
        'language': 'eng',
        'OCREngine': '2',
        'isOverlayRequired': 'false',
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await dio.post<dynamic>(endpoint, data: formData);
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final directText = (data['text'] as String?)?.trim() ?? '';
        if (directText.isNotEmpty) {
          return directText;
        }

        final parsedResults = data['ParsedResults'];
        if (parsedResults is List && parsedResults.isNotEmpty) {
          final first = parsedResults.first;
          if (first is Map<String, dynamic>) {
            final parsedText = (first['ParsedText'] as String?)?.trim() ?? '';
            if (parsedText.isNotEmpty) {
              return parsedText;
            }
          }
        }

        final cloudError = (data['ErrorMessage']?.toString() ?? '').trim();
        if (cloudError.isNotEmpty) {
          throw UnsupportedError('Cloud OCR error: $cloudError');
        }
      }

      return '';
    } on DioException catch (e) {
      throw UnsupportedError('Cloud OCR request failed: ${e.message}');
    }
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return 'upload_image.jpg';
    final parts = normalized.split('/');
    if (parts.isEmpty) return 'upload_image.jpg';
    final last = parts.last.trim();
    return last.isEmpty ? 'upload_image.jpg' : last;
  }

  ParsedInvoiceData parseInvoiceText(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final gstins = extractGstins(rawText);
    final gstin = gstins.isEmpty ? '' : gstins.first;
    final mobile = _extractMobile(rawText);
    final billNumber = _extractBillNumber(rawText);
    final billDate = _extractBillDate(rawText);
    final partyName = _extractPartyName(lines);
    final partyAddress = _extractPartyAddress(lines);
    final detectedGstPercentage = _extractDocumentGstPercentage(rawText);
    final items = _extractItems(lines)
        .map(
          (item) => item.gstPercentage > 0 || detectedGstPercentage <= 0
              ? item
              : item.copyWith(gstPercentage: detectedGstPercentage),
        )
        .toList(growable: false);
    final totalAmount = _extractTotalAmount(rawText, items: items);

    return ParsedInvoiceData(
      partyName: partyName,
      partyAddress: partyAddress,
      gstin: gstin,
      gstins: gstins,
      mobile: mobile,
      billNumber: billNumber,
      billDate: billDate,
      totalAmount: totalAmount,
      items: items,
      rawText: rawText,
    );
  }

  OcrValidationResult validateParsedData(ParsedInvoiceData parsed) {
    var score = 1.0;
    final warnings = <String>[];

    if (parsed.billNumber.trim().isEmpty) {
      score -= 0.2;
      warnings.add('Invoice number not detected');
    }
    if (parsed.billDate.trim().isEmpty) {
      score -= 0.15;
      warnings.add('Invoice date not detected');
    }
    if (parsed.partyName.trim().length < 3) {
      score -= 0.15;
      warnings.add('Party name confidence is low');
    }
    if (parsed.gstin.trim().isEmpty) {
      score -= 0.1;
      warnings.add('GSTIN not detected');
    }
    if (parsed.items.isEmpty) {
      score -= 0.2;
      warnings.add('No line items detected');
    }
    if (parsed.totalAmount <= 0) {
      score -= 0.1;
      warnings.add('Grand total not detected');
    }
    if (parsed.rawText.trim().length < 40) {
      score -= 0.1;
      warnings.add('Very low OCR text length');
    }

    if (score < 0) score = 0;
    return OcrValidationResult(
      confidence: double.parse(score.toStringAsFixed(2)),
      warnings: warnings,
    );
  }

  OcrDocumentAnalysis analyzeDocumentType(
    String rawText, {
    ParsedInvoiceData? parsed,
  }) {
    final text = rawText.toLowerCase();
    final score = <OcrDocumentKind, double>{
      OcrDocumentKind.salesInvoice: 0,
      OcrDocumentKind.purchaseBill: 0,
      OcrDocumentKind.creditNote: 0,
      OcrDocumentKind.debitNote: 0,
      OcrDocumentKind.chequeGiven: 0,
      OcrDocumentKind.chequeReceived: 0,
      OcrDocumentKind.paymentVoucher: 0,
      OcrDocumentKind.receiptVoucher: 0,
      OcrDocumentKind.unknown: 0,
    };

    final signals = <String>[];

    void mark(OcrDocumentKind kind, double points, String signal) {
      score[kind] = (score[kind] ?? 0) + points;
      signals.add(signal);
    }

    if (RegExp(
      r'sales\s+invoice|tax\s+invoice|invoice\s+for\s+sale',
    ).hasMatch(text)) {
      mark(OcrDocumentKind.salesInvoice, 1.1, 'sales-invoice keyword');
    }
    if (RegExp(
      r'purchase\s+bill|purchase\s+invoice|vendor\s+bill',
    ).hasMatch(text)) {
      mark(OcrDocumentKind.purchaseBill, 1.1, 'purchase-bill keyword');
    }
    if (RegExp(r'credit\s*note|cn\s*no').hasMatch(text)) {
      mark(OcrDocumentKind.creditNote, 1.2, 'credit-note keyword');
    }
    if (RegExp(r'debit\s*note|dn\s*no').hasMatch(text)) {
      mark(OcrDocumentKind.debitNote, 1.2, 'debit-note keyword');
    }
    if (RegExp(r'payment\s+voucher|payment\s+entry|paid\s+to').hasMatch(text)) {
      mark(OcrDocumentKind.paymentVoucher, 1.0, 'payment-voucher keyword');
    }
    if (RegExp(
      r'receipt\s+voucher|receipt\s+entry|received\s+from',
    ).hasMatch(text)) {
      mark(OcrDocumentKind.receiptVoucher, 1.0, 'receipt-voucher keyword');
    }
    if (RegExp(
      r'cheque\s+issued|cheque\s+given|issued\s+cheque',
    ).hasMatch(text)) {
      mark(OcrDocumentKind.chequeGiven, 1.2, 'cheque-given keyword');
    }
    if (RegExp(r'cheque\s+received|received\s+cheque').hasMatch(text)) {
      mark(OcrDocumentKind.chequeReceived, 1.2, 'cheque-received keyword');
    }

    if (RegExp(r'customer|bill\s*to|buyer').hasMatch(text)) {
      mark(OcrDocumentKind.salesInvoice, 0.35, 'customer/bill-to signal');
    }
    if (RegExp(r'vendor|supplier').hasMatch(text)) {
      mark(OcrDocumentKind.purchaseBill, 0.35, 'vendor/supplier signal');
    }
    if (RegExp(r'utr|neft|rtgs|imps|upi').hasMatch(text)) {
      mark(OcrDocumentKind.paymentVoucher, 0.25, 'bank transfer signal');
      mark(OcrDocumentKind.receiptVoucher, 0.25, 'bank transfer signal');
    }

    if (parsed != null && parsed.items.isNotEmpty) {
      mark(OcrDocumentKind.salesInvoice, 0.2, 'line-items signal');
      mark(OcrDocumentKind.purchaseBill, 0.2, 'line-items signal');
    }

    OcrDocumentKind bestKind = OcrDocumentKind.unknown;
    var bestScore = 0.0;
    score.forEach((kind, value) {
      if (value > bestScore) {
        bestScore = value;
        bestKind = kind;
      }
    });

    if (bestScore < 0.75) {
      return OcrDocumentAnalysis(
        kind: OcrDocumentKind.unknown,
        confidence: bestScore,
        signals: signals,
      );
    }

    final confidence = (bestScore / 2).clamp(0.0, 1.0);
    return OcrDocumentAnalysis(
      kind: bestKind,
      confidence: double.parse(confidence.toStringAsFixed(2)),
      signals: signals,
    );
  }

  DuplicateDetectionResult detectDuplicates({
    required ParsedInvoiceData parsed,
    required Iterable<InvoiceFingerprint> existing,
  }) {
    final result = <DuplicateMatch>[];
    for (final candidate in existing) {
      final scoreInfo = _scoreDuplicate(parsed, candidate);
      final score = scoreInfo.$1;
      final reasons = scoreInfo.$2;
      if (score >= 0.6) {
        result.add(
          DuplicateMatch(candidate: candidate, score: score, reasons: reasons),
        );
      }
    }

    result.sort((a, b) => b.score.compareTo(a.score));
    return DuplicateDetectionResult(
      matches: result.take(3).toList(growable: false),
    );
  }

  (double, List<String>) _scoreDuplicate(
    ParsedInvoiceData parsed,
    InvoiceFingerprint existing,
  ) {
    var score = 0.0;
    final reasons = <String>[];

    final parsedNumber = _normalizeToken(parsed.billNumber);
    final existingNumber = _normalizeToken(existing.referenceNumber);
    if (parsedNumber.isNotEmpty && parsedNumber == existingNumber) {
      score += 0.55;
      reasons.add('same invoice number');
    }

    final parsedGstin = _normalizeToken(parsed.gstin);
    final existingGstin = _normalizeToken(existing.gstin);
    if (parsedGstin.isNotEmpty && parsedGstin == existingGstin) {
      score += 0.2;
      reasons.add('same GSTIN');
    }

    final parsedDate = _normalizeToken(parsed.billDate);
    final existingDate = _normalizeToken(existing.billDate);
    if (parsedDate.isNotEmpty && parsedDate == existingDate) {
      score += 0.15;
      reasons.add('same bill date');
    }

    final parsedParty = _normalizeToken(parsed.partyName);
    final existingParty = _normalizeToken(existing.partyName);
    if (parsedParty.isNotEmpty && existingParty.isNotEmpty) {
      if (parsedParty == existingParty) {
        score += 0.15;
        reasons.add('same party');
      } else if (parsedParty.contains(existingParty) ||
          existingParty.contains(parsedParty)) {
        score += 0.08;
        reasons.add('similar party');
      }
    }

    if (parsed.totalAmount > 0 && existing.totalAmount > 0) {
      final delta = (parsed.totalAmount - existing.totalAmount).abs();
      final tolerance = parsed.totalAmount * 0.01;
      if (delta <= tolerance) {
        score += 0.1;
        reasons.add('similar total amount');
      }
    }

    if (score > 1) score = 1;
    return (double.parse(score.toStringAsFixed(2)), reasons);
  }

  String _normalizeToken(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  void dispose() {
    _textRecognizer?.close();
  }

  List<String> extractGstins(String text) {
    return RegExp(r'\b\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]\b')
        .allMatches(text.toUpperCase())
        .map((match) => match.group(0)!)
        .toSet()
        .toList(growable: false);
  }

  bool isRelatedToBusiness(String text, String businessGstin) {
    final normalized = businessGstin.trim().toUpperCase();
    return normalized.isNotEmpty && extractGstins(text).contains(normalized);
  }

  String _extractMobile(String text) {
    final match = RegExp(r'(?:\+91[-\s]?)?[6-9]\d{9}').firstMatch(text);
    if (match == null) return '';
    return match.group(0)?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  }

  String _extractBillNumber(String text) {
    final match = RegExp(
      r'(?:invoice|cash\s*bill|bill|voucher|receipt|ref(?:erence)?)\s*(?:no|number|#)?\s*[:\-]?\s*([A-Z0-9\-/]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final candidate = match?.group(1)?.trim() ?? '';
    if (RegExp(
      r'^(?:copy|date|total|value|amount|to|from|of)$',
      caseSensitive: false,
    ).hasMatch(candidate)) {
      return '';
    }
    return candidate;
  }

  String _extractBillDate(String text) {
    final dateMatch = RegExp(
      r'\b(\d{1,2}[\-/]\d{1,2}[\-/]\d{2,4}|\d{4}[\-/]\d{1,2}[\-/]\d{1,2})\b',
    ).firstMatch(text);
    final raw = dateMatch?.group(1) ?? '';
    return _normalizeDate(raw);
  }

  double _extractTotalAmount(
    String text, {
    required List<ParsedInvoiceItem> items,
  }) {
    final normalized = text.replaceAll(',', '');
    final keywordMatches = RegExp(
      r'(?:grand\s*total|net\s*amount|invoice\s*value|total\s*amount|amount\s*payable|(?<!sub)\btotal)\s*[:\-]?\s*(?:rs\.?|inr|₹)?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).allMatches(normalized);

    final keywordValues = <double>[];
    for (final match in keywordMatches) {
      final value = double.tryParse(match.group(1) ?? '0') ?? 0;
      if (value > 0) keywordValues.add(value);
    }
    keywordValues.sort();
    for (final value in keywordValues.reversed) {
      if (_isPlausibleInvoiceTotal(value, items)) return value;
    }
    if (keywordValues.isNotEmpty) return 0;

    final allNumbers = RegExp(r'\b\d+(?:\.\d{1,2})\b')
        .allMatches(normalized)
        .map((m) => double.tryParse(m.group(0) ?? '0') ?? 0)
        .where((v) => v > 0)
        .toList(growable: false);

    if (allNumbers.isEmpty) return 0;
    allNumbers.sort();
    for (final value in allNumbers.reversed) {
      if (_isPlausibleInvoiceTotal(value, items)) return value;
    }
    return 0;
  }

  bool _isPlausibleInvoiceTotal(double value, List<ParsedInvoiceItem> items) {
    if (!value.isFinite || value <= 0 || value > 100000000000) return false;
    if (items.isEmpty) return true;

    final itemSubtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.rate),
    );
    if (itemSubtotal <= 0) return true;
    return value <= math.max(itemSubtotal * 100, 1000000);
  }

  String _normalizeDate(String raw) {
    if (raw.isEmpty) return '';
    final clean = raw.replaceAll('/', '-');
    final parts = clean.split('-');
    if (parts.length != 3) return '';

    if (parts[0].length == 4) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return '';
      if (m < 1 || m > 12 || d < 1 || d > 31) return '';
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    }

    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    var y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return '';
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return '';
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }

  String _extractPartyName(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.startsWith('m/s')) return lines[i].trim();
      if (line.contains('sold to') ||
          line.contains('bill to') ||
          line.contains('buyer') ||
          line.contains('customer') ||
          line.contains('supplier') ||
          line.contains('vendor') ||
          line.contains('party')) {
        final separator = RegExp(r'[:\-]').firstMatch(lines[i]);
        if (separator != null) {
          final candidate = lines[i].substring(separator.end).trim();
          if (candidate.length >= 3) return candidate;
        }
        if (i + 1 < lines.length && lines[i + 1].length >= 3) {
          return lines[i + 1];
        }
      }
    }

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_isLikelyHeader(lower)) continue;
      if (line.length >= 4 && RegExp(r'[A-Za-z]').hasMatch(line)) {
        return line;
      }
    }
    return '';
  }

  String _extractPartyAddress(List<String> lines) {
    for (var index = 0; index < lines.length; index++) {
      final header = lines[index].toLowerCase();
      if (!header.contains('bill to') && !header.contains('buyer')) continue;

      final address = <String>[];
      for (var cursor = index + 2; cursor < lines.length; cursor++) {
        final value = lines[cursor].trim();
        final lower = value.toLowerCase();
        if (RegExp(
          r'gstin|gst\s*/\s*uin|state\s*name|buyer|ship\s*to',
        ).hasMatch(lower)) {
          break;
        }
        if (value.isNotEmpty && !RegExp(r'^\d+\s').hasMatch(value)) {
          address.add(value);
        }
      }
      return address.join(', ');
    }
    return '';
  }

  bool _isLikelyHeader(String line) {
    const blockers = [
      'invoice',
      'bill',
      'tax',
      'gst',
      'cgst',
      'sgst',
      'igst',
      'phone',
      'mobile',
      'email',
      'date',
      'amount',
      'total',
      'subtotal',
      'hsn',
      'qty',
      'rate',
    ];
    return blockers.any(line.contains);
  }

  List<ParsedInvoiceItem> _extractItems(List<String> lines) {
    final items = <ParsedInvoiceItem>[];
    final tableLayout = _detectItemTableLayout(lines);

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final lower = line.toLowerCase();
      if (_isLikelyHeader(lower)) continue;
      if (_isNonItemLabel(lower)) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(line)) continue;

      final isCharge = _isChargeLine(lower);
      if (!isCharge &&
          items.isNotEmpty &&
          (!RegExp(r'\d').hasMatch(line) ||
              RegExp(
                r'^\d+(?:\.\d+)?\s*(?:MM|CM|MTR|PCS?|NOS?)\b',
                caseSensitive: false,
              ).hasMatch(line)) &&
          line.length >= 3) {
        final previous = items.last;
        if (previous.lineType == ParsedInvoiceLineType.product) {
          items[items.length - 1] = previous.copyWith(description: line);
        }
        continue;
      }

      final normalizedLine = line.replaceFirst(RegExp(r'^\s*\d+[.)]?\s+'), '');
      final hsnPattern = tableLayout.hasHsnColumn
          ? RegExp(r'\b\d{4,8}\b')
          : RegExp(r'\b\d{6,8}\b');
      final hsnMatch = hsnPattern.firstMatch(normalizedLine);
      final valueSource = hsnMatch == null
          ? normalizedLine
          : normalizedLine.replaceRange(hsnMatch.start, hsnMatch.end, ' ');
      final amountSource = isCharge
          ? valueSource.replaceAll(RegExp(r'\b\d{1,2}(?:\.\d+)?\s*%'), '')
          : valueSource;
      final numberMatches = RegExp(
        r'(?<![A-Za-z0-9])\d[\d,]*(?:\.\d+)?(?=\s|%|$)',
      ).allMatches(amountSource).toList(growable: false);
      final numbers = numberMatches
          .map(
            (m) =>
                double.tryParse((m.group(0) ?? '0').replaceAll(',', '')) ?? 0,
          )
          .toList(growable: false);
      if ((!isCharge && numbers.length < 2) || (isCharge && numbers.isEmpty)) {
        continue;
      }

      final qtyIndex = tableLayout.quantityValueIndex;
      final rateIndex = tableLayout.rateValueIndex;
      final qty = isCharge
          ? 1.0
          : qtyIndex < numbers.length
          ? numbers[qtyIndex]
          : numbers[0];
      final rate = isCharge
          ? numbers.last
          : rateIndex < numbers.length
          ? numbers[rateIndex]
          : numbers[1];
      if (qty <= 0 || rate <= 0) continue;

      final firstValue = numberMatches.firstOrNull;
      final name =
          (firstValue == null
                  ? valueSource
                  : valueSource.substring(0, firstValue.start))
              .trim();
      if (name.length < 2) continue;

      final hsnCode = hsnMatch?.group(0) ?? '';
      final gstPercentage = _extractLineGstPercentage(line);

      final item = ParsedInvoiceItem(
        name: name,
        hsnCode: hsnCode,
        quantity: qty,
        rate: rate,
        gstPercentage: gstPercentage,
        lineType: isCharge
            ? ParsedInvoiceLineType.charge
            : ParsedInvoiceLineType.product,
        suggestedLedger: isCharge ? 'Indirect Income' : 'Sales Account',
      );
      final duplicate = items.any(
        (existing) =>
            existing.name.trim().toLowerCase() == name.toLowerCase() &&
            existing.hsnCode == hsnCode &&
            (existing.quantity - qty).abs() < 0.0001 &&
            (existing.rate - rate).abs() < 0.0001,
      );
      if (!duplicate) items.add(item);

      if (items.length >= 100) break;
    }

    return items;
  }

  bool _isNonItemLabel(String line) {
    return RegExp(
      r'^\s*(?:survey|site|plot|door|property|building|floor|address|village|taluk|district|state|pin(?:code)?|document)\s*(?:no\.?|number|name|:)\b',
    ).hasMatch(line);
  }

  _InvoiceItemTableLayout _detectItemTableLayout(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (!RegExp(r'\b(hsn|sac)\b').hasMatch(lower) ||
          !RegExp(
            r'\b(product|item|description|particulars|goods)\b',
          ).hasMatch(lower)) {
        continue;
      }

      final numericColumns = <({int position, String field})>[];
      void addColumn(String field, RegExp pattern) {
        final match = pattern.firstMatch(lower);
        if (match != null) {
          numericColumns.add((position: match.start, field: field));
        }
      }

      addColumn('quantity', RegExp(r'\b(qty|quantity)\b'));
      addColumn('rate', RegExp(r'\b(rate|price|unit\s*price)\b'));
      addColumn('discount', RegExp(r'\b(discount|disc)\b'));
      addColumn('tax', RegExp(r'\b(gst|tax)\s*%?'));
      addColumn('amount', RegExp(r'\b(amount|value|total)\b'));
      numericColumns.sort(
        (left, right) => left.position.compareTo(right.position),
      );

      final fields = numericColumns.map((column) => column.field).toList();
      final quantityIndex = fields.indexOf('quantity');
      final rateIndex = fields.indexOf('rate');
      return _InvoiceItemTableLayout(
        hasHsnColumn: true,
        quantityValueIndex: quantityIndex < 0 ? 0 : quantityIndex,
        rateValueIndex: rateIndex < 0 ? 1 : rateIndex,
      );
    }
    return const _InvoiceItemTableLayout();
  }

  bool _isChargeLine(String line) {
    return RegExp(
      r'\b(admin(?:istration)?|handling|packing|freight|delivery|transport|courier|service|installation|loading|unloading|misc(?:ellaneous)?)\s*(?:charge|charges|fee)?\b',
    ).hasMatch(line);
  }

  double _extractLineGstPercentage(String line) {
    final match = RegExp(r'\b(\d{1,2}(?:\.\d+)?)\s*%').firstMatch(line);
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }

  double _extractDocumentGstPercentage(String text) {
    double rateFor(String label) {
      final match = RegExp(
        '$label[^\n%]{0,24}(\\d{1,2}(?:\\.\\d+)?)\\s*%',
        caseSensitive: false,
      ).firstMatch(text);
      return double.tryParse(match?.group(1) ?? '') ?? 0;
    }

    final igst = rateFor('IGST');
    if (igst > 0) return igst;
    final cgst = rateFor('CGST');
    final sgst = rateFor('SGST');
    if (cgst > 0 && sgst > 0) return cgst + sgst;
    return 0;
  }
}
