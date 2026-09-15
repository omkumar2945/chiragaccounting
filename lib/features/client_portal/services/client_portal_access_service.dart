import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/client_portal/registry/client_portal_module_registry.dart';
import 'package:chirag_accounting/features/clients/services/authoritative_client_data_api.dart';

enum ClientPermissionTemplate {
  gst,
  accounting,
  payroll,
  audit,
  incomeTax,
  fullService,
}

extension ClientPermissionTemplateLabel on ClientPermissionTemplate {
  String get displayName => switch (this) {
    ClientPermissionTemplate.gst => 'GST Service',
    ClientPermissionTemplate.accounting => 'Accounting Service',
    ClientPermissionTemplate.payroll => 'Payroll Service',
    ClientPermissionTemplate.audit => 'Audit Service',
    ClientPermissionTemplate.incomeTax => 'Income Tax Service',
    ClientPermissionTemplate.fullService => 'Full Service',
  };
}

class ClientPortalAccessService extends ChangeNotifier {
  ClientPortalAccessService({
    SharedPreferences? preferences,
    AuthoritativeClientDataApi? clientDataApi,
    bool? useRemoteApi,
  }) : _preferences = preferences,
       _clientDataApi = clientDataApi ?? AuthoritativeClientDataApi(),
       _useRemoteApi = useRemoteApi ?? !ApiConstants.useMockApi;

  static const String storageKey = 'client_portal_access_profiles_v1';

  final SharedPreferences? _preferences;
  final AuthoritativeClientDataApi _clientDataApi;
  final bool _useRemoteApi;
  final Map<String, ClientPortalAccessProfile> _profiles =
      <String, ClientPortalAccessProfile>{};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<ClientModuleDefinition> get registeredModules =>
      ClientPortalModuleRegistry.enabledModules;

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final encoded = preferences.getString(storageKey);
    _profiles
      ..clear()
      ..addAll(_decode(encoded));
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> refreshAuthoritative(String clientId) async {
    if (!_useRemoteApi || clientId.trim().isEmpty) return;
    try {
      cacheAuthoritativeAggregate(
        await _clientDataApi.loadClient(clientId),
        notify: false,
      );
      await _save();
    } catch (error) {
      debugPrint('Unable to refresh client portal access: $error');
    }
  }

  void cacheAuthoritativeAggregate(
    Map<String, dynamic> aggregate, {
    bool notify = true,
  }) {
    final client = aggregate['client'];
    final access = aggregate['access'];
    if (client is! Map || access is! Map) return;
    final clientId = client['id']?.toString().trim() ?? '';
    if (clientId.isEmpty) return;

    final profile = ClientPortalAccessProfile.fromJson(<String, dynamic>{
      ...Map<String, dynamic>.from(access),
      'clientId': clientId,
    });
    _profiles[clientId] = profile;
    if (notify) notifyListeners();
  }

  ClientPortalAccessProfile profileFor(String clientId) {
    return _profiles[clientId] ?? _defaultProfile(clientId);
  }

  List<ClientModuleDefinition> visibleModules(
    String clientId,
    ClientPortalPlatform platform,
  ) {
    final profile = profileFor(clientId);
    if (!profile.loginEnabled || profile.accountLocked) return const [];
    if (platform == ClientPortalPlatform.web && !profile.webLoginEnabled) {
      return const [];
    }
    if (platform != ClientPortalPlatform.web && !profile.mobileLoginEnabled) {
      return const [];
    }
    return registeredModules
        .where((definition) {
          final access = moduleAccess(clientId, definition.id);
          return definition.enabled &&
              _moduleAllowedInBillingMode(profile.billingMode, definition.id) &&
              definition.supports(platform) &&
              access.enabled &&
              access.visible &&
              access.featureEnabled &&
              access.supports(platform) &&
              _subscriptionAllows(profile.subscriptionPlan, definition);
        })
        .toList(growable: false);
  }

  bool _moduleAllowedInBillingMode(
    ClientBillingMode billingMode,
    String moduleId,
  ) {
    if (billingMode != ClientBillingMode.imageUploadAccountantEntry) {
      return true;
    }
    const imageOnlyBlocked = <String>{'sales', 'invoicing', 'purchase'};
    return !imageOnlyBlocked.contains(moduleId);
  }

