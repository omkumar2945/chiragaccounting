// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_item.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/sales/models/sales_item.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/features/services/gst_portal_lookup_service.dart';

Widget buildSalesVoucherWebEmbed(
  String sourcePath, {
  required SalesService salesService,
  required PurchaseService purchaseService,
  VoidCallback? onOpenBusinessTemplate,
}) {
  return _SalesVoucherWebEmbed(
    sourcePath: sourcePath,
    salesService: salesService,
    purchaseService: purchaseService,
    onOpenBusinessTemplate: onOpenBusinessTemplate,
  );
}

class _SalesVoucherWebEmbed extends StatefulWidget {
  const _SalesVoucherWebEmbed({
    required this.sourcePath,
    required this.salesService,
    required this.purchaseService,
    this.onOpenBusinessTemplate,
  });

  final String sourcePath;
  final SalesService salesService;
  final PurchaseService purchaseService;
  final VoidCallback? onOpenBusinessTemplate;

  @override
  State<_SalesVoucherWebEmbed> createState() => _SalesVoucherWebEmbedState();
}

class _SalesVoucherWebEmbedState extends State<_SalesVoucherWebEmbed> {
  static final Set<String> _registeredViewTypes = <String>{};

  late final String _viewType;
  html.EventListener? _messageListener;

