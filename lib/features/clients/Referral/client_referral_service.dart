import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ClientReferralStatus { pending, rewarded }

class ClientReferral {
  const ClientReferral({
    required this.id,
    required this.referrerClientId,
    required this.referredName,
    required this.mobile,
    required this.gstin,
    required this.createdAt,
    this.status = ClientReferralStatus.pending,
    this.rewardPoints = 0,
    this.onboardedClientId = '',
    this.rewardedAt,
  });

  final String id;
  final String referrerClientId;
  final String referredName;
  final String mobile;
  final String gstin;
  final DateTime createdAt;
  final ClientReferralStatus status;
  final int rewardPoints;
  final String onboardedClientId;
  final DateTime? rewardedAt;

  ClientReferral copyWith({
    ClientReferralStatus? status,
    int? rewardPoints,
    String? onboardedClientId,
    DateTime? rewardedAt,
  }) {
    return ClientReferral(
      id: id,
      referrerClientId: referrerClientId,
      referredName: referredName,
      mobile: mobile,
      gstin: gstin,
      createdAt: createdAt,
      status: status ?? this.status,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      onboardedClientId: onboardedClientId ?? this.onboardedClientId,
      rewardedAt: rewardedAt ?? this.rewardedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'referrerClientId': referrerClientId,
    'referredName': referredName,
    'mobile': mobile,
    'gstin': gstin,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'rewardPoints': rewardPoints,
    'onboardedClientId': onboardedClientId,
    'rewardedAt': rewardedAt?.toIso8601String(),
  };

  factory ClientReferral.fromJson(Map<String, dynamic> json) {
    return ClientReferral(
      id: json['id']?.toString() ?? '',
      referrerClientId: json['referrerClientId']?.toString() ?? '',
      referredName: json['referredName']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      status: ClientReferralStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => ClientReferralStatus.pending,
      ),
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      onboardedClientId: json['onboardedClientId']?.toString() ?? '',
      rewardedAt: DateTime.tryParse(json['rewardedAt']?.toString() ?? ''),
    );
  }
}

class ClientReferralService extends ChangeNotifier {
  ClientReferralService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const int onboardingRewardPoints = 100;
  static const String storageKey = 'client_referrals_v1';

  final SharedPreferences? _preferences;
  final List<ClientReferral> _referrals = <ClientReferral>[];
  bool _isLoaded = false;

  List<ClientReferral> get referrals =>
      List<ClientReferral>.unmodifiable(_referrals);

  List<ClientReferral> referralsFor(String clientId) => _referrals
      .where((referral) => referral.referrerClientId == clientId)
      .toList(growable: false);

  int walletPointsFor(String clientId) => referralsFor(
    clientId,
  ).fold(0, (total, referral) => total + referral.rewardPoints);

  int rewardedCountFor(String clientId) => referralsFor(clientId)
      .where((referral) => referral.status == ClientReferralStatus.rewarded)
      .length;

  Future<void> load() async {
    if (_isLoaded) return;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _referrals
          ..clear()
          ..addAll(
            decoded
                .whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .map(ClientReferral.fromJson),
          );
      } catch (_) {
        _referrals.clear();
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<ClientReferral> createReferral({
    required String referrerClientId,
    required String referredName,
    required String mobile,
    required String gstin,
  }) async {
    await load();
    final cleanName = referredName.trim();
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final cleanGstin = gstin.trim().toUpperCase();
    if (cleanName.isEmpty) throw ArgumentError('New client name is required.');
    if (cleanMobile.length != 10) {
      throw ArgumentError('Enter a valid 10-digit mobile number.');
    }
    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$',
    ).hasMatch(cleanGstin)) {
      throw ArgumentError('Enter a valid 15-character GSTIN.');
    }
    if (_referrals.any(
      (referral) =>
          referral.mobile == cleanMobile || referral.gstin == cleanGstin,
    )) {
      throw ArgumentError('This mobile number or GSTIN is already referred.');
    }

    final referral = ClientReferral(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      referrerClientId: referrerClientId,
      referredName: cleanName,
      mobile: cleanMobile,
      gstin: cleanGstin,
      createdAt: DateTime.now(),
    );
    _referrals.insert(0, referral);
    await _save();
    notifyListeners();
    return referral;
  }

  Future<ClientReferral?> rewardOnboarding({
    required String onboardedClientId,
    required String mobile,
    required String gstin,
  }) async {
    await load();
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final cleanGstin = gstin.trim().toUpperCase();
    final index = _referrals.indexWhere(
      (referral) =>
          referral.status == ClientReferralStatus.pending &&
          ((cleanGstin.isNotEmpty && referral.gstin == cleanGstin) ||
              (cleanMobile.isNotEmpty && referral.mobile == cleanMobile)),
    );
    if (index < 0) return null;

    final rewarded = _referrals[index].copyWith(
      status: ClientReferralStatus.rewarded,
      rewardPoints: onboardingRewardPoints,
      onboardedClientId: onboardedClientId,
      rewardedAt: DateTime.now(),
    );
    _referrals[index] = rewarded;
    await _save();
    notifyListeners();
    return rewarded;
  }

  Future<ClientReferral?> rewardReferral(
    String referralId, {
    String onboardedClientId = 'admin-verified',
  }) async {
    await load();
    final index = _referrals.indexWhere(
      (referral) =>
          referral.id == referralId &&
          referral.status == ClientReferralStatus.pending,
    );
    if (index < 0) return null;

    final rewarded = _referrals[index].copyWith(
      status: ClientReferralStatus.rewarded,
      rewardPoints: onboardingRewardPoints,
      onboardedClientId: onboardedClientId,
      rewardedAt: DateTime.now(),
    );
    _referrals[index] = rewarded;
    await _save();
    notifyListeners();
    return rewarded;
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(
        _referrals.map((referral) => referral.toJson()).toList(growable: false),
      ),
    );
  }
}
