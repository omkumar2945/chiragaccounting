import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HiringStage { applied, screening, interview, offered, hired, rejected }
enum RecruitmentStatus { active, inactive }

class HrImportSummary {
  const HrImportSummary({
    required this.totalRows,
    required this.importedRows,
    required this.skippedRows,
    required this.errors,
  });

  final int totalRows;
  final int importedRows;
  final int skippedRows;
  final List<String> errors;
}

class CandidateBroadcastRecord {
  const CandidateBroadcastRecord({
    required this.id,
    required this.sentAt,
    required this.channel,
    required this.message,
    required this.recipientIds,
    required this.recipientNames,
    required this.roleFilter,
    required this.stageFilter,
  });

  final String id;
  final DateTime sentAt;
  final String channel;
  final String message;
  final List<String> recipientIds;
  final List<String> recipientNames;
  final String roleFilter;
  final String stageFilter;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sentAt': sentAt.toIso8601String(),
    'channel': channel,
    'message': message,
    'recipientIds': recipientIds,
    'recipientNames': recipientNames,
    'roleFilter': roleFilter,
    'stageFilter': stageFilter,
  };

  factory CandidateBroadcastRecord.fromJson(Map<String, dynamic> json) =>
      CandidateBroadcastRecord(
        id: json['id']?.toString() ?? '',
        sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ?? DateTime.now(),
        channel: json['channel']?.toString() ?? 'sms',
        message: json['message']?.toString() ?? '',
        recipientIds: (json['recipientIds'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList(growable: false),
        recipientNames: (json['recipientNames'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList(growable: false),
        roleFilter: json['roleFilter']?.toString() ?? 'All',
        stageFilter: json['stageFilter']?.toString() ?? 'All',
      );
}

class HiringCandidate {
  const HiringCandidate({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.position,
    required this.stage,
    required this.appliedAt,
    required this.notes,
    this.staffUserId = '',
    this.status = RecruitmentStatus.active,
    this.expectedJoinDate,
    this.department = '',
    this.salaryExpectation = '',
  });

  final String id;
  final String name;
  final String mobile;
  final String email;
  final String position;
  final HiringStage stage;
  final DateTime appliedAt;
  final String notes;
  final String staffUserId;
  final RecruitmentStatus status;
  final DateTime? expectedJoinDate;
  final String department;
  final String salaryExpectation;

  HiringCandidate copyWith({
    HiringStage? stage,
    String? staffUserId,
    RecruitmentStatus? status,
    DateTime? expectedJoinDate,
    String? department,
    String? salaryExpectation,
    String? notes,
  }) =>
      HiringCandidate(
        id: id,
        name: name,
        mobile: mobile,
        email: email,
        position: position,
        stage: stage ?? this.stage,
        appliedAt: appliedAt,
        notes: notes ?? this.notes,
        staffUserId: staffUserId ?? this.staffUserId,
        status: status ?? this.status,
        expectedJoinDate: expectedJoinDate ?? this.expectedJoinDate,
        department: department ?? this.department,
        salaryExpectation: salaryExpectation ?? this.salaryExpectation,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'mobile': mobile,
    'email': email,
    'position': position,
    'stage': stage.name,
    'appliedAt': appliedAt.toIso8601String(),
    'notes': notes,
    'staffUserId': staffUserId,
    'status': status.name,
    'expectedJoinDate': expectedJoinDate?.toIso8601String(),
    'department': department,
    'salaryExpectation': salaryExpectation,
  };

  factory HiringCandidate.fromJson(Map<String, dynamic> json) =>
      HiringCandidate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        position: json['position']?.toString() ?? '',
        stage: HiringStage.values.firstWhere(
          (value) => value.name == json['stage']?.toString(),
          orElse: () => HiringStage.applied,
        ),
        appliedAt:
            DateTime.tryParse(json['appliedAt']?.toString() ?? '') ??
            DateTime.now(),
        notes: json['notes']?.toString() ?? '',
        staffUserId: json['staffUserId']?.toString() ?? '',
        status: RecruitmentStatus.values.firstWhere(
          (value) => value.name == json['status']?.toString(),
          orElse: () => RecruitmentStatus.active,
        ),
        expectedJoinDate: DateTime.tryParse(
          json['expectedJoinDate']?.toString() ?? '',
        ),
        department: json['department']?.toString() ?? '',
        salaryExpectation: json['salaryExpectation']?.toString() ?? '',
      );
}

class HrEmployeeRecord {
  const HrEmployeeRecord({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.position,
    required this.department,
    required this.joinedAt,
    required this.source,
    this.staffUserId = '',
    this.currentStatus = 'active',
    this.salary = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String mobile;
  final String email;
  final String position;
  final String department;
  final DateTime joinedAt;
  final String source;
  final String staffUserId;
  final String currentStatus;
  final String salary;
  final String notes;

  HrEmployeeRecord copyWith({
    String? name,
    String? mobile,
    String? email,
    String? position,
    String? department,
    DateTime? joinedAt,
    String? source,
    String? staffUserId,
    String? currentStatus,
    String? salary,
    String? notes,
  }) =>
      HrEmployeeRecord(
        id: id,
        name: name ?? this.name,
        mobile: mobile ?? this.mobile,
        email: email ?? this.email,
        position: position ?? this.position,
        department: department ?? this.department,
        joinedAt: joinedAt ?? this.joinedAt,
        source: source ?? this.source,
        staffUserId: staffUserId ?? this.staffUserId,
        currentStatus: currentStatus ?? this.currentStatus,
        salary: salary ?? this.salary,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'mobile': mobile,
    'email': email,
    'position': position,
    'department': department,
    'joinedAt': joinedAt.toIso8601String(),
    'source': source,
    'staffUserId': staffUserId,
    'currentStatus': currentStatus,
    'salary': salary,
    'notes': notes,
  };

  factory HrEmployeeRecord.fromJson(Map<String, dynamic> json) =>
      HrEmployeeRecord(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        position: json['position']?.toString() ?? '',
        department: json['department']?.toString() ?? '',
        joinedAt:
            DateTime.tryParse(json['joinedAt']?.toString() ?? '') ??
            DateTime.now(),
        source: json['source']?.toString() ?? 'manual',
        staffUserId: json['staffUserId']?.toString() ?? '',
        currentStatus: json['currentStatus']?.toString() ?? 'active',
        salary: json['salary']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
      );
}

class HrService extends ChangeNotifier {
  HrService({SharedPreferences? preferences}) : _preferences = preferences;

  static const String storageKey = 'admin_hr_candidates_v1';
  static const String employeeStorageKey = 'admin_hr_employees_v1';
  static const String broadcastStorageKey = 'admin_hr_candidate_messages_v1';
  final SharedPreferences? _preferences;
  final List<HiringCandidate> _candidates = <HiringCandidate>[];
  final List<HrEmployeeRecord> _employees = <HrEmployeeRecord>[];
  final List<CandidateBroadcastRecord> _candidateMessages =
      <CandidateBroadcastRecord>[];

  List<HiringCandidate> get candidates => List.unmodifiable(_candidates);
  List<HrEmployeeRecord> get employees => List.unmodifiable(_employees);
  List<CandidateBroadcastRecord> get candidateMessages =>
      List.unmodifiable(_candidateMessages);

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final decoded = jsonDecode(preferences.getString(storageKey) ?? '[]');
    final employeeDecoded = jsonDecode(
      preferences.getString(employeeStorageKey) ?? '[]',
    );
    final broadcastDecoded = jsonDecode(
      preferences.getString(broadcastStorageKey) ?? '[]',
    );
    _candidates
      ..clear()
      ..addAll(
        (decoded as List<dynamic>).whereType<Map>().map(
          (item) => HiringCandidate.fromJson(Map<String, dynamic>.from(item)),
        ),
      );
    _employees
      ..clear()
      ..addAll(
        (employeeDecoded as List<dynamic>).whereType<Map>().map(
          (item) => HrEmployeeRecord.fromJson(Map<String, dynamic>.from(item)),
        ),
      );
    _candidateMessages
      ..clear()
      ..addAll(
        (broadcastDecoded as List<dynamic>).whereType<Map>().map(
          (item) => CandidateBroadcastRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        ),
      );
    notifyListeners();
  }

  Future<HiringCandidate> addCandidate({
    required String name,
    required String mobile,
    required String email,
    required String position,
    String notes = '',
  }) async {
    final cleanMobile = _normalizeMobile(mobile);
    final cleanEmail = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        cleanMobile.length != 10 ||
        !_isValidEmail(cleanEmail) ||
        position.trim().isEmpty) {
      throw ArgumentError('Complete valid candidate details are required.');
    }

    final alreadyExists = _candidates.any(
      (candidate) =>
          candidate.email.toLowerCase() == cleanEmail ||
          (_normalizeMobile(candidate.mobile).isNotEmpty &&
              _normalizeMobile(candidate.mobile) == cleanMobile),
    );
    if (alreadyExists) {
      throw ArgumentError(
        'Candidate already exists with same email/mobile.',
      );
    }

    final candidate = HiringCandidate(
      id: 'candidate-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      mobile: cleanMobile,
      email: cleanEmail,
      position: position.trim(),
      stage: HiringStage.applied,
      appliedAt: DateTime.now(),
      notes: notes.trim(),
    );
    _candidates.insert(0, candidate);
    await _save();
    notifyListeners();
    return candidate;
  }

  Future<void> changeStage(String candidateId, HiringStage stage) async {
    final index = _indexOf(candidateId);
    _candidates[index] = _candidates[index].copyWith(stage: stage);
    await _save();
    notifyListeners();
  }

  Future<void> updateRecruitmentStatus(
    String candidateId,
    RecruitmentStatus status,
  ) async {
    final index = _indexOf(candidateId);
    _candidates[index] = _candidates[index].copyWith(status: status);
    await _save();
    notifyListeners();
  }

  Future<void> updateCandidateDetails({
    required String candidateId,
    String? department,
    String? salaryExpectation,
    DateTime? expectedJoinDate,
    String? notes,
  }) async {
    final index = _indexOf(candidateId);
    _candidates[index] = _candidates[index].copyWith(
      department: department,
      salaryExpectation: salaryExpectation,
      expectedJoinDate: expectedJoinDate,
      notes: notes,
    );
    await _save();
    notifyListeners();
  }

  Future<CandidateBroadcastRecord> sendCandidateMessage({
    required Iterable<String> candidateIds,
    required String message,
    String channel = 'sms',
    String roleFilter = 'All',
    String stageFilter = 'All',
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      throw ArgumentError('Message content is required.');
    }

    final selectedIds = candidateIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (selectedIds.isEmpty) {
      throw ArgumentError('Select at least one candidate.');
    }

    final recipients = _candidates
        .where((candidate) => selectedIds.contains(candidate.id))
        .toList(growable: false);
    if (recipients.isEmpty) {
      throw ArgumentError('Selected candidates are no longer available.');
    }

    final record = CandidateBroadcastRecord(
      id: 'broadcast-${DateTime.now().microsecondsSinceEpoch}',
      sentAt: DateTime.now(),
      channel: channel.trim().isEmpty ? 'sms' : channel.trim().toLowerCase(),
      message: cleanMessage,
      recipientIds: recipients.map((item) => item.id).toList(growable: false),
      recipientNames: recipients.map((item) => item.name).toList(growable: false),
      roleFilter: roleFilter,
      stageFilter: stageFilter,
    );

    _candidateMessages.insert(0, record);
    await _saveAll();
    notifyListeners();
    return record;
  }

  Future<void> markHired(String candidateId, String staffUserId) async {
    if (staffUserId.trim().isEmpty) {
      throw ArgumentError('Staff ID is required.');
    }
    final index = _indexOf(candidateId);
    final candidate = _candidates[index];
    _candidates[index] = _candidates[index].copyWith(
      stage: HiringStage.hired,
      staffUserId: staffUserId.trim(),
    );
    _upsertEmployeeRecord(
      HrEmployeeRecord(
        id: 'employee-${DateTime.now().microsecondsSinceEpoch}',
        name: candidate.name,
        mobile: _normalizeMobile(candidate.mobile),
        email: candidate.email.toLowerCase(),
        position: candidate.position,
        department: candidate.department,
        joinedAt: candidate.expectedJoinDate ?? DateTime.now(),
        source: 'hiring',
        staffUserId: staffUserId.trim(),
        currentStatus: 'active',
        salary: candidate.salaryExpectation,
        notes: candidate.notes,
      ),
    );
    await _saveAll();
    notifyListeners();
  }

  Future<HrEmployeeRecord> addEmployeeRecord({
    required String name,
    required String mobile,
    required String email,
    required String position,
    required String department,
    String salary = '',
    String notes = '',
    DateTime? joinedAt,
    String source = 'manual',
    String staffUserId = '',
  }) async {
    final cleanMobile = _normalizeMobile(mobile);
    final cleanEmail = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        cleanMobile.length != 10 ||
        !_isValidEmail(cleanEmail) ||
        position.trim().isEmpty) {
      throw ArgumentError('Complete valid employee details are required.');
    }

    final record = HrEmployeeRecord(
      id: 'employee-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      mobile: cleanMobile,
      email: cleanEmail,
      position: position.trim(),
      department: department.trim(),
      joinedAt: joinedAt ?? DateTime.now(),
      source: source,
      staffUserId: staffUserId.trim(),
      salary: salary.trim(),
      notes: notes.trim(),
    );

    _upsertEmployeeRecord(record);
    await _saveAll();
    notifyListeners();
    return record;
  }

  Future<HrImportSummary> importCandidatesFromFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final rows = _parseFileRecords(fileName: fileName, bytes: bytes);
    final imported = <HiringCandidate>[];
    final errors = <String>[];
    final existingEmails = _candidates
        .map((item) => item.email.toLowerCase())
        .toSet();
    final existingMobiles = _candidates
        .map((item) => _normalizeMobile(item.mobile))
        .toSet();

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final name = _value(row, <String>['name', 'candidate name', 'full name']);
        final mobile = _normalizeMobile(
          _value(row, <String>['mobile', 'phone', 'contact', 'mobile number']),
        );
        final email = _value(row, <String>['email', 'email id']).toLowerCase();
        final position = _value(
          row,
          <String>['position', 'role', 'designation', 'job title'],
        );
        final notes = _value(row, <String>['notes', 'remarks']);
        final department = _value(row, <String>['department']);
        final salary = _value(
          row,
          <String>['salary expectation', 'salary', 'ctc'],
        );

        if (name.isEmpty || mobile.length != 10 || !_isValidEmail(email) || position.isEmpty) {
          throw ArgumentError('Missing required fields (name/mobile/email/position).');
        }

        if (existingEmails.contains(email) || existingMobiles.contains(mobile)) {
          continue;
        }

        final candidate = HiringCandidate(
          id: 'candidate-${DateTime.now().microsecondsSinceEpoch}-$i',
          name: name,
          mobile: mobile,
          email: email,
          position: position,
          stage: HiringStage.applied,
          appliedAt: _parseDate(_value(row, <String>['applied at', 'applied date', 'date'])) ?? DateTime.now(),
          notes: notes,
          department: department,
          salaryExpectation: salary,
        );
        imported.add(candidate);
        existingEmails.add(email);
        existingMobiles.add(mobile);
      } catch (error) {
        errors.add('Row ${i + 1}: $error');
      }
    }

    if (imported.isNotEmpty) {
      _candidates.insertAll(0, imported);
      await _saveAll();
      notifyListeners();
    }

    return HrImportSummary(
      totalRows: rows.length,
      importedRows: imported.length,
      skippedRows: rows.length - imported.length,
      errors: List<String>.unmodifiable(errors),
    );
  }

  Future<HrImportSummary> importEmployeesFromFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final rows = _parseFileRecords(fileName: fileName, bytes: bytes);
    var importedCount = 0;
    final errors = <String>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        final name = _value(row, <String>['name', 'employee name', 'full name']);
        final mobile = _normalizeMobile(
          _value(row, <String>['mobile', 'phone', 'contact', 'mobile number']),
        );
        final email = _value(row, <String>['email', 'email id']).toLowerCase();
        final position = _value(
          row,
          <String>['position', 'role', 'designation', 'job title'],
        );
        final department = _value(row, <String>['department']);
        final salary = _value(row, <String>['salary', 'ctc']);
        final staffUserId = _value(row, <String>['staff user id', 'staff id', 'user id']);
        final status = _value(row, <String>['status', 'current status']);
        final notes = _value(row, <String>['notes', 'remarks']);

        if (name.isEmpty || mobile.length != 10 || !_isValidEmail(email) || position.isEmpty) {
          throw ArgumentError('Missing required fields (name/mobile/email/position).');
        }

        final employee = HrEmployeeRecord(
          id: 'employee-${DateTime.now().microsecondsSinceEpoch}-$i',
          name: name,
          mobile: mobile,
          email: email,
          position: position,
          department: department,
          joinedAt: _parseDate(_value(row, <String>['joined at', 'joining date', 'date'])) ?? DateTime.now(),
          source: 'file_import',
          staffUserId: staffUserId,
          currentStatus: status.isEmpty ? 'active' : status,
          salary: salary,
          notes: notes,
        );

        _upsertEmployeeRecord(employee);
        importedCount += 1;
      } catch (error) {
        errors.add('Row ${i + 1}: $error');
      }
    }

    if (importedCount > 0) {
      await _saveAll();
      notifyListeners();
    }

    return HrImportSummary(
      totalRows: rows.length,
      importedRows: importedCount,
      skippedRows: rows.length - importedCount,
      errors: List<String>.unmodifiable(errors),
    );
  }

  int _indexOf(String candidateId) {
    final index = _candidates.indexWhere((item) => item.id == candidateId);
    if (index < 0) throw StateError('Hiring candidate was not found.');
    return index;
  }

  void _upsertEmployeeRecord(HrEmployeeRecord incoming) {
    final index = _employees.indexWhere(
      (employee) =>
          (incoming.staffUserId.isNotEmpty &&
              employee.staffUserId == incoming.staffUserId) ||
          employee.email.toLowerCase() == incoming.email.toLowerCase() ||
          (_normalizeMobile(employee.mobile).isNotEmpty &&
              _normalizeMobile(employee.mobile) ==
                  _normalizeMobile(incoming.mobile)),
    );

    if (index < 0) {
      _employees.insert(0, incoming);
      return;
    }

    _employees[index] = _employees[index].copyWith(
      name: incoming.name,
      mobile: incoming.mobile,
      email: incoming.email,
      position: incoming.position,
      department: incoming.department,
      joinedAt: incoming.joinedAt,
      source: incoming.source,
      staffUserId: incoming.staffUserId.isEmpty
          ? _employees[index].staffUserId
          : incoming.staffUserId,
      currentStatus: incoming.currentStatus,
      salary: incoming.salary,
      notes: incoming.notes,
    );
  }

  List<Map<String, String>> _parseFileRecords({
    required String fileName,
    required List<int> bytes,
  }) {
    final lower = fileName.toLowerCase();
    final content = utf8.decode(bytes, allowMalformed: true).trim();
    if (content.isEmpty) {
      throw ArgumentError('Uploaded file is empty.');
    }

    if (lower.endsWith('.json')) {
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        throw ArgumentError('JSON file must contain a list of records.');
      }
      return decoded
          .whereType<Map>()
          .map(
            (row) => Map<String, String>.fromEntries(
              row.entries.map(
                (entry) => MapEntry(
                  entry.key.toString().trim().toLowerCase(),
                  entry.value?.toString().trim() ?? '',
                ),
              ),
            ),
          )
          .toList(growable: false);
    }

    if (lower.endsWith('.csv')) {
      final lines = content
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList(growable: false);
      if (lines.length < 2) return <Map<String, String>>[];
      final headers = _parseCsvLine(lines.first)
          .map((item) => item.trim().toLowerCase())
          .toList(growable: false);
      final rows = <Map<String, String>>[];
      for (final line in lines.skip(1)) {
        final values = _parseCsvLine(line);
        final row = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          final value = i < values.length ? values[i].trim() : '';
          row[headers[i]] = value;
        }
        rows.add(row);
      }
      return rows;
    }

    throw ArgumentError('Only CSV and JSON files are supported right now.');
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  String _value(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      final key = alias.trim().toLowerCase();
      if (row.containsKey(key)) {
        return row[key]?.trim() ?? '';
      }
    }
    return '';
  }

  DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized);
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _normalizeMobile(String mobile) => mobile.replaceAll(RegExp(r'\D'), '');

  Future<void> _saveAll() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(_candidates.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      employeeStorageKey,
      jsonEncode(_employees.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      broadcastStorageKey,
      jsonEncode(_candidateMessages.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _save() => _saveAll();
}