  @override
  void initState() {
    super.initState();
    _messageListener = (html.Event event) {
      if (event is! html.MessageEvent || event.data is! Map) return;
      final data = Map<String, dynamic>.from(event.data as Map);
      if (data['source'] != 'sales-voucher-system') return;
      if (data['type'] == 'open-business-template') {
        widget.onOpenBusinessTemplate?.call();
      } else if (data['type'] == 'voucher-saved') {
        _recordVoucher(data);
      } else if (data['type'] == 'validate-gstin') {
        _validateGstinForVoucher(event, data);
      }
    };
    html.window.addEventListener('message', _messageListener!);
    _viewType = 'sales-voucher-system-iframe-${widget.sourcePath.hashCode}';
    if (_registeredViewTypes.add(_viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        return html.IFrameElement()
          ..src = widget.sourcePath
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'clipboard-read; clipboard-write';
      });
    }
  }

  Future<void> _validateGstinForVoucher(
    html.MessageEvent event,
    Map<String, dynamic> data,
  ) async {
    final requestId = data['requestId'] as String? ?? '';
    final gstin = data['gstin'] as String? ?? '';
    if (requestId.isEmpty) return;

    final result = await GstPortalLookupService().fetchTaxpayerByGstin(gstin);
    final profile = result.profile;
    final response = <String, dynamic>{
      'source': 'chirag-accounting-host',
      'type': 'gstin-validation-result',
      'requestId': requestId,
      'message': result.message,
      if (profile != null)
        'profile': <String, String>{
          'gstin': profile.gstin,
          'legalName': profile.legalName,
          'tradeName': profile.tradeName,
          'address': profile.address,
          'state': profile.state,
          'pincode': profile.pincode,
          'email': profile.email,
          'mobile': profile.mobile,
        },
    };
    final source = event.source;
    if (source is html.Window) {
      source.postMessage(response, '*');
    }
  }

  void _recordVoucher(Map<String, dynamic> data) {
    final voucherType = data['voucherType'] as String? ?? '';
    if (voucherType != 'Sales' && voucherType != 'Purchase') return;
    final header = Map<String, dynamic>.from(
      data['header'] as Map? ?? const <String, dynamic>{},
    );
    final totals = Map<String, dynamic>.from(
      data['totals'] as Map? ?? const <String, dynamic>{},
    );
    final rows = (data['rows'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final date =
        DateTime.tryParse(header['voucherDate'] as String? ?? '') ??
        DateTime.now();
    final number = (data['invoiceNo'] as String? ?? '').trim();
    if (number.isEmpty) return;
    final billingLocation = _addressFrom(header['billingLocation']);
    final shippingLocation = _addressFrom(header['shippingLocation']);
    if (voucherType == 'Sales') {
      if (widget.salesService.findByInvoiceNumber(number) != null) return;
      widget.salesService.addInvoice(
        SalesInvoice(
          id: 'web-sales-${data['voucherNo']}',
          createdByUserId: data['clientId'] as String? ?? '',
          createdByClient: true,
          invoiceNumber: number,
          invoiceDate: date,
          dueDate: date,
          customerName: header['partyName'] as String? ?? 'Walk-in Customer',
          gstNumber: header['partyGSTIN'] as String? ?? '',
            billingAddress: billingLocation?.enteredAddress ?? '',
            shippingAddress: shippingLocation?.enteredAddress ?? '',
            billingLocation: billingLocation,
            shippingLocation: shippingLocation,
            placeOfSupply:
              billingLocation?.stateName ??
              header['placeOfSupply'] as String? ??
              '',
          notes: header['reason'] as String? ?? '',
          outstandingAmount: (totals['grandTotal'] as num?)?.toDouble() ?? 0,
          items: rows
              .map(
                (row) => SalesItem(
                  id: row['id'] as String? ?? 'item-${row['itemName']}',
                  productName: row['itemName'] as String? ?? '',
                  hsnCode: row['hsn'] as String? ?? '',
                  unit: row['unit'] as String? ?? 'Nos',
                  quantity: (row['qty'] as num?)?.toDouble() ?? 0,
                  rate: (row['rate'] as num?)?.toDouble() ?? 0,
                  discount:
                      ((row['qty'] as num?)?.toDouble() ?? 0) *
                      ((row['rate'] as num?)?.toDouble() ?? 0) *
                      ((row['discountPercent'] as num?)?.toDouble() ?? 0) /
                      100,
                  gstPercentage: (row['gstPercent'] as num?)?.toDouble() ?? 0,
                  attributes: _stringAttributes(row['attributes']),
                ),
              )
              .toList(growable: false),
        ),
      );
      return;
    }
    if (widget.purchaseService.findByBillNumber(number) != null) return;
    widget.purchaseService.addBill(
      PurchaseBill(
        id: 'web-purchase-${data['voucherNo']}',
        billNumber: number,
        billDate: date,
        vendorName: header['partyName'] as String? ?? 'Vendor',
        vendorGstin: header['partyGSTIN'] as String? ?? '',
        vendorAddress: billingLocation?.enteredAddress ?? '',
        vendorLocation: billingLocation,
        mode: PurchaseEntryMode.manual,
        notes: header['reason'] as String? ?? '',
        outstandingAmount: (totals['grandTotal'] as num?)?.toDouble() ?? 0,
        items: rows
            .map(
              (row) => PurchaseItem(
                id: row['id'] as String? ?? 'item-${row['itemName']}',
                productName: row['itemName'] as String? ?? '',
                hsnCode: row['hsn'] as String? ?? '',
                unit: row['unit'] as String? ?? 'Nos',
                quantity: (row['qty'] as num?)?.toDouble() ?? 0,
                rate: (row['rate'] as num?)?.toDouble() ?? 0,
                gstPercentage: (row['gstPercent'] as num?)?.toDouble() ?? 0,
                attributes: _stringAttributes(row['attributes']),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Map<String, String> _stringAttributes(Object? value) {
    if (value is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in value.entries)
        if (entry.key is String && entry.value != null)
          entry.key as String: entry.value.toString(),
    };
  }

  StandardAddress? _addressFrom(Object? value) {
    if (value is! Map) return null;
    final address = StandardAddress.fromMap(
      Map<String, dynamic>.from(value),
    );
    return address.isEmpty ? null : address;
  }

  @override
  void dispose() {
    if (_messageListener != null) {
      html.window.removeEventListener('message', _messageListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: HtmlElementView(viewType: _viewType));
  }
}
