import 'dart:convert';

import 'package:chirag_accounting/core/constants/import_template_content.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';
import 'package:chirag_accounting/core/utils/file_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/features/compat/screens/client_data_exchange_screen_compat.dart';
import 'package:chirag_accounting/shared/widgets/address_location_form.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

import '../../models/customer.dart';
import '../../../services/customer_service.dart';
import '../../../services/gst_portal_lookup_service.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? initialCustomer;

  const AddCustomerScreen({super.key, this.initialCustomer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  static const List<String> _taxPreferences = <String>[
    'GST Registered',
    'GST Unregistered',
    'Composition Dealer',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GstPortalLookupService _gstPortalLookupService =
      GstPortalLookupService();

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _companyNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _altPhoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _panCtrl;
  late AddressFormController _billingAddress;
  late AddressFormController _shippingAddress;
  late TextEditingController _creditLimitCtrl;
  late TextEditingController _openingBalanceCtrl;

  bool _isActive = true;
  String? _selectedTaxPreference;
  bool _isFetchingGst = false;
  bool _didInitializeCustomerCode = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(
      text: widget.initialCustomer?.customerCode ?? '',
    );
    _nameCtrl = TextEditingController(
      text: widget.initialCustomer?.customerName ?? '',
    );
    _companyNameCtrl = TextEditingController(
      text: widget.initialCustomer?.companyName ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.initialCustomer?.mobileNumber ?? '',
    );
    _altPhoneCtrl = TextEditingController(
      text: widget.initialCustomer?.alternateMobile ?? '',
    );
    _emailCtrl = TextEditingController(
      text: widget.initialCustomer?.email ?? '',
    );
    _gstCtrl = TextEditingController(
      text: widget.initialCustomer?.gstNumber ?? '',
    );
    _panCtrl = TextEditingController(
      text: widget.initialCustomer?.panNumber ?? '',
    );
    final initial = widget.initialCustomer;
    _billingAddress = AddressFormController(
      initialValue:
          initial?.billingLocation ??
          StandardAddress.fromLegacy(
            address: initial?.billingAddress ?? '',
            state: initial?.state ?? '',
            city: initial?.city ?? '',
            pincode: initial?.pinCode ?? '',
            country: initial?.country ?? 'India',
          ),
    );
    _shippingAddress = AddressFormController(
      initialValue:
          initial?.shippingLocation ??
          StandardAddress.fromLegacy(
            address: initial?.shippingAddress ?? '',
            state: initial?.state ?? '',
            city: initial?.city ?? '',
            pincode: initial?.pinCode ?? '',
            country: initial?.country ?? 'India',
          ),
    );
    _creditLimitCtrl = TextEditingController(
      text: widget.initialCustomer?.creditLimit.toString() ?? '0',
    );
    _openingBalanceCtrl = TextEditingController(
      text: widget.initialCustomer?.openingBalance.toString() ?? '0',
    );
    final initialTaxPreference = widget.initialCustomer?.taxPreference.trim();
    _selectedTaxPreference = _taxPreferences.contains(initialTaxPreference)
        ? initialTaxPreference
        : _taxPreferences.first;
    _isActive = widget.initialCustomer?.isActive ?? true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeCustomerCode) return;
    _didInitializeCustomerCode = true;

    if (widget.initialCustomer == null && _codeCtrl.text.trim().isEmpty) {
      final customerService = context.read<CustomerService>();
      _codeCtrl.text = customerService.nextCustomerCode();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _companyNameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _billingAddress.dispose();
    _shippingAddress.dispose();
    _creditLimitCtrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  void _saveCustomer() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final addressValidation = validateAddressTaxIdentity(
      address: _billingAddress.value,
      gstin: _gstCtrl.text,
      pan: _panCtrl.text,
    );
    if (!addressValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(addressValidation.message)),
      );
      return;
    }

    final selectedTaxPreference = _selectedTaxPreference?.trim() ?? '';
    if (selectedTaxPreference.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select Tax Type.')));
      return;
    }

    try {
      final customerService = context.read<CustomerService>();
      final customerCode = widget.initialCustomer == null
          ? customerService.nextCustomerCode()
          : widget.initialCustomer!.customerCode.trim();

      final customer = Customer(
        id:
            widget.initialCustomer?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        customerCode: customerCode.isEmpty
            ? customerService.nextCustomerCode()
            : customerCode,
        customerName: _nameCtrl.text,
        companyName: _companyNameCtrl.text,
        mobileNumber: normalizeIndianMobile(_phoneCtrl.text),
        alternateMobile: normalizeIndianMobile(_altPhoneCtrl.text),
        email: _emailCtrl.text,
        taxPreference: selectedTaxPreference,
        gstNumber: _gstCtrl.text,
        panNumber: _panCtrl.text,
        billingAddress: _billingAddress.value.enteredAddress,
        shippingAddress: _shippingAddress.value.enteredAddress,
        state: _billingAddress.value.stateName,
        city: _billingAddress.value.cityName,
        pinCode: _billingAddress.value.pincode,
        country: _billingAddress.value.countryName,
        billingLocation: _billingAddress.value,
        shippingLocation: _shippingAddress.value,
        ledgerGroup: 'Sundry Debtors',
        creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
        openingBalance: double.tryParse(_openingBalanceCtrl.text) ?? 0,
        isActive: _isActive,
      );

      if (widget.initialCustomer != null) {
        customerService.updateCustomer(customer.id, customer);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer ${customer.customerName} updated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        customerService.addCustomer(customer);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer ${customer.customerName} added'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadCustomerTemplate({required bool mixedLedger}) async {
    final fileName = mixedLedger
        ? 'all_ledgers_mixed_import_template.csv'
        : 'customer_debtors_import_template.csv';

    final csv = mixedLedger
        ? ImportTemplateContent.allLedgersMixedCsv
        : ImportTemplateContent.customerDebtorsCsv;
    await _saveTemplateFile(fileName: fileName, content: csv);
  }

  Future<void> _downloadVendorTemplate() async {
    await _saveTemplateFile(
      fileName: 'vendor_creditors_import_template.csv',
      content: ImportTemplateContent.vendorCreditorsCsv,
    );
  }

  Future<void> _saveTemplateFile({
    required String fileName,
    required String content,
    String extension = 'csv',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));

    try {
      await downloadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: extension == 'csv' ? 'text/csv;charset=utf-8' : 'application/json',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Template downloaded: $fileName')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  void _openImportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientDataExchangeScreen(initialTabIndex: 1),
      ),
    );
  }

  Widget _buildImportAndTemplateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openImportScreen,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import Data'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Download Import Templates',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use these templates in Data Exchange -> Import Ledger for customer/vendor related data.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fill columns: ledger_name, ledger_group, mobile, email, gstin, pan, opening_balance',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _downloadCustomerTemplate(mixedLedger: false),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Customer Debtors CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _downloadCustomerTemplate(mixedLedger: true),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('All Ledgers Mixed CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: _downloadVendorTemplate,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Vendor Creditors CSV'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchFromGstPortal() async {
    final gstin = _gstCtrl.text.trim().toUpperCase();
    if (gstin.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter GSTIN first')));
      return;
    }

    setState(() {
      _isFetchingGst = true;
    });

    final result = await _gstPortalLookupService.fetchTaxpayerByGstin(gstin);

    if (!mounted) {
      return;
    }

    setState(() {
      _isFetchingGst = false;
    });

    final profile = result.profile;
    if (profile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    final preferredName = profile.tradeName.isNotEmpty
        ? profile.tradeName
        : profile.legalName;

    _gstCtrl.text = profile.gstin;

    if (_nameCtrl.text.trim().isEmpty) {
      _nameCtrl.text = preferredName;
    }
    if (_companyNameCtrl.text.trim().isEmpty) {
      _companyNameCtrl.text = profile.legalName.isNotEmpty
          ? profile.legalName
          : preferredName;
    }
    if (_panCtrl.text.trim().isEmpty && profile.gstin.length >= 12) {
      _panCtrl.text = profile.gstin.substring(2, 12);
    }
    if (_billingAddress.value.addressLine1.isEmpty) {
      _billingAddress.addressLine1.text = profile.address;
    }
    if (_shippingAddress.value.addressLine1.isEmpty) {
      _shippingAddress.addressLine1.text = profile.address;
    }
    if (_billingAddress.state.text.trim().isEmpty) {
      _billingAddress.state.text = profile.state;
    }
    if (_billingAddress.pincode.text.trim().isEmpty) {
      _billingAddress.pincode.text = profile.pincode;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _emailCtrl.text = profile.email;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _phoneCtrl.text = normalizeIndianMobile(profile.mobile);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;

    final formContent = Form(
      key: _formKey,
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth.clamp(980.0, 1320.0);
              final gap = isDesktop ? 20.0 : 16.0;
              final leftWidth = isDesktop
                  ? ((contentWidth - gap) * 0.62).clamp(560.0, 760.0)
                  : contentWidth;
              final rightWidth = isDesktop
                  ? (contentWidth - gap - leftWidth).clamp(320.0, 460.0)
                  : contentWidth;

              Widget customerDetailsCard = Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Customer Details'),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _codeCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Customer Code (Auto-generated)',
                          helperText:
                              'This code is assigned automatically and cannot be edited.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Customer name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _companyNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Contact Details'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: indianMobileInputFormatters(),
                        validator: (value) {
                          return validateIndianMobile(value, required: true);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _altPhoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Alternate Mobile',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: indianMobileInputFormatters(),
                        validator: validateIndianMobile,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Tax Details'),
                      const SizedBox(height: 12),
                      SearchableDropdownFormField<String>(
                        value: _selectedTaxPreference,
                        decoration: const InputDecoration(
                          labelText: 'Tax Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: _taxPreferences,
                        itemLabelBuilder: (option) => option,
                        onChanged: (value) {
                          setState(() {
                            _selectedTaxPreference = value;
                          });
                        },
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Please select Tax Type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _gstCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'GST Number',
                          suffixIcon: _isFetchingGst
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  onPressed: _fetchFromGstPortal,
                                  tooltip: 'Fetch from GST Portal',
                                  icon: const Icon(Icons.travel_explore),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _panCtrl,
                        decoration: const InputDecoration(
                          labelText: 'PAN Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Other Details'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _creditLimitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Credit Limit',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _openingBalanceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Opening Balance',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Active'),
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value ?? true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );

              Widget addressCard = Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Address'),
                      const SizedBox(height: 12),
                      AddressLocationForm(
                        controller: _billingAddress,
                        title: 'Billing Address',
                      ),
                      const Divider(height: 28),
                      AddressLocationForm(
                        controller: _shippingAddress,
                        title: 'Shipping Address',
                        sameAsController: _billingAddress,
                      ),
                    ],
                  ),
                ),
              );

              Widget saveButton = SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _saveCustomer,
                  icon: const Icon(Icons.save),
                  label: Text(
                    widget.initialCustomer != null
                        ? 'Update Customer'
                        : 'Add Customer',
                  ),
                ),
              );

              if (!isDesktop) {
                return Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        customerDetailsCard,
                        const SizedBox(height: 16),
                        _buildImportAndTemplateCard(),
                        const SizedBox(height: 16),
                        addressCard,
                        const SizedBox(height: 24),
                        saveButton,
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              }

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: leftWidth,
                            child: customerDetailsCard,
                          ),
                          SizedBox(width: gap),
                          SizedBox(
                            width: rightWidth,
                            child: _buildImportAndTemplateCard(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      addressCard,
                      const SizedBox(height: 24),
                      saveButton,
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialCustomer != null ? 'Edit Customer' : 'Add Customer',
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(builder: (_, _) => formContent),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}
