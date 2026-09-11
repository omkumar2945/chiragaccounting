import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/business_templates/models/business_template_models.dart';
import 'package:chirag_accounting/features/business_templates/models/business_voucher_configuration.dart';
import 'package:chirag_accounting/features/business_templates/presentation/pages/business_template_setup_screen.dart';
import 'package:chirag_accounting/features/business_templates/services/business_template_service.dart';
import 'package:chirag_accounting/features/business_templates/services/business_voucher_configuration_service.dart';
import 'package:chirag_accounting/features/clients/Billing/presentation/widgets/sales_voucher_web_embed.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

class SalesVoucherSystemScreen extends StatefulWidget {
  const SalesVoucherSystemScreen({
    super.key,
    this.initialVoucherType,
  });

  static const String voucherSystemPath = 'sales-voucher/index.html';

  final String? initialVoucherType;

  @override
  State<SalesVoucherSystemScreen> createState() =>
      _SalesVoucherSystemScreenState();
}

class _SalesVoucherSystemScreenState extends State<SalesVoucherSystemScreen> {
  final BusinessTemplateService _templateService = BusinessTemplateService();
  final BusinessVoucherConfigurationService _voucherConfigurationService =
      BusinessVoucherConfigurationService();
  BusinessTemplateProfile? _profile;
  BusinessVoucherConfiguration? _voucherConfiguration;
  List<BusinessTemplateProfile> _versions = const <BusinessTemplateProfile>[];
  String? _loadedClientId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clientId =
        context.read<AuthController>().currentUser?.id ?? 'anonymous';
    if (_loadedClientId != clientId) {
      _loadedClientId = clientId;
      _loadConfiguration(clientId);
    }
  }

  Future<void> _loadConfiguration(String clientId) async {
    final profile = await _templateService.loadProfile(clientId);
    final versions = await _templateService.loadVersions(clientId);
    if (profile == null) {
      if (mounted) {
        setState(() {
          _profile = null;
          _voucherConfiguration = null;
          _versions = const <BusinessTemplateProfile>[];
        });
      }
      return;
    }
    final configuration =
        await _voucherConfigurationService.load(clientId) ??
        await _voucherConfigurationService.generateAndSave(
          clientId: clientId,
          profile: profile,
        );
    if (mounted) {
      setState(() {
        _profile = profile;
        _voucherConfiguration = configuration;
        _versions = versions;
      });
    }
  }

  String _templateLabel(BusinessTemplateProfile profile) {
    final name = profile.customBusinessName.trim().isNotEmpty
        ? profile.customBusinessName.trim()
        : profile.businessTypes.join(', ');
    return name.isEmpty ? 'Template v${profile.version}' : '$name (v${profile.version})';
  }

  void _selectVersion(String clientId, int version) {
    final profile = _versions.singleWhere(
      (candidate) => candidate.version == version,
    );
    setState(() {
      _profile = profile;
      _voucherConfiguration = _voucherConfigurationService.generate(
        clientId: clientId,
        profile: profile,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final salesService = Provider.of<SalesService?>(context) ?? SalesService();
    final purchaseService =
        Provider.of<PurchaseService?>(context) ?? PurchaseService();
    final clientId = user?.id ?? 'anonymous';
    final voucherSystemUri = Uri(
      path: SalesVoucherSystemScreen.voucherSystemPath,
      queryParameters: <String, String>{
        if (user != null) ...<String, String>{
          'clientId': user.id,
          'clientName': user.name,
          'firmName': user.firmName,
          'email': user.email,
          'mobile': user.mobile,
        },
        if (widget.initialVoucherType != null)
          'initialVoucherType': widget.initialVoucherType!,
        if (_profile != null) ...<String, String>{
          'businessTemplates': _profile!.templateKeys.join(','),
          'businessNatures': _profile!.businessNatures
              .map((value) => value.name)
              .join(','),
          'enabledDocuments': _profile!.enabledDocuments.join(','),
          'enabledFields': _profile!.enabledFields.join(','),
          'templateVersion': '${_profile!.version}',
        },
        if (_voucherConfiguration != null)
          'voucherConfiguration': jsonEncode(_voucherConfiguration!.toJson()),
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(user?.firmName ?? 'Billing'),
        backgroundColor: const Color(0xFF123C69),
        foregroundColor: Colors.white,
        actions: <Widget>[
          if (_versions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: const ValueKey('business-template-version-selector'),
                  value: _profile?.version,
                  dropdownColor: const Color(0xFF123C69),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  items: _versions
                      .map(
                        (profile) => DropdownMenuItem<int>(
                          value: profile.version,
                          child: Text(_templateLabel(profile)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (version) {
                    if (version != null) _selectVersion(clientId, version);
                  },
                ),
              ),
            ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey<String>(voucherSystemUri.toString()),
        child: buildSalesVoucherWebEmbed(
          voucherSystemUri.toString(),
          salesService: salesService,
          purchaseService: purchaseService,
          onOpenBusinessTemplate: () => _openBusinessTemplate(
            clientId: clientId,
            clientName: user?.firmName ?? user?.name ?? '',
            canManageExistingTemplate: switch (user?.role) {
              UserRole.superAdmin ||
              UserRole.admin ||
              UserRole.firmAdmin => true,
              _ => false,
            },
            hasVoucherEntries:
                salesService.totalInvoices > 0 ||
                purchaseService.totalBills > 0,
          ),
        ),
      ),
    );
  }

  Future<void> _openBusinessTemplate({
    required String clientId,
    required String clientName,
    required bool canManageExistingTemplate,
    required bool hasVoucherEntries,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Universal Business Template System'),
            backgroundColor: const Color(0xFF123C69),
            foregroundColor: Colors.white,
          ),
          body: BusinessTemplateSetupScreen(
            clientId: clientId,
            clientName: clientName,
            canManageExistingTemplate: canManageExistingTemplate,
            hasVoucherEntries: hasVoucherEntries,
          ),
        ),
      ),
    );
    if (mounted) await _loadConfiguration(clientId);
  }
}
