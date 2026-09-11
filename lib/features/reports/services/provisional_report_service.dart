import 'dart:math' as math;

class ProvisionalCommand {
  const ProvisionalCommand({required this.growthPercent, this.years = 3});

  final double growthPercent;
  final int years;
}

class ProvisionalYearProjection {
  const ProvisionalYearProjection({
    required this.yearLabel,
    required this.turnover,
    required this.expenses,
    required this.netProfit,
  });

  final String yearLabel;
  final double turnover;
  final double expenses;
  final double netProfit;
}

class ProvisionalReport {
  const ProvisionalReport({
    required this.baseTurnover,
    required this.baseExpenses,
    required this.baseNetProfit,
    required this.growthPercent,
    required this.years,
    required this.projections,
  });

  final double baseTurnover;
  final double baseExpenses;
  final double baseNetProfit;
  final double growthPercent;
  final int years;
  final List<ProvisionalYearProjection> projections;
}

class ProvisionalReportService {
  const ProvisionalReportService();

  static const int defaultProjectionYears = 3;

  ProvisionalCommand parseQuickCommand(String rawInput) {
    final normalized = rawInput.trim().replaceAll('%', '');
    if (normalized.isEmpty) {
      throw const FormatException('Enter growth % command. Example: 15');
    }
    final value = double.tryParse(normalized);
    if (value == null || value < 0 || value > 300) {
      throw const FormatException('Growth % must be a number between 0 and 300.');
    }
    return ProvisionalCommand(growthPercent: value);
  }

  ProvisionalReport generateReport({
    required double baseTurnover,
    required double baseExpenses,
    required ProvisionalCommand command,
  }) {
    if (baseTurnover <= 0) {
      throw const FormatException('Previous turnover must be greater than zero.');
    }
    if (baseExpenses < 0) {
      throw const FormatException('Previous expenses cannot be negative.');
    }
    if (baseExpenses > baseTurnover) {
      throw const FormatException('Expenses cannot exceed turnover.');
    }

    final baseProfit = baseTurnover - baseExpenses;
    final growthMultiplier = 1 + (command.growthPercent / 100);
    final projections = <ProvisionalYearProjection>[];

    for (var year = 1; year <= command.years; year++) {
      final factor = math.pow(growthMultiplier, year).toDouble();
      final turnover = baseTurnover * factor;
      final netProfit = baseProfit * factor;
      final expenses = turnover - netProfit;
      projections.add(
        ProvisionalYearProjection(
          yearLabel: 'Year $year',
          turnover: turnover,
          expenses: expenses,
          netProfit: netProfit,
        ),
      );
    }

    return ProvisionalReport(
      baseTurnover: baseTurnover,
      baseExpenses: baseExpenses,
      baseNetProfit: baseProfit,
      growthPercent: command.growthPercent,
      years: command.years,
      projections: List<ProvisionalYearProjection>.unmodifiable(projections),
    );
  }

