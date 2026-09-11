import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/services/secure_storage_service.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/smart_invoice_engine.dart';

class RemoteOcrDocument {
  const RemoteOcrDocument({
    required this.id,
    required this.clientId,
    required this.assignedAccountantId,
    required this.fileName,
    required this.status,
    required this.uploadedAt,
    required this.updatedAt,
    required this.exactDuplicate,
    required this.result,
    this.failureReason,
  });

  final String id;
  final String clientId;
  final String assignedAccountantId;
  final String fileName;
  final String status;
  final DateTime uploadedAt;
  final DateTime updatedAt;
  final bool exactDuplicate;
  final String? failureReason;
  final SmartInvoiceResult? result;

  factory RemoteOcrDocument.fromJson(Map<String, dynamic> json) {
    final draftValue = json['draftJson'] ?? json['DraftJson'];
    Map<String, dynamic>? draft;
    if (draftValue is String && draftValue.trim().isNotEmpty) {
      final decoded = jsonDecode(draftValue);
      if (decoded is Map) draft = Map<String, dynamic>.from(decoded);
    } else if (draftValue is Map) {
      draft = Map<String, dynamic>.from(draftValue);
    }

    final duplicate =
        json['exactDuplicate'] == true || json['ExactDuplicate'] == true;
    return RemoteOcrDocument(
      id: _string(json, 'id'),
      clientId: _string(json, 'clientId'),
      assignedAccountantId: _string(json, 'assignedAccountantId'),
      fileName: _string(json, 'originalFileName'),
      status: _string(json, 'status'),
      uploadedAt: _date(json, 'uploadedAt'),
      updatedAt: _date(json, 'updatedAt'),
      exactDuplicate: duplicate,
      failureReason: _nullableString(json, 'failureReason'),
      result: draft == null ? null : _resultFromDraft(draft, duplicate),
    );
  }

  static SmartInvoiceResult _resultFromDraft(
    Map<String, dynamic> draft,
    bool duplicate,
  ) {
    final confidence = _number(draft, 'confidence');
    final cgst = _number(draft, 'cgst');
    final sgst = _number(draft, 'sgst');
    final igst = _number(draft, 'igst');
    final taxable = _number(draft, 'taxableAmount');
    final total = _number(draft, 'totalAmount');
    final gstin = _string(draft, 'gstin');
    final explanation = _string(draft, 'classificationExplanation');
    final partyName = _string(draft, 'partyName');
    final parsed = ParsedInvoiceData(
      partyName: partyName,
      gstin: gstin,
      billNumber: _string(draft, 'documentNumber'),
      billDate: _string(draft, 'date'),
      taxableAmount: taxable,
      totalTax: cgst + sgst + igst,
      totalAmount: total,
      extractionConfidence: confidence,
      rawText: _draftPreview(draft),
    );
    return SmartInvoiceResult(
      detectedKind: _documentKind(_string(draft, 'voucherType')),
      detectionReason: explanation,
      signals: const SmartMatchSignals(),
      gstResult: SmartGstResult(
        formatValid: gstin.isNotEmpty,
        detectedSellerGstin: gstin,
      ),
      partyMatch: partyName.isEmpty
          ? null
          : SmartMasterMatch(
              ocrText: partyName,
              matchedName: partyName,
              gstin: gstin,
              confidence: confidence,
              isNewMaster: _string(draft, 'partyLedgerId').isEmpty,
            ),
      taxResult: SmartTaxResult(
        extractedCgst: cgst,
        extractedSgst: sgst,
        extractedIgst: igst,
        extractedTotal: total,
        calculatedTotal: taxable + cgst + sgst + igst,
        taxCalcMatch: (taxable + cgst + sgst + igst - total).abs() <= 1,
      ),
      duplicateResult: SmartDuplicateResult(isDuplicate: duplicate),
      confidence: SmartConfidenceBreakdown(
        invoice: confidence,
        customer: confidence,
        gst: confidence,
        total: confidence,
        overall: confidence,
      ),
      classificationReasons: explanation.isEmpty ? const [] : [explanation],
      parsedData: parsed,
    );
  }

  static String _draftPreview(Map<String, dynamic> draft) {
    final fields = <String>[
      'Party: ${_string(draft, 'partyName')}',
      'Document No: ${_string(draft, 'documentNumber')}',
      'Date: ${_string(draft, 'date')}',
      'GSTIN: ${_string(draft, 'gstin')}',
      'Total: ${_number(draft, 'totalAmount').toStringAsFixed(2)}',
    ];
    return fields.where((line) => !line.endsWith(': ')).join('\n');
  }

