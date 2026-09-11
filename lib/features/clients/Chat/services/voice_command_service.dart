import 'package:chirag_accounting/features/products/models/product.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/vouchers/presentation/models/voucher_entry_type.dart';

enum VoiceCommandRoute { uiCommand, erpCommand, transcriptOnly }

enum VoiceUiAction {
  openBilling,
  openPurchase,
  openReports,
  openBanking,
  openUploads,
  searchCustomer,
}

enum VoiceErpAction {
  createVoucher,
  printInvoice,
  createSalesInvoice,
  createPurchaseVoucher,
}

class VoiceCommandDecision {
  const VoiceCommandDecision({
    required this.route,
    required this.intent,
    required this.transcript,
    required this.summary,
    this.uiAction,
    this.erpAction,
    this.voucherEntryType,
    this.matchedCustomerName,
    this.matchedProductName,
    this.permissionDeniedReason,
  });

  final VoiceCommandRoute route;
  final String intent;
  final String transcript;
  final String summary;
  final VoiceUiAction? uiAction;
  final VoiceErpAction? erpAction;
  final VoucherEntryType? voucherEntryType;
  final String? matchedCustomerName;
  final String? matchedProductName;
  final String? permissionDeniedReason;

  bool get isDenied => permissionDeniedReason != null;
}

class VoiceCommandService {
  VoiceCommandService({
    required CustomerService customerService,
    required ProductService productService,
  }) : _customerService = customerService,
       _productService = productService;

  final CustomerService _customerService;
  final ProductService _productService;

  VoiceCommandDecision analyze({
    required String transcript,
    required UserRole? role,
    required Set<String> allowedModuleIds,
  }) {
    final normalized = _normalizeText(transcript);
    final matchedCustomer = _matchCustomer(transcript);
    final matchedProduct = _matchProduct(transcript);

    final uiAction = _detectUiAction(normalized);
    if (uiAction != null) {
      final deniedReason = _uiPermissionDeniedReason(
        uiAction,
        role: role,
        allowedModuleIds: allowedModuleIds,
      );
      return VoiceCommandDecision(
        route: VoiceCommandRoute.uiCommand,
        intent: _uiIntentLabel(uiAction),
        transcript: transcript,
        summary: _summaryFor(
          base: 'Voice UI command detected: ${_uiIntentLabel(uiAction)}.',
          matchedCustomerName: matchedCustomer,
          matchedProductName: matchedProduct,
        ),
        uiAction: uiAction,
        matchedCustomerName: matchedCustomer,
        matchedProductName: matchedProduct,
        permissionDeniedReason: deniedReason,
      );
    }

    final erpAction = _detectErpAction(normalized);
    final voucherType = _extractVoucherType(normalized);
    if (erpAction != null) {
      final deniedReason = _erpPermissionDeniedReason(
        erpAction,
        voucherType: voucherType,
        role: role,
        allowedModuleIds: allowedModuleIds,
      );
      return VoiceCommandDecision(
        route: VoiceCommandRoute.erpCommand,
        intent: _erpIntentLabel(erpAction, voucherType),
        transcript: transcript,
        summary: _summaryFor(
          base:
              'Voice ERP command detected: ${_erpIntentLabel(erpAction, voucherType)}. Routing to command engine.',
          matchedCustomerName: matchedCustomer,
          matchedProductName: matchedProduct,
        ),
        erpAction: erpAction,
        voucherEntryType: voucherType,
        matchedCustomerName: matchedCustomer,
        matchedProductName: matchedProduct,
        permissionDeniedReason: deniedReason,
      );
    }

    return VoiceCommandDecision(
      route: VoiceCommandRoute.transcriptOnly,
      intent: 'transcript_only',
      transcript: transcript,
      summary: _summaryFor(
        base: 'Voice transcript captured. Review or send manually.',
        matchedCustomerName: matchedCustomer,
        matchedProductName: matchedProduct,
      ),
      matchedCustomerName: matchedCustomer,
      matchedProductName: matchedProduct,
    );
  }

