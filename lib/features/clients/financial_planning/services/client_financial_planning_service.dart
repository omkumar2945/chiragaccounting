import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/core/events/event_types.dart';
import 'package:chirag_accounting/features/clients/financial_planning/models/client_financial_planning_models.dart';

class ClientFinancialPlanningService extends ChangeNotifier {
  ClientFinancialPlanningService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _storageKey = 'client_financial_planning_v1';

  final SharedPreferences? _preferences;

  List<LoanPlan> _loans = const <LoanPlan>[];
  List<InvestmentPlan> _investments = const <InvestmentPlan>[];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      _loans = ((decoded['loans'] as List<dynamic>? ?? const <dynamic>[]))
          .whereType<Map>()
          .map((value) => LoanPlan.fromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
      _investments =
          ((decoded['investments'] as List<dynamic>? ?? const <dynamic>[]))
              .whereType<Map>()
              .map(
                (value) => InvestmentPlan.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .toList(growable: false);
    } catch (_) {
      _loans = const <LoanPlan>[];
      _investments = const <InvestmentPlan>[];
    }
    _loaded = true;
    notifyListeners();
  }

  List<LoanPlan> loansForClient(String clientId) {
    return _loans
        .where((plan) => plan.clientId == clientId)
        .toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  List<InvestmentPlan> investmentsForClient(String clientId) {
    return _investments
        .where((plan) => plan.clientId == clientId)
        .toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  Future<void> saveLoan(LoanPlan plan) async {
    final now = DateTime.now();
    final next = plan.copyWith(updatedAt: now);
    final index = _loans.indexWhere((item) => item.id == next.id);
    if (index >= 0) {
      final mutable = <LoanPlan>[..._loans];
      mutable[index] = next;
      _loans = mutable;
      await _save();
      _publishPlanEvent(next.clientId, next.clientName, 'Loan', next.planName, 'updated');
      return;
    }
    _loans = <LoanPlan>[next, ..._loans];
    await _save();
    _publishPlanEvent(next.clientId, next.clientName, 'Loan', next.planName, 'saved');
  }

  Future<void> deleteLoan(LoanPlan plan) async {
    _loans = _loans.where((item) => item.id != plan.id).toList(growable: false);
    await _save();
    _publishPlanEvent(plan.clientId, plan.clientName, 'Loan', plan.planName, 'deleted');
  }

  Future<void> saveInvestment(InvestmentPlan plan) async {
    final now = DateTime.now();
    final next = plan.copyWith(updatedAt: now);
    final index = _investments.indexWhere((item) => item.id == next.id);
    if (index >= 0) {
      final mutable = <InvestmentPlan>[..._investments];
      mutable[index] = next;
      _investments = mutable;
      await _save();
      _publishPlanEvent(next.clientId, next.clientName, 'Investment', next.planName, 'updated');
      return;
    }
    _investments = <InvestmentPlan>[next, ..._investments];
    await _save();
    _publishPlanEvent(next.clientId, next.clientName, 'Investment', next.planName, 'saved');
  }

  Future<void> deleteInvestment(InvestmentPlan plan) async {
    _investments = _investments
        .where((item) => item.id != plan.id)
        .toList(growable: false);
    await _save();
    _publishPlanEvent(
      plan.clientId,
      plan.clientName,
      'Investment',
      plan.planName,
      'deleted',
    );
  }

  double calculateLoanEmi({
    required double principal,
    required double annualRate,
    required int tenureMonths,
  }) {
    if (principal <= 0 || annualRate <= 0 || tenureMonths <= 0) return 0;
    final monthlyRate = annualRate / 1200;
    final factor = math.pow(1 + monthlyRate, tenureMonths).toDouble();
    if (factor == 1) return 0;
    return principal * monthlyRate * factor / (factor - 1);
  }

  double calculateOdCcInterest({
    required double utilizedAmount,
    required double annualRate,
    required int utilizedDays,
  }) {
    if (utilizedAmount <= 0 || annualRate <= 0 || utilizedDays <= 0) return 0;
    return utilizedAmount * annualRate * utilizedDays / 36500;
  }

  double calculateInvestmentProjection({
    required double monthlyContribution,
    required double yearlyContribution,
    required double annualReturnRate,
    required int tenureMonths,
  }) {
    if (tenureMonths <= 0) return 0;
    final monthlyRate = annualReturnRate / 1200;
    final monthlySeries = monthlyContribution > 0 && monthlyRate > 0
        ? monthlyContribution *
            ((math.pow(1 + monthlyRate, tenureMonths) - 1) / monthlyRate)
        : monthlyContribution * tenureMonths;
    final yearlyInstallments = tenureMonths ~/ 12;
    double yearlySeries = 0;
    if (yearlyContribution > 0 && yearlyInstallments > 0) {
      final annualRate = annualReturnRate / 100;
      yearlySeries = annualRate > 0
          ? yearlyContribution *
              ((math.pow(1 + annualRate, yearlyInstallments) - 1) / annualRate)
          : yearlyContribution * yearlyInstallments;
    }
    return monthlySeries + yearlySeries;
  }

  Future<void> _save() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(<String, dynamic>{
        'loans': _loans.map((plan) => plan.toJson()).toList(growable: false),
        'investments': _investments
            .map((plan) => plan.toJson())
            .toList(growable: false),
      }),
    );
    notifyListeners();
  }

  void _publishPlanEvent(
    String clientId,
    String clientName,
    String category,
    String planLabel,
    String actionLabel,
  ) {
    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.clientFinancialPlanUpdated,
        entityType: 'client_financial_plan',
        entityId: '$category:$planLabel',
        clientId: clientId,
        module: 'financial-planning',
        action: actionLabel,
        performedBy: clientName,
        role: 'client',
        payload: <String, dynamic>{
          'clientName': clientName,
          'planCategory': category,
          'planLabel': planLabel,
          'actionLabel': actionLabel,
          'summary': '$clientName $actionLabel $category plan "$planLabel".',
        },
      ),
    );
  }
}