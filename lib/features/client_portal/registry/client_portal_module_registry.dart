import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workbench_screen.dart';
import 'package:chirag_accounting/features/billing_print_setup/presentation/pages/billing_print_setup_screen.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';
import 'package:chirag_accounting/features/clients/Chat/authenticated_support_chat_shell.dart';
import 'package:chirag_accounting/features/clients/Chat/client_document_hub_screen.dart';
import 'package:chirag_accounting/features/clients/Customers/client_customers_screen.dart';
import 'package:chirag_accounting/features/clients/financial_planning/presentation/pages/client_investment_planner_screen.dart';
import 'package:chirag_accounting/features/clients/financial_planning/presentation/pages/client_loan_planner_screen.dart';
import 'package:chirag_accounting/features/clients/GST/client_gst_screen.dart';
import 'package:chirag_accounting/features/clients/Products/client_products_screen.dart';
import 'package:chirag_accounting/features/clients/Profile/client_profile_screen.dart';
import 'package:chirag_accounting/features/clients/Referral/client_referral_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/clients/Billing/presentation/pages/sales_voucher_system_screen.dart';
import 'package:chirag_accounting/features/compat/screens/client_documents_screen_compat.dart';
import 'package:chirag_accounting/features/clients/Uplads/smart_invoice_upload_screen.dart';
import 'package:chirag_accounting/features/compat/screens/client_data_exchange_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/client_reports_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/client_uploads_screen_compat.dart';
import 'package:chirag_accounting/features/business_templates/presentation/pages/client_accounting_workspace_screen.dart';
import 'package:chirag_accounting/features/gst_operations/presentation/pages/gst_document_operations_screen.dart';
import 'package:chirag_accounting/features/client_portal/presentation/pages/client_voucher_workspace_screen.dart';
import 'package:chirag_accounting/features/masters/presentation/pages/other_ledgers_screen.dart';
import 'package:chirag_accounting/features/reports/presentation/pages/client_provisional_reports_screen.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_dashboard_screen.dart';
import 'package:chirag_accounting/features/uni_desk/presentation/pages/uni_desk_screen.dart';

class ClientPortalModuleRegistry {
  const ClientPortalModuleRegistry._();

  static const List<ClientDashboardWidgetDefinition> dashboardWidgets =
      <ClientDashboardWidgetDefinition>[
        ClientDashboardWidgetDefinition(
          id: 'business_summary',
          displayName: 'Business Summary',
          icon: Icons.space_dashboard_outlined,
          sortOrder: 10,
          requiredModuleId: 'dashboard',
        ),
        ClientDashboardWidgetDefinition(
          id: 'accounting_trend',
          displayName: 'Accounting Trend',
          icon: Icons.show_chart_outlined,
          sortOrder: 20,
          requiredModuleId: 'reports',
        ),
        ClientDashboardWidgetDefinition(
          id: 'quick_actions',
          displayName: 'Quick Actions',
          icon: Icons.bolt_outlined,
          sortOrder: 30,
          requiredModuleId: 'dashboard',
        ),
        ClientDashboardWidgetDefinition(
          id: 'recent_activity',
          displayName: 'Recent Activity',
          icon: Icons.history_outlined,
          sortOrder: 40,
          requiredModuleId: 'dashboard',
        ),
        ClientDashboardWidgetDefinition(
          id: 'gst_status',
          displayName: 'GST Status',
          icon: Icons.receipt_long_outlined,
          sortOrder: 50,
          requiredModuleId: 'gst',
        ),
        ClientDashboardWidgetDefinition(
          id: 'ocr_queue',
          displayName: 'OCR Queue',
          icon: Icons.document_scanner_outlined,
          sortOrder: 60,
          requiredModuleId: 'ocr',
        ),
        ClientDashboardWidgetDefinition(
          id: 'financial_targets',
          displayName: 'Investment Targets',
          icon: Icons.track_changes_outlined,
          sortOrder: 70,
          requiredModuleId: 'investment_planner',
        ),
      ];

