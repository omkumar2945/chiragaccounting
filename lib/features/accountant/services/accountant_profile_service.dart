import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountantPerformanceSnapshot {
  const AccountantPerformanceSnapshot({
    required this.generatedAt,
    required this.tasksCompleted,
    required this.overdueTasks,
    required this.activeClients,
  });

  final DateTime generatedAt;
  final int tasksCompleted;
  final int overdueTasks;
  final int activeClients;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'generatedAt': generatedAt.toIso8601String(),
    'tasksCompleted': tasksCompleted,
    'overdueTasks': overdueTasks,
    'activeClients': activeClients,
  };

  factory AccountantPerformanceSnapshot.fromJson(Map<String, dynamic> json) {
    return AccountantPerformanceSnapshot(
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
      tasksCompleted: (json['tasksCompleted'] as num?)?.toInt() ?? 0,
      overdueTasks: (json['overdueTasks'] as num?)?.toInt() ?? 0,
      activeClients: (json['activeClients'] as num?)?.toInt() ?? 0,
    );
  }
}

class AccountantTargetProfile {
  const AccountantTargetProfile({
    this.monthlyTaskTarget = 120,
    this.monthlyRevenueTarget = 0,
    this.clientSatisfactionTarget = 92,
  });

  final int monthlyTaskTarget;
  final double monthlyRevenueTarget;
  final int clientSatisfactionTarget;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'monthlyTaskTarget': monthlyTaskTarget,
    'monthlyRevenueTarget': monthlyRevenueTarget,
    'clientSatisfactionTarget': clientSatisfactionTarget,
  };

  factory AccountantTargetProfile.fromJson(Map<String, dynamic> json) {
    return AccountantTargetProfile(
      monthlyTaskTarget: (json['monthlyTaskTarget'] as num?)?.toInt() ?? 120,
      monthlyRevenueTarget:
          (json['monthlyRevenueTarget'] as num?)?.toDouble() ?? 0,
      clientSatisfactionTarget:
          (json['clientSatisfactionTarget'] as num?)?.toInt() ?? 92,
    );
  }
}

class AccountantProfile {
  const AccountantProfile({
    required this.userId,
    this.fullName = '',
    this.email = '',
    this.mobile = '',
    this.designation = 'Accountant',
    this.resumePath = '',
    this.kycDocumentPath = '',
    this.photoPath = '',
    this.photoBase64 = '',
    this.target = const AccountantTargetProfile(),
    this.lastPerformance,
  });

  final String userId;
  final String fullName;
  final String email;
  final String mobile;
  final String designation;
  final String resumePath;
  final String kycDocumentPath;
  final String photoPath;
  final String photoBase64;
  final AccountantTargetProfile target;
  final AccountantPerformanceSnapshot? lastPerformance;

  AccountantProfile copyWith({
    String? fullName,
    String? email,
    String? mobile,
    String? designation,
    String? resumePath,
    String? kycDocumentPath,
    String? photoPath,
    String? photoBase64,
    AccountantTargetProfile? target,
    AccountantPerformanceSnapshot? lastPerformance,
  }) {
    return AccountantProfile(
      userId: userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      designation: designation ?? this.designation,
      resumePath: resumePath ?? this.resumePath,
      kycDocumentPath: kycDocumentPath ?? this.kycDocumentPath,
      photoPath: photoPath ?? this.photoPath,
      photoBase64: photoBase64 ?? this.photoBase64,
      target: target ?? this.target,
      lastPerformance: lastPerformance ?? this.lastPerformance,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'userId': userId,
    'fullName': fullName,
    'email': email,
    'mobile': mobile,
    'designation': designation,
    'resumePath': resumePath,
    'kycDocumentPath': kycDocumentPath,
    'photoPath': photoPath,
    'photoBase64': photoBase64,
    'target': target.toJson(),
    'lastPerformance': lastPerformance?.toJson(),
  };

  factory AccountantProfile.fromJson(Map<String, dynamic> json) {
    return AccountantProfile(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      designation: json['designation']?.toString() ?? 'Accountant',
      resumePath: json['resumePath']?.toString() ?? '',
      kycDocumentPath: json['kycDocumentPath']?.toString() ?? '',
      photoPath: json['photoPath']?.toString() ?? '',
      photoBase64: json['photoBase64']?.toString() ?? '',
      target: json['target'] is Map
          ? AccountantTargetProfile.fromJson(
              Map<String, dynamic>.from(json['target'] as Map),
            )
          : const AccountantTargetProfile(),
      lastPerformance: json['lastPerformance'] is Map
          ? AccountantPerformanceSnapshot.fromJson(
              Map<String, dynamic>.from(json['lastPerformance'] as Map),
            )
          : null,
    );
  }
}

class AccountantProfileService extends ChangeNotifier {
  AccountantProfileService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _profilesKey = 'accountant_profiles_v1';

  final SharedPreferences? _preferences;
  final Map<String, AccountantProfile> _profiles =
      <String, AccountantProfile>{};

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final decoded = jsonDecode(preferences.getString(_profilesKey) ?? '{}');
    _profiles.clear();
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          _profiles[entry.key.toString()] = AccountantProfile.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    notifyListeners();
  }

  AccountantProfile profileFor({
    required String userId,
    required String fallbackName,
    required String fallbackEmail,
    required String fallbackMobile,
  }) {
    final existing = _profiles[userId];
    if (existing != null) return existing;
    return AccountantProfile(
      userId: userId,
      fullName: fallbackName,
      email: fallbackEmail,
      mobile: fallbackMobile,
    );
  }

  Future<void> saveProfile(AccountantProfile profile) async {
    _profiles[profile.userId] = profile;
    await _save();
    notifyListeners();
  }

  Future<void> updateTargets({
    required String userId,
    required AccountantTargetProfile target,
    required String fallbackName,
    required String fallbackEmail,
    required String fallbackMobile,
  }) async {
    final current = profileFor(
      userId: userId,
      fallbackName: fallbackName,
      fallbackEmail: fallbackEmail,
      fallbackMobile: fallbackMobile,
    );
    _profiles[userId] = current.copyWith(target: target);
    await _save();
    notifyListeners();
  }

  Future<void> recordPerformance({
    required String userId,
    required AccountantPerformanceSnapshot snapshot,
    required String fallbackName,
    required String fallbackEmail,
    required String fallbackMobile,
  }) async {
    final current = profileFor(
      userId: userId,
      fallbackName: fallbackName,
      fallbackEmail: fallbackEmail,
      fallbackMobile: fallbackMobile,
    );
    _profiles[userId] = current.copyWith(lastPerformance: snapshot);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      _profilesKey,
      jsonEncode(
        _profiles.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }
}
