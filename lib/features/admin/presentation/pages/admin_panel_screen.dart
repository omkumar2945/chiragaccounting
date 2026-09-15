import 'package:flutter/material.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/accounting/accounting_policy_service.dart';
import 'package:chirag_accounting/core/navigation/end_of_screen_navigation.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/api_management_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/admin_referral_management_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/permission_dashboard_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/admin_user_management_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/client_permission_management_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/firebase_services_status_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/tally_sync_management_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/download_center_settings_screen.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/accountant/presentation/pages/accountant_dashboard_screen.dart';
import 'package:chirag_accounting/features/accountant/presentation/pages/ocr_module_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/notifications_panel.dart';
import 'package:chirag_accounting/features/uni_desk/presentation/pages/uni_desk_screen.dart';
import 'package:chirag_accounting/shared/widgets/session_logout_button.dart';
import 'package:chirag_accounting/features/gst_library/presentation/pages/gst_library_screen.dart';
import 'package:chirag_accounting/features/gst_notices/presentation/pages/gst_notice_management_screen.dart';
import 'package:chirag_accounting/features/gst_scrutiny/presentation/pages/gst_scrutiny_center_screen.dart';
import 'package:chirag_accounting/features/marketing/presentation/pages/marketing_pipeline_screen.dart';
import 'package:chirag_accounting/features/hr/presentation/pages/hr_management_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/ca_compliance_review_center_screen.dart';
import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/authentication/presentation/pages/login_screen.dart';
import 'package:chirag_accounting/features/business_templates/presentation/pages/client_accounting_workspace_screen.dart';
import 'package:chirag_accounting/shared/widgets/branding/chirag_associates_logo.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedSectionTitle;
  Widget? _activeWorkspace;
  String _activeWorkspaceTitle = 'Overview';
  bool _sidebarCollapsed = false;
  bool _mobileSearchOpen = false;

  static const String _featureGstLibrary = 'Full GST Act 2017 with Amendments';
  static const String _featureGstNoticeUpload =
      'Client GST Notice Upload System';
  static const String _featureGstScrutinyDraft =
      'GST Scrutiny Draft Reply Upgrade';
  static const String _featureGstJudgementOrders =
      'GST Case Judgements, Filed/Won Orders';

  static const List<_AdminSection> _legacySections = <_AdminSection>[
    _AdminSection(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      description: 'Business overview, health, usage, and alerts.',
      items: <String>[
        'Business Overview',
        'System Health',
        'Active Users',
        'Active Companies',
        'Today\'s Transactions',
        'OCR Status',
        'API Usage',
        'Storage Usage',
        'License Status',
        'Notifications',
      ],
    ),
    _AdminSection(
      title: 'Company Management',
      icon: Icons.apartment_outlined,
      description: 'Company onboarding, structure, and controls.',
      items: <String>[
        'Company List',
        'Add Company',
        'Company Profile',
        'Financial Years',
        'Branch Management',
        'Department Management',
        'Company Settings',
        'Subscription',
        'License',
        'Company Logo',
        'Archive Company',
      ],
    ),
    _AdminSection(
      title: 'Client Management',
      icon: Icons.manage_accounts_outlined,
      description:
          'Chirag Associates client lifecycle, portal access, and assignments.',
      items: <String>[
        'Client List',
        'Upload Client List',
        'Onboard Client',
        'Edit Client Profiles',
        'Client Accounting Access',
        'Assign Company',
        'Assign Branch',
        'Assign Department',
        'Assign Role',
        'User Status',
        'Reset Password',
        'Login History',
        'Active Sessions',
        'Device Management',
        'Force Logout',
      ],
    ),
    _AdminSection(
      title: 'Roles & Permissions',
      icon: Icons.verified_user_outlined,
      description: 'Enterprise permission stack from company to action.',
      items: <String>[
        'Permission Dashboard',
        'Client Portal Permissions',
        'Permission Templates',
        'Company Permissions',
        'Branch Permissions',
        'Department Permissions',
        'Role Permissions',
        'User Permissions',
        'Module Permissions',
        'Screen Permissions',
        'Action Permissions',
        'Data Access Permissions',
        'Workflow Permissions',
        'Approval Permissions',
        'Report Permissions',
        'API Permissions',
        'Feature Permissions',
        'Audit Permissions',
      ],
    ),
    _AdminSection(
      title: 'Module Management',
      icon: Icons.widgets_outlined,
      description: 'Enable and govern ERP modules company-wise.',
      items: <String>[
        'Accounting',
        'Sales',
        'Purchase',
        'Inventory',
        'Banking',
        'GST',
        'Manufacturing',
        'Payroll',
        'CRM',
        'Projects',
        'Assets',
        'POS',
        'OCR',
        'Import',
        'Reports',
        'Analytics',
        'AI Features',
      ],
    ),
    _AdminSection(
      title: 'Masters',
      icon: Icons.folder_open_outlined,
      description: 'Global ERP masters and opening balance setup.',
      items: <String>[
        'Ledger Groups',
        'Ledgers',
        'Customers',
        'Suppliers',
        'Items',
        'Item Groups',
        'Brands',
        'Units',
        'HSN/SAC',
        'Tax Masters',
        'Warehouses',
        'Godowns',
        'Batches',
        'Serial Numbers',
        'Price Lists',
        'Payment Terms',
        'Cost Centers',
        'Projects',
        'Banks',
        'Opening Balance Setup',
      ],
    ),
    _AdminSection(
      title: 'Workflow Management',
      icon: Icons.account_tree_outlined,
      description: 'Approval matrices and process controls.',
      items: <String>[
        'Approval Matrix',
        'Voucher Workflow',
        'Sales Workflow',
        'Purchase Workflow',
        'Inventory Workflow',
        'Banking Workflow',
        'GST Workflow',
        'Custom Workflow',
      ],
    ),
    _AdminSection(
      title: 'Subscription & License',
      icon: Icons.workspace_premium_outlined,
      description: 'Plans, billing, renewal, and license keys.',
      items: <String>[
        'Plans',
        'Trial Companies',
        'Paid Companies',
        'Renewal',
        'Invoices',
        'Payments',
        'Module Activation',
        'License Keys',
      ],
    ),
    _AdminSection(
      title: 'OCR & AI',
      icon: Icons.auto_awesome_outlined,
      description: 'Queue, rules, templates, logs, and training.',
      items: <String>[
        'OCR Queue',
        'OCR Templates',
        'AI Rules',
        'AI Mapping',
        'Invoice Matching',
        'Duplicate Detection',
        'OCR Logs',
        'Failed OCR',
        'AI Training',
      ],
    ),
    _AdminSection(
      title: 'Import / Export',
      icon: Icons.import_export_outlined,
      description: 'Bulk data import, migration, and export controls.',
      items: <String>[
        'Excel Import',
        'CSV Import',
        'JSON Import',
        'Desktop Software Import',
        'Web-Based Software Import',
        'Bank Statement Import',
        'GST Import',
        'Opening Balance Import',
        'Bulk Export',
        'Data Migration',
      ],
    ),
    _AdminSection(
      title: 'API & Integrations',
      icon: Icons.hub_outlined,
      description: 'Third-party API setup, webhooks, and logs.',
      items: <String>[
        'GST API',
        'OCR API',
        'Bank API',
        'WhatsApp API',
        'SMS API',
        'Email API',
        'Payment Gateway',
        'Google Drive',
        'OneDrive',
        'Dropbox',
        'Webhooks',
        'API Logs',
      ],
    ),
    _AdminSection(
      title: 'Reports & Analytics',
      icon: Icons.bar_chart_outlined,
      description: 'Cross-company analytics and compliance reports.',
      items: <String>[
        'Company Reports',
        'User Reports',
        'Activity Reports',
        'Financial Reports',
        'GST Reports',
        'Inventory Reports',
        'OCR Reports',
        'API Reports',
        'Audit Reports',
        'Dashboard Analytics',
      ],
    ),
    _AdminSection(
      title: 'Notifications',
      icon: Icons.notifications_active_outlined,
      description: 'Templates and delivery orchestration.',
      items: <String>[
        'Email',
        'SMS',
        'WhatsApp',
        'Push Notifications',
        'In-App Notifications',
        'Notification Templates',
        'Scheduler',
      ],
    ),
    _AdminSection(
      title: 'Security',
      icon: Icons.security_outlined,
      description: 'Authentication, restrictions, and trails.',
      items: <String>[
        'Password Policy',
        'Two-Factor Authentication',
        'OTP Settings',
        'Session Timeout',
        'Device Restrictions',
        'IP Restrictions',
        'Login Attempts',
        'Encryption',
        'Audit Trail',
        'Security Logs',
      ],
    ),
    _AdminSection(
      title: 'Backup & Restore',
      icon: Icons.backup_outlined,
      description: 'Backup policy, restore, and sync control.',
      items: <String>[
        'Manual Backup',
        'Automatic Backup',
        'Scheduled Backup',
        'Cloud Backup',
        'Restore Backup',
        'Restore History',
        'Database Maintenance',
        'Sync Control',
      ],
    ),
    _AdminSection(
      title: 'System Configuration',
      icon: Icons.settings_suggest_outlined,
      description: 'Core defaults and system behavior settings.',
      items: <String>[
        'Financial Year',
        'Voucher Numbering',
        'Number Series',
        'Date Format',
        'Currency',
        'Language',
        'Theme',
        'Print Templates',
        'Email Templates',
        'SMS Templates',
        'WhatsApp Templates',
        'Dashboard Settings',
        'System Preferences',
      ],
    ),
    _AdminSection(
      title: 'Audit Logs',
      icon: Icons.manage_search_outlined,
      description: 'System-wide auditable operational logs.',
      items: <String>[
        'Login Logs',
        'Activity Logs',
        'Voucher Logs',
        'Master Logs',
        'Permission Logs',
        'Import Logs',
        'OCR Logs',
        'API Logs',
        'Backup Logs',
        'Error Logs',
      ],
    ),
    _AdminSection(
      title: 'Help Center',
      icon: Icons.support_agent_outlined,
      description: 'Knowledge base and support operations.',
      items: <String>[
        'User Manual',
        'Video Tutorials',
        'Release Notes',
        'FAQs',
        'Raise Support Ticket',
        'Live Chat',
        'Remote Support',
        'Feedback',
      ],
    ),
    _AdminSection(
      title: 'My Account',
      icon: Icons.account_circle_outlined,
      description: 'Personal admin profile and preferences.',
      items: <String>[
        'Profile',
        'Change Password',
        'Notification Preferences',
        'Login Devices',
        'Activity',
        'About',
        'Logout',
      ],
    ),
  ];

  List<_AdminSection> get _sections => <_AdminSection>[
    const _AdminSection(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      description:
          'Mission control, business health, finance, staff, and alerts.',
      items: <String>[
        'Business Overview',
        'Mission Control',
        'Business Health',
        'Financial Dashboard',
        'Employee Dashboard',
        'CA Dashboard',
        'Accountant Dashboard',
        'Client Activity',
        'AI Center',
        'Compliance Monitor',
        'Storage Dashboard',
        'Activity Timeline',
        'Admin Shortcuts',
      ],
    ),
    const _AdminSection(
      title: 'Integrations',
      icon: Icons.sync_alt_outlined,
      description: 'Connect client companies with external accounting systems.',
      items: <String>['Tally Sync'],
    ),
    const _AdminSection(
      title: 'Uni-Desk',
      icon: Icons.desktop_windows_outlined,
      description:
          'Monitor client-authorized support requests and controlled assistance sessions.',
      items: <String>['Uni-Desk System Monitor'],
    ),
    _AdminSection(
      title: 'User Management',
      icon: Icons.manage_accounts_outlined,
      description:
          'Chirag Associates client lifecycle, portal access, and assignments.',
      items: <String>[
        ..._legacySection('Client Management').items,
        'Universal Business Templates',
      ],
    ),
    const _AdminSection(
      title: 'Marketing System',
      icon: Icons.campaign_outlined,
      description:
          'Manage referrals, lead follow-ups, conversion, and onboarding.',
      items: <String>[
        'Lead & Follow-up Pipeline',
        'Referral Tracking & Points',
        'Download Center Settings',
      ],
    ),
    const _AdminSection(
      title: 'GST Library',
      icon: Icons.local_library_outlined,
      description:
          'CGST Act sections, amendment history, source documents, and scrutiny references.',
      items: <String>[
        _featureGstLibrary,
        _featureGstNoticeUpload,
        _featureGstScrutinyDraft,
        _featureGstJudgementOrders,
      ],
    ),
    const _AdminSection(
      title: 'HR Module',
      icon: Icons.groups_2_outlined,
      description:
          'Manage Chirag staff accounts and recruitment through hiring.',
      items: <String>['Staff & Hiring'],
    ),
    _AdminSection(
      title: 'Role & Permissions',
      icon: Icons.verified_user_outlined,
      description: 'Role, module, screen, action, data, and API permissions.',
      items: _legacySection('Roles & Permissions').items,
    ),
    const _AdminSection(
      title: 'Company Settings',
      icon: Icons.apartment_outlined,
      description: 'Company identity, branches, financial years, and defaults.',
      items: <String>[
        'Company Profile',
        'Financial Years',
        'Branch Management',
        'Department Management',
        'Company Logo',
        'System Preferences',
      ],
    ),
    const _AdminSection(
      title: 'Subscription Plans',
      icon: Icons.workspace_premium_outlined,
      description:
          'Plans, renewals, invoices, payments, and module activation.',
      items: <String>[
        'Plans',
        'Client Renewals',
        'Pending Renewals',
        'Subscription Invoices',
        'Subscription Payments',
        'Module Activation',
        'License Keys',
      ],
    ),
    const _AdminSection(
      title: 'API Management',
      icon: Icons.hub_outlined,
      description:
          'API health, credentials, usage, billing, renewals, and logs.',
      items: <String>[
        'API Dashboard',
        'API Keys',
        'API Usage',
        'API Billing',
        'Renewal Reminders',
        'Payment History',
        'Vendor Management',
        'Webhooks',
        'Error Logs',
        'API Settings',
      ],
    ),
    _legacySection('OCR & AI'),
    const _AdminSection(
      title: 'Notification Center',
      icon: Icons.notifications_active_outlined,
      description: 'Email, SMS, WhatsApp, push, templates, and scheduling.',
      items: <String>[
        'Notification Dashboard',
        'Email Notifications',
        'SMS Notifications',
        'WhatsApp Notifications',
        'Push Notifications',
        'Notification Templates',
        'Notification Scheduler',
      ],
    ),
    _legacySection('Audit Logs'),
    _legacySection('Backup & Restore'),
    _legacySection('Security'),
    const _AdminSection(
      title: 'System Health',
      icon: Icons.monitor_heart_outlined,
      description: 'Database, API, server, queues, storage, CPU, and memory.',
      items: <String>[
        'System Health Dashboard',
        'Database Response Time',
        'API Response Time',
        'Server Ping',
        'OCR Speed',
        'AI Speed',
        'Memory Usage',
        'CPU Usage',
        'Queue Length',
        'Active Connections',
      ],
    ),
    const _AdminSection(
      title: 'Reports',
      icon: Icons.bar_chart_outlined,
      description: 'Company, users, activity, finance, compliance, and APIs.',
      items: <String>[
        'Company Reports',
        'User Reports',
        'Activity Reports',
        'Financial Reports',
        'GST Reports',
        'Compliance Reports',
        'API Reports',
        'Audit Reports',
      ],
    ),
  ];

  _AdminSection _legacySection(String title) =>
      _legacySections.firstWhere((section) => section.title == title);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _filteredSections(query);
    final matchingClients = _filterClientDirectory(
      context.watch<AdminUserService?>()?.users ?? const <UserModel>[],
      query,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final desktop = screenWidth >= 1050;
    final extendedHeader = screenWidth >= 1380;
    final showSearchWorkspace =
        query.isNotEmpty || (!desktop && _mobileSearchOpen);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F6FA),
      drawer: desktop ? null : Drawer(child: _adminSidebar()),
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: desktop ? 16 : 8,
        leading: desktop
            ? null
            : IconButton(
                tooltip: 'Open admin navigation',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
        title: Row(
          children: [
            if (desktop) ...[
              SizedBox(
                width: extendedHeader ? 350 : 168,
                child: _brandTitle(extended: extendedHeader),
              ),
              SizedBox(width: extendedHeader ? 16 : 12),
              SizedBox(
                width: extendedHeader ? 150 : 104,
                child: Text(
                  _activeWorkspaceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _headerSearchField()),
            ] else
              const Expanded(
                child: ChiragAssociatesLogo(
                  compact: true,
                  onDark: true,
                  showTagline: false,
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF073B78),
        foregroundColor: Colors.white,
        actions: [
          if (!desktop)
            IconButton(
              key: const ValueKey('admin-mobile-search'),
              tooltip: 'Search administration',
              onPressed: _openMobileSearch,
              icon: const Icon(Icons.search_rounded),
            ),
          if (desktop) ...[
            _financialYearAction(compact: !extendedHeader),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Notifications',
              onPressed: _openLiveNotificationCenter,
              icon: const Icon(Icons.notifications_none_outlined),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientSettingsScreen()),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          const SizedBox(width: 2),
          const SessionLogoutButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (desktop)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: _sidebarCollapsed ? 72 : 244,
              child: _adminSidebar(collapsed: _sidebarCollapsed),
            ),
          Expanded(
            child: showSearchWorkspace
                ? _searchWorkspace(
                    filtered,
                    matchingClients: matchingClients,
                    desktop: desktop,
                  )
                : (_activeWorkspace ??
                      Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                28,
                              ),
                              children: [
                                if (_selectedSectionTitle != null) ...[
                                  _dashboardHeading(),
                                  const SizedBox(height: 16),
                                ],
                                if (_selectedSectionTitle != null) ...[
                                  const SizedBox(height: 20),
                                  _sectionDashboard(
                                    _sections.firstWhere(
                                      (section) =>
                                          section.title ==
                                          _selectedSectionTitle,
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 20),
                                  _enterpriseOverview(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )),
          ),
        ],
      ),
    );
  }

  Widget _adminSidebar({bool collapsed = false}) => ColoredBox(
    color: const Color(0xFF082F63),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 14 : 16,
              18,
              collapsed ? 14 : 16,
              14,
            ),
            child: collapsed
                ? const Center(
                    child: ChiragAssociatesLogo(
                      compact: true,
                      onDark: true,
                      showName: false,
                      showTagline: false,
                    ),
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChiragAssociatesLogo(
                        compact: true,
                        onDark: true,
                        showTagline: false,
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Administration Console',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFB8CCE3),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFF244B78)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
              children: [
                _adminSidebarItem(
                  label: 'Overview',
                  icon: Icons.space_dashboard_outlined,
                  collapsed: collapsed,
                  selected:
                      _activeWorkspace == null && _selectedSectionTitle == null,
                  onTap: _openAdminOverview,
                ),
                if (!collapsed) const _AdminSidebarLabel('CORE MANAGEMENT'),
                for (final section in _sections.take(9))
                  _adminSidebarItem(
                    label: section.title,
                    icon: section.icon,
                    collapsed: collapsed,
                    selected:
                        _activeWorkspace == null &&
                        _selectedSectionTitle == section.title,
                    onTap: () => _openAdminSection(section),
                  ),
                if (!collapsed)
                  const _AdminSidebarLabel('GOVERNANCE & OPERATIONS'),
                for (final section in _sections.skip(9))
                  _adminSidebarItem(
                    label: section.title,
                    icon: section.icon,
                    collapsed: collapsed,
                    selected:
                        _activeWorkspace == null &&
                        _selectedSectionTitle == section.title,
                    onTap: () => _openAdminSection(section),
                  ),
              ],
            ),
          ),
          if (!collapsed)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'ENTERPRISE COMMAND CENTER',
                style: TextStyle(
                  color: Color(0xFF7696BA),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (MediaQuery.sizeOf(context).width >= 1050) ...[
            const Divider(height: 1, color: Color(0xFF244B78)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Align(
                alignment: collapsed ? Alignment.center : Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey('admin-sidebar-collapse'),
                  tooltip: collapsed
                      ? 'Expand navigation'
                      : 'Collapse navigation',
                  onPressed: () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _adminSidebarItem({
    required String label,
    required IconData icon,
    required bool collapsed,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Material(
      color: selected ? const Color(0xFF165DA8) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: label,
        child: ListTile(
          key: ValueKey(
            'admin-nav-${label.toLowerCase().replaceAll(' ', '-')}',
          ),
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: collapsed ? 20 : 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          leading: Icon(
            icon,
            color: selected ? Colors.white : const Color(0xFFB8CCE3),
            size: 18,
          ),
          title: collapsed
              ? null
              : Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFD7E3F0),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
          onTap: onTap,
        ),
      ),
    ),
  );

  void _closeAdminDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  void _openAdminOverview() {
    setState(() {
      _activeWorkspace = null;
      _activeWorkspaceTitle = 'Overview';
      _selectedSectionTitle = null;
    });
    _closeAdminDrawer();
  }

  void _openAdminSection(_AdminSection section) {
    setState(() {
      _activeWorkspace = null;
      _activeWorkspaceTitle = section.title;
      _selectedSectionTitle = section.title;
    });
    _closeAdminDrawer();
  }

  Widget _enterpriseOverview() {
    final directory = context.watch<AdminUserService?>();
    final operations = context.watch<OperationsCenterService?>();
    final users = directory?.users;
    final hasUserData = directory?.isLoaded ?? false;
    final clients = users?.where((user) => user.role.isClient).length ?? 0;
    final accountants =
        users?.where((user) => user.role == UserRole.accountant).length ?? 0;
    final auditors =
        users
            ?.where(
              (user) =>
                  user.role == UserRole.partner ||
                  user.role == UserRole.firmAdmin ||
                  user.role == UserRole.checker,
            )
            .length ??
        0;
    final admins =
        users
            ?.where(
              (user) =>
                  user.role == UserRole.superAdmin ||
                  user.role == UserRole.admin,
            )
            .length ??
        0;
    final activeModules = _sections
        .where(
          (section) => section.items.any(
            (item) => _isWiredFeature(item, sectionTitle: section.title),
          ),
        )
        .length;
    final userValue = hasUserData ? '${users!.length}' : 'No data';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _adminHero(operations),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1150
                ? 5
                : constraints.maxWidth >= 650
                ? 3
                : 2;
            final width =
                (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            final metrics = <_AdminMetricData>[
              _AdminMetricData(
                'Total Users',
                userValue,
                'Managed directory',
                Icons.groups_outlined,
                const Color(0xFF2463D4),
              ),
              _AdminMetricData(
                'Clients',
                hasUserData ? '$clients' : 'No data',
                'Client accounts',
                Icons.business_center_outlined,
                const Color(0xFF16875B),
              ),
              _AdminMetricData(
                'Accountants',
                hasUserData ? '$accountants' : 'No data',
                'Accounting users',
                Icons.calculate_outlined,
                const Color(0xFF7552CC),
              ),
              _AdminMetricData(
                'CA / Auditors',
                hasUserData ? '$auditors' : 'No data',
                'Review users',
                Icons.fact_check_outlined,
                const Color(0xFFE28A16),
              ),
              _AdminMetricData(
                'Active Modules',
                '$activeModules',
                'Connected workspaces',
                Icons.widgets_outlined,
                const Color(0xFF087E8B),
              ),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metrics
                  .map(
                    (metric) => _AdminMetric(
                      width: width,
                      label: metric.label,
                      value: metric.value,
                      detail: metric.detail,
                      icon: metric.icon,
                      color: metric.color,
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => _adminDashboardPair(
            constraints.maxWidth,
            _ecosystemInfographic(),
            _governancePosture(),
            leftFlex: 3,
            rightFlex: 2,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => _adminDashboardPair(
            constraints.maxWidth,
            _platformHealthEmpty(),
            _userDistribution(
              hasUserData: hasUserData,
              clients: clients,
              accountants: accountants,
              auditors: auditors,
              admins: admins,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _operationalWorkflow(operations?.snapshot.metrics),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => _adminDashboardPair(
            constraints.maxWidth,
            _moduleCommandCenter(),
            _alertsEmpty(),
            leftFlex: 3,
            rightFlex: 2,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => _adminDashboardPair(
            constraints.maxWidth,
            _platformActivityEmpty(),
            _quickAdminActions(),
            leftFlex: 3,
            rightFlex: 2,
          ),
        ),
        const SizedBox(height: 16),
        _adminActivity(operations?.snapshot.timeline),
        const SizedBox(height: 16),
        _permissionHierarchy(),
      ],
    );
  }

  Widget _adminHero(OperationsCenterService? operations) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD6E2F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D073B78),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFF1459B8),
                size: 27,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADMIN COMMAND CENTER',
                    style: TextStyle(
                      color: Color(0xFF132C4B),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Admin ERP Panel',
                    style: TextStyle(
                      color: Color(0xFF60758A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Control, monitor and manage the complete Chirag Accounting ecosystem from one place.',
                    style: TextStyle(color: Color(0xFF60758A), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
        final status = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F6FB),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 9,
                color: operations == null
                    ? const Color(0xFF8A96A5)
                    : const Color(0xFF16875B),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  operations == null
                      ? 'STATUS DATA UNAVAILABLE'
                      : operations.snapshot.streamState.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF304A67),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 12), status],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 14),
            status,
          ],
        );
      },
    ),
  );

  Widget _ecosystemInfographic() => _AdminPanel(
    title: 'Ecosystem Overview',
    subtitle: 'How governed platform roles connect to operational modules',
    child: Column(
      children: [
        const _EcosystemNode(
          Icons.balance_outlined,
          'CHIRAG ACCOUNTING',
          Color(0xFF1459B8),
        ),
        const _VerticalConnector(),
        const Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _EcosystemNode(Icons.person_outline, 'CLIENT', Color(0xFF16875B)),
            _EcosystemNode(
              Icons.calculate_outlined,
              'ACCOUNTANT',
              Color(0xFF2463D4),
            ),
            _EcosystemNode(
              Icons.fact_check_outlined,
              'CA / AUDITOR',
              Color(0xFF7552CC),
            ),
          ],
        ),
        const _VerticalConnector(),
        const _EcosystemNode(
          Icons.admin_panel_settings_outlined,
          'ADMIN CONTROL',
          Color(0xFFE28A16),
        ),
        const _VerticalConnector(),
        const Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _EcosystemNode(
              Icons.account_balance_outlined,
              'ACCOUNTING',
              Color(0xFF2463D4),
            ),
            _EcosystemNode(
              Icons.receipt_long_outlined,
              'GST',
              Color(0xFF16875B),
            ),
            _EcosystemNode(
              Icons.account_balance_wallet_outlined,
              'BANKING',
              Color(0xFFE28A16),
            ),
            _EcosystemNode(
              Icons.analytics_outlined,
              'REPORTS',
              Color(0xFF7552CC),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _governancePosture() => _AdminPanel(
    title: 'Governance Posture',
    subtitle: 'Configured controls; no synthetic score',
    child: const Column(
      children: [
        _AssuranceLine('Role-based access configured', true),
        _AssuranceLine('Permission matrix configured', true),
        _AssuranceLine('Client data isolation configured', true),
        _AssuranceLine('Document controls configured', true),
        _AssuranceLine('API governance workspace connected', true),
        SizedBox(height: 8),
        _AdminNoData(
          icon: Icons.donut_large_outlined,
          text: 'Governance score is not calculated by the current system',
        ),
      ],
    ),
  );

  Widget _platformHealthEmpty() => const _AdminPanel(
    title: 'Platform Health',
    subtitle: 'Users, modules, integrations, security and compliance',
    child: _AdminNoData(
      icon: Icons.monitor_heart_outlined,
      text: 'No calculated platform health data available',
    ),
  );

  Widget _userDistribution({
    required bool hasUserData,
    required int clients,
    required int accountants,
    required int auditors,
    required int admins,
  }) {
    final total = clients + accountants + auditors + admins;
    return _AdminPanel(
      title: 'User Ecosystem',
      subtitle: 'Managed users by login role',
      child: !hasUserData
          ? const _AdminNoData(
              icon: Icons.donut_large_outlined,
              text: 'No user directory data available',
            )
          : Row(
              children: [
                SizedBox.square(
                  dimension: 105,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 94,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : clients / total,
                          strokeWidth: 11,
                          backgroundColor: const Color(0xFFE5EAF1),
                          color: const Color(0xFF2463D4),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: const TextStyle(
                              color: Color(0xFF132C4B),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'TOTAL USERS',
                            style: TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _distributionRow(
                        'Clients',
                        clients,
                        const Color(0xFF2463D4),
                      ),
                      _distributionRow(
                        'Accountants',
                        accountants,
                        const Color(0xFF16875B),
                      ),
                      _distributionRow(
                        'CA / Auditors',
                        auditors,
                        const Color(0xFF7552CC),
                      ),
                      _distributionRow(
                        'Admins',
                        admins,
                        const Color(0xFFE28A16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _distributionRow(String label, int value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(Icons.circle, color: color, size: 9),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
        Text(
          '$value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _operationalWorkflow(Map<String, num>? metrics) {
    final stages = <(String, String, IconData, String, String)>[
      (
        'Document',
        _metricValue(metrics, 'Pending Uploads'),
        Icons.description_outlined,
        'OCR & AI',
        'OCR Queue',
      ),
      (
        'OCR',
        _metricValue(metrics, 'OCR Queue'),
        Icons.document_scanner_outlined,
        'OCR & AI',
        'OCR Queue',
      ),
      (
        'Accounting',
        _metricValue(metrics, 'Pending Verification'),
        Icons.edit_note_outlined,
        'Dashboard',
        'Accountant Dashboard',
      ),
      (
        'Check',
        _metricValue(metrics, 'Waiting CA'),
        Icons.rule_outlined,
        'Dashboard',
        'CA Dashboard',
      ),
      (
        'Approval',
        _metricValue(metrics, 'Pending Approvals'),
        Icons.approval_outlined,
        'Dashboard',
        'Compliance Monitor',
      ),
      (
        'Sync',
        _metricValue(metrics, 'Waiting Auditor'),
        Icons.sync_alt_outlined,
        'Integrations',
        'Tally Sync',
      ),
      (
        'Completed',
        _metricValue(metrics, 'Completed Today Queue'),
        Icons.task_alt_outlined,
        'Dashboard',
        'Business Overview',
      ),
    ];
    return _AdminPanel(
      title: 'Operational Workflow',
      subtitle: 'Live counts from document intake to completion',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stages
            .map(
              (stage) => InkWell(
                onTap: () =>
                    _openAdminFeature(stage.$5, sectionTitle: stage.$4),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 116,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F9FD),
                    border: Border.all(color: const Color(0xFFD8E3F0)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Column(
                    children: [
                      Icon(stage.$3, color: const Color(0xFF1459B8), size: 21),
                      const SizedBox(height: 6),
                      Text(
                        stage.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF132C4B),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        stage.$1,
                        style: const TextStyle(
                          color: Color(0xFF60758A),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _moduleCommandCenter() {
    const moduleSections = <String>[
      'Integrations',
      'User Management',
      'Marketing System',
      'GST Library',
      'HR Module',
      'Role & Permissions',
      'API Management',
      'OCR & AI',
      'Reports',
    ];
    final sections = _sections
        .where((section) => moduleSections.contains(section.title))
        .toList(growable: false);
    return _AdminPanel(
      title: 'Module Command Center',
      subtitle: 'Existing connected administration workspaces',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700 ? 3 : 2;
          final width = (constraints.maxWidth - ((columns - 1) * 8)) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sections
                .map((section) {
                  final wired = section.items
                      .where(
                        (item) =>
                            _isWiredFeature(item, sectionTitle: section.title),
                      )
                      .length;
                  return SizedBox(
                    width: width,
                    child: InkWell(
                      onTap: () => _openAdminSection(section),
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          border: Border.all(color: const Color(0xFFD8E3F0)),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              section.icon,
                              color: const Color(0xFF1459B8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF132C4B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '$wired connected',
                                    style: const TextStyle(
                                      color: Color(0xFF16875B),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 11,
                              color: Color(0xFF8A9AAC),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }

  Widget _alertsEmpty() => const _AdminPanel(
    title: 'System Alerts',
    subtitle: 'Critical, warning, information and resolved',
    child: _AdminNoData(
      icon: Icons.notifications_none_outlined,
      text: 'No categorized alert data available',
    ),
  );

  Widget _platformActivityEmpty() => const _AdminPanel(
    title: 'Platform Activity',
    subtitle: 'Today, week, month and financial year',
    child: _AdminNoData(
      icon: Icons.area_chart_outlined,
      text: 'No time-series platform activity data available',
    ),
  );

  Widget _quickAdminActions() => _AdminPanel(
    title: 'Quick Admin Actions',
    subtitle: 'Existing administration workflows',
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _adminLoginAction(
          'Open Client Login',
          Icons.person_outline,
          StaffLoginMode.client,
        ),
        _adminLoginAction(
          'Open Accountant Login',
          Icons.calculate_outlined,
          StaffLoginMode.accountant,
        ),
        _adminLoginAction(
          'Open CA/Auditor Login',
          Icons.fact_check_outlined,
          StaffLoginMode.caAuditor,
        ),
        _quickAction(
          'Add User',
          Icons.person_add_alt_1_outlined,
          'Onboard Client',
          'User Management',
        ),
        _quickAction(
          'Permissions',
          Icons.verified_user_outlined,
          'Permission Dashboard',
          'Role & Permissions',
        ),
        _quickAction(
          'Audit Logs',
          Icons.manage_search_outlined,
          'Activity Logs',
          'Audit Logs',
        ),
        _quickAction(
          'Backup',
          Icons.backup_outlined,
          'Manual Backup',
          'Backup & Restore',
        ),
        _quickAction(
          'Security',
          Icons.security_outlined,
          'Password Policy',
          'Security',
        ),
        _quickAction(
          'API Management',
          Icons.hub_outlined,
          'API Dashboard',
          'API Management',
        ),
        _quickAction(
          'OCR & AI',
          Icons.document_scanner_outlined,
          'OCR Queue',
          'OCR & AI',
        ),
      ],
    ),
  );

  Widget _adminLoginAction(String label, IconData icon, StaffLoginMode mode) =>
      ActionChip(
        avatar: Icon(icon, color: const Color(0xFF1459B8), size: 17),
        label: Text(label),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen(initialMode: mode)),
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFCAD8E8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      );

  Widget _quickAction(
    String label,
    IconData icon,
    String feature,
    String section,
  ) => ActionChip(
    avatar: Icon(icon, color: const Color(0xFF1459B8), size: 17),
    label: Text(label),
    onPressed: () => _openAdminFeature(feature, sectionTitle: section),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFCAD8E8)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
  );

  Widget _adminActivity(List<OperationTimelineEvent>? events) => _AdminPanel(
    title: 'Recent Admin Activity',
    subtitle: 'Existing platform timeline records',
    child: events == null || events.isEmpty
        ? const _AdminNoData(
            icon: Icons.history_outlined,
            text: 'No activity records available',
          )
        : Column(
            children: events
                .take(6)
                .map(
                  (event) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFFE8F0FE),
                      foregroundColor: Color(0xFF1459B8),
                      child: Icon(Icons.bolt_outlined, size: 15),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${event.clientName} • ${event.source}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
  );

  Widget _adminDashboardPair(
    double width,
    Widget left,
    Widget right, {
    int leftFlex = 1,
    int rightFlex = 1,
  }) => width >= 800
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
          ],
        )
      : Column(children: [left, const SizedBox(height: 16), right]);

  String _metricValue(Map<String, num>? metrics, String key) =>
      metrics == null || !metrics.containsKey(key)
      ? 'No data'
      : '${metrics[key]!.round()}';

  Widget _brandTitle({required bool extended}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66001A38),
            offset: Offset(1, 2),
            blurRadius: 2,
          ),
          BoxShadow(color: Color(0x334A9BE8), offset: Offset(-1, -1)),
        ],
      ),
      child: Row(
        children: [
          const ChiragAssociatesLogo(
            compact: true,
            onDark: true,
            showTagline: false,
          ),
          if (extended) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 9),
              child: SizedBox(
                height: 28,
                child: VerticalDivider(color: Color(0xFF6797C7)),
              ),
            ),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADMINISTRATION CONSOLE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'ADMINISTRATION & GOVERNANCE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD9E9FA),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _financialYearAction({bool compact = false}) {
    final period = context.watch<AccountingPolicyService>().period;
    final label =
        '${period.financialYearLabel} | ${period.assessmentYearLabel}';
    if (compact) {
      return IconButton(
        tooltip: 'Financial year: $label',
        onPressed: _selectFinancialYear,
        icon: const Icon(Icons.calendar_month_outlined),
      );
    }
    return TextButton.icon(
      onPressed: _selectFinancialYear,
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: Colors.white),
    );
  }

  Widget _sectionDashboard(_AdminSection section) {
    final wiredCount = section.items
        .where((item) => _isWiredFeature(item, sectionTitle: section.title))
        .length;
    final coverage = section.items.isEmpty
        ? 0
        : wiredCount / section.items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0D3768),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26001D3D),
                offset: Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCF66),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(section.icon, color: const Color(0xFF0D3768)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${section.title} Control Center',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      section.description,
                      style: const TextStyle(color: Color(0xFFD9E9FA)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Return to overview',
                onPressed: () => setState(() => _selectedSectionTitle = null),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final metricWidth = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AdminMetric(
                  width: metricWidth,
                  label: 'Available Options',
                  value: '${section.items.length}',
                  detail: 'Complete module hierarchy',
                  icon: Icons.account_tree_outlined,
                  color: const Color(0xFF0B4D93),
                ),
                _AdminMetric(
                  width: metricWidth,
                  label: 'Live Workspaces',
                  value: '$wiredCount',
                  detail: 'Directly connected destinations',
                  icon: Icons.task_alt_outlined,
                  color: const Color(0xFF16795A),
                ),
                _AdminMetric(
                  width: metricWidth,
                  label: 'Wiring Coverage',
                  value: '${(coverage * 100).round()}%',
                  detail: 'Verified implementation status',
                  icon: Icons.donut_large_outlined,
                  color: const Color(0xFF8B5B10),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _AdminPanel(
          title: 'Full Module Options',
          subtitle:
              'Select a live workspace or review mapped implementation status',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 720
                  ? 3
                  : constraints.maxWidth >= 460
                  ? 2
                  : 1;
              final tileWidth =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < section.items.length; index++)
                    SizedBox(
                      width: tileWidth,
                      child: _AdminOptionTile(
                        index: index,
                        label: section.items[index],
                        isWired: _isWiredFeature(
                          section.items[index],
                          sectionTitle: section.title,
                        ),
                        onTap: () => _openAdminFeature(
                          section.items[index],
                          sectionTitle: section.title,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isWiredFeature(String feature, {String? sectionTitle}) =>
      _resolveAdminFeatureRoute(feature, sectionTitle: sectionTitle) != null;

  Widget _dashboardHeading() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF0B4D93),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.balance_outlined, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin ERP Panel',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17324D),
              ),
            ),
            Text(
              'Legal entity governance, compliance and operational command dashboard',
              style: TextStyle(color: Color(0xFF60758A)),
            ),
          ],
        ),
      ),
      const _AdminTag('AUDIT READY'),
    ],
  );

  Widget _headerSearchField() => TextField(
    key: const ValueKey('admin-global-search'),
    controller: _searchCtrl,
    focusNode: _searchFocusNode,
    textInputAction: TextInputAction.search,
    onChanged: (_) => setState(() {}),
    onSubmitted: _submitSearch,
    style: const TextStyle(color: Colors.white, fontSize: 12),
    decoration: InputDecoration(
      hintText: 'Search modules, clients, reports, permissions',
      hintStyle: const TextStyle(color: Color(0xFFB8CCE3), fontSize: 11),
      prefixIcon: const Icon(Icons.search, color: Color(0xFFD7E5F3), size: 18),
      suffixIcon: _searchCtrl.text.trim().isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close, color: Color(0xFFD7E5F3), size: 18),
            ),
      filled: true,
      fillColor: const Color(0xFF164B84),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _searchWorkspace(
    List<_AdminSection> filtered, {
    required List<UserModel> matchingClients,
    required bool desktop,
  }) {
    final query = _searchCtrl.text.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        if (!desktop) ...[_searchField(), const SizedBox(height: 16)],
        Row(
          children: [
            Expanded(
              child: Text(
                query.isEmpty ? 'Search' : 'Search Results',
                style: const TextStyle(
                  color: Color(0xFF17324D),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close search',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (matchingClients.isNotEmpty) ...[
            _clientSearchResults(matchingClients),
            const SizedBox(height: 12),
          ],
          _searchHierarchy(filtered),
        ],
      ],
    );
  }

  List<_AdminSection> _filteredSections(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return _sections;
    return _sections
        .where((section) {
          if (section.title.toLowerCase().contains(normalizedQuery)) {
            return true;
          }
          return section.items.any(
            (item) => item.toLowerCase().contains(normalizedQuery),
          );
        })
        .toList(growable: false);
  }

  List<UserModel> _filterClientDirectory(
    Iterable<UserModel> users,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const <UserModel>[];
    return users
        .where(
          (user) =>
              user.role.isClient &&
              (user.name.toLowerCase().contains(normalizedQuery) ||
                  user.firmName.toLowerCase().contains(normalizedQuery) ||
                  user.email.toLowerCase().contains(normalizedQuery) ||
                  user.mobile.contains(normalizedQuery) ||
                  user.id.toLowerCase().contains(normalizedQuery)),
        )
        .take(8)
        .toList(growable: false);
  }

  Widget _clientSearchResults(List<UserModel> clients) => _AdminPanel(
    title: 'Client Directory',
    subtitle: '${clients.length} matching client(s) found',
    child: Column(
      children: [
        for (final client in clients)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE7F1FF),
              foregroundColor: const Color(0xFF0B4D93),
              child: Icon(
                client.isActive
                    ? Icons.business_center_outlined
                    : Icons.pending_outlined,
              ),
            ),
            title: Text(
              client.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              client.firmName.isEmpty
                  ? 'Client ID: ${client.id}'
                  : '${client.firmName} | Client ID: ${client.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => _openClientSearchResult(client),
          ),
      ],
    ),
  );

  void _openMobileSearch() {
    setState(() => _mobileSearchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _clearSearch() {
    _searchFocusNode.unfocus();
    setState(() {
      _searchCtrl.clear();
      _mobileSearchOpen = false;
    });
  }

  void _submitSearch(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;
    final matchingClients = _filterClientDirectory(
      context.read<AdminUserService>().users,
      query,
    );
    if (matchingClients.isNotEmpty) {
      _openClientSearchResult(matchingClients.first);
      return;
    }
    final sections = _filteredSections(query);
    if (sections.isEmpty) return;

    final section = sections.first;
    for (final feature in section.items) {
      if (feature.toLowerCase().contains(query)) {
        _openSearchResult(feature, sectionTitle: section.title);
        return;
      }
    }

    _searchFocusNode.unfocus();
    setState(() {
      _searchCtrl.clear();
      _mobileSearchOpen = false;
    });
    _openAdminSection(section);
  }

  void _openSearchResult(String feature, {String? sectionTitle}) {
    _searchFocusNode.unfocus();
    setState(() {
      _searchCtrl.clear();
      _mobileSearchOpen = false;
    });
    _openAdminFeature(feature, sectionTitle: sectionTitle);
  }

  void _openClientSearchResult(UserModel client) {
    _searchFocusNode.unfocus();
    setState(() {
      _searchCtrl.clear();
      _mobileSearchOpen = false;
      _activeWorkspace = AdminUserManagementScreen(initialQuery: client.id);
      _activeWorkspaceTitle = 'Client List';
      _selectedSectionTitle = null;
    });
    _closeAdminDrawer();
  }

  Widget _searchField() => TextField(
    key: const ValueKey('admin-search-workspace'),
    controller: _searchCtrl,
    focusNode: _searchFocusNode,
    textInputAction: TextInputAction.search,
    onChanged: (_) => setState(() {}),
    onSubmitted: _submitSearch,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search, color: Color(0xFF0B4D93)),
      suffixIcon: _searchCtrl.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close),
            ),
      hintText: 'Search module, legal control, report or permission...',
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFC5D2E0)),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );

  Widget _executiveMetrics() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 900
          ? (constraints.maxWidth - 36) / 4
          : constraints.maxWidth >= 520
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _AdminMetric(
            width: width,
            label: 'Governed Modules',
            value: '${_sections.length}',
            detail: 'Centralized control domains',
            icon: Icons.account_tree_outlined,
            color: const Color(0xFF0B4D93),
          ),
          _AdminMetric(
            width: width,
            label: 'Live Workspaces',
            value: '8',
            detail: 'Professionally wired modules',
            icon: Icons.task_alt_outlined,
            color: const Color(0xFF16795A),
          ),
          _AdminMetric(
            width: width,
            label: 'Control Layers',
            value: '14',
            detail: 'Entity to audit hierarchy',
            icon: Icons.security_outlined,
            color: const Color(0xFF8B5B10),
          ),
          _AdminMetric(
            width: width,
            label: 'System Status',
            value: 'Secure',
            detail: 'Permission and audit governed',
            icon: Icons.verified_user_outlined,
            color: const Color(0xFF6D3EA2),
          ),
        ],
      );
    },
  );

  Widget _dashboardInfographics() => LayoutBuilder(
    builder: (context, constraints) {
      final panels = <Widget>[
        _AdminPanel(
          title: 'Operational Readiness',
          subtitle: 'Implementation status by control domain',
          child: const Column(
            children: [
              _AdminProgress('Administration & users', 0.92, Color(0xFF0B4D93)),
              _AdminProgress('Compliance & GST', 0.86, Color(0xFF16795A)),
              _AdminProgress('People & growth', 0.78, Color(0xFF8B5B10)),
              _AdminProgress('Integrations & APIs', 0.72, Color(0xFF6D3EA2)),
            ],
          ),
        ),
        _AdminPanel(
          title: 'Governance Posture',
          subtitle: 'Legal entity control assurance',
          child: const Row(
            children: [
              _AdminScoreRing(score: 94),
              SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AssuranceLine('Role-based access', true),
                    _AssuranceLine('Audit trail controls', true),
                    _AssuranceLine('Client data isolation', true),
                    _AssuranceLine('Document locking', true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ];
      if (constraints.maxWidth >= 800) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: panels.first),
            const SizedBox(width: 16),
            Expanded(child: panels.last),
          ],
        );
      }
      return Column(
        children: [panels.first, const SizedBox(height: 16), panels.last],
      );
    },
  );

  Widget _searchHierarchy(List<_AdminSection> filtered) => _AdminPanel(
    title: 'Search Results',
    subtitle: '${filtered.length} administration area(s) found',
    child: filtered.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No matching administration module or control found.',
              ),
            ),
          )
        : Column(
            children: filtered
                .map(
                  (section) => ExpansionTile(
                    initiallyExpanded: true,
                    leading: Icon(section.icon, color: const Color(0xFF0B4D93)),
                    title: Text(
                      section.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(section.description),
                    children: section.items
                        .where(
                          (item) =>
                              section.title.toLowerCase().contains(
                                _searchCtrl.text.trim().toLowerCase(),
                              ) ||
                              item.toLowerCase().contains(
                                _searchCtrl.text.trim().toLowerCase(),
                              ),
                        )
                        .map(
                          (item) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_right),
                            title: Text(item),
                            trailing: const Icon(Icons.open_in_new, size: 16),
                            onTap: () => _openSearchResult(
                              item,
                              sectionTitle: section.title,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                )
                .toList(growable: false),
          ),
  );

  Widget _permissionHierarchy() => const _AdminPanel(
    title: 'Enterprise Permission Hierarchy',
    subtitle: 'Authority flows from legal entity ownership to auditable action',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _HierarchyNode(Icons.admin_panel_settings_outlined, 'Super Admin'),
            _HierarchyArrow(),
            _HierarchyNode(Icons.apartment_outlined, 'Legal Entity'),
            _HierarchyArrow(),
            _HierarchyNode(Icons.account_tree_outlined, 'Branch / Department'),
            _HierarchyArrow(),
            _HierarchyNode(Icons.badge_outlined, 'Role / User'),
            _HierarchyArrow(),
            _HierarchyNode(Icons.widgets_outlined, 'Module / Screen'),
            _HierarchyArrow(),
            _HierarchyNode(Icons.rule_outlined, 'Action / Data'),
            _HierarchyArrow(),
            _HierarchyNode(Icons.fact_check_outlined, 'Workflow / Audit'),
          ],
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AdminTag('PERMISSION DRIVEN'),
            _AdminTag('CLIENT ISOLATED'),
            _AdminTag('DOCUMENT CONTROLLED'),
            _AdminTag('AUDIT TRACEABLE'),
            _AdminTag('API GOVERNED'),
          ],
        ),
      ],
    ),
  );

  Widget _developedModulesLauncher() => _AdminPanel(
    title: 'Developed Modules',
    subtitle: 'Direct access to live operational workspaces',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final buttons = <Widget>[
              _moduleLaunchButton(
                icon: Icons.person_outline,
                label: 'Open Client Login',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginScreen(initialMode: StaffLoginMode.client),
                  ),
                ),
              ),
              _moduleLaunchButton(
                icon: Icons.calculate_outlined,
                label: 'Open Accountant Login',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(
                      initialMode: StaffLoginMode.accountant,
                    ),
                  ),
                ),
              ),
              _moduleLaunchButton(
                icon: Icons.verified_user_outlined,
                label: 'Open CA/Auditor Login',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(
                      initialMode: StaffLoginMode.caAuditor,
                    ),
                  ),
                ),
              ),
              _moduleLaunchButton(
                icon: Icons.campaign_outlined,
                label: 'Marketing',
                onTap: () => _openAdminFeature('Lead & Follow-up Pipeline'),
              ),
              _moduleLaunchButton(
                icon: Icons.groups_2_outlined,
                label: 'HR Module',
                onTap: () => _openAdminFeature('Staff & Hiring'),
              ),
              _moduleLaunchButton(
                icon: Icons.local_library_outlined,
                label: 'GST Library',
                onTap: () => _openAdminFeature(_featureGstLibrary),
              ),
              _moduleLaunchButton(
                icon: Icons.mark_email_unread_outlined,
                label: 'GST Notices',
                onTap: () => _openAdminFeature(_featureGstNoticeUpload),
              ),
              _moduleLaunchButton(
                icon: Icons.fact_check_outlined,
                label: 'GST Scrutiny Drafts',
                onTap: () => _openAdminFeature(_featureGstScrutinyDraft),
              ),
              _moduleLaunchButton(
                icon: Icons.gavel_outlined,
                label: 'GST Judgements',
                onTap: () => _openAdminFeature(_featureGstJudgementOrders),
              ),
            ];
            if (constraints.maxWidth >= 700) {
              return Row(
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(child: buttons[index]),
                  ],
                ],
              );
            }

            final buttonWidth = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: buttons
                  .map((button) => SizedBox(width: buttonWidth, child: button))
                  .toList(growable: false),
            );
          },
        ),
      ],
    ),
  );

  Widget _moduleLaunchButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
      alignment: Alignment.centerLeft,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFB8C8E0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  Future<void> _selectFinancialYear() async {
    final policy = context.read<AccountingPolicyService>();
    final currentStart = policy.period.financialYearStart;
    final choices = List<int>.generate(9, (index) => currentStart - 4 + index);
    final selected = await showMovableDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Financial Year'),
        children: choices
            .map((year) {
              final period = AccountingPeriod(financialYearStart: year);
              return RadioListTile<int>(
                value: year,
                groupValue: currentStart,
                title: Text(period.financialYearLabel),
                subtitle: Text(period.assessmentYearLabel),
                onChanged: (value) => Navigator.pop(dialogContext, value),
              );
            })
            .toList(growable: false),
      ),
    );
    if (selected != null && mounted) {
      await policy.setFinancialYearStart(selected);
    }
  }

  void _openAdminFeature(String feature, {String? sectionTitle}) {
    final normalizedFeature = feature.toLowerCase();
    final normalizedSection = (sectionTitle ?? '').toLowerCase();
    if (normalizedFeature.contains('notification') ||
        normalizedSection == 'notification center') {
      _openLiveNotificationCenter();
      return;
    }

    final route = _resolveAdminFeatureRoute(
      feature,
      sectionTitle: sectionTitle,
    );
    if (route != null) {
      setState(() {
        _activeWorkspace = route.child;
        _activeWorkspaceTitle = feature;
      });
      _closeAdminDrawer();
      return;
    }

    setState(() {
      _activeWorkspace = _AdminFeatureWorkspaceScreen(
        feature: feature,
        sectionTitle: sectionTitle,
      );
      _activeWorkspaceTitle = feature;
    });
    _closeAdminDrawer();
  }

  Future<void> _openLiveNotificationCenter() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const NotificationsPanelSheet();
      },
    );
  }

  _AdminFeatureRoute? _resolveAdminFeatureRoute(
    String feature, {
    String? sectionTitle,
  }) {
    final normalizedSection = sectionTitle ?? '';
    const systemSections = <String>{
      'Notification Center',
      'System Health',
      'Audit Logs',
      'Backup & Restore',
      'Security',
    };
    const companySections = <String>{
      'Company Settings',
      'Subscription Plans',
      'Reports',
    };

    const apiFeatureTabs = <String, int>{
      'API Dashboard': 0,
      'API Keys': 1,
      'API Usage': 2,
      'API Billing': 3,
      'Renewal Reminders': 4,
      'Payment History': 5,
      'Vendor Management': 6,
      'Webhooks': 7,
      'API Logs': 8,
      'Error Logs': 8,
      'API Settings': 9,
      'Settings': 9,
      'GST API': 0,
      'OCR API': 0,
      'Bank API': 0,
      'WhatsApp API': 0,
      'SMS API': 0,
      'Email API': 0,
      'Payment Gateway': 3,
      'Google Drive': 6,
      'OneDrive': 6,
      'Dropbox': 6,
    };

    const permissionFeatures = <String>{
      'Permission Dashboard',
      'Permission Templates',
      'Company Permissions',
      'Branch Permissions',
      'Department Permissions',
      'Role Permissions',
      'User Permissions',
      'Module Permissions',
      'Screen Permissions',
      'Action Permissions',
      'Data Access Permissions',
      'Workflow Permissions',
      'Approval Permissions',
      'Report Permissions',
      'API Permissions',
      'Feature Permissions',
      'Audit Permissions',
      'Compliance Monitor',
    };

    const userSummaryFeatures = <String>{
      'Business Overview',
      'Mission Control',
      'Business Health',
      'Financial Dashboard',
      'Employee Dashboard',
      'Client Activity',
      'Admin Shortcuts',
      'Company Profile',
      'Financial Years',
      'Branch Management',
      'Department Management',
      'Company Logo',
      'System Preferences',
    };

    if (_matchesFeature(feature, <String>{
      'Client GST Notice Management',
      _featureGstNoticeUpload,
      'Client GST Notice Upload',
      'GST Notice Upload',
      'GST Notice Management',
    })) {
      return const _AdminFeatureRoute(child: GstNoticeManagementScreen());
    }

    if (_matchesFeature(feature, <String>{
      _featureGstScrutinyDraft,
      'GST Scrutiny Draft',
      'GST Scrutiny',
      'E-Scrutiny',
    })) {
      return const _AdminFeatureRoute(child: GstScrutinyCenterScreen());
    }

    if (_matchesFeature(feature, <String>{
      _featureGstLibrary,
      'GST Act 2017 & Amendments',
      'GST Library',
      'GST Act',
    })) {
      return const _AdminFeatureRoute(
        child: GstLibraryScreen(
          showAdminActions: true,
          initialSectionId: 'cgst-act-2017-complete',
        ),
      );
    }

    if (_matchesFeature(feature, <String>{
      _featureGstJudgementOrders,
      'All Case Judgements',
      'GST Judgements',
      'GST Case Laws',
    })) {
      return const _AdminFeatureRoute(
        child: GstLibraryScreen(
          showAdminActions: true,
          initialSectionId: 'gst-case-judgements-orders',
        ),
      );
    }

    if (feature == 'Lead & Follow-up Pipeline') {
      return const _AdminFeatureRoute(child: MarketingPipelineScreen());
    }

    if (feature == 'Download Center Settings') {
      return const _AdminFeatureRoute(child: DownloadCenterSettingsScreen());
    }

    if (feature == 'Staff & Hiring') {
      return const _AdminFeatureRoute(child: HrManagementScreen());
    }

    if (feature == 'Referral Tracking & Points') {
      return const _AdminFeatureRoute(child: AdminReferralManagementScreen());
    }

    if (feature == 'Uni-Desk System Monitor') {
      return const _AdminFeatureRoute(child: UniDeskScreen());
    }

    if (feature == 'Tally Sync') {
      return const _AdminFeatureRoute(child: TallySyncManagementScreen());
    }

    if (feature == 'CA Dashboard') {
      return const _AdminFeatureRoute(child: CaComplianceReviewCenterScreen());
    }

    if (feature == 'Accountant Dashboard') {
      return const _AdminFeatureRoute(child: AccountantDashboardScreen());
    }

    if (feature == 'Universal Business Templates') {
      return const _AdminFeatureRoute(child: ClientAccountingWorkspaceScreen());
    }

    if (normalizedSection == 'Reports') {
      return const _AdminFeatureRoute(
        child: ClientAccountingWorkspaceScreen(
          initialArea: ClientAccountingWorkspaceArea.reports,
        ),
      );
    }

    if (normalizedSection == 'OCR & AI' ||
        _legacySection('OCR & AI').items.contains(feature)) {
      return const _AdminFeatureRoute(child: OcrModuleScreen());
    }

    if (feature == 'Client Portal Permissions') {
      return const _AdminFeatureRoute(
        child: ClientPermissionManagementScreen(),
      );
    }

    final userManagementFeatures = _legacySection('Client Management').items;
    if (normalizedSection == 'User Management' ||
        userManagementFeatures.contains(feature) ||
        userSummaryFeatures.contains(feature)) {
      final initialAction = switch (feature) {
        'Upload Client List' => AdminClientManagementAction.importList,
        'Onboard Client' => AdminClientManagementAction.onboardClient,
        _ => AdminClientManagementAction.clientList,
      };
      return _AdminFeatureRoute(
        child: AdminUserManagementScreen(initialAction: initialAction),
        nextLabel: 'Permission Dashboard',
        onNext: const PermissionDashboardScreen(),
      );
    }

    if (permissionFeatures.contains(feature) ||
        normalizedSection == 'Role & Permissions' ||
        normalizedSection == 'Roles & Permissions') {
      return const _AdminFeatureRoute(child: PermissionDashboardScreen());
    }

    final apiTab = apiFeatureTabs[feature];
    if (apiTab != null ||
        normalizedSection == 'API Management' ||
        normalizedSection == 'API & Integrations' ||
        feature == 'AI Center') {
      return _AdminFeatureRoute(
        child: ApiManagementScreen(initialTab: apiTab ?? 0),
      );
    }

    if (feature == 'Storage Dashboard' ||
        feature == 'Activity Timeline' ||
        feature == 'System Health Dashboard' ||
        feature == 'Push Notifications' ||
        systemSections.contains(normalizedSection)) {
      return const _AdminFeatureRoute(child: FirebaseServicesStatusScreen());
    }

    if (normalizedSection == 'Integrations') {
      return const _AdminFeatureRoute(child: TallySyncManagementScreen());
    }

    if (normalizedSection == 'Marketing System') {
      return const _AdminFeatureRoute(child: AdminReferralManagementScreen());
    }

    if (normalizedSection == 'GST Library') {
      return const _AdminFeatureRoute(
        child: GstLibraryScreen(showAdminActions: true),
      );
    }

    if (normalizedSection == 'HR Module') {
      return const _AdminFeatureRoute(child: HrManagementScreen());
    }

    if (normalizedSection == 'Uni-Desk') {
      return const _AdminFeatureRoute(child: UniDeskScreen());
    }

    if (companySections.contains(normalizedSection)) {
      return _AdminFeatureRoute(
        child: _AdminFeatureWorkspaceScreen(
          feature: feature,
          sectionTitle: sectionTitle,
        ),
        nextLabel: 'Admin ERP Panel',
      );
    }

    if (normalizedSection == 'Dashboard') {
      return _AdminFeatureRoute(
        child: _AdminFeatureWorkspaceScreen(
          feature: feature,
          sectionTitle: sectionTitle,
        ),
        nextLabel: 'Admin ERP Panel',
      );
    }

    return _AdminFeatureRoute(
      child: _AdminFeatureWorkspaceScreen(
        feature: feature,
        sectionTitle: sectionTitle,
      ),
      nextLabel: 'Admin ERP Panel',
    );
  }

  bool _matchesFeature(String feature, Set<String> aliases) {
    final featureKey = _featureKey(feature);
    for (final alias in aliases) {
      if (_featureKey(alias) == featureKey) return true;
    }
    return false;
  }

  String _featureKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _pushAdminScreen({
    required Widget child,
    required String previousLabel,
    String nextLabel = 'Next Screen',
    VoidCallback? onNext,
  }) {
    final controller = context.read<EndOfScreenNavigationController>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EndOfScreenNavigationScope(
          controller: controller,
          previousLabel: previousLabel,
          nextLabel: nextLabel,
          onPrevious: () => Navigator.of(context).pop(),
          onNext: onNext,
          child: child,
        ),
      ),
    );
  }

  void _replaceAdminScreen({
    required Widget child,
    required String previousLabel,
    String nextLabel = 'Next Screen',
    VoidCallback? onNext,
  }) {
    final controller = context.read<EndOfScreenNavigationController>();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EndOfScreenNavigationScope(
          controller: controller,
          previousLabel: previousLabel,
          nextLabel: nextLabel,
          onPrevious: () => Navigator.of(context).pop(),
          onNext: onNext,
          child: child,
        ),
      ),
    );
  }
}

