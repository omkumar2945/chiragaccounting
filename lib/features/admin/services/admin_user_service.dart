import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/core/events/event_types.dart';
import 'package:chirag_accounting/core/integrations/integration_hub_service.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/admin/models/tally_sync_settings.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/admin/models/admin_audit_event.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/clients/Referral/client_referral_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

enum CredentialChannel { email, sms, whatsapp }

enum CredentialDeliveryStatus { sent, queued, failed }

enum GstRegistrationType { unregistered, regular, composition }

enum ClientAccountingMode { accountingOnly, accountingWithInventory }

extension ClientAccountingModeLabel on ClientAccountingMode {
  String get displayName => switch (this) {
    ClientAccountingMode.accountingOnly => 'Accounting only',
    ClientAccountingMode.accountingWithInventory => 'Accounting with inventory',
  };
}

extension GstRegistrationTypeLabel on GstRegistrationType {
  String get displayName => switch (this) {
    GstRegistrationType.unregistered => 'Unregistered',
    GstRegistrationType.regular => 'Regular Dealer',
    GstRegistrationType.composition => 'Composition Dealer',
  };
}

class ClientServicePeriod {
  const ClientServicePeriod({
    required this.effectiveFrom,
    required this.accountingMode,
    required this.gstRegistrationType,
  });

  final DateTime effectiveFrom;
  final ClientAccountingMode accountingMode;
  final GstRegistrationType gstRegistrationType;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'effectiveFrom': effectiveFrom.toIso8601String(),
    'accountingMode': accountingMode.name,
    'gstRegistrationType': gstRegistrationType.name,
  };

  factory ClientServicePeriod.fromJson(Map<String, dynamic> json) {
    return ClientServicePeriod(
      effectiveFrom:
          DateTime.tryParse(json['effectiveFrom']?.toString() ?? '') ??
          DateTime.now(),
      accountingMode: ClientAccountingMode.values.firstWhere(
        (value) => value.name == json['accountingMode']?.toString(),
        orElse: () => ClientAccountingMode.accountingOnly,
      ),
      gstRegistrationType: GstRegistrationType.values.firstWhere(
        (value) => value.name == json['gstRegistrationType']?.toString(),
        orElse: () => GstRegistrationType.unregistered,
      ),
    );
  }
}

class AdminClientComplianceRecord {
  const AdminClientComplianceRecord({
    required this.userId,
    this.gstRegistrationType = GstRegistrationType.unregistered,
    this.gstin = '',
    this.pan = '',
    this.state = '',
    this.city = '',
    this.pincode = '',
    this.services = const <String>[],
    this.accountingEnabled = true,
    this.gstEnabled = false,
    this.servicePeriods = const <ClientServicePeriod>[],
  });

  final String userId;
  final GstRegistrationType gstRegistrationType;
  final String gstin;
  final String pan;
  final String state;
  final String city;
  final String pincode;
  final List<String> services;
  final bool accountingEnabled;
  final bool gstEnabled;
  final List<ClientServicePeriod> servicePeriods;

  ClientServicePeriod servicePeriodOn(DateTime date) {
    final eligible =
        servicePeriods
            .where((period) => !period.effectiveFrom.isAfter(date))
            .toList(growable: false)
          ..sort(
            (left, right) => right.effectiveFrom.compareTo(left.effectiveFrom),
          );
    return eligible.firstOrNull ??
        ClientServicePeriod(
          effectiveFrom: DateTime.fromMillisecondsSinceEpoch(0),
          accountingMode: ClientAccountingMode.accountingOnly,
          gstRegistrationType: gstRegistrationType,
        );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'userId': userId,
    'gstRegistrationType': gstRegistrationType.name,
    'gstin': gstin,
    'pan': pan,
    'state': state,
    'city': city,
    'pincode': pincode,
    'services': services,
    'accountingEnabled': accountingEnabled,
    'gstEnabled': gstEnabled,
    'servicePeriods': servicePeriods
        .map((period) => period.toJson())
        .toList(growable: false),
  };

