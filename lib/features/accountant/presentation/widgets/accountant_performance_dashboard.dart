import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/accountant/services/accountant_performance_service.dart';
import 'package:chirag_accounting/features/accountant/services/accountant_profile_service.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';

class AccountantPerformanceDashboard extends StatelessWidget {
  const AccountantPerformanceDashboard({
    super.key,
    required this.user,
    required this.profile,
    required this.scorecard,
  });

  static const _navy = Color(0xFF12213A);
  static const _blue = Color(0xFF2563EB);
  static const _border = Color(0xFFE4E9F1);

  final UserModel user;
  final AccountantProfile profile;
  final AccountantPerformanceScorecard scorecard;

  String get _displayName =>
      profile.fullName.trim().isEmpty ? user.name : profile.fullName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _performanceHeader(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final annual = _annualPerformance();
            final gap = _targetGap();
            if (constraints.maxWidth < 820) {
              return Column(
                children: [annual, const SizedBox(height: 16), gap],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: annual),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: gap),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _targetWisePerformance(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final monthly = _periodPerformance(
              title: 'Monthly Performance',
              subtitle: 'April to March target achievement',
              labels: const [
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec',
                'Jan',
                'Feb',
                'Mar',
              ],
              quarterly: false,
            );
            final quarterly = _periodPerformance(
              title: 'Quarterly Performance',
              subtitle: 'Quarter-level target achievement',
              labels: const ['Q1', 'Q2', 'Q3', 'Q4'],
              quarterly: true,
            );
            if (constraints.maxWidth < 820) {
              return Column(
                children: [monthly, const SizedBox(height: 16), quarterly],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: monthly),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: quarterly),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _operationalIndicators(),
        const SizedBox(height: 16),
        _performanceRecords(),
        const SizedBox(height: 16),
        _actionPlan(),
      ],
    );
  }

  Widget _performanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2412213A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    color: Color(0xFF93C5FD),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ACCOUNTANT PERFORMANCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 22,
                runSpacing: 10,
                children: [
                  _darkLabel('Accountant', _displayName),
                  _darkLabel('Designation', profile.designation),
                  _darkLabel('Firm', user.firmName),
                ],
              ),
            ],
          );
          final summary = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _darkMetric('Overall Achievement', 'Not Available'),
              _darkMetric('Overall Rating', 'Not Available'),
              _darkMetric('Current Rank', 'Not Available'),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .14),
                    ),
                  ),
                  child: Text(
                    scorecard.period.financialYearLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              if (constraints.maxWidth < 720) ...[
                identity,
                const SizedBox(height: 18),
                summary,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 20),
                    summary,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _annualPerformance() {
    return _card(
      title: 'Annual Performance - ${scorecard.period.financialYearLabel}',
      subtitle: 'Management-calculated annual scorecard',
      trailing: _availabilityBadge(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gauge = SizedBox(
            width: 145,
            height: 145,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: CircularProgressIndicator(
                    value: 0,
                    strokeWidth: 12,
                    backgroundColor: Color(0xFFEEF2F6),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'N/A',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Overall score',
                      style: TextStyle(color: Color(0xFF98A2B3), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
          final details = Column(
            children: [
              _scoreLine('Annual Target', 'Data Not Available'),
              _scoreLine('Annual Achievement', 'Data Not Available'),
              _scoreLine('Remaining', 'Not Yet Calculated'),
              const Divider(height: 24),
              _scoreLine('Performance Status', scorecard.performanceStatus),
              _scoreLine('Rating', 'Not Yet Calculated'),
              _scoreLine('Visual Rating', '☆ ☆ ☆ ☆ ☆'),
              _scoreLine('Rank', 'Data Not Available'),
            ],
          );
          return constraints.maxWidth < 520
              ? Column(children: [gauge, details])
              : Row(
                  children: [
                    gauge,
                    const SizedBox(width: 22),
                    Expanded(child: details),
                  ],
                );
        },
      ),
    );
  }

  Widget _targetGap() {
    return _card(
      title: 'Target Gap',
      subtitle: 'Position before financial year-end',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${scorecard.daysRemaining}',
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Days Remaining',
                  style: TextStyle(color: Color(0xFF667085), fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _scoreLine('Annual Target', 'Data Not Available'),
          _scoreLine('Achieved', 'Data Not Available'),
          _scoreLine('Remaining', 'Not Yet Calculated'),
          _scoreLine('Required Monthly Run Rate', 'Not Yet Calculated'),
          _scoreLine('Required Weekly Run Rate', 'Not Yet Calculated'),
        ],
      ),
    );
  }

  Widget _targetWisePerformance() {
    final targets = [
      ('Task Completion', '${scorecard.monthlyTaskTarget} / month', 'Quantity'),
      (
        'Revenue Support',
        'INR ${scorecard.monthlyRevenueTarget.toStringAsFixed(0)}',
        'Currency',
      ),
      (
        'Client Satisfaction',
        '${scorecard.clientSatisfactionTarget}%',
        'Percentage',
      ),
    ];
    return _card(
      title: 'Target Wise Performance',
      subtitle: 'Configured targets with management-owned scoring fields',
      trailing: _availabilityBadge(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                for (final target in targets)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target.$1,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        _scoreLine('Configured Target', target.$2),
                        _scoreLine('Measurement', target.$3),
                        _scoreLine('Weight', 'Not Configured'),
                        _scoreLine('Actual', 'Data Not Available'),
                        _scoreLine('Achievement', 'Not Yet Calculated'),
                      ],
                    ),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('TARGET')),
                DataColumn(label: Text('METHOD')),
                DataColumn(label: Text('WEIGHT')),
                DataColumn(label: Text('CONFIGURED TARGET')),
                DataColumn(label: Text('ACTUAL')),
                DataColumn(label: Text('ACHIEVEMENT')),
                DataColumn(label: Text('SCORE')),
              ],
              rows: [
                for (final target in targets)
                  DataRow(
                    cells: [
                      DataCell(Text(target.$1)),
                      DataCell(Text(target.$3)),
                      const DataCell(Text('Not Configured')),
                      DataCell(Text(target.$2)),
                      const DataCell(Text('Data Not Available')),
                      const DataCell(Text('Not Yet Calculated')),
                      const DataCell(Text('Not Yet Calculated')),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodPerformance({
    required String title,
    required String subtitle,
    required List<String> labels,
    required bool quarterly,
  }) {
    return _card(
      title: title,
      subtitle: subtitle,
      trailing: _availabilityBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < labels.length; index++)
                Container(
                  width: quarterly ? 108 : 67,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _periodState(index, quarterly: quarterly),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF98A2B3),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Target vs achievement activates when the authorized data source supplies period achievements.',
            style: TextStyle(color: Color(0xFF98A2B3), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _operationalIndicators() {
    final metrics = [
      (
        'Productivity',
        '${scorecard.completedToday}',
        'Completed today',
        Icons.speed_rounded,
        _blue,
      ),
      (
        'Recorded FY Work',
        '${scorecard.recordedFyCompletedTasks}',
        'Completed records created in FY',
        Icons.fact_check_outlined,
        const Color(0xFF16A34A),
      ),
      (
        'Quality / Accuracy',
        'N/A',
        'Data Not Available',
        Icons.verified_outlined,
        const Color(0xFF7C3AED),
      ),
      (
        'Turnaround Time',
        'N/A',
        'Completion timestamps unavailable',
        Icons.timer_outlined,
        const Color(0xFF0891B2),
      ),
      (
        'Client Service',
        'N/A',
        'Feedback actual unavailable',
        Icons.support_agent_outlined,
        const Color(0xFFF59E0B),
      ),
      (
        'Discipline',
        '${scorecard.overdueTasks}',
        '${scorecard.escalatedTasks} escalated / ${scorecard.pendingTasks} pending',
        Icons.rule_outlined,
        const Color(0xFFDC2626),
      ),
    ];
    return _card(
      title: 'Performance Indicators',
      subtitle: 'Actual operational facts and data-readiness status',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 960
              ? 3
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          final itemWidth =
              (constraints.maxWidth - ((columns - 1) * 10)) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final metric in metrics)
                Container(
                  width: itemWidth,
                  height: 108,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: metric.$5.withValues(alpha: .045),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: metric.$5.withValues(alpha: .16)),
                  ),
                  child: Row(
                    children: [
                      Icon(metric.$4, color: metric.$5, size: 23),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.$1,
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              metric.$2,
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              metric.$3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionPlan() {
    final focusAreas = [
      if (scorecard.overdueTasks > 0)
        'Resolve ${scorecard.overdueTasks} overdue task(s)',
      if (scorecard.escalatedTasks > 0)
        'Review ${scorecard.escalatedTasks} escalated task(s)',
      if (scorecard.pendingTasks > 0)
        'Progress ${scorecard.pendingTasks} pending task(s)',
    ];
    return _card(
      title: 'What Do I Need To Do?',
      subtitle: 'Action plan generated from available workflow gaps',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route_outlined, color: _blue, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Annual target guidance is not yet calculated.',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Management must configure annual targets, KPI weights, caps, and rating thresholds first.',
                  style: TextStyle(color: Color(0xFF667085), fontSize: 11),
                ),
                const SizedBox(height: 10),
                if (focusAreas.isEmpty)
                  const Text(
                    'No current overdue, escalated, or pending task gaps.',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  for (final area in focusAreas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '- $area',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _performanceRecords() {
    final snapshot = scorecard.latestSnapshot;
    final items = [
      (
        'Annual Ranking',
        'Data Not Available',
        'No authorized multi-accountant score dataset',
        Icons.leaderboard_outlined,
      ),
      (
        'Performance Heatmap',
        'Data Not Available',
        'No daily performance measurements',
        Icons.calendar_month_outlined,
      ),
      (
        'Performance History',
        'Data Not Available',
        'No financial-year score records',
        Icons.history_outlined,
      ),
      (
        'Year-End Summary',
        'Not Yet Calculated',
        'Requires an approved annual score',
        Icons.summarize_outlined,
      ),
    ];
    return _card(
      title: 'Performance Records',
      subtitle: 'Ranking, history, heatmap, and year-end data readiness',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in items)
                    Container(
                      width: itemWidth,
                      constraints: const BoxConstraints(minHeight: 126),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$4, color: _blue, size: 20),
                          const SizedBox(height: 9),
                          Text(
                            item.$1,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              color: Color(0xFF98A2B3),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Latest Recorded Snapshot',
              style: TextStyle(
                color: _navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text(
                  'Generated: ${_date(snapshot.generatedAt)}',
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  'Tasks completed: ${snapshot.tasksCompleted}',
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  'Overdue: ${snapshot.overdueTasks}',
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  'Active clients: ${snapshot.activeClients}',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
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

  Widget _darkLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8292AA), fontSize: 9),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _darkMetric(String label, String value) {
    return Container(
      width: 134,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF93A4BC), fontSize: 9),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _navy,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'AWAITING DATA',
        style: TextStyle(
          color: Color(0xFFB45309),
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _periodState(int index, {required bool quarterly}) {
    final startMonth = quarterly ? 4 + (index * 3) : 4 + index;
    final month = ((startMonth - 1) % 12) + 1;
    final year = month >= 4
        ? scorecard.period.financialYearStart
        : scorecard.period.financialYearEnd;
    return DateTime(year, month).isAfter(scorecard.generatedAt)
        ? 'Not Started'
        : 'Data Not Available';
  }

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
