import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';

import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/features/services/gst_portal_lookup_service.dart';
import 'package:chirag_accounting/features/vendors/models/vendor.dart';
import 'package:chirag_accounting/shared/widgets/address_location_form.dart';

class AddVendorScreen extends StatefulWidget {
  final Vendor? initialVendor;

  const AddVendorScreen({super.key, this.initialVendor});

  @override
  State<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends State<AddVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final GstPortalLookupService _gstPortalLookupService =
      GstPortalLookupService();

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _gstCtrl;
  late AddressFormController _billingAddress;
  bool _isActive = true;
  bool _isFetchingGst = false;

  @override
  void initState() {
    super.initState();
    final service = context.read<VendorService>();
    _codeCtrl = TextEditingController(
      text: widget.initialVendor?.vendorCode ?? service.nextVendorCode(),
    );
    _nameCtrl = TextEditingController(
      text: widget.initialVendor?.vendorName ?? '',
    );
    _mobileCtrl = TextEditingController(
      text: widget.initialVendor?.mobileNumber ?? '',
    );
    _emailCtrl = TextEditingController(text: widget.initialVendor?.email ?? '');
    _gstCtrl = TextEditingController(
      text: widget.initialVendor?.gstNumber ?? '',
    );
    final initial = widget.initialVendor;
    _billingAddress = AddressFormController(
      initialValue:
          initial?.billingLocation ??
          StandardAddress.fromLegacy(address: initial?.billingAddress ?? ''),
    );
    _isActive = widget.initialVendor?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _billingAddress.dispose();
    super.dispose();
  }

  void _saveVendor() {
    if (!_formKey.currentState!.validate()) return;

    final addressValidation = validateAddressTaxIdentity(
      address: _billingAddress.value,
      gstin: _gstCtrl.text,
    );
    if (!addressValidation.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(addressValidation.message)));
      return;
    }

    final service = context.read<VendorService>();
    final initial = widget.initialVendor;
    final vendor = Vendor(
      id:
          widget.initialVendor?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      vendorCode: _codeCtrl.text.trim(),
      vendorName: _nameCtrl.text.trim(),
      mobileNumber: normalizeIndianMobile(_mobileCtrl.text),
      email: _emailCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim().toUpperCase(),
      billingAddress: _billingAddress.value.enteredAddress,
      billingLocation: _billingAddress.value,
      ledgerGroup: initial?.ledgerGroup ?? 'Sundry Creditors',
      openingBalance: initial?.openingBalance ?? 0,
      isActive: _isActive,
    );

    try {
      if (widget.initialVendor == null) {
        service.addVendor(vendor);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor ${vendor.vendorName} added'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        service.updateVendor(vendor.id, vendor);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor ${vendor.vendorName} updated'),
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

  Future<void> _fetchFromGstPortal() async {
    final gstin = _gstCtrl.text.trim().toUpperCase();
    setState(() => _isFetchingGst = true);
    final result = await _gstPortalLookupService.fetchTaxpayerByGstin(gstin);
    if (!mounted) return;
    setState(() => _isFetchingGst = false);
    final profile = result.profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    _gstCtrl.text = profile.gstin;
    if (_nameCtrl.text.trim().isEmpty) {
      _nameCtrl.text = profile.tradeName.isNotEmpty
          ? profile.tradeName
          : profile.legalName;
    }
    if (_billingAddress.addressLine1.text.trim().isEmpty) {
      _billingAddress.addressLine1.text = profile.address;
    }
    if (_billingAddress.state.text.trim().isEmpty) {
      _billingAddress.state.text = profile.state;
    }
    if (_billingAddress.pincode.text.trim().isEmpty) {
      _billingAddress.pincode.text = profile.pincode;
    }
    if (_emailCtrl.text.trim().isEmpty) _emailCtrl.text = profile.email;
    if (_mobileCtrl.text.trim().isEmpty) {
      _mobileCtrl.text = normalizeIndianMobile(profile.mobile);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialVendor == null ? 'Add Vendor' : 'Edit Vendor',
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _codeCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Vendor Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vendor Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Vendor name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: indianMobileInputFormatters(),
                decoration: const InputDecoration(
                  labelText: 'Mobile',
                  border: OutlineInputBorder(),
                ),
                validator: validateIndianMobile,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gstCtrl,
                textCapitalization: TextCapitalization.characters,
                onEditingComplete: _fetchFromGstPortal,
                decoration: InputDecoration(
                  labelText: 'GSTIN',
                  border: OutlineInputBorder(),
                  suffixIcon: _isFetchingGst
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Fetch GST details',
                          onPressed: _fetchFromGstPortal,
                          icon: const Icon(Icons.verified_outlined),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              AddressLocationForm(
                controller: _billingAddress,
                title: 'Billing Address',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Active Vendor'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveVendor,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Vendor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