  factory AdminClientComplianceRecord.fromJson(Map<String, dynamic> json) {
    return AdminClientComplianceRecord(
      userId: json['userId']?.toString() ?? '',
      gstRegistrationType: GstRegistrationType.values.firstWhere(
        (value) => value.name == json['gstRegistrationType']?.toString(),
        orElse: () => GstRegistrationType.unregistered,
      ),
      gstin: json['gstin']?.toString() ?? '',
      pan: json['pan']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      services: (json['services'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
      accountingEnabled: json['accountingEnabled'] as bool? ?? true,
      gstEnabled: json['gstEnabled'] as bool? ?? false,
      servicePeriods:
          (json['servicePeriods'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .map(ClientServicePeriod.fromJson)
              .toList(growable: false),
    );
  }
}

class ClientWorkspaceBundle {
  const ClientWorkspaceBundle({
    required this.clientId,
    required this.createdAt,
    this.client360Enabled = true,
    this.documentFolderEnabled = true,
    this.complianceWorkspaceEnabled = true,
    this.accountingWorkspaceEnabled = true,
    this.aiWorkspaceEnabled = true,
    this.notificationSettingsEnabled = true,
  });

  final String clientId;
  final DateTime createdAt;
  final bool client360Enabled;
  final bool documentFolderEnabled;
  final bool complianceWorkspaceEnabled;
  final bool accountingWorkspaceEnabled;
  final bool aiWorkspaceEnabled;
  final bool notificationSettingsEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientId': clientId,
    'createdAt': createdAt.toIso8601String(),
    'client360Enabled': client360Enabled,
    'documentFolderEnabled': documentFolderEnabled,
    'complianceWorkspaceEnabled': complianceWorkspaceEnabled,
    'accountingWorkspaceEnabled': accountingWorkspaceEnabled,
    'aiWorkspaceEnabled': aiWorkspaceEnabled,
    'notificationSettingsEnabled': notificationSettingsEnabled,
  };

  factory ClientWorkspaceBundle.fromJson(Map<String, dynamic> json) {
    return ClientWorkspaceBundle(
      clientId: json['clientId']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      client360Enabled: json['client360Enabled'] as bool? ?? true,
      documentFolderEnabled: json['documentFolderEnabled'] as bool? ?? true,
      complianceWorkspaceEnabled:
          json['complianceWorkspaceEnabled'] as bool? ?? true,
      accountingWorkspaceEnabled:
          json['accountingWorkspaceEnabled'] as bool? ?? true,
      aiWorkspaceEnabled: json['aiWorkspaceEnabled'] as bool? ?? true,
      notificationSettingsEnabled:
          json['notificationSettingsEnabled'] as bool? ?? true,
    );
  }
}

class AdminClientAccountingAccess {
  const AdminClientAccountingAccess({
    required this.clientId,
    required this.joinedOn,
    this.assignedAccountantId = '',
    this.assignedCaId = '',
    this.oldAccountingApproved = false,
    this.reportsPublished = false,
    this.auditEnabled = false,
    this.financialStatementsEnabled = false,
    this.reportSigningEnabled = false,
    this.bankProjectReportsEnabled = false,
    this.staffDelegationEnabled = false,
  });

  final String clientId;
  final DateTime joinedOn;
  final String assignedAccountantId;
  final String assignedCaId;
  final bool oldAccountingApproved;
  final bool reportsPublished;
  final bool auditEnabled;
  final bool financialStatementsEnabled;
  final bool reportSigningEnabled;
  final bool bankProjectReportsEnabled;
  final bool staffDelegationEnabled;

  bool get hasAssignedAccountant => assignedAccountantId.trim().isNotEmpty;
  bool get canViewOlderHistory =>
      hasAssignedAccountant && oldAccountingApproved && reportsPublished;
  DateTime get standardHistoryStartsOn =>
      DateTime(joinedOn.year, joinedOn.month - 3, 1);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientId': clientId,
    'joinedOn': joinedOn.toIso8601String(),
    'assignedAccountantId': assignedAccountantId,
    'assignedCaId': assignedCaId,
    'oldAccountingApproved': oldAccountingApproved,
    'reportsPublished': reportsPublished,
    'auditEnabled': auditEnabled,
    'financialStatementsEnabled': financialStatementsEnabled,
    'reportSigningEnabled': reportSigningEnabled,
    'bankProjectReportsEnabled': bankProjectReportsEnabled,
    'staffDelegationEnabled': staffDelegationEnabled,
  };

  factory AdminClientAccountingAccess.fromJson(Map<String, dynamic> json) {
    return AdminClientAccountingAccess(
      clientId: json['clientId']?.toString() ?? '',
      joinedOn:
          DateTime.tryParse(json['joinedOn']?.toString() ?? '') ??
          DateTime.now(),
      assignedAccountantId: json['assignedAccountantId']?.toString() ?? '',
      assignedCaId: json['assignedCaId']?.toString() ?? '',
      oldAccountingApproved: json['oldAccountingApproved'] as bool? ?? false,
      reportsPublished: json['reportsPublished'] as bool? ?? false,
      auditEnabled: json['auditEnabled'] as bool? ?? false,
      financialStatementsEnabled:
          json['financialStatementsEnabled'] as bool? ?? false,
      reportSigningEnabled: json['reportSigningEnabled'] as bool? ?? false,
      bankProjectReportsEnabled:
          json['bankProjectReportsEnabled'] as bool? ?? false,
      staffDelegationEnabled: json['staffDelegationEnabled'] as bool? ?? false,
    );
  }
}

class GeneratedCredentials {
  const GeneratedCredentials({
    required this.userId,
    required this.temporaryPassword,
  });

  final String userId;
  final String temporaryPassword;
}

class CredentialDeliveryResult {
  const CredentialDeliveryResult({
    required this.channel,
    required this.status,
    required this.message,
  });

  final CredentialChannel channel;
  final CredentialDeliveryStatus status;
  final String message;
}

class UserImportResult {
  const UserImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  final int created;
  final int updated;
  final int skipped;
  final List<String> errors;
}

class AdminClientImportIssues {
  const AdminClientImportIssues({
    required this.source,
    required this.occurredAt,
    required this.errors,
  });

  final String source;
  final DateTime occurredAt;
  final List<String> errors;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': source,
    'occurredAt': occurredAt.toIso8601String(),
    'errors': errors,
  };

  factory AdminClientImportIssues.fromJson(Map<String, dynamic> json) {
    return AdminClientImportIssues(
      source: json['source']?.toString() ?? 'Client import',
      occurredAt:
          DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      errors: (json['errors'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

class AdminUserService extends ChangeNotifier {
  AdminUserService({
    IntegrationHubService? integrationHub,
    ClientPortalAccessService? clientPortalAccess,
    ClientReferralService? referralService,
    SharedPreferences? preferences,
    Random? random,
    Dio? dio,
    bool? useRemoteApi,
  }) : _integrationHub = integrationHub,
       _clientPortalAccess = clientPortalAccess,
       _referralService = referralService,
       _preferences = preferences,
       _random = random ?? Random.secure(),
       _dio = dio ?? ApiClient.dio,
       _useRemoteApi = useRemoteApi ?? !ApiConstants.useMockApi {
    if (_integrationHub != null) {
      _startAutoSyncTicker();
    }
  }

  static const String storageKey = 'admin_managed_users_v1';
  static const String passwordStorageKey = 'admin_temporary_passwords_v1';
  static const String complianceStorageKey = 'admin_client_compliance_v1';
  static const String accountingAccessStorageKey =
      'admin_client_accounting_access_v1';
  static const String importIssuesStorageKey = 'admin_client_import_issues_v1';
  static const String workspaceStorageKey = 'admin_client_workspaces_v1';
  static const String tallySyncStorageKey = 'admin_client_tally_sync_v1';

  final IntegrationHubService? _integrationHub;
  final ClientPortalAccessService? _clientPortalAccess;
  final ClientReferralService? _referralService;
  final SharedPreferences? _preferences;
  final Random _random;
  final Dio _dio;
  final bool _useRemoteApi;
  final List<UserModel> _users = <UserModel>[];
  final Map<String, String> _temporaryPasswords = <String, String>{};
  final Map<String, String> _passwordHashes = <String, String>{};
  final Map<String, AdminClientComplianceRecord> _complianceRecords =
      <String, AdminClientComplianceRecord>{};
  final Map<String, AdminClientAccountingAccess> _accountingAccessRecords =
      <String, AdminClientAccountingAccess>{};
  final Map<String, ClientWorkspaceBundle> _workspaceBundles =
      <String, ClientWorkspaceBundle>{};
  final Map<String, TallySyncSettings> _tallySyncSettings =
      <String, TallySyncSettings>{};
  final Map<String, List<TallySyncHistoryEntry>> _tallySyncHistory =
      <String, List<TallySyncHistoryEntry>>{};
  final Set<String> _autoSyncInFlight = <String>{};

  bool _isLoaded = false;
  bool _autoSyncSweepRunning = false;
  Timer? _autoSyncTimer;
  AdminClientImportIssues? _importIssues;

  bool get isLoaded => _isLoaded;
  List<UserModel> get users => List<UserModel>.unmodifiable(_users);
  AdminClientImportIssues? get importIssues => _importIssues;

  bool containsUser(String userId) => _users.any((user) => user.id == userId);

  bool canManageAccountAccess(String userId) {
    final user = _users.where((item) => item.id == userId).firstOrNull;
    return user?.role.isClient ?? false;
  }

  AdminClientComplianceRecord complianceFor(String userId) {
    return _complianceRecords[userId] ??
        AdminClientComplianceRecord(userId: userId);
  }

  AdminClientAccountingAccess accountingAccessFor(String clientId) {
    final stored = _accountingAccessRecords[clientId];
    if (stored != null) return stored;
    final user = _users.where((item) => item.id == clientId).firstOrNull;
    return AdminClientAccountingAccess(
      clientId: clientId,
      joinedOn: user?.createdAt ?? DateTime.now(),
    );
  }

  ClientWorkspaceBundle workspaceFor(String clientId) {
    return _workspaceBundles[clientId] ??
        ClientWorkspaceBundle(clientId: clientId, createdAt: DateTime.now());
  }

  TallySyncSettings tallySyncFor(String clientId) {
    return _tallySyncSettings[clientId] ??
        TallySyncSettings(clientId: clientId);
  }

  List<TallySyncHistoryEntry> tallySyncHistoryFor(String clientId) =>
      List<TallySyncHistoryEntry>.unmodifiable(
        _tallySyncHistory[clientId] ?? const <TallySyncHistoryEntry>[],
      );

  Future<void> loadTallySyncHistory(String clientId) async {
    if (_integrationHub == null) return;
    final response = await _integrationHub.execute(
      adapterId: 'tally',
      action: 'history',
      payload: <String, dynamic>{'clientId': clientId, 'limit': 25},
    );
    final data = response['data'];
    if (data is! List) return;
    _tallySyncHistory[clientId] = data
        .whereType<Map>()
        .map(
          (entry) =>
              TallySyncHistoryEntry.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);
    notifyListeners();
  }

  List<UserModel> get accountantAndCaUsers => _users
      .where(
        (user) =>
            user.isActive &&
            (user.role == UserRole.accountant ||
                user.role == UserRole.firmAdmin ||
                user.role == UserRole.superAdmin),
      )
      .toList(growable: false);

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final usersJson = preferences.getString(storageKey);
    final passwordsJson = preferences.getString(passwordStorageKey);
    final complianceJson = preferences.getString(complianceStorageKey);
    final accountingAccessJson = preferences.getString(
      accountingAccessStorageKey,
    );
    final importIssuesJson = preferences.getString(importIssuesStorageKey);
    final workspacesJson = preferences.getString(workspaceStorageKey);
    final tallySyncJson = preferences.getString(tallySyncStorageKey);

    _users
      ..clear()
      ..addAll(_decodeUsers(usersJson));
    _passwordHashes
      ..clear()
      ..addAll(decodePasswordHashes(passwordsJson));
    var migratedOrigins = false;
    for (var index = 0; index < _users.length; index++) {
      final user = _users[index];
      if (user.accountOrigin == AccountOrigin.legacyUnknown) {
        _users[index] = user.copyWith(
          accountOrigin: _passwordHashes.containsKey(user.id)
              ? AccountOrigin.adminOnboarded
              : AccountOrigin.selfRegistered,
        );
        migratedOrigins = true;
        continue;
      }
      final isPendingNonClientRegistration =
          user.accountOrigin == AccountOrigin.selfRegistered &&
          !user.role.isClient &&
          !user.isActive &&
          user.clientStatus == ClientAccountStatus.pendingApproval &&
          user.loginStatus == ClientLoginStatus.loginNotCreated &&
          _passwordHashes.containsKey(user.id);
      if (isPendingNonClientRegistration) {
        _users[index] = user.copyWith(
          isActive: true,
          clientStatus: ClientAccountStatus.active,
          loginStatus: ClientLoginStatus.active,
        );
        migratedOrigins = true;
      }
    }
    _complianceRecords
      ..clear()
      ..addAll(_decodeComplianceRecords(complianceJson));
    if (_useRemoteApi) await _mergeRemoteClients();
    _accountingAccessRecords
      ..clear()
      ..addAll(_decodeAccountingAccessRecords(accountingAccessJson));
    _workspaceBundles
      ..clear()
      ..addAll(_decodeWorkspaceBundles(workspacesJson));
    _tallySyncSettings
      ..clear()
      ..addAll(_decodeTallySyncSettings(tallySyncJson));
    var provisionedWorkspaces = false;
    for (final user in _users.where((item) => item.role.isClient)) {
      if (_workspaceBundles.containsKey(user.id)) continue;
      _workspaceBundles[user.id] = ClientWorkspaceBundle(
        clientId: user.id,
        createdAt: user.createdAt,
      );
      provisionedWorkspaces = true;
    }
    _importIssues = _decodeImportIssues(importIssuesJson);
    _isLoaded = true;
    if (migratedOrigins || provisionedWorkspaces) await _save();
    notifyListeners();
    unawaited(_runDueAutoSyncs());
  }

  void _startAutoSyncTicker() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_runDueAutoSyncs());
    });
  }

  Future<void> _runDueAutoSyncs() async {
    if (_autoSyncSweepRunning || !_isLoaded || _integrationHub == null) return;

    _autoSyncSweepRunning = true;
    try {
      final dueClientIds = _tallySyncSettings.entries
          .where(
            (entry) =>
                entry.value.isDue && !_autoSyncInFlight.contains(entry.key),
          )
          .map((entry) => entry.key)
          .toList(growable: false);

      for (final clientId in dueClientIds) {
        _autoSyncInFlight.add(clientId);
        try {
          await runTallySync(clientId, mode: 'automatic');
          await loadTallySyncHistory(clientId);
        } catch (_) {
          // runTallySync already persists failed state with error details.
        } finally {
          _autoSyncInFlight.remove(clientId);
        }
      }
    } finally {
      _autoSyncSweepRunning = false;
    }
  }

  Future<void> _mergeRemoteClients() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.adminClients,
      );
      final clients = response.data?['data'] is Map
          ? (response.data!['data'] as Map)['clients']
          : null;
      if (clients is! List) return;

