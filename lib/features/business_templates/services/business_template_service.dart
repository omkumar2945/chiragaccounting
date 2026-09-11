import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/business_templates/models/business_template_models.dart';
import 'package:chirag_accounting/features/business_templates/services/business_voucher_configuration_service.dart';

class BusinessTemplateService {
  BusinessTemplateService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _profilePrefix = 'business_template_profile_v1_';
  static const String _historyPrefix = 'business_template_history_v1_';

  final SharedPreferences? _preferences;

  Future<BusinessTemplateProfile?> loadProfile(String clientId) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final encoded = preferences.getString('$_profilePrefix$clientId');
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return BusinessTemplateProfile.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    }
  }

  Future<List<BusinessTemplateProfile>> loadHistory(String clientId) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final encoded =
        preferences.getStringList('$_historyPrefix$clientId') ??
        const <String>[];
    final profiles = <BusinessTemplateProfile>[];
    for (final entry in encoded) {
      try {
        profiles.add(
          BusinessTemplateProfile.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          ),
        );
      } on FormatException {
        continue;
      }
    }
    return profiles;
  }

  Future<List<BusinessTemplateProfile>> loadVersions(String clientId) async {
    final current = await loadProfile(clientId);
    if (current == null) return const <BusinessTemplateProfile>[];
    final versions = <BusinessTemplateProfile>[
      current,
      ...await loadHistory(clientId),
    ]..sort((left, right) => right.version.compareTo(left.version));
    return versions;
  }

  Future<BusinessTemplateProfile> saveProfile({
    required String clientId,
    required List<String> templateKeys,
    required List<String> businessTypes,
    required List<BusinessNature> businessNatures,
    required List<String> enabledDocuments,
    required List<String> enabledFields,
    String customBusinessName = '',
    bool canUpdateExisting = true,
  }) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final current = await loadProfile(clientId);
    if (current != null && !canUpdateExisting) {
      throw StateError(
        'Admin permission is required to change an active business template.',
      );
    }
    final profile = BusinessTemplateProfile(
      templateKeys: _unique(templateKeys),
      businessTypes: _unique(businessTypes),
      businessNatures: businessNatures.toSet().toList(growable: false),
      enabledDocuments: _unique(<String>[
        ...BusinessTemplateCatalog.standardVouchers,
        ...enabledDocuments,
      ]),
      enabledFields: _unique(enabledFields),
      customBusinessName: customBusinessName.trim(),
      version: (current?.version ?? 0) + 1,
      updatedAt: DateTime.now().toUtc(),
    );

    if (current != null) {
      final historyKey = '$_historyPrefix$clientId';
      final history = <String>[
        ...preferences.getStringList(historyKey) ?? const <String>[],
        jsonEncode(current.toJson()),
      ];
      await preferences.setStringList(historyKey, history);
    }
    await preferences.setString(
      '$_profilePrefix$clientId',
      jsonEncode(profile.toJson()),
    );
    await BusinessVoucherConfigurationService(
      preferences: preferences,
    ).generateAndSave(clientId: clientId, profile: profile);
    return profile;
  }

  static List<String> suggestedFields(Iterable<String> templateKeys) {
    return _unique(<String>[
      for (final key in templateKeys)
        ...?BusinessTemplateCatalog.byKey(key)?.invoiceFields,
    ]);
  }

  static List<String> suggestedDocuments(Iterable<String> templateKeys) {
    return _unique(<String>[
      ...BusinessTemplateCatalog.standardVouchers,
      for (final key in templateKeys)
        ...?BusinessTemplateCatalog.byKey(key)?.optionalDocuments,
    ]);
  }

  static List<TaxCodeSuggestion> searchTaxCodes(
    Iterable<String> templateKeys,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    final suggestions = <TaxCodeSuggestion>[
      for (final key in templateKeys)
        ...?BusinessTemplateCatalog.byKey(key)?.taxSuggestions,
    ];
    if (normalized.isEmpty) return suggestions;
    return suggestions
        .where((suggestion) {
          return suggestion.code.toLowerCase().contains(normalized) ||
              suggestion.category.toLowerCase().contains(normalized) ||
              suggestion.description.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  static List<String> _unique(Iterable<String> values) {
    return values
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