  ClientModuleAccess moduleAccess(String clientId, String moduleId) {
    final stored = profileFor(clientId).modules[moduleId];
    if (stored != null) return stored;
    final definition = ClientPortalModuleRegistry.find(moduleId);
    return _defaultAccess(definition);
  }

  bool canPerform(
    String clientId,
    String moduleId,
    ClientModuleAction action, {
    required ClientPortalPlatform platform,
  }) {
    final visible = visibleModules(
      clientId,
      platform,
    ).any((module) => module.id == moduleId);
    return visible && moduleAccess(clientId, moduleId).actions.contains(action);
  }

  bool widgetEnabled(String clientId, String widgetId) {
    return profileFor(clientId).dashboardWidgets[widgetId] ?? true;
  }

  List<ClientDashboardWidgetDefinition> visibleDashboardWidgets(
    String clientId,
    ClientPortalPlatform platform,
  ) {
    final visibleModuleIds = visibleModules(
      clientId,
      platform,
    ).map((module) => module.id).toSet();
    return ClientPortalModuleRegistry.dashboardWidgets
        .where((widget) {
          return widgetEnabled(clientId, widget.id) &&
              (widget.requiredModuleId == null ||
                  visibleModuleIds.contains(widget.requiredModuleId));
        })
        .toList(growable: false);
  }

  Future<void> updateLoginAccess(
    String clientId, {
    bool? loginEnabled,
    bool? mobileLoginEnabled,
    bool? webLoginEnabled,
    bool? twoFactorRequired,
    bool? accountLocked,
    String? subscriptionPlan,
  }) async {
    await _updateProfile(
      clientId,
      (current) => current.copyWith(
        loginEnabled: loginEnabled,
        mobileLoginEnabled: mobileLoginEnabled,
        webLoginEnabled: webLoginEnabled,
        twoFactorRequired: twoFactorRequired,
        accountLocked: accountLocked,
        subscriptionPlan: subscriptionPlan,
      ),
    );
  }

  Future<void> updateWorkflowAccess(
    String clientId, {
    ClientBillingMode? billingMode,
    ClientAccountingMode? accountingMode,
    ClientVoucherEntryMode? purchaseEntryMode,
    ClientVoucherEntryMode? salesEntryMode,
  }) async {
    await _updateProfile(clientId, (current) {
      final nextBillingMode = billingMode ?? current.billingMode;
      final modules = <String, ClientModuleAccess>{...current.modules};

      // Keep menus aligned with selected billing model.
      switch (nextBillingMode) {
        case ClientBillingMode.imageUploadAccountantEntry:
          _setModuleEnabled(modules, 'sales', false);
          _setModuleEnabled(modules, 'purchase', false);
          _setModuleEnabled(modules, 'uploads', true);
          _setModuleEnabled(modules, 'document_hub', true);
          _setModuleEnabled(modules, 'documents', true);
          _setModuleEnabled(modules, 'ocr', true);
          _setModuleEnabled(modules, 'voucher_upload', true);
          _setModuleEnabled(modules, 'chat', true);
        case ClientBillingMode.fullBillingSoftware:
          _setModuleEnabled(modules, 'sales', true);
          _setModuleEnabled(modules, 'purchase', true);
          _setModuleEnabled(modules, 'uploads', true);
          _setModuleEnabled(modules, 'document_hub', true);
          _setModuleEnabled(modules, 'documents', true);
          _setModuleEnabled(modules, 'ocr', true);
          _setModuleEnabled(modules, 'voucher_upload', true);
        case ClientBillingMode.hybrid:
          _setModuleEnabled(modules, 'sales', true);
          _setModuleEnabled(modules, 'purchase', true);
          _setModuleEnabled(modules, 'uploads', true);
          _setModuleEnabled(modules, 'document_hub', true);
          _setModuleEnabled(modules, 'documents', true);
          _setModuleEnabled(modules, 'ocr', true);
          _setModuleEnabled(modules, 'voucher_upload', true);
          _setModuleEnabled(modules, 'chat', true);
      }

      return current.copyWith(
        billingMode: nextBillingMode,
        accountingMode: accountingMode,
        purchaseEntryMode: purchaseEntryMode,
        salesEntryMode: salesEntryMode,
        modules: modules,
      );
    });
  }