      final remoteClients = clients
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
      _users.removeWhere((user) => user.role.isClient);
      for (final entry in remoteClients) {
        final user = UserModel.fromJson(entry);
        _users.add(user);
        final gstin = entry['gstin']?.toString().trim() ?? '';
        _complianceRecords[user.id] = AdminClientComplianceRecord(
          userId: user.id,
          gstRegistrationType: gstin.isEmpty
              ? GstRegistrationType.unregistered
              : GstRegistrationType.regular,
          gstin: gstin,
          pan: entry['pan']?.toString().trim() ?? '',
          state: entry['state']?.toString().trim() ?? '',
          city: entry['city']?.toString().trim() ?? '',
        );
      }
    } on DioException catch (error) {
      debugPrint('Unable to refresh admin clients: ${error.message}');
    }
  }

  Future<GeneratedCredentials> createUser({
    required String name,
    required String email,
    required String mobile,
    required String firmId,
    required String firmName,
    UserRole role = UserRole.client,
    bool? isActive,
    GstRegistrationType gstRegistrationType = GstRegistrationType.unregistered,
    String gstin = '',
    String pan = '',
    String state = '',
    String city = '',
    String pincode = '',
    List<String> services = const <String>[],
    bool accountingEnabled = true,
    ClientAccountingMode accountingMode = ClientAccountingMode.accountingOnly,
    DateTime? serviceEffectiveFrom,
    bool gstEnabled = false,
    AccountOrigin accountOrigin = AccountOrigin.adminOnboarded,
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    _validateIdentity(name: name, email: email, mobile: mobile);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedMobile = _normalizeMobile(mobile);
    final normalizedGstin = _validateCompliance(
      gstRegistrationType: gstRegistrationType,
      gstin: gstin,
    );
    _ensureUnique(normalizedEmail, normalizedMobile);

    final credentials = _generateCredentials(name);
    final isClient = role.isClient;
    final effectiveActive = isClient ? false : isActive ?? true;
    final user = UserModel(
      id: credentials.userId,
      name: name.trim(),
      email: normalizedEmail,
      mobile: normalizedMobile,
      role: role,
      firmId: firmId.trim(),
      firmName: firmName.trim().isEmpty ? 'Chirag Associates' : firmName.trim(),
      isActive: effectiveActive,
      accountOrigin: accountOrigin,
      clientStatus: isClient
          ? ClientAccountStatus.notOnboarded
          : ClientAccountStatus.active,
      loginStatus: isClient
          ? ClientLoginStatus.loginNotCreated
          : ClientLoginStatus.active,
      mustChangePassword: false,
      createdAt: DateTime.now(),
    );

    _users.add(user);
    _complianceRecords[user.id] = AdminClientComplianceRecord(
      userId: user.id,
      gstRegistrationType: gstRegistrationType,
      gstin: normalizedGstin,
      pan: pan.trim().toUpperCase(),
      state: state.trim(),
      city: city.trim(),
      pincode: pincode.trim(),
      services: List<String>.unmodifiable(services),
      accountingEnabled: accountingEnabled,
      gstEnabled:
          gstEnabled || gstRegistrationType != GstRegistrationType.unregistered,
      servicePeriods: <ClientServicePeriod>[
        ClientServicePeriod(
          effectiveFrom: _dateOnly(serviceEffectiveFrom ?? DateTime.now()),
          accountingMode: accountingMode,
          gstRegistrationType: gstRegistrationType,
        ),
      ],
    );
    _accountingAccessRecords[user.id] = AdminClientAccountingAccess(
      clientId: user.id,
      joinedOn: user.createdAt,
    );
    if (isClient) {
      _workspaceBundles[user.id] = ClientWorkspaceBundle(
        clientId: user.id,
        createdAt: user.createdAt,
      );
    }
    if (!isClient) {
      _temporaryPasswords[user.id] = credentials.temporaryPassword;
      _passwordHashes[user.id] = hashPassword(credentials.temporaryPassword);
    }
    await _save();
    if (isClient) {
      await _clientPortalAccess?.syncAssignedServices(user.id, services);
    }
    _publishAudit(
      eventType: EventTypes.adminUserLifecycleChanged,
      user: user,
      action: AdminAuditAction.created,
      actorUserId: actorUserId,
      actorRole: actorRole,
      after: user.toJson(),
    );
    notifyListeners();
    return isClient
        ? GeneratedCredentials(
            userId: credentials.userId,
            temporaryPassword: '',
          )
        : credentials;
  }

  Future<UserModel> createSelfRegisteredUser({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required String firmName,
    UserRole role = UserRole.client,
    GstRegistrationType gstRegistrationType = GstRegistrationType.unregistered,
    String gstin = '',
    String pan = '',
    String state = '',
    String city = '',
  }) async {
    _validateIdentity(name: name, email: email, mobile: mobile);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedMobile = _normalizeMobile(mobile);
    _ensureUnique(normalizedEmail, normalizedMobile);

    final userId = _generateCredentials(name).userId;
    final isClient = role.isClient;
    final user = UserModel(
      id: userId,
      name: name.trim(),
      email: normalizedEmail,
      mobile: normalizedMobile,
      role: role,
      firmId: 'self-$userId',
      firmName: firmName.trim().isEmpty ? name.trim() : firmName.trim(),
      isActive: !isClient,
      accountOrigin: AccountOrigin.selfRegistered,
      clientStatus: isClient
          ? ClientAccountStatus.pendingApproval
          : ClientAccountStatus.active,
      loginStatus: isClient
          ? ClientLoginStatus.loginNotCreated
          : ClientLoginStatus.active,
      createdAt: DateTime.now(),
    );
    _users.add(user);
    _passwordHashes[user.id] = hashPassword(password);
    _complianceRecords[user.id] = AdminClientComplianceRecord(
      userId: user.id,
      gstRegistrationType: gstRegistrationType,
      gstin: _validateCompliance(
        gstRegistrationType: gstRegistrationType,
        gstin: gstin,
      ),
      pan: pan.trim().toUpperCase(),
      state: state.trim(),
      city: city.trim(),
      gstEnabled: gstRegistrationType != GstRegistrationType.unregistered,
    );
    _accountingAccessRecords[user.id] = AdminClientAccountingAccess(
      clientId: user.id,
      joinedOn: user.createdAt,
    );
    _workspaceBundles[user.id] = ClientWorkspaceBundle(
      clientId: user.id,
      createdAt: user.createdAt,
    );
    await _save();
    notifyListeners();
    return user;
  }

  Future<void> updateUser(
    String userId, {
    required String name,
    required String email,
    required String mobile,
    required String firmName,
    required UserRole role,
    GstRegistrationType? gstRegistrationType,
    String? gstin,
    bool? accountingEnabled,
    bool? gstEnabled,
    String? pan,
    String? state,
    String? city,
    String? pincode,
    List<String>? services,
    ClientAccountingMode? accountingMode,
    DateTime? serviceEffectiveFrom,
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    final index = _indexOf(userId);
    _validateIdentity(name: name, email: email, mobile: mobile);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedMobile = _normalizeMobile(mobile);
    final currentCompliance = complianceFor(userId);
    final nextRegistrationType =
        gstRegistrationType ?? currentCompliance.gstRegistrationType;
    final normalizedGstin = _validateCompliance(
      gstRegistrationType: nextRegistrationType,
      gstin: gstin ?? currentCompliance.gstin,
    );
    _ensureUnique(normalizedEmail, normalizedMobile, excludingUserId: userId);
    final currentPeriod = currentCompliance.servicePeriodOn(DateTime.now());
    final nextAccountingMode = accountingMode ?? currentPeriod.accountingMode;
    final servicePeriods = <ClientServicePeriod>[
      ...currentCompliance.servicePeriods,
    ];
    if (servicePeriods.isEmpty ||
        nextAccountingMode != currentPeriod.accountingMode ||
        nextRegistrationType != currentPeriod.gstRegistrationType) {
      final effectiveFrom = _dateOnly(serviceEffectiveFrom ?? DateTime.now());
      servicePeriods.removeWhere(
        (period) => _dateOnly(period.effectiveFrom) == effectiveFrom,
      );
      servicePeriods.add(
        ClientServicePeriod(
          effectiveFrom: effectiveFrom,
          accountingMode: nextAccountingMode,
          gstRegistrationType: nextRegistrationType,
        ),
      );
      servicePeriods.sort(
        (left, right) => left.effectiveFrom.compareTo(right.effectiveFrom),
      );
    }

    final before = _users[index];
    final updated = before.copyWith(
      name: name.trim(),
      email: normalizedEmail,
      mobile: normalizedMobile,
      firmName: firmName.trim(),
      role: role,
    );
    _users[index] = updated;
    _complianceRecords[userId] = AdminClientComplianceRecord(
      userId: userId,
      gstRegistrationType: nextRegistrationType,
      gstin: normalizedGstin,
      pan: pan?.trim().toUpperCase() ?? currentCompliance.pan,
      state: state?.trim() ?? currentCompliance.state,
      city: city?.trim() ?? currentCompliance.city,
      pincode: pincode?.trim() ?? currentCompliance.pincode,
      services: services ?? currentCompliance.services,
      accountingEnabled:
          accountingEnabled ?? currentCompliance.accountingEnabled,
      gstEnabled: gstEnabled ?? currentCompliance.gstEnabled,
      servicePeriods: List<ClientServicePeriod>.unmodifiable(servicePeriods),
    );
    await _save();
    if (updated.role.isClient) {
      await _clientPortalAccess?.syncAssignedServices(
        userId,
        services ?? currentCompliance.services,
      );
    }
    _publishAudit(
      eventType: EventTypes.adminUserLifecycleChanged,
      user: updated,
      action: AdminAuditAction.updated,
      actorUserId: actorUserId,
      actorRole: actorRole,
      before: before.toJson(),
      after: updated.toJson(),
    );
    notifyListeners();
  }

  Future<UserModel> syncProfile(
    String userId, {
    required String name,
    required String email,
    required String mobile,
    String? firmName,
  }) async {
    final index = _indexOf(userId);
    final current = _users[index];
    await updateUser(
      userId,
      name: name,
      email: email,
      mobile: mobile,
      firmName: firmName ?? current.firmName,
      role: current.role,
      actorUserId: userId,
      actorRole: current.role.name,
    );
    return _users[index];
  }

  Future<void> updatePassword(String userId, String password) async {
    final index = _indexOf(userId);
    _passwordHashes[userId] = hashPassword(password);
    _temporaryPasswords.remove(userId);
    _users[index] = _users[index].copyWith(
      mustChangePassword: false,
      loginStatus: ClientLoginStatus.passwordChanged,
    );
    await _save();
    notifyListeners();
  }

  Future<Map<String, GeneratedCredentials>> onboardClients(
    Iterable<String> userIds, {
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    final credentials = <String, GeneratedCredentials>{};
    for (final userId in userIds.toSet()) {
      final index = _indexOf(userId);
      final before = _users[index];
      if (!before.role.isClient) {
        throw const FormatException('Only client accounts can be onboarded.');
      }
      if (before.clientStatus == ClientAccountStatus.archived) {
        throw FormatException(
          '${before.name} is archived and cannot be onboarded.',
        );
      }
      if (before.onboardedAt != null) {
        throw FormatException('${before.name} is already onboarded.');
      }

      final generated = GeneratedCredentials(
        userId: before.id,
        temporaryPassword: _generatePassword(),
      );
      _temporaryPasswords[before.id] = generated.temporaryPassword;
      _passwordHashes[before.id] = hashPassword(generated.temporaryPassword);
      final updated = before.copyWith(
        isActive: true,
        clientStatus: ClientAccountStatus.onboarded,
        loginStatus: ClientLoginStatus.neverLoggedIn,
        mustChangePassword: true,
        termsAccepted: false,
        onboardedAt: DateTime.now(),
        clearCredentialsSentAt: true,
        clearLastLoginAt: true,
      );
      _users[index] = updated;
      credentials[userId] = generated;
      await _referralService?.rewardOnboarding(
        onboardedClientId: updated.id,
        mobile: updated.mobile,
        gstin: complianceFor(updated.id).gstin,
      );
      _publishAudit(
        eventType: EventTypes.adminUserLifecycleChanged,
        user: updated,
        action: AdminAuditAction.activated,
        actorUserId: actorUserId,
        actorRole: actorRole,
        before: before.toJson(),
        after: updated.toJson(),
        metadata: const <String, dynamic>{
          'onboardingCompleted': true,
          'temporaryPasswordGenerated': true,
        },
      );
    }
    await _save();
    notifyListeners();
    return Map<String, GeneratedCredentials>.unmodifiable(credentials);
  }

  Future<void> acceptTerms(String userId) async {
    final index = _indexOf(userId);
    _users[index] = _users[index].copyWith(termsAccepted: true);
    await _save();
    notifyListeners();
  }

  Future<UserModel> recordSuccessfulLogin(String userId) async {
    final index = _indexOf(userId);
    final current = _users[index];
    final updated = current.copyWith(
      lastLoginAt: DateTime.now(),
      loginStatus: current.mustChangePassword
          ? ClientLoginStatus.active
          : ClientLoginStatus.passwordChanged,
      clientStatus: current.clientStatus == ClientAccountStatus.onboarded
          ? ClientAccountStatus.active
          : current.clientStatus,
    );
    _users[index] = updated;
    await _save();
    notifyListeners();
    return updated;
  }

  Future<void> setActive(
    String userId,
    bool isActive, {
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    if (!canManageAccountAccess(userId)) {
      throw const FormatException(
        'Self-registered client access is managed by the client.',
      );
    }
    final index = _indexOf(userId);
    final before = _users[index];
    if (before.role.isClient && before.onboardedAt == null) {
      throw const FormatException(
        'Onboard the client before changing portal access.',
      );
    }
    final updated = before.copyWith(isActive: isActive);
    final statusUpdated = updated.copyWith(
      clientStatus: isActive
          ? ClientAccountStatus.active
          : ClientAccountStatus.inactive,
      loginStatus: isActive ? updated.loginStatus : ClientLoginStatus.locked,
    );
    _users[index] = statusUpdated;
    await _save();
    _publishAudit(
      eventType: EventTypes.adminUserLifecycleChanged,
      user: statusUpdated,
      action: isActive
          ? AdminAuditAction.activated
          : AdminAuditAction.deactivated,
      actorUserId: actorUserId,
      actorRole: actorRole,
      before: before.toJson(),
      after: statusUpdated.toJson(),
    );
    notifyListeners();
  }

  Future<void> configureClientAccountingAccess(
    String clientId, {
    required String assignedAccountantId,
    String assignedCaId = '',
    required bool oldAccountingApproved,
    required bool reportsPublished,
    bool auditEnabled = false,
    bool financialStatementsEnabled = false,
    bool reportSigningEnabled = false,
    bool bankProjectReportsEnabled = false,
    bool staffDelegationEnabled = false,
  }) async {
    final client = _users[_indexOf(clientId)];
    if (!client.role.isClient) {
      throw const FormatException(
        'Accounting access can be set for clients only.',
      );
    }
    final accountantId = assignedAccountantId.trim();
    final caId = assignedCaId.trim();
    if (accountantId.isNotEmpty) {
      final accountant = _users[_indexOf(accountantId)];
      if (!accountantAndCaUsers.any((user) => user.id == accountant.id)) {
        throw const FormatException(
          'Select an active Accountant or CA-authorized user.',
        );
      }
    }
    if ((oldAccountingApproved || reportsPublished) && accountantId.isEmpty) {
      throw const FormatException(
        'Assign an Accountant or CA before approving old accounting or publishing reports.',
      );
    }
    if (caId.isNotEmpty) {
      final ca = _users[_indexOf(caId)];
      if (!ca.isActive ||
          (ca.role != UserRole.firmAdmin && ca.role != UserRole.checker)) {
        throw const FormatException('Select an active CA or Auditor.');
      }
    }
    if (caId.isEmpty &&
        (auditEnabled ||
            financialStatementsEnabled ||
            reportSigningEnabled ||
            bankProjectReportsEnabled ||
            staffDelegationEnabled)) {
      throw const FormatException(
        'Assign a CA or Auditor before activating CA work options.',
      );
    }
    if (reportsPublished && !oldAccountingApproved) {
      throw const FormatException(
        'Approve old accounting before publishing historical reports.',
      );
    }

    final current = accountingAccessFor(clientId);
    _accountingAccessRecords[clientId] = AdminClientAccountingAccess(
      clientId: clientId,
      joinedOn: current.joinedOn,
      assignedAccountantId: accountantId,
      assignedCaId: caId,
      oldAccountingApproved: oldAccountingApproved,
      reportsPublished: reportsPublished,
      auditEnabled: auditEnabled,
      financialStatementsEnabled: financialStatementsEnabled,
      reportSigningEnabled: reportSigningEnabled,
      bankProjectReportsEnabled: bankProjectReportsEnabled,
      staffDelegationEnabled: staffDelegationEnabled,
    );
    await _save();
    notifyListeners();
  }

  Future<void> configureTallySync(TallySyncSettings settings) async {
    final client = _users[_indexOf(settings.clientId)];
    if (!client.role.isClient) {
      throw const FormatException(
        'Tally sync can be configured for clients only.',
      );
    }
    final endpoint = Uri.tryParse(settings.endpoint.trim());
    if (endpoint == null ||
        !endpoint.hasScheme ||
        (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
      throw const FormatException('Enter a valid Tally HTTP endpoint.');
    }
    if (settings.enabled && settings.selectedCompanyNames.isEmpty) {
      throw const FormatException('Select at least one Tally company.');
    }
    if (!const <int>{5, 15, 30, 60}.contains(settings.intervalMinutes)) {
      throw const FormatException(
        'Select a supported automatic sync interval.',
      );
    }
    if (!settings.syncMasters &&
        !settings.syncVouchers &&
        !settings.syncInventory) {
      throw const FormatException(
        'Select at least one Tally data group to sync.',
      );
    }
    if ((settings.fromDate == null) != (settings.toDate == null)) {
      throw const FormatException('Select both From Date and To Date.');
    }
    if (settings.fromDate != null &&
        settings.toDate!.isBefore(settings.fromDate!)) {
      throw const FormatException('To Date cannot be before From Date.');
    }

    final automaticAllowed =
        settings.autoSyncEnabled && settings.hasCompletedInitialSync;
    final companyNames = settings.selectedCompanyNames;
    _tallySyncSettings[settings.clientId] = settings.copyWith(
      endpoint: endpoint.toString(),
      companyName: companyNames.isEmpty ? '' : companyNames.first,
      companyNames: companyNames,
      autoSyncEnabled: automaticAllowed,
      status: settings.enabled
          ? settings.hasCompletedInitialSync
                ? TallySyncStatus.success
                : TallySyncStatus.ready
          : TallySyncStatus.notConnected,
      lastError: '',
    );
    await _save();
    notifyListeners();
  }

  Future<TallySyncSettings> runTallySync(
    String clientId, {
    bool enableAutomaticAfterSuccess = true,
    TallySyncDirection? directionOverride,
    String mode = 'manual',
  }) async {
    final current = tallySyncFor(clientId);
    if (!current.enabled) {
      throw const FormatException('Enable and save Tally sync before syncing.');
    }
    if (_integrationHub == null) {
      throw StateError('Tally integration is not configured.');
    }

    _tallySyncSettings[clientId] = current.copyWith(
      status: TallySyncStatus.syncing,
      lastError: '',
    );
    notifyListeners();

    try {
      final response = await _integrationHub.execute(
        adapterId: 'tally',
        action: 'sync',
        payload: <String, dynamic>{
          'clientId': clientId,
          'endpoint': current.endpoint,
          'companyName': current.companyName,
          'companyNames': current.selectedCompanyNames,
          'direction': (directionOverride ?? current.direction).name,
          'mode': mode,
          'dateRange': <String, String?>{
            'from': current.fromDate?.toIso8601String(),
            'to': current.toDate?.toIso8601String(),
          },
          'dataGroups': <String, bool>{
            'masters': current.syncMasters,
            'vouchers': current.syncVouchers,
            'inventory': current.syncInventory,
          },
          'modules': current.effectiveModuleDirections.map(
            (module, direction) => MapEntry(module, direction.name),
          ),
          'conflictRules': <String, dynamic>{
            'masterDuplicate': current.masterConflictPolicy.name,
            'voucherDuplicate': current.voucherConflictPolicy.name,
            'overwriteMode': 'tallyAlter',
            'voucherIdentity': 'remoteIdOrVoucherTypeNumberDate',
            'masterIdentity': 'guidOrNormalizedName',
            'allowDeletion': current.allowTallyDeletions,
          },
        },
      );
      if (response['accepted'] == false) {
        throw StateError(
          response['message']?.toString() ?? 'Tally rejected the sync.',
        );
      }
      final completed = current.copyWith(
        hasCompletedInitialSync: true,
        autoSyncEnabled: enableAutomaticAfterSuccess,
        status: TallySyncStatus.success,
        lastSyncAt: DateTime.now(),
        lastError: '',
      );
      _tallySyncSettings[clientId] = completed;
      await _save();
      notifyListeners();
      return completed;
    } catch (error) {
      _tallySyncSettings[clientId] = current.copyWith(
        status: TallySyncStatus.failed,
        lastError: error.toString(),
      );
      await _save();
      notifyListeners();
      rethrow;
    }
  }

  Future<TallySyncSettings> testTallyConnection(String clientId) async {
    final current = tallySyncFor(clientId);
    if (!current.enabled) {
      throw const FormatException(
        'Enable and save Tally sync before testing the connection.',
      );
    }
    if (_integrationHub == null) {
      throw StateError('Tally integration is not configured.');
    }

    try {
      final response = await _integrationHub.execute(
        adapterId: 'tally',
        action: 'testConnection',
        payload: <String, dynamic>{
          'endpoint': current.endpoint,
          'companyName': current.companyName,
          'companyNames': current.selectedCompanyNames,
        },
      );
      if (response['connected'] != true) {
        throw StateError(
          response['message']?.toString() ?? 'Tally connection failed.',
        );
      }
      final connected = current.copyWith(
        status: current.hasCompletedInitialSync
            ? TallySyncStatus.success
            : TallySyncStatus.ready,
        lastError: '',
      );
      _tallySyncSettings[clientId] = connected;
      await _save();
      notifyListeners();
      return connected;
    } catch (error) {
      final failed = current.copyWith(
        status: TallySyncStatus.failed,
        lastError: error.toString(),
      );
      _tallySyncSettings[clientId] = failed;
      await _save();
      notifyListeners();
      rethrow;
    }
  }

  Future<TallySyncSettings> runInitialTallyImport(String clientId) {
    return runTallySync(
      clientId,
      enableAutomaticAfterSuccess: false,
      directionOverride: TallySyncDirection.tallyToChirag,
      mode: 'initialImport',
    );
  }

  Future<void> archiveClients(
    Iterable<String> userIds, {
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    for (final userId in userIds.toSet()) {
      final index = _indexOf(userId);
      final before = _users[index];
      if (!before.role.isClient) {
        throw const FormatException('Only client accounts can be archived.');
      }
      final archived = before.copyWith(
        isActive: false,
        clientStatus: ClientAccountStatus.archived,
        loginStatus: ClientLoginStatus.locked,
      );
      _users[index] = archived;
      _temporaryPasswords.remove(userId);
      _publishAudit(
        eventType: EventTypes.adminUserLifecycleChanged,
        user: archived,
        action: AdminAuditAction.archived,
        actorUserId: actorUserId,
        actorRole: actorRole,
        before: before.toJson(),
        after: archived.toJson(),
      );
    }
    await _save();
    notifyListeners();
  }

  Future<void> deleteClients(
    Iterable<String> userIds, {
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    for (final userId in userIds.toSet()) {
      final index = _indexOf(userId);
      final user = _users[index];
      if (!user.role.isClient) {
        throw const FormatException('Only client accounts can be deleted.');
      }
      _publishAudit(
        eventType: EventTypes.adminUserLifecycleChanged,
        user: user,
        action: AdminAuditAction.revoked,
        actorUserId: actorUserId,
        actorRole: actorRole,
        before: user.toJson(),
        metadata: const <String, dynamic>{'permanentlyDeleted': true},
      );
      _users.removeAt(index);
      _temporaryPasswords.remove(userId);
      _passwordHashes.remove(userId);
      _complianceRecords.remove(userId);
      _accountingAccessRecords.remove(userId);
      _workspaceBundles.remove(userId);
      _tallySyncSettings.remove(userId);
    }
    await _save();
    notifyListeners();
  }

  String exportClientsCsv(Iterable<String> userIds) {
    final selectedIds = userIds.toSet();
    final rows = <List<String>>[
      const <String>[
        'client_id',
        'client_name',
        'company_name',
        'mobile',
        'email',
        'account_status',
        'login_status',
        'gstin',
        'pan',
        'state',
        'city',
        'services',
        'assigned_accountant_id',
        'assigned_ca_id',
      ],
      for (final user in _users)
        if (selectedIds.isEmpty || selectedIds.contains(user.id))
          <String>[
            user.id,
            user.name,
            user.firmName,
            user.mobile,
            user.email,
            user.clientStatus.name,
            user.loginStatus.name,
            complianceFor(user.id).gstin,
            complianceFor(user.id).pan,
            complianceFor(user.id).state,
            complianceFor(user.id).city,
            complianceFor(user.id).services.join('|'),
            accountingAccessFor(user.id).assignedAccountantId,
            accountingAccessFor(user.id).assignedCaId,
          ],
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  Future<GeneratedCredentials> regenerateCredentials(
    String userId, {
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    if (!canManageAccountAccess(userId)) {
      throw const FormatException(
        'Temporary passwords are not available for self-registered clients.',
      );
    }
    final user = _users[_indexOf(userId)];
    if (!user.isActive ||
        user.clientStatus == ClientAccountStatus.pendingApproval ||
        user.clientStatus == ClientAccountStatus.notOnboarded ||
        user.clientStatus == ClientAccountStatus.draft) {
      throw const FormatException(
        'Onboard the client before resetting login credentials.',
      );
    }
    final credentials = GeneratedCredentials(
      userId: user.id,
      temporaryPassword: _generatePassword(),
    );
    _temporaryPasswords[user.id] = credentials.temporaryPassword;
    _passwordHashes[user.id] = hashPassword(credentials.temporaryPassword);
    _users[_indexOf(userId)] = user.copyWith(
      mustChangePassword: true,
      loginStatus: ClientLoginStatus.neverLoggedIn,
    );
    await _save();
    _publishAudit(
      eventType: EventTypes.adminUserLifecycleChanged,
      user: user,
      action: AdminAuditAction.passwordReset,
      actorUserId: actorUserId,
      actorRole: actorRole,
      metadata: const <String, dynamic>{'temporaryPasswordGenerated': true},
    );
    notifyListeners();
    return credentials;
  }

  GeneratedCredentials? credentialsFor(String userId) {
    final password = _temporaryPasswords[userId];
    if (password == null) return null;
    return GeneratedCredentials(userId: userId, temporaryPassword: password);
  }

  Future<UserImportResult> importClientsCsv(
    String csv, {
    String source = 'Client CSV import',
    String defaultFirmId = 'chirag-associates',
    String defaultFirmName = 'Chirag Associates',
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    return importClientsRows(
      _parseCsv(csv),
      source: source,
      defaultFirmId: defaultFirmId,
      defaultFirmName: defaultFirmName,
      actorUserId: actorUserId,
      actorRole: actorRole,
    );
  }

  Future<UserImportResult> importClientsRows(
    List<List<String>> rows, {
    String source = 'Client list import',
    String defaultFirmId = 'chirag-associates',
    String defaultFirmName = 'Chirag Associates',
    String actorUserId = 'system',
    String actorRole = 'superAdmin',
  }) async {
    if (rows.isEmpty) {
      const result = UserImportResult(
        created: 0,
        updated: 0,
        skipped: 0,
        errors: <String>['The import file is empty.'],
      );
      await recordImportFailure(source, result.errors.first);
      return result;
    }

    final headers = rows.first
        .map((value) => value.trim().toLowerCase().replaceAll(' ', '_'))
        .toList(growable: false);
    const clientNameHeaders = <String>{'name', 'client_name', 'full_name'};
    if (!headers.any(clientNameHeaders.contains)) {
      final message = headers.contains('ledger_name')
          ? 'This is a debtor/ledger template, not an Admin Client List template. Import it from Client Portal > Data Exchange > Ledgers, or use chirag_associates_client_user_import_template.csv here.'
          : 'The import file needs a client_name, name, or full_name column. Use chirag_associates_client_user_import_template.csv for Admin Client List imports.';
      final result = UserImportResult(
        created: 0,
        updated: 0,
        skipped: rows
            .skip(1)
            .where((row) => row.any((value) => value.trim().isNotEmpty))
            .length,
        errors: <String>[message],
      );
      await recordImportFailure(source, message);
      return result;
    }
    int created = 0;
    int updated = 0;
    int skipped = 0;
    final errors = <String>[];

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final values = rows[rowIndex];
      if (values.every((value) => value.trim().isEmpty)) continue;
      final row = <String, String>{};
      for (var column = 0; column < headers.length; column++) {
        row[headers[column]] = column < values.length
            ? values[column].trim()
            : '';
      }

      final name = _firstValue(row, <String>[
        'name',
        'client_name',
        'full_name',
      ]);
      final email = _firstValue(row, <String>['email', 'email_id']);
      final mobile = _firstValue(row, <String>[
        'mobile',
        'phone',
        'mobile_number',
      ]);
      final company = _firstValue(row, <String>[
        'company',
        'company_name',
        'firm_name',
        'business_name',
      ]);
      final activeValue = _firstValue(row, <String>[
        'active',
        'is_active',
        'status',
      ]);
      final requestedActive = !_isDisabledValue(activeValue);
      const registrationKeys = <String>[
        'gst_registration_type',
        'dealer_type',
        'taxpayer_type',
      ];
      const gstinKeys = <String>['gstin', 'gst_number'];
      const accountingKeys = <String>['accounting', 'accounting_service'];
      const gstServiceKeys = <String>['gst', 'gst_service'];
      final hasRegistrationType = registrationKeys.any(row.containsKey);
      final hasGstin = gstinKeys.any(row.containsKey);
      final hasAccountingService = accountingKeys.any(row.containsKey);
      final hasGstService = gstServiceKeys.any(row.containsKey);
      final registrationType = _registrationTypeFrom(
        _firstValue(row, registrationKeys),
      );
      final gstin = _firstValue(row, gstinKeys);
      final pan = _firstValue(row, const <String>['pan', 'pan_number']);
      final state = _firstValue(row, const <String>['state', 'gst_state']);
      final city = _firstValue(row, const <String>['city']);
      final services =
          _firstValue(row, const <String>['services', 'service_type'])
              .split(RegExp(r'[|;]'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
      final accountingEnabled = _serviceEnabled(
        _firstValue(row, accountingKeys),
        fallback: true,
      );
      final gstEnabled = _serviceEnabled(
        _firstValue(row, gstServiceKeys),
        fallback: registrationType != GstRegistrationType.unregistered,
      );

      try {
        _validateIdentity(name: name, email: email, mobile: mobile);
        final existing = _findByIdentity(email, mobile);
        if (existing == null) {
          await createUser(
            name: name,
            email: email,
            mobile: mobile,
            firmId: defaultFirmId,
            firmName: company.isEmpty ? defaultFirmName : company,
            isActive: false,
            gstRegistrationType: registrationType,
            gstin: gstin,
            pan: pan,
            state: state,
            city: city,
            services: services,
            accountingEnabled: accountingEnabled,
            gstEnabled: gstEnabled,
            accountOrigin: AccountOrigin.imported,
            actorUserId: actorUserId,
            actorRole: actorRole,
          );
          created++;
        } else {
          await updateUser(
            existing.id,
            name: name,
            email: email,
            mobile: mobile,
            firmName: company.isEmpty ? existing.firmName : company,
            role: UserRole.client,
            gstRegistrationType: hasRegistrationType ? registrationType : null,
            gstin: hasGstin ? gstin : null,
            accountingEnabled: hasAccountingService ? accountingEnabled : null,
            gstEnabled: hasGstService ? gstEnabled : null,
            pan: row.containsKey('pan') || row.containsKey('pan_number')
                ? pan
                : null,
            state: row.containsKey('state') || row.containsKey('gst_state')
                ? state
                : null,
            city: row.containsKey('city') ? city : null,
            services:
                row.containsKey('services') || row.containsKey('service_type')
                ? services
                : null,
            actorUserId: actorUserId,
            actorRole: actorRole,
          );
          if (existing.isActive != requestedActive &&
              existing.clientStatus != ClientAccountStatus.notOnboarded &&
              existing.clientStatus != ClientAccountStatus.pendingApproval) {
            if (canManageAccountAccess(existing.id)) {
              await setActive(
                existing.id,
                requestedActive,
                actorUserId: actorUserId,
                actorRole: actorRole,
              );
            }
          }
          updated++;
        }
      } on FormatException catch (error) {
        skipped++;
        errors.add('Row ${rowIndex + 1}: ${error.message}');
      }
    }

    final result = UserImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      errors: List<String>.unmodifiable(errors),
    );
    if (errors.isNotEmpty) {
      _importIssues = AdminClientImportIssues(
        source: source,
        occurredAt: DateTime.now(),
        errors: List<String>.unmodifiable(errors),
      );
      await _save();
      notifyListeners();
    }
    return result;
  }

  Future<void> recordImportFailure(String source, String message) async {
    _importIssues = AdminClientImportIssues(
      source: source.trim().isEmpty ? 'Client import' : source.trim(),
      occurredAt: DateTime.now(),
      errors: <String>[message],
    );
    await _save();
    notifyListeners();
  }

  Future<void> clearImportIssues() async {
    _importIssues = null;
    await _save();
    notifyListeners();
  }

  Future<CredentialDeliveryResult> sendCredentials(
    String userId,
    CredentialChannel channel,
  ) async {
    if (!canManageAccountAccess(userId)) {
      return CredentialDeliveryResult(
        channel: channel,
        status: CredentialDeliveryStatus.failed,
        message:
            'Temporary credentials are not available for self-registered clients.',
      );
    }
    final user = _users[_indexOf(userId)];
    final credentials = credentialsFor(userId);
    if (credentials == null) {
      return CredentialDeliveryResult(
        channel: channel,
        status: CredentialDeliveryStatus.failed,
        message: 'Generate temporary credentials before sending.',
      );
    }

    final destination = switch (channel) {
      CredentialChannel.email => user.email,
      CredentialChannel.sms || CredentialChannel.whatsapp => user.mobile,
    };
    if (destination.isEmpty) {
      return CredentialDeliveryResult(
        channel: channel,
        status: CredentialDeliveryStatus.failed,
        message: 'No ${channel.name} destination is saved for this client.',
      );
    }

    if (_integrationHub == null &&
        user.accountOrigin == AccountOrigin.selfRegistered) {
      await _markCredentialsSent(userId);
      return CredentialDeliveryResult(
        channel: channel,
        status: CredentialDeliveryStatus.queued,
        message:
            '${channel.name.toUpperCase()} delivery queued. Configure the live provider for actual delivery.',
      );
    }

    if (_integrationHub == null) {
      return CredentialDeliveryResult(
        channel: channel,
        status: CredentialDeliveryStatus.failed,
        message:
            '${channel.name.toUpperCase()} provider is not configured. Credentials were not sent.',
      );
    }

    final adapterId = switch (channel) {
      CredentialChannel.email => 'email',
      CredentialChannel.sms => 'sms',
      CredentialChannel.whatsapp => 'whatsapp',
    };
    final providerDestination = channel == CredentialChannel.sms
        ? '+91${normalizeIndianMobile(destination)}'
        : destination;
    try {
      await _integrationHub.execute(
        adapterId: adapterId,
        action: 'send',
        payload: <String, dynamic>{
          'to': providerDestination,
          'template': 'client_welcome_credentials',
          'name': user.name,
          'userId': credentials.userId,
          'temporaryPassword': credentials.temporaryPassword,
        },
      );
      await _markCredentialsSent(userId);
      return CredentialDeliveryResult(
        channel: channel,
        status: CredentialDeliveryStatus.sent,
        message: 'Credentials sent by ${channel.name}.',
      );
    } catch (_) {
      return CredentialDeliveryResult(
        channel: channel,
        status: CredentialDeliveryStatus.failed,
        message:
            '${channel.name} provider is unavailable. Credentials were not sent.',
      );
    }
  }

  Future<void> _markCredentialsSent(String userId) async {
    final index = _indexOf(userId);
    _users[index] = _users[index].copyWith(
      loginStatus: ClientLoginStatus.credentialsSent,
      credentialsSentAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(_users.map((user) => user.toJson()).toList(growable: false)),
    );
    await preferences.setString(
      passwordStorageKey,
      jsonEncode(_passwordHashes),
    );
    await preferences.setString(
      complianceStorageKey,
      jsonEncode(
        _complianceRecords.values
            .map((record) => record.toJson())
            .toList(growable: false),
      ),
    );
    await preferences.setString(
      accountingAccessStorageKey,
      jsonEncode(
        _accountingAccessRecords.values
            .map((record) => record.toJson())
            .toList(growable: false),
      ),
    );
    await preferences.setString(
      workspaceStorageKey,
      jsonEncode(
        _workspaceBundles.values
            .map((record) => record.toJson())
            .toList(growable: false),
      ),
    );
    await preferences.setString(
      tallySyncStorageKey,
      jsonEncode(
        _tallySyncSettings.values
            .map((record) => record.toJson())
            .toList(growable: false),
      ),
    );
    if (_importIssues == null) {
      await preferences.remove(importIssuesStorageKey);
    } else {
      await preferences.setString(
        importIssuesStorageKey,
        jsonEncode(_importIssues!.toJson()),
      );
    }
  }

  AdminClientImportIssues? _decodeImportIssues(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final issues = AdminClientImportIssues.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return issues.errors.isEmpty ? null : issues;
    } catch (_) {
      return null;
    }
  }

  Map<String, AdminClientComplianceRecord> _decodeComplianceRecords(
    String? encoded,
  ) {
    if (encoded == null || encoded.isEmpty) {
      return <String, AdminClientComplianceRecord>{};
    }
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final records = decoded.whereType<Map>().map(
        (value) => AdminClientComplianceRecord.fromJson(
          Map<String, dynamic>.from(value),
        ),
      );
      return <String, AdminClientComplianceRecord>{
        for (final record in records)
          if (record.userId.isNotEmpty) record.userId: record,
      };
    } catch (_) {
      return <String, AdminClientComplianceRecord>{};
    }
  }

  Map<String, AdminClientAccountingAccess> _decodeAccountingAccessRecords(
    String? encoded,
  ) {
    if (encoded == null || encoded.isEmpty) {
      return <String, AdminClientAccountingAccess>{};
    }
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final records = decoded.whereType<Map>().map(
        (value) => AdminClientAccountingAccess.fromJson(
          Map<String, dynamic>.from(value),
        ),
      );
      return <String, AdminClientAccountingAccess>{
        for (final record in records)
          if (record.clientId.isNotEmpty) record.clientId: record,
      };
    } catch (_) {
      return <String, AdminClientAccountingAccess>{};
    }
  }

  Map<String, ClientWorkspaceBundle> _decodeWorkspaceBundles(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return <String, ClientWorkspaceBundle>{};
    }
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final records = decoded.whereType<Map>().map(
        (value) =>
            ClientWorkspaceBundle.fromJson(Map<String, dynamic>.from(value)),
      );
      return <String, ClientWorkspaceBundle>{
        for (final record in records)
          if (record.clientId.isNotEmpty) record.clientId: record,
      };
    } catch (_) {
      return <String, ClientWorkspaceBundle>{};
    }
  }

  Map<String, TallySyncSettings> _decodeTallySyncSettings(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return <String, TallySyncSettings>{};
    }
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final records = decoded.whereType<Map>().map(
        (value) => TallySyncSettings.fromJson(Map<String, dynamic>.from(value)),
      );
      return <String, TallySyncSettings>{
        for (final record in records)
          if (record.clientId.isNotEmpty) record.clientId: record,
      };
    } catch (_) {
      return <String, TallySyncSettings>{};
    }
  }

  List<UserModel> _decodeUsers(String? encoded) {
    return decodeManagedUsers(encoded);
  }

  static List<UserModel> decodeManagedUsers(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <UserModel>[];
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((value) => UserModel.fromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
    } catch (_) {
      return <UserModel>[];
    }
  }

  static Map<String, String> decodePasswordHashes(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, String>{};
    try {
      return Map<String, dynamic>.from(
        jsonDecode(encoded) as Map,
      ).map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode('${password}chirag_salt_2024');
    return sha256.convert(bytes).toString();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _autoSyncInFlight.clear();
    super.dispose();
  }

  void _validateIdentity({
    required String name,
    required String email,
    required String mobile,
  }) {
    if (name.trim().isEmpty) {
      throw const FormatException('Client name is required.');
    }
    if (email.trim().isEmpty && _normalizeMobile(mobile).isEmpty) {
      throw const FormatException('Email or mobile number is required.');
    }
    if (email.trim().isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      throw const FormatException('Email address is invalid.');
    }
    final normalizedMobile = _normalizeMobile(mobile);
    if (mobile.trim().isNotEmpty && normalizedMobile.length != 10) {
      throw const FormatException('Mobile number must contain 10 digits.');
    }
  }

  void _ensureUnique(
    String email,
    String mobile, {
    String excludingUserId = '',
  }) {
    final duplicate = _users.any(
      (user) =>
          user.id != excludingUserId &&
          ((email.isNotEmpty && user.email.toLowerCase() == email) ||
              (mobile.isNotEmpty && user.mobile == mobile)),
    );
    if (duplicate) {
      throw const FormatException(
        'A user already exists with this email or mobile.',
      );
    }
  }

  UserModel? _findByIdentity(String email, String mobile) {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedMobile = _normalizeMobile(mobile);
    for (final user in _users) {
      if ((normalizedEmail.isNotEmpty && user.email == normalizedEmail) ||
          (normalizedMobile.isNotEmpty && user.mobile == normalizedMobile)) {
        return user;
      }
    }
    return null;
  }

  int _indexOf(String userId) {
    final index = _users.indexWhere((user) => user.id == userId);
    if (index < 0) throw StateError('User not found.');
    return index;
  }

  GeneratedCredentials _generateCredentials(String name) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .padRight(4, 'user');
    var suffix = 1000 + _random.nextInt(9000);
    var userId =
        '${base.substring(0, base.length > 12 ? 12 : base.length)}$suffix';
    while (_users.any((user) => user.id == userId)) {
      suffix = 1000 + _random.nextInt(9000);
      userId =
          '${base.substring(0, base.length > 12 ? 12 : base.length)}$suffix';
    }
    return GeneratedCredentials(
      userId: userId,
      temporaryPassword: _generatePassword(),
    );
  }

  String _generatePassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = '@#%';
    final all = '$upper$lower$digits$symbols';
    final chars = <String>[
      upper[_random.nextInt(upper.length)],
      lower[_random.nextInt(lower.length)],
      digits[_random.nextInt(digits.length)],
      symbols[_random.nextInt(symbols.length)],
      ...List<String>.generate(6, (_) => all[_random.nextInt(all.length)]),
    ]..shuffle(_random);
    return chars.join();
  }

  String _normalizeMobile(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _firstValue(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  bool _isDisabledValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'false' ||
        normalized == '0' ||
        normalized == 'disabled' ||
        normalized == 'inactive';
  }

  GstRegistrationType _registrationTypeFrom(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    if (normalized.contains('composition')) {
      return GstRegistrationType.composition;
    }
    if (normalized == 'regular' || normalized == 'regulardealer') {
      return GstRegistrationType.regular;
    }
    return GstRegistrationType.unregistered;
  }

  bool _serviceEnabled(String value, {required bool fallback}) {
    if (value.trim().isEmpty) return fallback;
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1' ||
        normalized == 'enabled';
  }

  String _validateCompliance({
    required GstRegistrationType gstRegistrationType,
    required String gstin,
  }) {
    final normalized = gstin.trim().toUpperCase();
    if (gstRegistrationType == GstRegistrationType.unregistered) {
      return normalized;
    }
    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$',
    ).hasMatch(normalized)) {
      throw const FormatException(
        'A valid 15-character GSTIN is required for registered dealers.',
      );
    }
    return normalized;
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final value = StringBuffer();
    var inQuotes = false;

    void addValue() {
      row.add(value.toString());
      value.clear();
    }

    void addRow() {
      addValue();
      rows.add(row);
      row = <String>[];
    }

    for (var index = 0; index < input.length; index++) {
      final char = input[index];
      if (char == '"') {
        if (inQuotes && index + 1 < input.length && input[index + 1] == '"') {
          value.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        addValue();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        addRow();
      } else {
        value.write(char);
      }
    }
    if (value.isNotEmpty || row.isNotEmpty) addRow();
    return rows;
  }

  void _publishAudit({
    required String eventType,
    required UserModel user,
    required AdminAuditAction action,
    required String actorUserId,
    required String actorRole,
    Map<String, dynamic> before = const <String, dynamic>{},
    Map<String, dynamic> after = const <String, dynamic>{},
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    AppEventBus.instance.publish(
      AdminAuditEvent.create(
        eventType: eventType,
        entity: AdminAuditEntity.user,
        entityId: user.id,
        action: action,
        actorUserId: actorUserId,
        actorRole: actorRole,
        companyId: user.firmId,
        before: before,
        after: after,
        metadata: metadata,
      ),
    );
  }
}
