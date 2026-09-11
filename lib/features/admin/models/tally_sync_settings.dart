enum TallySyncDirection { chiragToTally, tallyToChirag, bidirectional }

enum TallyConflictPolicy { skipDuplicate, overwriteExisting, rejectDuplicate }

enum TallySyncStatus { notConnected, ready, syncing, success, failed }

enum TallySyncModule {
  groups,
  ledgers,
  costCentres,
  godowns,
  gstMasters,
  stockGroups,
  stockItems,
  units,
  sales,
  purchase,
  receipt,
  payment,
  journal,
  contra,
  creditNote,
  debitNote,
  deliveryNote,
  receiptNote,
  stockJournal,
  physicalStock,
}

enum TallySyncModuleGroup { masters, inventory, vouchers }

extension TallySyncModuleDetails on TallySyncModule {
  String get displayName => switch (this) {
    TallySyncModule.groups => 'Groups',
    TallySyncModule.ledgers => 'Ledgers',
    TallySyncModule.costCentres => 'Cost Centres',
    TallySyncModule.godowns => 'Godowns',
    TallySyncModule.gstMasters => 'GST & HSN Masters',
    TallySyncModule.stockGroups => 'Stock Groups',
    TallySyncModule.stockItems => 'Stock Items',
    TallySyncModule.units => 'Units',
    TallySyncModule.sales => 'Sales',
    TallySyncModule.purchase => 'Purchase',
    TallySyncModule.receipt => 'Receipt',
    TallySyncModule.payment => 'Payment',
    TallySyncModule.journal => 'Journal',
    TallySyncModule.contra => 'Contra',
    TallySyncModule.creditNote => 'Credit Note',
    TallySyncModule.debitNote => 'Debit Note',
    TallySyncModule.deliveryNote => 'Delivery Note',
    TallySyncModule.receiptNote => 'Receipt Note',
    TallySyncModule.stockJournal => 'Stock Journal',
    TallySyncModule.physicalStock => 'Physical Stock',
  };

  TallySyncModuleGroup get group => switch (this) {
    TallySyncModule.groups ||
    TallySyncModule.ledgers ||
    TallySyncModule.costCentres ||
    TallySyncModule.godowns ||
    TallySyncModule.gstMasters => TallySyncModuleGroup.masters,
    TallySyncModule.stockGroups ||
    TallySyncModule.stockItems ||
    TallySyncModule.units => TallySyncModuleGroup.inventory,
    _ => TallySyncModuleGroup.vouchers,
  };
}

extension TallySyncDirectionLabel on TallySyncDirection {
  String get displayName => switch (this) {
    TallySyncDirection.chiragToTally => 'Chirag to Tally',
    TallySyncDirection.tallyToChirag => 'Tally to Chirag',
    TallySyncDirection.bidirectional => 'Two-way sync',
  };
}

extension TallyConflictPolicyLabel on TallyConflictPolicy {
  String get displayName => switch (this) {
    TallyConflictPolicy.skipDuplicate => 'Skip duplicate',
    TallyConflictPolicy.overwriteExisting => 'Overwrite using Tally ALTER',
    TallyConflictPolicy.rejectDuplicate => 'Stop and report duplicate',
  };
}

class TallySyncHistoryEntry {
  const TallySyncHistoryEntry({
    required this.id,
    required this.companyName,
    required this.direction,
    required this.status,
    required this.mode,
    required this.startedAt,
    this.completedAt,
    this.imported = 0,
    this.exported = 0,
    this.warnings = const <String>[],
    this.errorMessage = '',
  });

  final int id;
  final String companyName;
  final String direction;
  final String status;
  final String mode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int imported;
  final int exported;
  final List<String> warnings;
  final String errorMessage;

  bool get failed => status == 'failed';

  factory TallySyncHistoryEntry.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'] as Map)
        : const <String, dynamic>{};
    return TallySyncHistoryEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      startedAt:
          DateTime.tryParse(json['started_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
      imported: (result['imported'] as num?)?.toInt() ?? 0,
      exported: (result['exported'] as num?)?.toInt() ?? 0,
      warnings:
          (result['warnings'] as List?)
              ?.map((warning) => warning.toString())
              .toList(growable: false) ??
          const <String>[],
      errorMessage: json['error_message']?.toString() ?? '',
    );
  }
}

