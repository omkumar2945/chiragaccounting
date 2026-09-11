import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/navigation/end_of_screen_navigation.dart';
import 'package:chirag_accounting/features/accountant/presentation/widgets/accountant_performance_dashboard.dart';
import 'package:chirag_accounting/features/accountant/services/accountant_performance_service.dart';
import 'package:chirag_accounting/features/accountant/services/accountant_profile_service.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/tasks/models/work_queue_bucket.dart';
import 'package:chirag_accounting/features/tasks/models/work_task.dart';
import 'package:chirag_accounting/features/workflow/models/universal_status.dart';
import 'package:chirag_accounting/shared/widgets/session_logout_button.dart';

class AccountantDashboardView extends StatefulWidget {
  const AccountantDashboardView({
    super.key,
    required this.user,
    required this.profile,
    required this.performance,
    required this.tasks,
    required this.countByBucket,
    required this.workbenchInbox,
    required this.workbenchProcessing,
    required this.workbenchReview,
    required this.workbenchCompleted,
    required this.showWorkHistory,
    required this.onWorkHistoryChanged,
    required this.onEditProfile,
    required this.tallySyncBuilder,
    required this.approvalsBuilder,
    required this.voucherCheckBuilder,
    required this.workbenchBuilder,
    required this.ocrBuilder,
    required this.showGstWork,
    required this.gstWorkBuilder,
    required this.eInvoiceBuilder,
    required this.eWayBillBuilder,
    required this.clientAccountingBuilder,
    required this.reportsBuilder,
    required this.settingsBuilder,
  });

  final UserModel user;
  final AccountantProfile profile;
  final AccountantPerformanceScorecard performance;
  final List<WorkTask> tasks;
  final int Function(WorkQueueBucket bucket) countByBucket;
  final int workbenchInbox;
  final int workbenchProcessing;
  final int workbenchReview;
  final int workbenchCompleted;
  final bool showWorkHistory;
  final ValueChanged<bool> onWorkHistoryChanged;
  final VoidCallback onEditProfile;
  final WidgetBuilder tallySyncBuilder;
  final WidgetBuilder approvalsBuilder;
  final WidgetBuilder voucherCheckBuilder;
  final WidgetBuilder workbenchBuilder;
  final WidgetBuilder ocrBuilder;
  final bool showGstWork;
  final WidgetBuilder gstWorkBuilder;
  final WidgetBuilder eInvoiceBuilder;
  final WidgetBuilder eWayBillBuilder;
  final WidgetBuilder clientAccountingBuilder;
  final WidgetBuilder reportsBuilder;
  final WidgetBuilder settingsBuilder;

  @override
  State<AccountantDashboardView> createState() =>
      _AccountantDashboardViewState();
}

class _AccountantDashboardViewState extends State<AccountantDashboardView> {
  static const _navy = Color(0xFF12213A);
  static const _blue = Color(0xFF2563EB);
  static const _border = Color(0xFFE4E9F1);
  static const _background = Color(0xFFF4F7FB);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;
  final _searchController = TextEditingController();
  final List<_AccountantPane> _paneHistory = <_AccountantPane>[
    _AccountantPane.dashboard,
  ];
  int _paneHistoryIndex = 0;
  EndOfScreenNavigationController? _paneNavigation;

