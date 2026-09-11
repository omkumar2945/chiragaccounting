import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/business_templates/models/business_template_models.dart';
import 'package:chirag_accounting/features/business_templates/models/business_voucher_configuration.dart';

class BusinessVoucherConfigurationService {
  BusinessVoucherConfigurationService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _configurationPrefix =
      'business_voucher_configuration_v1_';
  static const Set<String> _coreFieldAliases = <String>{
    'item',
    'item / service',
    'item / service name',
    'menu item',
    'service description',
    'description',
    'quantity',
    'quantity/hours',
    'production qty',
    'unit',
    'uom',
    'meter/piece',
    'rate',
    'purchase rate',
    'sales rate',
    'discount',
    'hsn',
    'sac',
    'hsn/sac',
    'hsn / sac code',
    'gst',
    'gst rate',
    'tax inclusive / exclusive',
  };

  final SharedPreferences? _preferences;

  Future<BusinessVoucherConfiguration?> load(String clientId) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final encoded = preferences.getString('$_configurationPrefix$clientId');
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return BusinessVoucherConfiguration.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    }
  }

  Future<BusinessVoucherConfiguration> generateAndSave({
    required String clientId,
    required BusinessTemplateProfile profile,
  }) async {
    final configuration = generate(clientId: clientId, profile: profile);
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      '$_configurationPrefix$clientId',
      jsonEncode(configuration.toJson()),
    );
    return configuration;
  }

  BusinessVoucherConfiguration generate({
    required String clientId,
    required BusinessTemplateProfile profile,
  }) {
    final templates = profile.templateKeys
        .map(BusinessTemplateCatalog.byKey)
        .whereType<BusinessTemplateDefinition>()
        .toList(growable: false);
    final enabledFields = <String>{
      ...profile.enabledFields,
      for (final template in templates) ...template.invoiceFields,
    };
    final dynamicFields = enabledFields
        .where((field) => !_coreFieldAliases.contains(_normalize(field)))
        .map(
          (field) => VoucherDynamicField(
            key: _fieldKey(field),
            label: field,
            inputType: _inputType(field),
          ),
        )
        .fold(<String, VoucherDynamicField>{}, (fields, field) {
          fields[field.key] = field;
          return fields;
        })
        .values
        .toList(growable: false);
    final taxSuggestions = <String, TaxCodeSuggestion>{
      for (final template in templates)
        for (final suggestion in template.taxSuggestions)
          suggestion.code: suggestion,
    }.values.toList(growable: false);
    final inventoryEnabled = templates.any(
      (template) => template.stockTracking,
    );
    final printFormat = templates.isEmpty
        ? 'A4 Tax Invoice'
        : templates.map((template) => template.defaultPrintFormat).join(' / ');
    final units = _unitsFor(profile, templates);

    const definitions = <(String, String, String)>[
      ('Contra', 'F4', 'ledger'),
      ('Payment', 'F5', 'ledger'),
      ('Receipt', 'F6', 'ledger'),
      ('Journal', 'F7', 'ledger'),
      ('Sales', 'F8', 'item'),
      ('Purchase', 'F9', 'item'),
      ('Credit Note', 'Ctrl+F8', 'item'),
      ('Debit Note', 'Ctrl+F9', 'item'),
      ('Stock Journal', 'Alt+F7', 'stock'),
      ('Manufacturing Journal', 'Alt+F8', 'stock'),
    ];
    final vouchers = definitions
        .map((definition) {
          final category = definition.$3;
          return VoucherTemplateConfiguration(
            voucherType: definition.$1,
            shortcut: definition.$2,
            category: category,
            dynamicFields: category == 'item' ? dynamicFields : const [],
            units: units,
            taxSuggestions: category == 'item' ? taxSuggestions : const [],
            enabled: switch (category) {
              'stock' => inventoryEnabled,
              _ => true,
            },
            inventoryEnabled: inventoryEnabled,
            printFormat: printFormat,
          );
        })
        .toList(growable: false);

    return BusinessVoucherConfiguration(
      clientId: clientId,
      profileVersion: profile.version,
      businessTypes: profile.businessTypes,
      businessNatures: profile.businessNatures
          .map((nature) => nature.name)
          .toList(growable: false),
      vouchers: vouchers,
      documents: profile.enabledDocuments
          .where((document) => !document.contains(RegExp(r'F\d')))
          .toList(growable: false),
      generatedAt: DateTime.now().toUtc(),
    );
  }

  static List<String> _unitsFor(
    BusinessTemplateProfile profile,
    List<BusinessTemplateDefinition> templates,
  ) {
    final fields = templates.expand((template) => template.invoiceFields);
    final normalized = fields.map(_normalize).toSet();
    return <String>{
      'Nos',
      'Pc',
      if (normalized.contains('gross weight') ||
          normalized.contains('net weight')) ...<String>['Gram', 'Kg'],
      if (normalized.contains('meter/piece')) ...<String>['Meter'],
      if (normalized.contains('quantity/hours')) ...<String>['Hour', 'Day'],
      if (profile.businessNatures.contains(
        BusinessNature.contractor,
      )) ...<String>['Sq Ft', 'Running Ft', 'Job'],
      if (profile.businessNatures.contains(BusinessNature.service)) ...<String>[
        'Service',
      ],
    }.toList(growable: false);
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _fieldKey(String label) {
    final words = label
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    if (words.isEmpty) return 'customField';
    return words.first.toLowerCase() +
        words.skip(1).map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        }).join();
  }

  static String _inputType(String label) {
    final normalized = _normalize(label);
    return <String>[
          'weight',
          'charges',
          'wastage',
          'retention',
          'advance',
          'deductions',
          'free qty',
          'stock',
        ].any(normalized.contains)
        ? 'number'
        : 'text';
  }
}
