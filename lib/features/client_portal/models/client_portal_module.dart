import 'package:flutter/material.dart';

enum ClientPortalPlatform { mobile, web, tablet }

enum ClientModuleAction {
  view,
  create,
  upload,
  edit,
  approve,
  download,
  delete,
  admin,
}

enum ClientModulePermissionType {
  standard,
  readOnly,
  uploadOnly,
  administrative,
}

enum ClientBillingMode {
  imageUploadAccountantEntry,
  fullBillingSoftware,
  hybrid,
}

extension ClientBillingModeLabel on ClientBillingMode {
  String get displayName => switch (this) {
    ClientBillingMode.imageUploadAccountantEntry =>
      'Image Upload + Accountant Entry',
    ClientBillingMode.fullBillingSoftware => 'Complete Billing Software',
    ClientBillingMode.hybrid => 'Hybrid (Upload + Billing)',
  };
}

enum ClientAccountingMode { accountsOnly, accountsWithInventory }

enum ClientVoucherEntryMode { manual, ocr, both }

enum ClientDocumentIntakeChannel {
  mobileApp,
  whatsapp,
  email,
  cloudSync,
}

extension ClientDocumentIntakeChannelLabel on ClientDocumentIntakeChannel {
  String get displayName => switch (this) {
    ClientDocumentIntakeChannel.mobileApp => 'Mobile App Upload',
    ClientDocumentIntakeChannel.whatsapp => 'WhatsApp Upload',
    ClientDocumentIntakeChannel.email => 'Email Inbox Import',
    ClientDocumentIntakeChannel.cloudSync => 'Cloud Folder Sync',
  };
}

enum ClientDocumentQueueBucket {
  sales,
  purchase,
  expense,
  receipt,
  payment,
  creditNote,
  debitNote,
  bank,
  import,
  review,
}

extension ClientDocumentQueueBucketLabel on ClientDocumentQueueBucket {
  String get displayName => switch (this) {
    ClientDocumentQueueBucket.sales => 'Sales Pending Queue',
    ClientDocumentQueueBucket.purchase => 'Purchase Pending Queue',
    ClientDocumentQueueBucket.expense => 'Expense Pending Queue',
    ClientDocumentQueueBucket.receipt => 'Receipt Pending Queue',
    ClientDocumentQueueBucket.payment => 'Payment Pending Queue',
    ClientDocumentQueueBucket.creditNote => 'Credit Note Pending Queue',
    ClientDocumentQueueBucket.debitNote => 'Debit Note Pending Queue',
    ClientDocumentQueueBucket.bank => 'Bank Statement Pending Queue',
    ClientDocumentQueueBucket.import => 'Import Verification Queue',
    ClientDocumentQueueBucket.review => 'General Review Queue',
  };
}

class ClientModuleDefinition {
  const ClientModuleDefinition({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    required this.route,
    required this.category,
    required this.sortOrder,
    required this.builder,
    this.mobileSupported = true,
    this.webSupported = true,
    this.tabletSupported = true,
    this.enabled = true,
    this.defaultEnabled = false,
    this.permissionType = ClientModulePermissionType.standard,
    this.subscriptionRequired,
    this.featureFlag = '',
    this.beta = false,
    this.dashboardWidgetId,
  });

  final String id;
  final String name;
  final String displayName;
  final IconData icon;
  final String route;
  final String category;
  final int sortOrder;
  final WidgetBuilder builder;
  final bool mobileSupported;
  final bool webSupported;
  final bool tabletSupported;
  final bool enabled;
  final bool defaultEnabled;
  final ClientModulePermissionType permissionType;
  final String? subscriptionRequired;
  final String featureFlag;
  final bool beta;
  final String? dashboardWidgetId;

  bool supports(ClientPortalPlatform platform) => switch (platform) {
    ClientPortalPlatform.mobile => mobileSupported,
    ClientPortalPlatform.web => webSupported,
    ClientPortalPlatform.tablet => tabletSupported,
  };
}

class ClientDashboardWidgetDefinition {
  const ClientDashboardWidgetDefinition({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.sortOrder,
    this.requiredModuleId,
    this.defaultEnabled = true,
  });

  final String id;
  final String displayName;
  final IconData icon;
  final int sortOrder;
  final String? requiredModuleId;
  final bool defaultEnabled;
}

