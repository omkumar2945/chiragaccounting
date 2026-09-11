import 'dart:typed_data';

import 'package:chirag_accounting/features/gst_library/services/gst_library_service.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';

class GstNoticeAnalysis {
  const GstNoticeAnalysis({
    required this.fileName,
    required this.extractedText,
    required this.formNumber,
    required this.noticeNumber,
    required this.gstin,
    required this.taxPeriod,
    required this.dueDateText,
    required this.amountMentions,
    required this.riskFlags,
    required this.guidance,
    required this.draftReply,
  });

  final String fileName;
  final String extractedText;
  final String formNumber;
  final String noticeNumber;
  final String gstin;
  final String taxPeriod;
  final String dueDateText;
  final List<String> amountMentions;
  final List<String> riskFlags;
  final GstGuidanceSearchResult guidance;
  final String draftReply;
}

class GstNoticeAnalysisService {
  GstNoticeAnalysisService({InvoiceOcrService? ocrService})
    : _ocrService = ocrService ?? InvoiceOcrService();

  static const int maxFileBytes = 15 * 1024 * 1024;
  static const Set<String> supportedExtensions = <String>{
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'webp',
  };

  final InvoiceOcrService _ocrService;

  Future<String> extractText({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('The selected notice is empty.');
    if (bytes.length > maxFileBytes) {
      throw ArgumentError('GST notice must be 15 MB or smaller.');
    }
    final extension = fileName.split('.').last.toLowerCase();
    if (!supportedExtensions.contains(extension)) {
      throw ArgumentError('Upload a PDF, PNG, JPG, JPEG or WEBP notice.');
    }
    final text = extension == 'pdf'
        ? await _ocrService.extractTextFromPdfBytes(
            bytes,
            maxPagesToScan: 12,
            rasterDpi: 220,
          )
        : await _ocrService.extractTextFromImageBytes(
            bytes,
            fileName: fileName,
          );
    if (text.trim().length < 20) {
      throw const FormatException(
        'The notice text could not be read reliably. Upload a clearer scan or searchable PDF.',
      );
    }
    return text.trim();
  }

  GstNoticeAnalysis analyzeText({
    required String fileName,
    required String extractedText,
    required GstLibraryService library,
    String clientName = '',
    String expectedGstin = '',
  }) {
    final normalizedText = extractedText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .join('\n')
        .trim();
    final cleanText = normalizedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.length < 20) {
      throw const FormatException('Notice text is too short for analysis.');
    }
    final formNumber = _firstMatch(
      cleanText,
      RegExp(
        r'\b(?:ASMT|DRC|REG|GSTR|RFD|ADT|MOV)-?\s?\d{1,2}[A-Z]?\b',
        caseSensitive: false,
      ),
    ).toUpperCase().replaceAll(RegExp(r'\s+'), '-');
    final noticeNumber = _labeledToken(normalizedText, <String>[
      'reference number',
      'reference no',
      'notice number',
      'notice no',
    ]);
    final gstin = _firstMatch(
      cleanText.toUpperCase(),
      RegExp(r'\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]\b'),
    );
    final taxPeriod = _firstMatch(
      cleanText,
      RegExp(
        r'\b(?:FY\s*)?20\d{2}\s*[-/]\s*\d{2,4}\b|\b(?:Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|Jan|Feb|Mar)[a-z]*\s+20\d{2}\b',
        caseSensitive: false,
      ),
    );
    final dueDateText = _labeledDate(normalizedText, <String>[
      'reply by',
      'reply due date',
      'date by which reply',
      'due date',
      'appear on',
    ]);
    final amountMentions =
        RegExp(
              r'(?:Rs\.?|INR|₹)\s*[0-9][0-9,]*(?:\.\d{1,2})?',
              caseSensitive: false,
            )
            .allMatches(cleanText)
            .map((match) => match.group(0)!)
            .toSet()
            .take(10)
            .toList();
    final searchText = '$formNumber $cleanText';
    final guidance = library.searchGuidance(searchText).first;
    final riskFlags = _riskFlags(
      cleanText,
      dueDateText,
      amountMentions,
      detectedGstin: gstin,
      expectedGstin: expectedGstin,
    );
    return GstNoticeAnalysis(
      fileName: fileName,
      extractedText: extractedText.trim(),
      formNumber: formNumber,
      noticeNumber: noticeNumber,
      gstin: gstin,
      taxPeriod: taxPeriod,
      dueDateText: dueDateText,
      amountMentions: amountMentions,
      riskFlags: riskFlags,
      guidance: guidance,
      draftReply: _draftReply(
        clientName: clientName,
        formNumber: formNumber,
        noticeNumber: noticeNumber,
        gstin: gstin,
        taxPeriod: taxPeriod,
        dueDateText: dueDateText,
        guide: guidance.guide,
      ),
    );
  }

