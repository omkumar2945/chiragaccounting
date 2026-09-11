import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/constants/feature_flags.dart';

import 'package:chirag_accounting/features/clients/Bank/bank_statement_analyzer.dart';
import 'package:chirag_accounting/features/clients/Bank/bank_statement_history_screen.dart';
import 'package:chirag_accounting/features/clients/Bank/bank_statement_service.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

enum VoucherType { payment, receipt, creditNote, debitNote }

extension VoucherTypeExtension on VoucherType {
  String get displayName {
    switch (this) {
      case VoucherType.payment:
        return 'Payment';
      case VoucherType.receipt:
        return 'Receipt';
      case VoucherType.creditNote:
        return 'Credit Note';
      case VoucherType.debitNote:
        return 'Debit Note';
    }
  }
}

enum PaymentChannel { cash, upi, neftRtgsImps, cheque }

extension PaymentChannelExtension on PaymentChannel {
  String get displayName {
    switch (this) {
      case PaymentChannel.cash:
        return 'Cash';
      case PaymentChannel.upi:
        return 'UPI';
      case PaymentChannel.neftRtgsImps:
        return 'NEFT/RTGS/IMPS';
      case PaymentChannel.cheque:
        return 'Cheque';
    }
  }
}

enum EntryMode { manual, auto }

class _LedgerSelectIntent extends Intent {
  const _LedgerSelectIntent(this.offset);

  final int offset;
}

class _LedgerSubmitIntent extends Intent {
  const _LedgerSubmitIntent();
}

class BankVoucher {
  final String id;
  final VoucherType type;
  final PaymentChannel channel;
  final double amount;
  final String party;
  final String originalInvoiceNumber;
  final DateTime? originalInvoiceDate;
  final String returnReason;
  final String reference;
  final String narration;
  final DateTime createdAt;
  final bool autoCreated;

  const BankVoucher({
    required this.id,
    required this.type,
    required this.channel,
    required this.amount,
    required this.party,
    this.originalInvoiceNumber = '',
    this.originalInvoiceDate,
    this.returnReason = '',
    required this.reference,
    required this.narration,
    required this.createdAt,
    this.autoCreated = false,
  });
}

class ClientBankScreen extends StatefulWidget {
  final VoucherType? initialVoucherType;
  final bool startInAutoMode;
  final bool autoOpenStatementUpload;

  const ClientBankScreen({
    super.key,
    this.initialVoucherType,
    this.startInAutoMode = false,
    this.autoOpenStatementUpload = false,
  });

  @override
  State<ClientBankScreen> createState() => _ClientBankScreenState();
}

