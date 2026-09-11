import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/gst_library/services/gst_notice_analysis_service.dart';

enum GstManagedNoticeSource { onlinePortal, paperUpload }

enum GstManagedNoticeStatus {
  received,
  drafting,
  reviewReady,
  submitted,
  closed,
}

enum GstReplyPresentationMode { notPresented, physical, online }

class GstOfficerUpdate {
  const GstOfficerUpdate({
    required this.id,
    required this.recordedAt,
    required this.resultOrRemarks,
    required this.nextQuery,
    required this.nextAction,
    required this.actionDueDateText,
  });

  final String id;
  final DateTime recordedAt;
  final String resultOrRemarks;
  final String nextQuery;
  final String nextAction;
  final String actionDueDateText;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'recordedAt': recordedAt.toIso8601String(),
    'resultOrRemarks': resultOrRemarks,
    'nextQuery': nextQuery,
    'nextAction': nextAction,
    'actionDueDateText': actionDueDateText,
  };

  factory GstOfficerUpdate.fromJson(Map<String, dynamic> json) =>
      GstOfficerUpdate(
        id: json['id']?.toString() ?? '',
        recordedAt:
            DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
            DateTime.now(),
        resultOrRemarks: json['resultOrRemarks']?.toString() ?? '',
        nextQuery: json['nextQuery']?.toString() ?? '',
        nextAction: json['nextAction']?.toString() ?? '',
        actionDueDateText: json['actionDueDateText']?.toString() ?? '',
      );
}

class GstManagedNotice {
  const GstManagedNotice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.gstin,
    required this.source,
    required this.fileName,
    required this.fileExtension,
    required this.fileBytesBase64,
    required this.formNumber,
    required this.noticeNumber,
    required this.taxPeriod,
    required this.dueDateText,
    required this.extractedText,
    required this.riskFlags,
    required this.draftReply,
    required this.replyReport,
    required this.presentationMode,
    required this.presentedAt,
    required this.presentationReference,
    required this.officerUpdates,
    required this.finalOrderFileName,
    required this.finalOrderFileBytesBase64,
    required this.finalOrderRemarks,
    required this.lockedAt,
    required this.status,
    required this.clientVisible,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String gstin;
  final GstManagedNoticeSource source;
  final String fileName;
  final String fileExtension;
  final String fileBytesBase64;
  final String formNumber;
  final String noticeNumber;
  final String taxPeriod;
  final String dueDateText;
  final String extractedText;
  final List<String> riskFlags;
  final String draftReply;
  final String replyReport;
  final GstReplyPresentationMode presentationMode;
  final DateTime? presentedAt;
  final String presentationReference;
  final List<GstOfficerUpdate> officerUpdates;
  final String finalOrderFileName;
  final String finalOrderFileBytesBase64;
  final String finalOrderRemarks;
  final DateTime? lockedAt;
  final GstManagedNoticeStatus status;
  final bool clientVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasOriginalDocument => fileBytesBase64.isNotEmpty;
  bool get hasFinalOrder => finalOrderFileBytesBase64.isNotEmpty;
  bool get isLocked => lockedAt != null;

  Uint8List get originalDocumentBytes =>
      fileBytesBase64.isEmpty ? Uint8List(0) : base64Decode(fileBytesBase64);

  Uint8List get finalOrderBytes => finalOrderFileBytesBase64.isEmpty
      ? Uint8List(0)
      : base64Decode(finalOrderFileBytesBase64);

