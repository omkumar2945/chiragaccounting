import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UniDeskScope {
  viewOnly,
  accounting,
  gst,
  reports,
  documents,
  settings,
  fullControl,
}

enum UniDeskRequestStatus {
  pendingClientApproval,
  awaitingStaff,
  active,
  ended,
  revoked,
}

class UniDeskEvent {
  const UniDeskEvent({
    required this.action,
    required this.actorUserId,
    required this.occurredAt,
    this.note = '',
  });

  final String action;
  final String actorUserId;
  final DateTime occurredAt;
  final String note;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'action': action,
    'actorUserId': actorUserId,
    'occurredAt': occurredAt.toIso8601String(),
    'note': note,
  };

  factory UniDeskEvent.fromJson(Map<String, dynamic> json) => UniDeskEvent(
    action: json['action']?.toString() ?? '',
    actorUserId: json['actorUserId']?.toString() ?? '',
    occurredAt:
        DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
        DateTime.now(),
    note: json['note']?.toString() ?? '',
  );
}

class UniDeskRequest {
  const UniDeskRequest({
    required this.id,
    required this.clientId,
    required this.subject,
    required this.details,
    required this.scopes,
    required this.durationHours,
    required this.status,
    required this.requestedBy,
    required this.requestedAt,
    required this.events,
    this.clientConsentedAt,
    this.assignedUserId = '',
    this.activatedAt,
    this.endedAt,
  });

  final String id;
  final String clientId;
  final String subject;
  final String details;
  final Set<UniDeskScope> scopes;
  final int durationHours;
  final UniDeskRequestStatus status;
  final String requestedBy;
  final DateTime requestedAt;
  final DateTime? clientConsentedAt;
  final String assignedUserId;
  final DateTime? activatedAt;
  final DateTime? endedAt;
  final List<UniDeskEvent> events;

  DateTime? get expiresAt => activatedAt?.add(Duration(hours: durationHours));

  bool get grantsFullControl => scopes.contains(UniDeskScope.fullControl);

  bool isActiveAt(DateTime now) =>
      status == UniDeskRequestStatus.active &&
      expiresAt != null &&
      now.isBefore(expiresAt!);

  UniDeskRequest copyWith({
    Set<UniDeskScope>? scopes,
    UniDeskRequestStatus? status,
    DateTime? clientConsentedAt,
    String? assignedUserId,
    DateTime? activatedAt,
    DateTime? endedAt,
    List<UniDeskEvent>? events,
  }) => UniDeskRequest(
    id: id,
    clientId: clientId,
    subject: subject,
    details: details,
    scopes: scopes ?? this.scopes,
    durationHours: durationHours,
    status: status ?? this.status,
    requestedBy: requestedBy,
    requestedAt: requestedAt,
    clientConsentedAt: clientConsentedAt ?? this.clientConsentedAt,
    assignedUserId: assignedUserId ?? this.assignedUserId,
    activatedAt: activatedAt ?? this.activatedAt,
    endedAt: endedAt ?? this.endedAt,
    events: events ?? this.events,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'clientId': clientId,
    'subject': subject,
    'details': details,
    'scopes': scopes.map((scope) => scope.name).toList(),
    'durationHours': durationHours,
    'status': status.name,
    'requestedBy': requestedBy,
    'requestedAt': requestedAt.toIso8601String(),
    'clientConsentedAt': clientConsentedAt?.toIso8601String(),
    'assignedUserId': assignedUserId,
    'activatedAt': activatedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'events': events.map((event) => event.toJson()).toList(),
  };

