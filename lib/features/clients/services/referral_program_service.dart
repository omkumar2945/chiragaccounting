import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReferralStatus {
  invited,
  contacted,
  registered,
  converted,
  rewardApproved,
  rewardPaid,
  declined,
}

extension ReferralStatusLabel on ReferralStatus {
  String get displayLabel => switch (this) {
    ReferralStatus.invited => 'Invited',
    ReferralStatus.contacted => 'Contacted',
    ReferralStatus.registered => 'Registered',
    ReferralStatus.converted => 'Converted',
    ReferralStatus.rewardApproved => 'Reward Approved',
    ReferralStatus.rewardPaid => 'Reward Paid',
    ReferralStatus.declined => 'Closed',
  };

  bool get rewardEligible =>
      this == ReferralStatus.rewardApproved || this == ReferralStatus.rewardPaid;
}

class ReferralCampaign {
  const ReferralCampaign({
    this.campaignName = 'Unlimited Referral Rewards',
    this.rewardAmount = 500,
    this.yourAwardType = 'Amazon Voucher',
    this.contactAwardType = 'Subscription Discount',
    this.contactAwardDetail = 'Off on Chirag Accounting subscription',
    this.active = true,
    this.updatedAt,
  });

  final String campaignName;
  final int rewardAmount;
  final String yourAwardType;
  final String contactAwardType;
  final String contactAwardDetail;
  final bool active;
  final DateTime? updatedAt;

  String get rewardAmountLabel => 'Rs. $rewardAmount';

  ReferralCampaign copyWith({
    String? campaignName,
    int? rewardAmount,
    String? yourAwardType,
    String? contactAwardType,
    String? contactAwardDetail,
    bool? active,
    DateTime? updatedAt,
  }) {
    return ReferralCampaign(
      campaignName: campaignName ?? this.campaignName,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      yourAwardType: yourAwardType ?? this.yourAwardType,
      contactAwardType: contactAwardType ?? this.contactAwardType,
      contactAwardDetail: contactAwardDetail ?? this.contactAwardDetail,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'campaignName': campaignName,
    'rewardAmount': rewardAmount,
    'yourAwardType': yourAwardType,
    'contactAwardType': contactAwardType,
    'contactAwardDetail': contactAwardDetail,
    'active': active,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory ReferralCampaign.fromJson(Map<String, dynamic> json) {
    return ReferralCampaign(
      campaignName: json['campaignName']?.toString() ??
          'Unlimited Referral Rewards',
      rewardAmount: (json['rewardAmount'] as num?)?.round() ?? 500,
      yourAwardType: json['yourAwardType']?.toString() ?? 'Amazon Voucher',
      contactAwardType:
          json['contactAwardType']?.toString() ?? 'Subscription Discount',
      contactAwardDetail: json['contactAwardDetail']?.toString() ??
          'Off on Chirag Accounting subscription',
      active: json['active'] as bool? ?? true,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class ReferralRecord {
  const ReferralRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.contactName,
    required this.businessName,
    required this.mobileNumber,
    required this.email,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rewardAmount,
    this.adminNote = '',
    this.registrationLink = '',
    this.inviteSentAt,
    this.registeredAt,
    this.referredUserId = '',
  });

  final String id;
  final String clientId;
  final String clientName;
  final String contactName;
  final String businessName;
  final String mobileNumber;
  final String email;
  final String notes;
  final ReferralStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? rewardAmount;
  final String adminNote;
  final String registrationLink;
  final DateTime? inviteSentAt;
  final DateTime? registeredAt;
  final String referredUserId;

  ReferralRecord copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? contactName,
    String? businessName,
    String? mobileNumber,
    String? email,
    String? notes,
    ReferralStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? rewardAmount,
    String? adminNote,
    String? registrationLink,
    DateTime? inviteSentAt,
    DateTime? registeredAt,
    String? referredUserId,
  }) {
    return ReferralRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      contactName: contactName ?? this.contactName,
      businessName: businessName ?? this.businessName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      adminNote: adminNote ?? this.adminNote,
      registrationLink: registrationLink ?? this.registrationLink,
      inviteSentAt: inviteSentAt ?? this.inviteSentAt,
      registeredAt: registeredAt ?? this.registeredAt,
      referredUserId: referredUserId ?? this.referredUserId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'contactName': contactName,
    'businessName': businessName,
    'mobileNumber': mobileNumber,
    'email': email,
    'notes': notes,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'rewardAmount': rewardAmount,
    'adminNote': adminNote,
    'registrationLink': registrationLink,
    'inviteSentAt': inviteSentAt?.toIso8601String(),
    'registeredAt': registeredAt?.toIso8601String(),
    'referredUserId': referredUserId,
  };

  factory ReferralRecord.fromJson(Map<String, dynamic> json) {
    return ReferralRecord(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      mobileNumber: json['mobileNumber']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: ReferralStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => ReferralStatus.invited,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      rewardAmount: (json['rewardAmount'] as num?)?.round(),
      adminNote: json['adminNote']?.toString() ?? '',
      registrationLink: json['registrationLink']?.toString() ?? '',
      inviteSentAt: DateTime.tryParse(json['inviteSentAt']?.toString() ?? ''),
      registeredAt: DateTime.tryParse(json['registeredAt']?.toString() ?? ''),
      referredUserId: json['referredUserId']?.toString() ?? '',
    );
  }
}

class ReferralProgramService extends ChangeNotifier {
  ReferralProgramService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _campaignKey = 'referral_campaign_v1';
  static const String _recordsKey = 'referral_records_v1';