  VoiceUiAction? _detectUiAction(String text) {
    if (_containsAny(text, const <String>[
      'sales kholo',
      'open sales',
      'open billing',
      'billing kholo',
      'invoice screen kholo',
      'billing khol do',
      'sales dikhao',
      'bill screen kholo',
      'सेल्स खोलो',
      'बिलिंग खोलो',
      'बिलिंग खोल दो',
    ])) {
      return VoiceUiAction.openBilling;
    }
    if (_containsAny(text, const <String>[
      'purchase kholo',
      'open purchase',
      'purchase screen kholo',
      'purchase khol do',
      'खरीद खोलो',
      'परचेस खोलो',
      'परचेस खोल दो',
    ])) {
      return VoiceUiAction.openPurchase;
    }
    if (_containsAny(text, const <String>[
      'report kholo',
      'reports kholo',
      'open reports',
      'show report',
      'report dikhao',
      'reports dikhao',
      'रिपोर्ट खोलो',
      'रिपोर्ट दिखाओ',
    ])) {
      return VoiceUiAction.openReports;
    }
    if (_containsAny(text, const <String>[
      'bank kholo',
      'open bank',
      'payment kholo',
      'receipt kholo',
      'bank khol do',
      'बैंक खोलो',
      'पेमेंट खोलो',
      'रिसीट खोलो',
    ])) {
      return VoiceUiAction.openBanking;
    }
    if (_containsAny(text, const <String>[
      'upload kholo',
      'open upload',
      'document upload',
      'ocr kholo',
      'upload khol do',
      'दस्तावेज upload',
      'डॉक्यूमेंट upload',
      'अपलोड खोलो',
      'ओसीआर खोलो',
    ])) {
      return VoiceUiAction.openUploads;
    }
    if (_containsAny(text, const <String>[
      'search customer',
      'find customer',
      'customer search',
      'party search',
      'customer dhoondo',
      'party dhoondo',
      'customer dikhao',
      'party dikhao',
      'ग्राहक ढूंढो',
      'कस्टमर ढूंढो',
    ])) {
      return VoiceUiAction.searchCustomer;
    }
    return null;
  }

  VoiceErpAction? _detectErpAction(String text) {
    if (_containsAny(text, const <String>[
      'print invoice',
      'invoice print',
      'invoice print karo',
      'bill print',
      'प्रिंट invoice',
      'invoice प्रिंट',
    ])) {
      return VoiceErpAction.printInvoice;
    }

    if (_containsAny(text, const <String>[
      'sales invoice create',
      'invoice banao',
      'bill banana',
      'sales bill banao',
      'सेल्स invoice बनाओ',
      'बिल बनाओ',
    ])) {
      return VoiceErpAction.createSalesInvoice;
    }

    if (_containsAny(text, const <String>[
      'purchase voucher banao',
      'purchase bill banao',
      'create purchase',
      'purchase invoice create',
      'परचेस voucher बनाओ',
      'खरीद voucher बनाओ',
    ])) {
      return VoiceErpAction.createPurchaseVoucher;
    }

    if (_containsAny(text, const <String>[
      'create voucher',
      'voucher banao',
      'create receipt',
      'receipt banao',
      'create payment',
      'payment banao',
      'journal voucher',
      'credit note',
      'debit note',
      'entry banao',
      'voucher create karo',
      'voucher taiyar karo',
      'voucher बनाओ',
      'रिसीट बनाओ',
      'पेमेंट बनाओ',
      'जर्नल voucher',
      'क्रेडिट note',
      'डेबिट note',
    ])) {
      return VoiceErpAction.createVoucher;
    }

    return null;
  }

  String? _uiPermissionDeniedReason(
    VoiceUiAction action, {
    required UserRole? role,
    required Set<String> allowedModuleIds,
  }) {
    if (role != UserRole.client) {
      return null;
    }

    final requiredModule = switch (action) {
      VoiceUiAction.openBilling => 'sales',
      VoiceUiAction.openPurchase => 'purchase',
      VoiceUiAction.openReports => 'reports',
      VoiceUiAction.openBanking => 'bank',
      VoiceUiAction.openUploads => 'uploads',
      VoiceUiAction.searchCustomer => 'customers',
    };

    if (allowedModuleIds.contains(requiredModule)) {
      return null;
    }

    return 'You do not have permission for ${_uiIntentLabel(action)} in this client portal.';
  }

  String? _erpPermissionDeniedReason(
    VoiceErpAction action, {
    required VoucherEntryType? voucherType,
    required UserRole? role,
    required Set<String> allowedModuleIds,
  }) {
    if (role != UserRole.client) {
      return null;
    }

    final requiredModule = switch (action) {
      VoiceErpAction.createVoucher => 'voucher_upload',
      VoiceErpAction.printInvoice => 'sales',
      VoiceErpAction.createSalesInvoice => 'sales',
      VoiceErpAction.createPurchaseVoucher => 'purchase',
    };

    if (allowedModuleIds.contains(requiredModule)) {
      return null;
    }

    return 'You do not have permission for ${_erpIntentLabel(action, voucherType)} in this client portal.';
  }

  String _uiIntentLabel(VoiceUiAction action) {
    switch (action) {
      case VoiceUiAction.openBilling:
        return 'open billing';
      case VoiceUiAction.openPurchase:
        return 'open purchase';
      case VoiceUiAction.openReports:
        return 'open reports';
      case VoiceUiAction.openBanking:
        return 'open banking';
      case VoiceUiAction.openUploads:
        return 'open uploads';
      case VoiceUiAction.searchCustomer:
        return 'search customer';
    }
  }

  String _erpIntentLabel(
    VoiceErpAction action,
    VoucherEntryType? voucherType,
  ) {
    switch (action) {
      case VoiceErpAction.createVoucher:
        return voucherType == null
            ? 'create voucher'
            : 'create ${voucherType.name} voucher';
      case VoiceErpAction.printInvoice:
        return 'print invoice';
      case VoiceErpAction.createSalesInvoice:
        return 'create sales invoice';
      case VoiceErpAction.createPurchaseVoucher:
        return 'create purchase voucher';
    }
  }

