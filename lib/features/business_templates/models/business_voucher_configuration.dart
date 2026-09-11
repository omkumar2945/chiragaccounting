import 'package:chirag_accounting/features/business_templates/models/business_template_models.dart';

class VoucherDynamicField {
  const VoucherDynamicField({
    required this.key,
    required this.label,
    this.inputType = 'text',
  });

  final String key;
  final String label;
  final String inputType;

  Map<String, Object> toJson() => <String, Object>{
    'key': key,
    'label': label,
    'inputType': inputType,
  };

  factory VoucherDynamicField.fromJson(Map<String, dynamic> json) {
    return VoucherDynamicField(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      inputType: json['inputType'] as String? ?? 'text',
    );
  }
}

class VoucherTemplateConfiguration {
  const VoucherTemplateConfiguration({
    required this.voucherType,
    required this.shortcut,
    required this.category,
    required this.dynamicFields,
    required this.units,
    required this.taxSuggestions,
    required this.enabled,
    required this.inventoryEnabled,
    required this.printFormat,
  });

  final String voucherType;
  final String shortcut;
  final String category;
  final List<VoucherDynamicField> dynamicFields;
  final List<String> units;
  final List<TaxCodeSuggestion> taxSuggestions;
  final bool enabled;
  final bool inventoryEnabled;
  final String printFormat;

  Map<String, Object> toJson() => <String, Object>{
    'voucherType': voucherType,
    'shortcut': shortcut,
    'category': category,
    'dynamicFields': dynamicFields.map((field) => field.toJson()).toList(),
    'units': units,
    'taxSuggestions': taxSuggestions
        .map(
          (suggestion) => <String, Object>{
            'category': suggestion.category,
            'code': suggestion.code,
            'gstRate': suggestion.gstRate,
            'description': suggestion.description,
          },
        )
        .toList(),
    'enabled': enabled,
    'inventoryEnabled': inventoryEnabled,
    'printFormat': printFormat,
  };

  factory VoucherTemplateConfiguration.fromJson(Map<String, dynamic> json) {
    return VoucherTemplateConfiguration(
      voucherType: json['voucherType'] as String? ?? '',
      shortcut: json['shortcut'] as String? ?? '',
      category: json['category'] as String? ?? 'item',
      dynamicFields: (json['dynamicFields'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (field) =>
                VoucherDynamicField.fromJson(Map<String, dynamic>.from(field)),
          )
          .toList(growable: false),
      units: (json['units'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      taxSuggestions: (json['taxSuggestions'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final suggestion = Map<String, dynamic>.from(raw);
            return TaxCodeSuggestion(
              category: suggestion['category'] as String? ?? '',
              code: suggestion['code'] as String? ?? '',
              gstRate: (suggestion['gstRate'] as num?)?.toDouble() ?? 0,
              description: suggestion['description'] as String? ?? '',
            );
          })
          .toList(growable: false),
      enabled: json['enabled'] as bool? ?? true,
      inventoryEnabled: json['inventoryEnabled'] as bool? ?? true,
      printFormat: json['printFormat'] as String? ?? 'A4 Tax Invoice',
    );
  }
}

class BusinessVoucherConfiguration {
  const BusinessVoucherConfiguration({
    required this.clientId,
    required this.profileVersion,
    required this.businessTypes,
    required this.businessNatures,
    required this.vouchers,
    required this.documents,
    required this.generatedAt,
  });

  final String clientId;
  final int profileVersion;
  final List<String> businessTypes;
  final List<String> businessNatures;
  final List<VoucherTemplateConfiguration> vouchers;
  final List<String> documents;
  final DateTime generatedAt;

  Map<String, Object> toJson() => <String, Object>{
    'clientId': clientId,
    'profileVersion': profileVersion,
    'businessTypes': businessTypes,
    'businessNatures': businessNatures,
    'vouchers': vouchers.map((voucher) => voucher.toJson()).toList(),
    'documents': documents,
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory BusinessVoucherConfiguration.fromJson(Map<String, dynamic> json) {
    return BusinessVoucherConfiguration(
      clientId: json['clientId'] as String? ?? '',
      profileVersion: json['profileVersion'] as int? ?? 0,
      businessTypes: (json['businessTypes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      businessNatures: (json['businessNatures'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      vouchers: (json['vouchers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (voucher) => VoucherTemplateConfiguration.fromJson(
              Map<String, dynamic>.from(voucher),
            ),
          )
          .toList(growable: false),
      documents: (json['documents'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