  static List<String> _riskFlags(
    String text,
    String dueDate,
    List<String> amounts, {
    required String detectedGstin,
    required String expectedGstin,
  }) {
    final lower = text.toLowerCase();
    final flags = <String>[];
    if (dueDate.isEmpty) {
      flags.add('Reply deadline was not confidently detected.');
    }
    if (amounts.isNotEmpty) {
      flags.add('Monetary demand or amount detected; reconcile every figure.');
    }
    final normalizedExpected = expectedGstin.trim().toUpperCase();
    if (normalizedExpected.isNotEmpty &&
        detectedGstin.isNotEmpty &&
        normalizedExpected != detectedGstin.toUpperCase()) {
      flags.add(
        'Notice GSTIN $detectedGstin does not match selected client GSTIN $normalizedExpected.',
      );
    }
    if (lower.contains('fraud') ||
        lower.contains('suppression') ||
        lower.contains('wilful misstatement')) {
      flags.add('Fraud or suppression language detected; obtain legal review.');
    }
    if (lower.contains('personal hearing') || lower.contains('appear before')) {
      flags.add('Personal appearance or hearing requirement detected.');
    }
    if (lower.contains('cancellation') || lower.contains('suspension')) {
      flags.add('Registration cancellation or suspension risk detected.');
    }
    if (lower.contains('penalty') || lower.contains('interest')) {
      flags.add('Interest or penalty exposure detected.');
    }
    return flags;
  }

  static String _draftReply({
    required String clientName,
    required String formNumber,
    required String noticeNumber,
    required String gstin,
    required String taxPeriod,
    required String dueDateText,
    required GstProblemGuide guide,
  }) => <String>[
    'DRAFT FOR FACTUAL AND PROFESSIONAL REVIEW - DO NOT FILE AS-IS',
    '',
    'To,',
    'The Proper Officer,',
    '[Jurisdiction / Office]',
    '',
    'Subject: Reply to ${formNumber.isEmpty ? 'GST notice' : formNumber}${noticeNumber.isEmpty ? '' : ' bearing reference $noticeNumber'}${taxPeriod.isEmpty ? '' : ' for $taxPeriod'}',
    '',
    'Taxpayer: ${clientName.trim().isEmpty ? '[Verify legal name]' : clientName.trim()}',
    'GSTIN: ${gstin.isEmpty ? '[Verify GSTIN]' : gstin}',
    'Reply due date: ${dueDateText.isEmpty ? '[Verify from complete notice]' : dueDateText}',
    '',
    'Respected Sir/Madam,',
    '',
    'With reference to the notice mentioned above, the taxpayer submits this preliminary point-wise response, subject to verification of the complete notice, books, returns and supporting records.',
    '',
    '1. Notice allegation / discrepancy',
    '[Quote each allegation exactly from the notice.]',
    '',
    '2. Verified facts',
    '[Insert client-approved chronology, transaction facts and return-table details. Do not infer missing facts from OCR.]',
    '',
    '3. Reconciliation and tax position',
    '[Attach and summarize the issue-wise reconciliation. Clearly separate accepted, timing and disputed differences.]',
    '',
    '4. Legal submission',
    'The response should be reviewed with ${guide.sectionIds.isEmpty ? '[applicable GST provisions]' : guide.sectionIds.join(', ')} and the current rules, notifications, circulars and binding decisions.',
    '',
    '5. Supporting documents',
    for (var index = 0; index < guide.requiredDocuments.length; index++)
      'Annexure ${index + 1}: ${guide.requiredDocuments[index]} [attach / mark not applicable]',
    '',
    'Prayer',
    'In view of the verified facts, reconciliations and legal submissions, it is respectfully requested that the discrepancy/proceeding be dropped to the extent explained. The taxpayer requests an opportunity to provide further clarification and a personal hearing before any adverse decision.',
    '',
    'For the taxpayer',
    '[Authorized signatory]',
    '[Name, designation and date]',
    '',
    'Internal escalation: ${guide.escalationGuidance}',
  ].join('\n');

  static String _firstMatch(String text, RegExp pattern) =>
      pattern.firstMatch(text)?.group(0)?.trim() ?? '';

  static String _labeledToken(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '${RegExp.escape(label)}\\s*[:.-]?\\s*([A-Z0-9][A-Z0-9/-]{3,39})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) return match.group(1)?.trim() ?? '';
    }
    return '';
  }

  static String _labeledDate(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '${RegExp.escape(label)}\\s*[:.-]?\\s*(\\d{1,2}\\s+[A-Z]{3,9}\\s+\\d{4}|\\d{1,2}[-/.]\\d{1,2}[-/.]\\d{2,4})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) return match.group(1)?.trim() ?? '';
    }
    return '';
  }

  void dispose() => _ocrService.dispose();
}
