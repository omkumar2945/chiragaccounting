import 'package:chirag_accounting/features/roles/models/hierarchical_permission_model.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';


enum PermissionScopeType { company, branch, department, role, user }

enum ApprovalEntityType {
  voucher,
  sales,
  purchase,
  inventory,
  banking,
  gst,
  expense,
  leave,
}

class PermissionPolicy {
  const PermissionPolicy({
    required this.id,
    required this.name,
    required this.scopeType,
    required this.scopeId,
    required this.override,
    this.isEnabled = true,
  });

  final String id;
  final String name;
  final PermissionScopeType scopeType;
  final String scopeId;
  final PermissionScopeOverride override;
  final bool isEnabled;

  PermissionPolicy copyWith({
    String? name,
    PermissionScopeType? scopeType,
    String? scopeId,
    PermissionScopeOverride? override,
    bool? isEnabled,
  }) {
    return PermissionPolicy(
      id: id,
      name: name ?? this.name,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      override: override ?? this.override,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'scopeType': scopeType.name,
        'scopeId': scopeId,
        'isEnabled': isEnabled,
        'override': _permissionOverrideToMap(override),
      };

  factory PermissionPolicy.fromMap(Map<String, dynamic> map) {
    final overrideMap = map['override'];
    return PermissionPolicy(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      scopeType: PermissionScopeType.values.firstWhere(
        (value) => value.name == map['scopeType']?.toString(),
        orElse: () => PermissionScopeType.user,
      ),
      scopeId: map['scopeId']?.toString() ?? '',
      override: _permissionOverrideFromMap(
        overrideMap is Map
            ? Map<String, dynamic>.from(overrideMap)
            : const <String, dynamic>{},
        fallbackScopeId: map['scopeId']?.toString() ?? '',
      ),
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}

class ApprovalStep {
  const ApprovalStep({
    required this.sequence,
    required this.approverRoleId,
    this.minimumApprovers = 1,
    this.canReject = true,
    this.canSendBack = true,
  });

  final int sequence;
  final String approverRoleId;
  final int minimumApprovers;
  final bool canReject;
  final bool canSendBack;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sequence': sequence,
        'approverRoleId': approverRoleId,
        'minimumApprovers': minimumApprovers,
        'canReject': canReject,
        'canSendBack': canSendBack,
      };

  factory ApprovalStep.fromMap(Map<String, dynamic> map) {
    return ApprovalStep(
      sequence: int.tryParse(map['sequence']?.toString() ?? '') ?? 1,
      approverRoleId: map['approverRoleId']?.toString() ?? '',
      minimumApprovers:
          int.tryParse(map['minimumApprovers']?.toString() ?? '') ?? 1,
      canReject: map['canReject'] as bool? ?? true,
      canSendBack: map['canSendBack'] as bool? ?? true,
    );
  }
}

class ApprovalPolicy {
  ApprovalPolicy({
    required this.id,
    required this.companyId,
    required this.name,
    required this.entityType,
    required List<ApprovalStep> steps,
    this.minimumAmount = 0,
    this.maximumAmount,
    this.branchId = '',
    this.departmentId = '',
    this.isEnabled = true,
  }) : steps = List<ApprovalStep>.unmodifiable(
          [...steps]..sort((left, right) => left.sequence.compareTo(right.sequence)),
        );

  final String id;
  final String companyId;
  final String name;
  final ApprovalEntityType entityType;
  final double minimumAmount;
  final double? maximumAmount;
  final String branchId;
  final String departmentId;
  final List<ApprovalStep> steps;
  final bool isEnabled;

  bool appliesToAmount(double amount) {
    if (!isEnabled || amount < minimumAmount) return false;
    return maximumAmount == null || amount <= maximumAmount!;
  }

  ApprovalPolicy copyWith({
    String? name,
    ApprovalEntityType? entityType,
    double? minimumAmount,
    double? maximumAmount,
    bool clearMaximumAmount = false,
    String? branchId,
    String? departmentId,
    List<ApprovalStep>? steps,
    bool? isEnabled,
  }) {
    return ApprovalPolicy(
      id: id,
      companyId: companyId,
      name: name ?? this.name,
      entityType: entityType ?? this.entityType,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumAmount:
          clearMaximumAmount ? null : maximumAmount ?? this.maximumAmount,
      branchId: branchId ?? this.branchId,
      departmentId: departmentId ?? this.departmentId,
      steps: steps ?? this.steps,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'companyId': companyId,
        'name': name,
        'entityType': entityType.name,
        'minimumAmount': minimumAmount,
        'maximumAmount': maximumAmount,
        'branchId': branchId,
        'departmentId': departmentId,
        'steps': steps.map((step) => step.toMap()).toList(growable: false),
        'isEnabled': isEnabled,
      };

  factory ApprovalPolicy.fromMap(Map<String, dynamic> map) {
    return ApprovalPolicy(
      id: map['id']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      entityType: ApprovalEntityType.values.firstWhere(
        (value) => value.name == map['entityType']?.toString(),
        orElse: () => ApprovalEntityType.voucher,
      ),
      minimumAmount:
          double.tryParse(map['minimumAmount']?.toString() ?? '') ?? 0,
      maximumAmount: map['maximumAmount'] == null
          ? null
          : double.tryParse(map['maximumAmount'].toString()),
      branchId: map['branchId']?.toString() ?? '',
      departmentId: map['departmentId']?.toString() ?? '',
      steps: (map['steps'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((value) => ApprovalStep.fromMap(Map<String, dynamic>.from(value)))
          .toList(growable: false),
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}

Map<String, dynamic> _permissionOverrideToMap(
  PermissionScopeOverride override,
) {
  return <String, dynamic>{
    'scopeId': override.scopeId,
    'moduleLevels': override.moduleLevels.map(
      (module, level) => MapEntry(module.name, level.name),
    ),
    'screenActions': override.screenActions.map(
      (screen, actions) => MapEntry(
        screen,
        actions.map((action) => action.name).toList(growable: false),
      ),
    ),
    'allowedBanking':
        override.allowedBanking.map((value) => value.name).toList(growable: false),
    'deniedBanking':
        override.deniedBanking.map((value) => value.name).toList(growable: false),
    'allowedReports':
        override.allowedReports.map((value) => value.name).toList(growable: false),
    'deniedReports':
        override.deniedReports.map((value) => value.name).toList(growable: false),
  };
}

PermissionScopeOverride _permissionOverrideFromMap(
  Map<String, dynamic> map, {
  required String fallbackScopeId,
}) {
  final moduleLevels = map['moduleLevels'];
  final screenActions = map['screenActions'];
  return PermissionScopeOverride(
    scopeId: map['scopeId']?.toString() ?? fallbackScopeId,
    moduleLevels: moduleLevels is Map
        ? Map<String, dynamic>.from(moduleLevels).map(
            (module, level) => MapEntry(
              _enumByName(AppModule.values, module, AppModule.dashboard),
              _enumByName(
                PermissionLevel.values,
                level?.toString(),
                PermissionLevel.none,
              ),
            ),
          )
        : const <AppModule, PermissionLevel>{},
    screenActions: screenActions is Map
        ? Map<String, dynamic>.from(screenActions).map(
            (screen, actions) => MapEntry(
              screen,
              _enumSetByName(PermissionAction.values, actions),
            ),
          )
        : const <String, Set<PermissionAction>>{},
    allowedBanking:
        _enumSetByName(BankingPermission.values, map['allowedBanking']),
    deniedBanking:
        _enumSetByName(BankingPermission.values, map['deniedBanking']),
    allowedReports:
        _enumSetByName(ReportPermission.values, map['allowedReports']),
    deniedReports:
        _enumSetByName(ReportPermission.values, map['deniedReports']),
  );
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}

Set<T> _enumSetByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! List) return <T>{};
  final names = raw.map((value) => value.toString()).toSet();
  return values.where((value) => names.contains(value.name)).toSet();
}
