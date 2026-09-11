import 'package:shared_preferences/shared_preferences.dart';

enum BillingMethod {
  inApp,
  manual,
  otherSoftware,
}

extension BillingMethodLabel on BillingMethod {
  String get label {
    switch (this) {
      case BillingMethod.inApp:
        return 'Bill inside Chirag Accounting';
      case BillingMethod.manual:
        return 'Manual Billing (Paper/Printed/Excel)';
      case BillingMethod.otherSoftware:
        return 'Other Software';
    }
  }
}

class IndustrySetupState {
  final bool initialized;
  final String selectedIndustryKey;
  final String selectedIndustryLabel;
  final BillingMethod billingMethod;
  final String selectedSoftware;
  final List<String> installedTemplateComponents;

  const IndustrySetupState({
    required this.initialized,
    this.selectedIndustryKey = '',
    this.selectedIndustryLabel = '',
    this.billingMethod = BillingMethod.inApp,
    this.selectedSoftware = '',
    this.installedTemplateComponents = const <String>[],
  });
}

class IndustrySetupService {
  static const String _initializedKey = 'industry_setup_initialized';
  static const String _industryKey = 'industry_setup_industry_key';
  static const String _industryLabel = 'industry_setup_industry_label';
  static const String _billingMethodKey = 'industry_setup_billing_method';
  static const String _softwareKey = 'industry_setup_software';
  static const String _templateComponentsKey =
      'industry_setup_template_components';

  BillingMethod _billingMethodFromRaw(String raw) {
    for (final value in BillingMethod.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return BillingMethod.inApp;
  }

  List<String> defaultTemplateComponents() {
    return const <String>[
      'Product Categories',
      'Product Master',
      'HSN/SAC Codes',
      'GST Rates',
      'Units',
      'Ledger Groups',
      'Voucher Types',
      'Invoice Design',
      'Reports',
      'Dashboard Widgets',
    ];
  }

  Future<IndustrySetupState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawBilling = prefs.getString(_billingMethodKey) ?? '';
    return IndustrySetupState(
      initialized: prefs.getBool(_initializedKey) ?? false,
      selectedIndustryKey: prefs.getString(_industryKey) ?? '',
      selectedIndustryLabel: prefs.getString(_industryLabel) ?? '',
      billingMethod: _billingMethodFromRaw(rawBilling),
      selectedSoftware: prefs.getString(_softwareKey) ?? '',
      installedTemplateComponents:
          prefs.getStringList(_templateComponentsKey) ?? const <String>[],
    );
  }

  Future<void> saveSelection({
    required String industryKey,
    required String industryLabel,
    required BillingMethod billingMethod,
    String selectedSoftware = '',
    List<String>? installedTemplateComponents,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initializedKey, true);
    await prefs.setString(_industryKey, industryKey);
    await prefs.setString(_industryLabel, industryLabel);
    await prefs.setString(_billingMethodKey, billingMethod.name);
    await prefs.setString(_softwareKey, selectedSoftware);
    await prefs.setStringList(
      _templateComponentsKey,
      installedTemplateComponents ?? defaultTemplateComponents(),
    );
  }
}
