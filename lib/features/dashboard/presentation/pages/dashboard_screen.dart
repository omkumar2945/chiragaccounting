import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/constants/feature_flags.dart';
import 'package:chirag_accounting/core/accounting/accounting_policy_service.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/authentication/presentation/pages/login_screen.dart';
import 'package:chirag_accounting/features/dashboard/controllers/dashboard_controller.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/kpi_card_widget.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/client_business_dashboard_view.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/notifications_panel.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/quick_actions_widget.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/recent_activity_widget.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/sales_chart_widget.dart';
import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';
import 'package:chirag_accounting/features/clients/Bank/bank_statement_history_screen.dart';
import 'package:chirag_accounting/features/clients/Bank/bank_statement_service.dart';
import 'package:chirag_accounting/features/clients/Chat/client_chat_screen.dart';
import 'package:chirag_accounting/features/clients/Chat/services/chat_command_engine.dart';
import 'package:chirag_accounting/features/clients/Chat/services/command_api_models.dart';
import 'package:chirag_accounting/features/clients/Chat/services/command_api_service.dart';
import 'package:chirag_accounting/features/clients/Chat/services/speech/microphone_permission_service.dart';
import 'package:chirag_accounting/features/clients/Chat/services/speech/speech_provider.dart';
import 'package:chirag_accounting/features/clients/Chat/services/speech/speech_service.dart';
import 'package:chirag_accounting/features/clients/Chat/services/speech/web_mic_probe.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/compat/screens/client_data_exchange_screen_compat.dart';
import 'package:chirag_accounting/features/clients/financial_planning/presentation/pages/client_loan_planner_screen.dart';
import 'package:chirag_accounting/features/clients/Profile/client_profile_screen.dart';
import 'package:chirag_accounting/features/clients/Products/client_products_screen.dart';
import 'package:chirag_accounting/features/clients/Referral/client_referral_screen.dart';
import 'package:chirag_accounting/features/clients/Reports/client_reports_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/clients/Billing/presentation/pages/sales_voucher_system_screen.dart';
import 'package:chirag_accounting/features/compat/screens/purchase_screen_compat.dart';
import 'package:chirag_accounting/features/uni_desk/presentation/pages/uni_desk_screen.dart';
import 'package:chirag_accounting/features/compat/screens/sales_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/client_uploads_screen_compat.dart';
import 'package:chirag_accounting/features/clients/Uplads/smart_invoice_upload_screen.dart';
import 'package:chirag_accounting/features/clients/Vendors/client_vendors_screen.dart';
import 'package:chirag_accounting/features/masters/presentation/pages/other_ledgers_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/auditor_command_center_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/ca_compliance_review_center_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/manager_operations_center_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/my_work_queue_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/operations_center_screen.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/tax_invoice_screen.dart';
import 'package:chirag_accounting/features/customers/presentation/pages/add_customer_screen.dart';
import 'package:chirag_accounting/features/customers/presentation/pages/customers_screen.dart';
import 'package:chirag_accounting/features/clients/services/document_hub_service.dart';
import 'package:chirag_accounting/features/ca_workspace/presentation/pages/ca_team_workspace_screen.dart';
import 'package:chirag_accounting/features/products/presentation/pages/add_product_screen.dart';
import 'package:chirag_accounting/features/reports/presentation/pages/quick_provisional_report_screen.dart';
import 'package:chirag_accounting/features/vendors/presentation/pages/add_vendor_screen.dart';
import 'package:chirag_accounting/features/roles/controllers/role_controller.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/vouchers/presentation/models/voucher_entry_type.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_dashboard_screen.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _ClientSidebarGroup {
  const _ClientSidebarGroup({
    required this.name,
    required this.icon,
    required this.modules,
  });

  final String name;
  final IconData icon;
  final List<ClientModuleDefinition> modules;
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchCtrl = TextEditingController();
  final _supportInputCtrl = TextEditingController();
  final _supportScrollCtrl = ScrollController();
  final SpeechService _supportSpeechService =
      SpeechService.withDefaultProvider();
  final MicrophonePermissionService _supportMicrophonePermissionService =
      MicrophonePermissionService();
  final CommandApiService _supportCommandApiService = CommandApiService();
  final String _supportChatSessionId = CommandApiService.generateSessionId();

  bool _showSearch = false;
  bool _clientSidebarCollapsed = false;
  String _selectedClientSidebarItem = 'dashboard';
  final Set<String> _expandedClientSidebarGroups = <String>{'Accounting'};
  bool _isSupportChatOpen = false;
  bool _isSupportChatMinimized = false;
  bool _showEmojiPicker = false;
  bool _supportTyping = false;
  int _supportUnreadCount = 1;
  bool _supportListening = false;
  bool _supportTranscribing = false;
  String? _supportPendingBackendCommandId;
  int _supportVoiceSessionCounter = 0;
  String _supportVoiceSessionId = 'none';
  bool _supportVoiceSessionFinalized = false;
  String _supportVoiceStatus = 'IDLE';
  String _supportVoicePermission = 'NOT REQUESTED';
  String _supportVoiceSpeechApi = 'NOT CHECKED';
  String _supportVoiceMic = 'NOT CHECKED';
  String _supportVoiceAudio = 'IDLE';
  String _supportVoiceProvider = 'SpeechToTextProvider';
  String _supportVoiceTranscript = '';
  String _supportVoiceLastError = 'none';
  bool _supportVoiceAutoFinalizeQueued = false;
  bool _supportVoiceInitInProgress = false;
  bool _supportVoiceReady = false;
  bool _supportVoiceInitFailed = false;

  OverlayEntry? _supportChatOverlayEntry;

  final List<_SupportChatMessage> _supportMessages = <_SupportChatMessage>[
    const _SupportChatMessage(
      sender: 'Support',
      text:
          'Welcome to Chirag Support. You can type a message, use voice, or upload an invoice image/PDF.',
    ),
  ];

  static const List<String> _emojiChoices = <String>[
    '😀',
    '😊',
    '🙏',
    '👍',
    '🎉',
    '📄',
    '📎',
    '✅',
    '📌',
    '💬',
    '🧾',
    '📤',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardController>().loadDashboard();
      final user = context.read<AuthController>().currentUser;
      if (user?.role.isClient ?? false) {
        unawaited(
          context.read<ClientPortalAccessService>().refreshAuthoritative(
            user!.id,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _supportChatOverlayEntry?.remove();
    _supportChatOverlayEntry = null;
    _supportSpeechService.cancelListening();
    _searchCtrl.dispose();
    _supportInputCtrl.dispose();
    _supportScrollCtrl.dispose();
    super.dispose();
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsPanelSheet(),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthController>().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashCtrl = context.watch<DashboardController>();
    final authCtrl = context.watch<AuthController>();
    final roleCtrl = context.watch<RoleController>();
    final user = authCtrl.currentUser;
    final isClientUser = user?.role.isClient ?? false;
    final isCaAuditorUser = user != null && _isCaAuditorRole(user.role);
    final clientPlatform = kIsWeb
        ? ClientPortalPlatform.web
        : ClientPortalPlatform.mobile;
    final visibleClientModules = isClientUser && user != null
        ? context.watch<ClientPortalAccessService>().visibleModules(
            user.id,
            clientPlatform,
          )
        : const <ClientModuleDefinition>[];
    final visibleClientModuleIds = visibleClientModules
        .map((module) => module.id)
        .toSet();
    final desktopClient =
        isClientUser && MediaQuery.sizeOf(context).width >= 800;
    final selectedClientModule =
        desktopClient && _selectedClientSidebarItem != 'dashboard'
        ? visibleClientModules.cast<ClientModuleDefinition?>().firstWhere(
            (module) => module?.id == _selectedClientSidebarItem,
            orElse: () => null,
          )
        : null;
    final configuredPeriod = context.watch<AccountingPolicyService?>()?.period;
    final now = DateTime.now();
    final currentFinancialYearStart = now.month >= DateTime.april
        ? now.year
        : now.year - 1;
    final financialYearLabel =
        configuredPeriod?.financialYearLabel ??
        'FY $currentFinancialYearStart-${(currentFinancialYearStart + 1).toString().substring(2)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Search invoices, customers, GST...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: dashCtrl.setSearchQuery,
              )
            : Row(
                children: [
                  if (isClientUser)
                    _clientIdentityAvatar(user)
                  else
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'CA',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isClientUser
                        ? Text(
                            user?.firmName.trim().isNotEmpty == true
                                ? user!.firmName
                                : user?.name ?? 'Client',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Chirag Accounting',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (user != null)
                                Text(
                                  user.firmName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  dashCtrl.setSearchQuery('');
                }
              });
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _openNotifications,
              ),
              if (dashCtrl.unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${dashCtrl.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white24,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.role.displayName ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (!isClientUser || visibleClientModuleIds.contains('unidesk'))
                const PopupMenuItem(
                  value: 'unidesk',
                  child: Row(
                    children: [
                      Icon(Icons.desktop_windows_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Uni-Desk'),
                    ],
                  ),
                ),
              if (!isClientUser || visibleClientModuleIds.contains('profile'))
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
              if (!isClientUser || visibleClientModuleIds.contains('settings'))
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'unidesk') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UniDeskScreen()),
                );
              }
              if (v == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientProfileScreen(),
                  ),
                );
              }
              if (v == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientSettingsScreen(),
                  ),
                );
              }
              if (v == 'logout') _logout();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: desktopClient ? null : _buildDrawer(context, roleCtrl, user),
      body: Row(
        children: [
          if (desktopClient && user != null)
            _buildClientDesktopSidebar(context, user, visibleClientModules),
          Expanded(
            child: dashCtrl.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                  )
                : selectedClientModule != null
                ? KeyedSubtree(
                    key: ValueKey('client-content-${selectedClientModule.id}'),
                    child: selectedClientModule.builder(context),
                  )
                : isClientUser && user != null
                ? Stack(
                    children: [
                      ClientBusinessDashboardView(
                        user: user,
                        kpis: dashCtrl.kpiCards,
                        monthlySales: dashCtrl.monthlySales,
                        activities: dashCtrl.recentActivities,
                        notifications: dashCtrl.notifications,
                        visibleModules: visibleClientModules,
                        bankingPermissions: roleCtrl.bankingPermissions,
                        financialYearLabel: financialYearLabel,
                        onRefresh: dashCtrl.loadDashboard,
                      ),
                      if (visibleClientModuleIds.contains('chat'))
                        _buildSupportChatFab(context),
                    ],
                  )
                : Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: dashCtrl.loadDashboard,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Greeting
                              if (user != null) ...[
                                Text(
                                  '${_greeting()}, ${user.name.split(' ').first}!',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.role.displayName} \u00B7 ${user.firmName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // KPI Cards
                              const Text(
                                'Key Performance Indicators',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 144,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: dashCtrl.kpiCards.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (ctx, i) =>
                                      KpiCardWidget(kpi: dashCtrl.kpiCards[i]),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Chart
                              SalesChartWidget(
                                salesData: dashCtrl.monthlySales,
                                purchaseData: dashCtrl.monthlyPurchase,
                              ),

                              const SizedBox(height: 20),

                              // Quick Actions
                              const QuickActionsWidget(),

                              const SizedBox(height: 20),

                              // Recent Activities
                              RecentActivityWidget(
                                activities: dashCtrl.recentActivities,
                              ),

                              const SizedBox(height: 24),

                              // Role permission info
                              if (!isCaAuditorUser) ...[
                                _RolePermissionCard(roleCtrl: roleCtrl),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (isClientUser || isCaAuditorUser)
                        _buildSupportChatFab(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _clientIdentityAvatar(UserModel? user) {
    final clientName = user?.firmName.trim().isNotEmpty == true
        ? user!.firmName
        : user?.name ?? 'Client';
    final initials = clientName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final imageUrl = user?.profileImageUrl?.trim();

    return Container(
      width: 36,
      height: 36,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: imageUrl == null || imageUrl.isEmpty
          ? Center(
              child: Text(
                initials.isEmpty ? 'C' : initials,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initials.isEmpty ? 'C' : initials,
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildClientDesktopSidebar(
    BuildContext context,
    user,
    List<ClientModuleDefinition> modules,
  ) {
    const navy = Color(0xFF0B1F3A);
    final visibleModules = modules
        .where((module) => module.id != 'dashboard')
        .toList(growable: false);
    final groups = _clientSidebarGroups(visibleModules);
    return AnimatedContainer(
      key: const ValueKey('client-desktop-sidebar'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _clientSidebarCollapsed ? 76 : 272,
      color: navy,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('client-sidebar-menu'),
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                children: [
                  if (modules.any((module) => module.id == 'dashboard'))
                    _clientDesktopNavTile(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      navigationKey: const ValueKey('client-nav-dashboard'),
                      selected: _selectedClientSidebarItem == 'dashboard',
                      onTap: () => setState(
                        () => _selectedClientSidebarItem = 'dashboard',
                      ),
                    ),
                  if (_clientSidebarCollapsed)
                    for (final module in visibleModules)
                      _clientDesktopModuleTile(context, module)
                  else
                    for (final group in groups)
                      _clientDesktopNavGroup(context, group),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Material(
                color: const Color(0xFF193554),
                borderRadius: BorderRadius.circular(7),
                child: _clientSidebarCollapsed
                    ? Tooltip(
                        message: 'Expand menu',
                        child: InkWell(
                          key: const ValueKey('client-sidebar-collapse'),
                          onTap: () =>
                              setState(() => _clientSidebarCollapsed = false),
                          child: const SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: Icon(
                              Icons.keyboard_double_arrow_right_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                    : ListTile(
                        key: const ValueKey('client-sidebar-collapse'),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        leading: const Icon(
                          Icons.keyboard_double_arrow_left_rounded,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Collapse menu',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        onTap: () =>
                            setState(() => _clientSidebarCollapsed = true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientDesktopNavTile({
    required IconData icon,
    required String label,
    Key? navigationKey,
    bool selected = false,
    bool indented = false,
    VoidCallback? onTap,
  }) {
    if (_clientSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: Tooltip(
          message: label,
          child: Material(
            color: selected ? const Color(0xFF1E4D86) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              key: navigationKey,
              borderRadius: BorderRadius.circular(7),
              onTap: onTap,
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : const Color(0xFFB8C7DB),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final tile = Padding(
      padding: EdgeInsets.fromLTRB(indented ? 20 : 10, 1, 10, 1),
      child: Material(
        color: selected ? const Color(0xFF1E4D86) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: ListTile(
          key: navigationKey,
          dense: true,
          leading: Icon(
            icon,
            size: 19,
            color: selected ? Colors.white : const Color(0xFFB8C7DB),
          ),
          title: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFD7E0EC),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
    return tile;
  }

  List<_ClientSidebarGroup> _clientSidebarGroups(
    List<ClientModuleDefinition> modules,
  ) {
    const order = <String>[
      'Accounting',
      'Documents',
      'GST',
      'E-Invoicing',
      'E-Way Bill',
      'Reports',
      'Banking',
      'Finance',
      'Masters',
      'AI & Automation',
      'Compliance',
      'Workflow',
      'Communication',
      'Payroll',
      'General',
    ];
    final grouped = <String, List<ClientModuleDefinition>>{};
    for (final module in modules) {
      final group = switch (module.id) {
        'gst' => 'GST',
        'e_invoicing' => 'E-Invoicing',
        'eway_bill' => 'E-Way Bill',
        'bank' => 'Banking',
        'loan_planner' || 'investment_planner' => 'Finance',
        'ai_assistant' => 'AI & Automation',
        'settings' => 'General',
        _ => module.category,
      };
      grouped.putIfAbsent(group, () => <ClientModuleDefinition>[]).add(module);
    }
    return <_ClientSidebarGroup>[
      for (final name in order)
        if (grouped[name]?.isNotEmpty ?? false)
          _ClientSidebarGroup(
            name: name,
            icon: _clientSidebarGroupIcon(name),
            modules: grouped.remove(name)!,
          ),
      for (final entry in grouped.entries)
        _ClientSidebarGroup(
          name: entry.key,
          icon: _clientSidebarGroupIcon(entry.key),
          modules: entry.value,
        ),
    ];
  }

  IconData _clientSidebarGroupIcon(String group) => switch (group) {
    'Accounting' => Icons.calculate_outlined,
    'Documents' => Icons.folder_copy_outlined,
    'GST' => Icons.receipt_long_outlined,
    'E-Invoicing' => Icons.qr_code_2_outlined,
    'E-Way Bill' => Icons.local_shipping_outlined,
    'Reports' => Icons.bar_chart_outlined,
    'Banking' => Icons.account_balance_outlined,
    'Finance' => Icons.savings_outlined,
    'Masters' => Icons.inventory_2_outlined,
    'AI & Automation' => Icons.auto_awesome_outlined,
    'Compliance' => Icons.verified_user_outlined,
    'Workflow' => Icons.account_tree_outlined,
    'Communication' => Icons.forum_outlined,
    'Payroll' => Icons.groups_outlined,
    _ => Icons.tune_outlined,
  };

  Widget _clientDesktopNavGroup(
    BuildContext context,
    _ClientSidebarGroup group,
  ) {
    final expanded = _expandedClientSidebarGroups.contains(group.name);
    final hasSelected = group.modules.any(
      (module) => module.id == _selectedClientSidebarItem,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
          child: Material(
            color: hasSelected ? const Color(0xFF132F52) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              key: ValueKey('client-nav-group-${group.name}'),
              borderRadius: BorderRadius.circular(7),
              onTap: () => setState(() {
                if (expanded) {
                  _expandedClientSidebarGroups.remove(group.name);
                } else {
                  _expandedClientSidebarGroups.add(group.name);
                }
              }),
              child: SizedBox(
                height: 42,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        group.icon,
                        size: 19,
                        color: hasSelected
                            ? const Color(0xFF69A7F5)
                            : const Color(0xFFAFC1D8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          group.name.toUpperCase(),
                          style: TextStyle(
                            color: hasSelected
                                ? Colors.white
                                : const Color(0xFFD5DFEC),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 19,
                          color: Color(0xFF879CB7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  children: [
                    for (final module in group.modules)
                      _clientDesktopModuleTile(
                        context,
                        module,
                        parentGroup: group.name,
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _clientDesktopModuleTile(
    BuildContext context,
    ClientModuleDefinition module, {
    String? parentGroup,
  }) {
    return _clientDesktopNavTile(
      icon: module.icon,
      label: module.displayName,
      navigationKey: ValueKey('client-nav-${module.id}'),
      selected: _selectedClientSidebarItem == module.id,
      indented: !_clientSidebarCollapsed,
      onTap: () => setState(() {
        _selectedClientSidebarItem = module.id;
        if (parentGroup != null) {
          _expandedClientSidebarGroups.remove(parentGroup);
        }
      }),
    );
  }

  Widget _clientSidebarSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF7187A3),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, RoleController role, user) {
    final isClientUser = user?.role.isClient ?? false;
    final isCaAuditorUser = user != null && _isCaAuditorRole(user.role);
    final isOperationsAdminUser =
        user != null &&
        (user.role == UserRole.superAdmin ||
            user.role == UserRole.admin ||
            user.role == UserRole.firmAdmin ||
            user.role == UserRole.businessOwner);
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1565C0)),
            accountName: Text(user?.name ?? 'User'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            otherAccountsPictures: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user?.role.displayName ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (!isClientUser)
                  _drawerItem(
                    context,
                    Icons.dashboard,
                    'Dashboard',
                    true,
                    () => Navigator.pop(context),
                  ),
                if (!isClientUser && !isOperationsAdminUser)
                  if (!isCaAuditorUser)
                    _drawerItem(
                      context,
                      Icons.desktop_windows_outlined,
                      'Uni-Desk',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UniDeskScreen(),
                          ),
                        );
                      },
                    ),
                if (isOperationsAdminUser)
                  _drawerItem(
                    context,
                    Icons.hub_outlined,
                    'Operations Center',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OperationsCenterScreen(),
                        ),
                      );
                    },
                  ),
                if (user?.role == UserRole.manager)
                  _drawerItem(
                    context,
                    Icons.supervisor_account_outlined,
                    'Manager Operations',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManagerOperationsCenterScreen(),
                        ),
                      );
                    },
                  ),
                if (user?.role == UserRole.partner)
                  _drawerItem(
                    context,
                    Icons.fact_check_outlined,
                    'Auditor Command Center',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuditorCommandCenterScreen(),
                        ),
                      );
                    },
                  ),
                if (user?.role == UserRole.checker)
                  _drawerItem(
                    context,
                    Icons.verified_user_outlined,
                    'Compliance Review Center',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const CaComplianceReviewCenterScreen(),
                        ),
                      );
                    },
                  ),
                if (user?.role == UserRole.accountant)
                  _drawerItem(
                    context,
                    Icons.assignment_outlined,
                    'My Work Queue',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyWorkQueueScreen(),
                        ),
                      );
                    },
                  ),
                if (isCaAuditorUser) ..._buildCaAuditorMenuItems(context),
                if (isClientUser) ..._buildClientMenuItems(context),
                if (!isClientUser && !isCaAuditorUser) ...[
                  if (role.canAccess(AppModule.sales))
                    _drawerItem(
                      context,
                      Icons.point_of_sale,
                      'Sales Invoices',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SalesScreen(),
                          ),
                        );
                      },
                    ),
                  if (role.canAccess(AppModule.sales))
                    _drawerItem(
                      context,
                      Icons.receipt_long_outlined,
                      'Tax Invoices',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TaxInvoiceScreen(),
                          ),
                        );
                      },
                    ),
                  if (role.canAccess(AppModule.purchase))
                    _drawerItem(
                      context,
                      Icons.shopping_cart_outlined,
                      'Purchase',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PurchaseScreen(),
                          ),
                        );
                      },
                    ),
                  if (FeatureFlags.bankingEnabled &&
                      role.canAccess(AppModule.banking))
                    _drawerItem(
                      context,
                      Icons.account_balance_outlined,
                      'Bank',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientBankScreen(),
                          ),
                        );
                      },
                    ),
                  if (role.canAccess(AppModule.referral))
                    _drawerItem(
                      context,
                      Icons.group_add_outlined,
                      'Referral Rewards',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientReferralScreen(),
                          ),
                        );
                      },
                    ),
                  if (role.canAccess(AppModule.chat))
                    _drawerItem(
                      context,
                      Icons.chat_bubble_outline,
                      'Chat',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientChatScreen(),
                          ),
                        );
                      },
                    ),
                  if (role.canAccess(AppModule.uploads))
                    _drawerItem(
                      context,
                      Icons.upload_file_outlined,
                      'Uploads',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientUploadsScreen(),
                          ),
                        );
                      },
                    ),
                  if (role.canAccess(AppModule.uploads))
                    _drawerItem(
                      context,
                      Icons.import_export_outlined,
                      'Data Exchange',
                      false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientDataExchangeScreen(),
                          ),
                        );
                      },
                    ),
                  if (FeatureFlags.bankingEnabled &&
                      role.canAccess(AppModule.banking))
                    _voucherFolderItem(context, role, isClientUser: false),
                ],
                if (isClientUser &&
                    (role.canAccess(AppModule.customers) ||
                        role.canAccess(AppModule.products)))
                  _mastersFolderItem(context, role),
                if (FeatureFlags.bankingEnabled &&
                    !isClientUser &&
                    !isCaAuditorUser &&
                    role.canAccess(AppModule.banking))
                  _bankingFolderItem(context, role),
                if (!isClientUser &&
                    !isCaAuditorUser &&
                    role.canAccess(AppModule.gst))
                  _drawerItem(
                    context,
                    Icons.receipt_long_outlined,
                    'GST',
                    false,
                    () => Navigator.pop(context),
                  ),
                if (!isClientUser && role.canAccess(AppModule.reports))
                  _reportsFolderItem(
                    context,
                    role,
                    caAuditorMode: isCaAuditorUser,
                  ),
                if (!isCaAuditorUser && role.canAccess(AppModule.users))
                  _drawerItem(
                    context,
                    Icons.manage_accounts_outlined,
                    'User Management',
                    false,
                    () => Navigator.pop(context),
                  ),
                if (!isCaAuditorUser && role.canAccess(AppModule.settings))
                  _drawerItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClientSettingsScreen(),
                        ),
                      );
                    },
                  ),
                const Divider(),
                _drawerItem(
                  context,
                  Icons.logout,
                  'Logout',
                  false,
                  _logout,
                  color: Colors.red,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Chirag Accounting v1.0',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCaAuditorRole(UserRole role) {
    return role == UserRole.firmAdmin ||
        role == UserRole.checker ||
        role == UserRole.partner;
  }

  List<Widget> _buildCaAuditorMenuItems(BuildContext context) {
    final userRole = context.read<AuthController>().currentUser?.role;
    final showQuickProvisional = userRole != null && _isCaAuditorRole(userRole);

    return [
      _drawerItem(context, Icons.point_of_sale, 'Billing', false, () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesVoucherSystemScreen()),
        );
      }),
      _drawerItem(
        context,
        Icons.groups_outlined,
        'CA Team Workspace',
        false,
        () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CaTeamWorkspaceScreen()),
          );
        },
      ),
      _reportsFolderItem(
        context,
        context.read<RoleController>(),
        caAuditorMode: true,
        includeQuickProvisional: showQuickProvisional,
      ),
      _caAdjustmentEntriesItem(context),
    ];
  }

  Widget _caAdjustmentEntriesItem(BuildContext context) {
    return ExpansionTile(
      leading: Icon(Icons.tune_outlined, color: Colors.grey.shade700, size: 22),
      title: Text(
        'Adjustment Entries',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
      children: [
        _bankingSubItem(
          context,
          Icons.menu_book_outlined,
          'Journal Voucher',
          onTap: () => _openVoucherEntry(context, VoucherEntryType.journal),
        ),
        _bankingSubItem(
          context,
          Icons.payments_outlined,
          'Payment Voucher',
          onTap: () => _openVoucherEntry(context, VoucherEntryType.payment),
        ),
        _bankingSubItem(
          context,
          Icons.account_balance_wallet_outlined,
          'Receipt Voucher',
          onTap: () => _openVoucherEntry(context, VoucherEntryType.receipt),
        ),
        _bankingSubItem(
          context,
          Icons.inventory_2_outlined,
          'Stock Adjustment (Journal)',
          onTap: () => _openVoucherEntry(context, VoucherEntryType.journal),
        ),
      ],
    );
  }

  Widget _bankingFolderItem(
    BuildContext context,
    RoleController role, {
    bool isClientUser = false,
    bool showLoanPlanner = false,
  }) {
    final allowViewBalance = isClientUser
        ? role.canAccess(AppModule.banking)
        : role.canBank(BankingPermission.viewBalance);
    final allowViewStatement = isClientUser
        ? role.canAccess(AppModule.banking)
        : role.canBank(BankingPermission.viewStatements);

    return ExpansionTile(
      leading: Icon(
        Icons.account_balance_outlined,
        color: Colors.grey.shade700,
        size: 22,
      ),
      title: Text(
        'Banking',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
      children: [
        if (allowViewBalance)
          _bankingSubItem(
            context,
            Icons.account_balance_wallet_outlined,
            'View Balance',
          ),
        if (allowViewStatement)
          _bankingSubItem(
            context,
            Icons.description_outlined,
            'View Statement',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BankStatementHistoryScreen(
                    service: BankStatementService(),
                  ),
                ),
              );
            },
          ),
        _bankingSubItem(
          context,
          Icons.sync_alt_outlined,
          'Bank Pulling',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientBankScreen()),
            );
          },
        ),
        if (showLoanPlanner)
          _bankingSubItem(
            context,
            Icons.account_balance_wallet_outlined,
            'Loan Planner',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientLoanPlannerScreen(),
                ),
              );
            },
          ),
      ],
    );
  }

  List<Widget> _buildClientMenuItems(BuildContext context) {
    final user = context.read<AuthController>().currentUser;
    final access = context.watch<ClientPortalAccessService>();
    final platform = kIsWeb
        ? ClientPortalPlatform.web
        : ClientPortalPlatform.mobile;
    final visibleModules = user == null
        ? const <ClientModuleDefinition>[]
        : access.visibleModules(user.id, platform);

    return visibleModules
        .map((module) {
          return _drawerItem(
            context,
            module.icon,
            module.displayName,
            module.id == 'dashboard',
            () {
              Navigator.pop(context);
              if (module.id != 'dashboard') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: module.builder),
                );
              }
            },
          );
        })
        .toList(growable: false);
  }

  Widget _clientAccountingSystemFolderItem(
    BuildContext context,
    RoleController role,
  ) {
    return ExpansionTile(
      leading: Icon(
        Icons.menu_book_outlined,
        color: Colors.grey.shade700,
        size: 22,
      ),
      title: Text(
        'Accounting System',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
      children: [
        if (context
            .read<ClientPortalAccessService>()
            .visibleModules(
              context.read<AuthController>().currentUser?.id ?? '',
              kIsWeb ? ClientPortalPlatform.web : ClientPortalPlatform.mobile,
            )
            .any((module) => module.id == 'billing_system'))
          _bankingSubItem(
            context,
            Icons.point_of_sale,
            'Billing',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SalesVoucherSystemScreen(),
                ),
              );
            },
          ),
        if (role.canAccess(AppModule.sales))
          if (context
              .read<ClientPortalAccessService>()
              .visibleModules(
                context.read<AuthController>().currentUser?.id ?? '',
                kIsWeb ? ClientPortalPlatform.web : ClientPortalPlatform.mobile,
              )
              .any((module) => module.id == 'sales'))
            _bankingSubItem(
              context,
              Icons.point_of_sale,
              'Sales Invoice',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SalesScreen()),
                );
              },
            ),
        if (role.canAccess(AppModule.purchase))
          if (context
              .read<ClientPortalAccessService>()
              .visibleModules(
                context.read<AuthController>().currentUser?.id ?? '',
                kIsWeb ? ClientPortalPlatform.web : ClientPortalPlatform.mobile,
              )
              .any((module) => module.id == 'purchase'))
            _bankingSubItem(
              context,
              Icons.shopping_cart_outlined,
              'Purchase',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PurchaseScreen()),
                );
              },
            ),
        ExpansionTile(
          leading: Icon(
            Icons.receipt_long_outlined,
            color: Colors.grey.shade700,
            size: 20,
          ),
          title: Text(
            'Voucher Entry',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          tilePadding: const EdgeInsets.only(left: 8, right: 4),
          childrenPadding: const EdgeInsets.only(left: 12, right: 4),
          children: [
            _bankingSubItem(
              context,
              Icons.dashboard_outlined,
              'Voucher Entry Dashboard',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VoucherEntryDashboardScreen(),
                  ),
                );
              },
            ),
            _bankingSubItem(
              context,
              Icons.payments_outlined,
              'Payment Voucher',
              onTap: () => _openVoucherEntry(context, VoucherEntryType.payment),
            ),
            _bankingSubItem(
              context,
              Icons.account_balance_wallet_outlined,
              'Receipt Voucher',
              onTap: () => _openVoucherEntry(context, VoucherEntryType.receipt),
            ),
            _bankingSubItem(
              context,
              Icons.compare_arrows_outlined,
              'Contra Voucher',
              onTap: () => _openVoucherEntry(context, VoucherEntryType.contra),
            ),
            _bankingSubItem(
              context,
              Icons.menu_book_outlined,
              'Journal Voucher',
              onTap: () => _openVoucherEntry(context, VoucherEntryType.journal),
            ),
            _bankingSubItem(
              context,
              Icons.point_of_sale,
              'Sales Voucher',
              onTap: () => _openVoucherEntry(context, VoucherEntryType.sales),
            ),
            _bankingSubItem(
              context,
              Icons.shopping_cart_outlined,
              'Purchase Voucher',
              onTap: () =>
                  _openVoucherEntry(context, VoucherEntryType.purchase),
            ),
            _bankingSubItem(
              context,
              Icons.assignment_late_outlined,
              'Debit Note',
              onTap: () =>
                  _openVoucherEntry(context, VoucherEntryType.debitNote),
            ),
            _bankingSubItem(
              context,
              Icons.assignment_return_outlined,
              'Credit Note',
              onTap: () =>
                  _openVoucherEntry(context, VoucherEntryType.creditNote),
            ),
            _bankingSubItem(
              context,
              Icons.money_off_csred_outlined,
              'Expense Voucher',
              onTap: () => _openVoucherEntry(context, VoucherEntryType.expense),
            ),
            _bankingSubItem(
              context,
              Icons.account_balance_outlined,
              'Income Voucher',
              onTap: () => _openVoucherEntry(context, VoucherEntryType.income),
            ),
            _bankingSubItem(
              context,
              Icons.account_balance_outlined,
              'Bank Transfer',
              onTap: () =>
                  _openVoucherEntry(context, VoucherEntryType.bankTransfer),
            ),
            _bankingSubItem(
              context,
              Icons.currency_rupee_outlined,
              'Cash Transfer',
              onTap: () =>
                  _openVoucherEntry(context, VoucherEntryType.cashTransfer),
            ),
          ],
        ),
      ],
    );
  }

  void _openVoucherEntry(BuildContext context, VoucherEntryType type) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VoucherEntryFormScreen(type: type)),
    );
  }

  Widget _clientUploadsFolderItem(BuildContext context) {
    void openUpload(String source) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientUploadsScreen(
            autoPickOnOpen: true,
            autoRouteAfterDetect: true,
            autoRouteSource: source,
          ),
        ),
      );
    }

    return ExpansionTile(
      leading: Icon(
        Icons.upload_file_outlined,
        color: Colors.grey.shade700,
        size: 22,
      ),
      title: Text(
        'Uploads',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
      children: [
        _bankingSubItem(
          context,
          Icons.receipt_long_outlined,
          'Upload Sales Invoice',
          onTap: () => openUpload('upload-sales-invoice'),
        ),
        _bankingSubItem(
          context,
          Icons.shopping_cart_outlined,
          'Upload Purchase Invoice',
          onTap: () => openUpload('upload-purchase-invoice'),
        ),
        _bankingSubItem(
          context,
          Icons.payments_outlined,
          'Upload Cheque',
          onTap: () => openUpload('upload-cheque'),
        ),
        _bankingSubItem(
          context,
          Icons.account_balance_wallet_outlined,
          'Upload Cheque Receipt',
          onTap: () => openUpload('upload-cheque-receipt'),
        ),
        _bankingSubItem(
          context,
          Icons.attach_money_outlined,
          'Upload Cash Deposit Slip',
          onTap: () => openUpload('upload-cash-deposit-slip'),
        ),
        _bankingSubItem(
          context,
          Icons.account_balance_outlined,
          'Upload Bank Document',
          onTap: () => openUpload('upload-bank-document'),
        ),
        _bankingSubItem(
          context,
          Icons.picture_as_pdf_outlined,
          'Upload PDF/Image',
          onTap: () => openUpload('upload-generic'),
        ),
        _bankingSubItem(
          context,
          Icons.auto_awesome_outlined,
          'Smart Invoice V2',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SmartInvoiceUploadScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _voucherFolderItem(
    BuildContext context,
    RoleController role, {
    required bool isClientUser,
  }) {
    final allowPayment = isClientUser
        ? role.canAccess(AppModule.banking)
        : role.canBank(BankingPermission.createPaymentVoucher);
    final allowReceipt = isClientUser
        ? role.canAccess(AppModule.banking)
        : role.canBank(BankingPermission.createReceiptVoucher);
    final allowCreditNote = isClientUser
        ? role.canAccess(AppModule.banking)
        : role.canBank(BankingPermission.createCreditNoteVoucher);
    final allowDebitNote = isClientUser
        ? role.canAccess(AppModule.banking)
        : role.canBank(BankingPermission.createDebitNoteVoucher);

    return ExpansionTile(
      leading: Icon(
        Icons.receipt_long_outlined,
        color: Colors.grey.shade700,
        size: 22,
      ),
      title: Text(
        'Vouchers',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
      children: [
        _bankingSubItem(
          context,
          Icons.dashboard_outlined,
          'Voucher Entry Dashboard',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoucherEntryDashboardScreen(),
              ),
            );
          },
        ),
        if (allowPayment)
          _bankingSubItem(
            context,
            Icons.payments_outlined,
            'Payment Voucher',
            onTap: () {
              _openVoucherEntry(context, VoucherEntryType.payment);
            },
          ),
        if (allowReceipt)
          _bankingSubItem(
            context,
            Icons.account_balance_wallet_outlined,
            'Receipt Voucher',
            onTap: () {
              _openVoucherEntry(context, VoucherEntryType.receipt);
            },
          ),
        if (allowCreditNote)
          _bankingSubItem(
            context,
            Icons.assignment_return_outlined,
            'Sales Return (Credit Note)',
            onTap: () {
              _openVoucherEntry(context, VoucherEntryType.creditNote);
            },
          ),
        if (allowDebitNote)
          _bankingSubItem(
            context,
            Icons.assignment_late_outlined,
            'Purchase Return (Debit Note)',
            onTap: () {
              _openVoucherEntry(context, VoucherEntryType.debitNote);
            },
          ),
      ],
    );
  }

  Widget _mastersFolderItem(BuildContext context, RoleController role) {
    return ExpansionTile(
      leading: Icon(
        Icons.folder_open_outlined,
        color: Colors.grey.shade700,
        size: 22,
      ),
      title: Text(
        'Masters',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
      children: [
        if (role.canAccess(AppModule.products))
          _bankingSubItem(
            context,
            Icons.add_box_outlined,
            'Products - Create',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProductScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.products))
          _bankingSubItem(
            context,
            Icons.inventory_2_outlined,
            'Products - View',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientProductsScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.products))
          _bankingSubItem(
            context,
            Icons.edit_note_outlined,
            'Products - Edit',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientProductsScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.person_add_alt_1_outlined,
            'Customers - Create',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.people_outline,
            'Customers - View',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.edit_outlined,
            'Customers - Edit',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.storefront_outlined,
            'Suppliers - Create',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddVendorScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.store_mall_directory_outlined,
            'Suppliers - View',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientVendorsScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.edit_note,
            'Suppliers - Edit',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientVendorsScreen()),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.library_add_outlined,
            'Other Ledgers - Create',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OtherLedgersScreen(
                    initialMode: OtherLedgerMode.create,
                  ),
                ),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.menu_book_outlined,
            'Other Ledgers - View',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OtherLedgersScreen(
                    initialMode: OtherLedgerMode.view,
                  ),
                ),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.edit_calendar_outlined,
            'Other Ledgers - Edit',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OtherLedgersScreen(
                    initialMode: OtherLedgerMode.edit,
                  ),
                ),
              );
            },
          ),
        if (role.canAccess(AppModule.customers))
          _bankingSubItem(
            context,
            Icons.account_tree_outlined,
            'Ledger Categories',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OtherLedgersScreen(
                    initialMode: OtherLedgerMode.view,
                  ),
                ),
              );
            },
          ),
        _bankingSubItem(
          context,
          Icons.tag_outlined,
          'HSN/SAC',
          onTap: () => _showMasterComingSoon(context, 'HSN/SAC'),
        ),
        _bankingSubItem(
          context,
          Icons.straighten_outlined,
          'Units',
          onTap: () => _showMasterComingSoon(context, 'Units'),
        ),
        _bankingSubItem(
          context,
          Icons.percent_outlined,
          'GST Rates',
          onTap: () => _showMasterComingSoon(context, 'GST Rates'),
        ),
        _bankingSubItem(
          context,
          Icons.price_change_outlined,
          'Price Lists',
          onTap: () => _showMasterComingSoon(context, 'Price Lists'),
        ),
        _bankingSubItem(
          context,
          Icons.center_focus_strong_outlined,
          'Cost Centres',
          onTap: () => _showMasterComingSoon(context, 'Cost Centres'),
        ),
      ],
    );
  }

  void _showMasterComingSoon(BuildContext context, String moduleName) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$moduleName master is available in upcoming update.'),
      ),
    );
  }

  Widget _buildSupportChatFab(BuildContext context) {
    if (_isSupportChatOpen) return const SizedBox.shrink();

    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        child: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: FloatingActionButton(
                  heroTag: 'support_chat_fab',
                  backgroundColor: const Color(0xFF1565C0),
                  onPressed: () => _openSupportChatOverlay(),
                  child: const Icon(Icons.support_agent_outlined),
                ),
              ),
              if (_supportUnreadCount > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_supportUnreadCount.clamp(0, 99)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSupportChatOverlay() {
    if (_supportChatOverlayEntry != null) return;

    _resetSupportVoiceState();

    setState(() {
      _isSupportChatOpen = true;
      _supportUnreadCount = 0;
    });

    _supportChatOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        final screenWidth = media.size.width;
        final screenHeight = media.size.height;
        final maxPopupWidth = math.max(280.0, screenWidth - 40);
        final popupWidth = math
            .min(380.0, maxPopupWidth)
            .clamp(280.0, 380.0)
            .toDouble();
        final popupHeight = math
            .min(560.0, screenHeight - 40)
            .clamp(280.0, 600.0)
            .toDouble();
        final userName =
            context.read<AuthController>().currentUser?.name ?? 'Client';

        return Positioned(
          right: 20,
          bottom: 20,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: popupWidth,
                height: _isSupportChatMinimized ? 86 : popupHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1565C0),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hello $userName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'How can we help you?',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: _isSupportChatMinimized
                                ? 'Expand'
                                : 'Minimize',
                            icon: Icon(
                              _isSupportChatMinimized
                                  ? Icons.unfold_more
                                  : Icons.unfold_less,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _isSupportChatMinimized =
                                  !_isSupportChatMinimized;
                              _supportChatOverlayEntry?.markNeedsBuild();
                              if (!_isSupportChatMinimized) {
                                _scrollSupportToLatest();
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _closeSupportChatOverlay,
                          ),
                        ],
                      ),
                    ),
                    if (!_isSupportChatMinimized) ...[
                      Expanded(
                        child: Container(
                          color: const Color(0xFFF7F9FD),
                          child: ListView.builder(
                            controller: _supportScrollCtrl,
                            padding: const EdgeInsets.all(12),
                            itemCount:
                                _supportMessages.length +
                                (_supportTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_supportTyping &&
                                  index == _supportMessages.length) {
                                return _buildTypingIndicator();
                              }

                              final msg = _supportMessages[index];
                              final isClient = msg.sender == 'Client';
                              final align = isClient
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start;
                              final bubbleColor = isClient
                                  ? const Color(0xFFE6F0FF)
                                  : Colors.white;

                              return Column(
                                crossAxisAlignment: align,
                                children: [
                                  Text(
                                    msg.sender,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth: popupWidth * 0.78,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bubbleColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (msg.attachmentName != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.blueGrey.shade100,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  msg.attachmentKind == 'PDF'
                                                      ? Icons
                                                            .picture_as_pdf_outlined
                                                      : Icons.image_outlined,
                                                  size: 18,
                                                  color:
                                                      Colors.blueGrey.shade700,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    msg.attachmentName!,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        Text(msg.text),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (_showEmojiPicker)
                        Container(
                          height: 116,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: GridView.builder(
                            itemCount: _emojiChoices.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  mainAxisSpacing: 6,
                                  crossAxisSpacing: 6,
                                ),
                            itemBuilder: (context, index) {
                              final emoji = _emojiChoices[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  _supportInputCtrl.text =
                                      '${_supportInputCtrl.text}$emoji';
                                  _supportInputCtrl.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: _supportInputCtrl.text.length,
                                        ),
                                      );
                                  _supportChatOverlayEntry?.markNeedsBuild();
                                },
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (kDebugMode) _buildSupportVoiceDiagnostics(),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Upload image/pdf',
                              onPressed: _pickSupportAttachment,
                              icon: const Icon(Icons.attach_file),
                            ),
                            IconButton(
                              tooltip: 'Emoji',
                              onPressed: () {
                                _showEmojiPicker = !_showEmojiPicker;
                                _supportChatOverlayEntry?.markNeedsBuild();
                              },
                              icon: const Icon(Icons.emoji_emotions_outlined),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _supportInputCtrl,
                                minLines: 1,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Type message...',
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF3F6FB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (_) => _sendSupportMessage(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: _supportListening
                                  ? 'Stop listening'
                                  : 'Voice command',
                              onPressed: _onSupportMicrophonePressed,
                              icon: Icon(
                                _supportMicIcon,
                                color: _supportMicColor(context),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filled(
                              onPressed: _sendSupportMessage,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_supportChatOverlayEntry!);
    unawaited(_refreshSupportVoiceDiagnostics(includeMicrophone: false));
    _scrollSupportToLatest();
  }

  Future<bool> _initializeSupportVoiceProvider({bool force = false}) async {
    if (_supportVoiceInitInProgress) return _supportVoiceReady;
    if (_supportVoiceReady && !force) {
      await _refreshSupportVoiceDiagnostics(includeMicrophone: false);
      return true;
    }

    _supportVoiceInitInProgress = true;
    _supportVoiceInitFailed = false;
    _clearSupportVoiceError();
    _logSupportVoice('VOICE INIT START');

    if (mounted) {
      setState(() {});
    }
    _supportChatOverlayEntry?.markNeedsBuild();

    try {
      await _refreshSupportVoiceDiagnostics(includeMicrophone: false);

      final initialized = await _supportSpeechService.initializeProvider(
        timeout: const Duration(seconds: 6),
      );

      if (!initialized) {
        final providerErrorCode = _supportSpeechService.getLastErrorCode();
        final providerErrorMessage = _supportSpeechService
            .getLastErrorMessage();

        final timeoutCode = SpeechProvider.errorInitializationTimeout;
        final resolvedCode = providerErrorCode.isEmpty
            ? timeoutCode
            : providerErrorCode;
        final resolvedMessage = providerErrorMessage.isEmpty
            ? 'Voice provider initialization timed out.'
            : providerErrorMessage;

        _supportVoiceReady = false;
        _supportVoiceInitFailed = true;
        _supportVoiceSpeechApi = _supportSpeechService.isSpeechApiAvailable
            ? 'AVAILABLE'
            : 'UNAVAILABLE';
        _setSupportVoiceError(resolvedCode, resolvedMessage);
        _logSupportVoice(
          'VOICE INIT FAILED',
          details: <String, Object?>{
            'errorCode': resolvedCode,
            'errorMessage': resolvedMessage,
          },
        );
        return false;
      }

      _supportVoiceReady = true;
      _supportVoiceInitFailed = false;
      _supportVoiceSpeechApi = _supportSpeechService.isSpeechApiAvailable
          ? 'AVAILABLE'
          : 'UNAVAILABLE';
      if (_supportVoiceSpeechApi == 'UNAVAILABLE') {
        _supportVoiceReady = false;
        _supportVoiceInitFailed = true;
        _setSupportVoiceError(
          SpeechProvider.errorSpeechApiUnavailable,
          'Speech engine unavailable after initialization.',
        );
        _logSupportVoice(
          'VOICE INIT FAILED',
          details: <String, Object?>{
            'errorCode': SpeechProvider.errorSpeechApiUnavailable,
            'errorMessage': 'Speech engine unavailable after initialization.',
          },
        );
        return false;
      }

      _logSupportVoice('VOICE INIT SUCCESS');
      return true;
    } on TimeoutException {
      _supportVoiceReady = false;
      _supportVoiceInitFailed = true;
      _supportVoiceSpeechApi = 'UNAVAILABLE';
      _setSupportVoiceError(
        SpeechProvider.errorInitializationTimeout,
        'Voice provider initialization timed out.',
      );
      _logSupportVoice(
        'VOICE INIT FAILED',
        details: <String, Object?>{
          'errorCode': SpeechProvider.errorInitializationTimeout,
          'errorMessage': 'Voice provider initialization timed out.',
        },
      );
      return false;
    } catch (error) {
      _supportVoiceReady = false;
      _supportVoiceInitFailed = true;
      _supportVoiceSpeechApi = 'UNAVAILABLE';
      _setSupportVoiceError('PROVIDER_INITIALIZATION_FAILED', error.toString());
      _logSupportVoice(
        'VOICE INIT FAILED',
        details: <String, Object?>{
          'errorCode': 'PROVIDER_INITIALIZATION_FAILED',
          'errorMessage': error.toString(),
        },
      );
      return false;
    } finally {
      _supportVoiceInitInProgress = false;
      if (mounted) {
        setState(() {});
      }
      _supportChatOverlayEntry?.markNeedsBuild();
    }
  }

  Future<void> _refreshSupportVoiceDiagnostics({
    required bool includeMicrophone,
  }) async {
    if (kIsWeb) {
      if (!includeMicrophone) {
        final speechApiAvailable = await probeWebSpeechApiAvailability();
        _supportVoiceSpeechApi = speechApiAvailable
            ? 'AVAILABLE'
            : 'UNAVAILABLE';
        if (!mounted) return;
        setState(() {});
        _supportChatOverlayEntry?.markNeedsBuild();
        return;
      }

      final probe = await probeWebMicrophoneAndSpeechApi();
      _supportVoiceSpeechApi = probe.speechApiAvailable
          ? 'AVAILABLE'
          : 'UNAVAILABLE';
      _supportVoicePermission = probe.permissionGranted
          ? 'GRANTED'
          : (probe.errorCode == SpeechProvider.errorPermissionDenied
                ? 'DENIED'
                : 'PROMPT/UNKNOWN');
      _supportVoiceMic = (probe.microphoneAvailable && probe.audioTrackLive)
          ? 'AVAILABLE'
          : 'NOT AVAILABLE';
      _supportVoiceAudio = probe.audioTrackLive ? 'READY' : 'IDLE';
      if (!probe.permissionGranted && probe.errorMessage.isNotEmpty) {
        _setSupportVoiceError(
          probe.errorCode.isEmpty
              ? SpeechProvider.errorPermissionDenied
              : probe.errorCode,
          probe.errorMessage,
        );
      }
    } else {
      if (!includeMicrophone) {
        _supportVoiceSpeechApi = 'AVAILABLE';
        if (!mounted) return;
        setState(() {});
        _supportChatOverlayEntry?.markNeedsBuild();
        return;
      }

      final permission = await _supportMicrophonePermissionService
          .checkPermission();
      final micAvailable = await _supportMicrophonePermissionService
          .isMicrophoneAvailable();

      _supportVoicePermission = permission.name.toUpperCase();
      _supportVoiceMic = micAvailable ? 'AVAILABLE' : 'NOT AVAILABLE';
      _supportVoiceSpeechApi = _supportSpeechService.isSpeechApiAvailable
          ? 'AVAILABLE'
          : 'UNAVAILABLE';
    }

    if (!mounted) return;
    setState(() {});
    _supportChatOverlayEntry?.markNeedsBuild();
  }

  void _closeSupportChatOverlay() {
    unawaited(_supportSpeechService.cancelListening());
    _supportChatOverlayEntry?.remove();
    _supportChatOverlayEntry = null;
    _resetSupportVoiceState();

    if (mounted) {
      setState(() {
        _isSupportChatOpen = false;
        _isSupportChatMinimized = false;
        _showEmojiPicker = false;
        _supportTyping = false;
      });
    }
  }

  Future<void> _runSupportLocalFallback(
    String message, {
    required CommandApiInputType inputType,
  }) async {
    final auth = context.read<AuthController>();
    final userId = auth.currentUser?.id;
    final botEnabled =
        userId != null &&
        context
            .read<ClientPortalAccessService>()
            .profileFor(userId)
            .documentHubAccess
            .enableWhatsAppCommands;

    final engine = ChatCommandEngine(
      documentHubService: context.read<DocumentHubService>(),
    );
    final result = engine.process(
      input: message,
      inputType: inputType == CommandApiInputType.voice
          ? CommandInputType.voice
          : (inputType == CommandApiInputType.ocr
                ? CommandInputType.ocr
                : CommandInputType.text),
      botEnabled: botEnabled,
    );

    _supportMessages.add(
      _SupportChatMessage(sender: 'Support', text: result.message),
    );
    _supportChatOverlayEntry?.markNeedsBuild();
    _scrollSupportToLatest();
  }

  void _queueSupportVoiceAutoComplete(String sessionId) {
    if (_supportVoiceAutoFinalizeQueued || _supportVoiceSessionFinalized) {
      return;
    }
    if (_supportVoiceSessionId != sessionId) return;

    _supportVoiceAutoFinalizeQueued = true;
    Future<void>.microtask(() async {
      if (_supportVoiceSessionFinalized ||
          _supportVoiceSessionId != sessionId) {
        return;
      }
      await _stopAndSendSupportVoice();
    });
  }

  Future<void> _sendSupportMessage({
    CommandApiInputType inputType = CommandApiInputType.text,
    String? overrideMessage,
  }) async {
    final message = (overrideMessage ?? _supportInputCtrl.text).trim();
    if (message.isEmpty) return;

    if (overrideMessage == null) {
      _supportInputCtrl.clear();
    }
    _showEmojiPicker = false;
    _supportTyping = true;
    _supportMessages.add(_SupportChatMessage(sender: 'Client', text: message));
    _supportChatOverlayEntry?.markNeedsBuild();
    _scrollSupportToLatest();

    if (ApiConstants.useMockApi) {
      _supportTyping = false;
      _supportMessages.add(
        const _SupportChatMessage(
          sender: 'Support',
          text:
              'Command Center is running in local mode. Backend execution is disabled right now.',
        ),
      );
      await _runSupportLocalFallback(message, inputType: inputType);
      _supportChatOverlayEntry?.markNeedsBuild();
      _scrollSupportToLatest();
      return;
    }

    try {
      if (_supportPendingBackendCommandId != null) {
        final normalized = message.toLowerCase();
        if (_isSupportConfirmReply(normalized)) {
          final response = await _supportCommandApiService.confirmCommand(
            commandId: _supportPendingBackendCommandId!,
            sessionId: _supportChatSessionId,
            action: 'confirm',
          );
          _supportPendingBackendCommandId = null;
          _supportTyping = false;
          _appendSupportBackendReply(response);
          return;
        }

        if (_isSupportCancelReply(normalized)) {
          final response = await _supportCommandApiService.cancelCommand(
            commandId: _supportPendingBackendCommandId!,
            sessionId: _supportChatSessionId,
          );
          _supportPendingBackendCommandId = null;
          _supportTyping = false;
          _appendSupportBackendReply(response);
          return;
        }

        _supportTyping = false;
        _supportMessages.add(
          const _SupportChatMessage(
            sender: 'Support',
            text:
                'A command is awaiting confirmation. Reply with Confirm or Cancel.',
          ),
        );
        _supportChatOverlayEntry?.markNeedsBuild();
        _scrollSupportToLatest();
        return;
      }

      final response = await _supportCommandApiService.sendCommand(
        CommandApiRequest(
          inputType: inputType,
          transcript: message,
          sessionId: _supportChatSessionId,
          idempotencyKey: CommandApiService.generateIdempotencyKey(),
          context: const CommandContextPayload(
            screen: 'dashboard_support_chat',
            module: 'command_center',
          ),
        ),
      );

      _supportTyping = false;
      _appendSupportBackendReply(response);
    } catch (error) {
      _supportTyping = false;
      _supportMessages.add(
        _SupportChatMessage(
          sender: 'Support',
          text: 'Backend unavailable: $error',
        ),
      );
      _supportMessages.add(
        const _SupportChatMessage(
          sender: 'Support',
          text:
              'I can still help in local mode. Try typing a clear command, use voice, or upload a document to continue.',
        ),
      );
      _supportChatOverlayEntry?.markNeedsBuild();
      _scrollSupportToLatest();
    }
  }

  bool _isSupportConfirmReply(String text) {
    final normalized = text.trim();
    return normalized == 'confirm' ||
        normalized == 'yes' ||
        normalized == 'ok' ||
        normalized == 'post karo';
  }

  bool _isSupportCancelReply(String text) {
    final normalized = text.trim();
    return normalized == 'cancel' || normalized == 'no';
  }

  void _appendSupportBackendReply(CommandApiResponse response) {
    _supportPendingBackendCommandId = response.requiresConfirmation
        ? response.commandId
        : null;

    final lines = <String>[
      response.message,
      'Status: ${response.status.name.toUpperCase()}',
      if (response.commandId.isNotEmpty) 'Command ID: ${response.commandId}',
      if (response.requiresConfirmation)
        'Reply with Confirm or Cancel to continue.',
    ];

    _supportMessages.add(
      _SupportChatMessage(sender: 'Support', text: lines.join('\n')),
    );

    _supportChatOverlayEntry?.markNeedsBuild();
    _scrollSupportToLatest();
  }

  String _nextSupportVoiceSessionId() {
    _supportVoiceSessionCounter += 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'voice-$now-$_supportVoiceSessionCounter';
  }

  void _logSupportVoice(
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    final detailText = details.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint(
      '[VOICE] $event session=$_supportVoiceSessionId ${detailText.trim()}',
    );
  }

  void _setSupportVoiceError(String errorCode, String errorMessage) {
    _supportVoiceLastError = errorCode.isEmpty
        ? errorMessage
        : '$errorCode: $errorMessage';
  }

  void _clearSupportVoiceError() {
    _supportVoiceLastError = 'none';
  }

  void _resetSupportVoiceState() {
    _supportListening = false;
    _supportTranscribing = false;
    _supportVoiceSessionId = 'none';
    _supportVoiceSessionFinalized = false;
    _supportVoiceAutoFinalizeQueued = false;
    _supportVoiceStatus = 'IDLE';
    _supportVoicePermission = 'NOT REQUESTED';
    _supportVoiceSpeechApi = 'NOT CHECKED';
    _supportVoiceMic = 'NOT CHECKED';
    _supportVoiceAudio = 'IDLE';
    _supportVoiceTranscript = '';
    _clearSupportVoiceError();
    _supportVoiceReady = false;
    _supportVoiceInitFailed = false;
  }

  String _supportPermissionLabel(String status) {
    switch (status.toLowerCase()) {
      case 'granted':
        return 'GRANTED';
      case 'denied':
      case 'permanentlydenied':
      case 'restricted':
        return 'DENIED';
      case 'not_requested':
        return 'NOT REQUESTED';
      case 'prompt':
      case 'unknown':
      default:
        return 'PROMPT/UNKNOWN';
    }
  }

  String _supportVoiceMessageForError(String errorCode) {
    switch (errorCode) {
      case SpeechProvider.errorDeviceNotFound:
        return 'No microphone was found on this device. Connect or enable a microphone and try again.';
      case SpeechProvider.errorPermissionDenied:
        return 'Microphone permission is blocked. Please allow microphone access to use voice commands.';
      case SpeechProvider.errorSpeechApiUnavailable:
        return 'Speech API is unavailable in this browser. Please use typing for now.';
      case SpeechProvider.errorDeviceBusy:
        return 'The microphone is busy in another app or tab. Close the other app and try again.';
      default:
        return 'Voice input is unavailable right now. Please try again.';
    }
  }

  void _appendSupportMessageIfNotDuplicate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_supportMessages.isNotEmpty) {
      final last = _supportMessages.last;
      if (last.sender == 'Support' && last.text.trim() == trimmed) {
        return;
      }
    }
    _supportMessages.add(_SupportChatMessage(sender: 'Support', text: trimmed));
  }

  Future<void> _finalizeSupportVoiceSession({
    required String sessionId,
    required String finalStatus,
    String? userMessage,
  }) async {
    if (_supportVoiceSessionId != sessionId || _supportVoiceSessionFinalized) {
      _logSupportVoice(
        'VOICE_FINALIZE_IGNORED',
        details: <String, Object?>{
          'sessionId': sessionId,
          'activeSessionId': _supportVoiceSessionId,
          'alreadyFinalized': _supportVoiceSessionFinalized,
        },
      );
      return;
    }

    _supportVoiceSessionFinalized = true;
    _supportVoiceAutoFinalizeQueued = false;
    _supportListening = false;
    _supportTranscribing = false;
    _supportVoiceStatus = finalStatus;
    _logSupportVoice(
      'VOICE_SESSION_ENDED',
      details: <String, Object?>{'status': finalStatus},
    );

    if (userMessage != null && userMessage.trim().isNotEmpty) {
      _appendSupportMessageIfNotDuplicate(userMessage);
      _scrollSupportToLatest();
    }

    if (mounted) {
      setState(() {});
    }
    _supportChatOverlayEntry?.markNeedsBuild();
  }

  Future<void> _onSupportMicrophonePressed() async {
    if (_supportTyping || _supportTranscribing) return;

    _logSupportVoice('click');

    if (_supportListening || _supportSpeechService.isListening) {
      await _stopAndSendSupportVoice();
      return;
    }

    if (_supportVoiceInitInProgress) {
      _appendSupportMessageIfNotDuplicate('Voice input is still initializing.');
      _supportChatOverlayEntry?.markNeedsBuild();
      _scrollSupportToLatest();
      return;
    }

    final sessionId = _nextSupportVoiceSessionId();
    _supportVoiceSessionId = sessionId;
    _supportVoiceSessionFinalized = false;
    _supportVoiceAutoFinalizeQueued = false;
    _supportVoiceTranscript = '';
    _supportVoiceMic = 'NOT CHECKED';
    _supportVoicePermission = 'NOT REQUESTED';
    _supportVoiceAudio = 'IDLE';
    _supportVoiceStatus = 'INITIALIZING';
    _supportVoiceProvider = 'SpeechToTextProvider';
    _clearSupportVoiceError();

    _logSupportVoice('VOICE_SESSION_STARTED');

    if (!_supportVoiceReady) {
      final initialized = await _initializeSupportVoiceProvider(force: true);
      if (!initialized) {
        _supportVoiceStatus = 'ERROR';
        await _finalizeSupportVoiceSession(
          sessionId: sessionId,
          finalStatus: 'ERROR',
          userMessage: _supportVoiceMessageForError(
            _supportSpeechService.getLastErrorCode().isEmpty
                ? SpeechProvider.errorNotSupported
                : _supportSpeechService.getLastErrorCode(),
          ),
        );
        return;
      }
    }
    _logSupportVoice('permission check');

    if (!kIsWeb) {
      final permissionDecision = await _supportMicrophonePermissionService
          .ensureMicrophoneReadyWithDecision();

      _supportVoicePermission = permissionDecision.status.name.toUpperCase();

      if (permissionDecision.status != MicrophonePermissionStatus.granted) {
        _setSupportVoiceError(
          SpeechProvider.errorPermissionDenied,
          'Microphone permission is not granted.',
        );
        _logSupportVoice(
          'VOICE_SESSION_ERROR',
          details: <String, Object?>{'error': _supportVoiceLastError},
        );
        await _finalizeSupportVoiceSession(
          sessionId: sessionId,
          finalStatus: 'ERROR',
          userMessage: _supportVoiceMessageForError(
            SpeechProvider.errorPermissionDenied,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _supportTranscribing = false;
      _supportVoiceStatus = 'INITIALIZING';
      _supportVoiceAudio = 'IDLE';
    });
    _supportChatOverlayEntry?.markNeedsBuild();

    _logSupportVoice('recognition created');

    void handleDebugEvent(SpeechDebugEvent event) {
      if (_supportVoiceSessionId != sessionId ||
          _supportVoiceSessionFinalized) {
        _logSupportVoice(
          'VOICE_CALLBACK_IGNORED',
          details: <String, Object?>{'event': event.code},
        );
        return;
      }

      _logSupportVoice(event.code, details: event.data);
      if (event.code == 'onaudiostart') {
        _supportVoiceAudio = 'RECEIVING';
      }
      if (event.code == 'onresult') {
        _supportVoiceStatus = 'PROCESSING';
        final transcript = event.data['transcript'];
        if (transcript is String) {
          _supportVoiceTranscript = transcript;
        }
      }
      if (event.code == 'onstatus') {
        final status = (event.data['status'] ?? '').toString();
        if (status == 'listening') {
          _supportVoiceStatus = 'LISTENING';
        }
        if (status == 'done' || status == 'notListening') {
          _queueSupportVoiceAutoComplete(sessionId);
        }
      }
      if (event.code == 'onspeechend') {
        _queueSupportVoiceAutoComplete(sessionId);
      }
      if (event.code == 'onerror') {
        final error = event.data['error'];
        _setSupportVoiceError(
          SpeechProvider.errorUnknown,
          error is String ? error : 'Unknown recognition error',
        );
      }
      if (mounted) {
        setState(() {});
      }
      _supportChatOverlayEntry?.markNeedsBuild();
    }

    final started = await _supportSpeechService.startListening(
      localeId: 'en-IN',
      sessionId: sessionId,
      onDebugEvent: handleDebugEvent,
    );

    if (!started) {
      final providerErrorCode = _supportSpeechService.getLastErrorCode();
      final providerErrorMessage = _supportSpeechService.getLastErrorMessage();
      _supportVoiceSpeechApi = _supportSpeechService.isSpeechApiAvailable
          ? 'AVAILABLE'
          : 'UNAVAILABLE';
      _supportVoicePermission = _supportPermissionLabel(
        _supportSpeechService.permissionStatus,
      );
      _supportVoiceMic = _supportSpeechService.isMicrophoneAvailable
          ? 'AVAILABLE'
          : 'NOT AVAILABLE';

      _setSupportVoiceError(providerErrorCode, providerErrorMessage);
      _logSupportVoice(
        'VOICE_SESSION_ERROR',
        details: <String, Object?>{
          'errorCode': providerErrorCode,
          'errorMessage': providerErrorMessage,
        },
      );

      if (!mounted) return;
      setState(() {
        _supportListening = false;
        _supportTranscribing = false;
        _supportVoiceStatus = 'ERROR';
      });
      await _finalizeSupportVoiceSession(
        sessionId: sessionId,
        finalStatus: 'ERROR',
        userMessage: _supportVoiceMessageForError(providerErrorCode),
      );
      if (providerErrorCode == SpeechProvider.errorSpeechApiUnavailable) {
        _supportVoiceReady = false;
        _supportVoiceInitFailed = true;
      }
      _supportChatOverlayEntry?.markNeedsBuild();
      return;
    }

    _supportVoiceSpeechApi = _supportSpeechService.isSpeechApiAvailable
        ? 'AVAILABLE'
        : 'UNAVAILABLE';
    _supportVoicePermission = _supportPermissionLabel(
      _supportSpeechService.permissionStatus,
    );
    _supportVoiceMic = _supportSpeechService.isMicrophoneAvailable
        ? 'AVAILABLE'
        : 'NOT AVAILABLE';

    if (mounted) {
      setState(() {
        _supportListening = true;
        _supportVoiceStatus = 'LISTENING';
        _supportVoiceAudio = 'READY';
      });
    }

    _logSupportVoice('microphone ready');
    _logSupportVoice('recognition.start()');
    if (mounted) {
      setState(() {});
    }
    _supportChatOverlayEntry?.markNeedsBuild();
  }

  Future<void> _stopAndSendSupportVoice() async {
    final sessionId = _supportVoiceSessionId;
    if (sessionId == 'none') return;

    if (_supportVoiceSessionFinalized) {
      _logSupportVoice(
        'VOICE_STOP_IGNORED',
        details: <String, Object?>{'reason': 'session already finalized'},
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _supportListening = false;
      _supportTranscribing = true;
      _supportVoiceStatus = 'PROCESSING';
    });
    _supportChatOverlayEntry?.markNeedsBuild();

    final transcript = await _supportSpeechService
        .stopListeningAndAwaitTranscript(timeout: const Duration(seconds: 5));
    _supportVoiceTranscript = transcript.trim();

    if (!mounted) return;
    setState(() {
      _supportTranscribing = false;
    });

    if (_supportVoiceSessionFinalized || _supportVoiceSessionId != sessionId) {
      _logSupportVoice(
        'VOICE_RESULT_IGNORED',
        details: <String, Object?>{'reason': 'session mismatch/finalized'},
      );
      return;
    }

    _logSupportVoice(
      'VOICE_RESULT_RECEIVED',
      details: <String, Object?>{
        'transcriptLength': transcript.trim().length,
        'transcript': transcript.trim(),
        'confidence': _supportSpeechService.getConfidence(),
        'language': _supportSpeechService.getDetectedLanguage(),
      },
    );

    if (transcript.trim().isEmpty) {
      if (_supportVoiceLastError.trim().isNotEmpty) {
        await _finalizeSupportVoiceSession(
          sessionId: sessionId,
          finalStatus: 'ERROR',
        );
        return;
      }
      _setSupportVoiceError(
        SpeechProvider.errorNoSpeech,
        'Recognition ended without transcript.',
      );
      await _finalizeSupportVoiceSession(
        sessionId: sessionId,
        finalStatus: 'ERROR',
        userMessage: 'No speech detected. Please try speaking again.',
      );
      return;
    }

    _supportInputCtrl.text = transcript.trim();
    _supportChatOverlayEntry?.markNeedsBuild();
    await _finalizeSupportVoiceSession(
      sessionId: sessionId,
      finalStatus: 'SUCCESS',
    );
  }

  IconData get _supportMicIcon {
    if (_supportListening) return Icons.hearing_outlined;
    if (_supportTranscribing) return Icons.hourglass_top_outlined;
    return Icons.mic_none_outlined;
  }

  Color _supportMicColor(BuildContext context) {
    if (_supportListening) return Colors.red;
    if (_supportTranscribing) return Colors.orange.shade700;
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildSupportVoiceDiagnostics() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE4F2)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 11, color: Color(0xFF223049)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'VOICE DIAGNOSTICS (DEV)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Voice Status: $_supportVoiceStatus'),
            Text('Microphone: $_supportVoiceMic'),
            Text('Permission: $_supportVoicePermission'),
            Text('Speech API: $_supportVoiceSpeechApi'),
            Text('Audio: $_supportVoiceAudio'),
            Text('Session: $_supportVoiceSessionId'),
            Text('Provider: $_supportVoiceProvider'),
            Text('Init Failed: ${_supportVoiceInitFailed ? 'YES' : 'NO'}'),
            Text('Transcript: $_supportVoiceTranscript'),
            Text('Last Error: $_supportVoiceLastError'),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSupportAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;

    final selectedPath = picked.path;
    final selectedBytes = picked.bytes;
    final fileName = picked.name.trim().isEmpty ? 'file' : picked.name.trim();
    final lower = fileName.toLowerCase();
    final kind = lower.endsWith('.pdf') ? 'PDF' : 'Image';

    _supportMessages.add(
      _SupportChatMessage(
        sender: 'Client',
        text: 'Attached $kind file',
        attachmentName: fileName,
        attachmentKind: kind,
      ),
    );
    _supportTyping = false;
    _supportMessages.add(
      const _SupportChatMessage(
        sender: 'Support',
        text: 'Received. Opening related entry screen for auto-detection...',
      ),
    );
    _supportChatOverlayEntry?.markNeedsBuild();
    _scrollSupportToLatest();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientUploadsScreen(
          autoRouteAfterDetect: true,
          autoRouteSource: 'support-chat',
          initialFilePath: isUsableLocalFilePath(selectedPath)
              ? selectedPath
              : null,
          initialFileBytes: selectedBytes,
          initialFileName: fileName,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Typing',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              SizedBox(width: 3),
              Text(
                '...',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _scrollSupportToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_supportScrollCtrl.hasClients) return;
      _supportScrollCtrl.animateTo(
        _supportScrollCtrl.position.maxScrollExtent + 64,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _bankingSubItem(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 18, color: Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
      ),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  Widget _reportsFolderItem(
    BuildContext context,
    RoleController role, {
    bool caAuditorMode = false,
    bool? includeQuickProvisional,
  }) {
    final userRole = context.read<AuthController>().currentUser?.role;
    final showQuickProvisional =
        includeQuickProvisional ??
        (userRole != null && _isCaAuditorRole(userRole));
    void openReportsWorkspace() {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClientReportsScreen()),
      );
    }

    return ExpansionTile(
      leading: Icon(Icons.bar_chart, color: Colors.grey.shade700, size: 22),
      title: Text(
        'Reports',
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 4),
      children: [
        if (caAuditorMode)
          _reportSubItem(
            context,
            Icons.preview_outlined,
            'Reports Workspace (Preview/Filter/Download)',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientReportsScreen()),
              );
            },
          ),
        if (showQuickProvisional)
          _reportSubItem(
            context,
            Icons.flash_on_outlined,
            'Quick Provisional Report',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QuickProvisionalReportScreen(),
                ),
              );
            },
          ),
        if (caAuditorMode) const SizedBox.shrink(),
        if (!caAuditorMode && role.canReport(ReportPermission.allReports))
          _reportSubItem(
            context,
            Icons.grid_view_outlined,
            'All Reports',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.salesReport))
          _reportSubItem(
            context,
            Icons.show_chart_outlined,
            'Sales Report',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.purchaseReport))
          _reportSubItem(
            context,
            Icons.shopping_cart_outlined,
            'Purchase Report',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.gstReport))
          _reportSubItem(
            context,
            Icons.receipt_long_outlined,
            'GST Report',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode &&
            role.canReport(ReportPermission.outstandingReport))
          _reportSubItem(
            context,
            Icons.pending_actions_outlined,
            'Outstanding Report',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.profitAndLoss))
          _reportSubItem(
            context,
            Icons.trending_up_outlined,
            'Profit & Loss',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.balanceSheet))
          _reportSubItem(
            context,
            Icons.balance_outlined,
            'Balance Sheet',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.trialBalance))
          _reportSubItem(
            context,
            Icons.fact_check_outlined,
            'Trial Balance',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.cashBook))
          _reportSubItem(
            context,
            Icons.payments_outlined,
            'Cash Book',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.bankBook))
          _reportSubItem(
            context,
            Icons.account_balance_outlined,
            'Bank Book',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.customerLedger))
          _reportSubItem(
            context,
            Icons.people_outline,
            'Customer Ledger',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.vendorLedger))
          _reportSubItem(
            context,
            Icons.storefront_outlined,
            'Vendor Ledger',
            onTap: openReportsWorkspace,
          ),
        if (!caAuditorMode && role.canReport(ReportPermission.generalLedger))
          _reportSubItem(
            context,
            Icons.book_outlined,
            'General Ledger',
            onTap: openReportsWorkspace,
          ),
      ],
    );
  }

  Widget _reportSubItem(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 18, color: Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
      ),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  ListTile _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    bool selected,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected
            ? const Color(0xFF1565C0)
            : (color ?? Colors.grey.shade700),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: selected
              ? const Color(0xFF1565C0)
              : (color ?? Colors.grey.shade800),
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFFE8EAF6),
      onTap: onTap,
      dense: true,
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _SupportChatMessage {
  final String sender;
  final String text;
  final String? attachmentName;
  final String? attachmentKind;

  const _SupportChatMessage({
    required this.sender,
    required this.text,
    this.attachmentName,
    this.attachmentKind,
  });
}

// --------------- Role Permission Summary Card ---------------

class _RolePermissionCard extends StatelessWidget {
  final RoleController roleCtrl;

  const _RolePermissionCard({required this.roleCtrl});

  @override
  Widget build(BuildContext context) {
    final modules = roleCtrl.accessibleModules;
    if (modules.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: Color(0xFF1565C0),
              ),
              const SizedBox(width: 6),
              const Text(
                'Your Access Modules',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: modules
                .map(
                  (m) => Chip(
                    label: Text(
                      m.displayName,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: const Color(0xFFE8EAF6),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
          if (roleCtrl.canAccess(AppModule.banking)) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  size: 16,
                  color: Color(0xFF1565C0),
                ),
                SizedBox(width: 6),
                Text(
                  'Banking Permissions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: BankingPermission.values
                  .map(
                    (permission) => Chip(
                      label: Text(
                        permission.displayName,
                        style: const TextStyle(fontSize: 11),
                      ),
                      avatar: Icon(
                        roleCtrl.canBank(permission)
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                        size: 16,
                        color: roleCtrl.canBank(permission)
                            ? Colors.green.shade700
                            : Colors.red.shade400,
                      ),
                      backgroundColor: roleCtrl.canBank(permission)
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
