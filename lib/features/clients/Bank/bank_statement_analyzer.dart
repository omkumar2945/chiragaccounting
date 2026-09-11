import 'package:chirag_accounting/features/customers/models/customer.dart';
import 'package:chirag_accounting/features/vendors/models/vendor.dart';

enum BankStatementFormat { generic, sbi, icici, hdfc, axis }

extension BankStatementFormatExtension on BankStatementFormat {
  String get label {
    switch (this) {
      case BankStatementFormat.generic:
        return 'Generic CSV/TXT';
      case BankStatementFormat.sbi:
        return 'SBI';
      case BankStatementFormat.icici:
        return 'ICICI';
      case BankStatementFormat.hdfc:
        return 'HDFC';
      case BankStatementFormat.axis:
        return 'Axis';
    }
  }

  String get storageValue => name;

  static BankStatementFormat fromStorage(String value) {
    return BankStatementFormat.values
            .where((item) => item.name == value)
            .cast<BankStatementFormat?>()
            .firstWhere(
              (item) => item != null,
              orElse: () => BankStatementFormat.generic,
            ) ??
        BankStatementFormat.generic;
  }
}

enum StatementCategory {
  emi,
  rent,
  salary,
  gst,
  utility,
  bankCharge,
  transfer,
  salesReceipt,
  supplierPayment,
  cash,
  uncategorized,
}

extension StatementCategoryExtension on StatementCategory {
  String get label {
    switch (this) {
      case StatementCategory.emi:
        return 'EMI / Loan';
      case StatementCategory.rent:
        return 'Rent';
      case StatementCategory.salary:
        return 'Salary';
      case StatementCategory.gst:
        return 'GST / Tax';
      case StatementCategory.utility:
        return 'Utility';
      case StatementCategory.bankCharge:
        return 'Bank Charge';
      case StatementCategory.transfer:
        return 'Bank Transfer';
      case StatementCategory.salesReceipt:
        return 'Customer Receipt';
      case StatementCategory.supplierPayment:
        return 'Supplier Payment';
      case StatementCategory.cash:
        return 'Cash Transaction';
      case StatementCategory.uncategorized:
        return 'Uncategorized';
    }
  }
}

class BankStatementSuggestion {
  final DateTime? date;
  final String description;
  final String reference;
  final double amount;
  final bool isCredit;
  final String patternKey;
  final String suggestedLedger;
  final StatementCategory category;
  final bool isRecurring;
  final String recurringHint;

  const BankStatementSuggestion({
    required this.description,
    required this.reference,
    required this.amount,
    required this.isCredit,
    required this.patternKey,
    required this.suggestedLedger,
    required this.category,
    required this.isRecurring,
    required this.recurringHint,
    this.date,
  });

  String get voucherType => isCredit ? 'receipt' : 'payment';
  String get channel => 'bank';
  String get narration => category == StatementCategory.uncategorized
      ? description
      : '${category.label}: $description';

  String toAutoEntryLine() {
    return '$voucherType,$channel,${amount.toStringAsFixed(2)},$suggestedLedger,$reference,$narration';
  }

  BankStatementSuggestion copyWith({
    DateTime? date,
    String? description,
    String? reference,
    double? amount,
    bool? isCredit,
    String? patternKey,
    String? suggestedLedger,
    StatementCategory? category,
    bool? isRecurring,
    String? recurringHint,
  }) {
    return BankStatementSuggestion(
      date: date ?? this.date,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      amount: amount ?? this.amount,
      isCredit: isCredit ?? this.isCredit,
      patternKey: patternKey ?? this.patternKey,
      suggestedLedger: suggestedLedger ?? this.suggestedLedger,
      category: category ?? this.category,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringHint: recurringHint ?? this.recurringHint,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': date?.toIso8601String(),
      'description': description,
      'reference': reference,
      'amount': amount,
      'isCredit': isCredit,
      'patternKey': patternKey,
      'suggestedLedger': suggestedLedger,
      'category': category.name,
      'isRecurring': isRecurring,
      'recurringHint': recurringHint,
    };
  }

