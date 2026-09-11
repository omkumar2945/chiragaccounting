import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/roles/models/role_model.dart';

enum CaAssignmentStatus { assigned, staffSubmitted, caVerifiedSubmitted }

class CaStaffMember {
  const CaStaffMember({
    required this.id,
    required this.caUserId,
    required this.userId,
    required this.name,
    required this.email,
    required this.mobile,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String caUserId;
  final String userId;
  final String name;
  final String email;
  final String mobile;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'caUserId': caUserId,
    'userId': userId,
    'name': name,
    'email': email,
    'mobile': mobile,
    'role': role.name,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory CaStaffMember.fromJson(Map<String, dynamic> json) => CaStaffMember(
    id: json['id']?.toString() ?? '',
    caUserId: json['caUserId']?.toString() ?? '',
    userId: json['userId']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    mobile: json['mobile']?.toString() ?? '',
    role: UserRole.values.firstWhere(
      (entry) => entry.name == json['role']?.toString(),
      orElse: () => UserRole.dataEntryOperator,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    isActive: json['isActive'] as bool? ?? true,
  );
}

class CaClientAssignment {
  const CaClientAssignment({
    required this.id,
    required this.caUserId,
    required this.clientId,
    required this.clientName,
    required this.staffUserId,
    required this.staffName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
  });

  final String id;
  final String caUserId;
  final String clientId;
  final String clientName;
  final String staffUserId;
  final String staffName;
  final CaAssignmentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;

  CaClientAssignment copyWith({
    CaAssignmentStatus? status,
    DateTime? updatedAt,
    String? note,
  }) =>
      CaClientAssignment(
        id: id,
        caUserId: caUserId,
        clientId: clientId,
        clientName: clientName,
        staffUserId: staffUserId,
        staffName: staffName,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'caUserId': caUserId,
    'clientId': clientId,
    'clientName': clientName,
    'staffUserId': staffUserId,
    'staffName': staffName,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'note': note,
  };

  factory CaClientAssignment.fromJson(Map<String, dynamic> json) =>
      CaClientAssignment(
        id: json['id']?.toString() ?? '',
        caUserId: json['caUserId']?.toString() ?? '',
        clientId: json['clientId']?.toString() ?? '',
        clientName: json['clientName']?.toString() ?? '',
        staffUserId: json['staffUserId']?.toString() ?? '',
        staffName: json['staffName']?.toString() ?? '',
        status: CaAssignmentStatus.values.firstWhere(
          (entry) => entry.name == json['status']?.toString(),
          orElse: () => CaAssignmentStatus.assigned,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
        note: json['note']?.toString() ?? '',
      );
}

class CaWorkspaceService extends ChangeNotifier {
  CaWorkspaceService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _staffStorageKey = 'ca_workspace_staff_v1';
  static const String _assignmentsStorageKey = 'ca_workspace_assignments_v1';

  final SharedPreferences? _preferences;
  final List<CaStaffMember> _staff = <CaStaffMember>[];
  final List<CaClientAssignment> _assignments = <CaClientAssignment>[];

  List<CaStaffMember> staffForCa(String caUserId) =>
      _staff.where((entry) => entry.caUserId == caUserId).toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<CaClientAssignment> assignmentsForCa(String caUserId) => _assignments
      .where((entry) => entry.caUserId == caUserId)
      .toList(growable: false)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final staffDecoded = jsonDecode(preferences.getString(_staffStorageKey) ?? '[]');
    final assignmentDecoded = jsonDecode(
      preferences.getString(_assignmentsStorageKey) ?? '[]',
    );

    _staff
      ..clear()
      ..addAll(
        (staffDecoded as List<dynamic>).whereType<Map>().map(
          (entry) => CaStaffMember.fromJson(Map<String, dynamic>.from(entry)),
        ),
      );

    _assignments
      ..clear()
      ..addAll(
        (assignmentDecoded as List<dynamic>).whereType<Map>().map(
          (entry) => CaClientAssignment.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        ),
      );
    notifyListeners();
  }

  Future<void> registerStaffMember({
    required String caUserId,
    required String userId,
    required String name,
    required String email,
    required String mobile,
    required UserRole role,
  }) async {
    final member = CaStaffMember(
      id: 'ca-staff-${DateTime.now().microsecondsSinceEpoch}',
      caUserId: caUserId,
      userId: userId,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      mobile: mobile.trim(),
      role: role,
      createdAt: DateTime.now(),
    );

    final existing = _staff.indexWhere((entry) => entry.userId == userId);
    if (existing >= 0) {
      _staff[existing] = member;
    } else {
      _staff.insert(0, member);
    }
    await _save();
    notifyListeners();
  }

  Future<void> assignClient({
    required String caUserId,
    required String clientId,
    required String clientName,
    required String staffUserId,
    required String staffName,
    String note = '',
  }) async {
    if (clientId.trim().isEmpty || staffUserId.trim().isEmpty) {
      throw ArgumentError('Client and staff selection are required.');
    }
    final index = _assignments.indexWhere(
      (entry) => entry.caUserId == caUserId && entry.clientId == clientId,
    );
    final now = DateTime.now();
    if (index >= 0) {
      _assignments[index] = _assignments[index].copyWith(
        status: CaAssignmentStatus.assigned,
        updatedAt: now,
        note: note.trim(),
      );
    } else {
      _assignments.insert(
        0,
        CaClientAssignment(
          id: 'ca-assignment-${now.microsecondsSinceEpoch}',
          caUserId: caUserId,
          clientId: clientId,
          clientName: clientName.trim(),
          staffUserId: staffUserId,
          staffName: staffName.trim(),
          status: CaAssignmentStatus.assigned,
          createdAt: now,
          updatedAt: now,
          note: note.trim(),
        ),
      );
    }
    await _save();
    notifyListeners();
  }

  Future<void> updateAssignmentStatus({
    required String assignmentId,
    required CaAssignmentStatus status,
    String note = '',
  }) async {
    final index = _assignments.indexWhere((entry) => entry.id == assignmentId);
    if (index < 0) {
      throw StateError('Assignment not found.');
    }
    _assignments[index] = _assignments[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
      note: note.trim().isEmpty ? _assignments[index].note : note.trim(),
    );
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      _staffStorageKey,
      jsonEncode(_staff.map((entry) => entry.toJson()).toList(growable: false)),
    );
    await preferences.setString(
      _assignmentsStorageKey,
      jsonEncode(
        _assignments.map((entry) => entry.toJson()).toList(growable: false),
      ),
    );
  }
}
