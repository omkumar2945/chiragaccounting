import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/clients/Referral/client_referral_service.dart';

enum MarketingLeadStatus {
  newLead,
  contacted,
  followUp,
  qualified,
  proposal,
  won,
  onboarded,
  lost,
}

enum MarketingLeadSource { referral, direct, campaign, website }

class MarketingFollowUp {
  const MarketingFollowUp({
    required this.id,
    required this.note,
    required this.followUpAt,
    required this.createdAt,
  });

  final String id;
  final String note;
  final DateTime followUpAt;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'note': note,
    'followUpAt': followUpAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory MarketingFollowUp.fromJson(Map<String, dynamic> json) =>
      MarketingFollowUp(
        id: json['id']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
        followUpAt:
            DateTime.tryParse(json['followUpAt']?.toString() ?? '') ??
            DateTime.now(),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class MarketingLead {
  const MarketingLead({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.gstin,
    required this.source,
    required this.status,
    required this.owner,
    required this.createdAt,
    required this.followUps,
    this.referralId = '',
    this.onboardedClientId = '',
  });

  final String id;
  final String name;
  final String mobile;
  final String email;
  final String gstin;
  final MarketingLeadSource source;
  final MarketingLeadStatus status;
  final String owner;
  final DateTime createdAt;
  final List<MarketingFollowUp> followUps;
  final String referralId;
  final String onboardedClientId;

  MarketingLead copyWith({
    MarketingLeadStatus? status,
    List<MarketingFollowUp>? followUps,
    String? onboardedClientId,
  }) => MarketingLead(
    id: id,
    name: name,
    mobile: mobile,
    email: email,
    gstin: gstin,
    source: source,
    status: status ?? this.status,
    owner: owner,
    createdAt: createdAt,
    followUps: followUps ?? this.followUps,
    referralId: referralId,
    onboardedClientId: onboardedClientId ?? this.onboardedClientId,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'mobile': mobile,
    'email': email,
    'gstin': gstin,
    'source': source.name,
    'status': status.name,
    'owner': owner,
    'createdAt': createdAt.toIso8601String(),
    'followUps': followUps.map((item) => item.toJson()).toList(),
    'referralId': referralId,
    'onboardedClientId': onboardedClientId,
  };

  factory MarketingLead.fromJson(Map<String, dynamic> json) => MarketingLead(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    mobile: json['mobile']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    gstin: json['gstin']?.toString() ?? '',
    source: MarketingLeadSource.values.firstWhere(
      (value) => value.name == json['source']?.toString(),
      orElse: () => MarketingLeadSource.direct,
    ),
    status: MarketingLeadStatus.values.firstWhere(
      (value) => value.name == json['status']?.toString(),
      orElse: () => MarketingLeadStatus.newLead,
    ),
    owner: json['owner']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    followUps: (json['followUps'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) => MarketingFollowUp.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
    referralId: json['referralId']?.toString() ?? '',
    onboardedClientId: json['onboardedClientId']?.toString() ?? '',
  );
}

class MarketingService extends ChangeNotifier {
  MarketingService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String storageKey = 'admin_marketing_leads_v1';
  final SharedPreferences? _preferences;
  final List<MarketingLead> _leads = <MarketingLead>[];

  List<MarketingLead> get leads => List.unmodifiable(_leads);

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final decoded = jsonDecode(preferences.getString(storageKey) ?? '[]');
    _leads
      ..clear()
      ..addAll(
        (decoded as List<dynamic>).whereType<Map>().map(
          (item) => MarketingLead.fromJson(Map<String, dynamic>.from(item)),
        ),
      );
    notifyListeners();
  }

  Future<MarketingLead> addLead({
    required String name,
    required String mobile,
    String email = '',
    String gstin = '',
    String owner = '',
    MarketingLeadSource source = MarketingLeadSource.direct,
    String referralId = '',
  }) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    if (name.trim().isEmpty || cleanMobile.length != 10) {
      throw ArgumentError('Lead name and valid 10-digit mobile are required.');
    }
    final duplicate = _leads.where(
      (lead) =>
          lead.mobile == cleanMobile ||
          (gstin.trim().isNotEmpty && lead.gstin == gstin.trim().toUpperCase()),
    );
    if (duplicate.isNotEmpty) return duplicate.first;
    final lead = MarketingLead(
      id: 'lead-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      mobile: cleanMobile,
      email: email.trim().toLowerCase(),
      gstin: gstin.trim().toUpperCase(),
      source: source,
      status: MarketingLeadStatus.newLead,
      owner: owner.trim(),
      createdAt: DateTime.now(),
      followUps: const <MarketingFollowUp>[],
      referralId: referralId,
    );
    _leads.insert(0, lead);
    await _save();
    notifyListeners();
    return lead;
  }

  Future<int> importReferrals(Iterable<ClientReferral> referrals) async {
    var imported = 0;
    for (final referral in referrals) {
      if (_leads.any((lead) => lead.referralId == referral.id)) continue;
      await addLead(
        name: referral.referredName,
        mobile: referral.mobile,
        gstin: referral.gstin,
        source: MarketingLeadSource.referral,
        referralId: referral.id,
      );
      imported++;
    }
    return imported;
  }

  Future<void> changeStatus(String leadId, MarketingLeadStatus status) async {
    final index = _indexOf(leadId);
    _leads[index] = _leads[index].copyWith(status: status);
    await _save();
    notifyListeners();
  }

  Future<void> addFollowUp({
    required String leadId,
    required String note,
    required DateTime followUpAt,
  }) async {
    if (note.trim().isEmpty) throw ArgumentError('Follow-up note is required.');
    final index = _indexOf(leadId);
    final followUp = MarketingFollowUp(
      id: 'follow-${DateTime.now().microsecondsSinceEpoch}',
      note: note.trim(),
      followUpAt: followUpAt,
      createdAt: DateTime.now(),
    );
    _leads[index] = _leads[index].copyWith(
      status: MarketingLeadStatus.followUp,
      followUps: <MarketingFollowUp>[..._leads[index].followUps, followUp],
    );
    await _save();
    notifyListeners();
  }

  Future<void> markOnboarded(String leadId, String clientId) async {
    if (clientId.trim().isEmpty) throw ArgumentError('Client ID is required.');
    final index = _indexOf(leadId);
    _leads[index] = _leads[index].copyWith(
      status: MarketingLeadStatus.onboarded,
      onboardedClientId: clientId.trim(),
    );
    await _save();
    notifyListeners();
  }

  int _indexOf(String leadId) {
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index < 0) throw StateError('Marketing lead was not found.');
    return index;
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(_leads.map((lead) => lead.toJson()).toList()),
    );
  }
}