  static OcrDocumentKind _documentKind(String value) {
    switch (value.toLowerCase()) {
      case 'sales':
        return OcrDocumentKind.salesInvoice;
      case 'purchase':
      case 'expense':
      case 'assetpurchase':
        return OcrDocumentKind.purchaseBill;
      case 'creditnote':
        return OcrDocumentKind.creditNote;
      case 'debitnote':
        return OcrDocumentKind.debitNote;
      case 'receipt':
      case 'bankreceipt':
        return OcrDocumentKind.receiptVoucher;
      case 'payment':
      case 'bankpayment':
        return OcrDocumentKind.paymentVoucher;
      default:
        return OcrDocumentKind.unknown;
    }
  }

  static String _string(Map<String, dynamic> json, String key) =>
      _nullableString(json, key) ?? '';

  static String? _nullableString(Map<String, dynamic> json, String key) {
    final pascalKey = '${key[0].toUpperCase()}${key.substring(1)}';
    final value = json[key] ?? json[pascalKey];
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _number(Map<String, dynamic> json, String key) =>
      double.tryParse(_string(json, key)) ?? 0;

  static DateTime _date(Map<String, dynamic> json, String key) =>
      DateTime.tryParse(_string(json, key)) ?? DateTime.now();
}

class OcrModuleApiService {
  OcrModuleApiService({Dio? dio}) : _dio = dio ?? Dio();

  static const String baseUrl = String.fromEnvironment(
    'OCR_API_BASE_URL',
    defaultValue: '',
  );

  final Dio _dio;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<List<RemoteOcrDocument>> documents({
    required String clientId,
    required String assignedAccountantId,
    required bool clientRole,
  }) async {
    if (!isConfigured) return const <RemoteOcrDocument>[];
    final response = await _dio.get<List<dynamic>>(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/ocr/documents',
      options: Options(
        headers: await _headers(
          clientId,
          assignedAccountantId,
          clientRole: clientRole,
        ),
      ),
    );
    return (response.data ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(RemoteOcrDocument.fromJson)
        .toList(growable: false);
  }

  Future<String?> upload({
    required String clientId,
    required String assignedAccountantId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!isConfigured) return null;

    final token = await SecureStorageService.getAccessToken();
    final response = await _dio.post<List<dynamic>>(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/ocr/upload',
      data: FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
      options: Options(
        headers: <String, dynamic>{
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
          'X-Client-Id': clientId,
          'X-Accountant-Id': assignedAccountantId,
          'X-Role': 'Client',
        },
      ),
    );

    final items = response.data;
    if (items == null || items.isEmpty || items.first is! Map) {
      throw const FormatException('OCR service returned an invalid response.');
    }
    final item = Map<String, dynamic>.from(items.first as Map);
    final id = (item['id'] ?? item['Id'])?.toString().trim();
    if (id == null || id.isEmpty) {
      final error = (item['error'] ?? item['Error'])?.toString();
      throw FormatException(error ?? 'OCR service did not accept the file.');
    }
    return id;
  }

  Future<void> rename({
    required String documentId,
    required String clientId,
    required String assignedAccountantId,
    required String fileName,
  }) async {
    if (!isConfigured) return;
    await _dio.patch<void>(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/ocr/documents/$documentId',
      data: <String, dynamic>{'fileName': fileName},
      options: Options(headers: await _headers(clientId, assignedAccountantId)),
    );
  }

  Future<void> delete({
    required String documentId,
    required String clientId,
    required String assignedAccountantId,
  }) async {
    if (!isConfigured) return;
    await _dio.delete<void>(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/ocr/documents/$documentId',
      options: Options(headers: await _headers(clientId, assignedAccountantId)),
    );
  }

  Future<void> complete({
    required String documentId,
    required String clientId,
    required String assignedAccountantId,
    String? voucherId,
  }) async {
    if (!isConfigured) return;
    await _dio.post<void>(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/ocr/complete/$documentId',
      data: <String, dynamic>{'voucherId': voucherId},
      options: Options(
        headers: await _headers(
          clientId,
          assignedAccountantId,
          clientRole: false,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _headers(
    String clientId,
    String assignedAccountantId, {
    bool clientRole = true,
  }) async {
    final token = await SecureStorageService.getAccessToken();
    return <String, dynamic>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'X-Client-Id': clientId,
      'X-Accountant-Id': assignedAccountantId,
      'X-Role': clientRole ? 'Client' : 'Accountant',
    };
  }
}
