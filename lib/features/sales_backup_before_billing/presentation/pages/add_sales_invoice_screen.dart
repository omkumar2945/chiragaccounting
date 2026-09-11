import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/accounting/accounting_policy_service.dart';
import 'package:chirag_accounting/core/constants/feature_flags.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';
import 'package:chirag_accounting/features/clients/services/client_profile_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/customers/models/customer.dart';
import 'package:chirag_accounting/features/purchase/presentation/pages/add_purchase_bill_screen.dart';
import 'package:chirag_accounting/features/products/industry_master_pack.dart';
import 'package:chirag_accounting/features/products/industry_setup_service.dart';
import 'package:chirag_accounting/features/products/models/product.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/sales/presentation/widgets/product_selector.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/invoice_output_screen.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/sales/models/sales_item.dart';
import 'package:chirag_accounting/features/sales/services/invoice_product_reconciliation_service.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/gst_portal_lookup_service.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/ledger_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/features/vouchers/presentation/models/voucher_entry_type.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_form_screen.dart';
import 'package:chirag_accounting/features/vouchers/presentation/widgets/voucher_shortcut_shell.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class _MoveSelectionIntent extends Intent {
  const _MoveSelectionIntent(this.offset);

  final int offset;
}

class _SubmitSelectionIntent extends Intent {
  const _SubmitSelectionIntent();
}

enum _AiFieldStatus { verified, review, missing, create }

class _AiFieldValidation {
  final String label;
  final _AiFieldStatus status;
  final String detail;

  const _AiFieldValidation({
    required this.label,
    required this.status,
    required this.detail,
  });
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

enum SalesEntryMode { standard, manual, ocr }

class _ProductSelectionCandidate {
  final Product product;
  bool selected;

  _ProductSelectionCandidate({required this.product, this.selected = false});
}

class AddSalesInvoiceScreen extends StatefulWidget {
  final ParsedInvoiceData? prefillParsedData;
  final OcrDocumentAnalysis? prefillAnalysis;
  final Uint8List? prefillPreviewBytes;
  final String? prefillPreviewFilePath;
  final String? prefillPreviewFileName;
  final bool prefillPreviewIsPdf;
  final bool autoEntryMode;
  final bool openCameraOnLaunch;
  final bool? forceMobileOcrLaunchSheet;
  final SalesInvoiceType invoiceType;
  final SalesEntryMode initialEntryMode;

  const AddSalesInvoiceScreen({
    super.key,
    this.prefillParsedData,
    this.prefillAnalysis,
    this.prefillPreviewBytes,
    this.prefillPreviewFilePath,
    this.prefillPreviewFileName,
    this.prefillPreviewIsPdf = false,
    this.autoEntryMode = false,
    this.openCameraOnLaunch = false,
    this.forceMobileOcrLaunchSheet,
    this.invoiceType = SalesInvoiceType.sales,
    this.initialEntryMode = SalesEntryMode.standard,
  });

  @override
  State<AddSalesInvoiceScreen> createState() => _AddSalesInvoiceScreenState();
}

class _AddSalesInvoiceScreenState extends State<AddSalesInvoiceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<ProductRow> _products = [];
  final _ocrService = InvoiceOcrService();
  final _imagePicker = ImagePicker();
  bool _isParsingUpload = false;
  bool _isResolvingProducts = false;
  final _ocrTextCtrl = TextEditingController();
  bool _requiresVerification = false;
  bool _ocrVerified = false;
  OcrDocumentAnalysis? _lastDocumentAnalysis;
  ParsedInvoiceData? _lastParsedInvoiceData;
  bool _initialEntryFlowHandled = false;
  bool _aiDetailsExpanded = false;
  bool _paymentStatusExpanded = false;
  final bool _uploadedInvoiceBelongsToBusiness = true;
  Uint8List? _previewBytes;
  String? _previewFilePath;
  String? _previewFileName;
  bool _previewIsPdf = false;
  double _previewScale = 1.0;
  int _previewQuarterTurns = 0;
  bool _showOcrOverlay = true;
  String _activePreviewHighlight = 'Invoice Number';
  static const double _aiReviewThreshold = 0.90;

  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _invoiceDateCtrl;
  late TextEditingController _dueDateCtrl;
  String _placeOfSupply = 'Karnataka';
  InvoicePaymentStatus _invoicePaymentStatus = InvoicePaymentStatus.credit;
  String _invoicePaymentMode = 'Cash';
  late TextEditingController _receivedAmountCtrl;
  late TextEditingController _paymentReferenceCtrl;
  late TextEditingController _paymentDateCtrl;

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
  Customer? _shippingCustomer;
  bool _shipToAnotherCustomer = false;
  late TextEditingController _customerNameCtrl;
  final FocusNode _customerNameFocus = FocusNode();
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

  bool _eInvoiceApplicable = false;
  late TextEditingController _irnCtrl;
  late TextEditingController _ackNoCtrl;
  late TextEditingController _ackDateCtrl;

  late TextEditingController _notesCtrl;
  List<String> _attachmentPaths = [];

  bool get _isTaxInvoice => widget.invoiceType == SalesInvoiceType.tax;

  String get _screenLabel => _isTaxInvoice ? 'Tax Invoice' : 'Sales Invoice';

  bool get _showAiWorkspace {
    final hasPreview =
        _previewBytes != null || (_previewFilePath ?? '').trim().isNotEmpty;
    return widget.initialEntryMode == SalesEntryMode.ocr ||
        hasPreview ||
        _requiresVerification ||
        _lastParsedInvoiceData != null;
  }

  bool get _isManualWorkspace {
    final hasPreview =
        _previewBytes != null || (_previewFilePath ?? '').trim().isNotEmpty;
    return widget.initialEntryMode == SalesEntryMode.manual &&
        hasPreview &&
        _lastParsedInvoiceData == null;
  }

  double get _workspaceConfidence {
    final checks = _buildValidationChecklist();
    if (checks.isEmpty) {
      return 0;
    }
    var score = 0.0;
    for (final item in checks) {
      switch (item.status) {
        case _AiFieldStatus.verified:
          score += 1;
          break;
        case _AiFieldStatus.review:
          score += 0.6;
          break;
        case _AiFieldStatus.create:
          score += 0.45;
          break;
        case _AiFieldStatus.missing:
          score += 0.1;
          break;
      }
    }
    return (score / checks.length).clamp(0, 1);
  }