class _AdminFeatureWorkspaceScreen extends StatelessWidget {
  const _AdminFeatureWorkspaceScreen({
    required this.feature,
    required this.sectionTitle,
  });

  final String feature;
  final String? sectionTitle;

  @override
  Widget build(BuildContext context) {
    final title = sectionTitle ?? 'Admin Module';
    final lowerFeature = feature.toLowerCase();
    final lowerSection = (sectionTitle ?? '').toLowerCase();
    final isApiRelated =
        lowerSection.contains('api') || lowerFeature.contains('api');
    final isPermissionRelated =
        lowerSection.contains('permission') ||
        lowerFeature.contains('permission');
    final isUserRelated =
        lowerSection.contains('user') ||
        lowerFeature.contains('client') ||
        lowerFeature.contains('user');
    final isSystemRelated =
        lowerSection.contains('system') ||
        lowerFeature.contains('health') ||
        lowerFeature.contains('storage') ||
        lowerFeature.contains('notification') ||
        lowerFeature.contains('timeline');
    void openLiveNotificationCenter() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const NotificationsPanelSheet(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FD),
      appBar: AppBar(
        title: Text(feature),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD5E2F5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A607A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feature,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF133258),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This submenu is now wired to an actionable workspace. Use the launch options below to continue into the implemented modules.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF546E8A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FeatureLaunchButton(
            icon: Icons.manage_accounts_outlined,
            label: 'Open User Management',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminUserManagementScreen(),
              ),
            ),
          ),
          if (isPermissionRelated || isSystemRelated)
            _FeatureLaunchButton(
              icon: Icons.verified_user_outlined,
              label: 'Open Permission Dashboard',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PermissionDashboardScreen(),
                ),
              ),
            ),
          if (isPermissionRelated)
            _FeatureLaunchButton(
              icon: Icons.account_tree_outlined,
              label: 'Open Client Portal Permissions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientPermissionManagementScreen(),
                ),
              ),
            ),
          if (isApiRelated)
            _FeatureLaunchButton(
              icon: Icons.hub_outlined,
              label: 'Open API Management',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiManagementScreen()),
              ),
            ),
          if (isSystemRelated || lowerSection == 'dashboard')
            _FeatureLaunchButton(
              icon: Icons.monitor_heart_outlined,
              label: 'Open System Health Workspace',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FirebaseServicesStatusScreen(),
                ),
              ),
            ),
          if (lowerSection == 'dashboard')
            _FeatureLaunchButton(
              icon: Icons.workspace_premium_outlined,
              label: 'Open CA Dashboard',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CaComplianceReviewCenterScreen(),
                ),
              ),
            ),
          if (lowerSection == 'dashboard')
            _FeatureLaunchButton(
              icon: Icons.calculate_outlined,
              label: 'Open Accountant Dashboard',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountantDashboardScreen(),
                ),
              ),
            ),
          _FeatureLaunchButton(
            icon: Icons.person_outline,
            label: 'Open Client Login',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LoginScreen(initialMode: StaffLoginMode.client),
              ),
            ),
          ),
          _FeatureLaunchButton(
            icon: Icons.calculate_outlined,
            label: 'Open Accountant Login',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LoginScreen(initialMode: StaffLoginMode.accountant),
              ),
            ),
          ),
          _FeatureLaunchButton(
            icon: Icons.verified_user_outlined,
            label: 'Open CA/Auditor Login',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LoginScreen(initialMode: StaffLoginMode.caAuditor),
              ),
            ),
          ),
          if (isUserRelated)
            _FeatureLaunchButton(
              icon: Icons.share_outlined,
              label: 'Open Referral Management',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminReferralManagementScreen(),
                ),
              ),
            ),
          if (isSystemRelated)
            _FeatureLaunchButton(
              icon: Icons.notifications_active_outlined,
              label: 'Open Live Notification Center',
              onTap: openLiveNotificationCenter,
            ),
          _FeatureLaunchButton(
            icon: Icons.sync_alt_outlined,
            label: 'Open Tally Sync Management',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TallySyncManagementScreen(),
              ),
            ),
          ),
          _FeatureLaunchButton(
            icon: Icons.desktop_windows_outlined,
            label: 'Open Uni-Desk Monitor',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UniDeskScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminFeatureRoute {
  const _AdminFeatureRoute({
    required this.child,
    this.nextLabel = 'Next Screen',
    this.onNext,
  });

  final Widget child;
  final String nextLabel;
  final Widget? onNext;
}

class _FeatureLaunchButton extends StatelessWidget {
  const _FeatureLaunchButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          alignment: Alignment.centerLeft,
          backgroundColor: const Color(0xFFE7F0FF),
          foregroundColor: const Color(0xFF0D47A1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _AdminSection {
  const _AdminSection({
    required this.title,
    required this.icon,
    required this.description,
    required this.items,
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> items;
}

class _AdminOptionTile extends StatelessWidget {
  const _AdminOptionTile({
    required this.index,
    required this.label,
    required this.isWired,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool isWired;
  final VoidCallback onTap;

  static const _icons = <IconData>[
    Icons.dashboard_customize_outlined,
    Icons.fact_check_outlined,
    Icons.account_tree_outlined,
    Icons.analytics_outlined,
    Icons.tune_outlined,
    Icons.manage_search_outlined,
  ];

  static const _colors = <Color>[
    Color(0xFF0B4D93),
    Color(0xFF16795A),
    Color(0xFF8B5B10),
    Color(0xFF6D3EA2),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return Material(
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFD6E0EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(_icons[index % _icons.length], color: color),
                  ),
                  const Spacer(),
                  Icon(
                    isWired ? Icons.arrow_outward : Icons.schedule_outlined,
                    size: 18,
                    color: isWired
                        ? const Color(0xFF16795A)
                        : const Color(0xFF7A8794),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF17324D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isWired ? 'LIVE WORKSPACE' : 'MAPPED',
                style: TextStyle(
                  color: isWired
                      ? const Color(0xFF16795A)
                      : const Color(0xFF7A8794),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTag extends StatelessWidget {
  const _AdminTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0D47A1),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AdminMetricData {
  const _AdminMetricData(
    this.label,
    this.value,
    this.detail,
    this.icon,
    this.color,
  );

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _AdminSidebarLabel extends StatelessWidget {
  const _AdminSidebarLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(9, 15, 9, 6),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF7696BA),
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _EcosystemNode extends StatelessWidget {
  const _EcosystemNode(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 118),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.28)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _VerticalConnector extends StatelessWidget {
  const _VerticalConnector();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 25,
    child: Column(
      children: [
        Expanded(child: VerticalDivider(width: 1, color: Color(0xFF9AB4D1))),
        Icon(Icons.keyboard_arrow_down, color: Color(0xFF6689B1), size: 14),
      ],
    ),
  );
}

class _AdminNoData extends StatelessWidget {
  const _AdminNoData({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F8FB),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xFFE1E7EF)),
    ),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFF8A9AAC), size: 27),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF667A8E), fontSize: 11),
        ),
      ],
    ),
  );
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17324D),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6A7D90), fontSize: 12),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    constraints: const BoxConstraints(minHeight: 126),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border(top: BorderSide(color: color, width: 4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D17324D),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF667A8E),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(color: Color(0xFF718397), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdminProgress extends StatelessWidget {
  const _AdminProgress(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            color: color,
            backgroundColor: const Color(0xFFE7EDF3),
          ),
        ),
      ],
    ),
  );
}

class _AdminScoreRing extends StatelessWidget {
  const _AdminScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 112,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: 102,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 10,
            color: const Color(0xFF16795A),
            backgroundColor: const Color(0xFFE5EDE9),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score%',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16795A),
              ),
            ),
            const Text('CONTROLLED', style: TextStyle(fontSize: 9)),
          ],
        ),
      ],
    ),
  );
}

class _AssuranceLine extends StatelessWidget {
  const _AssuranceLine(this.label, this.complete);

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          complete ? Icons.check_circle : Icons.pending_outlined,
          size: 18,
          color: complete ? const Color(0xFF16795A) : const Color(0xFF8B5B10),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _HierarchyNode extends StatelessWidget {
  const _HierarchyNode(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F6FA),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFFB8C8D8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF0B4D93)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _HierarchyArrow extends StatelessWidget {
  const _HierarchyArrow();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF7C8FA3));
}
