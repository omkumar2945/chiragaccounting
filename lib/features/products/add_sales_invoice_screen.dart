import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/features/customers/models/customer.dart';
import 'package:chirag_accounting/features/sales/presentation/widgets/product_selector.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/sales/models/sales_item.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class _MoveSelectionIntent extends Intent {
  const _MoveSelectionIntent(this.offset);

  final int offset;
}

class _SubmitSelectionIntent extends Intent {
  const _SubmitSelectionIntent();
}

const List<String> _kPaymentTerms = [
  'Cash',
  'Immediate / Due on Receipt',
  'COD (Cash on Delivery)',
  'Advance Payment',
  '50% Advance',
  'Net 7',
  'Net 10',
  'Net 15',
  'Net 30',
  'Net 45',
  'Net 60',
  'Net 90',
  '2/10 Net 30',
  '1/15 Net 30',
  'End of Month (EOM)',
  '15th of Following Month',
  '30th of Following Month',
  '21 MFI',
  'Letter of Credit (LC)',
  'Bank Transfer / NEFT',
  'RTGS',
  'UPI',
  'Cheque',
  'Post-Dated Cheque',
];

const List<String> _kStates = [
  'Andaman and Nicobar Islands',
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chandigarh',
  'Chhattisgarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jammu and Kashmir',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Ladakh',
  'Lakshadweep',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Puducherry',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
];

const List<String> _kTransportModes = ['Road', 'Rail', 'Air', 'Ship'];
const List<String> _kVehicleTypes = ['Regular', 'Over Dimensional Cargo (ODC)'];

class AddSalesInvoiceScreen extends StatefulWidget {
  final dynamic prefillParsedData;
  final dynamic prefillAnalysis;
  final bool autoEntryMode;
  final SalesInvoiceType invoiceType;

  const AddSalesInvoiceScreen({
    super.key,
    this.prefillParsedData,
    this.prefillAnalysis,
    this.autoEntryMode = false,
    this.invoiceType = SalesInvoiceType.sales,
  });
  @override
  State<AddSalesInvoiceScreen> createState() => _AddSalesInvoiceScreenState();
}

