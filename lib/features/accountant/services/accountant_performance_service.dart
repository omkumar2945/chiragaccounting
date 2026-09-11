import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/accounting/accounting_policy_service.dart';
import 'package:chirag_accounting/features/accountant/services/accountant_profile_service.dart';
import 'package:chirag_accounting/features/tasks/models/work_queue_bucket.dart';
import 'package:chirag_accounting/features/tasks/models/work_task.dart';
import 'package:chirag_accounting/features/workflow/models/universal_status.dart';

@immutable
class AccountantPerformanceScorecard {
  const AccountantPerformanceScorecard({
    required this.period,
    required this.generatedAt,
    required this.monthlyTaskTarget,
    required this.monthlyRevenueTarget,
    required this.clientSatisfactionTarget,
    required this.completedToday,
    required this.recordedCompletedTasks,
    required this.recordedFyCompletedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.escalatedTasks,
    required this.activeClients,
    required this.daysRemaining,
    required this.latestSnapshot,
  });

  final AccountingPeriod period;
  final DateTime generatedAt;
  final int monthlyTaskTarget;
  final double monthlyRevenueTarget;
  final int clientSatisfactionTarget;
  final int completedToday;
  final int recordedCompletedTasks;
  final int recordedFyCompletedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final int escalatedTasks;
  final int activeClients;
  final int daysRemaining;
  final AccountantPerformanceSnapshot? latestSnapshot;

  // These require organization-owned KPI definitions and period achievements.
  double? get annualTarget => null;
  double? get annualAchievement => null;
  double? get annualAchievementPercent => null;
  double? get overallScore => null;
  double? get rating => null;
  int? get rank => null;
  int? get rankPopulation => null;
  double? get accuracyPercent => null;
  Duration? get averageTurnaroundTime => null;
  double? get clientSatisfactionActual => null;
  double? get requiredMonthlyRunRate => null;
  double? get requiredWeeklyRunRate => null;

  String get performanceStatus => 'Not Yet Calculated';
}

class AccountantPerformanceService {
  const AccountantPerformanceService();

  static AccountingPeriod currentIndianFinancialYear(DateTime now) {
    return AccountingPeriod(
      financialYearStart: now.month >= DateTime.april ? now.year : now.year - 1,
    );
  }

  AccountantPerformanceScorecard build({
    required AccountantProfile profile,
    required List<WorkTask> tasks,
    required AccountingPeriod period,
    required DateTime now,
    required int completedToday,
    required int overdueTasks,
    required int escalatedTasks,
  }) {
    final completed = tasks.where(_isCompleted).toList(growable: false);
    final completedInFinancialYear = completed
        .where((task) => period.contains(task.createdAt))
        .length;
    final pending = tasks.where((task) => !_isCompleted(task)).length;
    final activeClients = tasks
        .map((task) => task.clientName.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;
    final daysRemaining = period.endsOn.isBefore(now)
        ? 0
        : period.endsOn.difference(now).inDays + 1;

    return AccountantPerformanceScorecard(
      period: period,
      generatedAt: now,
      monthlyTaskTarget: profile.target.monthlyTaskTarget,
      monthlyRevenueTarget: profile.target.monthlyRevenueTarget,
      clientSatisfactionTarget: profile.target.clientSatisfactionTarget,
      completedToday: completedToday,
      recordedCompletedTasks: completed.length,
      recordedFyCompletedTasks: completedInFinancialYear,
      pendingTasks: pending,
      overdueTasks: overdueTasks,
      escalatedTasks: escalatedTasks,
      activeClients: activeClients,
      daysRemaining: daysRemaining,
      latestSnapshot: profile.lastPerformance,
    );
  }

  bool _isCompleted(WorkTask task) {
    return task.status == UniversalStatus.completed ||
        task.status == UniversalStatus.archived ||
        task.bucket == WorkQueueBucket.completedToday;
  }
}
