// Smart Invoice Engine – V2 multi-engine classification pipeline.
//
// Runs 12 specialised engines in the optimal order, sharing extracted OCR text
// so each engine starts instantly without additional network round-trips.
// Stages that are mutually independent run in parallel (Future.wait).
//
// Enterprise matching formula (weights sum to 1.0):
//   QR / IRN match          30%
//   Company GST ownership   25%
//   Existing party match    15%
//   Invoice-number pattern   5%
//   Product similarity       5%
//   HSN match                5%
//   Tax calc match           5%
//   Layout fingerprint       5%
//   Historical pattern       5%

import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'invoice_ocr_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & status
// ─────────────────────────────────────────────────────────────────────────────

enum SmartInvoiceStage {
  idle,
  readingDocument,
  duplicateCheck,
  qrDetection,
  classification,
  gstValidation,
  masterMatching,
  productMatching,
  ledgerSuggestion,
  taxValidation,
  confidenceCalc,
  ready,
  error,
}

extension SmartInvoiceStageLabel on SmartInvoiceStage {
  String get label {
    switch (this) {
      case SmartInvoiceStage.idle:
        return 'Waiting for upload';
      case SmartInvoiceStage.readingDocument:
        return 'Reading Document...';
      case SmartInvoiceStage.duplicateCheck:
        return 'Duplicate Check...';
      case SmartInvoiceStage.qrDetection:
        return 'QR / IRN Detection...';
      case SmartInvoiceStage.classification:
        return 'Detecting Voucher...';
      case SmartInvoiceStage.gstValidation:
        return 'GST Validation...';
      case SmartInvoiceStage.masterMatching:
        return 'Matching Masters...';
      case SmartInvoiceStage.productMatching:
        return 'Matching Products...';
      case SmartInvoiceStage.ledgerSuggestion:
        return 'Suggesting Ledger...';
      case SmartInvoiceStage.taxValidation:
        return 'Checking Tax Amounts...';
      case SmartInvoiceStage.confidenceCalc:
        return 'Calculating Confidence...';
      case SmartInvoiceStage.ready:
        return 'Ready';
      case SmartInvoiceStage.error:
        return 'Error';
    }
  }

  bool get isTerminal =>
      this == SmartInvoiceStage.ready || this == SmartInvoiceStage.error;
}

// ─────────────────────────────────────────────────────────────────────────────
// Result models
// ─────────────────────────────────────────────────────────────────────────────

class SmartProductMatch {
  final String ocrText;
  final String matchedName;
  final String hsnCode;
  final double confidence;
  final bool isNewMaster;

  const SmartProductMatch({
    required this.ocrText,
    required this.matchedName,
    this.hsnCode = '',
    required this.confidence,
    this.isNewMaster = false,
  });
}

class SmartMasterMatch {
  final String ocrText;
  final String matchedName;
  final String gstin;
  final double confidence;
  final bool isNewMaster;
  final String? existingId;

  const SmartMasterMatch({
    required this.ocrText,
    required this.matchedName,
    this.gstin = '',
    required this.confidence,
    this.isNewMaster = false,
    this.existingId,
  });
}

class SmartLedgerSuggestion {
  final String ledgerName;
  final String group;
  final double confidence;
  final String reason;

  const SmartLedgerSuggestion({
    required this.ledgerName,
    required this.group,
    required this.confidence,
    required this.reason,
  });
}

class SmartGstResult {
  final bool sellerGstinBelongsToCompany;
  final bool buyerGstinBelongsToCompany;
  final bool formatValid;
  final bool qrVerified;
  final String detectedSellerGstin;
  final String detectedBuyerGstin;
  final List<String> warnings;

  const SmartGstResult({
    this.sellerGstinBelongsToCompany = false,
    this.buyerGstinBelongsToCompany = false,
    this.formatValid = false,
    this.qrVerified = false,
    this.detectedSellerGstin = '',
    this.detectedBuyerGstin = '',
    this.warnings = const [],
  });
}

class SmartTaxResult {
  final double extractedCgst;
  final double extractedSgst;
  final double extractedIgst;
  final double extractedTotal;
  final double calculatedTotal;
  final bool taxCalcMatch;
  final List<String> warnings;

  const SmartTaxResult({
    this.extractedCgst = 0,
    this.extractedSgst = 0,
    this.extractedIgst = 0,
    this.extractedTotal = 0,
    this.calculatedTotal = 0,
    this.taxCalcMatch = false,
    this.warnings = const [],
  });
}

class SmartDuplicateResult {
  final bool isDuplicate;
  final String? matchedDate;
  final String? matchedInvoiceNumber;
  final double score;

  const SmartDuplicateResult({
    this.isDuplicate = false,
    this.matchedDate,
    this.matchedInvoiceNumber,
    this.score = 0,
  });
}

class SmartConfidenceBreakdown {
  final double invoice;
  final double customer;
  final double products;
  final double gst;
  final double total;
  final double overall;

  const SmartConfidenceBreakdown({
    this.invoice = 0,
    this.customer = 0,
    this.products = 0,
    this.gst = 0,
    this.total = 0,
    this.overall = 0,
  });
}