class _AddSalesInvoiceScreenState extends State<AddSalesInvoiceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<ProductRow> _products = [];
  String _typedCustomerName = '';

  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _invoiceDateCtrl;
  late TextEditingController _dueDateCtrl;
  String _placeOfSupply = 'Karnataka';
  final InvoiceStatus _selectedStatus = InvoiceStatus.draft;

  String _paymentTerms = '';
  bool _showPaymentTermsList = false;
  String _paymentTermsSearch = '';
  int _paymentTermsHighlightedIndex = 0;
  final TextEditingController _paymentTermsSearchCtrl = TextEditingController();
  late TextEditingController _poNumberCtrl;
  late TextEditingController _poDateCtrl;
  late TextEditingController _projectNameCtrl;
  late TextEditingController _refNumberCtrl;

  Customer? _selectedCustomer;
  late TextEditingController _mobileCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _billingAddressCtrl;
  late TextEditingController _shippingAddressCtrl;

  bool _showTransport = false;
  String _transportMode = '';
  late TextEditingController _transporterNameCtrl;
  late TextEditingController _transporterGstinCtrl;
  late TextEditingController _transportDocNoCtrl;
  late TextEditingController _transportDateCtrl;
  late TextEditingController _vehicleNumberCtrl;
  String _vehicleType = 'Regular';
  late TextEditingController _distanceKmCtrl;
  late TextEditingController _ewayBillNoCtrl;
  late TextEditingController _ewayBillDateCtrl;
  late TextEditingController _notesCtrl;

  bool get _isTaxInvoice => widget.invoiceType == SalesInvoiceType.tax;

  String get _screenLabel => _isTaxInvoice ? 'Tax Invoice' : 'Sales Invoice';

  @override
  void initState() {
    super.initState();
    final salesService = context.read<SalesService>();
    _invoiceNumberCtrl = TextEditingController(
      text: _isTaxInvoice
          ? salesService.generateNextTaxInvoiceNumber()
          : salesService.generateNextInvoiceNumber(),
    );
    _invoiceDateCtrl = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    _dueDateCtrl = TextEditingController();
    _poNumberCtrl = TextEditingController();
    _poDateCtrl = TextEditingController();
    _projectNameCtrl = TextEditingController();
    _refNumberCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _gstinCtrl = TextEditingController();
    _billingAddressCtrl = TextEditingController();
    _shippingAddressCtrl = TextEditingController();
    _transporterNameCtrl = TextEditingController();
    _transporterGstinCtrl = TextEditingController();
    _transportDocNoCtrl = TextEditingController();
    _transportDateCtrl = TextEditingController();
    _vehicleNumberCtrl = TextEditingController();
    _distanceKmCtrl = TextEditingController();
    _ewayBillNoCtrl = TextEditingController();
    _ewayBillDateCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _invoiceNumberCtrl,
      _invoiceDateCtrl,
      _dueDateCtrl,
      _poNumberCtrl,
      _poDateCtrl,
      _projectNameCtrl,
      _refNumberCtrl,
      _mobileCtrl,
      _gstinCtrl,
      _billingAddressCtrl,
      _shippingAddressCtrl,
      _transporterNameCtrl,
      _transporterGstinCtrl,
      _transportDocNoCtrl,
      _transportDateCtrl,
      _vehicleNumberCtrl,
      _distanceKmCtrl,
      _ewayBillNoCtrl,
      _ewayBillDateCtrl,
      _notesCtrl,
      _paymentTermsSearchCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillCustomer(Customer c) => setState(() {
    _selectedCustomer = c;
    _typedCustomerName = c.customerName;
    _mobileCtrl.text = c.mobileNumber;
    _gstinCtrl.text = c.gstNumber;
    _billingAddressCtrl.text = c.billingAddress;
    _shippingAddressCtrl.text = c.shippingAddress;
  });

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _sanitizeMobile(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _nextCustomerCode(CustomerService service) {
    return service.nextCustomerCode();
  }

  Customer? _findExistingCustomer(CustomerService service) {
    if (_selectedCustomer != null) {
      return _selectedCustomer;
    }

    final typedName = _normalize(_typedCustomerName);
    final gstin = _gstinCtrl.text.trim().toUpperCase();
    final mobile = _sanitizeMobile(_mobileCtrl.text);

    if (gstin.isNotEmpty) {
      for (final customer in service.customers) {
        if (customer.gstNumber.trim().toUpperCase() == gstin) {
          return customer;
        }
      }
    }

    if (mobile.isNotEmpty) {
      for (final customer in service.customers) {
        final customerMobile = _sanitizeMobile(customer.mobileNumber);
        final customerAltMobile = _sanitizeMobile(customer.alternateMobile);
        if (customerMobile == mobile || customerAltMobile == mobile) {
          return customer;
        }
      }
    }

    if (typedName.isNotEmpty) {
      for (final customer in service.customers) {
        if (_normalize(customer.customerName) == typedName ||
            _normalize(customer.companyName) == typedName) {
          return customer;
        }
      }
    }

    return null;
  }

  Customer? _resolveOrCreateCustomer(CustomerService service) {
    final existing = _findExistingCustomer(service);
    if (existing != null) {
      _fillCustomer(existing);
      return existing;
    }

    final customerName = _typedCustomerName.trim();
    if (customerName.isEmpty) {
      return null;
    }

    final customer = Customer(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      customerCode: _nextCustomerCode(service),
      customerName: customerName,
      companyName: customerName,
      mobileNumber: normalizeIndianMobile(_mobileCtrl.text),
      gstNumber: _gstinCtrl.text.trim().toUpperCase(),
      billingAddress: _billingAddressCtrl.text.trim(),
      shippingAddress: _shippingAddressCtrl.text.trim(),
      state: _placeOfSupply,
      isActive: true,
    );

    service.addCustomer(customer);
    _fillCustomer(customer);
    return customer;
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) ctrl.text = picked.toString().split(' ')[0];
  }

  Widget _buildStringOptionsView(
    BuildContext context,
    AutocompleteOnSelected<String> onSelected,
    Iterable<String> options,
  ) {
    final optionsList = options.toList(growable: false);
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: optionsList.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) => Builder(
              builder: (itemContext) {
                final isHighlighted =
                    AutocompleteHighlightedOption.of(itemContext) == index;
                if (isHighlighted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Scrollable.ensureVisible(
                      itemContext,
                      alignment: 0.5,
                      duration: Duration.zero,
                    );
                  });
                }

                return ListTile(
                  dense: true,
                  selected: isHighlighted,
                  tileColor: isHighlighted
                      ? Theme.of(itemContext).colorScheme.primaryContainer
                      : null,
                  title: Text(optionsList[index]),
                  onTap: () => onSelected(optionsList[index]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerOptionsView(
    BuildContext context,
    AutocompleteOnSelected<Customer> onSelected,
    Iterable<Customer> options,
  ) {
    final optionsList = options.toList(growable: false);
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: optionsList.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) => Builder(
              builder: (itemContext) {
                final customer = optionsList[index];
                final isHighlighted =
                    AutocompleteHighlightedOption.of(itemContext) == index;
                if (isHighlighted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Scrollable.ensureVisible(
                      itemContext,
                      alignment: 0.5,
                      duration: Duration.zero,
                    );
                  });
                }

                return ListTile(
                  dense: true,
                  selected: isHighlighted,
                  tileColor: isHighlighted
                      ? Theme.of(itemContext).colorScheme.primaryContainer
                      : null,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      customer.customerName.isNotEmpty
                          ? customer.customerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  title: Text(customer.customerName),
                  subtitle: Text(
                    '${customer.customerCode}  •  ${customer.mobileNumber}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: customer.gstNumber.isNotEmpty
                      ? Text(
                          customer.gstNumber,
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                  onTap: () => onSelected(customer),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _selectPaymentTerm(String value) {
    setState(() {
      _paymentTerms = value;
      _showPaymentTermsList = false;
      _paymentTermsSearch = '';
      _paymentTermsSearchCtrl.clear();
      _paymentTermsHighlightedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add $_screenLabel'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Invoice Information'),
              const SizedBox(height: 12),
              _invoiceInfoCard(),
              const SizedBox(height: 20),
              _sectionTitle('Customer Details'),
              const SizedBox(height: 12),
              _customerCard(),
              const SizedBox(height: 20),
              _sectionTitle('Reference Details'),
              const SizedBox(height: 12),
              _referenceCard(),
              const SizedBox(height: 20),
              _transportHeader(),
              if (_showTransport) ...[
                const SizedBox(height: 12),
                _transportCard(),
              ],
              const SizedBox(height: 20),
              _sectionTitle('Products'),
              const SizedBox(height: 12),
              ProductSelector(
                initialRows: _products,
                placeOfSupply: _placeOfSupply,
                onProductsChanged: (rows) => setState(() => _products = rows),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Notes / Narration'),
              const SizedBox(height: 12),
              _buildCard(
                child: TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Narration',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saveInvoice,
                  icon: const Icon(Icons.save),
                  label: Text(
                    'Save $_screenLabel',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceInfoCard() => _buildCard(
    child: Column(
      children: [
        TextFormField(
          controller: _invoiceNumberCtrl,
          decoration: const InputDecoration(
            labelText: 'Invoice Number',
            prefixIcon: Icon(Icons.receipt_long),
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _invoiceDateCtrl,
                readOnly: true,
                onTap: () => _pickDate(_invoiceDateCtrl),
                decoration: const InputDecoration(
                  labelText: 'Invoice Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _dueDateCtrl,
                readOnly: true,
                onTap: () => _pickDate(_dueDateCtrl),
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _placeOfSupply),
          optionsBuilder: (v) {
            final q = v.text.trim().toLowerCase();
            return q.isEmpty
                ? _kStates
                : _kStates.where((s) => s.toLowerCase().contains(q));
          },
          onSelected: (s) => setState(() => _placeOfSupply = s),
          optionsViewBuilder: _buildStringOptionsView,
          fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) => TextFormField(
            controller: ctrl,
            focusNode: fn,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Place of Supply',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _placeOfSupply = v,
            onFieldSubmitted: (_) => onFieldSubmitted(),
          ),
        ),
      ],
    ),
  );

  Widget _customerCard() {
    final customers = context.watch<CustomerService>().customers;
    return _buildCard(
      child: Column(
        children: [
          Autocomplete<Customer>(
            displayStringForOption: (c) => c.customerName,
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return customers;
              return customers.where(
                (c) =>
                    c.customerName.toLowerCase().contains(q) ||
                    c.customerCode.toLowerCase().contains(q) ||
                    c.mobileNumber.contains(q) ||
                    c.gstNumber.toLowerCase().contains(q),
              );
            },
            onSelected: _fillCustomer,
            fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) => TextFormField(
              controller: ctrl,
              focusNode: fn,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Search Customer',
                prefixIcon: Icon(Icons.person_search),
                hintText:
                    'Type customer name (new/existing), code, mobile or GSTIN',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _typedCustomerName = value;
                  _selectedCustomer = null;
                });
              },
              onFieldSubmitted: (_) => onFieldSubmitted(),
              validator: (_) {
                if (_selectedCustomer != null) return null;
                if (_typedCustomerName.trim().isNotEmpty) return null;
                return 'Enter customer name or select existing customer';
              },
            ),
            optionsViewBuilder: _buildCustomerOptionsView,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _mobileCtrl,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _gstinCtrl,
            decoration: const InputDecoration(
              labelText: 'GSTIN',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _billingAddressCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Billing Address',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _shippingAddressCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Shipping Address',
              prefixIcon: Icon(Icons.local_shipping),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceCard() => _buildCard(
    child: Column(
      children: [
        _paymentTermsField(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _poNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'PO Number',
                  prefixIcon: Icon(Icons.article_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _poDateCtrl,
                readOnly: true,
                onTap: () => _pickDate(_poDateCtrl),
                decoration: const InputDecoration(
                  labelText: 'PO Date',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _projectNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            prefixIcon: Icon(Icons.folder_open),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _refNumberCtrl,
          decoration: const InputDecoration(
            labelText: 'Reference Number',
            prefixIcon: Icon(Icons.tag),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
  );

  Widget _paymentTermsField() {
    final filtered = _paymentTermsSearch.isEmpty
        ? _kPaymentTerms
        : _kPaymentTerms
              .where(
                (t) =>
                    t.toLowerCase().contains(_paymentTermsSearch.toLowerCase()),
              )
              .toList();

    if (filtered.isEmpty) {
      _paymentTermsHighlightedIndex = 0;
    } else if (_paymentTermsHighlightedIndex >= filtered.length) {
      _paymentTermsHighlightedIndex = filtered.length - 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () =>
              setState(() => _showPaymentTermsList = !_showPaymentTermsList),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Payment Terms',
              prefixIcon: const Icon(Icons.payment),
              border: const OutlineInputBorder(),
              suffixIcon: Icon(
                _showPaymentTermsList
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
            ),
            child: Text(
              _paymentTerms.isEmpty ? 'Select payment terms' : _paymentTerms,
              style: TextStyle(
                color: _paymentTerms.isEmpty ? Colors.black45 : Colors.black87,
              ),
            ),
          ),
        ),
        if (_showPaymentTermsList)
          Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.arrowDown):
                  _MoveSelectionIntent(1),
              SingleActivator(LogicalKeyboardKey.arrowUp): _MoveSelectionIntent(
                -1,
              ),
              SingleActivator(LogicalKeyboardKey.enter):
                  _SubmitSelectionIntent(),
              SingleActivator(LogicalKeyboardKey.numpadEnter):
                  _SubmitSelectionIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _MoveSelectionIntent: CallbackAction<_MoveSelectionIntent>(
                  onInvoke: (intent) {
                    if (filtered.isEmpty) {
                      return null;
                    }
                    setState(() {
                      final nextIndex =
                          _paymentTermsHighlightedIndex + intent.offset;
                      if (nextIndex < 0) {
                        _paymentTermsHighlightedIndex = 0;
                      } else if (nextIndex >= filtered.length) {
                        _paymentTermsHighlightedIndex = filtered.length - 1;
                      } else {
                        _paymentTermsHighlightedIndex = nextIndex;
                      }
                    });
                    return null;
                  },
                ),
                _SubmitSelectionIntent: CallbackAction<_SubmitSelectionIntent>(
                  onInvoke: (intent) {
                    if (filtered.isNotEmpty) {
                      _selectPaymentTerm(
                        filtered[_paymentTermsHighlightedIndex],
                      );
                    }
                    return null;
                  },
                ),
              },
              child: Card(
                margin: const EdgeInsets.only(top: 2),
                elevation: 6,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: _paymentTermsSearchCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search payment terms…',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (v) => setState(() {
                          _paymentTermsSearch = v;
                          _paymentTermsHighlightedIndex = 0;
                        }),
                        onSubmitted: (_) {
                          if (filtered.isNotEmpty) {
                            _selectPaymentTerm(
                              filtered[_paymentTermsHighlightedIndex],
                            );
                          }
                        },
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          selected: i == _paymentTermsHighlightedIndex,
                          tileColor: i == _paymentTermsHighlightedIndex
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          leading: Icon(
                            _paymentTerms == filtered[i]
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: Colors.blue,
                          ),
                          title: Text(filtered[i]),
                          onTap: () => _selectPaymentTerm(filtered[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _transportHeader() => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => setState(() => _showTransport = !_showTransport),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: Colors.blue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Transport & E-Way Bill Details',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
            ),
          ),
          Icon(
            _showTransport
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: Colors.blue,
          ),
        ],
      ),
    ),
  );

  Widget _transportCard() => _buildCard(
    child: Column(
      children: [
        SearchableDropdownFormField<String>(
          value: _transportMode.isEmpty ? null : _transportMode,
          decoration: const InputDecoration(
            labelText: 'Transport Mode',
            prefixIcon: Icon(Icons.route),
            border: OutlineInputBorder(),
          ),
          hintText: 'Select mode',
          items: _kTransportModes,
          itemLabelBuilder: (m) => m,
          onChanged: (v) => setState(() => _transportMode = v ?? ''),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _transporterNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Transporter Name',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _transporterGstinCtrl,
          decoration: const InputDecoration(
            labelText: 'Transporter GSTIN',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _transportDocNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'LR / GR / Doc No',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _transportDateCtrl,
                readOnly: true,
                onTap: () => _pickDate(_transportDateCtrl),
                decoration: const InputDecoration(
                  labelText: 'Transport Date',
                  prefixIcon: Icon(Icons.date_range),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _vehicleNumberCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableDropdownFormField<String>(
                value: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                items: _kVehicleTypes,
                itemLabelBuilder: (t) => t,
                onChanged: (v) => setState(() => _vehicleType = v ?? 'Regular'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _distanceKmCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Distance (km)',
            prefixIcon: Icon(Icons.social_distance),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(Icons.qr_code, size: 16, color: Colors.orange),
              SizedBox(width: 6),
              Text(
                'E-Way Bill',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ewayBillNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-Way Bill Number',
                  prefixIcon: Icon(Icons.qr_code_2),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _ewayBillDateCtrl,
                readOnly: true,
                onTap: () => _pickDate(_ewayBillDateCtrl),
                decoration: const InputDecoration(
                  labelText: 'E-Way Bill Date',
                  prefixIcon: Icon(Icons.event_note),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _saveInvoice() {
    if (!_formKey.currentState!.validate()) return;
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }
    final hasInvalid = _products.any(
      (p) =>
          (p.productName ?? '').trim().isEmpty ||
          p.quantity <= 0 ||
          p.rate <= 0,
    );
    if (hasInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Each line must have product, quantity and rate'),
        ),
      );
      return;
    }
    try {
      final customerService = context.read<CustomerService>();
      final existingCustomer = _findExistingCustomer(customerService);
      final resolvedCustomer =
          existingCustomer ?? _resolveOrCreateCustomer(customerService);
      if (resolvedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter customer name')),
        );
        return;
      }

      final items = _products
          .map(
            (p) => SalesItem(
              id: p.id,
              productName: p.productName ?? '',
              hsnCode: p.hsnCode ?? '',
              unit: p.unit ?? 'Pc',
              quantity: p.quantity,
              rate: p.rate,
              discount: p.discount,
              gstPercentage: p.gstPercentage,
            ),
          )
          .toList();

      final invoice = SalesInvoice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        invoiceType: widget.invoiceType,
        invoiceNumber: _invoiceNumberCtrl.text.trim(),
        invoiceDate: DateTime.parse(_invoiceDateCtrl.text),
        dueDate: DateTime.parse(_dueDateCtrl.text),
        customerName: resolvedCustomer.customerName,
        customerMobile: normalizeIndianMobile(_mobileCtrl.text),
        customerEmail: resolvedCustomer.email,
        gstNumber: _gstinCtrl.text.trim(),
        panNumber: resolvedCustomer.panNumber,
        billingAddress: _billingAddressCtrl.text.trim(),
        shippingAddress: _shippingAddressCtrl.text.trim(),
        placeOfSupply: _placeOfSupply,
        items: items,
        status: _selectedStatus,
        notes: _notesCtrl.text.trim(),
        paymentTerms: _paymentTerms,
        poNumber: _poNumberCtrl.text.trim(),
        poDate: _poDateCtrl.text.trim(),
        projectName: _projectNameCtrl.text.trim(),
        referenceNumber: _refNumberCtrl.text.trim(),
        transportMode: _transportMode,
        transporterName: _transporterNameCtrl.text.trim(),
        transporterGstin: _transporterGstinCtrl.text.trim(),
        transportDocNo: _transportDocNoCtrl.text.trim(),
        transportDate: _transportDateCtrl.text.trim(),
        vehicleNumber: _vehicleNumberCtrl.text.trim(),
        vehicleType: _vehicleType,
        distanceKm: _distanceKmCtrl.text.trim(),
        ewayBillNo: _ewayBillNoCtrl.text.trim(),
        ewayBillDate: _ewayBillDateCtrl.text.trim(),
      );

      context.read<SalesService>().addInvoice(invoice);
      final customerAction = existingCustomer != null
          ? 'Customer matched: ${resolvedCustomer.customerName}'
          : 'Customer created: ${resolvedCustomer.customerName}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_screenLabel ${invoice.invoiceNumber} saved successfully. $customerAction',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      final customerService = context.read<CustomerService>();
      final matched = _findExistingCustomer(customerService);
      if (matched != null) {
        _fillCustomer(matched);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duplicate prevented. Matched existing customer: ${matched.customerName}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer validation failed: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );

  Widget _buildCard({required Widget child}) => Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
