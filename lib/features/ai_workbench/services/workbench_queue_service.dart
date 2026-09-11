import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/services/ocr_module_api_service.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/smart_invoice_engine.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';

class BatchUploadFile {
  final String fileName;
  final String? filePath;
  final Uint8List? fileBytes;
  const BatchUploadFile({
    required this.fileName,
    this.filePath,
    this.fileBytes,
  });
}

class GlobalMissingMaster {
  final String type;
  final String suggestedName;
  final String extra;
  final List<String> jobIds;
  bool resolved;
  String? resolvedName;
  GlobalMissingMaster({
    required this.type,
    required this.suggestedName,
    this.extra = '',
    required this.jobIds,
    this.resolved = false,
    this.resolvedName,
  });
  String get displayLabel =>
      resolvedName?.isNotEmpty == true ? resolvedName! : suggestedName;
}

class WorkbenchQueueService extends ChangeNotifier {
  static const String _prefsKeyJobCount = 'wb_job_count';
  static const String _prefsKeyDocRefSeq = 'wb_doc_reference_seq';
  static const int _maxParallel = 3;

  final InvoiceOcrService _ocr = InvoiceOcrService();
  final List<WorkbenchJob> _jobs = [];
  int _activeProcessing = 0;
  final List<String> _pendingProcessQueue = [];

  List<String> customerNames = [];
  List<String> customerGstins = [];
  List<String> vendorNames = [];
  List<String> vendorGstins = [];
  List<String> productMasterNames = [];
  List<String> companyGstins = [];

  int _totalProcessed = 0;
  int _duplicatesPrevented = 0;
  int _mastersCreated = 0;
  int _errorsFound = 0;

  int get totalProcessed => _totalProcessed;
  int get duplicatesPrevented => _duplicatesPrevented;
  int get mastersCreated => _mastersCreated;
  int get errorsFound => _errorsFound;

  final List<GlobalMissingMaster> _globalMasters = [];
  List<GlobalMissingMaster> get globalMissingMasters =>
      List.unmodifiable(_globalMasters);
  int countByType(String type) =>
      _globalMasters.where((m) => m.type == type && !m.resolved).length;