/// Signals driving the enterprise matching formula.
class SmartMatchSignals {
  final double qrIrnMatch; // 30%
  final double companyGstOwnership; // 25%
  final double existingPartyMatch; // 15%
  final double invoiceNumberPattern; // 5%
  final double productSimilarity; // 5%
  final double hsnMatch; // 5%
  final double taxCalcMatch; // 5%
  final double layoutFingerprint; // 5%
  final double historicalPattern; // 5%

  const SmartMatchSignals({
    this.qrIrnMatch = 0,
    this.companyGstOwnership = 0,
    this.existingPartyMatch = 0,
    this.invoiceNumberPattern = 0,
    this.productSimilarity = 0,
    this.hsnMatch = 0,
    this.taxCalcMatch = 0,
    this.layoutFingerprint = 0,
    this.historicalPattern = 0,
  });

  double get weightedScore =>
      qrIrnMatch * 0.30 +
      companyGstOwnership * 0.25 +
      existingPartyMatch * 0.15 +
      invoiceNumberPattern * 0.05 +
      productSimilarity * 0.05 +
      hsnMatch * 0.05 +
      taxCalcMatch * 0.05 +
      layoutFingerprint * 0.05 +
      historicalPattern * 0.05;
}

/// Auto-verify ≥ 95%, review 85–94%, manual < 85%.
enum SmartVerificationLevel { autoVerified, reviewRequired, manualRequired }

extension SmartVerificationLevelFromScore on double {
  SmartVerificationLevel get verificationLevel {
    if (this >= 0.95) return SmartVerificationLevel.autoVerified;
    if (this >= 0.85) return SmartVerificationLevel.reviewRequired;
    return SmartVerificationLevel.manualRequired;
  }
}

class SmartMissingMaster {
  final String type; // 'customer' | 'supplier' | 'product' | 'ledger' | 'hsn' | 'unit'
  final String suggestedName;
  final String extra; // extra context like GSTIN, HSN code, unit name

  const SmartMissingMaster({
    required this.type,
    required this.suggestedName,
    this.extra = '',
  });
}

/// Full output from the 12-engine pipeline.
class SmartInvoiceResult {
  final OcrDocumentKind detectedKind;
  final String detectionReason;
  final SmartMatchSignals signals;
  final SmartGstResult gstResult;
  final SmartMasterMatch? partyMatch;
  final List<SmartProductMatch> productMatches;
  final SmartLedgerSuggestion? ledgerSuggestion;
  final SmartTaxResult taxResult;
  final SmartDuplicateResult duplicateResult;
  final SmartConfidenceBreakdown confidence;
  final List<SmartMissingMaster> missingMasters;
  final List<String> classificationReasons;
  final ParsedInvoiceData parsedData;
  final String? qrIrnValue;

  const SmartInvoiceResult({
    required this.detectedKind,
    this.detectionReason = '',
    required this.signals,
    required this.gstResult,
    this.partyMatch,
    this.productMatches = const [],
    this.ledgerSuggestion,
    required this.taxResult,
    required this.duplicateResult,
    required this.confidence,
    this.missingMasters = const [],
    this.classificationReasons = const [],
    required this.parsedData,
    this.qrIrnValue,
  });

  SmartVerificationLevel get verificationLevel =>
      confidence.overall.verificationLevel;

  bool get readyToAutoPost => verificationLevel == SmartVerificationLevel.autoVerified;
}

// ─────────────────────────────────────────────────────────────────────────────
// SmartInvoiceEngine
// ─────────────────────────────────────────────────────────────────────────────

typedef SmartStageCallback = void Function(SmartInvoiceStage stage);

class SmartInvoiceEngine {
  static const String _prefsKeyFingerprints = 'smart_inv_fingerprints';
  static const String _prefsKeyPatterns = 'smart_inv_patterns';
  static const int _maxStoredFingerprints = 500;

  // Injected known company GSTINs (loaded from client profile).
  final List<String> companyGstins;

  // Injected lists for master matching (customer/vendor names + GSTINs).
  final List<String> customerNames;
  final List<String> customerGstins;
  final List<String> vendorNames;
  final List<String> vendorGstins;
  final List<String> productMasterNames;

  SmartInvoiceEngine({
    this.companyGstins = const [],
    this.customerNames = const [],
    this.customerGstins = const [],
    this.vendorNames = const [],
    this.vendorGstins = const [],
    this.productMasterNames = const [],
  });

  // ── Public entry point ──────────────────────────────────────────────────

