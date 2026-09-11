import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/dashboard/models/activity_model.dart';
import 'package:chirag_accounting/features/dashboard/models/kpi_model.dart';
import 'package:chirag_accounting/features/dashboard/models/notification_model.dart';
import 'package:chirag_accounting/features/dashboard/presentation/widgets/quick_actions_widget.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';

class ClientBusinessDashboardView extends StatelessWidget {
  const ClientBusinessDashboardView({
    super.key,
    required this.user,
    required this.kpis,
    required this.monthlySales,
    required this.activities,
    required this.notifications,
    required this.visibleModules,
    required this.bankingPermissions,
    required this.financialYearLabel,
    required this.onRefresh,
  });

  static const _navy = Color(0xFF12213A);
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF16865C);
  static const _amber = Color(0xFFD97706);
  static const _border = Color(0xFFE3E9F2);

  final UserModel user;
  final List<KpiModel> kpis;
  final List<double> monthlySales;
  final List<ActivityModel> activities;
  final List<NotificationModel> notifications;
  final List<ClientModuleDefinition> visibleModules;
  final Set<BankingPermission> bankingPermissions;
  final String financialYearLabel;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final sales = _kpi(KpiType.sales);
    final clients = _kpi(KpiType.clients);
    final products = _kpi(KpiType.tasks);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          _welcome(sales),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 5
                  : constraints.maxWidth >= 700
                  ? 3
                  : constraints.maxWidth >= 360
                  ? 2
                  : 1;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric(
                    "Today's Sales",
                    sales?.value ?? '₹0',
                    sales?.subtitle ?? '0 invoices',
                    Icons.trending_up_rounded,
                    _green,
                    itemWidth,
                    available: true,
                  ),
                  _metric(
                    "Today's Purchase",
                    null,
                    'Awaiting purchase activity',
                    Icons.shopping_bag_outlined,
                    _amber,
                    itemWidth,
                  ),
                  _metric(
                    'Total Receivables',
                    null,
                    'Awaiting outstanding data',
                    Icons.call_received_rounded,
                    _blue,
                    itemWidth,
                  ),
                  _metric(
                    'Total Payables',
                    null,
                    'Awaiting outstanding data',
                    Icons.call_made_rounded,
                    const Color(0xFFC2415D),
                    itemWidth,
                  ),
                  _metric(
                    'Net Profit',
                    null,
                    'Awaiting verified profit data',
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFF4F46E5),
                    itemWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = _salesChart();
              final overview = _businessOverview(sales);
              if (constraints.maxWidth < 840) {
                return Column(
                  children: [chart, const SizedBox(height: 16), overview],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chart),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: overview),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _financialSummary(),
          const SizedBox(height: 14),
          const QuickActionsWidget(compact: true),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final reminders = _reminders();
              final recent = _recentActivity();
              if (constraints.maxWidth < 840) {
                return Column(
                  children: [reminders, const SizedBox(height: 16), recent],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: reminders),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: recent),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final customers = _entitySummary(
                title: 'Top Customers',
                value: clients?.value ?? '0',
                detail: clients?.subtitle ?? 'No customer data available',
                icon: Icons.groups_outlined,
              );
              final productSummary = _entitySummary(
                title: 'Top Products / Services',
                value: products?.value ?? '0',
                detail: products?.subtitle ?? 'No product data available',
                icon: Icons.inventory_2_outlined,
              );
              if (constraints.maxWidth < 700) {
                return Column(
                  children: [
                    customers,
                    const SizedBox(height: 16),
                    productSummary,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: customers),
                  const SizedBox(width: 16),
                  Expanded(child: productSummary),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _accessSummary(),
        ],
      ),
    );
  }

  Widget _welcome(KpiModel? sales) {
    final firstName = user.name.trim().isEmpty
        ? 'Client'
        : user.name.trim().split(RegExp(r'\s+')).first;
    final invoiceCount = _leadingNumber(sales?.subtitle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_greeting()}, $firstName!',
              style: const TextStyle(
                color: _navy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Here's what's happening with your business today.",
              style: TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ],
        );
        final factItems = <Widget>[
            _infographicFact(
              Icons.receipt_long_outlined,
              '$invoiceCount',
              'Invoices',
              _green,
            ),
            _infographicFact(
              Icons.widgets_outlined,
              '${visibleModules.length}',
              'Modules',
              _blue,
            ),
            _infographicFact(
              Icons.calendar_month_outlined,
              financialYearLabel,
              'Accounting period',
              const Color(0xFF7C3AED),
            ),
          ];
        final facts = constraints.maxWidth < 360
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < factItems.length; index++) ...[
                      factItems[index],
                      if (index < factItems.length - 1)
                        const SizedBox(width: 18),
                    ],
                  ],
                ),
              )
            : Wrap(spacing: 18, runSpacing: 10, children: factItems);

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [intro, const SizedBox(height: 14), facts],
          );
        }
        return Row(
          children: [
            Expanded(child: intro),
            const SizedBox(width: 24),
            facts,
          ],
        );
      },
    );
  }

  Widget _infographicFact(
    IconData icon,
    String value,
    String label,
    Color color, {
    bool compact = false,
  }
  ) {
    final details = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: _navy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 9),
        ),
      ],
    );
    final iconWidget = Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 17),
    );
    if (compact) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          children: [iconWidget, const SizedBox(height: 5), details],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 8),
        details,
      ],
    );
  }

  Widget _metric(
    String title,
    String? value,
    String detail,
    IconData icon,
    Color color,
    double width, {
    bool available = false,
  }) {
    return Container(
      width: width,
      height: width < 150 ? 152 : 126,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (width < 150) ...[
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 6),
            Tooltip(
              message: available ? 'Current' : 'Pending',
              child: Icon(
                available
                    ? Icons.trending_flat_rounded
                    : Icons.hourglass_empty_rounded,
                color: color,
                size: 16,
              ),
            ),
          ] else
            Row(
              children: [
                Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
                const Spacer(),
                _metricStatus(color, available),
              ],
            ),
          const Spacer(),
          Text(
            value ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == null ? const Color(0xFF98A2B3) : _navy,
              fontSize: value == null ? 20 : 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _navy,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF7C8AA0), fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _metricStatus(Color color, bool available) {
    if (!available) {
      return Tooltip(
        message: 'Pending',
        child: Icon(Icons.hourglass_empty_rounded, color: color, size: 16),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_flat_rounded,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            'CURRENT',
            style: TextStyle(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesChart() {
    final hasData = monthlySales.any((value) => value > 0);
    return _card(
      title: 'Monthly Sales & Purchase',
      subtitle: 'Recorded business activity by month',
      trailing: _SmallTag(financialYearLabel),
      child: hasData
          ? Column(
              children: [
                const Row(
                  children: [
                    _LegendDot(color: _blue, label: 'Sales'),
                    SizedBox(width: 14),
                    _LegendDot(
                      color: _amber,
                      label: 'Purchase · awaiting data',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 176,
                  child: CustomPaint(
                    painter: _SalesBarsPainter(monthlySales),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 7),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Apr', style: _axisStyle),
                    Text('Jun', style: _axisStyle),
                    Text('Aug', style: _axisStyle),
                    Text('Oct', style: _axisStyle),
                    Text('Dec', style: _axisStyle),
                    Text('Feb', style: _axisStyle),
                    Text('Mar', style: _axisStyle),
                  ],
                ),
              ],
            )
          : const _BusinessEmptyState(),
    );
  }

  Widget _businessOverview(KpiModel? sales) {
    final invoiceCount = _leadingNumber(sales?.subtitle);
    return _card(
      title: 'Business Overview',
      subtitle: 'Transaction categories supported by current data',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final ring = SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(
                  painter: _OverviewRingPainter(hasSales: invoiceCount > 0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$invoiceCount',
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'TOTAL TRANSACTIONS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF7C8AA0),
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              final legend = Column(
                children: [
                  _overviewLine(
                    'Sales Invoices',
                    invoiceCount > 0 ? '100% · $invoiceCount' : '0% · 0',
                    _green,
                  ),
                  _overviewLine('Purchase Bills', 'Awaiting activity', _amber),
                  _overviewLine(
                    'Payments / Receipts',
                    'Awaiting activity',
                    _blue,
                  ),
                  _overviewLine(
                    'Journal Entries',
                    'Awaiting activity',
                    const Color(0xFF7C3AED),
                  ),
                ],
              );
              if (constraints.maxWidth < 390) {
                return Column(
                  children: [ring, const SizedBox(height: 12), legend],
                );
              }
              return Row(
                children: [
                  ring,
                  const SizedBox(width: 14),
                  Expanded(child: legend),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FF),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              invoiceCount == 0
                  ? 'No business activity yet. Your transaction mix will appear automatically.'
                  : 'Overview reflects currently recorded sales invoices.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF53709C), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialSummary() {
    const items = <({String label, IconData icon, Color color})>[
      (label: 'Cash in Hand', icon: Icons.savings_outlined, color: _green),
      (
        label: 'Bank Balance',
        icon: Icons.account_balance_outlined,
        color: _blue,
      ),
      (
        label: 'Outstanding Receivables',
        icon: Icons.receipt_long_outlined,
        color: _amber,
      ),
      (
        label: 'Outstanding Payables',
        icon: Icons.payments_outlined,
        color: Color(0xFFC2415D),
      ),
      (
        label: 'Documents Pending',
        icon: Icons.file_copy_outlined,
        color: Color(0xFF7C3AED),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 620
            ? 3
            : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _SummaryTile(
                  label: item.label,
                  icon: item.icon,
                  color: item.color,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _overviewLine(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _navy,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _reminders() {
    return _card(
      title: 'Important Reminders',
      subtitle: 'Current system notifications',
      child: notifications.isEmpty
          ? _empty(
              Icons.task_alt_rounded,
              "You're all caught up.",
              'New reminders will appear here.',
            )
          : Column(
              children: [
                for (final item in notifications.take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.notifications_none_rounded,
                      color: _amber,
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      item.message,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _recentActivity() {
    return _card(
      title: 'Recent Activity',
      subtitle: 'Latest activity from the existing dashboard feed',
      child: activities.isEmpty
          ? _empty(
              Icons.history_rounded,
              'No recent activities.',
              'Your latest accounting activity will appear here.',
            )
          : Column(
              children: [
                for (final activity in activities.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _activityIcon(activity.type),
                            color: _blue,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                activity.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _relativeTime(activity.timestamp),
                          style: const TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _entitySummary({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
  }) {
    return _card(
      title: title,
      subtitle: 'Summary from the existing dashboard source',
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10,
                  ),
                ),
                const Text(
                  'Contribution detail: Data Not Available',
                  style: TextStyle(color: Color(0xFF98A2B3), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final access = _card(
          title: 'My Access',
          subtitle: 'Modules allowed by your existing role permissions',
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final module in visibleModules)
                Chip(
                  avatar: const Icon(
                    Icons.check_circle,
                    size: 15,
                    color: _green,
                  ),
                  label: Text(module.displayName),
                  labelStyle: const TextStyle(fontSize: 10),
                  backgroundColor: const Color(0xFFF7FAFC),
                  side: const BorderSide(color: _border),
                ),
            ],
          ),
        );
        final banking = _card(
          title: 'Banking Access',
          subtitle: 'Existing banking permission badges',
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final permission in bankingPermissions)
                Chip(
                  avatar: const Icon(Icons.check, size: 14, color: _blue),
                  label: Text(permission.displayName),
                  labelStyle: const TextStyle(fontSize: 10),
                  backgroundColor: const Color(0xFFF7FAFC),
                  side: const BorderSide(color: _border),
                ),
            ],
          ),
        );
        if (constraints.maxWidth < 840) {
          return Column(
            children: [access, const SizedBox(height: 16), banking],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: access),
            const SizedBox(width: 16),
            Expanded(child: banking),
          ],
        );
      },
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _decoration,
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
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String title, String detail) {
    return SizedBox(
      width: double.infinity,
      height: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFB2BDCC), size: 25),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10))),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _valueLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _navy,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  KpiModel? _kpi(KpiType type) {
    for (final kpi in kpis) {
      if (kpi.type == type) return kpi;
    }
    return null;
  }

  int _leadingNumber(String? value) {
    if (value == null) return 0;
    return int.tryParse(RegExp(r'^\d+').firstMatch(value)?.group(0) ?? '') ?? 0;
  }

  IconData _activityIcon(ActivityType type) => switch (type) {
    ActivityType.sale => Icons.receipt_long_outlined,
    ActivityType.purchase => Icons.shopping_bag_outlined,
    ActivityType.payment => Icons.call_made_rounded,
    ActivityType.receipt => Icons.call_received_rounded,
    ActivityType.gst => Icons.percent_rounded,
    ActivityType.bank => Icons.account_balance_outlined,
  };

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.isNegative || difference.inMinutes < 1) return 'Now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  BoxDecoration get _decoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _border),
    boxShadow: const [
      BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 3)),
    ],
  );
}

class _SmallTag extends StatelessWidget {
  const _SmallTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F6FF),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF2563EB),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

const _axisStyle = TextStyle(color: Color(0xFF98A2B3), fontSize: 8);

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 9),
        ),
      ],
    );
  }
}

class _BusinessEmptyState extends StatelessWidget {
  const _BusinessEmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 224,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 86,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const Icon(
                Icons.insert_chart_outlined_rounded,
                color: Color(0xFF4F7DD9),
                size: 42,
              ),
              const Positioned(
                right: 4,
                top: 2,
                child: Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF16A673),
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Text(
            'No business activity yet',
            style: TextStyle(
              color: Color(0xFF12213A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your financial overview will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7C8AA0), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE3E9F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Awaiting activity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF12213A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRingPainter extends CustomPainter {
  const _OverviewRingPainter({required this.hasSales});

  final bool hasSales;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final track = Paint()
      ..color = const Color(0xFFEDF1F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15;
    canvas.drawCircle(center, radius, track);
    if (!hasSales) return;
    final sales = Paint()
      ..color = const Color(0xFF16A673)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 - .06,
      false,
      sales,
    );
  }

  @override
  bool shouldRepaint(covariant _OverviewRingPainter oldDelegate) =>
      oldDelegate.hasSales != hasSales;
}

class _SalesBarsPainter extends CustomPainter {
  const _SalesBarsPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<double>(0, math.max);
    if (maxValue <= 0) return;
    final paint = Paint()..color = const Color(0xFF2563EB);
    final track = Paint()..color = const Color(0xFFEEF2F6);
    final slot = size.width / values.length;
    for (var index = 0; index < values.length; index++) {
      final barWidth = math.min(18.0, slot * .52);
      final left = (index * slot) + ((slot - barWidth) / 2);
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, barWidth, size.height),
        const Radius.circular(4),
      );
      canvas.drawRRect(trackRect, track);
      final barHeight = (values[index] / maxValue) * size.height;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesBarsPainter oldDelegate) =>
      oldDelegate.values != values;
}
