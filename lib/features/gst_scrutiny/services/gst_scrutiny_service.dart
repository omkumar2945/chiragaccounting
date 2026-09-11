import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/features/gst_library/services/gst_library_service.dart';

enum GstScrutinyCaseStatus { draft, inReview, submitted, closed }

enum GstScrutinyReplyStatus { draft, reviewed }

enum GstScrutinyReportStatus { pending, ready }

class GstScrutinyEnquiry {
  const GstScrutinyEnquiry({required this.query, this.response = ''});

  final String query;
  final String response;

  GstScrutinyEnquiry copyWith({String? response}) {
    return GstScrutinyEnquiry(
      query: query,
      response: response ?? this.response,
    );
  }
}

class GstScrutinyReport {
  const GstScrutinyReport({
    required this.id,
    required this.title,
    required this.status,
    this.sourceNote = '',
  });

  final String id;
  final String title;
  final GstScrutinyReportStatus status;
  final String sourceNote;
}

class GstScrutinyReply {
  const GstScrutinyReply({
    required this.body,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String body;
  final GstScrutinyReplyStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  GstScrutinyReply copyWith({
    String? body,
    GstScrutinyReplyStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return GstScrutinyReply(
      body: body ?? this.body,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}

class GstScrutinyCase {
  const GstScrutinyCase({
    required this.id,
    required this.clientId,
    required this.noticeNumber,
    required this.noticeDate,
    required this.section,
    required this.taxPeriod,
    required this.dueDate,
    required this.officerEmail,
    required this.status,
    required this.enquiries,
    required this.reports,
    required this.reply,
    required this.legalReferenceIds,
    required this.availablePortalSources,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String noticeNumber;
  final DateTime noticeDate;
  final String section;
  final String taxPeriod;
  final DateTime dueDate;
  final String officerEmail;
  final GstScrutinyCaseStatus status;
  final List<GstScrutinyEnquiry> enquiries;
  final List<GstScrutinyReport> reports;
  final GstScrutinyReply reply;
  final List<String> legalReferenceIds;
  final Set<String> availablePortalSources;
  final String createdBy;
  final DateTime createdAt;

  bool get hasMissingSourceData => reports.any((report) => report.status == GstScrutinyReportStatus.pending);

  GstScrutinyCase copyWith({
    GstScrutinyCaseStatus? status,
    List<GstScrutinyEnquiry>? enquiries,
    List<GstScrutinyReport>? reports,
    GstScrutinyReply? reply,
  }) {
    return GstScrutinyCase(
      id: id,
      clientId: clientId,
      noticeNumber: noticeNumber,
      noticeDate: noticeDate,
      section: section,
      taxPeriod: taxPeriod,
      dueDate: dueDate,
      officerEmail: officerEmail,
      status: status ?? this.status,
      enquiries: enquiries ?? this.enquiries,
      reports: reports ?? this.reports,
      reply: reply ?? this.reply,
      legalReferenceIds: legalReferenceIds,
      availablePortalSources: availablePortalSources,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

class GstScrutinyService extends ChangeNotifier {
  final Map<String, List<GstScrutinyCase>> _casesByClient = <String, List<GstScrutinyCase>>{};

  List<GstScrutinyCase> casesFor(String clientId) {
    return List<GstScrutinyCase>.unmodifiable(_casesByClient[clientId] ?? const <GstScrutinyCase>[]);
  }

  Future<void> createCase({
    required String clientId,
    required String noticeNumber,
    required DateTime noticeDate,
    required String section,
    required String taxPeriod,
    required DateTime dueDate,
    required String officerEmail,
    required String createdBy,
    required List<String> enquiryTexts,
    required Set<String> availablePortalSources,
    required List<String> legalReferenceIds,
    String clientName = '',
    String clientGstin = '',
  }) async {
    final cleanedEnquiries = enquiryTexts
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .map((text) => GstScrutinyEnquiry(query: text))
        .toList(growable: false);

    final reports = <GstScrutinyReport>[
      GstScrutinyReport(
        id: 'tax-liability',
        title: 'Tax Liability Reconciliation',
        status: availablePortalSources.contains('tax-liability')
            ? GstScrutinyReportStatus.ready
            : GstScrutinyReportStatus.pending,
        sourceNote: availablePortalSources.contains('tax-liability')
            ? 'Based on available 3B dataset.'
            : 'Portal source missing. Upload 3B extract.',
      ),
      GstScrutinyReport(
        id: 'itc-register',
        title: 'ITC Register vs 2B Matching',
        status: availablePortalSources.contains('itc-register')
            ? GstScrutinyReportStatus.ready
            : GstScrutinyReportStatus.pending,
        sourceNote: availablePortalSources.contains('itc-register')
            ? 'Based on available 2B dataset.'
            : 'Portal source missing. Upload 2B data.',
      ),
      GstScrutinyReport(
        id: 'voucher-pack',
        title: 'Voucher Soft-Copy Pack',
        status: GstScrutinyReportStatus.ready,
        sourceNote: 'Generated from current sales/purchase vouchers.',
      ),
    ];

    final draftReply = _buildDraftReply(
      section: section,
      taxPeriod: taxPeriod,
      enquiries: cleanedEnquiries,
      reports: reports,
      legalReferenceIds: legalReferenceIds,
      clientName: clientName,
      clientGstin: clientGstin,
    );

    final caseItem = GstScrutinyCase(
      id: 'gst_case_${DateTime.now().millisecondsSinceEpoch}',
      clientId: clientId,
      noticeNumber: noticeNumber.trim(),
      noticeDate: noticeDate,
      section: section.trim(),
      taxPeriod: taxPeriod.trim(),
      dueDate: dueDate,
      officerEmail: officerEmail.trim(),
      status: GstScrutinyCaseStatus.inReview,
      enquiries: cleanedEnquiries,
      reports: reports,
      reply: GstScrutinyReply(body: draftReply, status: GstScrutinyReplyStatus.draft),
      legalReferenceIds: List<String>.from(legalReferenceIds),
      availablePortalSources: Set<String>.from(availablePortalSources),
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    final list = _casesByClient.putIfAbsent(clientId, () => <GstScrutinyCase>[]);
    list.add(caseItem);
    notifyListeners();
  }

  Future<void> reviewReply({
    required String caseId,
    required String reviewedBody,
    required String reviewedBy,
  }) async {
    for (final entry in _casesByClient.entries) {
      final index = entry.value.indexWhere((element) => element.id == caseId);
      if (index < 0) continue;
      final existing = entry.value[index];
      entry.value[index] = existing.copyWith(
        status: GstScrutinyCaseStatus.submitted,
        reply: existing.reply.copyWith(
          body: reviewedBody.trim(),
          status: GstScrutinyReplyStatus.reviewed,
          reviewedBy: reviewedBy,
          reviewedAt: DateTime.now(),
        ),
      );
      notifyListeners();
      return;
    }
  }

  String _buildDraftReply({
    required String section,
    required String taxPeriod,
    required List<GstScrutinyEnquiry> enquiries,
    required List<GstScrutinyReport> reports,
    required List<String> legalReferenceIds,
    required String clientName,
    required String clientGstin,
  }) {
    final library = GstLibraryService();
    final selectedReferences = legalReferenceIds
      .map(library.sectionById)
      .whereType<GstLibrarySection>()
      .toList(growable: false);
    final referenceLabels = legalReferenceIds
        .map((id) => library.sectionById(id)?.displayName ?? id)
        .toList(growable: false);
    final judgementHints = library.judgements
      .take(3)
      .map(
        (judgement) =>
          '${judgement.title} (${judgement.outcome}; ${judgement.orderReference})',
      )
      .join('; ');

    final buffer = StringBuffer()
      ..writeln('Subject: Reply to GST Notice under $section')
      ..writeln()
      ..writeln('Tax Period: $taxPeriod')
      ..writeln()
      ..writeln('Respected Officer,')
      ..writeln('Please find our point-wise response below for ${clientName.isEmpty ? 'the taxpayer' : clientName}${clientGstin.isEmpty ? '' : ' (GSTIN: $clientGstin)'}.')
      ..writeln()
      ..writeln('We submit that the reply is prepared from available client records, books of account, filed returns and the supporting source documents already uploaded for review. Prepared from available client records.')
      ..writeln();

    for (var i = 0; i < enquiries.length; i++) {
      buffer
        ..writeln('${i + 1}. Query: ${enquiries[i].query}')
        ..writeln('   Response: The matter has been examined with reference to the relevant books, returns and portal data. The explanation and supporting evidence are attached for your consideration.')
        ..writeln();
    }

    buffer
      ..writeln('Relevant legal framework:')
      ..writeln('- ${referenceLabels.isEmpty ? 'Applicable GST provisions as per the notice and available records' : referenceLabels.join('; ')}')
      ..writeln('- Judgement references: $judgementHints')
      ..writeln();

    buffer.writeln('Selected GST Library references applied in this draft:');
    if (selectedReferences.isEmpty) {
      buffer.writeln('- No explicit library reference was selected. General GST framework applied as per notice context.');
    } else {
      for (final sectionRef in selectedReferences) {
        buffer.writeln('- ${sectionRef.displayName}: ${sectionRef.summary}');
        if (sectionRef.highlights.isNotEmpty) {
          buffer.writeln('  Key support: ${sectionRef.highlights.first}');
        }
      }
    }
    buffer.writeln();

    buffer.writeln('Supporting reports attached:');
    for (final report in reports) {
      buffer.writeln('- ${report.title}: ${report.sourceNote}');
    }

    buffer
      ..writeln()
      ..writeln('We respectfully submit that the above response is made in good faith and is supported by the available records. Kindly consider the attached evidence and confirm if any additional document is required for complete adjudication.')
      ..writeln()
      ..writeln('Regards,')
      ..writeln('Authorized Representative');

    return buffer.toString();
  }
}