class TallySyncSettings {
  const TallySyncSettings({
    required this.clientId,
    this.enabled = false,
    this.autoSyncEnabled = false,
    this.hasCompletedInitialSync = false,
    this.endpoint = 'http://127.0.0.1:9000',
    this.companyName = '',
    this.companyNames = const <String>[],
    this.direction = TallySyncDirection.bidirectional,
    this.masterConflictPolicy = TallyConflictPolicy.skipDuplicate,
    this.voucherConflictPolicy = TallyConflictPolicy.skipDuplicate,
    this.syncMasters = true,
    this.syncVouchers = true,
    this.syncInventory = true,
    this.moduleDirections = const <String, TallySyncDirection>{},
    this.allowTallyDeletions = false,
    this.confirmBeforeManualSync = true,
    this.fromDate,
    this.toDate,
    this.intervalMinutes = 15,
    this.status = TallySyncStatus.notConnected,
    this.lastSyncAt,
    this.lastError = '',
  });

  final String clientId;
  final bool enabled;
  final bool autoSyncEnabled;
  final bool hasCompletedInitialSync;
  final String endpoint;
  final String companyName;
  final List<String> companyNames;
  final TallySyncDirection direction;
  final TallyConflictPolicy masterConflictPolicy;
  final TallyConflictPolicy voucherConflictPolicy;
  final bool syncMasters;
  final bool syncVouchers;
  final bool syncInventory;
  final Map<String, TallySyncDirection> moduleDirections;
  final bool allowTallyDeletions;
  final bool confirmBeforeManualSync;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int intervalMinutes;
  final TallySyncStatus status;
  final DateTime? lastSyncAt;
  final String lastError;