  void _setModuleEnabled(
    Map<String, ClientModuleAccess> modules,
    String moduleId,
    bool enabled,
  ) {
    final existing = modules[moduleId];
    if (existing != null) {
      modules[moduleId] = existing.copyWith(enabled: enabled);
      return;
    }
    final definition = ClientPortalModuleRegistry.find(moduleId);
    if (definition == null) return;
    final base = _defaultAccess(definition);
    modules[moduleId] = base.copyWith(enabled: enabled);
  }

  Future<void> updateModuleAccess(
    String clientId,
    ClientModuleAccess access,
  ) async {
    if (ClientPortalModuleRegistry.find(access.moduleId) == null) {
      throw FormatException('Unknown client module: ${access.moduleId}.');
    }
    await _updateProfile(
      clientId,
      (current) => current.copyWith(
        modules: <String, ClientModuleAccess>{
          ...current.modules,
          access.moduleId: access,
        },
      ),
    );
  }

  Future<void> setDashboardWidget(
    String clientId,
    String widgetId,
    bool enabled,
  ) async {
    await _updateProfile(
      clientId,
      (current) => current.copyWith(
        dashboardWidgets: <String, bool>{
          ...current.dashboardWidgets,
          widgetId: enabled,
        },
      ),
    );
  }

  Future<void> updateDocumentHubAccess(
    String clientId,
    ClientDocumentHubAccess access,
  ) async {
    await _updateProfile(
      clientId,
      (current) => current.copyWith(documentHubAccess: access),
    );
  }

  Future<void> applyTemplate(
    Iterable<String> clientIds,
    ClientPermissionTemplate template,
  ) async {
    for (final clientId in clientIds.toSet()) {
      await _updateProfile(
        clientId,
        (current) => _profileWithTemplate(current, template),
      );
    }
  }

  Future<void> syncAssignedServices(
    String clientId,
    Iterable<String> services,
  ) async {
    final normalized = services
        .map((service) => service.trim().toLowerCase())
        .where((service) => service.isNotEmpty)
        .toSet();
    await _updateProfile(clientId, (current) {
      var next = current;
      for (final template in ClientPermissionTemplate.values) {
        if (template == ClientPermissionTemplate.fullService) continue;
        final keywords = switch (template) {
          ClientPermissionTemplate.gst => const <String>{'gst'},
          ClientPermissionTemplate.accounting => const <String>{
            'accounting',
            'accounts',
          },
          ClientPermissionTemplate.payroll => const <String>{
            'payroll',
            'salary',
          },
          ClientPermissionTemplate.audit => const <String>{'audit'},
          ClientPermissionTemplate.incomeTax => const <String>{
            'income tax',
            'itr',
          },
          ClientPermissionTemplate.fullService => const <String>{},
        };
        if (normalized.any(
          (service) => keywords.any((keyword) => service.contains(keyword)),
        )) {
          next = _profileWithTemplate(next, template);
        }
      }
      return next;
    });
  }

  ClientPortalAccessProfile _defaultProfile(String clientId) {
    return ClientPortalAccessProfile(
      clientId: clientId,
      modules: <String, ClientModuleAccess>{
        for (final definition in registeredModules)
          definition.id: _defaultAccess(definition),
      },
      dashboardWidgets: <String, bool>{
        for (final widget in ClientPortalModuleRegistry.dashboardWidgets)
          widget.id: widget.defaultEnabled,
      },
    );
  }

  ClientModuleAccess _defaultAccess(ClientModuleDefinition? definition) {
    final enabled = definition?.defaultEnabled ?? false;
    return ClientModuleAccess(
      moduleId: definition?.id ?? '',
      enabled: enabled,
      mobileAccess: definition?.mobileSupported ?? false,
      webAccess: definition?.webSupported ?? false,
      tabletAccess: definition?.tabletSupported ?? false,
      actions: enabled
          ? _templateActions(
              definition?.permissionType ?? ClientModulePermissionType.standard,
            )
          : const <ClientModuleAction>{},
    );
  }

  Future<void> _updateProfile(
    String clientId,
    ClientPortalAccessProfile Function(ClientPortalAccessProfile current)
    update,
  ) async {
    final current = await _profileForMutation(clientId);
    await _persistProfile(update(current));
  }