  static final List<ClientModuleDefinition> modules = <ClientModuleDefinition>[
    ClientModuleDefinition(
      id: 'unidesk',
      name: 'Uni-Desk',
      displayName: 'Uni-Desk',
      icon: Icons.desktop_windows_outlined,
      route: '/client/unidesk',
      category: 'General',
      sortOrder: 5,
      defaultEnabled: true,
      builder: (_) => const UniDeskScreen(),
    ),
    ClientModuleDefinition(
      id: 'dashboard',
      name: 'Dashboard',
      displayName: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/client/dashboard',
      category: 'General',
      sortOrder: 10,
      defaultEnabled: true,
      dashboardWidgetId: 'business_summary',
      builder: (_) => const _ModuleMessageScreen(
        title: 'Dashboard',
        message: 'You are already on the client dashboard.',
      ),
    ),
    ClientModuleDefinition(
      id: 'ai_assistant',
      name: 'AI Workbench',
      displayName: 'AI Workbench',
      icon: Icons.auto_awesome_outlined,
      route: '/client/ai',
      category: 'AI',
      sortOrder: 15,
      defaultEnabled: true,
      featureFlag: 'ai_workbench',
      dashboardWidgetId: 'ai_suggestions',
      builder: (_) => const AiWorkbenchScreen(),
    ),
    ClientModuleDefinition(
      id: 'sales',
      name: 'Sales Billing',
      displayName: 'Sales Billing',
      icon: Icons.point_of_sale_outlined,
      route: '/client/sales',
      category: 'Accounting',
      sortOrder: 20,
      defaultEnabled: true,
      builder: (_) => const ClientVoucherWorkspaceScreen(),
    ),
    ClientModuleDefinition(
      id: 'billing_system',
      name: 'Billing System',
      displayName: 'Billing',
      icon: Icons.point_of_sale_outlined,
      route: '/client/billing',
      category: 'Accounting',
      sortOrder: 21,
      defaultEnabled: true,
      builder: (_) => const SalesVoucherSystemScreen(),
    ),
    ClientModuleDefinition(
      id: 'business_templates',
      name: 'Universal Business Template',
      displayName: 'Business Templates',
      icon: Icons.dashboard_customize_outlined,
      route: '/client/business-templates',
      category: 'Accounting',
      sortOrder: 22,
      defaultEnabled: true,
      builder: (_) => const ClientAccountingWorkspaceScreen(),
    ),
    ClientModuleDefinition(
      id: 'billing_print_setup',
      name: 'Billing & Print Setup',
      displayName: 'Billing & Print Setup',
      icon: Icons.print_outlined,
      route: '/client/billing-print-setup',
      category: 'Accounting',
      sortOrder: 24,
      defaultEnabled: true,
      builder: (_) => const BillingPrintSetupScreen(),
    ),
    ClientModuleDefinition(
      id: 'invoicing',
      name: 'Invoicing',
      displayName: 'Invoicing',
      icon: Icons.request_quote_outlined,
      route: '/client/invoicing',
      category: 'Accounting',
      sortOrder: 23,
      defaultEnabled: true,
      builder: (_) => const _ApiReadyModuleScreen(
        title: 'Invoicing',
        description:
            'Create, manage, and track customer invoices from one workspace.',
        capabilities: <String>[
          'Create tax and non-tax invoices',
          'View invoice status and history',
          'Download and share invoice documents',
        ],
      ),
    ),
    ClientModuleDefinition(
      id: 'purchase',
      name: 'Purchase',
      displayName: 'Purchase',
      icon: Icons.shopping_cart_outlined,
      route: '/client/purchase',
      category: 'Accounting',
      sortOrder: 30,
      defaultEnabled: true,
      builder: (_) => const ClientVoucherWorkspaceScreen(),
    ),
    ClientModuleDefinition(
      id: 'voucher_upload',
      name: 'Voucher Upload',
      displayName: 'Voucher Entry',
      icon: Icons.menu_book_outlined,
      route: '/client/vouchers',
      category: 'Accounting',
      sortOrder: 40,
      defaultEnabled: true,
      builder: (_) => const VoucherEntryDashboardScreen(),
    ),
    ClientModuleDefinition(
      id: 'ledger',
      name: 'Ledger',
      displayName: 'Ledger',
      icon: Icons.account_balance_outlined,
      route: '/client/ledger',
      category: 'Accounting',
      sortOrder: 50,
      webSupported: true,
      mobileSupported: true,
      builder: (_) => const OtherLedgersScreen(),
    ),
    ClientModuleDefinition(
      id: 'uploads',
      name: 'Uploads',
      displayName: 'Uploads',
      icon: Icons.upload_file_outlined,
      route: '/client/uploads',
      category: 'Documents',
      sortOrder: 60,
      defaultEnabled: true,
      permissionType: ClientModulePermissionType.uploadOnly,
      builder: (_) => const ClientUploadsScreen(),
    ),
    ClientModuleDefinition(
      id: 'document_hub',
      name: 'Document Hub',
      displayName: 'Document Hub',
      icon: Icons.hub_outlined,
      route: '/client/document-hub',
      category: 'Documents',
      sortOrder: 65,
      defaultEnabled: true,
      permissionType: ClientModulePermissionType.uploadOnly,
      builder: (_) => const ClientDocumentHubScreen(),
    ),
    ClientModuleDefinition(
      id: 'ocr',
      name: 'OCR',
      displayName: 'OCR Scanner',
      icon: Icons.document_scanner_outlined,
      route: '/client/ocr',
      category: 'Documents',
      sortOrder: 70,
      defaultEnabled: true,
      featureFlag: 'smart_invoice_v2',
      dashboardWidgetId: 'ocr_queue',
      builder: (_) => const SmartInvoiceUploadScreen(),
    ),
    ClientModuleDefinition(
      id: 'documents',
      name: 'Documents',
      displayName: 'Documents',
      icon: Icons.folder_copy_outlined,
      route: '/client/documents',
      category: 'Documents',
      sortOrder: 80,
      defaultEnabled: true,
      builder: (_) => const ClientDocumentsScreen(),
    ),
    ClientModuleDefinition(
      id: 'data_exchange',
      name: 'Data Exchange',
      displayName: 'Import / Pulling',
      icon: Icons.import_export_outlined,
      route: '/client/data-exchange',
      category: 'Documents',
      sortOrder: 90,
      builder: (_) => const ClientDataExchangeScreen(),
    ),
    ClientModuleDefinition(
      id: 'gst',
      name: 'GST',
      displayName: 'GST',
      icon: Icons.receipt_long_outlined,
      route: '/client/gst',
      category: 'Compliance',
      sortOrder: 100,
      defaultEnabled: true,
      dashboardWidgetId: 'gst_status',
      builder: (_) => const ClientGstScreen(),
    ),
    ClientModuleDefinition(
      id: 'e_invoicing',
      name: 'E-Invoicing',
      displayName: 'E-Invoicing',
      icon: Icons.qr_code_2_outlined,
      route: '/client/e-invoicing',
      category: 'Compliance',
      sortOrder: 102,
      defaultEnabled: true,
      builder: (_) => const GstDocumentOperationsScreen.eInvoice(),
    ),
    ClientModuleDefinition(
      id: 'eway_bill',
      name: 'E-Way Bill',
      displayName: 'E-Way Bill',
      icon: Icons.local_shipping_outlined,
      route: '/client/eway-bill',
      category: 'Compliance',
      sortOrder: 105,
      defaultEnabled: true,
      builder: (_) => const GstDocumentOperationsScreen.eWayBill(),
    ),
    ClientModuleDefinition(
      id: 'reports',
      name: 'Reports',
      displayName: 'Reports',
      icon: Icons.bar_chart_outlined,
      route: '/client/reports',
      category: 'Reports',
      sortOrder: 110,
      defaultEnabled: true,
      permissionType: ClientModulePermissionType.readOnly,
      dashboardWidgetId: 'ledger_summary',
      builder: (_) => const ClientReportsScreen(),
    ),
    ClientModuleDefinition(
      id: 'provisional_reports',
      name: 'Provisional Reports',
      displayName: 'Provisional Reports',
      icon: Icons.verified_outlined,
      route: '/client/provisional-reports',
      category: 'Reports',
      sortOrder: 115,
      defaultEnabled: true,
      permissionType: ClientModulePermissionType.readOnly,
      builder: (_) => const ClientProvisionalReportsScreen(),
    ),
    ClientModuleDefinition(
      id: 'bank',
      name: 'Bank',
      displayName: 'Banking',
      icon: Icons.account_balance_outlined,
      route: '/client/bank',
      category: 'Accounting',
      sortOrder: 120,
      defaultEnabled: true,
      dashboardWidgetId: 'bank_balance',
      builder: (_) => const ClientBankScreen(),
    ),
    ClientModuleDefinition(
      id: 'loan_planner',
      name: 'Loan Planner',
      displayName: 'Loan',
      icon: Icons.account_balance_wallet_outlined,
      route: '/client/loan-planner',
      category: 'Finance',
      sortOrder: 122,
      defaultEnabled: true,
      builder: (_) => const ClientLoanPlannerScreen(),
    ),
    ClientModuleDefinition(
      id: 'investment_planner',
      name: 'Investment Planner',
      displayName: 'Investment',
      icon: Icons.savings_outlined,
      route: '/client/investment-planner',
      category: 'Finance',
      sortOrder: 124,
      defaultEnabled: true,
      dashboardWidgetId: 'financial_targets',
      builder: (_) => const ClientInvestmentPlannerScreen(),
    ),
    ClientModuleDefinition(
      id: 'products',
      name: 'Products',
      displayName: 'Products',
      icon: Icons.inventory_2_outlined,
      route: '/client/products',
      category: 'Masters',
      sortOrder: 130,
      defaultEnabled: true,
      builder: (_) => const ClientProductsScreen(),
    ),
    ClientModuleDefinition(
      id: 'customers',
      name: 'Customers',
      displayName: 'My Customers',
      icon: Icons.people_outline,
      route: '/client/customers',
      category: 'Masters',
      sortOrder: 135,
      defaultEnabled: true,
      builder: (_) => const ClientCustomersScreen(),
    ),
    ClientModuleDefinition(
      id: 'chat',
      name: 'Client Chat',
      displayName: 'Chat & Queries',
      icon: Icons.chat_bubble_outline,
      route: '/client/chat',
      category: 'Communication',
      sortOrder: 140,
      defaultEnabled: true,
      dashboardWidgetId: 'queries',
      builder: (_) => const OpenSupportChatRedirect(),
    ),
    ClientModuleDefinition(
      id: 'referral',
      name: 'Referral Rewards',
      displayName: 'Referral Rewards',
      icon: Icons.group_add_outlined,
      route: '/client/referral',
      category: 'Communication',
      sortOrder: 150,
      defaultEnabled: true,
      builder: (_) => const ClientReferralScreen(),
    ),
    ClientModuleDefinition(
      id: 'settings',
      name: 'Settings',
      displayName: 'Settings',
      icon: Icons.settings_outlined,
      route: '/client/settings',
      category: 'General',
      sortOrder: 900,
      defaultEnabled: true,
      builder: (_) => const ClientSettingsScreen(),
    ),
    ClientModuleDefinition(
      id: 'profile',
      name: 'Profile',
      displayName: 'Profile',
      icon: Icons.person_outline,
      route: '/client/profile',
      category: 'General',
      sortOrder: 910,
      defaultEnabled: true,
      builder: (_) => const ClientProfileScreen(),
    ),
    ..._futureModules,
  ]..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