  String _summaryFor({
    required String base,
    required String? matchedCustomerName,
    required String? matchedProductName,
  }) {
    final parts = <String>[base];
    if (matchedCustomerName != null && matchedCustomerName.isNotEmpty) {
      parts.add('Matched customer: $matchedCustomerName.');
    }
    if (matchedProductName != null && matchedProductName.isNotEmpty) {
      parts.add('Matched product: $matchedProductName.');
    }
    return parts.join(' ');
  }

  String? _matchCustomer(String transcript) {
    final candidate = _candidateAfterKeywords(
      transcript,
      const <String>[
        'customer',
        'party',
        'client',
        'kustomer',
        'grahak',
        'ग्राहक',
        'कस्टमर',
        'पार्टी',
      ],
    );
    final direct = _customerService.findIdentityMatch(
      candidate.isEmpty ? transcript : candidate,
    );
    if (direct != null) {
      return direct.customerName;
    }
    final searchText = candidate.isEmpty ? transcript : candidate;
    final matches = _customerService.searchCustomers(searchText.trim());
    if (matches.isNotEmpty) {
      return matches.first.customerName;
    }

    final normalizedTranscript = _normalizeText(transcript);
    for (final customer in _customerService.customers) {
      final normalizedName = _normalizeText(customer.customerName);
      if (normalizedName.isNotEmpty &&
          normalizedTranscript.contains(normalizedName)) {
        return customer.customerName;
      }
      final normalizedCompany = _normalizeText(customer.companyName);
      if (normalizedCompany.isNotEmpty &&
          normalizedTranscript.contains(normalizedCompany)) {
        return customer.customerName;
      }
    }

    return null;
  }

  String? _matchProduct(String transcript) {
    final candidate = _candidateAfterKeywords(
      transcript,
      const <String>[
        'product',
        'item',
        'material',
        'maal',
        'samaan',
        'उत्पाद',
        'आइटम',
        'मटेरियल',
        'सामान',
      ],
    );
    final probe = candidate.isEmpty ? transcript : candidate;
    final products = _productService.searchProducts(probe);
    if (products.isNotEmpty) {
      final exact = _exactProduct(products, probe);
      return (exact ?? products.first).productName;
    }

    final normalizedTranscript = _normalizeText(transcript);
    for (final product in _productService.products) {
      final normalizedName = _normalizeText(product.productName);
      if (normalizedName.isNotEmpty &&
          normalizedTranscript.contains(normalizedName)) {
        return product.productName;
      }
    }

    return null;
  }

  Product? _exactProduct(List<Product> products, String probe) {
    final normalized = probe.trim().toLowerCase();
    for (final product in products) {
      if (product.productName.trim().toLowerCase() == normalized) {
        return product;
      }
    }
    return null;
  }

  VoucherEntryType? _extractVoucherType(String text) {
    if (_containsAny(text, const <String>[
      'receipt',
      'receipt banao',
      'rasiid',
      'rasid',
      'रसीद',
      'रिसीट',
    ])) {
      return VoucherEntryType.receipt;
    }
    if (_containsAny(text, const <String>[
      'payment',
      'payment banao',
      'bhugtan',
      'भुगतान',
      'पेमेंट',
    ])) {
      return VoucherEntryType.payment;
    }
    if (_containsAny(text, const <String>[
      'journal',
      'journal voucher',
      'जर्नल',
    ])) {
      return VoucherEntryType.journal;
    }
    if (_containsAny(text, const <String>[
      'contra',
      'cash transfer',
      'bank transfer',
      'कॉन्ट्रा',
    ])) {
      return VoucherEntryType.contra;
    }
    if (_containsAny(text, const <String>[
      'sales',
      'sales voucher',
      'sales invoice',
      'सेल्स',
      'बिक्री',
    ])) {
      return VoucherEntryType.sales;
    }
    if (_containsAny(text, const <String>[
      'purchase',
      'purchase voucher',
      'purchase bill',
      'परचेस',
      'खरीद',
    ])) {
      return VoucherEntryType.purchase;
    }
    if (_containsAny(text, const <String>[
      'credit note',
      'sales return',
      'क्रेडिट note',
    ])) {
      return VoucherEntryType.creditNote;
    }
    if (_containsAny(text, const <String>[
      'debit note',
      'purchase return',
      'डेबिट note',
    ])) {
      return VoucherEntryType.debitNote;
    }
    if (_containsAny(text, const <String>[
      'expense',
      'kharch',
      'खर्च',
    ])) {
      return VoucherEntryType.expense;
    }
    if (_containsAny(text, const <String>[
      'income',
      'aay',
      'आय',
    ])) {
      return VoucherEntryType.income;
    }
    return null;
  }

  String _normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _candidateAfterKeywords(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    for (final keyword in keywords) {
      final index = lower.indexOf('$keyword ');
      if (index < 0) continue;
      final value = text.substring(index + keyword.length).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  bool _containsAny(String value, List<String> tokens) {
    return tokens.any(value.contains);
  }
}