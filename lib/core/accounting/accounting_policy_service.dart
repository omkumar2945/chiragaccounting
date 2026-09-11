import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountingPeriod {
  const AccountingPeriod({required this.financialYearStart});

  final int financialYearStart;

  int get financialYearEnd => financialYearStart + 1;
  String get financialYearLabel =>
      'FY $financialYearStart-${financialYearEnd.toString().substring(2)}';
  String get assessmentYearLabel =>
      'AY $financialYearEnd-${(financialYearEnd + 1).toString().substring(2)}';

  DateTime get startsOn => DateTime(financialYearStart, 4, 1);
  DateTime get endsOn => DateTime(financialYearEnd, 3, 31, 23, 59, 59, 999);

  bool contains(DateTime date) =>
      !date.isBefore(startsOn) && !date.isAfter(endsOn);
}

class AccountingPolicyException implements Exception {
  const AccountingPolicyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountingPolicyService extends ChangeNotifier {
  AccountingPolicyService({SharedPreferences? preferences, DateTime? now})
    : _preferences = preferences,
      _now = now ?? DateTime.now(),
      _period = AccountingPeriod(
        financialYearStart: _financialYearStartFor(now ?? DateTime.now()),
      );

  static const String _financialYearKey = 'accounting_financial_year_start_v1';
  static const String _filedPeriodsKey = 'accounting_filed_gst_periods_v1';
  static const String _voucherNumbersKey = 'accounting_voucher_numbers_v1';

  final SharedPreferences? _preferences;
  final DateTime _now;
  AccountingPeriod _period;
  final Set<String> _filedGstPeriods = <String>{};
  final Set<String> _voucherNumbers = <String>{};
  bool _isLoaded = false;

  AccountingPeriod get period => _period;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final storedYear = preferences.getInt(_financialYearKey);
    if (storedYear != null) {
      _period = AccountingPeriod(financialYearStart: storedYear);
    }
    _filedGstPeriods
      ..clear()
      ..addAll(preferences.getStringList(_filedPeriodsKey) ?? const <String>[]);
    _voucherNumbers
      ..clear()
      ..addAll(
        preferences.getStringList(_voucherNumbersKey) ?? const <String>[],
      );
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setFinancialYearStart(int year) async {
    if (year < 2000 || year > 2100) {
      throw const AccountingPolicyException('Financial year is invalid.');
    }
    _period = AccountingPeriod(financialYearStart: year);
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setInt(_financialYearKey, year);
    notifyListeners();
  }

  void validateClientSubmissionDate(DateTime date) {
    if (date.year != _now.year || date.month != _now.month) {
      throw const AccountingPolicyException(
        'Clients can upload and submit current-month data only. Contact Chirag Associates for prior-period adjustments.',
      );
    }
    if (!_period.contains(date)) {
      throw AccountingPolicyException(
        'The date is outside ${_period.financialYearLabel}. Change the financial year before posting.',
      );
    }
  }

  DateTime clientStandardHistoryStartsOn(DateTime joinedOn) {
    return DateTime(joinedOn.year, joinedOn.month - 3, 1);
  }

  bool canClientViewData({
    required DateTime recordDate,
    required DateTime joinedOn,
    bool isClientOwned = false,
    bool accountantAssigned = false,
    bool oldAccountingApproved = false,
    bool reportsPublished = false,
  }) {
    if (isClientOwned) return true;
    final standardStart = clientStandardHistoryStartsOn(joinedOn);
    if (!recordDate.isBefore(standardStart)) return true;
    return accountantAssigned && oldAccountingApproved && reportsPublished;
  }

  void validateClientDataAccess({
    required DateTime recordDate,
    required DateTime joinedOn,
    bool isClientOwned = false,
    bool accountantAssigned = false,
    bool oldAccountingApproved = false,
    bool reportsPublished = false,
  }) {
    if (canClientViewData(
      recordDate: recordDate,
      joinedOn: joinedOn,
      isClientOwned: isClientOwned,
      accountantAssigned: accountantAssigned,
      oldAccountingApproved: oldAccountingApproved,
      reportsPublished: reportsPublished,
    )) {
      return;
    }
    throw const AccountingPolicyException(
      'This period is older than the three-month joining window. An admin must assign an Accountant/CA, approve old accounting, and publish the reports before the client can view it.',
    );
  }

  void validateOpenPeriod({required String clientId, required DateTime date}) {
    if (isGstPeriodFiled(clientId: clientId, date: date)) {
      throw AccountingPolicyException(
        'GST return for ${periodKey(date)} is filed. Existing accounting entries cannot be changed or deleted; post an adjustment in an open period.',
      );
    }
  }

  bool isGstPeriodFiled({required String clientId, required DateTime date}) {
    return _filedGstPeriods.contains(_filedKey(clientId, date));
  }

  Future<void> markGstPeriodFiled({
    required String clientId,
    required DateTime date,
  }) async {
    _filedGstPeriods.add(_filedKey(clientId, date));
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setStringList(
      _filedPeriodsKey,
      _filedGstPeriods.toList(growable: false),
    );
    notifyListeners();
  }

  bool voucherNumberExists(String voucherNumber) {
    return _voucherNumbers.contains(_normalizeNumber(voucherNumber));
  }

  Future<void> reserveVoucherNumber(String voucherNumber) async {
    final normalized = _normalizeNumber(voucherNumber);
    if (normalized.isEmpty) {
      throw const AccountingPolicyException('Voucher number is required.');
    }
    if (_voucherNumbers.contains(normalized)) {
      throw AccountingPolicyException(
        'Voucher number "$voucherNumber" already exists. Voucher numbers must be unique across all voucher types.',
      );
    }
    _voucherNumbers.add(normalized);
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setStringList(
      _voucherNumbersKey,
      _voucherNumbers.toList(growable: false),
    );
    notifyListeners();
  }

  String nextVoucherNumber() {
    var sequence = _voucherNumbers.length + 1;
    String candidate;
    do {
      candidate =
          'VCH-${_period.financialYearStart.toString().substring(2)}-${sequence.toString().padLeft(6, '0')}';
      sequence++;
    } while (voucherNumberExists(candidate));
    return candidate;
  }

  static int _financialYearStartFor(DateTime date) =>
      date.month >= 4 ? date.year : date.year - 1;

  static String periodKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _filedKey(String clientId, DateTime date) =>
      '${clientId.trim().toLowerCase()}|${periodKey(date)}';

  String _normalizeNumber(String value) => value.trim().toLowerCase();
}