  factory BankStatementSuggestion.fromMap(Map<String, dynamic> map) {
    return BankStatementSuggestion(
      date: map['date'] is String
          ? DateTime.tryParse(map['date'] as String)
          : null,
      description: (map['description'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      isCredit: map['isCredit'] == true,
      patternKey: (map['patternKey'] ?? '').toString(),
      suggestedLedger: (map['suggestedLedger'] ?? '').toString(),
      category:
          StatementCategory.values
              .where((item) => item.name == (map['category'] ?? '').toString())
              .cast<StatementCategory?>()
              .firstWhere(
                (item) => item != null,
                orElse: () => StatementCategory.uncategorized,
              ) ??
          StatementCategory.uncategorized,
      isRecurring: map['isRecurring'] == true,
      recurringHint: (map['recurringHint'] ?? '').toString(),
    );
  }
}

class BankRecurringRule {
  final String patternKey;
  final String ledgerName;
  final StatementCategory category;

  const BankRecurringRule({
    required this.patternKey,
    required this.ledgerName,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'patternKey': patternKey,
      'ledgerName': ledgerName,
      'category': category.name,
    };
  }

  factory BankRecurringRule.fromMap(Map<String, dynamic> map) {
    return BankRecurringRule(
      patternKey: (map['patternKey'] ?? '').toString(),
      ledgerName: (map['ledgerName'] ?? '').toString(),
      category:
          StatementCategory.values
              .where((item) => item.name == (map['category'] ?? '').toString())
              .cast<StatementCategory?>()
              .firstWhere(
                (item) => item != null,
                orElse: () => StatementCategory.uncategorized,
              ) ??
          StatementCategory.uncategorized,
    );
  }
}

class BankStatementAnalysisResult {
  final List<BankStatementSuggestion> suggestions;
  final int recurringCount;
  final BankStatementFormat detectedFormat;

  const BankStatementAnalysisResult({
    required this.suggestions,
    required this.recurringCount,
    required this.detectedFormat,
  });

  bool get hasSuggestions => suggestions.isNotEmpty;
}

class BankStatementAnalyzer {
  BankStatementAnalysisResult analyze({
    required String statementText,
    required List<Customer> customers,
    required List<Vendor> vendors,
    List<BankRecurringRule> recurringRules = const <BankRecurringRule>[],
  }) {
    final parsed = _parseRows(statementText);
    final rows = parsed.rows;
    final ruleByPattern = <String, BankRecurringRule>{
      for (final rule in recurringRules)
        if (rule.patternKey.trim().isNotEmpty) rule.patternKey.trim(): rule,
    };
    final recurrenceMap = <String, int>{};
    for (final row in rows) {
      final key = buildRecurringKey(row.description);
      recurrenceMap[key] = (recurrenceMap[key] ?? 0) + 1;
    }

    final suggestions = rows
        .map((row) {
          final patternKey = buildRecurringKey(row.description);
          final matchedRule = ruleByPattern[patternKey];
          final detectedCategory = _detectCategory(
            description: row.description,
            isCredit: row.isCredit,
          );
          final category = matchedRule?.category ?? detectedCategory;
          final ledger =
              matchedRule?.ledgerName ??
              _suggestLedger(
                description: row.description,
                isCredit: row.isCredit,
                category: category,
                customers: customers,
                vendors: vendors,
              );
          final recurring =
              matchedRule != null ||
              _isRecurring(
                description: row.description,
                category: category,
                hitsInBatch: recurrenceMap[patternKey] ?? 0,
              );
          return BankStatementSuggestion(
            date: row.date,
            description: row.description,
            reference: row.reference,
            amount: row.amount,
            isCredit: row.isCredit,
            patternKey: patternKey,
            suggestedLedger: ledger,
            category: category,
            isRecurring: recurring,
            recurringHint: matchedRule != null
                ? 'Saved rule applied'
                : recurring
                ? _recurringHint(category)
                : '',
          );
        })
        .toList(growable: false);

    return BankStatementAnalysisResult(
      suggestions: suggestions,
      recurringCount: suggestions.where((item) => item.isRecurring).length,
      detectedFormat: parsed.format,
    );
  }

  String buildRecurringKey(String description) => _recurrenceKey(description);

  _ParsedStatement _parseRows(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      return const _ParsedStatement(
        rows: <_StatementRow>[],
        format: BankStatementFormat.generic,
      );
    }

    var startIndex = 0;
    final headerColumns = _splitColumns(
      lines.first,
    ).map((e) => e.toLowerCase()).toList(growable: false);
    final headerMapping = _matchHeaderMapping(headerColumns);
    final hasHeader = headerColumns.any(
      (column) =>
          column.contains('date') ||
          column.contains('description') ||
          column.contains('particular') ||
          column.contains('debit') ||
          column.contains('credit'),
    );

    int? dateIndex = headerMapping?.dateIndex;
    int? descriptionIndex = headerMapping?.descriptionIndex;
    int? referenceIndex = headerMapping?.referenceIndex;
    int? debitIndex = headerMapping?.debitIndex;
    int? creditIndex = headerMapping?.creditIndex;

    if (hasHeader) {
      startIndex = 1;
      for (var index = 0; index < headerColumns.length; index++) {
        final column = headerColumns[index];
        if (dateIndex == null && column.contains('date')) dateIndex = index;
        if (descriptionIndex == null &&
            (column.contains('description') ||
                column.contains('particular') ||
                column.contains('narration') ||
                column.contains('remark'))) {
          descriptionIndex = index;
        }
        if (referenceIndex == null &&
            (column.contains('ref') ||
                column.contains('utr') ||
                column.contains('chq'))) {
          referenceIndex = index;
        }
        if (debitIndex == null &&
            (column.contains('debit') || column.contains('withdrawal'))) {
          debitIndex = index;
        }
        if (creditIndex == null &&
            (column.contains('credit') || column.contains('deposit'))) {
          creditIndex = index;
        }
      }
    }

    final rows = <_StatementRow>[];
    for (var index = startIndex; index < lines.length; index++) {
      final columns = _splitColumns(lines[index]);
      final row = _parseRow(
        columns,
        dateIndex: dateIndex,
        descriptionIndex: descriptionIndex,
        referenceIndex: referenceIndex,
        debitIndex: debitIndex,
        creditIndex: creditIndex,
      );
      if (row != null) rows.add(row);
    }
    return _ParsedStatement(
      rows: rows,
      format: headerMapping?.format ?? BankStatementFormat.generic,
    );
  }

  _HeaderMapping? _matchHeaderMapping(List<String> columns) {
    final signatures = <_HeaderSignature>[
      const _HeaderSignature(
        format: BankStatementFormat.sbi,
        containsAll: <String>[
          'txn date',
          'description',
          'ref no',
          'debit',
          'credit',
        ],
      ),
      const _HeaderSignature(
        format: BankStatementFormat.icici,
        containsAll: <String>[
          'transaction date',
          'narration',
          'withdrawal amt',
          'deposit amt',
        ],
      ),
      const _HeaderSignature(
        format: BankStatementFormat.hdfc,
        containsAll: <String>[
          'date',
          'narration',
          'chq./ref.no.',
          'withdrawal amt',
          'deposit amt',
        ],
      ),
      const _HeaderSignature(
        format: BankStatementFormat.axis,
        containsAll: <String>[
          'tran date',
          'particulars',
          'chq no',
          'debit',
          'credit',
        ],
      ),
    ];

    for (final signature in signatures) {
      final matched = signature.containsAll.every(
        (token) => columns.any((column) => column.contains(token)),
      );
      if (!matched) continue;
      switch (signature.format) {
        case BankStatementFormat.sbi:
          return _HeaderMapping(
            format: signature.format,
            dateIndex: _findIndex(columns, <String>[
              'txn date',
              'transaction date',
            ]),
            descriptionIndex: _findIndex(columns, <String>['description']),
            referenceIndex: _findIndex(columns, <String>[
              'ref no',
              'cheque no',
            ]),
            debitIndex: _findIndex(columns, <String>['debit']),
            creditIndex: _findIndex(columns, <String>['credit']),
          );
        case BankStatementFormat.icici:
          return _HeaderMapping(
            format: signature.format,
            dateIndex: _findIndex(columns, <String>['transaction date']),
            descriptionIndex: _findIndex(columns, <String>['narration']),
            referenceIndex: _findIndex(columns, <String>[
              'chq/ref no',
              'ref no',
            ]),
            debitIndex: _findIndex(columns, <String>['withdrawal amt']),
            creditIndex: _findIndex(columns, <String>['deposit amt']),
          );
        case BankStatementFormat.hdfc:
          return _HeaderMapping(
            format: signature.format,
            dateIndex: _findIndex(columns, <String>['date']),
            descriptionIndex: _findIndex(columns, <String>['narration']),
            referenceIndex: _findIndex(columns, <String>[
              'chq./ref.no.',
              'chq/ref no',
            ]),
            debitIndex: _findIndex(columns, <String>['withdrawal amt']),
            creditIndex: _findIndex(columns, <String>['deposit amt']),
          );
        case BankStatementFormat.axis:
          return _HeaderMapping(
            format: signature.format,
            dateIndex: _findIndex(columns, <String>['tran date']),
            descriptionIndex: _findIndex(columns, <String>['particulars']),
            referenceIndex: _findIndex(columns, <String>['chq no']),
            debitIndex: _findIndex(columns, <String>['debit']),
            creditIndex: _findIndex(columns, <String>['credit']),
          );
        case BankStatementFormat.generic:
          break;
      }
    }
    return null;
  }

  int? _findIndex(List<String> columns, List<String> candidates) {
    for (var index = 0; index < columns.length; index++) {
      final column = columns[index];
      if (candidates.any((candidate) => column.contains(candidate))) {
        return index;
      }
    }
    return null;
  }

  _StatementRow? _parseRow(
    List<String> columns, {
    int? dateIndex,
    int? descriptionIndex,
    int? referenceIndex,
    int? debitIndex,
    int? creditIndex,
  }) {
    if (columns.isEmpty) return null;

    final date = dateIndex != null && dateIndex < columns.length
        ? _tryParseDate(columns[dateIndex])
        : _tryParseDate(columns.first);

    final description =
        descriptionIndex != null && descriptionIndex < columns.length
        ? columns[descriptionIndex].trim()
        : columns.length > 1
        ? columns[1].trim()
        : columns.first.trim();
    if (description.isEmpty) return null;

    final reference = referenceIndex != null && referenceIndex < columns.length
        ? columns[referenceIndex].trim()
        : '';

    double debit = 0;
    double credit = 0;
    if (debitIndex != null && debitIndex < columns.length) {
      debit = _tryParseAmount(columns[debitIndex]) ?? 0;
    }
    if (creditIndex != null && creditIndex < columns.length) {
      credit = _tryParseAmount(columns[creditIndex]) ?? 0;
    }

    if (debit <= 0 && credit <= 0) {
      final numericValues = columns
          .map(_tryParseAmount)
          .whereType<double>()
          .where((value) => value > 0)
          .toList(growable: false);
      if (numericValues.isEmpty) return null;
      if (numericValues.length >= 2) {
        debit = numericValues[0];
        credit = numericValues[1];
      } else {
        final rawLine = columns.join(' ').toLowerCase();
        if (rawLine.contains('cr') ||
            rawLine.contains('credit') ||
            rawLine.contains('received')) {
          credit = numericValues.first;
        } else {
          debit = numericValues.first;
        }
      }
    }

    final amount = credit > 0 ? credit : debit;
    if (amount <= 0) return null;

    return _StatementRow(
      date: date,
      description: description,
      reference: reference,
      amount: amount,
      isCredit: credit > 0,
    );
  }

  List<String> _splitColumns(String line) {
    if (line.contains('\t') && !line.contains(',')) {
      return line
          .split('\t')
          .map((part) => part.trim())
          .toList(growable: false);
    }

    final columns = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (char == ',' && !inQuotes) {
        columns.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    columns.add(buffer.toString().trim());
    return columns;
  }

  DateTime? _tryParseDate(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    final slash = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$',
    ).firstMatch(cleaned);
    if (slash != null) {
      final day = int.tryParse(slash.group(1) ?? '');
      final month = int.tryParse(slash.group(2) ?? '');
      final yearRaw = int.tryParse(slash.group(3) ?? '');
      if (day != null && month != null && yearRaw != null) {
        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(cleaned);
  }

  double? _tryParseAmount(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '-') return null;
    return double.tryParse(cleaned);
  }

  StatementCategory _detectCategory({
    required String description,
    required bool isCredit,
  }) {
    final text = description.toLowerCase();
    if (text.contains('emi') || text.contains('loan')) {
      return StatementCategory.emi;
    }
    if (text.contains('rent') || text.contains('lease')) {
      return StatementCategory.rent;
    }
    if (text.contains('salary') ||
        text.contains('payroll') ||
        text.contains('wages')) {
      return StatementCategory.salary;
    }
    if (text.contains('gst') ||
        text.contains('cgst') ||
        text.contains('sgst') ||
        text.contains('igst') ||
        text.contains('tax')) {
      return StatementCategory.gst;
    }
    if (text.contains('electricity') ||
        text.contains('water') ||
        text.contains('internet') ||
        text.contains('broadband') ||
        text.contains('mobile bill')) {
      return StatementCategory.utility;
    }
    if (text.contains('charge') ||
        text.contains('fee') ||
        text.contains('commission') ||
        text.contains('interest debit')) {
      return StatementCategory.bankCharge;
    }
    if (text.contains('cash') || text.contains('atm')) {
      return StatementCategory.cash;
    }
    if (text.contains('upi') ||
        text.contains('neft') ||
        text.contains('rtgs') ||
        text.contains('imps') ||
        text.contains('transfer')) {
      return StatementCategory.transfer;
    }
    if (isCredit) return StatementCategory.salesReceipt;
    return StatementCategory.supplierPayment;
  }

  String _suggestLedger({
    required String description,
    required bool isCredit,
    required StatementCategory category,
    required List<Customer> customers,
    required List<Vendor> vendors,
  }) {
    final normalizedDescription = description.toLowerCase();
    for (final customer in customers) {
      final customerName = customer.customerName.trim();
      if (customerName.isNotEmpty &&
          normalizedDescription.contains(customerName.toLowerCase())) {
        return customerName;
      }
    }
    for (final vendor in vendors) {
      final vendorName = vendor.vendorName.trim();
      if (vendorName.isNotEmpty &&
          normalizedDescription.contains(vendorName.toLowerCase())) {
        return vendorName;
      }
    }

    switch (category) {
      case StatementCategory.gst:
        return 'GST Payable';
      case StatementCategory.salary:
        return 'Salary Payable';
      case StatementCategory.rent:
        return 'Rent Expense';
      case StatementCategory.emi:
        return 'Loan Account';
      case StatementCategory.utility:
        return 'Utility Expense';
      case StatementCategory.bankCharge:
        return 'Bank Charges';
      case StatementCategory.cash:
        return 'Cash Account';
      case StatementCategory.salesReceipt:
        return customers.isNotEmpty
            ? customers.first.customerName
            : 'Customer Receipt Ledger';
      case StatementCategory.supplierPayment:
        return vendors.isNotEmpty
            ? vendors.first.vendorName
            : 'Supplier Payment Ledger';
      case StatementCategory.transfer:
        return isCredit ? 'Transfer Inward' : 'Transfer Outward';
      case StatementCategory.uncategorized:
        return isCredit ? 'Receipt Ledger' : 'Payment Ledger';
    }
  }

  bool _isRecurring({
    required String description,
    required StatementCategory category,
    required int hitsInBatch,
  }) {
    if (hitsInBatch > 1) return true;
    switch (category) {
      case StatementCategory.emi:
      case StatementCategory.rent:
      case StatementCategory.salary:
      case StatementCategory.gst:
      case StatementCategory.utility:
        return true;
      case StatementCategory.bankCharge:
      case StatementCategory.transfer:
      case StatementCategory.salesReceipt:
      case StatementCategory.supplierPayment:
      case StatementCategory.cash:
      case StatementCategory.uncategorized:
        return false;
    }
  }

  String _recurrenceKey(String description) {
    return description
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _recurringHint(StatementCategory category) {
    switch (category) {
      case StatementCategory.emi:
        return 'Recurring EMI / loan debit';
      case StatementCategory.rent:
        return 'Recurring monthly rent';
      case StatementCategory.salary:
        return 'Recurring salary payout';
      case StatementCategory.gst:
        return 'Recurring GST / tax payment';
      case StatementCategory.utility:
        return 'Recurring utility expense';
      default:
        return 'Repeated transaction pattern detected';
    }
  }
}

class _StatementRow {
  final DateTime? date;
  final String description;
  final String reference;
  final double amount;
  final bool isCredit;

  const _StatementRow({
    required this.description,
    required this.reference,
    required this.amount,
    required this.isCredit,
    this.date,
  });
}

class _ParsedStatement {
  final List<_StatementRow> rows;
  final BankStatementFormat format;

  const _ParsedStatement({required this.rows, required this.format});
}

class _HeaderMapping {
  final BankStatementFormat format;
  final int? dateIndex;
  final int? descriptionIndex;
  final int? referenceIndex;
  final int? debitIndex;
  final int? creditIndex;

  const _HeaderMapping({
    required this.format,
    this.dateIndex,
    this.descriptionIndex,
    this.referenceIndex,
    this.debitIndex,
    this.creditIndex,
  });
}

class _HeaderSignature {
  final BankStatementFormat format;
  final List<String> containsAll;

  const _HeaderSignature({required this.format, required this.containsAll});
}