  GstManagedNotice copyWith({
    String? draftReply,
    String? replyReport,
    GstReplyPresentationMode? presentationMode,
    DateTime? presentedAt,
    String? presentationReference,
    List<GstOfficerUpdate>? officerUpdates,
    String? finalOrderFileName,
    String? finalOrderFileBytesBase64,
    String? finalOrderRemarks,
    DateTime? lockedAt,
    GstManagedNoticeStatus? status,
    bool? clientVisible,
    DateTime? updatedAt,
  }) => GstManagedNotice(
    id: id,
    clientId: clientId,
    clientName: clientName,
    gstin: gstin,
    source: source,
    fileName: fileName,
    fileExtension: fileExtension,
    fileBytesBase64: fileBytesBase64,
    formNumber: formNumber,
    noticeNumber: noticeNumber,
    taxPeriod: taxPeriod,
    dueDateText: dueDateText,
    extractedText: extractedText,
    riskFlags: riskFlags,
    draftReply: draftReply ?? this.draftReply,
    replyReport: replyReport ?? this.replyReport,
    presentationMode: presentationMode ?? this.presentationMode,
    presentedAt: presentedAt ?? this.presentedAt,
    presentationReference: presentationReference ?? this.presentationReference,
    officerUpdates: officerUpdates ?? this.officerUpdates,
    finalOrderFileName: finalOrderFileName ?? this.finalOrderFileName,
    finalOrderFileBytesBase64:
        finalOrderFileBytesBase64 ?? this.finalOrderFileBytesBase64,
    finalOrderRemarks: finalOrderRemarks ?? this.finalOrderRemarks,
    lockedAt: lockedAt ?? this.lockedAt,
    status: status ?? this.status,
    clientVisible: clientVisible ?? this.clientVisible,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'gstin': gstin,
    'source': source.name,
    'fileName': fileName,
    'fileExtension': fileExtension,
    'fileBytesBase64': fileBytesBase64,
    'formNumber': formNumber,
    'noticeNumber': noticeNumber,
    'taxPeriod': taxPeriod,
    'dueDateText': dueDateText,
    'extractedText': extractedText,
    'riskFlags': riskFlags,
    'draftReply': draftReply,
    'replyReport': replyReport,
    'presentationMode': presentationMode.name,
    'presentedAt': presentedAt?.toIso8601String(),
    'presentationReference': presentationReference,
    'officerUpdates': officerUpdates
        .map((update) => update.toJson())
        .toList(growable: false),
    'finalOrderFileName': finalOrderFileName,
    'finalOrderFileBytesBase64': finalOrderFileBytesBase64,
    'finalOrderRemarks': finalOrderRemarks,
    'lockedAt': lockedAt?.toIso8601String(),
    'status': status.name,
    'clientVisible': clientVisible,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory GstManagedNotice.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((value) => value.name == name).firstOrNull ?? fallback;
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return GstManagedNotice(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      source: enumValue(
        GstManagedNoticeSource.values,
        json['source']?.toString(),
        GstManagedNoticeSource.paperUpload,
      ),
      fileName: json['fileName']?.toString() ?? '',
      fileExtension: json['fileExtension']?.toString() ?? '',
      fileBytesBase64: json['fileBytesBase64']?.toString() ?? '',
      formNumber: json['formNumber']?.toString() ?? '',
      noticeNumber: json['noticeNumber']?.toString() ?? '',
      taxPeriod: json['taxPeriod']?.toString() ?? '',
      dueDateText: json['dueDateText']?.toString() ?? '',
      extractedText: json['extractedText']?.toString() ?? '',
      riskFlags: (json['riskFlags'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      draftReply: json['draftReply']?.toString() ?? '',
      replyReport: json['replyReport']?.toString() ?? '',
      presentationMode: enumValue(
        GstReplyPresentationMode.values,
        json['presentationMode']?.toString(),
        GstReplyPresentationMode.notPresented,
      ),
      presentedAt: DateTime.tryParse(json['presentedAt']?.toString() ?? ''),
      presentationReference: json['presentationReference']?.toString() ?? '',
      officerUpdates:
          (json['officerUpdates'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .map(GstOfficerUpdate.fromJson)
              .toList(growable: false),
      finalOrderFileName: json['finalOrderFileName']?.toString() ?? '',
      finalOrderFileBytesBase64:
          json['finalOrderFileBytesBase64']?.toString() ?? '',
      finalOrderRemarks: json['finalOrderRemarks']?.toString() ?? '',
      lockedAt: DateTime.tryParse(json['lockedAt']?.toString() ?? ''),
      status: enumValue(
        GstManagedNoticeStatus.values,
        json['status']?.toString(),
        GstManagedNoticeStatus.received,
      ),
      clientVisible: json['clientVisible'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

class GstNoticeManagementService extends ChangeNotifier {
  GstNoticeManagementService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String storageKey = 'gst_managed_notices_v1';

  final SharedPreferences? _preferences;
  final List<GstManagedNotice> _notices = <GstManagedNotice>[];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<GstManagedNotice> get notices => List.unmodifiable(_notices);

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey);
    _notices
      ..clear()
      ..addAll(_decode(encoded));
    _sort();
    _isLoaded = true;
    notifyListeners();
  }

  List<GstManagedNotice> noticesForClient(
    String clientId, {
    bool visibleOnly = false,
  }) => _notices
      .where(
        (notice) =>
            notice.clientId == clientId &&
            (!visibleOnly || notice.clientVisible),
      )
      .toList(growable: false);

  Future<GstManagedNotice> addUploadedNotice({
    required String clientId,
    required String clientName,
    required String clientGstin,
    required Uint8List bytes,
    required GstNoticeAnalysis analysis,
  }) async {
    if (clientId.trim().isEmpty) {
      throw ArgumentError('Select a client before saving the GST notice.');
    }
    if (bytes.isEmpty) throw ArgumentError('The selected notice is empty.');
    final now = DateTime.now();
    final notice = GstManagedNotice(
      id: 'gst-notice-${now.microsecondsSinceEpoch}',
      clientId: clientId.trim(),
      clientName: clientName.trim(),
      gstin: clientGstin.trim().toUpperCase(),
      source: GstManagedNoticeSource.paperUpload,
      fileName: analysis.fileName,
      fileExtension: analysis.fileName.contains('.')
          ? analysis.fileName.split('.').last.toLowerCase()
          : '',
      fileBytesBase64: base64Encode(bytes),
      formNumber: analysis.formNumber,
      noticeNumber: analysis.noticeNumber,
      taxPeriod: analysis.taxPeriod,
      dueDateText: analysis.dueDateText,
      extractedText: analysis.extractedText,
      riskFlags: analysis.riskFlags,
      draftReply: analysis.draftReply,
      replyReport: '',
      presentationMode: GstReplyPresentationMode.notPresented,
      presentedAt: null,
      presentationReference: '',
      officerUpdates: const <GstOfficerUpdate>[],
      finalOrderFileName: '',
      finalOrderFileBytesBase64: '',
      finalOrderRemarks: '',
      lockedAt: null,
      status: GstManagedNoticeStatus.drafting,
      clientVisible: false,
      createdAt: now,
      updatedAt: now,
    );
    _notices.add(notice);
    _sort();
    await _save();
    return notice;
  }

  Future<void> updateRecord(
    String noticeId, {
    String? draftReply,
    String? replyReport,
    GstManagedNoticeStatus? status,
    bool? clientVisible,
  }) async {
    final index = _notices.indexWhere((notice) => notice.id == noticeId);
    if (index < 0) throw StateError('GST notice record was not found.');
    if (_notices[index].isLocked) {
      throw StateError('Final order is locked. This record is view-only.');
    }
    _notices[index] = _notices[index].copyWith(
      draftReply: draftReply,
      replyReport: replyReport,
      status: status,
      clientVisible: clientVisible,
      updatedAt: DateTime.now(),
    );
    _sort();
    await _save();
  }

  Future<void> recordReplyPresentation(
    String noticeId, {
    required GstReplyPresentationMode mode,
    required DateTime presentedAt,
    required String reference,
  }) async {
    if (mode == GstReplyPresentationMode.notPresented) {
      throw ArgumentError('Select physical or online presentation mode.');
    }
    final index = _editableIndex(noticeId);
    _notices[index] = _notices[index].copyWith(
      presentationMode: mode,
      presentedAt: presentedAt,
      presentationReference: reference.trim(),
      status: GstManagedNoticeStatus.submitted,
      updatedAt: DateTime.now(),
    );
    _sort();
    await _save();
  }

  Future<void> addOfficerUpdate(
    String noticeId, {
    required String resultOrRemarks,
    required String nextQuery,
    required String nextAction,
    required String actionDueDateText,
  }) async {
    if (<String>[
      resultOrRemarks,
      nextQuery,
      nextAction,
    ].every((value) => value.trim().isEmpty)) {
      throw ArgumentError('Enter officer remarks, next query or next action.');
    }
    final index = _editableIndex(noticeId);
    final now = DateTime.now();
    final update = GstOfficerUpdate(
      id: 'officer-update-${now.microsecondsSinceEpoch}',
      recordedAt: now,
      resultOrRemarks: resultOrRemarks.trim(),
      nextQuery: nextQuery.trim(),
      nextAction: nextAction.trim(),
      actionDueDateText: actionDueDateText.trim(),
    );
    _notices[index] = _notices[index].copyWith(
      officerUpdates: <GstOfficerUpdate>[
        ..._notices[index].officerUpdates,
        update,
      ],
      status: GstManagedNoticeStatus.submitted,
      updatedAt: now,
    );
    _sort();
    await _save();
  }

  Future<void> uploadFinalOrder(
    String noticeId, {
    required String fileName,
    required Uint8List bytes,
    required String remarks,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('The final order file is empty.');
    if (bytes.length > 15 * 1024 * 1024) {
      throw ArgumentError('Final order must be 15 MB or smaller.');
    }
    final index = _editableIndex(noticeId);
    final now = DateTime.now();
    _notices[index] = _notices[index].copyWith(
      finalOrderFileName: fileName.trim(),
      finalOrderFileBytesBase64: base64Encode(bytes),
      finalOrderRemarks: remarks.trim(),
      lockedAt: now,
      status: GstManagedNoticeStatus.closed,
      updatedAt: now,
    );
    _sort();
    await _save();
  }

  Future<void> deleteRecord(String noticeId) async {
    final notice = _notices.where((item) => item.id == noticeId).firstOrNull;
    if (notice?.isLocked ?? false) {
      throw StateError('Final order is locked. This record is view-only.');
    }
    _notices.removeWhere((notice) => notice.id == noticeId);
    await _save();
  }

  int _editableIndex(String noticeId) {
    final index = _notices.indexWhere((notice) => notice.id == noticeId);
    if (index < 0) throw StateError('GST notice record was not found.');
    if (_notices[index].isLocked) {
      throw StateError('Final order is locked. This record is view-only.');
    }
    return index;
  }

  void _sort() =>
      _notices.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(_notices.map((notice) => notice.toJson()).toList()),
    );
    notifyListeners();
  }

  List<GstManagedNotice> _decode(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const [];
    try {
      final values = jsonDecode(encoded) as List<dynamic>;
      return values
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .map(GstManagedNotice.fromJson)
          .where((notice) => notice.id.isNotEmpty && notice.clientId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