  _AccountantPane get _activePane => _paneHistory[_paneHistoryIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPaneNavigation());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paneNavigation = context.read<EndOfScreenNavigationController?>();
  }

  @override
  void dispose() {
    _paneNavigation?.unregister(this);
    _searchController.dispose();
    super.dispose();
  }

  void _openPane(_AccountantPane pane) {
    if (pane == _activePane) {
      _closeDrawerIfNeeded();
      return;
    }
    setState(() {
      if (_paneHistoryIndex < _paneHistory.length - 1) {
        _paneHistory.removeRange(_paneHistoryIndex + 1, _paneHistory.length);
      }
      _paneHistory.add(pane);
      _paneHistoryIndex = _paneHistory.length - 1;
    });
    _closeDrawerIfNeeded();
    _syncPaneNavigation();
  }

  void _goBack() {
    if (_paneHistoryIndex == 0) return;
    setState(() => _paneHistoryIndex--);
    _syncPaneNavigation();
  }

  void _goForward() {
    if (_paneHistoryIndex >= _paneHistory.length - 1) return;
    setState(() => _paneHistoryIndex++);
    _syncPaneNavigation();
  }

  void _syncPaneNavigation() {
    if (!mounted) return;
    _paneNavigation?.register(
      this,
      previousLabel: 'Previous accountant screen',
      nextLabel: 'Next accountant screen',
      onPrevious: _paneHistoryIndex > 0 ? _goBack : null,
      onNext: _paneHistoryIndex < _paneHistory.length - 1 ? _goForward : null,
    );
  }

  void _closeDrawerIfNeeded() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1050;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background,
      drawer: desktop ? null : Drawer(child: _navigation(compact: false)),
      appBar: _topBar(desktop),
      body: Row(
        children: [
          if (desktop) _navigation(compact: _sidebarCollapsed),
          Expanded(child: _activeContent()),
        ],
      ),
    );
  }

  Widget _activeContent() {
    return switch (_activePane) {
      _AccountantPane.dashboard => _dashboard(),
      _AccountantPane.tallySync => widget.tallySyncBuilder(context),
      _AccountantPane.approvals ||
      _AccountantPane.workQueue => widget.approvalsBuilder(context),
      _AccountantPane.ocr => widget.ocrBuilder(context),
      _AccountantPane.workbench => widget.workbenchBuilder(context),
      _AccountantPane.vouchers => widget.voucherCheckBuilder(context),
      _AccountantPane.documents => _documentsPane(),
      _AccountantPane.gstWork => widget.gstWorkBuilder(context),
      _AccountantPane.eInvoice => widget.eInvoiceBuilder(context),
      _AccountantPane.eWayBill => widget.eWayBillBuilder(context),
      _AccountantPane.clientAccounting => widget.clientAccountingBuilder(
        context,
      ),
      _AccountantPane.reports => widget.reportsBuilder(context),
      _AccountantPane.settings => widget.settingsBuilder(context),
    };
  }

  Widget _documentsPane() {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Documents'),
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: widget.onEditProfile,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile documents'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Accountant Documents',
            style: TextStyle(
              color: _navy,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Profile and verification documents linked to this accountant.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 18),
          _documentStatusTile(
            icon: Icons.description_outlined,
            title: 'Resume',
            path: widget.profile.resumePath,
          ),
          const SizedBox(height: 10),
          _documentStatusTile(
            icon: Icons.badge_outlined,
            title: 'KYC Document',
            path: widget.profile.kycDocumentPath,
          ),
          const SizedBox(height: 10),
          _documentStatusTile(
            icon: Icons.photo_outlined,
            title: 'Profile Photo',
            path: widget.profile.photoPath,
          ),
        ],
      ),
    );
  }

  Widget _documentStatusTile({
    required IconData icon,
    required String title,
    required String path,
  }) {
    final available = path.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Icon(icon, color: _blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  available ? path : 'Not uploaded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            available ? Icons.check_circle : Icons.info_outline,
            color: available
                ? const Color(0xFF16A34A)
                : const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _topBar(bool desktop) {
    return AppBar(
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: _navy,
      leading: desktop
          ? null
          : Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
      titleSpacing: desktop ? 22 : 0,
      title: Row(
        children: [
          if (desktop) ...[
            _brandMark(),
            const SizedBox(width: 12),
            const Text(
              'Chirag Accounting',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 32),
          ],
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search current tasks and clients',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: _background,
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
      ),
      actions: [
        IconButton(
          tooltip: 'Edit profile',
          onPressed: widget.onEditProfile,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        if (desktop)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Text(
                _displayName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        const SessionLogoutButton(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _navigation({required bool compact}) {
    final pendingApprovals = widget.countByBucket(
      WorkQueueBucket.waitingApproval,
    );
    final waitingAccountant = widget.countByBucket(
      WorkQueueBucket.waitingAccountant,
    );
    final items = <_NavItem>[
      _NavItem(
        Icons.dashboard_rounded,
        'Dashboard',
        _AccountantPane.dashboard,
        null,
      ),
      if (widget.showGstWork)
        _NavItem(
          Icons.account_balance_outlined,
          'GST-PORTAL WORK',
          _AccountantPane.gstWork,
          null,
        ),
      if (widget.showGstWork)
        _NavItem(
          Icons.qr_code_2_outlined,
          'E-Invoicing',
          _AccountantPane.eInvoice,
          null,
        ),
      if (widget.showGstWork)
        _NavItem(
          Icons.local_shipping_outlined,
          'E-Way Bill',
          _AccountantPane.eWayBill,
          null,
        ),
      _NavItem(
        Icons.sync_alt_rounded,
        'Tally Sync',
        _AccountantPane.tallySync,
        null,
      ),
      _NavItem(
        Icons.approval_outlined,
        'Approvals',
        _AccountantPane.approvals,
        pendingApprovals,
      ),
      _NavItem(
        Icons.view_list_outlined,
        'Work Queue',
        _AccountantPane.workQueue,
        null,
      ),
      _NavItem(
        Icons.document_scanner_outlined,
        'OCR Module',
        _AccountantPane.ocr,
        null,
      ),
      _NavItem(
        Icons.upload_file_outlined,
        'Upload Workbench',
        _AccountantPane.workbench,
        null,
      ),
      _NavItem(
        Icons.playlist_add_check_circle_outlined,
        'Voucher Entries',
        _AccountantPane.vouchers,
        waitingAccountant,
      ),
      _NavItem(
        Icons.folder_outlined,
        'Documents',
        _AccountantPane.documents,
        null,
      ),
      _NavItem(
        Icons.dashboard_customize_outlined,
        'Business Templates',
        _AccountantPane.clientAccounting,
        null,
      ),
      _NavItem(
        Icons.analytics_outlined,
        'Reports',
        _AccountantPane.reports,
        null,
      ),
      _NavItem(
        Icons.settings_outlined,
        'Settings',
        _AccountantPane.settings,
        null,
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: compact ? 76 : 236,
      color: _navy,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                child: _profileSummary(),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: _avatar(radius: 20),
              ),
            Expanded(
              child: ListView(
                key: const ValueKey('accountant-sidebar-menu'),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final item in items) _navTile(item, compact: compact),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 1050)
              IconButton(
                tooltip: compact ? 'Expand sidebar' : 'Collapse sidebar',
                onPressed: () {
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                },
                color: Colors.white70,
                icon: Icon(
                  compact
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _dashboard() {
    final pendingOcr = widget.countByBucket(WorkQueueBucket.pendingOcr);
    final waitingClient = widget.countByBucket(WorkQueueBucket.waitingClient);
    final waitingAccountant = widget.countByBucket(
      WorkQueueBucket.waitingAccountant,
    );
    final waitingCa = widget.countByBucket(WorkQueueBucket.waitingCa);
    final waitingAuditor = widget.countByBucket(WorkQueueBucket.waitingAuditor);
    final pendingApprovals = widget.countByBucket(
      WorkQueueBucket.waitingApproval,
    );
    final completedToday = widget.countByBucket(WorkQueueBucket.completedToday);
    final overdue = widget.countByBucket(WorkQueueBucket.overdue);
    final escalated = widget.countByBucket(WorkQueueBucket.escalated);
    final activeWorkload = waitingClient + waitingCa + overdue;
    final visibleTasks = _filteredTasks;
    final assigned = visibleTasks
        .where((task) => task.owner == widget.user.id)
        .toList(growable: false);
    final completed = visibleTasks
        .where(
          (task) =>
              task.status == UniversalStatus.completed ||
              task.status == UniversalStatus.archived,
        )
        .toList(growable: false);
    final todayDone = completed
        .where((task) => task.bucket == WorkQueueBucket.completedToday)
        .toList(growable: false);
    final visibleDone = widget.showWorkHistory ? completed : todayDone;
    final buckets = <_BucketData>[
      _BucketData('Pending OCR', pendingOcr, const Color(0xFF7C3AED)),
      _BucketData('Waiting Client', waitingClient, const Color(0xFFF59E0B)),
      _BucketData('Waiting Accountant', waitingAccountant, _blue),
      _BucketData('Waiting CA', waitingCa, const Color(0xFF0891B2)),
      _BucketData('Waiting Auditor', waitingAuditor, const Color(0xFF4F46E5)),
      _BucketData(
        'Waiting Approval',
        pendingApprovals,
        const Color(0xFFEA580C),
      ),
      _BucketData('Completed Today', completedToday, const Color(0xFF16A34A)),
      _BucketData('Overdue', overdue, const Color(0xFFDC2626)),
      _BucketData('Escalated', escalated, const Color(0xFFBE185D)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      children: [
        const Text(
          'Accountant Dashboard',
          style: TextStyle(
            color: _blue,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$_greeting, $_firstName',
          style: const TextStyle(
            color: _navy,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          "Here's what's happening with your accounting workflow today.",
          style: TextStyle(color: Color(0xFF667085), fontSize: 14),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _openPane(_AccountantPane.tallySync),
              icon: const Icon(Icons.sync_alt_rounded, size: 18),
              label: const Text('Tally Sync'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openPane(_AccountantPane.approvals),
              icon: const Icon(Icons.approval_outlined, size: 18),
              label: const Text('Approvals'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openPane(_AccountantPane.ocr),
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text('Open OCR Module'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              'Pending Approvals: $pendingApprovals',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'OCR Module',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AccountantPerformanceDashboard(
          user: widget.user,
          profile: widget.profile,
          scorecard: widget.performance,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpi(
                  'Completed Today',
                  completedToday,
                  Icons.task_alt_rounded,
                  const Color(0xFF16A34A),
                  itemWidth,
                ),
                _kpi(
                  'Active Workload',
                  activeWorkload,
                  Icons.work_outline_rounded,
                  _blue,
                  itemWidth,
                ),
                _kpi(
                  'Pending Approvals',
                  pendingApprovals,
                  Icons.approval_outlined,
                  const Color(0xFFEA580C),
                  itemWidth,
                ),
                _kpi(
                  'Overdue Tasks',
                  overdue,
                  Icons.error_outline_rounded,
                  const Color(0xFFDC2626),
                  itemWidth,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final overview = _workOverview(buckets);
            final performance = _monthlyPerformance(completedToday);
            if (!wide) {
              return Column(
                children: [overview, const SizedBox(height: 16), performance],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: overview),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: performance),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Workflow Shortcuts',
          subtitle: 'Open your existing accounting workspaces',
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _shortcut(
                  'Tally Sync Center',
                  'Sync entities and monitor status',
                  Icons.sync_alt_rounded,
                  () => _openPane(_AccountantPane.tallySync),
                ),
                _shortcut(
                  'Approval Queue',
                  '$pendingApprovals pending approvals',
                  Icons.approval_outlined,
                  () => _openPane(_AccountantPane.approvals),
                ),
                _shortcut(
                  'Voucher Entries Check',
                  '$waitingAccountant waiting accountant',
                  Icons.playlist_add_check_circle_outlined,
                  () => _openPane(_AccountantPane.vouchers),
                ),
                _shortcut(
                  'Upload Workbench',
                  '${widget.workbenchInbox + widget.workbenchProcessing + widget.workbenchReview} active documents',
                  Icons.upload_file_outlined,
                  () => _openPane(_AccountantPane.workbench),
                ),
                _shortcut(
                  'OCR Module',
                  '$pendingOcr documents pending OCR',
                  Icons.document_scanner_outlined,
                  () => _openPane(_AccountantPane.ocr),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final recent = _assignments(assigned);
            final alerts = _alerts(overdue, pendingApprovals, waitingClient);
            if (!wide) {
              return Column(
                children: [recent, const SizedBox(height: 16), alerts],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: recent),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: alerts),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final workload = _emptyChart();
            final clients = _topClients();
            if (!wide) {
              return Column(
                children: [workload, const SizedBox(height: 16), clients],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: workload),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: clients),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _workDone(visibleDone),
        const SizedBox(height: 16),
        _recentActivity(visibleTasks),
        const SizedBox(height: 16),
        _uploadSummary(),
      ],
    );
  }

  Widget _kpi(
    String title,
    int value,
    IconData icon,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      height: 134,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
              const Text(
                'Live',
                style: TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
              ),
            ],
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: _navy,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workOverview(List<_BucketData> buckets) {
    final total = buckets.fold<int>(0, (sum, bucket) => sum + bucket.value);
    return _sectionCard(
      title: 'Work Overview',
      subtitle: 'Current workflow status distribution',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final chart = SizedBox(
            width: 170,
            height: 170,
            child: CustomPaint(
              painter: _DonutPainter(buckets),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          final legend = Column(
            children: [
              for (final bucket in buckets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: bucket.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bucket.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475467),
                          ),
                        ),
                      ),
                      Text(
                        '${bucket.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Text(
                          total == 0
                              ? '0%'
                              : '${(bucket.value * 100 / total).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
          return compact
              ? Column(children: [chart, const SizedBox(height: 12), legend])
              : Row(
                  children: [
                    chart,
                    const SizedBox(width: 22),
                    Expanded(child: legend),
                  ],
                );
        },
      ),
    );
  }

  Widget _monthlyPerformance(int completedToday) {
    return _sectionCard(
      title: 'Configured Monthly Targets',
      subtitle: 'Read-only targets supplied by the existing profile source',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _progressRow(
            'Task Completion Target',
            '${widget.profile.target.monthlyTaskTarget}',
            0,
            _blue,
          ),
          const SizedBox(height: 20),
          _progressRow(
            'Revenue Support Target',
            'INR ${widget.profile.target.monthlyRevenueTarget.toStringAsFixed(0)}',
            0,
            const Color(0xFF0891B2),
          ),
          const SizedBox(height: 20),
          _progressRow(
            'Client Satisfaction Target',
            '${widget.profile.target.clientSatisfactionTarget}%',
            0,
            const Color(0xFF16A34A),
          ),
          const SizedBox(height: 12),
          Text(
            'Completed today: $completedToday. Monthly achievement is not calculated because completion-date history is unavailable.',
            style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(
    String label,
    String value,
    double progress,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: const Color(0xFFEEF2F6),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _shortcut(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: 220,
      height: 90,
      child: Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _blue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _assignments(List<WorkTask> tasks) {
    final sorted = [...tasks]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _sectionCard(
      title: 'Recent Assignments',
      subtitle: 'Tasks assigned to your account',
      trailing: TextButton(
        onPressed: () => _openPane(_AccountantPane.approvals),
        child: const Text('View queue'),
      ),
      child: sorted.isEmpty
          ? _emptyState(
              Icons.assignment_turned_in_outlined,
              'No Active Work',
              "You're all caught up. New assignments will appear here.",
            )
          : Column(
              children: [for (final task in sorted.take(5)) _taskRow(task)],
            ),
    );
  }

  Widget _taskRow(WorkTask task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE8F0FF),
            child: Text(
              task.clientName.isEmpty ? '?' : task.clientName[0].toUpperCase(),
              style: const TextStyle(color: _blue, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          _statusBadge(_bucketLabel(task.bucket), _bucketColor(task.bucket)),
          const SizedBox(width: 10),
          Text(
            _relativeTime(task.createdAt),
            style: const TextStyle(fontSize: 10, color: Color(0xFF98A2B3)),
          ),
        ],
      ),
    );
  }

  Widget _alerts(int overdue, int approvals, int waitingClient) {
    final alerts = <(String, int, Color, IconData)>[
      (
        'Overdue Tasks',
        overdue,
        const Color(0xFFDC2626),
        Icons.error_outline_rounded,
      ),
      (
        'Pending Approvals',
        approvals,
        const Color(0xFFEA580C),
        Icons.approval_outlined,
      ),
      ('Waiting Client', waitingClient, _blue, Icons.hourglass_bottom_rounded),
    ];
    final hasAlerts = alerts.any((alert) => alert.$2 > 0);
    return _sectionCard(
      title: 'Alerts & Notifications',
      subtitle: 'Items requiring attention',
      child: hasAlerts
          ? Column(
              children: [
                for (final alert in alerts.where((item) => item.$2 > 0))
                  _alertRow(alert.$1, alert.$2, alert.$3, alert.$4),
              ],
            )
          : _emptyState(
              Icons.notifications_none_rounded,
              'No active alerts',
              'Everything is currently up to date.',
            ),
    );
  }

  Widget _alertRow(String label, int count, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart() {
    return _sectionCard(
      title: 'Workload Trend',
      subtitle: 'Created, completed and overdue tasks',
      trailing: const _PeriodLabel(),
      child: _emptyState(
        Icons.show_chart_rounded,
        'No historical trend available',
        'Task history will appear when the existing data source provides it.',
      ),
    );
  }

  Widget _topClients() {
    final counts = <String, int>{};
    for (final task in _filteredTasks) {
      if (task.clientName.trim().isNotEmpty) {
        counts.update(task.clientName, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.isEmpty ? 1 : sorted.first.value;
    return _sectionCard(
      title: 'Top Clients by Workload',
      subtitle: 'Based on current task volume',
      child: sorted.isEmpty
          ? _emptyState(
              Icons.groups_outlined,
              'No client workload',
              'Client workload will appear when tasks are assigned.',
            )
          : Column(
              children: [
                for (final entry in sorted.take(5))
                  _clientBar(entry.key, entry.value, max),
              ],
            ),
    );
  }

  Widget _clientBar(String name, int count, int max) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$count tasks',
                style: const TextStyle(fontSize: 10, color: Color(0xFF667085)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: count / max,
              minHeight: 7,
              backgroundColor: const Color(0xFFEEF2F6),
              color: _blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workDone(List<WorkTask> tasks) {
    return _sectionCard(
      title: 'Work Done',
      subtitle: widget.showWorkHistory
          ? 'Completed and archived history'
          : 'Completed today',
      trailing: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Today')),
          ButtonSegment(value: true, label: Text('History')),
        ],
        selected: {widget.showWorkHistory},
        onSelectionChanged: (selection) =>
            widget.onWorkHistoryChanged(selection.first),
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
      ),
      child: tasks.isEmpty
          ? _emptyState(
              Icons.task_alt_outlined,
              widget.showWorkHistory
                  ? 'No completed work history'
                  : 'Nothing completed today',
              'Completed tasks will appear here automatically.',
            )
          : Column(
              children: [for (final task in tasks.take(5)) _taskRow(task)],
            ),
    );
  }

  Widget _recentActivity(List<WorkTask> tasks) {
    final recent = [...tasks]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return _sectionCard(
      title: 'Recent Activity',
      subtitle: 'Latest activity from the existing task workflow',
      child: recent.isEmpty
          ? _emptyState(
              Icons.history_rounded,
              'No recent activity',
              'Workflow activity will appear here automatically.',
            )
          : Column(
              children: [for (final task in recent.take(5)) _taskRow(task)],
            ),
    );
  }

  Widget _uploadSummary() {
    return _sectionCard(
      title: 'Upload Images & Document Queue',
      subtitle: 'Live Upload Workbench processing status',
      trailing: TextButton.icon(
        onPressed: () => _openPane(_AccountantPane.workbench),
        icon: const Icon(Icons.open_in_new_rounded, size: 17),
        label: const Text('Open Upload Workbench'),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _queueStat('Inbox', widget.workbenchInbox, const Color(0xFF7C3AED)),
          _queueStat('Processing', widget.workbenchProcessing, _blue),
          _queueStat('Review', widget.workbenchReview, const Color(0xFFEA580C)),
          _queueStat(
            'Completed',
            widget.workbenchCompleted,
            const Color(0xFF16A34A),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OCR Module',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _openPane(_AccountantPane.ocr),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Open OCR Module'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _queueStat(String label, int count, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        border: Border.all(color: color.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB5C0D0), size: 31),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
          ),
        ],
      ),
    );
  }

  Widget _profileSummary() {
    return Row(
      children: [
        _avatar(radius: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.profile.designation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFAAB8CE), fontSize: 11),
              ),
              Text(
                widget.user.firmName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF8292AA), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar({required double radius}) {
    final bytes = _photoBytes;
    return CircleAvatar(
      radius: radius,
      backgroundColor: _blue,
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes == null
          ? Text(
              _displayName.isEmpty ? '?' : _displayName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  Widget _brandMark() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.account_balance_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _navTile(_NavItem item, {required bool compact}) {
    final active = item.pane == _activePane;
    return Tooltip(
      message: compact ? item.label : '',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: active
              ? Colors.white.withValues(alpha: .1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: ValueKey('accountant-nav-${item.pane.name}'),
            onTap: () => _openPane(item.pane),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!compact) const SizedBox(width: 12),
                  Icon(
                    item.icon,
                    color: active ? Colors.white : const Color(0xFF9AABC3),
                    size: 20,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : const Color(0xFFC1CDDD),
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (item.badge != null && item.badge! > 0)
                      _statusBadge('${item.badge}', const Color(0xFF60A5FA)),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _border),
    boxShadow: const [
      BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 3)),
    ],
  );

  String get _displayName => widget.profile.fullName.trim().isEmpty
      ? widget.user.name
      : widget.profile.fullName;

  List<WorkTask> get _filteredTasks {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.tasks;
    return widget.tasks
        .where(
          (task) =>
              task.title.toLowerCase().contains(query) ||
              task.clientName.toLowerCase().contains(query) ||
              task.entityType.toLowerCase().contains(query) ||
              task.entityId.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  String get _firstName => _displayName.trim().split(RegExp(r'\s+')).first;
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Uint8List? get _photoBytes {
    final value = widget.profile.photoBase64.trim();
    if (value.isEmpty) return null;
    try {
      return UriData.parse(
        value.startsWith('data:') ? value : 'data:image/png;base64,$value',
      ).contentAsBytes();
    } catch (_) {
      return null;
    }
  }

  String _bucketLabel(WorkQueueBucket bucket) => switch (bucket) {
    WorkQueueBucket.pendingOcr => 'Pending OCR',
    WorkQueueBucket.waitingClient => 'Waiting Client',
    WorkQueueBucket.waitingAccountant => 'Waiting Accountant',
    WorkQueueBucket.waitingCa => 'Waiting CA',
    WorkQueueBucket.waitingAuditor => 'Waiting Auditor',
    WorkQueueBucket.waitingApproval => 'Waiting Approval',
    WorkQueueBucket.completedToday => 'Completed',
    WorkQueueBucket.overdue => 'Overdue',
    WorkQueueBucket.escalated => 'Escalated',
  };

  Color _bucketColor(WorkQueueBucket bucket) => switch (bucket) {
    WorkQueueBucket.completedToday => const Color(0xFF16A34A),
    WorkQueueBucket.overdue ||
    WorkQueueBucket.escalated => const Color(0xFFDC2626),
    WorkQueueBucket.waitingApproval ||
    WorkQueueBucket.waitingClient => const Color(0xFFEA580C),
    _ => _blue,
  };

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.isNegative || difference.inMinutes < 1) return 'Now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.buckets);

  final List<_BucketData> buckets;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = buckets.fold<int>(0, (sum, bucket) => sum + bucket.value);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    if (total == 0) {
      canvas.drawCircle(center, radius, paint..color = const Color(0xFFEEF2F6));
      return;
    }
    var start = -math.pi / 2;
    for (final bucket in buckets.where((item) => item.value > 0)) {
      final sweep = (bucket.value / total) * math.pi * 2;
      canvas.drawArc(rect, start, sweep, false, paint..color = bucket.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.buckets != buckets;
}

class _BucketData {
  const _BucketData(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _NavItem {
  const _NavItem(this.icon, this.label, this.pane, this.badge);
  final IconData icon;
  final String label;
  final _AccountantPane pane;
  final int? badge;
}

enum _AccountantPane {
  dashboard,
  tallySync,
  approvals,
  workQueue,
  ocr,
  workbench,
  vouchers,
  documents,
  gstWork,
  eInvoice,
  eWayBill,
  clientAccounting,
  reports,
  settings,
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel();
  @override
  Widget build(BuildContext context) => const Chip(
    label: Text('This Month', style: TextStyle(fontSize: 10)),
    visualDensity: VisualDensity.compact,
    side: BorderSide(color: Color(0xFFE4E9F1)),
    backgroundColor: Color(0xFFF8FAFC),
  );
}
