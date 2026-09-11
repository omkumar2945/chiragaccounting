import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/accountant/presentation/pages/ocr_module_screen.dart';
import 'package:chirag_accounting/features/admin/presentation/pages/tally_sync_management_screen.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workbench_screen.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/ca_workspace/presentation/pages/ca_team_workspace_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/compat/screens/client_reports_screen_compat.dart';
import 'package:chirag_accounting/features/customers/presentation/pages/customers_screen.dart';
import 'package:chirag_accounting/features/gst_workbench/presentation/pages/accountant_gst_workbench_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/my_work_queue_screen.dart';
import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';
import 'package:chirag_accounting/features/reports/presentation/pages/quick_provisional_report_screen.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_dashboard_screen.dart';
import 'package:chirag_accounting/shared/widgets/profile/profile_avatar_menu.dart';
import 'package:chirag_accounting/shared/widgets/session_logout_button.dart';

class CaCommandCenterView extends StatefulWidget {
  const CaCommandCenterView({super.key});

  @override
  State<CaCommandCenterView> createState() => _CaCommandCenterViewState();
}

class _CaCommandCenterViewState extends State<CaCommandCenterView> {
  static const _navy = Color(0xFF10233F);
  static const _blue = Color(0xFF1D5FD1);
  static const _indigo = Color(0xFF3E4FB2);
  static const _green = Color(0xFF17874B);
  static const _amber = Color(0xFFC27A0A);
  static const _red = Color(0xFFC93C37);
  static const _canvas = Color(0xFFF3F6FA);
  static const _border = Color(0xFFDDE4EE);
  static const _muted = Color(0xFF667085);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  bool _sidebarCollapsed = false;
  _CaPane _pane = _CaPane.dashboard;
  late String _financialYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = now.month >= 4 ? now.year : now.year - 1;
    _financialYear = '$start-${(start + 1).toString().substring(2)}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1050;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _canvas,
      drawer: desktop ? null : Drawer(child: _sidebar()),
      appBar: _header(desktop),
      body: Row(
        children: [
          if (desktop)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _sidebarCollapsed ? 76 : 252,
              child: _sidebar(compact: _sidebarCollapsed),
            ),
          Expanded(child: _workspace()),
        ],
      ),
    );
  }

  PreferredSizeWidget _header(bool desktop) {
    final user = context.watch<AuthController>().currentUser;
    return AppBar(
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: _navy,
      leading: desktop
          ? null
          : IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
      titleSpacing: desktop ? 22 : 0,
      title: Row(
        children: [
          Expanded(
            flex: desktop ? 0 : 1,
            child: Text(
              _pane.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (desktop) ...[
            const SizedBox(width: 24),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search clients, documents, vouchers, tasks',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: _canvas,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _open(_CaPane.communication),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (desktop)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 145),
            child: Center(
              child: Text(
                user?.name ?? 'CA Profile',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        const ProfileAvatarMenu(showDashboardOption: false),
        const SessionLogoutButton(),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _sidebar({bool compact = false}) {
    final role = context.watch<AuthController>().currentUser?.role;
    final visible = _menu
        .where(
          (item) =>
              role != null && PermissionMatrix.canAccess(role, item.module),
        )
        .toList(growable: false);
    return ColoredBox(
      color: _navy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 18,
                18,
                compact ? 12 : 18,
                16,
              ),
              child: Row(
                children: [
                  const _BrandMark(),
                  if (!compact) ...[
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chirag Accounting',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'CA / Practice Workspace',
                            style: TextStyle(
                              color: Color(0xFF9EB2CF),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF28405F)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: visible.length,
                itemBuilder: (_, index) {
                  final item = visible[index];
                  final showGroup =
                      index == 0 || visible[index - 1].group != item.group;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showGroup && !compact)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 13, 18, 5),
                          child: Text(
                            item.group.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF7890AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 1,
                        ),
                        child: Material(
                          color: item.pane == _pane
                              ? const Color(0xFF1E4D86)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          child: compact
                              ? Tooltip(
                                  message: item.label,
                                  child: InkWell(
                                    key: ValueKey('ca-nav-${item.pane.name}'),
                                    borderRadius: BorderRadius.circular(7),
                                    onTap: () => _open(item.pane),
                                    child: SizedBox(
                                      height: 48,
                                      width: double.infinity,
                                      child: Icon(
                                        item.icon,
                                        size: 19,
                                        color: item.pane == _pane
                                            ? Colors.white
                                            : const Color(0xFFB8C7DB),
                                      ),
                                    ),
                                  ),
                                )
                              : ListTile(
                                  key: ValueKey('ca-nav-${item.pane.name}'),
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  leading: Icon(
                                    item.icon,
                                    size: 19,
                                    color: item.pane == _pane
                                        ? Colors.white
                                        : const Color(0xFFB8C7DB),
                                  ),
                                  title: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: item.pane == _pane
                                          ? Colors.white
                                          : const Color(0xFFD7E0EC),
                                      fontSize: 13,
                                      fontWeight: item.pane == _pane
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  onTap: () => _open(item.pane),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 1050)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Material(
                  color: const Color(0xFF193554),
                  borderRadius: BorderRadius.circular(7),
                  child: compact
                      ? Tooltip(
                          message: 'Expand menu',
                          child: InkWell(
                            key: const ValueKey('ca-sidebar-collapse'),
                            onTap: () =>
                                setState(() => _sidebarCollapsed = false),
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
                          key: const ValueKey('ca-sidebar-collapse'),
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
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => setState(() => _sidebarCollapsed = true),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(_CaPane next) {
    setState(() => _pane = next);
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Widget _workspace() => switch (_pane) {
    _CaPane.dashboard => _dashboard(),
    _CaPane.clients => const CustomersScreen(),
    _CaPane.team || _CaPane.allocation => const CaTeamWorkspaceScreen(),
    _CaPane.queue || _CaPane.approvals => const MyWorkQueueScreen(),
    _CaPane.ocr => const OcrModuleScreen(),
    _CaPane.workbench => const AiWorkbenchScreen(),
    _CaPane.vouchers => const VoucherEntryDashboardScreen(),
    _CaPane.tally => const TallySyncManagementScreen(),
    _CaPane.gst => const AccountantGstWorkbenchScreen(),
    _CaPane.reports ||
    _CaPane.performance ||
    _CaPane.targets => const ClientReportsScreen(),
    _CaPane.provisional => const QuickProvisionalReportScreen(),
    _CaPane.projects => _projectsWorkspace(),
    _CaPane.communication => _communication(),
    _CaPane.settings => const ClientSettingsScreen(),
  };

  Widget _projectsWorkspace() => const Center(
    child: _Empty(
      icon: Icons.folder_copy_outlined,
      text: 'No project data available.',
    ),
  );

  Widget _dashboard() {
    final service = context.watch<OperationsCenterService>();
    final snapshot = service.snapshot;
    final user = context.watch<AuthController>().currentUser;
    final name = user?.name.trim().split(' ').first ?? 'CA';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    return RefreshIndicator(
      onRefresh: service.refreshNow,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final wide = constraints.maxWidth >= 900;
          return ListView(
            padding: EdgeInsets.all(wide ? 24 : 14),
            children: [
              _welcome(greeting, name, snapshot),
              const SizedBox(height: 18),
              _kpis(snapshot.metrics, constraints.maxWidth),
              const SizedBox(height: 16),
              _responsivePair(
                wide,
                _performance(snapshot.metrics),
                _priorities(snapshot.metrics),
              ),
              const SizedBox(height: 16),
              _pipeline(snapshot.metrics, constraints.maxWidth),
              const SizedBox(height: 16),
              _responsivePair(
                wide,
                _portfolio(service),
                _approval(snapshot.metrics),
                leftFlex: 3,
                rightFlex: 2,
              ),
              const SizedBox(height: 16),
              _quickActions(),
              const SizedBox(height: 16),
              _responsiveTriple(
                wide,
                _ocrStatus(snapshot.metrics),
                _gstStatus(snapshot.metrics),
                _emptySection(
                  'Team Performance',
                  'No team performance data available',
                  Icons.insights_outlined,
                  _CaPane.team,
                ),
              ),
              const SizedBox(height: 16),
              _responsivePair(
                wide,
                _activity(snapshot.timeline),
                _sideSummaries(),
                leftFlex: 3,
                rightFlex: 2,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _welcome(String greeting, String name, OperationsSnapshot snapshot) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, $name!',
              style: const TextStyle(
                color: _navy,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Here's your practice overview and today's priorities.",
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _financialYear,
                  items: _years
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text('FY $year'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _financialYear = value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Data status: ${snapshot.streamState}',
              child: const Icon(Icons.sync_rounded, color: _green),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpis(Map<String, num> data, double width) {
    final items = <_Metric>[
      _Metric(
        'Total Clients',
        _value(data, 'Clients'),
        Icons.apartment_rounded,
        _blue,
      ),
      _Metric(
        'Active Clients',
        _value(data, 'Active Clients'),
        Icons.verified_user_outlined,
        _green,
      ),
      _Metric(
        'Pending Work',
        _value(data, "Today's Tasks"),
        Icons.pending_actions_outlined,
        _indigo,
      ),
      _Metric(
        'Pending Approvals',
        _value(data, 'Pending Approvals'),
        Icons.fact_check_outlined,
        _amber,
      ),
      _Metric(
        'Overdue',
        _value(data, 'Overdue'),
        Icons.error_outline_rounded,
        _red,
      ),
      _Metric(
        'Accountant Workload',
        _value(data, 'Waiting Accountant'),
        Icons.groups_2_outlined,
        const Color(0xFF087E8B),
      ),
    ];
    final columns = width >= 1200
        ? 6
        : width >= 650
        ? 3
        : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 132,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: _decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(item.icon, color: item.color, size: 19),
              ),
              const Spacer(),
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                item.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _performance(Map<String, num> data) {
    final rows = <_Metric>[
      _Metric(
        'Completed',
        '${_num(data, 'Completed Today Queue')}',
        Icons.circle,
        _green,
      ),
      _Metric('Pending', '${_num(data, "Today's Tasks")}', Icons.circle, _blue),
      _Metric(
        'Waiting for Client',
        '${_num(data, 'Waiting Client')}',
        Icons.circle,
        _amber,
      ),
      _Metric(
        'Waiting for Accountant',
        '${_num(data, 'Waiting Accountant')}',
        Icons.circle,
        _indigo,
      ),
      _Metric(
        'Waiting for Approval',
        '${_num(data, 'Waiting Approval')}',
        Icons.circle,
        const Color(0xFF087E8B),
      ),
      _Metric('Overdue', '${_num(data, 'Overdue')}', Icons.circle, _red),
    ];
    final total = rows.fold<int>(0, (sum, item) => sum + int.parse(item.value));
    final done = _num(data, 'Completed Today Queue');
    return _section(
      'Practice Performance',
      'Live client-work distribution',
      Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 82,
                  child: CircularProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    strokeWidth: 9,
                    backgroundColor: const Color(0xFFE8EDF4),
                    color: _blue,
                  ),
                ),
                Text(
                  '${total == 0 ? 0 : (done / total * 100).round()}%',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: row.color, size: 8),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              row.label,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            row.value,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorities(Map<String, num> data) {
    final rows = <(_CaPane, String, int, Color)>[
      (_CaPane.queue, 'Overdue work', _num(data, 'Overdue'), _red),
      (
        _CaPane.approvals,
        'Approval pending',
        _num(data, 'Pending Approvals'),
        _amber,
      ),
      (
        _CaPane.queue,
        'Client documents pending',
        _num(data, 'Waiting Client'),
        _blue,
      ),
      (_CaPane.gst, 'GST returns due', _num(data, 'GST Returns Due'), _indigo),
    ].where((row) => row.$3 > 0).toList(growable: false);
    return _section(
      "Today's Priorities",
      'Highest-impact pending work',
      rows.isEmpty
          ? const _Empty(
              icon: Icons.task_alt_rounded,
              text: 'No priority work right now',
            )
          : Column(
              children: rows
                  .map(
                    (row) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 7,
                        height: 34,
                        decoration: BoxDecoration(
                          color: row.$4,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      title: Text(
                        row.$2,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${row.$3} items require attention',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                      trailing: IconButton(
                        tooltip: 'Open',
                        onPressed: () => _open(row.$1),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _pipeline(Map<String, num> data, double width) {
    final stages = <(_CaPane, String, String, IconData)>[
      (
        _CaPane.workbench,
        'Documents',
        _value(data, 'Pending Uploads'),
        Icons.description_outlined,
      ),
      (
        _CaPane.ocr,
        'OCR',
        _value(data, 'OCR Queue'),
        Icons.document_scanner_outlined,
      ),
      (
        _CaPane.vouchers,
        'Entry',
        _value(data, 'Pending Verification'),
        Icons.edit_note_outlined,
      ),
      (
        _CaPane.vouchers,
        'Check',
        _value(data, 'Waiting CA'),
        Icons.fact_check_outlined,
      ),
      (
        _CaPane.approvals,
        'Approval',
        _value(data, 'Pending Approvals'),
        Icons.approval_outlined,
      ),
      (
        _CaPane.tally,
        'Tally Sync',
        _value(data, 'Waiting Auditor'),
        Icons.sync_alt_rounded,
      ),
      (
        _CaPane.queue,
        'Completed',
        _value(data, 'Completed Today Queue'),
        Icons.task_alt_rounded,
      ),
    ];
    return _section(
      'Workflow Pipeline',
      'Documents to completed books',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stages
            .map(
              (stage) => SizedBox(
                width: width >= 900 ? 116 : 101,
                child: InkWell(
                  onTap: () => _open(stage.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _canvas,
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(stage.$4, color: _blue, size: 20),
                        const SizedBox(height: 6),
                        Text(
                          stage.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          stage.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _portfolio(OperationsCenterService service) {
    final names = service.knownClientNames.take(5).toList(growable: false);
    return _section(
      'My Client Portfolio',
      'Recent practice activity by client',
      names.isEmpty
          ? const _Empty(
              icon: Icons.apartment_outlined,
              text: 'No client activity yet',
            )
          : Column(
              children: names
                  .map((name) {
                    final events = service.timelineForClient(name);
                    final attention = events.any(
                      (event) =>
                          event.severity == OperationSeverity.warning ||
                          event.severity == OperationSeverity.critical,
                    );
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _blue.withValues(alpha: 0.1),
                        foregroundColor: _blue,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        events.isEmpty ? 'No activity yet' : events.first.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                      trailing: _badge(
                        attention ? 'Attention' : 'Healthy',
                        attention ? _amber : _green,
                      ),
                      onTap: () => _open(_CaPane.clients),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }

  Widget _approval(Map<String, num> data) => _section(
    'Approval Center',
    'Review and decision queue',
    Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _smallMetric(
                'Pending',
                _value(data, 'Pending Approvals'),
                _amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _smallMetric(
                'Approved Today',
                _value(data, 'Completed Today'),
                _green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _smallMetric(
                'Correction',
                _value(data, 'Waiting CA'),
                _red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _smallMetric(
                'Escalated',
                _value(data, 'Escalated'),
                _indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _open(_CaPane.approvals),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Open Approval Queue'),
            style: FilledButton.styleFrom(backgroundColor: _blue),
          ),
        ),
      ],
    ),
  );

  Widget _quickActions() {
    final role = context.watch<AuthController>().currentUser?.role;
    final actions = _menu.where(
      (item) =>
          <_CaPane>{
            _CaPane.clients,
            _CaPane.allocation,
            _CaPane.workbench,
            _CaPane.ocr,
            _CaPane.vouchers,
            _CaPane.approvals,
            _CaPane.gst,
            _CaPane.reports,
          }.contains(item.pane) &&
          role != null &&
          PermissionMatrix.canAccess(role, item.module),
    );
    return _section(
      'Quick Actions',
      'Open existing practice workflows',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (item) => ActionChip(
                avatar: Icon(item.icon, color: _blue, size: 17),
                label: Text(item.label),
                onPressed: () => _open(item.pane),
                backgroundColor: Colors.white,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _ocrStatus(Map<String, num> data) =>
      _statusSection('Document & OCR Status', _CaPane.ocr, [
        ('OCR Queue', _num(data, 'OCR Queue'), _blue),
        ('Review Required', _num(data, 'Pending Verification'), _amber),
        ('Completed', _num(data, 'OCR Completed'), _green),
        ('Failed', _num(data, 'OCR Failed'), _red),
      ]);

  Widget _gstStatus(Map<String, num> data) =>
      _statusSection('GST & Compliance', _CaPane.gst, [
        ('Returns Due', _num(data, 'GST Returns Due'), _amber),
        ('Pending Filing', _num(data, 'Pending Filing'), _blue),
        ('Mismatch / Attention', _num(data, 'Gst Mismatch Flags'), _red),
        ('Completed Today', _num(data, 'Completed Today'), _green),
      ]);

  Widget _statusSection(
    String title,
    _CaPane pane,
    List<(String, int, Color)> rows,
  ) => _section(
    title,
    'Current operational status',
    Column(
      children: [
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  row.$2 == 0 ? Icons.check_circle_outline : Icons.circle,
                  color: row.$2 == 0 ? _green : row.$3,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.$1,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
                Text(
                  '${row.$2}',
                  style: TextStyle(
                    color: row.$3,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => _open(pane),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open workspace'),
        ),
      ],
    ),
  );

  Widget _activity(List<OperationTimelineEvent> events) => _section(
    'Recent Activity',
    'Latest practice events',
    events.isEmpty
        ? const _Empty(icon: Icons.history_rounded, text: 'No activity yet')
        : Column(
            children: events
                .take(6)
                .map(
                  (event) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: _severity(
                        event.severity,
                      ).withValues(alpha: 0.1),
                      foregroundColor: _severity(event.severity),
                      child: const Icon(Icons.bolt_rounded, size: 15),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${event.clientName} • ${event.source}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
  );

  Widget _sideSummaries() => Column(
    children: [
      _emptySection(
        'Practice Targets & Goals',
        'No target data available',
        Icons.track_changes_outlined,
        _CaPane.targets,
      ),
      const SizedBox(height: 14),
      _section(
        'Announcements',
        'Practice and compliance updates',
        const _Empty(
          icon: Icons.campaign_outlined,
          text: 'No announcements configured',
        ),
      ),
    ],
  );

  Widget _emptySection(
    String title,
    String text,
    IconData icon,
    _CaPane pane,
  ) => _section(
    title,
    'Uses existing configured data',
    Column(
      children: [
        _Empty(icon: icon, text: text),
        TextButton(
          onPressed: () => _open(pane),
          child: const Text('Open workspace'),
        ),
      ],
    ),
  );

  Widget _communication() {
    final data = context.watch<OperationsCenterService>().snapshot.metrics;
    return ColoredBox(
      color: _canvas,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Communication',
            style: TextStyle(
              color: _navy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Messages, queries, and practice notifications.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          _section(
            'Communication Center',
            'Current communication workload',
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 190,
                  child: _smallMetric(
                    'Unread Client Messages',
                    _value(data, 'Unread Client Messages'),
                    _blue,
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _smallMetric(
                    'Pending Queries',
                    _value(data, 'Outstanding Queries'),
                    _amber,
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _smallMetric(
                    'Important Notifications',
                    _value(data, 'Pending Approvals'),
                    _indigo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsivePair(
    bool wide,
    Widget left,
    Widget right, {
    int leftFlex = 1,
    int rightFlex = 1,
  }) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
          ],
        )
      : Column(children: [left, const SizedBox(height: 14), right]);

  Widget _responsiveTriple(
    bool wide,
    Widget first,
    Widget second,
    Widget third,
  ) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
            const SizedBox(width: 14),
            Expanded(child: third),
          ],
        )
      : Column(
          children: [
            first,
            const SizedBox(height: 14),
            second,
            const SizedBox(height: 14),
            third,
          ],
        );

  Widget _section(String title, String subtitle, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _decoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: _navy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _smallMetric(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 9),
        ),
      ],
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );

  BoxDecoration get _decoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _border),
    boxShadow: const [
      BoxShadow(color: Color(0x0A10233F), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );

  int _num(Map<String, num> data, String key) => (data[key] ?? 0).round();
  String _value(Map<String, num> data, String key) =>
      data.containsKey(key) ? '${_num(data, key)}' : 'Data unavailable';
  Color _severity(OperationSeverity severity) => switch (severity) {
    OperationSeverity.info => _blue,
    OperationSeverity.success => _green,
    OperationSeverity.warning => _amber,
    OperationSeverity.critical => _red,
  };

  List<String> get _years {
    final start = int.parse(_financialYear.substring(0, 4));
    return List.generate(3, (index) {
      final year = start - 1 + index;
      return '$year-${(year + 1).toString().substring(2)}';
    });
  }
}

enum _CaPane {
  dashboard,
  clients,
  team,
  allocation,
  queue,
  ocr,
  workbench,
  vouchers,
  approvals,
  tally,
  gst,
  reports,
  provisional,
  projects,
  performance,
  targets,
  communication,
  settings,
}

extension on _CaPane {
  String get title => switch (this) {
    _CaPane.dashboard => 'Auditor Command Center',
    _CaPane.clients => 'Clients',
    _CaPane.team => 'Accountants / Team',
    _CaPane.allocation => 'Work Allocation',
    _CaPane.queue => 'Client Work Queue',
    _CaPane.ocr => 'OCR Processing',
    _CaPane.workbench => 'Upload Workbench',
    _CaPane.vouchers => 'Voucher Entries Check',
    _CaPane.approvals => 'Approval Queue',
    _CaPane.tally => 'Tally Sync Center',
    _CaPane.gst => 'GST Work',
    _CaPane.reports => 'Reports & Analytics',
    _CaPane.provisional => 'Provisional Reports',
    _CaPane.projects => 'Projects',
    _CaPane.performance => 'Performance',
    _CaPane.targets => 'Targets & Goals',
    _CaPane.communication => 'Communication',
    _CaPane.settings => 'Settings',
  };
}

const _menu = <_MenuItem>[
  _MenuItem(
    'My Practice',
    'Dashboard',
    Icons.dashboard_outlined,
    _CaPane.dashboard,
    AppModule.dashboard,
  ),
  _MenuItem(
    'My Practice',
    'Clients',
    Icons.apartment_outlined,
    _CaPane.clients,
    AppModule.customers,
  ),
  _MenuItem(
    'My Practice',
    'Accountants / Team',
    Icons.groups_2_outlined,
    _CaPane.team,
    AppModule.users,
  ),
  _MenuItem(
    'My Practice',
    'Work Allocation',
    Icons.assignment_ind_outlined,
    _CaPane.allocation,
    AppModule.users,
  ),
  _MenuItem(
    'My Practice',
    'Client Work Queue',
    Icons.view_list_outlined,
    _CaPane.queue,
    AppModule.accounting,
  ),
  _MenuItem(
    'Reports & Analytics',
    'Reports & Analytics',
    Icons.analytics_outlined,
    _CaPane.reports,
    AppModule.reports,
  ),
  _MenuItem(
    'Reports & Analytics',
    'Provisional Reports',
    Icons.auto_graph_outlined,
    _CaPane.provisional,
    AppModule.reports,
  ),
  _MenuItem(
    'Reports & Analytics',
    'Projects',
    Icons.folder_copy_outlined,
    _CaPane.projects,
    AppModule.reports,
  ),
  _MenuItem(
    'Performance',
    'Performance',
    Icons.speed_outlined,
    _CaPane.performance,
    AppModule.reports,
  ),
  _MenuItem(
    'Performance',
    'Targets & Goals',
    Icons.track_changes_outlined,
    _CaPane.targets,
    AppModule.reports,
  ),
  _MenuItem(
    'Communication',
    'Notifications',
    Icons.notifications_none_rounded,
    _CaPane.communication,
    AppModule.chat,
  ),
  _MenuItem(
    'Support',
    'Settings',
    Icons.settings_outlined,
    _CaPane.settings,
    AppModule.settings,
  ),
];

class _MenuItem {
  const _MenuItem(this.group, this.label, this.icon, this.pane, this.module);
  final String group;
  final String label;
  final IconData icon;
  final _CaPane pane;
  final AppModule module;
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: _CaCommandCenterViewState._blue,
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Icon(
      Icons.account_balance_rounded,
      color: Colors.white,
      size: 19,
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 19),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFF98A2B3), size: 24),
        const SizedBox(height: 7),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
        ),
      ],
    ),
  );
}