  static List<ClientModuleDefinition> get enabledModules =>
      modules.where((module) => module.enabled).toList(growable: false);

  static ClientModuleDefinition? find(String moduleId) {
    for (final module in modules) {
      if (module.id == moduleId) return module;
    }
    return null;
  }

  static List<ClientModuleDefinition>
  get _futureModules => <ClientModuleDefinition>[
    _future(
      'income_tax',
      'Income Tax',
      Icons.request_quote_outlined,
      200,
      'Compliance',
    ),
    _future('tds', 'TDS', Icons.percent_outlined, 210, 'Compliance'),
    _future('payroll', 'Payroll', Icons.groups_outlined, 220, 'Payroll'),
    _future('audit', 'Audit', Icons.fact_check_outlined, 230, 'Compliance'),
    _future(
      'roc_filing',
      'ROC Filing',
      Icons.account_balance_outlined,
      240,
      'Compliance',
    ),
    _future(
      'inventory',
      'Inventory',
      Icons.warehouse_outlined,
      250,
      'Accounting',
    ),
    _future('analytics', 'Analytics', Icons.analytics_outlined, 260, 'Reports'),
    _future('approvals', 'Approvals', Icons.approval_outlined, 270, 'Workflow'),
    _future('tasks', 'Tasks', Icons.task_alt_outlined, 280, 'Workflow'),
    _future(
      'notifications',
      'Notifications',
      Icons.notifications_outlined,
      290,
      'Communication',
    ),
  ];
  static ClientModuleDefinition _future(
    String id,
    String displayName,
    IconData icon,
    int sortOrder,
    String category,
  ) {
    return ClientModuleDefinition(
      id: id,
      name: displayName,
      displayName: displayName,
      icon: icon,
      route: '/client/$id',
      category: category,
      sortOrder: sortOrder,
      enabled: true,
      builder: (_) => _ModuleMessageScreen(
        title: displayName,
        message:
            '$displayName is registered and ready for its implementation package.',
      ),
    );
  }
}

class _ModuleMessageScreen extends StatelessWidget {
  const _ModuleMessageScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _ApiReadyModuleScreen extends StatelessWidget {
  const _ApiReadyModuleScreen({
    required this.title,
    required this.description,
    required this.capabilities,
  });

  final String title;
  final String description;
  final List<String> capabilities;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.hub_outlined,
                  size: 48,
                  color: Color(0xFF176B5B),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF5C6B67)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD6E1DE)),
                  ),
                  child: Column(
                    children: [
                      for (final capability in capabilities)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 19,
                                color: Color(0xFF176B5B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(capability)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5DE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.api_outlined, color: Color(0xFF8A5A00)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Interface ready. API connection is pending.',
                          style: TextStyle(
                            color: Color(0xFF6F4900),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