class _ClientBankScreenState extends State<ClientBankScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final _ledgerSearchCtrl = TextEditingController();
  final _ledgerSearchFocusNode = FocusNode();
  final _originalInvoiceNoCtrl = TextEditingController();
  final _originalInvoiceDateCtrl = TextEditingController();
  final _returnReasonCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _autoLineCtrl = TextEditingController();
  final _statementAnalyzer = BankStatementAnalyzer();
  final _statementService = BankStatementService();

  EntryMode _entryMode = EntryMode.manual;
  VoucherType _voucherType = VoucherType.payment;
  PaymentChannel _channel = PaymentChannel.cash;
  String _ledgerSearchQuery = '';
  int _ledgerHighlightedIndex = 0;
  String _statementStatus =
      'Upload a bank statement CSV/TXT to suggest ledger allocation, detect recurring entries, and auto-categorize transactions.';
  List<BankStatementSuggestion> _statementSuggestions =
      <BankStatementSuggestion>[];

  final List<BankVoucher> _vouchers = <BankVoucher>[];

  bool get _requiresCustomerName =>
      _voucherType == VoucherType.creditNote ||
      _voucherType == VoucherType.debitNote;

  bool get _requiresOriginalInvoice => _requiresCustomerName;

  String get _partyFieldLabel => _voucherType == VoucherType.payment
      ? 'Payment Ledger (Debtor/Creditor)'
      : _voucherType == VoucherType.receipt
      ? 'Receipt Ledger (Debtor/Creditor)'
      : _voucherType == VoucherType.creditNote
      ? 'Customer Ledger (Sales Return)'
      : _voucherType == VoucherType.debitNote
      ? 'Supplier Ledger (Purchase Return)'
      : 'Party / Account Name';

  String get _partyRequiredMessage => _voucherType == VoucherType.creditNote
      ? 'Customer ledger is required'
      : _voucherType == VoucherType.debitNote
      ? 'Supplier ledger is required'
      : 'Party ledger is required';

  String get _originalInvoiceLabel => _voucherType == VoucherType.debitNote
      ? 'Original Purchase Invoice No.'
      : 'Original Sales Invoice No.';

  String get _originalInvoiceDateLabel => _voucherType == VoucherType.debitNote
      ? 'Original Purchase Invoice Date'
      : 'Original Sales Invoice Date';

  String get _originalInvoiceHint => _voucherType == VoucherType.debitNote
      ? 'Purchase invoice being returned to supplier'
      : 'Sales invoice being returned by customer';

  String get _returnReasonLabel => _voucherType == VoucherType.debitNote
      ? 'Reason For Purchase Return'
      : 'Reason For Sales Return';

  bool get _usesLedgerPicker =>
      _voucherType == VoucherType.payment ||
      _voucherType == VoucherType.receipt ||
      _voucherType == VoucherType.creditNote ||
      _voucherType == VoucherType.debitNote;

  List<String> _availableLedgers() {
    if (_voucherType == VoucherType.payment ||
        _voucherType == VoucherType.receipt) {
      final customerLedgers = context
          .read<CustomerService>()
          .customers
          .map((customer) => customer.customerName)
          .where((name) => name.trim().isNotEmpty);
      final vendorLedgers = context
          .read<VendorService>()
          .vendors
          .map((vendor) => vendor.vendorName)
          .where((name) => name.trim().isNotEmpty);

      return {...customerLedgers, ...vendorLedgers}.toList(growable: false)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    if (_voucherType == VoucherType.creditNote) {
      return context
          .read<CustomerService>()
          .customers
          .map((customer) => customer.customerName)
          .where((name) => name.trim().isNotEmpty)
          .toList(growable: false);
    }

    if (_voucherType == VoucherType.debitNote) {
      return context
          .read<VendorService>()
          .vendors
          .map((vendor) => vendor.vendorName)
          .where((name) => name.trim().isNotEmpty)
          .toList(growable: false);
    }

    return const [];
  }

  List<String> _filteredLedgers() {
    final query = _ledgerSearchQuery.trim().toLowerCase();
    final ledgers = _availableLedgers();
    if (query.isEmpty) return ledgers;
    return ledgers
        .where((ledger) => ledger.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialVoucherType != null) {
      _voucherType = widget.initialVoucherType!;
    }
    if (widget.startInAutoMode) {
      _entryMode = EntryMode.auto;
    }
    if (widget.autoOpenStatementUpload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analyzeUploadedStatement();
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _partyCtrl.dispose();
    _ledgerSearchCtrl.dispose();
    _ledgerSearchFocusNode.dispose();
    _originalInvoiceNoCtrl.dispose();
    _originalInvoiceDateCtrl.dispose();
    _returnReasonCtrl.dispose();
    _referenceCtrl.dispose();
    _narrationCtrl.dispose();
    _autoLineCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value.trim());
    } catch (_) {
      return null;
    }
  }

  bool _hasMatchingLedger(String partyName) {
    if (partyName.trim().isEmpty) return false;

    if (_voucherType == VoucherType.payment ||
        _voucherType == VoucherType.receipt) {
      return context.read<CustomerService>().findIdentityMatch(partyName) !=
              null ||
          context.read<VendorService>().findIdentityMatch(name: partyName) !=
              null;
    }

    if (_voucherType == VoucherType.creditNote) {
      return context.read<CustomerService>().findIdentityMatch(partyName) !=
          null;
    }

    if (_voucherType == VoucherType.debitNote) {
      return context.read<VendorService>().findIdentityMatch(name: partyName) !=
          null;
    }

    return true;
  }

  void _syncLedgerSelection(String ledger) {
    _partyCtrl.text = ledger;
    _ledgerSearchCtrl.text = ledger;
    _ledgerSearchQuery = ledger;
    _ledgerHighlightedIndex = 0;
  }

  void _moveLedgerSelection(int offset) {
    final ledgers = _filteredLedgers();
    if (ledgers.isEmpty) return;
    setState(() {
      final next = _ledgerHighlightedIndex + offset;
      if (next < 0) {
        _ledgerHighlightedIndex = 0;
      } else if (next >= ledgers.length) {
        _ledgerHighlightedIndex = ledgers.length - 1;
      } else {
        _ledgerHighlightedIndex = next;
      }
    });
  }

  void _submitLedgerSelection() {
    final ledgers = _filteredLedgers();
    if (ledgers.isEmpty) return;
    setState(() {
      _syncLedgerSelection(ledgers[_ledgerHighlightedIndex]);
    });
    _ledgerSearchFocusNode.requestFocus();
  }

  void _onVoucherTypeChanged(VoucherType type) {
    setState(() {
      _voucherType = type;
      _partyCtrl.clear();
      _ledgerSearchCtrl.clear();
      _ledgerSearchQuery = '';
      _ledgerHighlightedIndex = 0;
      _originalInvoiceNoCtrl.clear();
      _originalInvoiceDateCtrl.clear();
      _returnReasonCtrl.clear();
    });
  }

  String _normalizeParty(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  bool _matchesProvidedDate(DateTime expected, DateTime provided) {
    return expected.year == provided.year &&
        expected.month == provided.month &&
        expected.day == provided.day;
  }

  String? _validateAccountingRules() {
    final partyName = _partyCtrl.text.trim();
    if (_usesLedgerPicker &&
        partyName.isNotEmpty &&
        !_hasMatchingLedger(partyName)) {
      if (_voucherType == VoucherType.payment ||
          _voucherType == VoucherType.receipt) {
        return 'Ledger not found. Select an existing debtor/creditor ledger.';
      }
      return _voucherType == VoucherType.creditNote
          ? 'Customer ledger not found. Save the customer first.'
          : 'Vendor ledger not found. Save the vendor first.';
    }

    if (!_requiresOriginalInvoice) return null;

    if (partyName.isEmpty) {
      return _partyRequiredMessage;
    }

    final invoiceNo = _originalInvoiceNoCtrl.text.trim();
    if (invoiceNo.isEmpty) {
      return '$_originalInvoiceLabel is required';
    }

    final invoiceDate = _parseDate(_originalInvoiceDateCtrl.text);
    if (invoiceDate == null) {
      return 'Original invoice date is required';
    }

    if (_returnReasonCtrl.text.trim().isEmpty) {
      return '$_returnReasonLabel is required';
    }

    if (_voucherType == VoucherType.creditNote) {
      final salesInvoice = context.read<SalesService>().findByInvoiceNumber(
        invoiceNo,
      );
      if (salesInvoice == null) {
        return 'Credit note allowed only against existing sales invoice.';
      }

      if (_normalizeParty(salesInvoice.customerName) !=
          _normalizeParty(partyName)) {
        return 'Selected customer does not match that sales invoice.';
      }

      if (!_matchesProvidedDate(salesInvoice.invoiceDate, invoiceDate)) {
        return 'Original invoice date must match the selected sales invoice date.';
      }
    }

    if (_voucherType == VoucherType.debitNote) {
      final purchaseBill = context.read<PurchaseService>().findByBillNumber(
        invoiceNo,
      );
      if (purchaseBill == null) {
        return 'Debit note allowed only against existing purchase bill.';
      }

      if (_normalizeParty(purchaseBill.vendorName) !=
          _normalizeParty(partyName)) {
        return 'Selected vendor does not match that purchase bill.';
      }

      if (!_matchesProvidedDate(purchaseBill.billDate, invoiceDate)) {
        return 'Original bill date must match the selected purchase bill date.';
      }
    }

    return null;
  }

  double get _balance {
    var opening = 0.0;
    for (final voucher in _vouchers) {
      final addToBalance =
          voucher.type == VoucherType.receipt ||
          voucher.type == VoucherType.creditNote;
      opening += addToBalance ? voucher.amount : -voucher.amount;
    }
    return opening;
  }

  void _createManualVoucher() {
    if (!_formKey.currentState!.validate()) return;

    final accountingError = _validateAccountingRules();
    if (accountingError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(accountingError)));
      return;
    }

    final partyName = _partyCtrl.text.trim();
    final originalInvoiceDate = _parseDate(_originalInvoiceDateCtrl.text);

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    final voucher = BankVoucher(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _voucherType,
      channel: _channel,
      amount: amount,
      party: partyName,
      originalInvoiceNumber: _originalInvoiceNoCtrl.text.trim(),
      originalInvoiceDate: originalInvoiceDate,
      returnReason: _returnReasonCtrl.text.trim(),
      reference: _referenceCtrl.text.trim(),
      narration: _narrationCtrl.text.trim(),
      createdAt: DateTime.now(),
      autoCreated: false,
    );

    setState(() {
      _vouchers.insert(0, voucher);
      _amountCtrl.clear();
      _referenceCtrl.clear();
      _returnReasonCtrl.clear();
      _narrationCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${voucher.type.displayName} voucher created via ${voucher.channel.displayName}.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _createAutoVoucherFromLine() {
    final raw = _autoLineCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter bank entry: type,channel,amount,party,reference,narration',
          ),
        ),
      );
      return;
    }

    final parts = raw.split(',').map((e) => e.trim()).toList(growable: false);
    if (parts.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid format. Example: receipt,upi,3500,ABC Traders,UTR123,Advance received',
          ),
        ),
      );
      return;
    }

    final type = _parseType(parts[0]);
    final channel = _parseChannel(parts[1]);
    final amount = double.tryParse(parts[2]) ?? 0;
    final party = parts[3].trim();

    if (type == null || channel == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to parse type/channel/amount.')),
      );
      return;
    }

    if ((type == VoucherType.creditNote || type == VoucherType.debitNote) &&
        party.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer name is required for credit/debit notes.'),
        ),
      );
      return;
    }

    if (type == VoucherType.creditNote || type == VoucherType.debitNote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use manual entry for credit/debit notes with original invoice number/date.',
          ),
        ),
      );
      return;
    }

    final voucher = BankVoucher(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      channel: channel,
      amount: amount,
      party: party,
      originalInvoiceNumber: '',
      originalInvoiceDate: null,
      returnReason: '',
      reference: parts[4],
      narration: parts.sublist(5).join(', '),
      createdAt: DateTime.now(),
      autoCreated: true,
    );

    setState(() {
      _vouchers.insert(0, voucher);
      _autoLineCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Autoentry created ${voucher.type.displayName} (${voucher.channel.displayName}).',
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _analyzeUploadedStatement() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _statementStatus =
            'Could not read the selected statement file. Try CSV or TXT export.';
        _statementSuggestions = <BankStatementSuggestion>[];
      });
      return;
    }

    final text = utf8.decode(bytes, allowMalformed: true);
    final rules = await _statementService.loadRecurringRules();
    final analysis = _statementAnalyzer.analyze(
      statementText: text,
      customers: context.read<CustomerService>().customers,
      vendors: context.read<VendorService>().vendors,
      recurringRules: rules,
    );

    final entry = await _statementService.saveHistoryEntry(
      sourceName: file.name.trim().isEmpty ? 'Statement' : file.name.trim(),
      format: analysis.detectedFormat,
      suggestions: analysis.suggestions,
    );

    setState(() {
      _statementSuggestions = analysis.suggestions;
      _statementStatus = analysis.hasSuggestions
          ? 'Analyzed ${analysis.suggestions.length} transaction(s) from ${analysis.detectedFormat.label}. ${analysis.recurringCount} recurring pattern(s) detected.'
          : 'No transactions could be read from the uploaded statement.';
    });

    if (!mounted) return;
    await _openStatementHistory(initialEntryId: entry.id);
  }

  Future<void> _openStatementHistory({String? initialEntryId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankStatementHistoryScreen(
          service: _statementService,
          initialEntryId: initialEntryId,
          onPostSuggestions: _postSuggestionsFromReview,
        ),
      ),
    );
  }

  void _applySuggestion(BankStatementSuggestion suggestion) {
    _autoLineCtrl.text = suggestion.toAutoEntryLine();
    _createAutoVoucherFromLine();
  }

  Future<void> _applyAllSuggestions() async {
    if (_statementSuggestions.isEmpty) return;
    await _statementService.upsertRecurringRulesFromSuggestions(
      _statementSuggestions,
    );
    await _postSuggestionsFromReview(_statementSuggestions);
    if (!mounted) return;
    setState(() {
      _statementSuggestions = <BankStatementSuggestion>[];
      _autoLineCtrl.clear();
    });
  }

  Future<void> _postSuggestionsFromReview(
    List<BankStatementSuggestion> suggestions,
  ) async {
    final vouchers = suggestions
        .map(
          (suggestion) => BankVoucher(
            id:
                DateTime.now().microsecondsSinceEpoch.toString() +
                suggestion.reference +
                suggestion.patternKey,
            type: suggestion.isCredit
                ? VoucherType.receipt
                : VoucherType.payment,
            channel: PaymentChannel.neftRtgsImps,
            amount: suggestion.amount,
            party: suggestion.suggestedLedger,
            originalInvoiceNumber: '',
            originalInvoiceDate: null,
            returnReason: '',
            reference: suggestion.reference,
            narration: suggestion.narration,
            createdAt: suggestion.date ?? DateTime.now(),
            autoCreated: true,
          ),
        )
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _vouchers.insertAll(0, vouchers);
      _statementStatus =
          'Created ${suggestions.length} voucher(s) from reviewed bank statement.';
    });
  }

  VoucherType? _parseType(String raw) {
    final key = raw.toLowerCase().replaceAll(' ', '');
    switch (key) {
      case 'payment':
        return VoucherType.payment;
      case 'receipt':
        return VoucherType.receipt;
      case 'creditnote':
      case 'credit':
        return VoucherType.creditNote;
      case 'debitnote':
      case 'debit':
        return VoucherType.debitNote;
      default:
        return null;
    }
  }

  PaymentChannel? _parseChannel(String raw) {
    final key = raw.toLowerCase().replaceAll(' ', '');
    switch (key) {
      case 'cash':
        return PaymentChannel.cash;
      case 'upi':
        return PaymentChannel.upi;
      case 'neft':
      case 'rtgs':
      case 'imps':
      case 'neftrtgsimps':
      case 'bank':
        return PaymentChannel.neftRtgsImps;
      case 'cheque':
      case 'check':
        return PaymentChannel.cheque;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.bankingEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voucher Entry'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_outline,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Banking Module Pending',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This module is currently on hold and will be developed as per customer confirmation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Voucher Entry'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Current Balance'),
              subtitle: const Text(
                'Based on payment, receipt, sales return, and purchase return vouchers',
              ),
              trailing: Text(
                'Rs. ${_balance.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<EntryMode>(
            segments: const [
              ButtonSegment(
                value: EntryMode.manual,
                label: Text('Manual Update'),
              ),
              ButtonSegment(
                value: EntryMode.auto,
                label: Text('Autoentry System'),
              ),
            ],
            selected: {_entryMode},
            onSelectionChanged: (values) =>
                setState(() => _entryMode = values.first),
          ),
          const SizedBox(height: 12),
          if (_entryMode == EntryMode.manual) _manualEntryCard(),
          if (_entryMode == EntryMode.auto) _autoEntryCard(),
          const SizedBox(height: 16),
          const Text(
            'Voucher History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_vouchers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No vouchers yet. Create manual or auto entries.'),
              ),
            )
          else
            ..._vouchers.map(_voucherTile),
        ],
      ),
    );
  }

  Widget _manualEntryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SearchableDropdownFormField<VoucherType>(
                value: _voucherType,
                decoration: const InputDecoration(
                  labelText: 'Voucher Type',
                  border: OutlineInputBorder(),
                ),
                items: VoucherType.values,
                itemLabelBuilder: (e) => e.displayName,
                onChanged: (v) {
                  if (v == null) return;
                  _onVoucherTypeChanged(v);
                },
              ),
              const SizedBox(height: 10),
              SearchableDropdownFormField<PaymentChannel>(
                value: _channel,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(),
                ),
                items: PaymentChannel.values,
                itemLabelBuilder: (e) => e.displayName,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _channel = v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim()) ?? 0;
                  if (amount <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              if (_usesLedgerPicker) ...[
                _ledgerSearchWidget(),
              ] else ...[
                TextFormField(
                  controller: _partyCtrl,
                  decoration: InputDecoration(
                    labelText: _partyFieldLabel,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? _partyRequiredMessage
                      : null,
                ),
              ],
              if (_requiresOriginalInvoice) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _originalInvoiceNoCtrl,
                  decoration: InputDecoration(
                    labelText: _originalInvoiceLabel,
                    hintText: _originalInvoiceHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? '$_originalInvoiceLabel is required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _originalInvoiceDateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: _originalInvoiceDateLabel,
                    hintText: 'Select original invoice date',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(DateTime.now().year - 5),
                          lastDate: DateTime.now(),
                        );
                        if (picked == null) return;
                        setState(() {
                          _originalInvoiceDateCtrl.text = picked
                              .toIso8601String()
                              .split('T')
                              .first;
                        });
                      },
                    ),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Original invoice date is required'
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  _voucherType == VoucherType.creditNote
                      ? 'Sales return voucher requires the original sales invoice number, invoice date, customer ledger, and return reason.'
                      : 'Purchase return voucher requires the original purchase invoice number, invoice date, supplier ledger, and return reason.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 10),
              if (_requiresCustomerName)
                TextFormField(
                  controller: _returnReasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _returnReasonLabel,
                    hintText: 'Goods return / sales return reason',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? '$_returnReasonLabel is required'
                      : null,
                ),
              if (_requiresCustomerName) const SizedBox(height: 10),
              TextFormField(
                controller: _referenceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reference (UTR/Cheque/Txn ID)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _narrationCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Narration',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createManualVoucher,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Create Voucher'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ledgerSearchWidget() {
    final ledgers = _filteredLedgers();
    if (_ledgerHighlightedIndex >= ledgers.length && ledgers.isNotEmpty) {
      _ledgerHighlightedIndex = ledgers.length - 1;
    }

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowDown): _LedgerSelectIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _LedgerSelectIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _LedgerSubmitIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _LedgerSubmitIntent(),
        SingleActivator(LogicalKeyboardKey.tab): _LedgerSubmitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _LedgerSelectIntent: CallbackAction<_LedgerSelectIntent>(
            onInvoke: (intent) {
              _moveLedgerSelection(intent.offset);
              return null;
            },
          ),
          _LedgerSubmitIntent: CallbackAction<_LedgerSubmitIntent>(
            onInvoke: (intent) {
              _submitLedgerSelection();
              return null;
            },
          ),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _ledgerSearchCtrl,
              focusNode: _ledgerSearchFocusNode,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: _partyFieldLabel,
                hintText: 'Search existing ledger...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _partyCtrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _partyCtrl.clear();
                            _ledgerSearchCtrl.clear();
                            _ledgerSearchQuery = '';
                            _ledgerHighlightedIndex = 0;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _ledgerSearchQuery = value;
                  _ledgerHighlightedIndex = 0;
                });
              },
              onFieldSubmitted: (_) => _submitLedgerSelection(),
              validator: (value) {
                if (_partyCtrl.text.trim().isEmpty) {
                  return _partyRequiredMessage;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Card(
                elevation: 2,
                child: ledgers.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No existing ledgers found.'),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: ledgers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final ledger = ledgers[index];
                          final selected = index == _ledgerHighlightedIndex;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            selectedTileColor: const Color(0xFFE8F1FB),
                            leading: Icon(
                              _voucherType == VoucherType.payment
                                  ? Icons.storefront_outlined
                                  : Icons.person_outline,
                              size: 18,
                              color: selected
                                  ? const Color(0xFF1565C0)
                                  : Colors.grey.shade700,
                            ),
                            title: Text(ledger),
                            onTap: () => setState(() {
                              _syncLedgerSelection(ledger);
                            }),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _voucherType == VoucherType.payment ||
                      _voucherType == VoucherType.receipt
                  ? 'Use existing debtor/creditor ledgers. Arrow keys move, Enter/Tab select.'
                  : _voucherType == VoucherType.debitNote
                  ? 'Use existing vendor ledger list. Arrow keys move, Enter/Tab select.'
                  : 'Use existing customer ledger list. Arrow keys move, Enter/Tab select.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _autoEntryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auto entry by bank statement/UPI/NEFT/RTGS/IMPS/Cheque',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _analyzeUploadedStatement,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Bank Statement'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _statementSuggestions.isEmpty
                        ? null
                        : _applyAllSuggestions,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('Create All Suggested'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openStatementHistory,
                icon: const Icon(Icons.history_outlined),
                label: const Text('View Statement History'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statementStatus,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (_statementSuggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _statementSuggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = _statementSuggestions[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        suggestion.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Suggested Ledger: ${suggestion.suggestedLedger} • ${suggestion.category.label}',
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Chip(
                                label: Text(
                                  suggestion.isCredit ? 'Receipt' : 'Payment',
                                ),
                              ),
                              if (suggestion.isRecurring)
                                Chip(label: Text(suggestion.recurringHint)),
                              if (suggestion.reference.trim().isNotEmpty)
                                Chip(
                                  label: Text('Ref: ${suggestion.reference}'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${suggestion.isCredit ? '+' : '-'}Rs. ${suggestion.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: suggestion.isCredit
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _applySuggestion(suggestion),
                            child: const Text(
                              'Create',
                              style: TextStyle(
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _autoLineCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Autoentry line',
                hintText: _requiresCustomerName
                    ? 'creditnote,upi,3500,ABC Traders,Ref123,Customer return'
                    : 'receipt,upi,3500,ABC Traders,UTR123,Advance received',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Format: type,channel,amount,party,reference,narration',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createAutoVoucherFromLine,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Run Autoentry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _voucherTile(BankVoucher voucher) {
    final isPositive =
        voucher.type == VoucherType.receipt ||
        voucher.type == VoucherType.creditNote;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isPositive
              ? Icons.arrow_downward_outlined
              : Icons.arrow_upward_outlined,
          color: isPositive ? Colors.green : Colors.red,
        ),
        title: Text(
          '${voucher.type.displayName} • ${voucher.channel.displayName}',
        ),
        subtitle: Text(
          '${voucher.party}${voucher.originalInvoiceNumber.isNotEmpty ? '\nOrig Inv: ${voucher.originalInvoiceNumber} / ${voucher.originalInvoiceDate?.toIso8601String().split('T').first ?? '-'}' : ''}${voucher.returnReason.isNotEmpty ? '\nReason: ${voucher.returnReason}' : ''}\nRef: ${voucher.reference.isEmpty ? '-' : voucher.reference}${voucher.autoCreated ? ' • Auto' : ' • Manual'}',
        ),
        isThreeLine: true,
        trailing: Text(
          '${isPositive ? '+' : '-'}Rs. ${voucher.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ),
    );
  }
}