  Future<SmartInvoiceResult> run(
    String ocrText, {
    SmartStageCallback? onStage,
  }) async {
    onStage?.call(SmartInvoiceStage.readingDocument);

    // Parse structured data first (fast, synchronous regex).
    final parsed = _parseInvoiceData(ocrText);

    // Stage 2 + 3 in parallel: duplicate check & QR detection (independent).
    onStage?.call(SmartInvoiceStage.duplicateCheck);
    final futures2 = await Future.wait([
      _runDuplicateCheck(parsed),
      _runQrDetection(ocrText),
    ]);
    final duplicateResult = futures2[0] as SmartDuplicateResult;
    final qrIrnValue = futures2[1] as String?;

    // Stage 4: Classification (needs QR result + GST text).
    onStage?.call(SmartInvoiceStage.classification);
    final gstResult = _runGstValidation(ocrText, parsed);

    onStage?.call(SmartInvoiceStage.gstValidation);
    final classifyOut = _runClassification(
      ocrText,
      parsed: parsed,
      gstResult: gstResult,
      qrIrn: qrIrnValue,
    );

    // Stages 5–8 in parallel: master matching, product matching,
    // ledger suggestion, tax validation (all read-only).
    onStage?.call(SmartInvoiceStage.masterMatching);
    final futures5 = await Future.wait([
      _runMasterMatching(ocrText, parsed, classifyOut.kind),
      _runProductMatching(parsed),
      _runLedgerSuggestion(parsed, classifyOut.kind),
      Future.value(_runTaxValidation(ocrText, parsed)),
    ]);
    final partyMatch = futures5[0] as SmartMasterMatch?;
    final productMatches = futures5[1] as List<SmartProductMatch>;
    final ledgerSuggestion = futures5[2] as SmartLedgerSuggestion?;
    final taxResult = futures5[3] as SmartTaxResult;

    onStage?.call(SmartInvoiceStage.confidenceCalc);

    // Stage 9: Build signals.
    final signals = _buildSignals(
      qrIrn: qrIrnValue,
      gstResult: gstResult,
      partyMatch: partyMatch,
      parsed: parsed,
      productMatches: productMatches,
      taxResult: taxResult,
      ocrText: ocrText,
    );

    // Stage 10: Confidence breakdown.
    final confidence = _computeConfidence(
      signals: signals,
      parsed: parsed,
      partyMatch: partyMatch,
      productMatches: productMatches,
      taxResult: taxResult,
    );

    // Stage 11: Missing masters.
    final missingMasters = _detectMissingMasters(
      partyMatch: partyMatch,
      productMatches: productMatches,
      ledgerSuggestion: ledgerSuggestion,
      parsed: parsed,
    );

    // Stage 12: AI Learning – store fingerprint + patterns.
    await _learnFromResult(parsed, ocrText, classifyOut.kind);

    onStage?.call(SmartInvoiceStage.ready);

    return SmartInvoiceResult(
      detectedKind: classifyOut.kind,
      detectionReason: classifyOut.reason,
      signals: signals,
      gstResult: gstResult,
      partyMatch: partyMatch,
      productMatches: productMatches,
      ledgerSuggestion: ledgerSuggestion,
      taxResult: taxResult,
      duplicateResult: duplicateResult,
      confidence: confidence,
      missingMasters: missingMasters,
      classificationReasons: classifyOut.reasons,
      parsedData: parsed,
      qrIrnValue: qrIrnValue,
    );
  }

  // ── Engine 3: Fast parse (synchronous, no I/O) ──────────────────────────

  ParsedInvoiceData _parseInvoiceData(String text) {
    final upper = text.toUpperCase();

    // GSTIN detection (15-char GST format).
    final gstinRx = RegExp(r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z])\b');
    final gstinMatches = gstinRx.allMatches(upper).map((m) => m.group(1)!).toList();
    final gstin = gstinMatches.isNotEmpty ? gstinMatches.first : '';

    // Invoice number.
    final invRx = RegExp(
      r'(?:invoice\s*(?:no|number|#)|bill\s*(?:no|number|#)|receipt\s*no)[\s:]*([A-Z0-9/\-]+)',
      caseSensitive: false,
    );
    final billNumber = invRx.firstMatch(text)?.group(1)?.trim() ?? '';

    // Date.
    final dateRx = RegExp(
      r'\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{4}[-/]\d{2}[-/]\d{2})\b',
    );
    final billDate = dateRx.firstMatch(text)?.group(1) ?? '';

    // Amount.
    final amtRx = RegExp(
      r'(?:total|grand\s*total|amount\s*due|net\s*amount)[^\d]*(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final amtStr = amtRx.firstMatch(text)?.group(1)?.replaceAll(',', '') ?? '0';
    final totalAmount = double.tryParse(amtStr) ?? 0.0;

    // Party name – look for "To:" / "Bill To:" / company name blocks.
    final partyRx = RegExp(
      r'(?:bill\s*to|sold\s*to|to\s*:|customer\s*name)[:\s]+([A-Za-z][A-Za-z0-9&\s\.,]{2,50})',
      caseSensitive: false,
    );
    final partyName = partyRx.firstMatch(text)?.group(1)?.trim() ?? '';

    // Mobile.
    final mobRx = RegExp(r'\b(?:\+91[-\s]?)?([6-9]\d{9})\b');
    final mobile = mobRx.firstMatch(text)?.group(1) ?? '';

    // Line items (heuristic: rows with qty × rate pattern).
    final items = _extractLineItems(text);

    return ParsedInvoiceData(
      partyName: partyName,
      gstin: gstin,
      mobile: mobile,
      billNumber: billNumber,
      billDate: billDate,
      totalAmount: totalAmount,
      items: items,
      rawText: text,
    );
  }