  List<WorkbenchJob> get allJobs => List.unmodifiable(_jobs);
  List<WorkbenchJob> get inboxJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.inbox).toList();
  List<WorkbenchJob> get processingJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.processing).toList();
  List<WorkbenchJob> get verificationJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.verification).toList();
  List<WorkbenchJob> get readyJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.approved).toList();
  List<WorkbenchJob> get reviewJobs => _jobs
      .where(
        (j) =>
            j.status == WorkbenchJobStatus.verification ||
            j.status == WorkbenchJobStatus.error,
      )
      .toList();
  List<WorkbenchJob> get approvedJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.approved).toList();
  List<WorkbenchJob> get completedJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.completed).toList();
  List<WorkbenchJob> get failedJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.error).toList();
  List<WorkbenchJob> get archiveJobs =>
      _jobs.where((j) => j.status == WorkbenchJobStatus.archive).toList();
  int get pendingCount =>
      inboxJobs.length + processingJobs.length + verificationJobs.length;

  void synchronizeRemoteDocuments(List<RemoteOcrDocument> documents) {
    var changed = false;
    for (final remote in documents) {
      final index = _jobs.indexWhere(
        (job) => job.remoteDocumentId == remote.id,
      );
      final status = _statusForRemote(remote.status);
      if (index >= 0) {
        final current = _jobs[index];
        _jobs[index] = current.copyWith(
          status: status,
          result: remote.result ?? current.result,
          errorMessage: remote.failureReason,
          assignedAccountantId: remote.assignedAccountantId,
          currentStage: status == WorkbenchJobStatus.processing
              ? SmartInvoiceStage.readingDocument
              : status == WorkbenchJobStatus.error
              ? SmartInvoiceStage.error
              : remote.result != null
              ? SmartInvoiceStage.ready
              : current.currentStage,
        );
        changed = true;
        continue;
      }

      final extension = _ext(remote.fileName);
      final queueBucket = remote.result == null
          ? ClientDocumentQueueBucket.review
          : _bucketFor(remote.result!.detectedKind, extension);
      _jobs.add(
        WorkbenchJob(
          id: 'remote_${remote.id}',
          fileName: remote.fileName,
          status: status,
          result: remote.result,
          uploadedAt: remote.uploadedAt,
          errorMessage: remote.failureReason,
          queueBucket: queueBucket,
          clientId: remote.clientId,
          assignedAccountantId: remote.assignedAccountantId,
          remoteDocumentId: remote.id,
          intakeChannel: ClientDocumentIntakeChannel.mobileApp,
          sourceIdentity: 'ocr-api',
          externalReference: remote.id,
          timeline: <WorkbenchTimelineEvent>[
            WorkbenchTimelineEvent(
              title: 'Synchronized from OCR service',
              at: remote.updatedAt,
              detail: 'Backend status: ${remote.status}',
            ),
          ],
          currentStage: status == WorkbenchJobStatus.processing
              ? SmartInvoiceStage.readingDocument
              : status == WorkbenchJobStatus.error
              ? SmartInvoiceStage.error
              : remote.result != null
              ? SmartInvoiceStage.ready
              : SmartInvoiceStage.idle,
        ),
      );
      changed = true;
    }
    if (changed) {
      _jobs.sort((left, right) => right.uploadedAt.compareTo(left.uploadedAt));
      notifyListeners();
    }
  }

  List<WorkbenchJob> batchJobs(String batchId) =>
      _jobs.where((j) => j.batchId == batchId).toList();
  List<WorkbenchJob> batchReviewJobs(String batchId) => _jobs
      .where(
        (j) =>
            j.batchId == batchId &&
            (j.status == WorkbenchJobStatus.verification ||
                j.status == WorkbenchJobStatus.error),
      )
      .toList();

  ({int total, int ready, int review, int failed, int processing, int inbox})
  batchStats(String batchId) {
    final batch = _jobs.where((j) => j.batchId == batchId).toList();
    return (
      total: batch.length,
      ready: batch
          .where(
            (j) =>
                j.status == WorkbenchJobStatus.approved ||
                j.status == WorkbenchJobStatus.completed,
          )
          .length,
      review: batch
          .where((j) => j.status == WorkbenchJobStatus.verification)
          .length,
      failed: batch.where((j) => j.status == WorkbenchJobStatus.error).length,
      processing: batch
          .where((j) => j.status == WorkbenchJobStatus.processing)
          .length,
      inbox: batch.where((j) => j.status == WorkbenchJobStatus.inbox).length,
    );
  }

  Future<WorkbenchJob> addJob({
    required String fileName,
    String? filePath,
    Uint8List? fileBytes,
    bool autoProcess = true,
    String? clientId,
    String? assignedAccountantId,
    String? remoteDocumentId,
    String? batchId,
    ClientDocumentQueueBucket queueBucket = ClientDocumentQueueBucket.review,
    ClientDocumentIntakeChannel intakeChannel =
        ClientDocumentIntakeChannel.mobileApp,
    String? sourceIdentity,
    String? externalReference,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final seq = (prefs.getInt(_prefsKeyJobCount) ?? 0) + 1;
    await prefs.setInt(_prefsKeyJobCount, seq);
    final ref = externalReference ?? await _nextDocumentReference(prefs);
    final now = DateTime.now();
    final job = WorkbenchJob(
      id: 'wb_${DateTime.now().millisecondsSinceEpoch}_$seq',
      fileName: fileName.isNotEmpty ? fileName : 'document_$seq',
      filePath: filePath,
      fileBytes: fileBytes,
      status: WorkbenchJobStatus.inbox,
      uploadedAt: now,
      batchId: batchId,
      queueBucket: queueBucket,
      clientId: clientId,
      assignedAccountantId: assignedAccountantId,
      remoteDocumentId: remoteDocumentId,
      intakeChannel: intakeChannel,
      sourceIdentity: sourceIdentity,
      externalReference: ref,
      timeline: <WorkbenchTimelineEvent>[
        WorkbenchTimelineEvent(
          title: 'Received',
          at: now,
          detail: 'Received from ${intakeChannel.displayName}',
        ),
      ],
    );
    _jobs.insert(0, job);
    notifyListeners();
    if (autoProcess) _scheduleProcess(job.id);
    return job;
  }

  Future<String> addBatchJobs(
    List<BatchUploadFile> files, {
    String? clientId,
    String? assignedAccountantId,
    bool autoProcess = true,
    ClientDocumentIntakeChannel intakeChannel =
        ClientDocumentIntakeChannel.mobileApp,
    String? sourceIdentity,
  }) async {
    if (files.isEmpty) return '';
    final batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    int seq = prefs.getInt(_prefsKeyJobCount) ?? 0;
    final newJobs = <WorkbenchJob>[];
    for (final f in files) {
      seq++;
      final now = DateTime.now();
      newJobs.add(
        WorkbenchJob(
          id: 'wb_${DateTime.now().millisecondsSinceEpoch}_$seq',
          fileName: f.fileName.isNotEmpty ? f.fileName : 'document_$seq',
          filePath: f.filePath,
          fileBytes: f.fileBytes,
          status: WorkbenchJobStatus.inbox,
          uploadedAt: now,
          batchId: batchId,
          clientId: clientId,
          assignedAccountantId: assignedAccountantId,
          intakeChannel: intakeChannel,
          sourceIdentity: sourceIdentity,
          externalReference: await _nextDocumentReference(prefs),
          timeline: <WorkbenchTimelineEvent>[
            WorkbenchTimelineEvent(
              title: 'Received',
              at: now,
              detail: 'Received from ${intakeChannel.displayName}',
            ),
          ],
        ),
      );
    }
    await prefs.setInt(_prefsKeyJobCount, seq);
    _jobs.insertAll(0, newJobs.reversed);
    notifyListeners();
    if (autoProcess) {
      for (final job in newJobs) {
        _scheduleProcess(job.id);
      }
    }
    return batchId;
  }

  void _scheduleProcess(String id) {
    if (_activeProcessing < _maxParallel) {
      _activeProcessing++;
      _processJob(id).whenComplete(() {
        _activeProcessing--;
        _drainQueue();
      });
    } else {
      _pendingProcessQueue.add(id);
    }
  }

  void _drainQueue() {
    while (_pendingProcessQueue.isNotEmpty &&
        _activeProcessing < _maxParallel) {
      final next = _pendingProcessQueue.removeAt(0);
      _activeProcessing++;
      _processJob(next).whenComplete(() {
        _activeProcessing--;
        _drainQueue();
      });
    }
  }

  Future<void> _processJob(String id) async {
    _updateJob(
      id,
      (j) => j.copyWith(
        status: WorkbenchJobStatus.processing,
        currentStage: SmartInvoiceStage.readingDocument,
      ),
    );
    _appendTimeline(
      id,
      'AI OCR Started',
      'Pipeline started for extraction and classification',
    );
    final job = _find(id);
    String ocrText = '';
    try {
      final ext = _ext(job.fileName);
      final isPdf = ext == 'pdf';
      if (isUsableLocalFilePath(job.filePath)) {
        final file = File(job.filePath!);
        ocrText = isPdf
            ? await _ocr.extractTextFromPdf(
                file,
                maxPagesToScan: 8,
                rasterDpi: 220,
              )
            : await _ocr.extractTextFromImage(file);
      } else if (job.fileBytes != null && job.fileBytes!.isNotEmpty) {
        ocrText = isPdf
            ? await _ocr.extractTextFromPdfBytes(
                job.fileBytes!,
                maxPagesToScan: 8,
                rasterDpi: 220,
              )
            : await _ocr.extractTextFromImageBytes(
                job.fileBytes!,
                fileName: job.fileName,
              );
      } else {
        throw Exception('No file data available for OCR.');
      }

      final engine = SmartInvoiceEngine(
        companyGstins: companyGstins,
        customerNames: customerNames,
        customerGstins: customerGstins,
        vendorNames: vendorNames,
        vendorGstins: vendorGstins,
        productMasterNames: productMasterNames,
      );

      final result = await engine.run(
        ocrText,
        onStage: (stage) {
          _updateJob(id, (j) {
            final done = List<SmartInvoiceStage>.from(j.completedStages);
            if (j.currentStage != SmartInvoiceStage.idle &&
                j.currentStage != SmartInvoiceStage.error &&
                !done.contains(j.currentStage)) {
              done.add(j.currentStage);
            }
            return j.copyWith(currentStage: stage, completedStages: done);
          });
        },
      );

      _totalProcessed++;
      if (result.duplicateResult.isDuplicate) _duplicatesPrevented++;
      if (result.gstResult.warnings.isNotEmpty) _errorsFound++;
      for (final mm in result.missingMasters) {
        _mergeMissingMaster(id, mm);
      }
      _mastersCreated = _globalMasters.where((m) => m.resolved).length;

      final reviewReason = _buildReviewReason(result);
      final detectedBucket = _bucketFor(result.detectedKind, ext);
      final queueBucket = job.queueBucket == ClientDocumentQueueBucket.review
          ? detectedBucket
          : job.queueBucket;
      final autoApprove =
          result.verificationLevel == SmartVerificationLevel.autoVerified;

      _updateJob(
        id,
        (j) => j.copyWith(
          result: result,
          status: autoApprove
              ? WorkbenchJobStatus.approved
              : WorkbenchJobStatus.verification,
          reviewReason: reviewReason,
          queueBucket: queueBucket,
          currentStage: SmartInvoiceStage.ready,
          completedStages: SmartInvoiceStage.values
              .where(
                (s) =>
                    s != SmartInvoiceStage.idle && s != SmartInvoiceStage.error,
              )
              .toList(),
        ),
      );
      _appendTimeline(
        id,
        'AI OCR Completed',
        'Classified as ${result.detectedKind.name}',
      );
      _appendTimeline(
        id,
        autoApprove ? 'Auto Approved' : 'Pending Accountant Review',
        autoApprove ? 'Ready for posting' : reviewReason,
      );
    } catch (e) {
      _errorsFound++;
      _updateJob(
        id,
        (j) => j.copyWith(
          status: WorkbenchJobStatus.error,
          errorMessage: e.toString(),
          currentStage: SmartInvoiceStage.error,
        ),
      );
      _appendTimeline(id, 'Processing Error', e.toString());
    }
  }

  String _buildReviewReason(SmartInvoiceResult result) {
    if (result.duplicateResult.isDuplicate) return 'Duplicate Invoice';
    if (result.missingMasters.any((m) => m.type == 'product')) {
      return 'Product Missing';
    }
    if (result.missingMasters.any(
      (m) => m.type == 'customer' || m.type == 'supplier',
    )) {
      return 'Supplier/Customer Missing';
    }
    if (result.gstResult.warnings.isNotEmpty) return 'GST Mismatch';
    if (!result.taxResult.taxCalcMatch) return 'Tax Mismatch';
    if (result.confidence.overall < 0.85) return 'Low Confidence';
    return 'Needs Review';
  }

  void _mergeMissingMaster(String jobId, SmartMissingMaster mm) {
    final norm = mm.suggestedName.trim().toLowerCase();
    GlobalMissingMaster? existing;
    for (final g in _globalMasters) {
      if (g.type == mm.type && g.suggestedName.trim().toLowerCase() == norm) {
        existing = g;
        break;
      }
    }
    if (existing == null) {
      existing = GlobalMissingMaster(
        type: mm.type,
        suggestedName: mm.suggestedName,
        extra: mm.extra,
        jobIds: [],
      );
      _globalMasters.add(existing);
    }
    if (!existing.jobIds.contains(jobId)) existing.jobIds.add(jobId);
  }

  void resolveMissingMaster(GlobalMissingMaster master, String resolvedName) {
    master.resolved = true;
    master.resolvedName = resolvedName;
    for (final jobId in master.jobIds) {
      _recheckJobAfterMasterResolution(jobId);
    }
    _mastersCreated++;
    notifyListeners();
  }

  void _recheckJobAfterMasterResolution(String jobId) {
    final job = _tryFind(jobId);
    if (job == null || job.result == null) return;
    final unresolved = job.result!.missingMasters.where((mm) {
      return !_globalMasters.any(
        (g) =>
            g.type == mm.type &&
            g.suggestedName.trim().toLowerCase() ==
                mm.suggestedName.trim().toLowerCase() &&
            g.resolved,
      );
    }).toList();
    if (unresolved.isEmpty && job.status == WorkbenchJobStatus.verification) {
      _updateJob(jobId, (j) => j.copyWith(status: WorkbenchJobStatus.approved));
    }
  }

  void saveAllReady() {
    for (final job in readyJobs) {
      _updateJob(
        job.id,
        (j) => j.copyWith(status: WorkbenchJobStatus.completed),
      );
      _appendTimeline(job.id, 'Voucher Posted', 'Saved to accounting records');
    }
    notifyListeners();
  }

  bool updateClientDocument({
    required String jobId,
    required String clientId,
    required String fileName,
  }) {
    final job = _tryFind(jobId);
    if (job == null || !job.canClientMutate(clientId)) return false;
    final index = _jobs.indexWhere((candidate) => candidate.id == jobId);
    _jobs[index] = WorkbenchJob(
      id: job.id,
      fileName: fileName.trim().isEmpty ? job.fileName : fileName.trim(),
      filePath: job.filePath,
      fileBytes: job.fileBytes,
      status: job.status,
      result: job.result,
      uploadedAt: job.uploadedAt,
      errorMessage: job.errorMessage,
      corrections: job.corrections,
      batchId: job.batchId,
      reviewReason: job.reviewReason,
      queueBucket: job.queueBucket,
      clientId: job.clientId,
      assignedAccountantId: job.assignedAccountantId,
      remoteDocumentId: job.remoteDocumentId,
      intakeChannel: job.intakeChannel,
      sourceIdentity: job.sourceIdentity,
      externalReference: job.externalReference,
      timeline: <WorkbenchTimelineEvent>[
        ...job.timeline,
        WorkbenchTimelineEvent(
          title: 'Updated by Client',
          at: DateTime.now(),
          detail: 'Document name changed before accounting entry',
        ),
      ],
      currentStage: job.currentStage,
      completedStages: job.completedStages,
    );
    notifyListeners();
    return true;
  }

  bool deleteClientDocument({required String jobId, required String clientId}) {
    final job = _tryFind(jobId);
    if (job == null || !job.canClientMutate(clientId)) return false;
    _pendingProcessQueue.remove(jobId);
    _jobs.removeWhere((candidate) => candidate.id == jobId);
    notifyListeners();
    return true;
  }

  void saveBatchReady(String batchId) {
    for (final job in batchJobs(batchId)) {
      if (job.status == WorkbenchJobStatus.approved) {
        _updateJob(
          job.id,
          (j) => j.copyWith(status: WorkbenchJobStatus.completed),
        );
        _appendTimeline(
          job.id,
          'Voucher Posted',
          'Saved to accounting records',
        );
      }
    }
    notifyListeners();
  }

  void approveJob(String id) =>
      _updateJob(id, (j) => j.copyWith(status: WorkbenchJobStatus.approved));
  void completeJob(String id) =>
      _updateJob(id, (j) => j.copyWith(status: WorkbenchJobStatus.completed));
  void rejectJob(String id) => _updateJob(
    id,
    (j) => j.copyWith(status: WorkbenchJobStatus.verification),
  );
  void archiveJob(String id) =>
      _updateJob(id, (j) => j.copyWith(status: WorkbenchJobStatus.archive));

  Future<String> _nextDocumentReference(SharedPreferences prefs) async {
    final next = (prefs.getInt(_prefsKeyDocRefSeq) ?? 0) + 1;
    await prefs.setInt(_prefsKeyDocRefSeq, next);
    final year = DateTime.now().year;
    return 'DOC-$year-${next.toString().padLeft(6, '0')}';
  }

  void _appendTimeline(String jobId, String title, String detail) {
    _updateJob(jobId, (j) {
      final events = List<WorkbenchTimelineEvent>.from(j.timeline)
        ..add(
          WorkbenchTimelineEvent(
            title: title,
            detail: detail,
            at: DateTime.now(),
          ),
        );
      return j.copyWith(timeline: events);
    });
  }

  void retryJob(String id) {
    _updateJob(
      id,
      (j) => j.copyWith(
        status: WorkbenchJobStatus.inbox,
        currentStage: SmartInvoiceStage.idle,
        completedStages: [],
        reviewReason: null,
      ),
    );
    _scheduleProcess(id);
  }

  void recordCorrection(
    String id,
    String fieldName,
    String original,
    String corrected,
  ) {
    _updateJob(id, (j) {
      final list = List<WorkbenchCorrection>.from(j.corrections)
        ..add(
          WorkbenchCorrection(
            fieldName: fieldName,
            original: original,
            corrected: corrected,
            correctedAt: DateTime.now(),
          ),
        );
      return j.copyWith(corrections: list);
    });
  }

  void removeJob(String id) {
    _jobs.removeWhere((j) => j.id == id);
    notifyListeners();
  }

  WorkbenchJob _find(String id) => _jobs.firstWhere((j) => j.id == id);
  WorkbenchJob? _tryFind(String id) {
    try {
      return _jobs.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }

  void _updateJob(String id, WorkbenchJob Function(WorkbenchJob) transform) {
    final idx = _jobs.indexWhere((j) => j.id == id);
    if (idx < 0) return;
    _jobs[idx] = transform(_jobs[idx]);
    notifyListeners();
  }

  String _ext(String name) {
    final idx = name.lastIndexOf('.');
    if (idx < 0 || idx >= name.length - 1) return '';
    return name.substring(idx + 1).toLowerCase();
  }

  WorkbenchJobStatus _statusForRemote(String status) {
    switch (status.toLowerCase()) {
      case 'uploaded':
        return WorkbenchJobStatus.inbox;
      case 'processing':
      case 'reprocessing':
        return WorkbenchJobStatus.processing;
      case 'ready':
      case 'approved':
        return WorkbenchJobStatus.approved;
      case 'saved':
      case 'posted':
      case 'completed':
        return WorkbenchJobStatus.completed;
      case 'error':
      case 'apifailure':
        return WorkbenchJobStatus.error;
      case 'rejected':
        return WorkbenchJobStatus.archive;
      default:
        return WorkbenchJobStatus.verification;
    }
  }

  ClientDocumentQueueBucket _bucketFor(OcrDocumentKind kind, String ext) {
    if (ext == 'csv' ||
        ext == 'xlsx' ||
        ext == 'xls' ||
        ext == 'xlsm' ||
        ext == 'json' ||
        ext == 'txt') {
      return ClientDocumentQueueBucket.import;
    }
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return ClientDocumentQueueBucket.sales;
      case OcrDocumentKind.purchaseBill:
        return ClientDocumentQueueBucket.purchase;
      case OcrDocumentKind.creditNote:
        return ClientDocumentQueueBucket.creditNote;
      case OcrDocumentKind.debitNote:
        return ClientDocumentQueueBucket.debitNote;
      case OcrDocumentKind.chequeGiven:
      case OcrDocumentKind.paymentVoucher:
        return ClientDocumentQueueBucket.payment;
      case OcrDocumentKind.chequeReceived:
      case OcrDocumentKind.receiptVoucher:
        return ClientDocumentQueueBucket.receipt;
      case OcrDocumentKind.unknown:
        return ClientDocumentQueueBucket.review;
    }
  }
}