  List<String> get selectedCompanyNames {
    final values = companyNames.isEmpty ? <String>[companyName] : companyNames;
    return values
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  bool get isDue {
    if (!enabled || !autoSyncEnabled || !hasCompletedInitialSync) return false;
    final last = lastSyncAt;
    return last == null ||
        DateTime.now().difference(last) >= Duration(minutes: intervalMinutes);
  }

  Map<String, TallySyncDirection> get effectiveModuleDirections {
    if (moduleDirections.isNotEmpty) return moduleDirections;
    return <String, TallySyncDirection>{
      for (final module in TallySyncModule.values)
        if ((module.group == TallySyncModuleGroup.masters && syncMasters) ||
            (module.group == TallySyncModuleGroup.inventory && syncInventory) ||
            (module.group == TallySyncModuleGroup.vouchers && syncVouchers))
          module.name: direction,
    };
  }

  TallySyncSettings copyWith({
    bool? enabled,
    bool? autoSyncEnabled,
    bool? hasCompletedInitialSync,
    String? endpoint,
    String? companyName,
    List<String>? companyNames,
    TallySyncDirection? direction,
    TallyConflictPolicy? masterConflictPolicy,
    TallyConflictPolicy? voucherConflictPolicy,
    bool? syncMasters,
    bool? syncVouchers,
    bool? syncInventory,
    Map<String, TallySyncDirection>? moduleDirections,
    bool? allowTallyDeletions,
    bool? confirmBeforeManualSync,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    int? intervalMinutes,
    TallySyncStatus? status,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
    String? lastError,
  }) {
    return TallySyncSettings(
      clientId: clientId,
      enabled: enabled ?? this.enabled,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      hasCompletedInitialSync:
          hasCompletedInitialSync ?? this.hasCompletedInitialSync,
      endpoint: endpoint ?? this.endpoint,
      companyName:
          companyName ??
          (companyNames?.isNotEmpty == true
              ? companyNames!.first
              : this.companyName),
      companyNames:
          companyNames ??
          (companyName != null ? <String>[companyName] : this.companyNames),
      direction: direction ?? this.direction,
      masterConflictPolicy: masterConflictPolicy ?? this.masterConflictPolicy,
      voucherConflictPolicy:
          voucherConflictPolicy ?? this.voucherConflictPolicy,
      syncMasters: syncMasters ?? this.syncMasters,
      syncVouchers: syncVouchers ?? this.syncVouchers,
      syncInventory: syncInventory ?? this.syncInventory,
      moduleDirections: moduleDirections ?? this.moduleDirections,
      allowTallyDeletions: allowTallyDeletions ?? this.allowTallyDeletions,
      confirmBeforeManualSync:
          confirmBeforeManualSync ?? this.confirmBeforeManualSync,
      fromDate: clearFromDate ? null : fromDate ?? this.fromDate,
      toDate: clearToDate ? null : toDate ?? this.toDate,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      status: status ?? this.status,
      lastSyncAt: clearLastSyncAt ? null : lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientId': clientId,
    'enabled': enabled,
    'autoSyncEnabled': autoSyncEnabled,
    'hasCompletedInitialSync': hasCompletedInitialSync,
    'endpoint': endpoint,
    'companyName': companyName,
    'companyNames': selectedCompanyNames,
    'direction': direction.name,
    'masterConflictPolicy': masterConflictPolicy.name,
    'voucherConflictPolicy': voucherConflictPolicy.name,
    'syncMasters': syncMasters,
    'syncVouchers': syncVouchers,
    'syncInventory': syncInventory,
    'moduleDirections': moduleDirections.map(
      (module, direction) => MapEntry(module, direction.name),
    ),
    'allowTallyDeletions': allowTallyDeletions,
    'confirmBeforeManualSync': confirmBeforeManualSync,
    'fromDate': fromDate?.toIso8601String(),
    'toDate': toDate?.toIso8601String(),
    'intervalMinutes': intervalMinutes,
    'status': status.name,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'lastError': lastError,
  };

  factory TallySyncSettings.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      return values
              .where((value) => value.name == raw?.toString())
              .firstOrNull ??
          fallback;
    }

    return TallySyncSettings(
      clientId: json['clientId']?.toString() ?? '',
      enabled: json['enabled'] as bool? ?? false,
      autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? false,
      hasCompletedInitialSync:
          json['hasCompletedInitialSync'] as bool? ?? false,
      endpoint: json['endpoint']?.toString() ?? 'http://127.0.0.1:9000',
      companyName: json['companyName']?.toString() ?? '',
      companyNames:
          (json['companyNames'] as List?)
              ?.map((name) => name.toString())
              .toList(growable: false) ??
          const <String>[],
      direction: enumValue(
        TallySyncDirection.values,
        json['direction'],
        TallySyncDirection.bidirectional,
      ),
      masterConflictPolicy: enumValue(
        TallyConflictPolicy.values,
        json['masterConflictPolicy'],
        TallyConflictPolicy.skipDuplicate,
      ),
      voucherConflictPolicy: enumValue(
        TallyConflictPolicy.values,
        json['voucherConflictPolicy'],
        TallyConflictPolicy.skipDuplicate,
      ),
      syncMasters: json['syncMasters'] as bool? ?? true,
      syncVouchers: json['syncVouchers'] as bool? ?? true,
      syncInventory: json['syncInventory'] as bool? ?? true,
      moduleDirections:
          (json['moduleDirections'] as Map?)?.map<String, TallySyncDirection>(
            (module, rawDirection) => MapEntry(
              module.toString(),
              enumValue(
                TallySyncDirection.values,
                rawDirection,
                TallySyncDirection.bidirectional,
              ),
            ),
          ) ??
          const <String, TallySyncDirection>{},
      allowTallyDeletions: json['allowTallyDeletions'] as bool? ?? false,
      confirmBeforeManualSync: json['confirmBeforeManualSync'] as bool? ?? true,
      fromDate: DateTime.tryParse(json['fromDate']?.toString() ?? ''),
      toDate: DateTime.tryParse(json['toDate']?.toString() ?? ''),
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt() ?? 15,
      status: enumValue(
        TallySyncStatus.values,
        json['status'],
        TallySyncStatus.notConnected,
      ),
      lastSyncAt: DateTime.tryParse(json['lastSyncAt']?.toString() ?? ''),
      lastError: json['lastError']?.toString() ?? '',
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