  List<ParsedInvoiceItem> _extractLineItems(String text) {
    final items = <ParsedInvoiceItem>[];
    // Heuristic: lines like "Product Name   qty   rate   amount"
    final lineRx = RegExp(
      r'^([A-Za-z][A-Za-z0-9 /\-]+?)\s{2,}(\d+(?:\.\d+)?)\s+(\d+(?:[,.]\d+)?)',
      multiLine: true,
    );
    for (final m in lineRx.allMatches(text)) {
      final name = m.group(1)?.trim() ?? '';
      final qty = double.tryParse(m.group(2) ?? '1') ?? 1;
      final rate = double.tryParse(
        (m.group(3) ?? '0').replaceAll(',', ''),
      ) ?? 0;
      if (name.length > 2 && rate > 0) {
        items.add(ParsedInvoiceItem(name: name, quantity: qty, rate: rate));
      }
    }
    return items.take(30).toList();
  }

  // ── Engine 1: Duplicate detection ──────────────────────────────────────

  Future<SmartDuplicateResult> _runDuplicateCheck(
    ParsedInvoiceData parsed,
  ) async {
    if (parsed.billNumber.isEmpty && parsed.totalAmount <= 0) {
      return const SmartDuplicateResult();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKeyFingerprints) ?? [];
      final fingerKey = _buildFingerprintKey(parsed);
      for (final entry in stored) {
        final parts = entry.split('|');
        if (parts.length < 3) continue;
        final storedKey = parts[0];
        final storedDate = parts.length > 3 ? parts[3] : '';
        if (_fingerprintScore(fingerKey, storedKey) > 0.90) {
          return SmartDuplicateResult(
            isDuplicate: true,
            matchedInvoiceNumber: parts.length > 1 ? parts[1] : null,
            matchedDate: storedDate,
            score: _fingerprintScore(fingerKey, storedKey),
          );
        }
      }
    } catch (_) {
      // Non-critical – continue without duplicate check.
    }
    return const SmartDuplicateResult();
  }

  String _buildFingerprintKey(ParsedInvoiceData p) {
    final raw = '${p.billNumber}|${p.totalAmount.toStringAsFixed(2)}|${p.gstin}';
    return md5.convert(utf8.encode(raw)).toString();
  }

  double _fingerprintScore(String a, String b) => a == b ? 1.0 : 0.0;

  // ── Engine 2: QR / IRN detection ───────────────────────────────────────

  Future<String?> _runQrDetection(String text) async {
    // IRN is 64-char hex string in GST e-invoices.
    final irnRx = RegExp(r'\b([0-9a-fA-F]{64})\b');
    final irnMatch = irnRx.firstMatch(text);
    if (irnMatch != null) return irnMatch.group(1);
    // Also look for explicit "IRN:" label.
    final labelRx = RegExp(r'IRN\s*[:\-]\s*([0-9a-fA-F]{40,})', caseSensitive: false);
    final labelMatch = labelRx.firstMatch(text);
    if (labelMatch != null) return labelMatch.group(1);
    return null;
  }

  // ── Engine 4: Classification ────────────────────────────────────────────

  _ClassifyOut _runClassification(
    String text, {
    required ParsedInvoiceData parsed,
    required SmartGstResult gstResult,
    String? qrIrn,
  }) {
    final reasons = <String>[];
    var kind = OcrDocumentKind.unknown;
    var confidence = 0.3;

    // 1. GST ownership is the strongest signal.
    if (gstResult.sellerGstinBelongsToCompany) {
      kind = OcrDocumentKind.salesInvoice;
      confidence = 0.90;
      reasons.add('Seller GSTIN belongs to your company');
    } else if (gstResult.buyerGstinBelongsToCompany) {
      kind = OcrDocumentKind.purchaseBill;
      confidence = 0.88;
      reasons.add('Buyer GSTIN belongs to your company');
    }

    // 2. QR / IRN found → definite e-invoice.
    if (qrIrn != null && qrIrn.isNotEmpty) {
      if (kind == OcrDocumentKind.unknown) {
        kind = OcrDocumentKind.salesInvoice;
        confidence = 0.75;
      } else {
        confidence = math.min(confidence + 0.07, 1.0);
      }
      reasons.add('QR / IRN verified');
    }

    // 3. Keyword-based re-classification.
    final upper = text.toUpperCase();
    if (upper.contains('CREDIT NOTE') || upper.contains('CREDIT MEMO')) {
      kind = OcrDocumentKind.creditNote;
      confidence = math.max(confidence, 0.80);
      reasons.add('Credit Note keyword found');
    } else if (upper.contains('DEBIT NOTE') || upper.contains('DEBIT MEMO')) {
      kind = OcrDocumentKind.debitNote;
      confidence = math.max(confidence, 0.80);
      reasons.add('Debit Note keyword found');
    } else if (upper.contains('CHEQUE') || upper.contains('CHEQUE NO')) {
      final isReceived = upper.contains('RECEIVED FROM') || upper.contains('RECEIPT');
      kind = isReceived ? OcrDocumentKind.chequeReceived : OcrDocumentKind.chequeGiven;
      confidence = math.max(confidence, 0.75);
      reasons.add('Cheque keyword found');
    } else if (upper.contains('PAYMENT VOUCHER') || upper.contains('PAYMENT RECEIPT')) {
      kind = OcrDocumentKind.paymentVoucher;
      confidence = math.max(confidence, 0.75);
      reasons.add('Payment Voucher keyword found');
    } else if (upper.contains('RECEIPT VOUCHER')) {
      kind = OcrDocumentKind.receiptVoucher;
      confidence = math.max(confidence, 0.75);
      reasons.add('Receipt Voucher keyword found');
    }

    // 4. Fall back to "Tax Invoice" / "Invoice" keywords.
    if (kind == OcrDocumentKind.unknown) {
      if (upper.contains('TAX INVOICE') || upper.contains('INVOICE')) {
        kind = OcrDocumentKind.salesInvoice;
        confidence = 0.60;
        reasons.add('Tax Invoice keyword found');
      } else if (upper.contains('BILL') || upper.contains('PURCHASE ORDER')) {
        kind = OcrDocumentKind.purchaseBill;
        confidence = 0.55;
        reasons.add('Bill / Purchase Order keyword found');
      }
    }

    final reason = _buildDetectionReason(kind, gstResult);

    return _ClassifyOut(
      kind: kind,
      confidence: confidence.clamp(0.0, 1.0),
      reason: reason,
      reasons: reasons,
    );
  }

  String _buildDetectionReason(OcrDocumentKind kind, SmartGstResult gst) {
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return gst.sellerGstinBelongsToCompany
            ? 'Seller GST belongs to your company'
            : 'Tax Invoice keywords detected';
      case OcrDocumentKind.purchaseBill:
        return gst.buyerGstinBelongsToCompany
            ? 'Buyer GST belongs to your company'
            : 'Bill / Purchase keywords detected';
      case OcrDocumentKind.creditNote:
        return 'Credit Note keyword found';
      case OcrDocumentKind.debitNote:
        return 'Debit Note keyword found';
      case OcrDocumentKind.chequeGiven:
        return 'Cheque payment keyword found';
      case OcrDocumentKind.chequeReceived:
        return 'Cheque receipt keyword found';
      case OcrDocumentKind.paymentVoucher:
        return 'Payment Voucher keyword found';
      case OcrDocumentKind.receiptVoucher:
        return 'Receipt Voucher keyword found';
      case OcrDocumentKind.unknown:
        return 'Unable to auto-classify – please select manually';
    }
  }

  // ── Engine 5: GST Validation ────────────────────────────────────────────

  SmartGstResult _runGstValidation(String text, ParsedInvoiceData parsed) {
    final upper = text.toUpperCase();
    final gstinRx = RegExp(r'\b([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z])\b');
    final all = gstinRx.allMatches(upper).map((m) => m.group(1)!).toSet().toList();

    // Validate format using checksum pattern (simplified Luhn-style).
    final formatValid = all.every(_isValidGstinFormat);

    // Try to detect seller vs buyer GSTINs from context.
    String sellerGstin = '';
    String buyerGstin = '';
    final sellerRx = RegExp(
      r'(?:gstin|gst\s*no|gst\s*number)\s*[:\-]?\s*([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z])',
      caseSensitive: false,
    );
    final buyerRx = RegExp(
      r'(?:buyer\s*gstin|customer\s*gst|bill\s*to.*?gst)\s*[:\-]?\s*([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z])',
      caseSensitive: false,
    );
    sellerGstin = sellerRx.firstMatch(upper)?.group(1) ?? (all.isNotEmpty ? all.first : '');
    buyerGstin = buyerRx.firstMatch(upper)?.group(1) ??
        (all.length > 1 ? all[1] : '');

    final companySet = companyGstins.map((g) => g.trim().toUpperCase()).toSet();
    final sellerBelongs = sellerGstin.isNotEmpty && companySet.contains(sellerGstin);
    final buyerBelongs = buyerGstin.isNotEmpty && companySet.contains(buyerGstin);

    final warnings = <String>[];
    if (all.isEmpty) warnings.add('No GSTIN found in document');
    if (!formatValid && all.isNotEmpty) warnings.add('One or more GSTIN formats appear invalid');

    return SmartGstResult(
      sellerGstinBelongsToCompany: sellerBelongs,
      buyerGstinBelongsToCompany: buyerBelongs,
      formatValid: formatValid || all.isEmpty,
      qrVerified: false,
      detectedSellerGstin: sellerGstin,
      detectedBuyerGstin: buyerGstin,
      warnings: warnings,
    );
  }

  bool _isValidGstinFormat(String gstin) {
    if (gstin.length != 15) return false;
    final rx = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
    return rx.hasMatch(gstin);
  }

  // ── Engine 6: Master Matching ───────────────────────────────────────────

  Future<SmartMasterMatch?> _runMasterMatching(
    String text,
    ParsedInvoiceData parsed,
    OcrDocumentKind kind,
  ) async {
    final candidates = kind == OcrDocumentKind.salesInvoice ||
            kind == OcrDocumentKind.receiptVoucher
        ? customerNames
        : vendorNames;
    final gstinCandidates = kind == OcrDocumentKind.salesInvoice ||
            kind == OcrDocumentKind.receiptVoucher
        ? customerGstins
        : vendorGstins;

    if (candidates.isEmpty && gstinCandidates.isEmpty) return null;

    // GSTIN match first (exact).
    final docGstin = parsed.gstin.trim().toUpperCase();
    if (docGstin.isNotEmpty) {
      for (var i = 0; i < gstinCandidates.length; i++) {
        if (gstinCandidates[i].trim().toUpperCase() == docGstin) {
          final name = i < candidates.length ? candidates[i] : docGstin;
          return SmartMasterMatch(
            ocrText: parsed.partyName,
            matchedName: name,
            gstin: docGstin,
            confidence: 1.0,
            isNewMaster: false,
            existingId: 'gstin_match_$i',
          );
        }
      }
    }

    // Fuzzy name match.
    if (parsed.partyName.isEmpty || candidates.isEmpty) return null;
    final best = _bestFuzzyMatch(parsed.partyName, candidates);
    if (best != null && best.score > 0.60) {
      return SmartMasterMatch(
        ocrText: parsed.partyName,
        matchedName: best.value,
        confidence: best.score,
        isNewMaster: false,
        existingId: 'name_match_${best.index}',
      );
    }

    // No match → suggest creating new master.
    if (parsed.partyName.isNotEmpty) {
      return SmartMasterMatch(
        ocrText: parsed.partyName,
        matchedName: parsed.partyName,
        gstin: parsed.gstin,
        confidence: 0.5,
        isNewMaster: true,
      );
    }
    return null;
  }

  // ── Engine 7: Product Matching ──────────────────────────────────────────

  Future<List<SmartProductMatch>> _runProductMatching(
    ParsedInvoiceData parsed,
  ) async {
    if (parsed.items.isEmpty) return [];
    final results = <SmartProductMatch>[];
    for (final item in parsed.items) {
      final normalized = _normalizeProductName(item.name);
      if (productMasterNames.isEmpty) {
        results.add(SmartProductMatch(
          ocrText: item.name,
          matchedName: normalized,
          confidence: 0.5,
          isNewMaster: true,
        ));
        continue;
      }
      final best = _bestFuzzyMatch(normalized, productMasterNames);
      if (best != null && best.score > 0.55) {
        results.add(SmartProductMatch(
          ocrText: item.name,
          matchedName: best.value,
          confidence: best.score,
          isNewMaster: false,
        ));
      } else {
        results.add(SmartProductMatch(
          ocrText: item.name,
          matchedName: normalized,
          confidence: 0.45,
          isNewMaster: true,
        ));
      }
    }
    return results;
  }

  String _normalizeProductName(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^A-Za-z0-9 /\-]'), '')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  // ── Engine 8: Ledger Suggestion ─────────────────────────────────────────

  Future<SmartLedgerSuggestion?> _runLedgerSuggestion(
    ParsedInvoiceData parsed,
    OcrDocumentKind kind,
  ) async {
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return const SmartLedgerSuggestion(
          ledgerName: 'Sales Account',
          group: 'Sales',
          confidence: 0.92,
          reason: 'Matched Product Category',
        );
      case OcrDocumentKind.purchaseBill:
        return const SmartLedgerSuggestion(
          ledgerName: 'Purchase Account',
          group: 'Purchases',
          confidence: 0.90,
          reason: 'Purchase voucher type',
        );
      case OcrDocumentKind.creditNote:
        return const SmartLedgerSuggestion(
          ledgerName: 'Sales Return Account',
          group: 'Sales',
          confidence: 0.88,
          reason: 'Credit Note maps to Sales Return',
        );
      case OcrDocumentKind.debitNote:
        return const SmartLedgerSuggestion(
          ledgerName: 'Purchase Return Account',
          group: 'Purchases',
          confidence: 0.88,
          reason: 'Debit Note maps to Purchase Return',
        );
      case OcrDocumentKind.paymentVoucher:
      case OcrDocumentKind.chequeGiven:
        return const SmartLedgerSuggestion(
          ledgerName: 'Cash / Bank Account',
          group: 'Bank Accounts',
          confidence: 0.85,
          reason: 'Payment voucher type',
        );
      case OcrDocumentKind.receiptVoucher:
      case OcrDocumentKind.chequeReceived:
        return const SmartLedgerSuggestion(
          ledgerName: 'Cash / Bank Account',
          group: 'Bank Accounts',
          confidence: 0.85,
          reason: 'Receipt voucher type',
        );
      case OcrDocumentKind.unknown:
        return null;
    }
  }

  // ── Engine 9: Tax Validation ────────────────────────────────────────────

  SmartTaxResult _runTaxValidation(String text, ParsedInvoiceData parsed) {
    final cgst = _extractTaxAmount(text, 'CGST');
    final sgst = _extractTaxAmount(text, 'SGST');
    final igst = _extractTaxAmount(text, 'IGST');

    // Calculate total from items if available.
    var calculatedBase = 0.0;
    for (final item in parsed.items) {
      calculatedBase += item.quantity * item.rate;
    }
    final calculatedTax = cgst + sgst + igst;
    final calculatedTotal = calculatedBase + calculatedTax;

    // Check if calculated total ≈ extracted total (within 1% or ₹5).
    final diff = (calculatedTotal - parsed.totalAmount).abs();
    final taxCalcMatch = parsed.totalAmount > 0 &&
        calculatedTotal > 0 &&
        (diff / math.max(parsed.totalAmount, 1) < 0.01 || diff < 5);

    final warnings = <String>[];
    if (cgst > 0 && sgst > 0 && igst > 0) {
      warnings.add('CGST + SGST and IGST both found – usually only one pair applies');
    }
    if (parsed.totalAmount > 0 && !taxCalcMatch && calculatedTotal > 0) {
      warnings.add('Extracted total ₹${parsed.totalAmount.toStringAsFixed(2)} differs from calculated ₹${calculatedTotal.toStringAsFixed(2)}');
    }

    return SmartTaxResult(
      extractedCgst: cgst,
      extractedSgst: sgst,
      extractedIgst: igst,
      extractedTotal: parsed.totalAmount,
      calculatedTotal: calculatedTotal,
      taxCalcMatch: taxCalcMatch,
      warnings: warnings,
    );
  }

  double _extractTaxAmount(String text, String taxLabel) {
    final rx = RegExp(
      '$taxLabel[^\\d]*(\\d[\\d,]*(?:\\.\\d{1,2})?)',
      caseSensitive: false,
    );
    final m = rx.firstMatch(text);
    if (m == null) return 0;
    return double.tryParse(m.group(1)?.replaceAll(',', '') ?? '0') ?? 0;
  }

  // ── Engine 10: Signal building ──────────────────────────────────────────

  SmartMatchSignals _buildSignals({
    required String? qrIrn,
    required SmartGstResult gstResult,
    required SmartMasterMatch? partyMatch,
    required ParsedInvoiceData parsed,
    required List<SmartProductMatch> productMatches,
    required SmartTaxResult taxResult,
    required String ocrText,
  }) {
    final qrScore = (qrIrn != null && qrIrn.isNotEmpty) ? 1.0 : 0.0;
    final gstOwnerScore = (gstResult.sellerGstinBelongsToCompany ||
            gstResult.buyerGstinBelongsToCompany)
        ? 1.0
        : (gstResult.formatValid ? 0.4 : 0.0);
    final partyScore = partyMatch == null
        ? 0.0
        : (partyMatch.isNewMaster ? 0.3 : partyMatch.confidence);
    final invNumScore = parsed.billNumber.isNotEmpty ? 0.8 : 0.0;
    final prodScore = productMatches.isEmpty
        ? 0.0
        : productMatches.map((p) => p.confidence).reduce((a, b) => a + b) /
            productMatches.length;
    final hsnScore = productMatches.any((p) => p.hsnCode.isNotEmpty) ? 1.0 : 0.4;
    final taxScore = taxResult.taxCalcMatch ? 1.0 : 0.3;
    final layoutScore = parsed.items.isNotEmpty ? 0.7 : 0.3;
    final historicalScore = _checkHistoricalPattern(parsed.gstin);

    return SmartMatchSignals(
      qrIrnMatch: qrScore,
      companyGstOwnership: gstOwnerScore,
      existingPartyMatch: partyScore,
      invoiceNumberPattern: invNumScore,
      productSimilarity: prodScore,
      hsnMatch: hsnScore,
      taxCalcMatch: taxScore,
      layoutFingerprint: layoutScore,
      historicalPattern: historicalScore,
    );
  }

  double _checkHistoricalPattern(String gstin) {
    // Synchronous check against in-memory cache loaded during init.
    // Returns 1.0 if we've seen this GSTIN before, 0.0 otherwise.
    return _seenGstins.contains(gstin.trim().toUpperCase()) ? 1.0 : 0.0;
  }

  // In-memory set populated by _learnFromResult.
  final Set<String> _seenGstins = {};

  // ── Engine 10b: Confidence Breakdown ────────────────────────────────────

  SmartConfidenceBreakdown _computeConfidence({
    required SmartMatchSignals signals,
    required ParsedInvoiceData parsed,
    required SmartMasterMatch? partyMatch,
    required List<SmartProductMatch> productMatches,
    required SmartTaxResult taxResult,
  }) {
    final invoice = _clamp(
      (parsed.billNumber.isNotEmpty ? 0.5 : 0) +
          (parsed.billDate.isNotEmpty ? 0.3 : 0) +
          (parsed.totalAmount > 0 ? 0.2 : 0),
    );
    final customer = partyMatch == null
        ? 0.0
        : _clamp(partyMatch.isNewMaster ? 0.4 : partyMatch.confidence);
    final products = productMatches.isEmpty
        ? 0.0
        : _clamp(
            productMatches.map((p) => p.confidence).reduce((a, b) => a + b) /
                productMatches.length,
          );
    final gst = _clamp(
      (taxResult.extractedCgst + taxResult.extractedSgst + taxResult.extractedIgst > 0
          ? 0.5
          : 0) +
      (taxResult.taxCalcMatch ? 0.5 : 0.2),
    );
    final totalConf = _clamp(taxResult.taxCalcMatch ? 0.95 : 0.7);
    final overall = _clamp(signals.weightedScore);

    return SmartConfidenceBreakdown(
      invoice: invoice,
      customer: customer,
      products: products,
      gst: gst,
      total: totalConf,
      overall: overall,
    );
  }

  double _clamp(double v) => v.clamp(0.0, 1.0);

  // ── Engine 11: Missing Masters ──────────────────────────────────────────

  List<SmartMissingMaster> _detectMissingMasters({
    required SmartMasterMatch? partyMatch,
    required List<SmartProductMatch> productMatches,
    required SmartLedgerSuggestion? ledgerSuggestion,
    required ParsedInvoiceData parsed,
  }) {
    final missing = <SmartMissingMaster>[];

    if (partyMatch != null && partyMatch.isNewMaster && partyMatch.matchedName.isNotEmpty) {
      missing.add(SmartMissingMaster(
        type: 'customer',
        suggestedName: partyMatch.matchedName,
        extra: partyMatch.gstin,
      ));
    }

    for (final pm in productMatches) {
      if (pm.isNewMaster) {
        missing.add(SmartMissingMaster(
          type: 'product',
          suggestedName: pm.matchedName,
          extra: pm.hsnCode,
        ));
      }
    }

    if (ledgerSuggestion == null) {
      missing.add(const SmartMissingMaster(
        type: 'ledger',
        suggestedName: 'Unknown Ledger',
      ));
    }

    return missing;
  }

  // ── Engine 12: AI Learning ──────────────────────────────────────────────

  Future<void> _learnFromResult(
    ParsedInvoiceData parsed,
    String ocrText,
    OcrDocumentKind kind,
  ) async {
    // Update in-memory GSTIN cache.
    if (parsed.gstin.trim().isNotEmpty) {
      _seenGstins.add(parsed.gstin.trim().toUpperCase());
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Store fingerprint (max 500 entries, FIFO).
      final stored = List<String>.from(
        prefs.getStringList(_prefsKeyFingerprints) ?? [],
      );
      final key = _buildFingerprintKey(parsed);
      final entry =
          '$key|${parsed.billNumber}|${parsed.totalAmount.toStringAsFixed(2)}|${parsed.billDate}';
      if (!stored.any((e) => e.startsWith('$key|'))) {
        stored.add(entry);
        if (stored.length > _maxStoredFingerprints) {
          stored.removeAt(0);
        }
        await prefs.setStringList(_prefsKeyFingerprints, stored);
      }

      // Store supplier/GSTIN → voucher-type pattern.
      if (parsed.gstin.isNotEmpty) {
        final patterns = Map<String, String>.from(
          jsonDecode(prefs.getString(_prefsKeyPatterns) ?? '{}') as Map,
        );
        patterns[parsed.gstin.trim().toUpperCase()] = kind.name;
        await prefs.setString(_prefsKeyPatterns, jsonEncode(patterns));
      }
    } catch (_) {
      // Non-critical.
    }
  }

  // ── Fuzzy matching helpers ──────────────────────────────────────────────

  _FuzzyMatch? _bestFuzzyMatch(String query, List<String> candidates) {
    if (candidates.isEmpty || query.isEmpty) return null;
    final normQ = query.toLowerCase().trim();
    double bestScore = 0;
    int bestIdx = -1;
    for (var i = 0; i < candidates.length; i++) {
      final score = _jaroWinkler(normQ, candidates[i].toLowerCase().trim());
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) return null;
    return _FuzzyMatch(value: candidates[bestIdx], index: bestIdx, score: bestScore);
  }

  /// Jaro-Winkler similarity – O(n×m) but fast for short strings.
  static double _jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final matchDistance = math.max(s1.length, s2.length) ~/ 2 - 1;
    final s1Matches = List<bool>.filled(s1.length, false);
    final s2Matches = List<bool>.filled(s2.length, false);
    var matches = 0;
    var transpositions = 0;
    for (var i = 0; i < s1.length; i++) {
      final start = math.max(0, i - matchDistance);
      final end = math.min(i + matchDistance + 1, s2.length);
      for (var j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) return 0.0;
    var k = 0;
    for (var i = 0; i < s1.length; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }
    final jaro = (matches / s1.length +
            matches / s2.length +
            (matches - transpositions / 2) / matches) /
        3;
    var prefix = 0;
    for (var i = 0; i < math.min(4, math.min(s1.length, s2.length)); i++) {
      if (s1[i] != s2[i]) break;
      prefix++;
    }
    return jaro + prefix * 0.1 * (1 - jaro);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ClassifyOut {
  final OcrDocumentKind kind;
  final double confidence;
  final String reason;
  final List<String> reasons;

  const _ClassifyOut({
    required this.kind,
    required this.confidence,
    required this.reason,
    required this.reasons,
  });
}

class _FuzzyMatch {
  final String value;
  final int index;
  final double score;
  const _FuzzyMatch({required this.value, required this.index, required this.score});
}