  Future<ClientPortalAccessProfile> _profileForMutation(String clientId) async {
    if (!_useRemoteApi) return profileFor(clientId);
    cacheAuthoritativeAggregate(
      await _clientDataApi.loadClient(clientId),
      notify: false,
    );
    return profileFor(clientId);
  }

  Future<void> _persistProfile(ClientPortalAccessProfile profile) async {
    if (!_useRemoteApi) {
      _profiles[profile.clientId] = profile;
      await _save();
      return;
    }
    final payload = profile.toJson()..remove('clientId');
    cacheAuthoritativeAggregate(
      await _clientDataApi.updateAccess(profile.clientId, payload),
      notify: false,
    );
    await _save();
  }

  ClientPortalAccessProfile _profileWithTemplate(
    ClientPortalAccessProfile current,
    ClientPermissionTemplate template,
  ) {
    final modules = <String, ClientModuleAccess>{...current.modules};
    for (final moduleId in _templateModules(template)) {
      final definition = ClientPortalModuleRegistry.find(moduleId);
      if (definition == null) continue;
      final existing = modules[moduleId] ?? _defaultAccess(definition);
      modules[moduleId] = existing.copyWith(
        enabled: true,
        actions: _templateActions(definition.permissionType),
      );
    }
    return current.copyWith(modules: modules);
  }

  Set<String> _templateModules(ClientPermissionTemplate template) =>
      switch (template) {
        ClientPermissionTemplate.gst => const <String>{
          'gst',
          'eway_bill',
          'documents',
          'uploads',
          'reports',
        },
        ClientPermissionTemplate.accounting => const <String>{
          'sales',
          'invoicing',
          'purchase',
          'voucher_upload',
          'ledger',
          'documents',
          'reports',
          'bank',
          'loan_planner',
          'investment_planner',
        },
        ClientPermissionTemplate.payroll => const <String>{
          'payroll',
          'documents',
          'reports',
        },
        ClientPermissionTemplate.audit => const <String>{
          'audit',
          'documents',
          'reports',
          'approvals',
        },
        ClientPermissionTemplate.incomeTax => const <String>{
          'income_tax',
          'documents',
          'reports',
        },
        ClientPermissionTemplate.fullService => <String>{
          for (final module in registeredModules) module.id,
        },
      };

  Set<ClientModuleAction> _templateActions(
    ClientModulePermissionType permissionType,
  ) => switch (permissionType) {
    ClientModulePermissionType.readOnly => const <ClientModuleAction>{
      ClientModuleAction.view,
      ClientModuleAction.download,
    },
    ClientModulePermissionType.uploadOnly => const <ClientModuleAction>{
      ClientModuleAction.view,
      ClientModuleAction.create,
      ClientModuleAction.upload,
      ClientModuleAction.download,
    },
    ClientModulePermissionType.standard => const <ClientModuleAction>{
      ClientModuleAction.view,
      ClientModuleAction.create,
      ClientModuleAction.upload,
      ClientModuleAction.edit,
      ClientModuleAction.download,
    },
    ClientModulePermissionType.administrative =>
      ClientModuleAction.values.toSet(),
  };

  bool _subscriptionAllows(
    String currentPlan,
    ClientModuleDefinition definition,
  ) {
    final requiredPlan = definition.subscriptionRequired;
    if (requiredPlan == null || requiredPlan.isEmpty) return true;
    const ranks = <String, int>{'standard': 0, 'premium': 1, 'enterprise': 2};
    return (ranks[currentPlan.toLowerCase()] ?? 0) >=
        (ranks[requiredPlan.toLowerCase()] ?? 0);
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(
        _profiles.values
            .map((profile) => profile.toJson())
            .toList(growable: false),
      ),
    );
    notifyListeners();
  }

  Map<String, ClientPortalAccessProfile> _decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return <String, ClientPortalAccessProfile>{};
    }
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final profiles = decoded.whereType<Map>().map(
        (value) => ClientPortalAccessProfile.fromJson(
          Map<String, dynamic>.from(value),
        ),
      );
      return <String, ClientPortalAccessProfile>{
        for (final profile in profiles)
          if (profile.clientId.isNotEmpty) profile.clientId: profile,
      };
    } catch (_) {
      return <String, ClientPortalAccessProfile>{};
    }
  }
}