class ClientModuleAccess {
  const ClientModuleAccess({
    required this.moduleId,
    this.enabled = false,
    this.mobileAccess = true,
    this.webAccess = true,
    this.tabletAccess = true,
    this.visible = true,
    this.featureEnabled = true,
    this.actions = const <ClientModuleAction>{ClientModuleAction.view},
  });

  final String moduleId;
  final bool enabled;
  final bool mobileAccess;
  final bool webAccess;
  final bool tabletAccess;
  final bool visible;
  final bool featureEnabled;
  final Set<ClientModuleAction> actions;

  bool supports(ClientPortalPlatform platform) => switch (platform) {
    ClientPortalPlatform.mobile => mobileAccess,
    ClientPortalPlatform.web => webAccess,
    ClientPortalPlatform.tablet => tabletAccess,
  };

  ClientModuleAccess copyWith({
    bool? enabled,
    bool? mobileAccess,
    bool? webAccess,
    bool? tabletAccess,
    bool? visible,
    bool? featureEnabled,
    Set<ClientModuleAction>? actions,
  }) {
    return ClientModuleAccess(
      moduleId: moduleId,
      enabled: enabled ?? this.enabled,
      mobileAccess: mobileAccess ?? this.mobileAccess,
      webAccess: webAccess ?? this.webAccess,
      tabletAccess: tabletAccess ?? this.tabletAccess,
      visible: visible ?? this.visible,
      featureEnabled: featureEnabled ?? this.featureEnabled,
      actions: actions ?? this.actions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'moduleId': moduleId,
    'enabled': enabled,
    'mobileAccess': mobileAccess,
    'webAccess': webAccess,
    'tabletAccess': tabletAccess,
    'visible': visible,
    'featureEnabled': featureEnabled,
    'actions': actions.map((action) => action.name).toList(growable: false),
  };

  factory ClientModuleAccess.fromJson(Map<String, dynamic> json) {
    final actionNames = (json['actions'] as List<dynamic>? ?? const <dynamic>[])
        .map((value) => value.toString())
        .toSet();
    return ClientModuleAccess(
      moduleId: json['moduleId']?.toString() ?? '',
      enabled: json['enabled'] as bool? ?? false,
      mobileAccess: json['mobileAccess'] as bool? ?? true,
      webAccess: json['webAccess'] as bool? ?? true,
      tabletAccess: json['tabletAccess'] as bool? ?? true,
      visible: json['visible'] as bool? ?? true,
      featureEnabled: json['featureEnabled'] as bool? ?? true,
      actions: ClientModuleAction.values
          .where((action) => actionNames.contains(action.name))
          .toSet(),
    );
  }
}

class ClientDocumentHubAccess {
  const ClientDocumentHubAccess({
    this.enableWhatsAppUpload = true,
    this.autoOcr = true,
    this.autoClassification = true,
    this.allowVoiceNotes = true,
    this.autoReply = true,
    this.enableWhatsAppCommands = true,
    this.enableAiChat = true,
    this.documentStatusNotifications = true,
    this.dailyReminder = false,
    this.monthlyReminder = true,
    this.autoFollowUpMissingBills = true,
    this.enableEmailImport = false,
    this.enableCloudSync = false,
  });

  final bool enableWhatsAppUpload;
  final bool autoOcr;
  final bool autoClassification;
  final bool allowVoiceNotes;
  final bool autoReply;
  final bool enableWhatsAppCommands;
  final bool enableAiChat;
  final bool documentStatusNotifications;
  final bool dailyReminder;
  final bool monthlyReminder;
  final bool autoFollowUpMissingBills;
  final bool enableEmailImport;
  final bool enableCloudSync;