  factory UniDeskRequest.fromJson(Map<String, dynamic> json) => UniDeskRequest(
    id: json['id']?.toString() ?? '',
    clientId: json['clientId']?.toString() ?? '',
    subject: json['subject']?.toString() ?? '',
    details: json['details']?.toString() ?? '',
    scopes: (json['scopes'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (value) => UniDeskScope.values.firstWhere(
            (scope) => scope.name == value.toString(),
            orElse: () => UniDeskScope.viewOnly,
          ),
        )
        .toSet(),
    durationHours: (json['durationHours'] as num?)?.toInt() ?? 1,
    status: UniDeskRequestStatus.values.firstWhere(
      (status) => status.name == json['status']?.toString(),
      orElse: () => UniDeskRequestStatus.pendingClientApproval,
    ),
    requestedBy: json['requestedBy']?.toString() ?? '',
    requestedAt:
        DateTime.tryParse(json['requestedAt']?.toString() ?? '') ??
        DateTime.now(),
    clientConsentedAt: DateTime.tryParse(
      json['clientConsentedAt']?.toString() ?? '',
    ),
    assignedUserId: json['assignedUserId']?.toString() ?? '',
    activatedAt: DateTime.tryParse(json['activatedAt']?.toString() ?? ''),
    endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
    events: (json['events'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((event) => UniDeskEvent.fromJson(Map<String, dynamic>.from(event)))
        .toList(growable: false),
  );
}

class UniDeskService extends ChangeNotifier {
  UniDeskService({SharedPreferences? preferences, DateTime Function()? clock})
    : _preferences = preferences,
      _clock = clock ?? DateTime.now;

  static const String _storageKey = 'uni_desk_requests_v1';
  static const String _accessIdKey = 'uni_desk_access_id_v1';
  static const String _accessAuthKey = 'uni_desk_access_auth_v1';

  final SharedPreferences? _preferences;
  final DateTime Function() _clock;
  final List<UniDeskRequest> _requests = <UniDeskRequest>[];
  String _activeAccessId = '';
  final Map<String, String> _authenticatedUserIdByRole = <String, String>{};

  List<UniDeskRequest> get requests =>
      List<UniDeskRequest>.unmodifiable(_requests);
  String get activeAccessId => _activeAccessId;

  bool get hasActiveAccessId => _activeAccessId.trim().isNotEmpty;

  bool isUserAuthenticatedForRole({
    required String roleKey,
    required String userId,
  }) => _authenticatedUserIdByRole[roleKey] == userId;

  List<UniDeskRequest> requestsForClient(String clientId) => _requests
      .where((request) => request.clientId == clientId)
      .toList(growable: false);

  List<UniDeskRequest> requestsForStaff(
    String userId, {
    required bool isAdmin,
  }) => _requests
      .where(
        (request) =>
            isAdmin ||
            request.assignedUserId.isEmpty ||
            request.assignedUserId == userId,
      )
      .toList(growable: false);

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final decoded = jsonDecode(preferences.getString(_storageKey) ?? '[]');
    _requests
      ..clear()
      ..addAll(
        (decoded as List<dynamic>? ?? const <dynamic>[]).whereType<Map>().map(
          (item) => UniDeskRequest.fromJson(Map<String, dynamic>.from(item)),
        ),
      );
    _activeAccessId = preferences.getString(_accessIdKey) ?? '';
    final rawAuth = jsonDecode(preferences.getString(_accessAuthKey) ?? '{}');
    _authenticatedUserIdByRole
      ..clear()
      ..addAll(
        Map<String, dynamic>.from(rawAuth as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    notifyListeners();
  }

  Future<String> rotateAccessId({required String generatedByUserId}) async {
    final random = Random.secure();
    final digits = List<int>.generate(6, (_) => random.nextInt(10)).join();
    _activeAccessId = 'CHIRAG-$digits';
    _authenticatedUserIdByRole.clear();
    await _saveAccessState();
    notifyListeners();
    return _activeAccessId;
  }

  Future<bool> authenticateWithAccessId({
    required String roleKey,
    required String userId,
    required String accessId,
  }) async {
    if (_activeAccessId.trim().isEmpty) return false;
    final matches = accessId.trim().toUpperCase() ==
        _activeAccessId.trim().toUpperCase();
    if (!matches) return false;
    _authenticatedUserIdByRole[roleKey] = userId;
    await _saveAccessState();
    notifyListeners();
    return true;
  }

  Future<UniDeskRequest> raiseByClient({
    required String clientId,
    required String subject,
    required String details,
    required Set<UniDeskScope> scopes,
    required int durationHours,
  }) => _create(
    clientId: clientId,
    subject: subject,
    details: details,
    scopes: scopes,
    durationHours: durationHours,
    requestedBy: clientId,
    clientConsentedAt: _clock(),
    status: UniDeskRequestStatus.awaitingStaff,
  );

  Future<UniDeskRequest> requestPermissionByStaff({
    required String clientId,
    required String requestedBy,
    required String subject,
    required String details,
    required Set<UniDeskScope> scopes,
    required int durationHours,
  }) => _create(
    clientId: clientId,
    subject: subject,
    details: details,
    scopes: scopes,
    durationHours: durationHours,
    requestedBy: requestedBy,
    status: UniDeskRequestStatus.pendingClientApproval,
  );

  Future<UniDeskRequest> _create({
    required String clientId,
    required String subject,
    required String details,
    required Set<UniDeskScope> scopes,
    required int durationHours,
    required String requestedBy,
    required UniDeskRequestStatus status,
    DateTime? clientConsentedAt,
  }) async {
    if (clientId.trim().isEmpty || subject.trim().isEmpty) {
      throw const FormatException(
        'Client and assistance subject are required.',
      );
    }
    if (scopes.isEmpty) {
      throw const FormatException('Select at least one assistance permission.');
    }
    if (durationHours < 1 || durationHours > 24) {
      throw const FormatException('Assistance duration must be 1 to 24 hours.');
    }
    final now = _clock();
    final request = UniDeskRequest(
      id: 'desk-${now.microsecondsSinceEpoch}',
      clientId: clientId.trim(),
      subject: subject.trim(),
      details: details.trim(),
      scopes: Set<UniDeskScope>.unmodifiable(scopes),
      durationHours: durationHours,
      status: status,
      requestedBy: requestedBy.trim(),
      requestedAt: now,
      clientConsentedAt: clientConsentedAt,
      events: <UniDeskEvent>[
        UniDeskEvent(
          action: status == UniDeskRequestStatus.awaitingStaff
              ? 'client_permission_granted'
              : 'staff_permission_requested',
          actorUserId: requestedBy,
          occurredAt: now,
        ),
      ],
    );
    _requests.add(request);
    await _save();
    notifyListeners();
    return request;
  }

  Future<void> approveByClient({
    required String requestId,
    required String clientId,
    Set<UniDeskScope>? approvedScopes,
  }) async {
    final index = _indexOf(requestId);
    final request = _requests[index];
    if (request.clientId != clientId ||
        request.status != UniDeskRequestStatus.pendingClientApproval) {
      throw StateError('This request cannot be approved by the client.');
    }
    final scopes = approvedScopes ?? request.scopes;
    if (scopes.isEmpty || !request.scopes.containsAll(scopes)) {
      throw const FormatException(
        'Approved permissions must be a non-empty subset of the request.',
      );
    }
    final now = _clock();
    _requests[index] = request.copyWith(
      scopes: Set<UniDeskScope>.unmodifiable(scopes),
      status: UniDeskRequestStatus.awaitingStaff,
      clientConsentedAt: now,
      events: <UniDeskEvent>[
        ...request.events,
        UniDeskEvent(
          action: 'client_permission_granted',
          actorUserId: clientId,
          occurredAt: now,
        ),
      ],
    );
    await _saveAndNotify();
  }

  Future<void> startSession({
    required String requestId,
    required String staffUserId,
    required bool isAdmin,
    required String assignedAccountantId,
  }) async {
    final index = _indexOf(requestId);
    final request = _requests[index];
    if (request.status != UniDeskRequestStatus.awaitingStaff ||
        request.clientConsentedAt == null) {
      throw StateError(
        'Client permission is required before assistance starts.',
      );
    }
    if (!isAdmin && staffUserId != assignedAccountantId) {
      throw StateError('Only the assigned accountant or an admin can assist.');
    }
    final now = _clock();
    _requests[index] = request.copyWith(
      status: UniDeskRequestStatus.active,
      assignedUserId: staffUserId,
      activatedAt: now,
      events: <UniDeskEvent>[
        ...request.events,
        UniDeskEvent(
          action: 'assistance_started',
          actorUserId: staffUserId,
          occurredAt: now,
        ),
      ],
    );
    await _saveAndNotify();
  }

  bool canAssist({required String requestId, required String staffUserId}) {
    final request = _requests[_indexOf(requestId)];
    return request.assignedUserId == staffUserId &&
        request.isActiveAt(_clock());
  }

  Future<void> revokeByClient({
    required String requestId,
    required String clientId,
  }) async {
    final index = _indexOf(requestId);
    final request = _requests[index];
    if (request.clientId != clientId ||
        request.status == UniDeskRequestStatus.ended ||
        request.status == UniDeskRequestStatus.revoked) {
      throw StateError('This assistance permission cannot be revoked.');
    }
    final now = _clock();
    _requests[index] = request.copyWith(
      status: UniDeskRequestStatus.revoked,
      endedAt: now,
      events: <UniDeskEvent>[
        ...request.events,
        UniDeskEvent(
          action: 'client_permission_revoked',
          actorUserId: clientId,
          occurredAt: now,
        ),
      ],
    );
    await _saveAndNotify();
  }

  Future<void> endSession({
    required String requestId,
    required String staffUserId,
  }) async {
    final index = _indexOf(requestId);
    final request = _requests[index];
    if (request.assignedUserId != staffUserId ||
        request.status != UniDeskRequestStatus.active) {
      throw StateError('Only the active assisting user can end this session.');
    }
    final now = _clock();
    _requests[index] = request.copyWith(
      status: UniDeskRequestStatus.ended,
      endedAt: now,
      events: <UniDeskEvent>[
        ...request.events,
        UniDeskEvent(
          action: 'assistance_ended',
          actorUserId: staffUserId,
          occurredAt: now,
        ),
      ],
    );
    await _saveAndNotify();
  }

  int _indexOf(String requestId) {
    final index = _requests.indexWhere((request) => request.id == requestId);
    if (index < 0) throw StateError('Uni-Desk request was not found.');
    return index;
  }

  Future<void> _saveAndNotify() async {
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_requests.map((request) => request.toJson()).toList()),
    );
  }

  Future<void> _saveAccessState() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(_accessIdKey, _activeAccessId);
    await preferences.setString(
      _accessAuthKey,
      jsonEncode(_authenticatedUserIdByRole),
    );
  }
}
