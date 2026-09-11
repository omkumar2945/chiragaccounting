import 'dart:typed_data';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/smart_invoice_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkbenchJobStatus – lifecycle of a document in the AI Workbench
// ─────────────────────────────────────────────────────────────────────────────

enum WorkbenchJobStatus {
  inbox, // Queued – waiting to be processed
  processing, // Running through the 12-engine pipeline
  verification, // Pipeline done – awaiting user review
  approved, // User approved – pending final save
  completed, // Saved / posted to accounting
  error, // Pipeline or save failed
  archive, // Archived (done / dismissed)
}

extension WorkbenchJobStatusLabel on WorkbenchJobStatus {
  String get label {
    switch (this) {
      case WorkbenchJobStatus.inbox:
        return 'Inbox';
      case WorkbenchJobStatus.processing:
        return 'Processing';
      case WorkbenchJobStatus.verification:
        return 'Verification';
      case WorkbenchJobStatus.approved:
        return 'Approved';
      case WorkbenchJobStatus.completed:
        return 'Completed';
      case WorkbenchJobStatus.error:
        return 'Error';
      case WorkbenchJobStatus.archive:
        return 'Archive';
    }
  }

  bool get isActive =>
      this == WorkbenchJobStatus.inbox ||
      this == WorkbenchJobStatus.processing ||
      this == WorkbenchJobStatus.verification ||
      this == WorkbenchJobStatus.approved;
}

// ─────────────────────────────────────────────────────────────────────────────
// WorkbenchCorrection – logged when user corrects an AI field
// ─────────────────────────────────────────────────────────────────────────────

class WorkbenchCorrection {
  final String fieldName;
  final String original;
  final String corrected;
  final DateTime correctedAt;

  const WorkbenchCorrection({
    required this.fieldName,
    required this.original,
    required this.corrected,
    required this.correctedAt,
  });
}

class WorkbenchTimelineEvent {
  final String title;
  final DateTime at;
  final String detail;

  const WorkbenchTimelineEvent({
    required this.title,
    required this.at,
    this.detail = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// WorkbenchJob – single document moving through the AI Workbench pipeline
// ─────────────────────────────────────────────────────────────────────────────

class WorkbenchJob {
  final String id;
  final String fileName;
  final String? filePath;
  final Uint8List? fileBytes;
  final WorkbenchJobStatus status;
  final SmartInvoiceResult? result;
  final DateTime uploadedAt;
  final String? errorMessage;
  final List<WorkbenchCorrection> corrections;
  final String? batchId; // groups jobs from the same batch upload
  final String? reviewReason; // why this job needs review (human-readable)
  final ClientDocumentQueueBucket queueBucket;
  final String? clientId;
  final String? assignedAccountantId;
  final String? remoteDocumentId;
  final ClientDocumentIntakeChannel intakeChannel;
  final String? sourceIdentity;
  final String? externalReference;
  final List<WorkbenchTimelineEvent> timeline;

  // Live pipeline progress
  final SmartInvoiceStage currentStage;
  final List<SmartInvoiceStage> completedStages;

  const WorkbenchJob({
    required this.id,
    required this.fileName,
    this.filePath,
    this.fileBytes,
    required this.status,
    this.result,
    required this.uploadedAt,
    this.errorMessage,
    this.corrections = const [],
    this.batchId,
    this.reviewReason,
    this.queueBucket = ClientDocumentQueueBucket.review,
    this.clientId,
    this.assignedAccountantId,
    this.remoteDocumentId,
    this.intakeChannel = ClientDocumentIntakeChannel.mobileApp,
    this.sourceIdentity,
    this.externalReference,
    this.timeline = const [],
    this.currentStage = SmartInvoiceStage.idle,
    this.completedStages = const [],
  });

  WorkbenchJob copyWith({
    WorkbenchJobStatus? status,
    SmartInvoiceResult? result,
    String? errorMessage,
    List<WorkbenchCorrection>? corrections,
    String? reviewReason,
    ClientDocumentQueueBucket? queueBucket,
    String? clientId,
    String? assignedAccountantId,
    String? remoteDocumentId,
    ClientDocumentIntakeChannel? intakeChannel,
    String? sourceIdentity,
    String? externalReference,
    List<WorkbenchTimelineEvent>? timeline,
    SmartInvoiceStage? currentStage,
    List<SmartInvoiceStage>? completedStages,
  }) {
    return WorkbenchJob(
      id: id,
      fileName: fileName,
      filePath: filePath,
      fileBytes: fileBytes,
      status: status ?? this.status,
      result: result ?? this.result,
      uploadedAt: uploadedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      corrections: corrections ?? this.corrections,
      batchId: batchId,
      reviewReason: reviewReason ?? this.reviewReason,
      queueBucket: queueBucket ?? this.queueBucket,
      clientId: clientId ?? this.clientId,
      assignedAccountantId: assignedAccountantId ?? this.assignedAccountantId,
      remoteDocumentId: remoteDocumentId ?? this.remoteDocumentId,
      intakeChannel: intakeChannel ?? this.intakeChannel,
      sourceIdentity: sourceIdentity ?? this.sourceIdentity,
      externalReference: externalReference ?? this.externalReference,
      timeline: timeline ?? this.timeline,
      currentStage: currentStage ?? this.currentStage,
      completedStages: completedStages ?? this.completedStages,
    );
  }

  String get shortName {
    if (fileName.length <= 28) return fileName;
    final ext = fileName.contains('.') ? fileName.split('.').last : '';
    return '${fileName.substring(0, 22)}...${ext.isNotEmpty ? '.$ext' : ''}';
  }

  String get documentTypeLabel {
    if (result == null) return 'Unknown';
    switch (result!.detectedKind) {
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

  String get queueBucketLabel => queueBucket.displayName;

  String get intakeChannelLabel => intakeChannel.displayName;

  bool get isPosted => status == WorkbenchJobStatus.completed;

  bool canClientMutate(String actorClientId) =>
      clientId == actorClientId && !isPosted;
}