  ClientDocumentHubAccess copyWith({
    bool? enableWhatsAppUpload,
    bool? autoOcr,
    bool? autoClassification,
    bool? allowVoiceNotes,
    bool? autoReply,
    bool? enableWhatsAppCommands,
    bool? enableAiChat,
    bool? documentStatusNotifications,
    bool? dailyReminder,
    bool? monthlyReminder,
    bool? autoFollowUpMissingBills,
    bool? enableEmailImport,
    bool? enableCloudSync,
  }) {
    return ClientDocumentHubAccess(
      enableWhatsAppUpload: enableWhatsAppUpload ?? this.enableWhatsAppUpload,
      autoOcr: autoOcr ?? this.autoOcr,
      autoClassification: autoClassification ?? this.autoClassification,
      allowVoiceNotes: allowVoiceNotes ?? this.allowVoiceNotes,
      autoReply: autoReply ?? this.autoReply,
      enableWhatsAppCommands:
          enableWhatsAppCommands ?? this.enableWhatsAppCommands,
      enableAiChat: enableAiChat ?? this.enableAiChat,
      documentStatusNotifications:
          documentStatusNotifications ?? this.documentStatusNotifications,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      monthlyReminder: monthlyReminder ?? this.monthlyReminder,
      autoFollowUpMissingBills:
          autoFollowUpMissingBills ?? this.autoFollowUpMissingBills,
      enableEmailImport: enableEmailImport ?? this.enableEmailImport,
      enableCloudSync: enableCloudSync ?? this.enableCloudSync,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enableWhatsAppUpload': enableWhatsAppUpload,
    'autoOcr': autoOcr,
    'autoClassification': autoClassification,
    'allowVoiceNotes': allowVoiceNotes,
    'autoReply': autoReply,
    'enableWhatsAppCommands': enableWhatsAppCommands,
    'enableAiChat': enableAiChat,
    'documentStatusNotifications': documentStatusNotifications,
    'dailyReminder': dailyReminder,
    'monthlyReminder': monthlyReminder,
    'autoFollowUpMissingBills': autoFollowUpMissingBills,
    'enableEmailImport': enableEmailImport,
    'enableCloudSync': enableCloudSync,
  };

  factory ClientDocumentHubAccess.fromJson(Map<String, dynamic> json) {
    return ClientDocumentHubAccess(
      enableWhatsAppUpload: json['enableWhatsAppUpload'] as bool? ?? true,
      autoOcr: json['autoOcr'] as bool? ?? true,
      autoClassification: json['autoClassification'] as bool? ?? true,
      allowVoiceNotes: json['allowVoiceNotes'] as bool? ?? true,
      autoReply: json['autoReply'] as bool? ?? true,
      enableWhatsAppCommands: json['enableWhatsAppCommands'] as bool? ?? true,
      enableAiChat: json['enableAiChat'] as bool? ?? true,
      documentStatusNotifications:
          json['documentStatusNotifications'] as bool? ?? true,
      dailyReminder: json['dailyReminder'] as bool? ?? false,
      monthlyReminder: json['monthlyReminder'] as bool? ?? true,
      autoFollowUpMissingBills:
          json['autoFollowUpMissingBills'] as bool? ?? true,
      enableEmailImport: json['enableEmailImport'] as bool? ?? false,
      enableCloudSync: json['enableCloudSync'] as bool? ?? false,
    );
  }
}

class ClientPortalAccessProfile {
  const ClientPortalAccessProfile({
    required this.clientId,
    this.loginEnabled = true,
    this.mobileLoginEnabled = true,
    this.webLoginEnabled = true,
    this.twoFactorRequired = false,
    this.accountLocked = false,
    this.subscriptionPlan = 'standard',
    this.billingMode = ClientBillingMode.imageUploadAccountantEntry,
    this.accountingMode = ClientAccountingMode.accountsOnly,
    this.purchaseEntryMode = ClientVoucherEntryMode.ocr,
    this.salesEntryMode = ClientVoucherEntryMode.manual,
    this.documentHubAccess = const ClientDocumentHubAccess(),
    this.modules = const <String, ClientModuleAccess>{},
    this.dashboardWidgets = const <String, bool>{},
  });

  final String clientId;
  final bool loginEnabled;
  final bool mobileLoginEnabled;
  final bool webLoginEnabled;
  final bool twoFactorRequired;
  final bool accountLocked;
  final String subscriptionPlan;
  final ClientBillingMode billingMode;
  final ClientAccountingMode accountingMode;
  final ClientVoucherEntryMode purchaseEntryMode;
  final ClientVoucherEntryMode salesEntryMode;
  final ClientDocumentHubAccess documentHubAccess;
  final Map<String, ClientModuleAccess> modules;
  final Map<String, bool> dashboardWidgets;