  final SharedPreferences? _preferences;

  ReferralCampaign _campaign = const ReferralCampaign();
  List<ReferralRecord> _records = const <ReferralRecord>[];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  ReferralCampaign get campaign => _campaign;
  List<ReferralRecord> get allRecords => _records;

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final rawCampaign = preferences.getString(_campaignKey);
    final rawRecords = preferences.getString(_recordsKey);
    _campaign = _decodeCampaign(rawCampaign);
    _records = _decodeRecords(rawRecords);
    _loaded = true;
    notifyListeners();
  }

  List<ReferralRecord> referralsForClient(String clientId) {
    return _records
        .where((record) => record.clientId == clientId)
        .toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  List<ReferralRecord> rewardHistoryForClient(String clientId) {
    return referralsForClient(clientId)
        .where((record) => record.status.rewardEligible)
        .toList(growable: false);
  }

  List<ReferralRecord> eligibleRewardsForClient(String clientId) {
    return referralsForClient(clientId)
        .where((record) => record.status == ReferralStatus.rewardApproved)
        .toList(growable: false);
  }

  List<ReferralRecord> claimedRewardsForClient(String clientId) {
    return referralsForClient(clientId)
        .where((record) => record.status == ReferralStatus.rewardPaid)
        .toList(growable: false);
  }

  List<ReferralRecord> claimHistoryForClient(String clientId) {
    return referralsForClient(clientId)
        .where(
          (record) =>
              record.status == ReferralStatus.rewardApproved ||
              record.status == ReferralStatus.rewardPaid,
        )
        .toList(growable: false);
  }

  List<ReferralRecord> upcomingRewardsForClient(String clientId) {
    return referralsForClient(clientId)
        .where(
          (record) =>
              record.status == ReferralStatus.contacted ||
              record.status == ReferralStatus.registered ||
              record.status == ReferralStatus.converted,
        )
        .toList(growable: false);
  }

  int totalEligibleRewardAmountForClient(String clientId) {
    return eligibleRewardsForClient(clientId).fold<int>(
      0,
      (sum, record) => sum + (record.rewardAmount ?? _campaign.rewardAmount),
    );
  }

  int totalClaimedRewardAmountForClient(String clientId) {
    return claimedRewardsForClient(clientId).fold<int>(
      0,
      (sum, record) => sum + (record.rewardAmount ?? _campaign.rewardAmount),
    );
  }

  int totalUpcomingRewardAmountForClient(String clientId) {
    return upcomingRewardsForClient(clientId).fold<int>(
      0,
      (sum, record) => sum + _campaign.rewardAmount,
    );
  }

  Future<ReferralRecord> createReferral({
    required String clientId,
    required String clientName,
    required String contactName,
    required String businessName,
    required String mobileNumber,
    required String email,
    String notes = '',
  }) async {
    if (!_loaded) {
      await load();
    }

    final cleanClientId = clientId.trim();
    final cleanClientName = clientName.trim();
    final cleanContactName = contactName.trim();
    final cleanBusinessName = businessName.trim();
    final cleanMobile = mobileNumber.replaceAll(RegExp(r'\D'), '');
    final cleanEmail = email.trim().toLowerCase();
    final cleanNotes = notes.trim();

    if (cleanClientId.isEmpty) {
      throw ArgumentError('Client session is required to create a referral.');
    }
    if (cleanContactName.isEmpty) {
      throw ArgumentError('Contact name is required.');
    }
    if (cleanBusinessName.isEmpty) {
      throw ArgumentError('Business name is required.');
    }
    if (cleanMobile.isEmpty && cleanEmail.isEmpty) {
      throw ArgumentError('Enter mobile number or email for referral invite.');
    }
    if (cleanMobile.isNotEmpty && cleanMobile.length != 10) {
      throw ArgumentError('Enter a valid 10-digit mobile number.');
    }
    if (cleanEmail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw ArgumentError('Enter a valid email address or leave it blank.');
    }
    if (_records.any(
      (record) =>
          record.clientId == cleanClientId &&
          (record.mobileNumber.replaceAll(RegExp(r'\D'), '') == cleanMobile ||
              (cleanEmail.isNotEmpty &&
                  record.email.trim().toLowerCase() == cleanEmail)),
    )) {
      throw ArgumentError(
        'This referral already exists for the same mobile number or email.',
      );
    }

    final now = DateTime.now();
    final registrationLink = _buildRegistrationLink(
      referralId: 'ref-${now.microsecondsSinceEpoch}',
      mobileNumber: cleanMobile,
      email: cleanEmail,
    );
    final record = ReferralRecord(
      id: 'ref-${now.microsecondsSinceEpoch}',
      clientId: cleanClientId,
      clientName: cleanClientName,
      contactName: cleanContactName,
      businessName: cleanBusinessName,
      mobileNumber: cleanMobile,
      email: cleanEmail,
      notes: cleanNotes,
      status: ReferralStatus.invited,
      createdAt: now,
      updatedAt: now,
      registrationLink: registrationLink,
      inviteSentAt: now,
    );
    _records = <ReferralRecord>[record, ..._records];
    await _save();
    return record;
  }

  Future<ReferralRecord?> markRegistrationCompleted({
    required String mobileNumber,
    required String email,
    String referredUserId = '',
  }) async {
    if (!_loaded) {
      await load();
    }

    final cleanMobile = mobileNumber.replaceAll(RegExp(r'\D'), '');
    final cleanEmail = email.trim().toLowerCase();
    if (cleanMobile.isEmpty && cleanEmail.isEmpty) return null;

    final index = _records.indexWhere((record) {
      final mobileMatch =
          cleanMobile.isNotEmpty && record.mobileNumber == cleanMobile;
      final emailMatch =
          cleanEmail.isNotEmpty && record.email.trim().toLowerCase() == cleanEmail;
      if (!mobileMatch && !emailMatch) return false;
      return record.status != ReferralStatus.declined &&
          record.status != ReferralStatus.rewardPaid;
    });
    if (index < 0) return null;

    final current = _records[index];
    final now = DateTime.now();
    final updated = current.copyWith(
      status: ReferralStatus.registered,
      updatedAt: now,
      registeredAt: now,
      referredUserId: referredUserId.trim(),
      adminNote: current.adminNote.trim().isEmpty
          ? 'Registration completed by referred contact.'
          : current.adminNote,
    );

    final next = List<ReferralRecord>.from(_records);
    next[index] = updated;
    _records = next;
    await _save();
    return updated;
  }

  String _buildRegistrationLink({
    required String referralId,
    required String mobileNumber,
    required String email,
  }) {
    final uri = Uri(
      scheme: 'https',
      host: 'app.chiragaccounting.in',
      path: '/register',
      queryParameters: <String, String>{
        'ref': referralId,
        if (mobileNumber.isNotEmpty) 'mobile': mobileNumber,
        if (email.isNotEmpty) 'email': email,
      },
    );
    return uri.toString();
  }

  Future<void> updateCampaign(ReferralCampaign campaign) async {
    _campaign = campaign.copyWith(updatedAt: DateTime.now());
    await _save();
  }

  Future<void> updateReferralStatus(
    String referralId,
    ReferralStatus status, {
    String? adminNote,
  }) async {
    final rewardAmount = status.rewardEligible ? _campaign.rewardAmount : null;
    _records = _records.map((record) {
      if (record.id != referralId) return record;
      return record.copyWith(
        status: status,
        rewardAmount: rewardAmount ?? record.rewardAmount,
        updatedAt: DateTime.now(),
        adminNote: adminNote ?? record.adminNote,
      );
    }).toList(growable: false);
    await _save();
  }

  Future<void> deleteReferral(String referralId) async {
    _records = _records
        .where((record) => record.id != referralId)
        .toList(growable: false);
    await _save();
  }

  ReferralCampaign _decodeCampaign(String? raw) {
    if (raw == null || raw.isEmpty) return const ReferralCampaign();
    try {
      return ReferralCampaign.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const ReferralCampaign();
    }
  }

  List<ReferralRecord> _decodeRecords(String? raw) {
    if (raw == null || raw.isEmpty) return const <ReferralRecord>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (value) => ReferralRecord.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <ReferralRecord>[];
    }
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(_campaignKey, jsonEncode(_campaign.toJson()));
    await preferences.setString(
      _recordsKey,
      jsonEncode(
        _records.map((record) => record.toJson()).toList(growable: false),
      ),
    );
    notifyListeners();
  }
}