  FinancialStatementBase parseFinancialStatementText(String rawText) {
    final text = rawText.toLowerCase();
    double valueFor(List<String> keys, {double fallback = 0}) {
      for (final key in keys) {
        final pattern = RegExp(
          '${RegExp.escape(key)}[^0-9\\-]{0,25}([0-9][0-9,]*(?:\\.[0-9]+)?)',
          caseSensitive: false,
        );
        final match = pattern.firstMatch(text);
        if (match == null) continue;
        final parsed = _parseAmount(match.group(1) ?? '');
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final turnover = valueFor(<String>[
      'turnover',
      'revenue from operations',
      'sales',
      'gross turnover',
    ]);
    final otherIncome = valueFor(<String>[
      'other income',
      'non operating income',
    ]);
    final cogs = valueFor(<String>[
      'cost of goods sold',
      'cost of sales',
      'purchase',
      'material consumed',
    ]);
    final operatingExpenses = valueFor(<String>[
      'operating expenses',
      'employee benefit expenses',
      'administrative expenses',
      'other expenses',
      'selling expenses',
    ]);
    final depreciation = valueFor(<String>[
      'depreciation',
      'depreciation and amortization',
    ]);
    final interest = valueFor(<String>[
      'interest',
      'finance cost',
      'finance costs',
    ]);
    final taxExpense = valueFor(<String>[
      'tax expense',
      'income tax',
      'tax',
    ]);

    final currentAssets = valueFor(<String>['current assets']);
    final fixedAssets = valueFor(<String>[
      'fixed assets',
      'non current assets',
      'property plant equipment',
    ]);
    final currentLiabilities = valueFor(<String>['current liabilities']);
    final longTermLiabilities = valueFor(<String>[
      'long term liabilities',
      'non current liabilities',
      'borrowings',
    ]);
    final equityOpening = valueFor(<String>[
      'equity',
      'capital',
      'share capital',
      'owner funds',
    ]);

    final cfo = valueFor(<String>[
      'cash flow from operating',
      'cash generated from operations',
    ]);
    final cfi = valueFor(<String>[
      'cash flow from investing',
      'investing activities',
    ]);
    final cff = valueFor(<String>[
      'cash flow from financing',
      'financing activities',
    ]);

    final effectiveTaxRate = turnover <= 0
      ? 25.0
        : _safeTaxRate(
            taxExpense: taxExpense,
            turnover: turnover,
          );

    return FinancialStatementBase(
      turnover: turnover,
      otherIncome: otherIncome,
      costOfGoodsSold: cogs,
      operatingExpenses: operatingExpenses,
      depreciation: depreciation,
      interest: interest,
      taxRatePercent: effectiveTaxRate,
      currentAssets: currentAssets,
      fixedAssets: fixedAssets,
      currentLiabilities: currentLiabilities,
      longTermLiabilities: longTermLiabilities,
      equityOpening: equityOpening,
      cashFlowOperating: cfo,
      cashFlowInvesting: cfi,
      cashFlowFinancing: cff,
    );
  }

  FinancialProjectionReport generateFinancialProjection({
    required FinancialStatementBase base,
    required ProvisionalCommand command,
  }) {
    if (command.years <= 0) {
      throw const FormatException('Projection years must be at least 1.');
    }
    if (base.turnover <= 0) {
      throw const FormatException('Turnover must be greater than zero.');
    }

    final factor = 1 + (command.growthPercent / 100);
    final years = <FinancialProjectionYear>[];
    var equityCarry = base.equityOpening;

    for (var i = 1; i <= command.years; i++) {
      final multiplier = math.pow(factor, i).toDouble();
      final turnover = base.turnover * multiplier;
      final otherIncome = base.otherIncome * multiplier;
      final totalIncome = turnover + otherIncome;
      final cogs = base.costOfGoodsSold * multiplier;
      final opex = base.operatingExpenses * multiplier;
      final depreciation = base.depreciation * multiplier;
      final interest = base.interest * multiplier;

      final ebitda = totalIncome - cogs - opex;
      final pbt = ebitda - depreciation - interest;
      final tax = pbt > 0 ? (pbt * base.taxRatePercent / 100).toDouble() : 0.0;
      final pat = pbt - tax;

      final currentAssets = base.currentAssets * multiplier;
      final fixedAssets = base.fixedAssets * multiplier;
      final currentLiabilities = base.currentLiabilities * multiplier;
      final longTermLiabilities = base.longTermLiabilities * multiplier;
      equityCarry += pat;

      final cfo = (base.cashFlowOperating == 0 ? pat * 0.9 : base.cashFlowOperating * multiplier);
      final cfi = (base.cashFlowInvesting == 0 ? -(fixedAssets * 0.08) : base.cashFlowInvesting * multiplier);
      final cff = (base.cashFlowFinancing == 0 ? -(interest * 0.7) : base.cashFlowFinancing * multiplier);

      years.add(
        FinancialProjectionYear(
          label: 'Year $i',
          turnover: turnover,
          otherIncome: otherIncome,
          totalIncome: totalIncome,
          costOfGoodsSold: cogs,
          operatingExpenses: opex,
          ebitda: ebitda,
          depreciation: depreciation,
          interest: interest,
          profitBeforeTax: pbt,
          taxExpense: tax,
          netProfit: pat,
          currentAssets: currentAssets,
          fixedAssets: fixedAssets,
          totalAssets: currentAssets + fixedAssets,
          currentLiabilities: currentLiabilities,
          longTermLiabilities: longTermLiabilities,
          totalLiabilities: currentLiabilities + longTermLiabilities,
          equityClosing: equityCarry,
          cashFlowOperating: cfo,
          cashFlowInvesting: cfi,
          cashFlowFinancing: cff,
          netCashFlow: cfo + cfi + cff,
        ),
      );
    }

    return FinancialProjectionReport(
      base: base,
      growthPercent: command.growthPercent,
      years: command.years,
      projections: List<FinancialProjectionYear>.unmodifiable(years),
    );
  }

  double _safeTaxRate({
    required double taxExpense,
    required double turnover,
  }) {
    if (turnover <= 0 || taxExpense <= 0) return 25;
    return (taxExpense / turnover * 100).clamp(0, 35);
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }
}

class FinancialStatementBase {
  const FinancialStatementBase({
    required this.turnover,
    required this.otherIncome,
    required this.costOfGoodsSold,
    required this.operatingExpenses,
    required this.depreciation,
    required this.interest,
    required this.taxRatePercent,
    required this.currentAssets,
    required this.fixedAssets,
    required this.currentLiabilities,
    required this.longTermLiabilities,
    required this.equityOpening,
    required this.cashFlowOperating,
    required this.cashFlowInvesting,
    required this.cashFlowFinancing,
  });

  final double turnover;
  final double otherIncome;
  final double costOfGoodsSold;
  final double operatingExpenses;
  final double depreciation;
  final double interest;
  final double taxRatePercent;

  final double currentAssets;
  final double fixedAssets;
  final double currentLiabilities;
  final double longTermLiabilities;
  final double equityOpening;

  final double cashFlowOperating;
  final double cashFlowInvesting;
  final double cashFlowFinancing;

  FinancialStatementBase copyWith({
    double? turnover,
    double? otherIncome,
    double? costOfGoodsSold,
    double? operatingExpenses,
    double? depreciation,
    double? interest,
    double? taxRatePercent,
    double? currentAssets,
    double? fixedAssets,
    double? currentLiabilities,
    double? longTermLiabilities,
    double? equityOpening,
    double? cashFlowOperating,
    double? cashFlowInvesting,
    double? cashFlowFinancing,
  }) {
    return FinancialStatementBase(
      turnover: turnover ?? this.turnover,
      otherIncome: otherIncome ?? this.otherIncome,
      costOfGoodsSold: costOfGoodsSold ?? this.costOfGoodsSold,
      operatingExpenses: operatingExpenses ?? this.operatingExpenses,
      depreciation: depreciation ?? this.depreciation,
      interest: interest ?? this.interest,
      taxRatePercent: taxRatePercent ?? this.taxRatePercent,
      currentAssets: currentAssets ?? this.currentAssets,
      fixedAssets: fixedAssets ?? this.fixedAssets,
      currentLiabilities: currentLiabilities ?? this.currentLiabilities,
      longTermLiabilities: longTermLiabilities ?? this.longTermLiabilities,
      equityOpening: equityOpening ?? this.equityOpening,
      cashFlowOperating: cashFlowOperating ?? this.cashFlowOperating,
      cashFlowInvesting: cashFlowInvesting ?? this.cashFlowInvesting,
      cashFlowFinancing: cashFlowFinancing ?? this.cashFlowFinancing,
    );
  }
}

class FinancialProjectionYear {
  const FinancialProjectionYear({
    required this.label,
    required this.turnover,
    required this.otherIncome,
    required this.totalIncome,
    required this.costOfGoodsSold,
    required this.operatingExpenses,
    required this.ebitda,
    required this.depreciation,
    required this.interest,
    required this.profitBeforeTax,
    required this.taxExpense,
    required this.netProfit,
    required this.currentAssets,
    required this.fixedAssets,
    required this.totalAssets,
    required this.currentLiabilities,
    required this.longTermLiabilities,
    required this.totalLiabilities,
    required this.equityClosing,
    required this.cashFlowOperating,
    required this.cashFlowInvesting,
    required this.cashFlowFinancing,
    required this.netCashFlow,
  });

  final String label;
  final double turnover;
  final double otherIncome;
  final double totalIncome;
  final double costOfGoodsSold;
  final double operatingExpenses;
  final double ebitda;
  final double depreciation;
  final double interest;
  final double profitBeforeTax;
  final double taxExpense;
  final double netProfit;
  final double currentAssets;
  final double fixedAssets;
  final double totalAssets;
  final double currentLiabilities;
  final double longTermLiabilities;
  final double totalLiabilities;
  final double equityClosing;
  final double cashFlowOperating;
  final double cashFlowInvesting;
  final double cashFlowFinancing;
  final double netCashFlow;
}

class FinancialProjectionReport {
  const FinancialProjectionReport({
    required this.base,
    required this.growthPercent,
    required this.years,
    required this.projections,
  });

  final FinancialStatementBase base;
  final double growthPercent;
  final int years;
  final List<FinancialProjectionYear> projections;
}