  ClientPortalAccessProfile copyWith({
    bool? loginEnabled,
    bool? mobileLoginEnabled,
    bool? webLoginEnabled,
    bool? twoFactorRequired,
    bool? accountLocked,
    String? subscriptionPlan,
    ClientBillingMode? billingMode,
    ClientAccountingMode? accountingMode,
    ClientVoucherEntryMode? purchaseEntryMode,
    ClientVoucherEntryMode? salesEntryMode,
    ClientDocumentHubAccess? documentHubAccess,
    Map<String, ClientModuleAccess>? modules,
    Map<String, bool>? dashboardWidgets,
  }) {
    return ClientPortalAccessProfile(
      clientId: clientId,
      loginEnabled: loginEnabled ?? this.loginEnabled,
      mobileLoginEnabled: mobileLoginEnabled ?? this.mobileLoginEnabled,
      webLoginEnabled: webLoginEnabled ?? this.webLoginEnabled,
      twoFactorRequired: twoFactorRequired ?? this.twoFactorRequired,
      accountLocked: accountLocked ?? this.accountLocked,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      billingMode: billingMode ?? this.billingMode,
      accountingMode: accountingMode ?? this.accountingMode,
      purchaseEntryMode: purchaseEntryMode ?? this.purchaseEntryMode,
      salesEntryMode: salesEntryMode ?? this.salesEntryMode,
      documentHubAccess: documentHubAccess ?? this.documentHubAccess,
      modules: modules ?? this.modules,
      dashboardWidgets: dashboardWidgets ?? this.dashboardWidgets,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientId': clientId,
    'loginEnabled': loginEnabled,
    'mobileLoginEnabled': mobileLoginEnabled,
    'webLoginEnabled': webLoginEnabled,
    'twoFactorRequired': twoFactorRequired,
    'accountLocked': accountLocked,
    'subscriptionPlan': subscriptionPlan,
    'billingMode': billingMode.name,
    'accountingMode': accountingMode.name,
    'purchaseEntryMode': purchaseEntryMode.name,
    'salesEntryMode': salesEntryMode.name,
    'documentHubAccess': documentHubAccess.toJson(),
    'modules': modules.map(
      (moduleId, access) => MapEntry(moduleId, access.toJson()),
    ),
    'dashboardWidgets': dashboardWidgets,
  };

  factory ClientPortalAccessProfile.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'];
    final rawWidgets = json['dashboardWidgets'];
    return ClientPortalAccessProfile(
      clientId: json['clientId']?.toString() ?? '',
      loginEnabled: json['loginEnabled'] as bool? ?? true,
      mobileLoginEnabled: json['mobileLoginEnabled'] as bool? ?? true,
      webLoginEnabled: json['webLoginEnabled'] as bool? ?? true,
      twoFactorRequired: json['twoFactorRequired'] as bool? ?? false,
      accountLocked: json['accountLocked'] as bool? ?? false,
      subscriptionPlan: json['subscriptionPlan']?.toString() ?? 'standard',
      billingMode: _parseBillingMode(json['billingMode']?.toString()),
      accountingMode: _parseAccountingMode(json['accountingMode']?.toString()),
      purchaseEntryMode: _parseEntryMode(json['purchaseEntryMode']?.toString()),
      salesEntryMode: _parseEntryMode(json['salesEntryMode']?.toString()),
      documentHubAccess:
          json['documentHubAccess'] is Map
          ? ClientDocumentHubAccess.fromJson(
              Map<String, dynamic>.from(json['documentHubAccess'] as Map),
            )
          : const ClientDocumentHubAccess(),
      modules: rawModules is Map
          ? Map<String, dynamic>.from(rawModules).map(
              (moduleId, value) => MapEntry(
                moduleId,
                ClientModuleAccess.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              ),
            )
          : const <String, ClientModuleAccess>{},
      dashboardWidgets: rawWidgets is Map
          ? Map<String, dynamic>.from(
              rawWidgets,
            ).map((key, value) => MapEntry(key, value as bool? ?? false))
          : const <String, bool>{},
    );
  }
}

ClientBillingMode _parseBillingMode(String? value) {
  return ClientBillingMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ClientBillingMode.imageUploadAccountantEntry,
  );
}

ClientAccountingMode _parseAccountingMode(String? value) {
  return ClientAccountingMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ClientAccountingMode.accountsOnly,
  );
}

ClientVoucherEntryMode _parseEntryMode(String? value) {
  return ClientVoucherEntryMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ClientVoucherEntryMode.manual,
  );
}