  String get _saveReadinessLabel {
    if (_isManualWorkspace) {
      return 'Save Invoice';
    }
    final confidence = _workspaceConfidence;
    if (confidence >= 0.95) {
      return 'Save Invoice';
    }
    if (confidence >= 0.80) {
      return 'Review Required';
    }
    return 'Manual Verification Required';
  }

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
    _dueDateCtrl = TextEditingController(text: _invoiceDateCtrl.text);
    _receivedAmountCtrl = TextEditingController(text: '0');
    _paymentReferenceCtrl = TextEditingController();
    _paymentDateCtrl = TextEditingController(text: _invoiceDateCtrl.text);
    _poNumberCtrl = TextEditingController();
    _poDateCtrl = TextEditingController();
    _projectNameCtrl = TextEditingController();
    _refNumberCtrl = TextEditingController();
    _customerNameCtrl = TextEditingController();
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
    _irnCtrl = TextEditingController();
    _ackNoCtrl = TextEditingController();
    _ackDateCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    if ((widget.prefillPreviewBytes?.isNotEmpty ?? false) ||
        (widget.prefillPreviewFilePath?.trim().isNotEmpty ?? false)) {
      _cachePreviewSource(
        filePath: widget.prefillPreviewFilePath,
        bytes: widget.prefillPreviewBytes,
        fileName: widget.prefillPreviewFileName ?? 'Uploaded invoice',
        isPdf: widget.prefillPreviewIsPdf,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (widget.prefillParsedData != null &&
          await _validateUploadedBusiness(widget.prefillParsedData!)) {
        setState(() {
          _applyParsedInvoiceData(widget.prefillParsedData!);
          _lastDocumentAnalysis = widget.prefillAnalysis;
        });

        if (widget.autoEntryMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Auto-entry applied: $_screenLabel form prefilled from upload.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      await _maybeLaunchInitialEntryFlow();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _invoiceNumberCtrl,
      _invoiceDateCtrl,
      _dueDateCtrl,
      _receivedAmountCtrl,
      _paymentReferenceCtrl,
      _paymentDateCtrl,
      _poNumberCtrl,
      _poDateCtrl,
      _projectNameCtrl,
      _refNumberCtrl,
      _customerNameCtrl,
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
      _irnCtrl,
      _ackNoCtrl,
      _ackDateCtrl,
      _notesCtrl,
      _paymentTermsSearchCtrl,
      _ocrTextCtrl,
    ]) {
      c.dispose();
    }
    _customerNameFocus.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  double get _invoiceGrandTotal {
    return _products.fold<double>(0, (sum, row) => sum + row.lineTotal);
  }

  double get _invoiceTaxableTotal {
    return _products.fold<double>(0, (sum, row) => sum + row.taxableAmount);
  }

  double get _invoiceGstTotal {
    return _products.fold<double>(0, (sum, row) => sum + row.gstAmount);
  }

  double get _receivedAmount {
    return double.tryParse(_receivedAmountCtrl.text.trim()) ?? 0;
  }

  double get _outstandingAmount {
    final value = _invoiceGrandTotal - _receivedAmount;
    return value < 0 ? 0 : value;
  }

  bool get _isAccountantUploadRestricted {
    return false;
  }

  bool _ensureClientUploadedSourceOnly() {
    return true;
  }

  void _onInvoicePaymentStatusChanged(InvoicePaymentStatus value) {
    setState(() {
      _invoicePaymentStatus = value;
      final total = _invoiceGrandTotal;
      if (value == InvoicePaymentStatus.fullyPaid) {
        _receivedAmountCtrl.text = total.toStringAsFixed(2);
      } else if (value == InvoicePaymentStatus.credit) {
        _receivedAmountCtrl.text = '0';
      }
    });
  }

  Product? _resolveMasterProduct({
    String? productName,
    String? hsnCode,
    String? productCode,
  }) {
    final candidates = context.read<ProductService>().products;
    final normalizedName = productName?.trim().toLowerCase() ?? '';
    final normalizedHsn = hsnCode?.trim().toLowerCase() ?? '';
    final normalizedCode = productCode?.trim().toLowerCase() ?? '';

    for (final product in candidates) {
      final nameMatches = normalizedName.isNotEmpty &&
          product.productName.trim().toLowerCase() == normalizedName;
      final hsnMatches = normalizedHsn.isNotEmpty &&
          product.hsnCode.trim().toLowerCase() == normalizedHsn;
      final codeMatches = normalizedCode.isNotEmpty &&
          product.productCode.trim().toLowerCase() == normalizedCode;

      if (nameMatches || hsnMatches || codeMatches) {
        return product;
      }
    }

    return null;
  }

  void _cachePreviewSource({
    String? filePath,
    Uint8List? bytes,
    required String fileName,
    required bool isPdf,
  }) {
    _previewFilePath = filePath;
    _previewBytes = bytes;
    _previewFileName = fileName;
    _previewIsPdf = isPdf;
    _previewScale = 1.0;
    _previewQuarterTurns = 0;
    if (_activePreviewHighlight.isEmpty) {
      _activePreviewHighlight = 'Invoice Number';
    }
  }

  _AiFieldStatus _statusForValue(String value) {
    if (value.trim().isEmpty) {
      return _AiFieldStatus.missing;
    }
    return _AiFieldStatus.verified;
  }

  _AiFieldStatus _statusForAmount(double value) {
    if (value <= 0) {
      return _AiFieldStatus.missing;
    }
    return _AiFieldStatus.verified;
  }

  _AiFieldStatus _statusForCustomer() {
    final hasName = _customerNameCtrl.text.trim().isNotEmpty;
    if (!hasName) {
      return _AiFieldStatus.missing;
    }
    if (_selectedCustomer != null) {
      return _AiFieldStatus.verified;
    }
    return _AiFieldStatus.create;
  }

  _AiFieldStatus _statusForProducts() {
    if (_products.isEmpty) {
      return _AiFieldStatus.missing;
    }
    final hasIncomplete = _products.any((row) {
      return (row.productName ?? '').trim().isEmpty ||
          row.quantity <= 0 ||
          row.rate <= 0;
    });
    if (hasIncomplete) {
      return _AiFieldStatus.review;
    }
    final hasUnmapped = _products.any((row) {
      return row.productCode.trim().isEmpty;
    });
    if (hasUnmapped) {
      return _AiFieldStatus.create;
    }
    return _AiFieldStatus.verified;
  }

  List<_AiFieldValidation> _buildValidationChecklist() {
    final subtotal = _invoiceTaxableTotal;
    final tax = _invoiceGstTotal;
    final total = _invoiceGrandTotal;

    return <_AiFieldValidation>[
      _AiFieldValidation(
        label: 'Invoice Number',
        status: _statusForValue(_invoiceNumberCtrl.text),
        detail: _invoiceNumberCtrl.text.trim(),
      ),
      _AiFieldValidation(
        label: 'Date',
        status: _statusForValue(_invoiceDateCtrl.text),
        detail: _invoiceDateCtrl.text.trim(),
      ),
      _AiFieldValidation(
        label: 'Customer',
        status: _statusForCustomer(),
        detail:
            _selectedCustomer?.customerName ?? _customerNameCtrl.text.trim(),
      ),
      _AiFieldValidation(
        label: 'GSTIN',
        status: _statusForValue(_gstinCtrl.text),
        detail: _gstinCtrl.text.trim(),
      ),
      _AiFieldValidation(
        label: 'Products',
        status: _statusForProducts(),
        detail: _products.isEmpty
            ? 'No line items'
            : '${_products.length} line item(s)',
      ),
      _AiFieldValidation(
        label: 'HSN',
        status: _products.isEmpty
            ? _AiFieldStatus.missing
            : (_products.any(
                    (row) =>
                        (row.hsnCode ?? '').trim().isEmpty ||
                        !row.taxCodeVerified,
                  )
                  ? _AiFieldStatus.review
                  : _AiFieldStatus.verified),
        detail: _products.isEmpty
            ? 'No items'
            : _products
                  .where((row) => (row.hsnCode ?? '').trim().isNotEmpty)
                  .map((row) => row.hsnCode!.trim())
                  .toSet()
                  .take(3)
                  .join(', '),
      ),
      _AiFieldValidation(
        label: 'Amount',
        status: _statusForAmount(subtotal),
        detail: 'Rs. ${subtotal.toStringAsFixed(2)}',
      ),
      _AiFieldValidation(
        label: 'Tax',
        status:
            _products.any(
              (row) => row.gstPercentage <= 0 || !row.taxCodeVerified,
            )
            ? _AiFieldStatus.review
            : _statusForAmount(tax),
        detail:
            'Rs. ${tax.toStringAsFixed(2)}${_products.any((row) => row.isCharge) ? ' | Charges: Indirect Income' : ''}',
      ),
      _AiFieldValidation(
        label: 'Total',
        status: _statusForAmount(total),
        detail: 'Rs. ${total.toStringAsFixed(2)}',
      ),
    ];
  }

  Future<Customer?> _createCustomerInline({bool selectAsBilling = true}) async {
    final nameCtrl = TextEditingController(text: _customerNameCtrl.text.trim());
    final mobileCtrl = TextEditingController(text: _mobileCtrl.text.trim());
    final gstinCtrl = TextEditingController(text: _gstinCtrl.text.trim());
    final billingCtrl = TextEditingController(
      text: _billingAddressCtrl.text.trim(),
    );
    final stateCtrl = TextEditingController(text: _placeOfSupply);
    final pinCtrl = TextEditingController();
    var isFetchingGst = false;
    String lookupMessage = '';
    String saveError = '';

    final customer = await showMovableDialog<Customer>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Create Customer'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gstinCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'GST Number',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: isFetchingGst
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isFetchingGst = true;
                                    lookupMessage = '';
                                  });
                                  final result = await GstPortalLookupService()
                                      .fetchTaxpayerByGstin(gstinCtrl.text);
                                  if (!dialogContext.mounted) return;
                                  final profile = result.profile;
                                  setDialogState(() {
                                    isFetchingGst = false;
                                    lookupMessage = result.message;
                                    if (profile != null) {
                                      nameCtrl.text =
                                          profile.tradeName.isNotEmpty
                                          ? profile.tradeName
                                          : profile.legalName;
                                      billingCtrl.text = profile.address;
                                      stateCtrl.text = profile.state;
                                      pinCtrl.text = profile.pincode;
                                      mobileCtrl.text = profile.mobile;
                                    }
                                  });
                                },
                          icon: isFetchingGst
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_download_outlined),
                          label: const Text('Fetch GST'),
                        ),
                      ],
                    ),
                    if (lookupMessage.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          lookupMessage,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                    if (saveError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          saveError,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: billingCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: pinCtrl,
                            decoration: const InputDecoration(
                              labelText: 'PIN',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    setDialogState(
                      () => saveError = 'Customer name is required.',
                    );
                    return;
                  }
                  final service = context.read<CustomerService>();
                  final created = Customer(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    customerCode: service.nextCustomerCode(),
                    customerName: name,
                    companyName: name,
                    mobileNumber: normalizeIndianMobile(mobileCtrl.text),
                    gstNumber: gstinCtrl.text.trim().toUpperCase(),
                    billingAddress: billingCtrl.text.trim(),
                    shippingAddress: billingCtrl.text.trim(),
                    state: stateCtrl.text.trim(),
                    pinCode: pinCtrl.text.trim(),
                    ledgerGroup: 'Sundry Debtors',
                  );
                  try {
                    final saved = service.addCustomerWithLedger(
                      created,
                      context.read<LedgerService?>(),
                    );
                    Navigator.pop(dialogContext, saved);
                  } on ArgumentError catch (error) {
                    setDialogState(() => saveError = error.message.toString());
                  } catch (error) {
                    setDialogState(() => saveError = error.toString());
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );

    nameCtrl.dispose();
    mobileCtrl.dispose();
    gstinCtrl.dispose();
    billingCtrl.dispose();
    stateCtrl.dispose();
    pinCtrl.dispose();

    if (customer == null) {
      return null;
    }

    if (selectAsBilling) {
      _fillCustomer(customer);
    }
    return customer;
  }

  Future<void> _createProductInline() async {
    if (_isResolvingProducts || _products.isEmpty) return;
    setState(() => _isResolvingProducts = true);

    final result = await InvoiceProductReconciliationService().reconcile(
      rows: _products,
      productService: context.read<ProductService>(),
    );
    if (!mounted) return;

    setState(() {
      _products = List<ProductRow>.of(_products);
      _isResolvingProducts = false;
      _ocrVerified = result.completed;
    });
    final message = result.completed
        ? '${result.matched} matched, ${result.created} created. All products resolved.'
        : '${result.matched} matched, ${result.created} created, ${result.errors.length} need review. ${result.errors.first}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildOcrInsights(
    ParsedInvoiceData parsed,
    OcrDocumentAnalysis analysis,
  ) {
    final validation = _ocrService.validateParsedData(parsed);
    final salesService = context.read<SalesService>();
    final duplicates = _ocrService.detectDuplicates(
      parsed: parsed,
      existing: salesService.invoices
          .map(
            (invoice) => InvoiceFingerprint(
              referenceNumber: invoice.invoiceNumber,
              partyName: invoice.customerName,
              gstin: invoice.gstNumber,
              billDate: invoice.invoiceDate.toIso8601String().split('T').first,
              totalAmount: invoice.grandTotal,
            ),
          )
          .toList(growable: false),
    );

    final notes = <String>[];
    if (validation.needsReview) {
      final warningPreview = validation.warnings.take(2).join(', ');
      notes.add(
        'AI validation ${(validation.confidence * 100).round()}%${warningPreview.isNotEmpty ? ': $warningPreview' : ''}',
      );
    }

    if (duplicates.hasDuplicates) {
      final best = duplicates.matches.first;
      notes.add(
        'Possible duplicate ${best.candidate.referenceNumber} (${(best.score * 100).round()}%)',
      );
    }

    final detected = _documentKindLabel(analysis.kind);
    notes.add(
      'Detected type: $detected (${(analysis.confidence * 100).round()}%)',
    );

    return notes.join(' | ');
  }

  String _documentKindLabel(OcrDocumentKind kind) {
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return 'Sales Invoice';
      case OcrDocumentKind.purchaseBill:
        return 'Purchase Bill';
      case OcrDocumentKind.creditNote:
        return 'Credit Note';
      case OcrDocumentKind.debitNote:
        return 'Debit Note';
      case OcrDocumentKind.chequeGiven:
        return 'Cheque Given';
      case OcrDocumentKind.chequeReceived:
        return 'Cheque Received';
      case OcrDocumentKind.paymentVoucher:
        return 'Payment Voucher';
      case OcrDocumentKind.receiptVoucher:
        return 'Receipt Voucher';
      case OcrDocumentKind.unknown:
        return 'Unknown';
    }
  }

  bool _isSalesCompatible(OcrDocumentKind kind) {
    return kind == OcrDocumentKind.salesInvoice ||
        kind == OcrDocumentKind.unknown;
  }

  VoucherType? _voucherTypeForDocument(OcrDocumentKind kind) {
    switch (kind) {
      case OcrDocumentKind.paymentVoucher:
      case OcrDocumentKind.chequeGiven:
        return VoucherType.payment;
      case OcrDocumentKind.receiptVoucher:
      case OcrDocumentKind.chequeReceived:
        return VoucherType.receipt;
      case OcrDocumentKind.creditNote:
        return VoucherType.creditNote;
      case OcrDocumentKind.debitNote:
        return VoucherType.debitNote;
      default:
        return null;
    }
  }

  Future<void> _handleMismatchedSalesDocument(
    OcrDocumentAnalysis analysis,
  ) async {
    final detected = _documentKindLabel(analysis.kind);
    if (!mounted) return;

    await showMovableDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload routed to safer module'),
        content: Text(
          'Detected "$detected" document. To keep data accurate, this file is not auto-applied in Sales Invoice module.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (analysis.kind == OcrDocumentKind.purchaseBill)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddPurchaseBillScreen(),
                  ),
                );
              },
              child: const Text('Open Purchase'),
            ),
          if (FeatureFlags.bankingEnabled &&
              _voucherTypeForDocument(analysis.kind) != null)
            ElevatedButton(
              onPressed: () {
                final voucherType = _voucherTypeForDocument(analysis.kind)!;
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ClientBankScreen(initialVoucherType: voucherType),
                  ),
                );
              },
              child: const Text('Open Banking Voucher'),
            ),
        ],
      ),
    );
  }

  Future<void> _parseInvoiceFile(
    File file, {
    required bool isPdf,
    String? displayName,
  }) async {
    _cachePreviewSource(
      filePath: file.path,
      fileName: displayName ?? file.uri.pathSegments.last,
      isPdf: isPdf,
    );
    setState(() => _isParsingUpload = true);
    try {
      final bytes = await file.readAsBytes();
      final structuredData = await _ocrService.extractStructuredInvoiceData(
        bytes,
        fileName: displayName ?? file.uri.pathSegments.last,
      );
      final extractedText =
          structuredData?.rawText ??
          (isPdf
              ? await _ocrService.extractTextFromPdf(file)
              : await _ocrService.extractTextFromImage(file));
      final parsed =
          structuredData ?? _ocrService.parseInvoiceText(extractedText);
      if (!await _validateUploadedBusiness(parsed)) return;
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isSalesCompatible(analysis.kind)) {
        setState(() {
          _ocrTextCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
          _lastParsedInvoiceData = parsed;
        });
        await _handleMismatchedSalesDocument(analysis);
        return;
      }

      setState(() {
        _applyParsedInvoiceData(parsed);
        _lastDocumentAnalysis = analysis;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Invoice parsed: ${parsed.items.length} product line(s) detected' : 'Text extracted. Review and complete remaining fields.'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR parse failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _scanInvoiceFromCamera() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;
    if (!isUsableLocalFilePath(image.path)) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Captured image bytes are empty.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _parseImageBytes(bytes, sourceName: 'camera_invoice.jpg');
      return;
    }
    await _parseInvoiceFile(
      File(image.path),
      isPdf: false,
      displayName: image.name,
    );
  }

  Future<void> _pickInvoiceFromGallery() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;
    if (!isUsableLocalFilePath(image.path)) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected image bytes are empty.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _parseImageBytes(bytes, sourceName: 'gallery_invoice.jpg');
      return;
    }
    await _parseInvoiceFile(
      File(image.path),
      isPdf: false,
      displayName: image.name,
    );
  }

  Future<void> _pickMultipleInvoiceImages() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    setState(() => _isParsingUpload = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final files = result.files
          .map((item) => item.path)
          .whereType<String>()
          .where(isUsableLocalFilePath)
          .map(File.new)
          .toList(growable: false);

      String extractedText;
      if (files.isNotEmpty) {
        _cachePreviewSource(
          filePath: files.first.path,
          fileName: files.first.uri.pathSegments.last,
          isPdf: false,
        );
        extractedText = await _ocrService.extractTextFromImages(files);
      } else {
        final imageBytes = result.files
            .map((item) => item.bytes)
            .whereType<Uint8List>()
            .where((bytes) => bytes.isNotEmpty)
            .toList(growable: false);
        final fileNames = result.files
            .map(
              (item) => item.name.trim().isEmpty
                  ? 'upload_image.jpg'
                  : item.name.trim(),
            )
            .toList(growable: false);

        if (imageBytes.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No usable image path or bytes found for OCR.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        _cachePreviewSource(
          bytes: imageBytes.first,
          fileName: fileNames.first,
          isPdf: false,
        );

        extractedText = await _ocrService.extractTextFromImagesBytes(
          imageBytes,
          fileNames: fileNames,
        );
      }

      final parsed = _ocrService.parseInvoiceText(extractedText);
      if (!await _validateUploadedBusiness(parsed)) return;
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isSalesCompatible(analysis.kind)) {
        setState(() {
          _ocrTextCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
          _lastParsedInvoiceData = parsed;
        });
        await _handleMismatchedSalesDocument(analysis);
        return;
      }

      setState(() {
        _applyParsedInvoiceData(parsed);
        _lastDocumentAnalysis = analysis;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Batch OCR parsed: ${parsed.items.length} product line(s) detected' : 'Batch OCR text extracted. Review and complete remaining fields.'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch OCR parse failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _parseImageBytes(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    _cachePreviewSource(bytes: bytes, fileName: sourceName, isPdf: false);
    setState(() => _isParsingUpload = true);
    try {
      final extractedText = await _ocrService.extractTextFromImageBytes(
        bytes,
        fileName: sourceName,
      );
      final parsed = _ocrService.parseInvoiceText(extractedText);
      if (!await _validateUploadedBusiness(parsed)) return;
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isSalesCompatible(analysis.kind)) {
        setState(() {
          _ocrTextCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
          _lastParsedInvoiceData = parsed;
        });
        await _handleMismatchedSalesDocument(analysis);
        return;
      }

      setState(() {
        _applyParsedInvoiceData(parsed);
        _lastDocumentAnalysis = analysis;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Invoice parsed: ${parsed.items.length} product line(s) detected' : 'Text extracted. Review and complete remaining fields.'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR parse failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _pickInvoicePdf() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path;

    if (path != null && isUsableLocalFilePath(path)) {
      await _parseInvoiceFile(
        File(path),
        isPdf: true,
        displayName: picked.name,
      );
      return;
    }

    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read PDF bytes from selected file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isParsingUpload = true);
    try {
      _cachePreviewSource(bytes: bytes, fileName: picked.name, isPdf: true);
      final extractedText = await _ocrService.extractTextFromPdfBytes(bytes);
      final parsed = _ocrService.parseInvoiceText(extractedText);
      if (!await _validateUploadedBusiness(parsed)) return;
      final analysis = _ocrService.analyzeDocumentType(
        extractedText,
        parsed: parsed,
      );
      final insights = _buildOcrInsights(parsed, analysis);

      if (!_isSalesCompatible(analysis.kind)) {
        setState(() {
          _ocrTextCtrl.text = parsed.rawText;
          _requiresVerification = true;
          _ocrVerified = false;
          _lastDocumentAnalysis = analysis;
          _lastParsedInvoiceData = parsed;
        });
        await _handleMismatchedSalesDocument(analysis);
        return;
      }

      setState(() {
        _applyParsedInvoiceData(parsed);
        _lastDocumentAnalysis = analysis;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.items.isNotEmpty ? 'Invoice parsed: ${parsed.items.length} product line(s) detected' : 'Text extracted. Review and complete remaining fields.'}${insights.isNotEmpty ? '\n$insights' : ''}',
          ),
          backgroundColor: insights.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR parse failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsingUpload = false);
      }
    }
  }

  Future<void> _maybeLaunchInitialEntryFlow() async {
    if (_initialEntryFlowHandled || !mounted) {
      return;
    }
    _initialEntryFlowHandled = true;

    if (widget.initialEntryMode != SalesEntryMode.ocr ||
        widget.prefillParsedData != null) {
      return;
    }

    if (_isAccountantUploadRestricted) {
      return;
    }

    if (_isMobileDevice && widget.openCameraOnLaunch) {
      await _scanInvoiceFromCamera();
      return;
    }

    if (_isMobileDevice) {
      await _showMobileOcrLaunchSheet();
      return;
    }

    await _showOcrSourcePicker();
  }

  bool get _isMobileDevice {
    if (widget.forceMobileOcrLaunchSheet != null) {
      return widget.forceMobileOcrLaunchSheet!;
    }

    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _showMobileOcrLaunchSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan Invoice',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how you want to capture the invoice on mobile.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Use Camera'),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _scanInvoiceFromCamera();
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick from Gallery'),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _pickInvoiceFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOcrSourcePicker() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Scan Camera'),
                subtitle: Text('Capture a $_screenLabel document'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _scanInvoiceFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Pick Image'),
                subtitle: Text('Choose a $_screenLabel image'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickInvoiceFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.collections_outlined),
                title: const Text('Pick Multi Images'),
                subtitle: Text('Combine multiple $_screenLabel photos'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickMultipleInvoiceImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Pick PDF'),
                subtitle: Text('Import a $_screenLabel PDF'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickInvoicePdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAttachments() async {
    if (!_ensureClientUploadedSourceOnly()) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files.toList(growable: false);
    final paths = files
        .map((item) => item.path)
        .whereType<String>()
        .where(isUsableLocalFilePath)
        .toList(growable: false);

    if (paths.isEmpty) return;

    setState(() {
      _attachmentPaths = <String>{
        ..._attachmentPaths,
        ...paths,
      }.toList(growable: false);
      if (_previewBytes == null && paths.isNotEmpty) {
        final first = files.first;
        _cachePreviewSource(
          filePath: first.path,
          bytes: first.bytes,
          fileName: first.name.trim().isEmpty ? 'attachment' : first.name.trim(),
          isPdf: first.extension?.toLowerCase() == 'pdf',
        );
      }
    });
  }

  Future<void> _openQuickProductPicker() async {
    final productService = context.read<ProductService>();
    if (productService.products.isEmpty) {
      final setup = await IndustrySetupService().loadState();
      final pack = IndustryMasterPacks.byKey(setup.selectedIndustryKey);
      if (setup.initialized && pack != null) {
        productService.installIndustryPack(pack);
      }
    }
    if (!mounted) return;

    final activeProducts = productService.filterActiveProducts().toList(
      growable: false,
    );

    if (activeProducts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active products found. Add products first.'),
        ),
      );
      return;
    }

    final existingProductNames = _products
        .map((row) => row.productName?.trim().toLowerCase() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    final candidates = activeProducts
        .map(
          (product) => _ProductSelectionCandidate(
            product: product,
            selected: existingProductNames.contains(
              product.productName.trim().toLowerCase(),
            ),
          ),
        )
        .toList(growable: false);

    final selectedProducts = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var query = '';
        var selectedCategory = 'All';
        final categories = <String>{
          'All',
          ...activeProducts
              .map((product) => product.category.trim())
              .where((category) => category.isNotEmpty),
        }.toList(growable: false)..sort();

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = candidates
                .where((entry) {
                  final matchQuery =
                      query.trim().isEmpty ||
                      entry.product.productName.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      entry.product.productCode.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      entry.product.hsnCode.toLowerCase().contains(
                        query.toLowerCase(),
                      );

                  final matchCategory =
                      selectedCategory == 'All' ||
                      entry.product.category == selectedCategory;
                  return matchQuery && matchCategory;
                })
                .toList(growable: false);

            final selectedCount = candidates
                .where((entry) => entry.selected)
                .length;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.82,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Item',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search product',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      SearchableDropdownFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: categories,
                        itemLabelBuilder: (category) => category,
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$selectedCount product(s) selected',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('No products match your search.'),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final entry = filtered[index];
                                  final product = entry.product;
                                  return CheckboxListTile(
                                    value: entry.selected,
                                    onChanged: (value) {
                                      setModalState(() {
                                        entry.selected = value ?? false;
                                      });
                                    },
                                    title: Text(product.productName),
                                    subtitle: Text(
                                      '${product.category.isEmpty ? 'Uncategorized' : product.category} • HSN ${product.hsnCode.isEmpty ? '-' : product.hsnCode} • GST ${product.gstPercentage.toStringAsFixed(0)}%',
                                    ),
                                    secondary: Text(
                                      product.unit,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: selectedCount == 0
                                ? null
                                : () {
                                    final selected = candidates
                                        .where((entry) => entry.selected)
                                        .map((entry) => entry.product)
                                        .toList(growable: false);
                                    Navigator.pop(sheetContext, selected);
                                  },
                            child: const Text('Add to Invoice'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedProducts == null || selectedProducts.isEmpty) {
      return;
    }

    setState(() {
      final existingNames = _products
          .map((row) => row.productName?.trim().toLowerCase() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();

      for (final product in selectedProducts) {
        final normalizedName = product.productName.trim().toLowerCase();
        if (existingNames.contains(normalizedName)) {
          continue;
        }

        _products.add(
          ProductRow(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            productCode: product.productCode,
            productName: product.productName,
            hsnCode: product.hsnCode,
            unit: product.unit,
            quantity: 1,
            rate: product.salesRate,
            gstPercentage: product.gstPercentage,
            stockAvailable: product.openingStock,
          ),
        );
        existingNames.add(normalizedName);
      }
    });
  }

  void _fillCustomer(Customer c) => setState(() {
    _selectedCustomer = c;
    _customerNameCtrl.text = c.customerName;
    _mobileCtrl.text = c.mobileNumber;
    _gstinCtrl.text = c.gstNumber;
    _billingAddressCtrl.text = c.billingAddress;
    _shippingAddressCtrl.text = c.shippingAddress;
  });

  Future<bool> _validateUploadedBusiness(ParsedInvoiceData parsed) async {
    final hasUsefulData = parsed.rawText.trim().isNotEmpty ||
        parsed.partyName.trim().isNotEmpty ||
        parsed.gstin.trim().isNotEmpty ||
        parsed.billNumber.trim().isNotEmpty ||
        parsed.items.isNotEmpty;

    if (!hasUsefulData && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No invoice data could be read from the attached file.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return hasUsefulData;
  }

  void _applyParsedInvoiceData(ParsedInvoiceData parsed) {
    final customerService = context.read<CustomerService>();
    final matchedCustomer = customerService.findIdentityMatch(
      parsed.partyName,
      gstNumber: parsed.gstin,
      mobileNumber: normalizeIndianMobile(parsed.mobile),
    );

    if (matchedCustomer != null) {
      _fillCustomer(matchedCustomer);
    } else {
      if (parsed.partyName.trim().isNotEmpty) {
        _customerNameCtrl.text = parsed.partyName.trim();
      }
      if (parsed.mobile.trim().isNotEmpty) {
        _mobileCtrl.text = normalizeIndianMobile(parsed.mobile);
      }
      if (parsed.gstin.trim().isNotEmpty) {
        _gstinCtrl.text = parsed.gstin.trim().toUpperCase();
      }
      if (parsed.partyAddress.trim().isNotEmpty) {
        _billingAddressCtrl.text = parsed.partyAddress.trim();
        _shippingAddressCtrl.text = parsed.partyAddress.trim();
      }
      _selectedCustomer = null;
    }

    if (parsed.billNumber.trim().isNotEmpty) {
      _invoiceNumberCtrl.text = parsed.billNumber.trim();
    }
    if (parsed.billDate.trim().isNotEmpty) {
      _invoiceDateCtrl.text = parsed.billDate.trim();
      if (_dueDateCtrl.text.trim().isEmpty) {
        _dueDateCtrl.text = parsed.billDate.trim();
      }
    }

    final parsedRows = parsed.items.map((item) {
      final master = _resolveMasterProduct(
        productName: item.name,
        hsnCode: item.hsnCode,
      );
      return ProductRow(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productCode: master?.productCode ?? '',
        productName: item.name,
        description: item.description,
        hsnCode: item.hsnCode.isEmpty ? master?.hsnCode : item.hsnCode,
        unit: item.unit.isEmpty ? master?.unit : item.unit,
        quantity: item.quantity,
        rate: item.rate,
        extractedAmount: item.amount > 0 ? item.amount : null,
        gstPercentage: item.gstPercentage > 0 ? item.gstPercentage : master?.gstPercentage ?? 18,
        taxCodeVerified: master != null || item.hsnCode.trim().isNotEmpty,
      );
    }).toList(growable: false);

    setState(() {
      if (parsedRows.isNotEmpty) {
        _products = parsedRows;
      }
      _ocrTextCtrl.text = parsed.rawText;
      _requiresVerification = parsed.extractionConfidence < _aiReviewThreshold;
      _ocrVerified = !_requiresVerification;
      _lastParsedInvoiceData = parsed;
      _aiDetailsExpanded = true;
      if (_paymentTerms.isEmpty) {
        _paymentTerms = 'Net 30';
      }
    });
  }

  void _tryMatchCustomerFromInputs() {
    final service = context.read<CustomerService>();
    final name = _customerNameCtrl.text.trim();
    final gstin = _gstinCtrl.text.trim();
    final mobile = normalizeIndianMobile(_mobileCtrl.text);

    final matched = service.findIdentityMatch(
      name,
      gstNumber: gstin,
      mobileNumber: mobile,
    );

    if (matched != null) {
      _fillCustomer(matched);
      return;
    }

    if (_selectedCustomer != null) {
      setState(() {
        _selectedCustomer = null;
      });
    }
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

  Future<void> _pickInvoiceDate() async {
    final previousInvoiceDate = _invoiceDateCtrl.text.trim();
    await _pickDate(_invoiceDateCtrl);
    final newInvoiceDate = _invoiceDateCtrl.text.trim();
    if (newInvoiceDate.isEmpty) return;

    final dueDate = _dueDateCtrl.text.trim();
    if (dueDate.isEmpty || dueDate == previousInvoiceDate) {
      _dueDateCtrl.text = newInvoiceDate;
    }
  }

  Future<void> _continueInvoiceNumbering() async {
    final previousNumberCtrl = TextEditingController();
    final previousNumber = await showMovableDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Continue Invoice Numbering'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the last invoice number used before billing started in this software. The next invoice will continue its prefix and serial.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: previousNumberCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Previous / Last Invoice Number',
                  hintText: 'Example: FY26/INV/0125',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) =>
                    Navigator.pop(dialogContext, value.trim()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, previousNumberCtrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    previousNumberCtrl.dispose();
    if (!mounted || previousNumber == null || previousNumber.isEmpty) return;

    try {
      final service = context.read<SalesService>();
      service.continueInvoiceNumbering(
        type: widget.invoiceType,
        previousInvoiceNumber: previousNumber,
      );
      setState(() {
        _invoiceNumberCtrl.text = _isTaxInvoice
            ? service.generateNextTaxInvoiceNumber()
            : service.generateNextInvoiceNumber();
      });
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _responsiveFieldRow(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                fields[index],
                if (index < fields.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              Expanded(child: fields[index]),
              if (index < fields.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
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
                    '${customer.customerCode}  �  ${customer.mobileNumber}',
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

  void _openVoucherShortcut(VoucherEntryType type) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => VoucherEntryFormScreen(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isTaxInvoice ? Colors.orange : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add $_screenLabel'),
        centerTitle: true,
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
      body: VoucherShortcutShell(
        currentType: VoucherEntryType.sales,
        onSelected: _openVoucherShortcut,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyC, alt: true):
                _createCustomerInline,
            const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                _createProductInline,
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                _saveInvoice,
          },
          child: Form(
            key: _formKey,
            child: _showAiWorkspace
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildAiVerificationWorkspace(accentColor),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Invoice Information'),
                        const SizedBox(height: 12),
                        _buildClassicOcrUploadCard(),
                        const SizedBox(height: 12),
                        _invoiceInfoCard(),
                        const SizedBox(height: 20),
                        _customerCard(),
                        const SizedBox(height: 12),
                        _referenceCard(),
                        const SizedBox(height: 20),
                        _transportHeader(),
                        if (_showTransport) ...[
                          const SizedBox(height: 12),
                          _transportCard(),
                        ],
                        const SizedBox(height: 20),
                        _eInvoiceSection(),
                        const SizedBox(height: 20),
                        _sectionTitle('Products'),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            key: const ValueKey('sales-quick-product-picker'),
                            onPressed: _openQuickProductPicker,
                            icon: const Icon(
                              Icons.playlist_add_check_circle_outlined,
                            ),
                            label: const Text('Add Item (Quick Picker)'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ProductSelector(
                          initialRows: _products,
                          placeOfSupply: _placeOfSupply,
                          onProductsChanged: (rows) =>
                              setState(() => _products = rows),
                        ),
                        const SizedBox(height: 20),
                        _paymentStatusCard(),
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
                        const SizedBox(height: 12),
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Supporting Images / PDF',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickAttachments,
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('Attach Manual Files'),
                                  ),
                                  if (_attachmentPaths.isNotEmpty)
                                    Chip(
                                      label: Text(
                                        '${_attachmentPaths.length} file(s) attached',
                                      ),
                                    ),
                                ],
                              ),
                              if (_attachmentPaths.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _attachmentPaths
                                      .map(
                                        (path) => Chip(
                                          label: Text(
                                            File(path).uri.pathSegments.last,
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ],
                            ],
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
                              _showAiWorkspace
                                  ? _saveReadinessLabel
                                  : 'Save Invoice',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      floatingActionButton: _showAiWorkspace
          ? FloatingActionButton.extended(
              onPressed: _showAiAssistant,
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('AI Assistant'),
            )
          : null,
      bottomNavigationBar: _showAiWorkspace ? _buildAiStatusBar() : null,
    );
  }

  Widget _buildClassicOcrUploadCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice OCR Upload (camera/gallery/batch/PDF)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isParsingUpload ? null : _scanInvoiceFromCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scan Camera'),
              ),
              OutlinedButton.icon(
                onPressed: _isParsingUpload ? null : _pickInvoiceFromGallery,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Pick Image'),
              ),
              OutlinedButton.icon(
                onPressed: _isParsingUpload ? null : _pickMultipleInvoiceImages,
                icon: const Icon(Icons.collections_outlined),
                label: const Text('Pick Multi Images'),
              ),
              OutlinedButton.icon(
                onPressed: _isParsingUpload ? null : _pickInvoicePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Pick PDF'),
              ),
            ],
          ),
          if (_isParsingUpload) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            const Text(
              'Reading invoice text (with scanned-PDF OCR fallback)...',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: _ocrTextCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Extracted OCR Text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_requiresVerification) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _ocrVerified = true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Tick Correct'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _ocrVerified = false),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Data'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _ocrVerified
                  ? 'Marked as verified. You can now save.'
                  : 'If OCR data is not correct, edit fields then click Tick Correct.',
              style: TextStyle(
                fontSize: 12,
                color: _ocrVerified ? Colors.green.shade700 : Colors.black54,
              ),
            ),
          ] else
            const Text(
              'Upload an invoice to enable Tick Correct / Edit Data actions.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _buildAiVerificationWorkspace(Color accentColor) {
    final checklist = _buildValidationChecklist();
    final confidence = _workspaceConfidence;
    final matched = checklist
        .where((item) => item.status == _AiFieldStatus.verified)
        .length;
    final review = checklist
        .where(
          (item) =>
              item.status == _AiFieldStatus.review ||
              item.status == _AiFieldStatus.missing,
        )
        .length;
    final newMasters = checklist
        .where((item) => item.status == _AiFieldStatus.create)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 980;

        final splitContent = isCompact
            ? Column(
                children: [
                  Expanded(
                    flex: 11,
                    child: _buildAiFormPanel(accentColor, checklist),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 9,
                    child: _buildAiPreviewPanel(accentColor, checklist),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    key: const ValueKey('sales-invoice-entry-pane'),
                    flex: 35,
                    child: _buildAiFormPanel(accentColor, checklist),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    key: const ValueKey('sales-invoice-preview-pane'),
                    flex: 65,
                    child: _buildAiPreviewPanel(accentColor, checklist),
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompactAiSummary(
              matched: matched,
              review: review,
              newMasters: newMasters,
              confidence: confidence,
            ),
            const SizedBox(height: 8),
            Expanded(child: splitContent),
          ],
        );
      },
    );
  }

  Widget _buildCompactAiSummary({
    required int matched,
    required int review,
    required int newMasters,
    required double confidence,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5F2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 8),
          const Text(
            'AI Summary',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _aiMetric(Icons.check_circle, Colors.green, '$matched Matched'),
                InkWell(
                  onTap: () => setState(() => _aiDetailsExpanded = true),
                  child: _aiMetric(
                    Icons.add_circle,
                    Colors.blue,
                    '$newMasters New Masters',
                  ),
                ),
                _aiMetric(
                  Icons.warning_amber_rounded,
                  Colors.orange,
                  '$review Review',
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _aiDetailsExpanded
                ? 'Collapse AI details'
                : 'Expand AI details',
            onPressed: () =>
                setState(() => _aiDetailsExpanded = !_aiDetailsExpanded),
            icon: Icon(
              _aiDetailsExpanded ? Icons.expand_less : Icons.expand_more,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiMetric(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildAiStatusBar() {
    final confidence = _workspaceConfidence;
    return Material(
      elevation: 10,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final status = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AI ${(confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 18),
                  const Text('Ctrl+S  Save', style: TextStyle(fontSize: 12)),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showFullScreenPreview,
                    icon: const Icon(Icons.open_in_full, size: 17),
                    label: const Text('Original'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saveInvoice,
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Save'),
                  ),
                ],
              );
              if (constraints.maxWidth < 540) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    status,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(children: [status, const Spacer(), actions]);
            },
          ),
        ),
      ),
    );
  }

  void _showAiAssistant() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Assistant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.rule_outlined, size: 17),
                    label: const Text('Explain Highlight'),
                    onPressed: () => _showAiAnswer(
                      '$_activePreviewHighlight is selected for comparison with the uploaded invoice.',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.account_tree_outlined, size: 17),
                    label: const Text('Suggest Ledger'),
                    onPressed: () => _showAiAnswer(
                      'Use Sales Account for the invoice and the selected customer as debtor ledger.',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.percent_outlined, size: 17),
                    label: const Text('Explain GST'),
                    onPressed: () => _showAiAnswer(
                      'GST is calculated from product HSN, tax rate, and place of supply.',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.content_copy_outlined, size: 17),
                    label: const Text('Find Duplicate'),
                    onPressed: () => _showAiAnswer(
                      'Duplicate validation runs again when the invoice is saved.',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add_box_outlined, size: 17),
                    label: Text(
                      _isResolvingProducts
                          ? 'Resolving...'
                          : 'Resolve Products',
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _createProductInline();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiAnswer(String message) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showFullScreenPreview() async {
    if (_previewBytes == null && (_previewFilePath ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload an invoice to open the original.'),
        ),
      );
      return;
    }
    await showMovableDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(_previewFileName ?? 'Original Invoice'),
              actions: [
                IconButton(
                  tooltip: 'Rotate',
                  onPressed: () {
                    setState(() {
                      _previewQuarterTurns = (_previewQuarterTurns + 1) % 4;
                    });
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            body: ColoredBox(
              color: const Color(0xFF202124),
              child: SizedBox.expand(child: _buildPreviewCanvas()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiFormPanel(
    Color accentColor,
    List<_AiFieldValidation> checklist,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Compact Entry',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${(_workspaceConfidence * 100).round()}% AI filled',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isParsingUpload ? null : _scanInvoiceFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _isParsingUpload ? null : _pickInvoiceFromGallery,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Image'),
                ),
                OutlinedButton.icon(
                  onPressed: _isParsingUpload
                      ? null
                      : _pickMultipleInvoiceImages,
                  icon: const Icon(Icons.collections_outlined, size: 18),
                  label: const Text('Multi'),
                ),
                OutlinedButton.icon(
                  onPressed: _isParsingUpload ? null : _pickInvoicePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
              ],
            ),
            if (_isParsingUpload) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text(
                'Running OCR extraction and master matching...',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _compactInvoiceDateField()),
                const SizedBox(width: 8),
                Expanded(child: _compactInvoiceNumberField()),
              ],
            ),
            const SizedBox(height: 8),
            _compactCustomerField(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _gstinCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: _confidenceAwareDecoration(
                const InputDecoration(
                  labelText: 'GSTIN',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                fieldKey: 'gstin',
              ),
              onChanged: (_) => _tryMatchCustomerFromInputs(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _compactDisplayField(
                    'GST Type',
                    _isInterStateSupply ? 'Inter-State (IGST)' : 'Intra-State',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _compactDisplayField(
                    'State',
                    _selectedCustomer?.state.isNotEmpty == true
                        ? _selectedCustomer!.state
                        : _placeOfSupply,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _compactPlaceOfSupplyField(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Line Items',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Add product',
                  onPressed: _openQuickProductPicker,
                  icon: const Icon(Icons.add, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            ProductSelector(
              initialRows: _products,
              placeOfSupply: _placeOfSupply,
              operatorCompact: true,
              onProductsChanged: (rows) => setState(() => _products = rows),
            ),
            const SizedBox(height: 8),
            _compactTotals(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Narration',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_statusForCustomer() == _AiFieldStatus.create)
                  FilledButton.icon(
                    onPressed: _createCustomerInline,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Create Customer'),
                  ),
                if (_statusForProducts() == _AiFieldStatus.create)
                  FilledButton.icon(
                    onPressed: _createProductInline,
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: Text(
                      _isResolvingProducts
                          ? 'Resolving...'
                          : 'Resolve Products',
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _requiresVerification
                      ? () => setState(() => _ocrVerified = true)
                      : null,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark Verified'),
                ),
                OutlinedButton.icon(
                  onPressed: _requiresVerification
                      ? () => setState(() => _ocrVerified = false)
                      : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Needs Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isInterStateSupply =>
      _placeOfSupply.trim().toLowerCase() != 'karnataka';

  bool _isLowConfidenceField(String fieldKey) {
    if (!_requiresVerification) return false;
    final parsed = _lastParsedInvoiceData;
    if (parsed == null) return false;
    final confidence = parsed.confidenceFor(
      fieldKey,
      fallback: parsed.extractionConfidence,
    );
    return confidence > 0 && confidence < _aiReviewThreshold;
  }

  InputDecoration _confidenceAwareDecoration(
    InputDecoration base, {
    required String fieldKey,
  }) {
    if (!_isLowConfidenceField(fieldKey)) {
      return base;
    }

    return base.copyWith(
      filled: true,
      fillColor: const Color(0xFFFFF3E0),
      helperText: 'AI confidence below 90%. Please verify.',
      helperStyle: TextStyle(
        color: Colors.deepOrange.shade700,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.deepOrange.shade300, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.deepOrange.shade500, width: 1.8),
      ),
    );
  }

  Widget _compactInvoiceDateField() => TextFormField(
    controller: _invoiceDateCtrl,
    readOnly: true,
    onTap: _pickInvoiceDate,
    decoration: _confidenceAwareDecoration(
      const InputDecoration(
        labelText: 'Date',
        border: OutlineInputBorder(),
        isDense: true,
        suffixIcon: Icon(Icons.calendar_today_outlined, size: 17),
      ),
      fieldKey: 'billDate',
    ),
    validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
  );

  Widget _compactInvoiceNumberField() => TextFormField(
    controller: _invoiceNumberCtrl,
    decoration: _confidenceAwareDecoration(
      const InputDecoration(
        labelText: 'Invoice No',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      fieldKey: 'billNumber',
    ),
    validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
  );

  Widget _compactCustomerField() {
    final customers = context.watch<CustomerService>().customers;
    return Row(
      children: [
        Expanded(
          child: RawAutocomplete<Customer>(
            textEditingController: _customerNameCtrl,
            focusNode: _customerNameFocus,
            displayStringForOption: (customer) => customer.customerName,
            optionsBuilder: (value) {
              final query = value.text.trim().toLowerCase();
              if (query.isEmpty) return customers.take(8);
              return customers.where(
                (customer) =>
                    customer.customerName.toLowerCase().contains(query) ||
                    customer.customerCode.toLowerCase().contains(query) ||
                    customer.gstNumber.toLowerCase().contains(query),
              );
            },
            onSelected: _fillCustomer,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: _confidenceAwareDecoration(
                  const InputDecoration(
                    labelText: 'Customer',
                    hintText: 'Instant search',
                    prefixIcon: Icon(Icons.search, size: 19),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  fieldKey: 'partyName',
                ),
                onChanged: (_) => _tryMatchCustomerFromInputs(),
                onFieldSubmitted: (_) => onSubmitted(),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Customer is required'
                    : null,
              );
            },
            optionsViewBuilder: _buildCustomerOptionsView,
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          key: const ValueKey('sales-inline-create-customer'),
          tooltip: 'Create customer',
          onPressed: _createCustomerInline,
          icon: const Icon(Icons.add, size: 19),
        ),
      ],
    );
  }

  Widget _compactDisplayField(String label, String value) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF6F8FB),
    ),
    child: Text(
      value.isEmpty ? '-' : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    ),
  );

  Widget _compactPlaceOfSupplyField() => Autocomplete<String>(
    initialValue: TextEditingValue(text: _placeOfSupply),
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      return query.isEmpty
          ? _kStates
          : _kStates.where((state) => state.toLowerCase().contains(query));
    },
    onSelected: (state) => setState(() => _placeOfSupply = state),
    optionsViewBuilder: _buildStringOptionsView,
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: const InputDecoration(
          labelText: 'Place of Supply',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (value) => setState(() => _placeOfSupply = value),
        onFieldSubmitted: (_) => onSubmitted(),
      );
    },
  );

  Widget _compactTotals() {
    final cgst = _isInterStateSupply ? 0.0 : _invoiceGstTotal / 2;
    final sgst = _isInterStateSupply ? 0.0 : _invoiceGstTotal / 2;
    final igst = _isInterStateSupply ? _invoiceGstTotal : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _compactDisplayField(
                'Invoice Value',
                _invoiceGrandTotal.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _compactDisplayField(
                'Taxable Value',
                _invoiceTaxableTotal.toStringAsFixed(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _compactDisplayField('CGST', cgst.toStringAsFixed(2)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _compactDisplayField('SGST', sgst.toStringAsFixed(2)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _compactDisplayField('IGST', igst.toStringAsFixed(2)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewFocusOverlay() => Positioned(
    left: 12,
    right: 12,
    bottom: 12,
    child: IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xD9146C43),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF6FE3A5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.center_focus_strong,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'OCR focus: $_activePreviewHighlight',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildAiPreviewPanel(
    Color accentColor,
    List<_AiFieldValidation> checklist,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Uploaded Invoice Preview',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'OCR overlay',
                      onPressed: () {
                        setState(() => _showOcrOverlay = !_showOcrOverlay);
                      },
                      icon: Icon(
                        Icons.document_scanner_outlined,
                        size: 18,
                        color: _showOcrOverlay ? accentColor : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Zoom +',
                      onPressed: () {
                        setState(() {
                          _previewScale = math.min(3.0, _previewScale + 0.15);
                        });
                      },
                      icon: const Icon(Icons.zoom_in, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Zoom -',
                      onPressed: () {
                        setState(() {
                          _previewScale = math.max(0.5, _previewScale - 0.15);
                        });
                      },
                      icon: const Icon(Icons.zoom_out, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Rotate',
                      onPressed: () {
                        setState(() {
                          _previewQuarterTurns = (_previewQuarterTurns + 1) % 4;
                        });
                      },
                      icon: const Icon(Icons.rotate_right, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Fit width',
                      onPressed: () {
                        setState(() {
                          _previewScale = 1.35;
                          _previewQuarterTurns = 0;
                        });
                      },
                      icon: const Icon(Icons.fit_screen, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Fit page',
                      onPressed: () {
                        setState(() {
                          _previewScale = 1.0;
                          _previewQuarterTurns = 0;
                        });
                      },
                      icon: const Icon(Icons.crop_free, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Full screen',
                      onPressed: _showFullScreenPreview,
                      icon: const Icon(Icons.open_in_full, size: 18),
                    ),
                  ],
                ),
                if ((_previewFileName ?? '').isNotEmpty)
                  Text(
                    _previewFileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              child: _buildPreviewCanvas(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: checklist
                  .take(7)
                  .map((item) {
                    final active = _activePreviewHighlight == item.label;
                    return ChoiceChip(
                      label: Text(item.label),
                      selected: active,
                      onSelected: (_) {
                        setState(() {
                          _activePreviewHighlight = item.label;
                        });
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCanvas() {
    final hasPreview =
        _previewBytes != null || (_previewFilePath ?? '').isNotEmpty;
    if (!hasPreview) {
      return const Center(
        child: Text(
          'Upload an image or PDF to preview and verify fields.',
          style: TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_previewIsPdf) {
      final bytesFuture = _previewBytes != null
          ? Future<Uint8List>.value(_previewBytes!)
          : File(_previewFilePath!).readAsBytes();
      return FutureBuilder<Uint8List>(
        future: bytesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              Positioned.fill(
                child: Transform.rotate(
                  angle: _previewQuarterTurns * math.pi / 2,
                  child: PdfPreview(
                    build: (_) async => snapshot.data!,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    useActions: false,
                  ),
                ),
              ),
              if (_showOcrOverlay) _buildPreviewFocusOverlay(),
            ],
          );
        },
      );
    }

    Widget? imageWidget;
    if (_previewBytes != null && _previewBytes!.isNotEmpty) {
      imageWidget = Image.memory(_previewBytes!, fit: BoxFit.contain);
    } else if (!kIsWeb && (_previewFilePath ?? '').isNotEmpty) {
      imageWidget = Image.file(File(_previewFilePath!), fit: BoxFit.contain);
    }

    if (imageWidget == null) {
      return const Center(
        child: Text(
          'Preview is unavailable for this file source on current platform.',
          style: TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Transform.scale(
          scale: _previewScale,
          child: RotatedBox(
            quarterTurns: _previewQuarterTurns,
            child: Stack(
              alignment: Alignment.center,
              children: [
                imageWidget,
                if (_showOcrOverlay) _buildPreviewFocusOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _invoiceInfoCard() => _buildCard(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _invoiceNumberCtrl,
                decoration: _confidenceAwareDecoration(
                  const InputDecoration(
                    labelText: 'Invoice Number',
                    prefixIcon: Icon(Icons.receipt_long),
                    border: OutlineInputBorder(),
                  ),
                  fieldKey: 'billNumber',
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Continue from previous invoice number',
              onPressed: _continueInvoiceNumbering,
              icon: const Icon(Icons.format_list_numbered),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _invoiceDateCtrl,
                readOnly: true,
                onTap: _pickInvoiceDate,
                decoration: _confidenceAwareDecoration(
                  const InputDecoration(
                    labelText: 'Invoice Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  fieldKey: 'billDate',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Customer & Shipping',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _createCustomerInline,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('New  Alt+C'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RawAutocomplete<Customer>(
            textEditingController: _customerNameCtrl,
            focusNode: _customerNameFocus,
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
            fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) =>
                TextFormField(
                  controller: ctrl,
                  focusNode: fn,
                  textInputAction: TextInputAction.done,
                  decoration: _confidenceAwareDecoration(
                    const InputDecoration(
                      labelText: 'Customer Name',
                      prefixIcon: Icon(Icons.person_search),
                      hintText: 'Search name, code, mobile or GSTIN',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    fieldKey: 'partyName',
                  ),
                  onChanged: (_) => _tryMatchCustomerFromInputs(),
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Customer name is required'
                      : null,
                ),
            optionsViewBuilder: _buildCustomerOptionsView,
          ),
          if (_selectedCustomer != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (_selectedCustomer!.mobileNumber.isNotEmpty)
                  _selectedCustomer!.mobileNumber,
                if (_selectedCustomer!.gstNumber.isNotEmpty)
                  _selectedCustomer!.gstNumber,
                if (_billingAddressCtrl.text.trim().isNotEmpty)
                  _billingAddressCtrl.text.trim(),
              ].join(' | '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Ship to another customer/address'),
            value: _shipToAnotherCustomer,
            onChanged: (value) => setState(() {
              _shipToAnotherCustomer = value ?? false;
              if (!_shipToAnotherCustomer) {
                _shippingCustomer = null;
                _shippingAddressCtrl.text =
                    _selectedCustomer?.shippingAddress.isNotEmpty == true
                    ? _selectedCustomer!.shippingAddress
                    : _billingAddressCtrl.text;
              }
            }),
          ),
          if (_shipToAnotherCustomer) ...[
            SearchableDropdownFormField<Customer>(
              value: _shippingCustomer,
              items: customers,
              itemLabelBuilder: (customer) =>
                  '${customer.customerName} | ${customer.shippingAddress.isEmpty ? customer.billingAddress : customer.shippingAddress}',
              dialogTitle: 'Select Shipping Customer',
              decoration: const InputDecoration(
                labelText: 'Shipping Customer (optional)',
                prefixIcon: Icon(Icons.local_shipping_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onCreate: () => _createCustomerInline(selectAsBilling: false),
              createLabel: 'Create Customer',
              onChanged: (customer) {
                if (customer == null) return;
                setState(() {
                  _shippingCustomer = customer;
                  _shippingAddressCtrl.text =
                      customer.shippingAddress.isNotEmpty
                      ? customer.shippingAddress
                      : customer.billingAddress;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
          TextFormField(
            controller: _shippingAddressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Shipping Address (editable)',
              prefixIcon: Icon(Icons.local_shipping),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceCard() => _buildCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reference Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _responsiveFieldRow([
          _paymentTermsField(),
          TextFormField(
            controller: _poNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'PO Number',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _responsiveFieldRow([
          TextFormField(
            controller: _poDateCtrl,
            readOnly: true,
            onTap: () => _pickDate(_poDateCtrl),
            decoration: const InputDecoration(
              labelText: 'PO Date',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          TextFormField(
            controller: _projectNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Project',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          TextFormField(
            controller: _refNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ]),
      ],
    ),
  );

  Widget _paymentStatusCard() => _buildCard(
    child: ExpansionTile(
      initiallyExpanded: _paymentStatusExpanded,
      onExpansionChanged: (expanded) {
        setState(() => _paymentStatusExpanded = expanded);
      },
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      leading: const Icon(Icons.payments_outlined),
      title: const Text(
        'Payment Status',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_invoicePaymentStatus.name == 'fullyPaid'
            ? 'Fully Paid'
            : _invoicePaymentStatus.name == 'partiallyPaid'
            ? 'Partially Paid'
            : 'Credit'} | Outstanding: Rs. ${_outstandingAmount.toStringAsFixed(2)}',
      ),
      children: [
        SegmentedButton<InvoicePaymentStatus>(
          segments: const [
            ButtonSegment(
              value: InvoicePaymentStatus.fullyPaid,
              label: Text('Fully Paid'),
            ),
            ButtonSegment(
              value: InvoicePaymentStatus.partiallyPaid,
              label: Text('Partially Paid'),
            ),
            ButtonSegment(
              value: InvoicePaymentStatus.credit,
              label: Text('Credit'),
            ),
          ],
          selected: {_invoicePaymentStatus},
          onSelectionChanged: (selection) {
            _onInvoicePaymentStatusChanged(selection.first);
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _receivedAmountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount Received',
            prefixIcon: Icon(Icons.currency_rupee),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text(
          'Outstanding: Rs. ${_outstandingAmount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SearchableDropdownFormField<String>(
          value: _invoicePaymentMode,
          decoration: const InputDecoration(
            labelText: 'Payment Mode',
            prefixIcon: Icon(Icons.payments_outlined),
            border: OutlineInputBorder(),
          ),
          items: _kPaymentTerms
              .where(
                (term) => const [
                  'Cash',
                  'Bank Transfer / NEFT',
                  'RTGS',
                  'UPI',
                  'Cheque',
                ].contains(term),
              )
              .toList(growable: false),
          itemLabelBuilder: (mode) => mode,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _invoicePaymentMode = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _paymentReferenceCtrl,
          decoration: const InputDecoration(
            labelText: 'Payment Reference Number',
            prefixIcon: Icon(Icons.tag),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _paymentDateCtrl,
          readOnly: true,
          onTap: () => _pickDate(_paymentDateCtrl),
          decoration: const InputDecoration(
            labelText: 'Receive Date',
            prefixIcon: Icon(Icons.event),
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
              isDense: true,
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
                          hintText: 'Search payment terms�',
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

  Widget _eInvoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              setState(() => _eInvoiceApplicable = !_eInvoiceApplicable),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _eInvoiceApplicable
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _eInvoiceApplicable
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: _eInvoiceApplicable
                      ? Colors.green.shade700
                      : Colors.grey,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-Invoicing (IRP / GST Portal)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Enable for businesses above e-invoice threshold',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _eInvoiceApplicable,
                  onChanged: (v) =>
                      setState(() => _eInvoiceApplicable = v),
                ),
              ],
            ),
          ),
        ),
        if (_eInvoiceApplicable) ...[
          const SizedBox(height: 10),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 4),
                    _buildIrnStatusChip(),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _irnCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'IRN (Invoice Reference Number)',
                    prefixIcon: Icon(Icons.tag_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '64-character hash from IRP',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ackNoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Acknowledgement No',
                          prefixIcon: Icon(
                              Icons.confirmation_number_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _ackDateCtrl,
                        readOnly: true,
                        onTap: () => _pickDate(_ackDateCtrl),
                        decoration: const InputDecoration(
                          labelText: 'Acknowledgement Date',
                          prefixIcon: Icon(Icons.event_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(
                              Icons.calendar_today_outlined,
                              size: 17),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIrnStatusChip() {
    final hasIrn = _irnCtrl.text.trim().isNotEmpty;
    return Chip(
      avatar: Icon(
        hasIrn ? Icons.check_circle_outline : Icons.schedule_outlined,
        size: 15,
        color: hasIrn ? Colors.green.shade700 : Colors.orange.shade700,
      ),
      label: Text(
        hasIrn ? 'IRN Generated' : 'IRN not generated',
        style: TextStyle(
          fontSize: 11,
          color:
              hasIrn ? Colors.green.shade700 : Colors.orange.shade700,
        ),
      ),
      backgroundColor:
          hasIrn ? Colors.green.shade50 : Colors.orange.shade50,
      side: BorderSide(
        color:
            hasIrn ? Colors.green.shade200 : Colors.orange.shade200,
      ),
      padding: EdgeInsets.zero,
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

  Future<void> _saveInvoice({
    bool openOutput = true,
    bool resetAfterSave = false,
  }) async {
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
    final confidence = _workspaceConfidence;
    if (_showAiWorkspace && confidence < 0.70 && !_isManualWorkspace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Manual verification required. Current AI confidence is ${(confidence * 100).toStringAsFixed(0)}%.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_requiresVerification && !_ocrVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please verify uploaded OCR data and tick confirmation before saving',
          ),
        ),
      );
      return;
    }
    if (_showAiWorkspace &&
        confidence < 0.95 &&
        !_ocrVerified &&
        !_isManualWorkspace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Confidence is ${(confidence * 100).toStringAsFixed(0)}%. Please review exceptions and mark as verified before saving.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_lastDocumentAnalysis != null &&
        !_isSalesCompatible(_lastDocumentAnalysis!.kind)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Detected ${_documentKindLabel(_lastDocumentAnalysis!.kind)}. Use related module for accurate posting.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_lastParsedInvoiceData != null && !_uploadedInvoiceBelongsToBusiness) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This invoice is not related to your business.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final salesService = context.read<SalesService>();
    final duplicate = salesService.findByInvoiceNumber(
      _invoiceNumberCtrl.text.trim(),
    );
    if (duplicate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Duplicate invoice detected: ${duplicate.invoiceNumber} already exists for ${duplicate.customerName}.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final invoiceDate = DateTime.parse(_invoiceDateCtrl.text);
      final user = context.read<AuthController>().currentUser;
      final accountingPolicy = context.read<AccountingPolicyService>();
      if (user?.role.isClient ?? false) {
        accountingPolicy.validateClientSubmissionDate(invoiceDate);
      }
      accountingPolicy.validateOpenPeriod(
        clientId: user?.id ?? 'shared-books',
        date: invoiceDate,
      );
      final dueDateText = _dueDateCtrl.text.trim();
      final dueDate = dueDateText.isEmpty
          ? invoiceDate
          : DateTime.parse(dueDateText);
      final receivedAmount = _receivedAmount;
      final invoiceTotal = _invoiceGrandTotal;
      if (receivedAmount < 0 || receivedAmount > invoiceTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Received amount must be between 0 and invoice total.',
            ),
          ),
        );
        return;
      }

      final customerService = context.read<CustomerService>();
      var customer = customerService.findIdentityMatch(
        _customerNameCtrl.text.trim(),
        gstNumber: _gstinCtrl.text.trim(),
        mobileNumber: normalizeIndianMobile(_mobileCtrl.text),
      );
      if (customer == null) {
        customer = Customer(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          customerCode: customerService.nextCustomerCode(),
          customerName: _customerNameCtrl.text.trim(),
          companyName: _customerNameCtrl.text.trim(),
          mobileNumber: normalizeIndianMobile(_mobileCtrl.text),
          gstNumber: _gstinCtrl.text.trim().toUpperCase(),
          billingAddress: _billingAddressCtrl.text.trim(),
          shippingAddress: _shippingAddressCtrl.text.trim(),
          state: _placeOfSupply,
          isActive: true,
        );
        customer = customerService.addCustomerWithLedger(
          customer,
          context.read<LedgerService?>(),
        );
      }
      _selectedCustomer = customer;

      final items = _products
          .map(
            (p) => SalesItem(
              id: p.id,
              productName: p.productName ?? '',
              description: p.description,
              hsnCode: p.hsnCode ?? '',
              unit: p.unit ?? 'Pc',
              isCharge: p.isCharge,
              accountingLedger: p.accountingLedger,
              quantity: p.quantity,
              rate: p.rate,
              discount: p.discount,
              gstPercentage: p.gstPercentage,
            ),
          )
          .toList();

      final clientProfile = user == null
          ? null
          : await ClientProfileService().load(user.id);
      if (!mounted) return;
      final sellerAddress = <String>[
        if (clientProfile?.address.trim().isNotEmpty == true)
          clientProfile!.address.trim(),
        if (clientProfile?.city.trim().isNotEmpty == true)
          clientProfile!.city.trim(),
        if (clientProfile?.state.trim().isNotEmpty == true)
          clientProfile!.state.trim(),
        if (clientProfile?.pincode.trim().isNotEmpty == true)
          clientProfile!.pincode.trim(),
      ].join(', ');

      final invoice = SalesInvoice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdByUserId: user?.id ?? '',
        createdByClient: user?.role.isClient ?? false,
        invoiceType: widget.invoiceType,
        invoiceNumber: _invoiceNumberCtrl.text.trim(),
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        sellerName: clientProfile?.firmName.trim().isNotEmpty == true
            ? clientProfile!.firmName.trim()
            : user?.firmName ?? '',
        sellerAddress: sellerAddress,
        sellerGstin: clientProfile?.gstin.trim().toUpperCase() ?? '',
        sellerPan: clientProfile?.pan.trim().toUpperCase() ?? '',
        customerName:
            _selectedCustomer?.customerName ?? _customerNameCtrl.text.trim(),
        customerMobile: normalizeIndianMobile(_mobileCtrl.text),
        customerEmail: _selectedCustomer?.email ?? '',
        gstNumber: _gstinCtrl.text.trim(),
        panNumber: _selectedCustomer?.panNumber ?? '',
        billingAddress: _billingAddressCtrl.text.trim(),
        shippingCustomerName:
            _shippingCustomer?.customerName ??
            _selectedCustomer?.customerName ??
            _customerNameCtrl.text.trim(),
        shippingAddress: _shippingAddressCtrl.text.trim(),
        placeOfSupply: _placeOfSupply,
        items: items,
        status: _invoicePaymentStatus == InvoicePaymentStatus.fullyPaid
            ? InvoiceStatus.paid
            : InvoiceStatus.pending,
        notes: _notesCtrl.text.trim(),
        paymentStatus: _invoicePaymentStatus,
        receivedAmount: receivedAmount,
        outstandingAmount: invoiceTotal - receivedAmount,
        paymentMode: _invoicePaymentMode,
        paymentReference: _paymentReferenceCtrl.text.trim(),
        paymentDate: _paymentDateCtrl.text.trim().isEmpty
            ? null
            : DateTime.tryParse(_paymentDateCtrl.text.trim()),
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
        eInvoiceApplicable: _eInvoiceApplicable,
        irn: _irnCtrl.text.trim(),
        ackNo: _ackNoCtrl.text.trim(),
        ackDate: _ackDateCtrl.text.trim().isEmpty
            ? null
            : DateTime.tryParse(_ackDateCtrl.text.trim()),
        shipToDifferent: _shipToAnotherCustomer,
        attachmentPaths: _attachmentPaths,
      );

      salesService.addInvoice(invoice);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_screenLabel ${invoice.invoiceNumber} saved. Received: Rs. ${receivedAmount.toStringAsFixed(2)}, Outstanding: Rs. ${(invoiceTotal - receivedAmount).toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      if (resetAfterSave) {
        _resetForNewInvoice();
        if (mounted) {
          setState(() {});
        }
        return;
      }
      if (!openOutput) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceOutputScreen(invoice: invoice),
        ),
      );
    } on AccountingPolicyException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
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

  void _resetForNewInvoice() {
    final salesService = context.read<SalesService>();
    _invoiceNumberCtrl.text = _isTaxInvoice
        ? salesService.generateNextTaxInvoiceNumber()
        : salesService.generateNextInvoiceNumber();
    _invoiceDateCtrl.text = DateTime.now().toString().split(' ')[0];
    _dueDateCtrl.text = _invoiceDateCtrl.text;
    _receivedAmountCtrl.text = '0';
    _paymentReferenceCtrl.clear();
    _paymentDateCtrl.text = _invoiceDateCtrl.text;
    _poNumberCtrl.clear();
    _poDateCtrl.clear();
    _projectNameCtrl.clear();
    _refNumberCtrl.clear();
    _customerNameCtrl.clear();
    _mobileCtrl.clear();
    _gstinCtrl.clear();
    _billingAddressCtrl.clear();
    _shippingAddressCtrl.clear();
    _transporterNameCtrl.clear();
    _transporterGstinCtrl.clear();
    _transportDocNoCtrl.clear();
    _transportDateCtrl.clear();
    _vehicleNumberCtrl.clear();
    _distanceKmCtrl.clear();
    _ewayBillNoCtrl.clear();
    _ewayBillDateCtrl.clear();
    _irnCtrl.clear();
    _ackNoCtrl.clear();
    _ackDateCtrl.clear();
    _eInvoiceApplicable = false;
    _notesCtrl.clear();
    _products = <ProductRow>[ProductRow(id: DateTime.now().microsecondsSinceEpoch.toString())];
    _attachmentPaths = <String>[];
    _previewBytes = null;
    _previewFilePath = null;
    _previewFileName = null;
    _previewIsPdf = false;
    _selectedCustomer = null;
    _shippingCustomer = null;
    _shipToAnotherCustomer = false;
    _showTransport = false;
    _transportMode = '';
    _invoicePaymentStatus = InvoicePaymentStatus.credit;
    _invoicePaymentMode = 'Cash';
    _paymentTerms = '';
    _requiresVerification = false;
    _ocrVerified = false;
    _lastDocumentAnalysis = null;
    _lastParsedInvoiceData = null;
    _ocrTextCtrl.clear();
    _activePreviewHighlight = 'Invoice Number';
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
