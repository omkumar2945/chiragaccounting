import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/vouchers/presentation/models/voucher_entry_type.dart';

class VoucherEntryFormScreen extends StatefulWidget {
  const VoucherEntryFormScreen({
    super.key,
    required this.type,
    this.prefillParsedData,
    this.sourceFileName,
    this.autoEntryMode = false,
  });

  final VoucherEntryType type;
  final ParsedInvoiceData? prefillParsedData;
  final String? sourceFileName;
  final bool autoEntryMode;

  @override
  State<VoucherEntryFormScreen> createState() => _VoucherEntryFormScreenState();
}

class _VoucherEntryFormScreenState extends State<VoucherEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  DateTime _date = DateTime.now();
  String _mode = 'Cash';
  String _paymentStatus = 'Pending';
  bool _gstApplicable = false;
  bool _isSaving = false;
  final bool _canDelete = false;

  final List<_LedgerRow> _ledgerRows = <_LedgerRow>[_LedgerRow()];
  final List<_ItemRow> _itemRows = <_ItemRow>[_ItemRow()];
  final List<String> _attachments = <String>[];

  static const List<String> _paymentModes = <String>[
    'Cash',
    'Bank',
    'UPI',
    'Cheque',
  ];

  static const List<String> _paymentStatuses = <String>[
    'Pending',
    'Partially Paid',
    'Paid',
  ];

  @override
  void initState() {
    super.initState();
    _setDefaultControllers();
    _applyOcrPrefill();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Text(type.title),
        actions: [
          IconButton(
            tooltip: 'Audit Trail',
            icon: const Icon(Icons.history),
            onPressed: () =>
                _showSnack('Audit Trail opened for ${type.title}.'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1150) {
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildPanel(
                            title: 'Voucher Details',
                            expandBody: true,
                            child: _buildVoucherDetailsSection(),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: _buildPanel(
                            title: 'Item / Ledger Grid',
                            expandBody: true,
                            child: _buildGridSection(),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: _buildPanel(
                            title: 'AI Preview / Files',
                            expandBody: true,
                            child: _buildAiPreviewSection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBottomActionBar(),
                ],
              );
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildPanel(
                          title: 'Voucher Details',
                          child: _buildVoucherDetailsSection(),
                        ),
                        _buildPanel(
                          title: 'Item / Ledger Grid',
                          child: _buildGridSection(),
                        ),
                        _buildPanel(
                          title: 'AI Preview / Files',
                          child: _buildAiPreviewSection(),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildBottomActionBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required Widget child,
    bool expandBody = false,
  }) {
    final body = expandBody
        ? Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          )
        : Padding(padding: const EdgeInsets.all(12), child: child);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF4FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1A237E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }

  Widget _buildVoucherDetailsSection() {
    final title = widget.type.title;
    return Column(
      children: [
        _readOnlyField('Voucher Type', title),
        const SizedBox(height: 10),
        _textField('Voucher No', 'voucherNo', readOnly: true),
        const SizedBox(height: 10),
        _datePickerField(),
        const SizedBox(height: 10),
        ..._buildTypeSpecificDetailFields(),
        const SizedBox(height: 10),
        _uploadButton('Upload Image/PDF'),
        const SizedBox(height: 8),
        _featureChips(),
      ],
    );
  }

  List<Widget> _buildTypeSpecificDetailFields() {
    switch (widget.type) {
      case VoucherEntryType.payment:
        return [
          _radioGroup('Payment Type', _paymentModes, _mode),
          const SizedBox(height: 10),
          ..._buildCommonPartyAmountFields(
            partyLabel: 'Paid To (Search Ledger)',
            referenceLabel: 'Reference No',
            includeChequeAndBank: true,
          ),
        ];
      case VoucherEntryType.receipt:
        return [
          _radioGroup('Receipt Mode', _paymentModes, _mode),
          const SizedBox(height: 10),
          ..._buildCommonPartyAmountFields(
            partyLabel: 'Received From (Search Ledger)',
            referenceLabel: 'Reference',
            includeChequeAndBank: true,
          ),
        ];
      case VoucherEntryType.contra:
        return [
          _textField('Transfer From (Cash/Bank)', 'transferFrom'),
          const SizedBox(height: 10),
          _textField('Transfer To (Cash/Bank)', 'transferTo'),
          const SizedBox(height: 10),
          _amountField(),
          const SizedBox(height: 10),
          _textField('Reference', 'reference'),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.journal:
        return [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('GST Applicable'),
            value: _gstApplicable,
            onChanged: (v) => setState(() => _gstApplicable = v),
          ),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.purchase:
        return [
          _textField('Supplier', 'supplier'),
          const SizedBox(height: 10),
          _textField('Invoice No', 'invoiceNo'),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.sales:
        return [
          _textField('Customer', 'customer'),
          const SizedBox(height: 10),
          _textField('Invoice No', 'invoiceNo'),
          const SizedBox(height: 10),
          _textField('Round Off', 'roundOff'),
          const SizedBox(height: 10),
          _textField(
            'Grand Total',
            'grandTotal',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _paymentStatus,
            items: _paymentStatuses
                .map(
                  (status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _paymentStatus = value);
            },
            decoration: const InputDecoration(
              labelText: 'Payment Status',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case VoucherEntryType.debitNote:
        return [
          _textField('Supplier / Customer', 'party'),
          const SizedBox(height: 10),
          _textField('Debit Note No', 'debitNo'),
          const SizedBox(height: 10),
          _textField('Reason', 'reason'),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.creditNote:
        return [
          _textField('Customer', 'customer'),
          const SizedBox(height: 10),
          _textField('Credit Note No', 'creditNo'),
          const SizedBox(height: 10),
          _textField('Reason', 'reason'),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.expense:
        return [
          _textField('Expense Head', 'expenseHead'),
          const SizedBox(height: 10),
          _textField('Ledger', 'ledger'),
          const SizedBox(height: 10),
          _amountField(),
          const SizedBox(height: 10),
          _textField('GST', 'gst'),
          const SizedBox(height: 10),
          _radioGroup('Payment Mode', _paymentModes, _mode),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.income:
        return [
          _textField('Income Head', 'incomeHead'),
          const SizedBox(height: 10),
          _textField('Ledger', 'ledger'),
          const SizedBox(height: 10),
          _amountField(),
          const SizedBox(height: 10),
          _textField('GST', 'gst'),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.bankTransfer:
        return [
          _textField('From Bank', 'fromBank'),
          const SizedBox(height: 10),
          _textField('To Bank', 'toBank'),
          const SizedBox(height: 10),
          _amountField(),
          const SizedBox(height: 10),
          _textField('Transaction No', 'transactionNo'),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
      case VoucherEntryType.cashTransfer:
        return [
          _textField('Cash Account', 'cashAccount'),
          const SizedBox(height: 10),
          _textField('Destination', 'destination'),
          const SizedBox(height: 10),
          _amountField(),
          const SizedBox(height: 10),
          _textField('Narration', 'narration', maxLines: 3),
        ];
    }
  }

  List<Widget> _buildCommonPartyAmountFields({
    required String partyLabel,
    required String referenceLabel,
    required bool includeChequeAndBank,
  }) {
    return [
      _textField(partyLabel, 'party'),
      const SizedBox(height: 10),
      _amountField(),
      const SizedBox(height: 10),
      _textField(referenceLabel, 'reference'),
      const SizedBox(height: 10),
      if (includeChequeAndBank) ...[
        _textField('Cheque No', 'chequeNo'),
        const SizedBox(height: 10),
        _textField('Bank', 'bank'),
        const SizedBox(height: 10),
      ],
      _textField('Narration', 'narration', maxLines: 3),
    ];
  }

  Widget _buildGridSection() {
    if (widget.type == VoucherEntryType.journal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._ledgerRows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return _journalRowCard(index, row);
          }),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _ledgerRows.add(_LedgerRow())),
            icon: const Icon(Icons.add),
            label: const Text('Add Another Row'),
          ),
        ],
      );
    }

    if (_usesItemRows()) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._itemRows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return _itemRowCard(index, row, widget.type);
          }),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _itemRows.add(_ItemRow())),
            icon: const Icon(Icons.add),
            label: const Text('Add Item Row'),
          ),
        ],
      );
    }

    return const Text(
      'No grid rows required for this voucher type. Use narration and attachments for supporting details.',
      style: TextStyle(color: Colors.black54),
    );
  }

  Widget _buildAiPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.autoEntryMode) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: const Text(
              'OCR auto-filled this draft. Review all values before saving.',
              style: TextStyle(
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _miniAction('AI OCR', Icons.auto_awesome, () {
              _showSnack(
                'AI OCR started. Suggested values prepared for review.',
              );
            }),
            _miniAction('Search Ledger', Icons.search, () {
              _showSnack('Ledger search opened.');
            }),
            _miniAction('Create Ledger', Icons.add_card, () {
              _showSnack('Quick ledger creation opened.');
            }),
            _miniAction('Attach Doc', Icons.attach_file, _pickAttachment),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'OCR Confidence',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: 0.86,
          color: const Color(0xFF1565C0),
          backgroundColor: Colors.grey.shade300,
        ),
        const SizedBox(height: 14),
        const Text(
          'AI Suggestions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Party Name, Amount, Date, GST, and Reference are auto-detected for review.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        const Text(
          'Uploaded Files',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_attachments.isEmpty)
          const Text(
            'No files attached yet.',
            style: TextStyle(color: Colors.black54),
          ),
        ..._attachments.map(
          (name) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined, size: 18),
            title: Text(name, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Validation Alerts',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'No validation errors found.',
          style: TextStyle(color: Color(0xFF2E7D32)),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDDE5F2))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () =>
                _showSnack('Draft saved for ${widget.type.title}.'),
            child: const Text('Save Draft'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveVoucher,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            child: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showSnack('Print preview opened.'),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showSnack('Share PDF prepared.'),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showSnack('Voucher sent by email.'),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showSnack('Voucher sent on WhatsApp.'),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              if (value == 'edit') _showSnack('Edit mode enabled.');
              if (value == 'delete') {
                if (_canDelete) {
                  _showSnack('Voucher deleted.');
                } else {
                  _showSnack('Delete blocked: permission required.');
                }
              }
              if (value == 'audit') {
                _showSnack('Audit Trail opened for ${widget.type.title}.');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete (Permission-Based)'),
              ),
              PopupMenuItem(value: 'audit', child: Text('Audit Trail')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('More'),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePickerField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_month_outlined),
        ),
        child: Text(DateFormat('dd MMM yyyy').format(_date)),
      ),
    );
  }

  Widget _amountField() {
    return _textField(
      'Amount',
      'amount',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixText: '₹ ',
    );
  }

  Widget _textField(
    String label,
    String key, {
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return TextFormField(
      controller: _controllers[key],
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if (!readOnly && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: prefixText,
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      child: Text(value),
    );
  }

  Widget _radioGroup(String label, List<String> values, String currentValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          children: values
              .map(
                (value) => ChoiceChip(
                  label: Text(value),
                  selected: currentValue == value,
                  onSelected: (_) => setState(() => _mode = value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _featureChips() {
    final chips = <String>[
      'Upload Image/PDF',
      'AI OCR',
      'AI Auto Fill',
      'Search Ledger',
      'Create Ledger',
      'Attach Document',
      'Save Draft',
      'Save',
      'Print',
      'Share PDF',
      'Email',
      'WhatsApp',
      'Edit',
      'Delete (Permission)',
      'Audit Trail',
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips
          .map(
            (chip) => Chip(
              label: Text(chip, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _uploadButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _pickAttachment,
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(label),
      ),
    );
  }

  Widget _miniAction(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _journalRowCard(int index, _LedgerRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Row ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_ledgerRows.length > 1)
                  IconButton(
                    onPressed: () =>
                        setState(() => _ledgerRows.removeAt(index)),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.debitLedger,
              decoration: const InputDecoration(
                labelText: 'Debit Ledger',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => row.debitLedger = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.creditLedger,
              decoration: const InputDecoration(
                labelText: 'Credit Ledger',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => row.creditLedger = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => row.amount = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRowCard(int index, _ItemRow row, VoucherEntryType type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_itemRows.length > 1)
                  IconButton(
                    onPressed: () => setState(() => _itemRows.removeAt(index)),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: row.name,
              decoration: InputDecoration(
                labelText: _itemNameLabel(type),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => row.name = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row.qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => row.qty = v,
                  ),
                ),
                if (_needsUnitColumn(type)) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: row.unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => row.unit = v,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _usesAmountColumn(type)
                        ? row.amount
                        : row.rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _usesAmountColumn(type) ? 'Amount' : 'Rate',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (_usesAmountColumn(type)) {
                        row.amount = v;
                      } else {
                        row.rate = v;
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_needsDiscountColumn(type)) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: row.discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Discount',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => row.discount = v,
              ),
            ],
            if (_needsHsnColumn(type)) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: row.hsn,
                decoration: const InputDecoration(
                  labelText: 'HSN',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => row.hsn = v,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row.gst,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'GST %',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => row.gst = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: row.total,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => row.total = v,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _itemNameLabel(VoucherEntryType type) {
    if (type == VoucherEntryType.sales || type == VoucherEntryType.purchase) {
      return 'Product';
    }
    return 'Item';
  }

  bool _needsUnitColumn(VoucherEntryType type) {
    return type == VoucherEntryType.sales;
  }

  bool _needsDiscountColumn(VoucherEntryType type) {
    return type == VoucherEntryType.sales;
  }

  bool _needsHsnColumn(VoucherEntryType type) {
    return type == VoucherEntryType.purchase;
  }

  bool _usesAmountColumn(VoucherEntryType type) {
    return type == VoucherEntryType.debitNote ||
        type == VoucherEntryType.creditNote;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'txt'],
    );
    if (result == null) return;
    setState(() {
      _attachments.addAll(
        result.files.map((f) => f.name).where((name) => name.trim().isNotEmpty),
      );
    });
    _showSnack('${result.files.length} file(s) attached.');
  }

  Future<void> _saveVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isSaving = false);
    _showSnack('${widget.type.title} saved successfully.');
  }

  bool _usesItemRows() {
    return widget.type == VoucherEntryType.sales ||
        widget.type == VoucherEntryType.purchase ||
        widget.type == VoucherEntryType.debitNote ||
        widget.type == VoucherEntryType.creditNote;
  }

  void _setDefaultControllers() {
    const keys = <String>[
      'voucherNo',
      'party',
      'amount',
      'reference',
      'chequeNo',
      'bank',
      'narration',
      'transferFrom',
      'transferTo',
      'supplier',
      'invoiceNo',
      'hsn',
      'customer',
      'roundOff',
      'grandTotal',
      'debitNo',
      'creditNo',
      'reason',
      'expenseHead',
      'ledger',
      'gst',
      'incomeHead',
      'fromBank',
      'toBank',
      'transactionNo',
      'cashAccount',
      'destination',
    ];

    for (final key in keys) {
      _controllers[key] = TextEditingController();
    }
    _controllers['voucherNo']!.text = 'Auto';
  }

  void _applyOcrPrefill() {
    final data = widget.prefillParsedData;
    if (data == null) return;

    _controllers['party']!.text = data.partyName;
    _controllers['amount']!.text = data.totalAmount > 0
        ? data.totalAmount.toStringAsFixed(2)
        : '';
    _controllers['reference']!.text = data.billNumber;
    _controllers['narration']!.text = data.billNumber.isEmpty
        ? 'OCR detected ${widget.type.title.toLowerCase()}.'
        : 'Against document ${data.billNumber} detected by OCR.';

    final parsedDate = DateTime.tryParse(data.billDate);
    if (parsedDate != null) _date = parsedDate;

    final sourceFileName = widget.sourceFileName?.trim() ?? '';
    if (sourceFileName.isNotEmpty) _attachments.add(sourceFileName);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LedgerRow {
  _LedgerRow();

  String debitLedger = '';
  String creditLedger = '';
  String amount = '';
}

class _ItemRow {
  _ItemRow();

  String name = '';
  String qty = '';
  String unit = '';
  String rate = '';
  String discount = '';
  String hsn = '';
  String amount = '';
  String gst = '';
  String total = '';
}
