import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/integrations/integration_hub_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/gst_operations/presentation/widgets/client_gst_portal_setup_dialog.dart';
import 'package:chirag_accounting/features/gst_operations/services/client_gst_portal_connection_service.dart';

class GstDocumentOperationsScreen extends StatefulWidget {
  const GstDocumentOperationsScreen.eInvoice({super.key})
    : title = 'E-Invoicing',
      subtitle =
          'Generate, retrieve, and cancel GST e-invoices through GSTZen.',
        connectionType = ClientGstPortalConnectionType.einvoicing,
      operations = _eInvoiceOperations;

  const GstDocumentOperationsScreen.eWayBill({super.key})
    : title = 'E-Way Bill',
      subtitle = 'Manage the complete e-way bill lifecycle through GSTZen.',
      connectionType = ClientGstPortalConnectionType.ewayBill,
      operations = _eWayBillOperations;

  final String title;
  final String subtitle;
  final ClientGstPortalConnectionType connectionType;
  final List<_GstOperation> operations;

  @override
  State<GstDocumentOperationsScreen> createState() =>
      _GstDocumentOperationsScreenState();
}

class _GstDocumentOperationsScreenState
    extends State<GstDocumentOperationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late _GstOperation _operation;
  late final TextEditingController _payloadController;
  final TextEditingController _gstinController = TextEditingController();
  String? _response;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _operation = widget.operations.first;
    _payloadController = TextEditingController(text: _operation.example);
    _syncExampleGstin();
  }

  @override
  void didUpdateWidget(covariant GstDocumentOperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operations == widget.operations) return;
    _operation = widget.operations.first;
    _payloadController.text = _operation.example;
    _syncExampleGstin();
    _response = null;
    _error = null;
  }

  @override
  void dispose() {
    _payloadController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  void _selectOperation(_GstOperation? operation) {
    if (operation == null) return;
    setState(() {
      _operation = operation;
      _payloadController.text = operation.example;
      _syncExampleGstin();
      _response = null;
      _error = null;
    });
  }

  void _syncExampleGstin() {
    _gstinController.text = _operation.requiresGstin ? '29AAFCC9980M1ZR' : '';
  }

  Future<void> _submit() async {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(_payloadController.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('The request body must be a JSON object.');
      }
      payload = Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      setState(() {
        _error = 'Invalid JSON: ${error.message}';
        _response = null;
      });
      return;
    }

    if (_operation.requiresGstin) {
      final gstin = _gstinController.text.trim().toUpperCase();
      if (!RegExp(r'^[0-9]{2}[A-Z0-9]{13}$').hasMatch(gstin)) {
        setState(() {
          _error = 'Enter a valid 15-character GSTIN for this operation.';
          _response = null;
        });
        return;
      }
      payload['gstin'] = gstin;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _response = null;
    });
    try {
      final result = await context.read<IntegrationHubService>().execute(
        adapterId: 'gst',
        action: _operation.action,
        payload: payload,
      );
      if (!mounted) return;
      setState(() {
        _response = const JsonEncoder.withIndent('  ').convert(result);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFor(Object error) {
    final message = error.toString();
    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('DioException [bad response]: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final isClient =
      context.watch<AuthController?>()?.currentUser?.role.isClient ?? false;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(child: _operationNavigation(closeDrawer: true)),
            ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: wide
            ? null
            : IconButton(
                tooltip: 'Open ${widget.title} operations',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        elevation: 0,
        actions: isClient
            ? [
                IconButton(
                  tooltip: 'Configure ${widget.title} portal',
                  onPressed: _submitting ? null : _showPortalSetup,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ]
            : null,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            SizedBox(width: 248, child: _operationNavigation(closeDrawer: false)),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 20 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _requestPanel(),
                  const SizedBox(height: 16),
                  _resultPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPortalSetup() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ClientGstPortalSetupDialog(
        title: '${widget.title} Portal Setup',
        connectionType: widget.connectionType,
      ),
    );
  }

  Widget _operationNavigation({required bool closeDrawer}) {
    return ColoredBox(
      color: const Color(0xFF102A43),
      child: ListView(
        key: ValueKey('${widget.title}-operation-selector'),
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Text(
              '${widget.title} OPERATIONS',
              style: const TextStyle(
                color: Color(0xFF9FB3C8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final operation in widget.operations)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Material(
                color: operation == _operation
                    ? const Color(0xFF1E5A8A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                child: ListTile(
                  key: ValueKey('gst-operation-${operation.action}'),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    operation.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: operation == _operation
                          ? Colors.white
                          : const Color(0xFFD9E2EC),
                      fontSize: 12,
                      fontWeight: operation == _operation
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  onTap: _submitting
                      ? null
                      : () {
                          _selectOperation(operation);
                          if (closeDrawer) Navigator.of(context).pop();
                        },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _requestPanel() {
    return _Panel(
      title: _operation.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _operation.description,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
          if (_operation.requiresGstin) ...[
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('gst-operation-gstin'),
              controller: _gstinController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              decoration: const InputDecoration(
                labelText: 'Client GSTIN',
                hintText: '27ABCDE1234F1Z5',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.security_outlined, size: 18, color: Color(0xFF52606D)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Request details are prepared securely and processed by the backend.',
                  style: TextStyle(color: Color(0xFF52606D), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('gst-operation-submit'),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_submitting ? 'Submitting...' : _operation.label),
          ),
        ],
      ),
    );
  }

  Widget _resultPanel() {
    return _Panel(
      title: 'Status',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _error != null
            ? SelectableText(
                _error!,
                key: const ValueKey('gst-operation-error'),
                style: const TextStyle(color: Color(0xFFB42318)),
              )
            : _response != null
            ? const Row(
                key: ValueKey('gst-operation-response'),
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The operation completed successfully.',
                      style: TextStyle(color: Color(0xFF166534)),
                    ),
                  ),
                ],
              )
            : const Text(
                'Choose an operation from the left menu and submit it to view its status.',
                key: ValueKey('gst-operation-empty'),
                style: TextStyle(color: Color(0xFF667085)),
              ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _GstOperation {
  const _GstOperation({
    required this.action,
    required this.label,
    required this.description,
    required this.example,
    this.requiresGstin = false,
  });

  final String action;
  final String label;
  final String description;
  final String example;
  final bool requiresGstin;
}

const _irnExample = '''{
  "Irn": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}''';
const _getEInvoiceExample = '''{
  "SellerDtls": {
    "Gstin": "29AADCG4992P1ZP"
  },
  "Irn": "6572600aa1108dc76a11c05f427451fec1de7437881aa4e90e6e580cf89cf3f6"
}''';
const _getEInvoiceNic1Example = '''{
  "SellerDtls": {
    "Gstin": "29AADCG4992P1ZP"
  },
  "Irn": "6572600aa1108dc76a11c05f427451fec1de7437881aa4e90e6e580cf89cf3f6",
  "irp": "NIC1"
}''';
const _gstinExample = '''{
  "ewbNo": 123456789012
}''';
const _createStandaloneEwayBillExample = '''{
  "supplyType": "O",
  "subSupplyType": "1",
  "subSupplyDesc": "",
  "docType": "INV",
  "docNo": "sum/1/23/79",
  "docDate": "07/07/2017",
  "fromGstin": "29AAFCC9980M1ZR",
  "fromTrdName": "welton",
  "fromAddr1": "2ND CROSS NO 59  19  A",
  "fromAddr2": "GROUND FLOOR OSBORNE ROAD",
  "fromPlace": "FRAZER TOWN",
  "fromPincode": 560090,
  "actFromStateCode": 29,
  "fromStateCode": 29,
  "toGstin": "29AEKPV7203E1Z9",
  "toTrdName": "sthuthya",
  "toAddr1": "Shree Nilaya",
  "toAddr2": "Dasarahosahalli",
  "toPlace": "Beml Nagar",
  "toPincode": 560090,
  "actToStateCode": 29,
  "toStateCode": 27,
  "transactionType": 4,
  "shipToGSTIN": "29ABCDE8755F1Z2",
  "shipToTradeName": "XYZ Traders",
  "otherValue": "0",
  "totalValue": 56099,
  "cgstValue": 0,
  "sgstValue": 0,
  "igstValue": 300.67,
  "cessValue": 400.56,
  "cessNonAdvolValue": 400,
  "totInvValue": 68358,
  "transporterId": "",
  "transporterName": "",
  "transDocNo": "",
  "transMode": "1",
  "transDistance": "100",
  "transDocDate": "",
  "vehicleNo": "PVC1234",
  "vehicleType": "R",
  "itemList": [{
    "productName": "Wheat",
    "productDesc": "Wheat",
    "hsnCode": 1001,
    "quantity": 4,
    "qtyUnit": "BOX",
    "cgstRate": 0,
    "sgstRate": 0,
    "igstRate": 3,
    "cessRate": 3,
    "cessNonadvol": 0,
    "taxableAmount": 5609889
  }]
}''';
const _cancelStandaloneEwayBillExample = '''{
  "cancelRmrk": "Cancelled the order",
  "cancelRsnCode": 2,
  "ewbNo": 141010282832
}''';
const _updatePartBExample = '''{
  "ewbNo": 111000609282,
  "FromPlace": "BANGALORE",
  "FromState": 29,
  "ReasonCode": "1",
  "ReasonRem": "vehicle broke down",
  "TransDocDate": "12/10/2017",
  "TransDocNo": "1234",
  "TransMode": "1",
  "VehicleNo": "PQR1234"
}''';
const _updateTransporterExample = '''{
  "ewbNo": "191010282840",
  "transporterId": "29AKLPM8755F1Z2"
}''';
const _getEwayBillExample = '''{
  "ewbNo": 141010270204
}''';
const _consolidateEwayBillExample = '''{
  "fromPlace": "BANGALORE SOUTH",
  "fromState": 29,
  "vehicleNo": "KA12AB1234",
  "transMode": "1",
  "transDocNo": "1234",
  "transDocDate": "12/10/2017",
  "tripSheetEwbBills": [
    {"ewbNo": "111000609282"},
    {"ewbNo": "181000609270"}
  ]
}''';
const _getConsolidatedEwayBillExample = '''{
  "tripSheetNo": "1610005711"
}''';
const _extendEwayBillExample = '''{
  "ewbNo": 191010282840,
  "vehicleNo": "PQR1234",
  "fromPlace": "Bengaluru",
  "fromState": 29,
  "fromPincode": 560077,
  "remainingDistance": 50,
  "transDocNo": "1234",
  "transDocDate": "12/10/2017",
  "transMode": "1",
  "extnRsnCode": 1,
  "extnRemarks": "Flood",
  "transitType": "",
  "consignmentStatus": "M"
}''';
const _initiateMultiVehicleExample = '''{
  "ewbNo": 131001111287,
  "reasonCode": "1",
  "reasonRem": "vehicle broke down",
  "fromPlace": "BANGALORE",
  "fromState": 29,
  "toPlace": "Chennai",
  "toState": 33,
  "transMode": "1",
  "totalQuantity": 33,
  "unitCode": "NOS"
}''';
const _addMultiVehicleExample = '''{
  "ewbNo": 131001111287,
  "groupNo": "1",
  "vehicleNo": "PQR1234",
  "transDocNo": "1234",
  "transDocDate": "12/10/2017",
  "quantity": 15
}''';
const _changeMultiVehicleExample = '''{
  "ewbNo": 111000609282,
  "groupNo": 1,
  "oldvehicleNo": "PQR1234",
  "newVehicleNo": "PQR1234",
  "oldTranNo": "ABC123",
  "newTranNo": "PQR123",
  "fromPlace": "Lucknow",
  "fromState": 9,
  "reasonCode": "1",
  "reasonRem": "vehicle broke down"
}''';
const _closeEwayBillExample = '''{
  "ewbNo": 111000609282,
  "closureDate": "21/05/2026",
  "remarks": "Closed the order"
}''';
const _ewayBillOnIrnExample = '''{
  "Version": "1.1",
  "TranDtls": {
    "TaxSch": "GST",
    "SupTyp": "B2B",
    "RegRev": "N",
    "IgstOnIntra": "N"
  },
  "DocDtls": {"Typ": "INV", "No": "23-24/DEM/52", "Dt": "22/03/2023"},
  "SellerDtls": {
    "Gstin": "29AADCG4992P1ZP",
    "LglNm": "GSTZEN DEMO PRIVATE LIMITED",
    "Addr1": "Manyata Tech Park",
    "Loc": "BANGALORE",
    "Pin": 560077,
    "Stcd": "29"
  },
  "BuyerDtls": {
    "Gstin": "06AAMCS8709B1ZA",
    "LglNm": "Quality Products Private Limited",
    "Pos": "06",
    "Addr1": "133, Mahatma Gandhi Road",
    "Loc": "HARYANA",
    "Pin": 121009,
    "Stcd": "06"
  },
  "DispDtls": {
    "Nm": "Maharashtra Storage",
    "Addr1": "133, Mahatma Gandhi Road",
    "Loc": "Bhiwandi",
    "Pin": 400001,
    "Stcd": "27"
  },
  "ShipDtls": {
    "Gstin": "URP",
    "LglNm": "Quality Products Construction Site",
    "Addr1": "Anna Salai",
    "Loc": "Chennai",
    "Pin": 600001,
    "Stcd": "33"
  },
  "ItemList": [{
    "ItemNo": 0,
    "SlNo": "1",
    "IsServc": "N",
    "PrdDesc": "Computer Hardware - Keyboard and Mouse",
    "HsnCd": "3205",
    "Qty": 25,
    "FreeQty": 0,
    "Unit": "PCS",
    "UnitPrice": 200,
    "TotAmt": 5000,
    "Discount": 0,
    "PreTaxVal": 0,
    "AssAmt": 5000,
    "GstRt": 18,
    "IgstAmt": 900,
    "CgstAmt": 0,
    "SgstAmt": 0,
    "CesRt": 0,
    "CesAmt": 0,
    "CesNonAdvlAmt": 0,
    "StateCesRt": 0,
    "StateCesAmt": 0,
    "StateCesNonAdvlAmt": 0,
    "OthChrg": 0,
    "TotItemVal": 5900
  }],
  "ValDtls": {
    "AssVal": 5000,
    "CgstVal": 0,
    "SgstVal": 0,
    "IgstVal": 900,
    "CesVal": 0,
    "StCesVal": 0,
    "Discount": 0,
    "OthChrg": 0,
    "RndOffAmt": 0,
    "TotInvVal": 5900
  },
  "EwbDtls": {
    "TransId": "21ADAPP6261D1Z1",
    "TransName": "Just in time Shippers Pvt Limited",
    "TransMode": "1",
    "Distance": 0,
    "VehNo": "KA331234",
    "VehType": "R"
  },
  "ExpShipDtls": {
    "Gstin": "29XXXXXXXXXX",
    "TrdNm": "ABC",
    "Addr1": "7th block",
    "Addr2": "kuvempu layout",
    "Loc": "Banagalore",
    "Pin": 562160,
    "Stcd": "29"
  }
}''';
const _cancelEwayBillOnIrnExample = '''{
  "Version": "1.1",
  "TranDtls": {"TaxSch": "GST", "SupTyp": "B2B", "RegRev": "N", "IgstOnIntra": "N"},
  "DocDtls": {"Typ": "INV", "No": "23-24/DEM/54", "Dt": "22/03/2023"},
  "SellerDtls": {
    "Gstin": "29AADCG4992P1ZP",
    "LglNm": "GSTZEN DEMO PRIVATE LIMITED",
    "Addr1": "Manyata Tech Park",
    "Loc": "BANGALORE",
    "Pin": 560077,
    "Stcd": "29"
  },
  "BuyerDtls": {
    "Gstin": "06AAMCS8709B1ZA",
    "LglNm": "Quality Products Private Limited",
    "Pos": "06",
    "Addr1": "133, Mahatma Gandhi Road",
    "Loc": "HARYANA",
    "Pin": 121009,
    "Stcd": "06"
  },
  "DispDtls": {
    "Nm": "Maharashtra Storage",
    "Addr1": "133, Mahatma Gandhi Road",
    "Loc": "Bhiwandi",
    "Pin": 400001,
    "Stcd": "27"
  },
  "ShipDtls": {
    "Gstin": "URP",
    "LglNm": "Quality Products Construction Site",
    "Addr1": "Anna Salai",
    "Loc": "Chennai",
    "Pin": 600001,
    "Stcd": "33"
  },
  "ItemList": [{
    "ItemNo": 0,
    "SlNo": "1",
    "IsServc": "N",
    "PrdDesc": "Computer Hardware - Keyboard and Mouse",
    "HsnCd": "3205",
    "Qty": 25,
    "FreeQty": 0,
    "Unit": "PCS",
    "UnitPrice": 200,
    "TotAmt": 5000,
    "Discount": 0,
    "PreTaxVal": 0,
    "AssAmt": 5000,
    "GstRt": 18,
    "IgstAmt": 900,
    "CgstAmt": 0,
    "SgstAmt": 0,
    "CesRt": 0,
    "CesAmt": 0,
    "CesNonAdvlAmt": 0,
    "StateCesRt": 0,
    "StateCesAmt": 0,
    "StateCesNonAdvlAmt": 0,
    "OthChrg": 0,
    "TotItemVal": 5900
  }],
  "ValDtls": {
    "AssVal": 5000,
    "CgstVal": 0,
    "SgstVal": 0,
    "IgstVal": 900,
    "CesVal": 0,
    "StCesVal": 0,
    "Discount": 0,
    "OthChrg": 0,
    "RndOffAmt": 0,
    "TotInvVal": 5900
  }
}''';

const List<_GstOperation> _eInvoiceOperations = [
  _GstOperation(
    action: 'generate-einvoice',
    label: 'Generate E-Invoice',
    description:
        'Generate an IRN, signed invoice, and QR code from invoice JSON.',
    example: '''{
  "Version": "1.1",
  "TranDtls": {"TaxSch": "GST", "SupTyp": "B2B"},
  "DocDtls": {"Typ": "INV", "No": "INV-001", "Dt": "05/09/2026"},
  "SellerDtls": {"Gstin": "27ABCDE1234F1Z5", "LglNm": "Seller Business", "Addr1": "Business address", "Loc": "Mumbai", "Pin": 400001, "Stcd": "27"},
  "BuyerDtls": {"Gstin": "24AAACS1234D1Z2", "LglNm": "Buyer Business", "Pos": "24", "Addr1": "Buyer address", "Loc": "Ahmedabad", "Stcd": "24"},
  "ItemList": [{"SlNo": "1", "IsServc": "N", "HsnCd": "1001", "UnitPrice": 1000, "TotAmt": 1000, "AssAmt": 1000, "GstRt": 18, "IgstAmt": 180, "TotItemVal": 1180}],
  "ValDtls": {"AssVal": 1000, "IgstVal": 180, "TotInvVal": 1180}
}''',
  ),
  _GstOperation(
    action: 'get-einvoice',
    label: 'Get E-Invoice',
    description: 'Retrieve an existing e-invoice using seller GSTIN and IRN.',
    example: _getEInvoiceExample,
  ),
  _GstOperation(
    action: 'get-einvoice',
    label: 'Get E-Invoice (NIC1)',
    description: 'Retrieve an e-invoice from the NIC1 IRP.',
    example: _getEInvoiceNic1Example,
  ),
  _GstOperation(
    action: 'cancel-einvoice',
    label: 'Cancel E-Invoice',
    description:
        'Cancel an active IRN using the provider cancellation payload.',
    example: _irnExample,
  ),
];

const List<_GstOperation> _eWayBillOperations = [
  _GstOperation(
    action: 'generate-eway-bill',
    label: 'Generate E-WayBill on IRN',
    description:
        'Generate an e-way bill while registering the invoice and transport details.',
    example: _ewayBillOnIrnExample,
  ),
  _GstOperation(
    action: 'cancel-eway-bill',
    label: 'Cancel E-WayBill on IRN',
    description:
        'Cancel the e-way bill linked to a registered invoice document.',
    example: _cancelEwayBillOnIrnExample,
  ),
  _GstOperation(
    action: 'create-eway-bill',
    label: 'Create E-Way Bill',
    description:
        'Create a standalone e-way bill from supply and transport data.',
    example: _createStandaloneEwayBillExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'cancel-standalone-eway-bill',
    label: 'Cancel E-Way Bill',
    description: 'Cancel a standalone e-way bill.',
    example: _cancelStandaloneEwayBillExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'update-eway-bill-part-b',
    label: 'Update Part B',
    description: 'Update vehicle and movement details in Part B.',
    example: _updatePartBExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'update-eway-bill-transporter',
    label: 'Update Transporter',
    description: 'Assign or change the transporter.',
    example: _updateTransporterExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'get-eway-bill',
    label: 'Get E-Way Bill',
    description: 'Retrieve an e-way bill by number.',
    example: _getEwayBillExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'generate-consolidated-eway-bill',
    label: 'Generate Consolidated Bill',
    description: 'Combine eligible e-way bills for one movement.',
    example: _consolidateEwayBillExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'get-consolidated-eway-bill',
    label: 'Get Consolidated Bill',
    description: 'Retrieve a consolidated e-way bill.',
    example: _getConsolidatedEwayBillExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'extend-eway-bill',
    label: 'Extend Validity',
    description:
        'Extend e-way bill validity using reason and transport details.',
    example: _extendEwayBillExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'initiate-eway-bill-multi-vehicle',
    label: 'Initiate Multi-Vehicle',
    description: 'Start multi-vehicle movement for an e-way bill.',
    example: _initiateMultiVehicleExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'add-eway-bill-multi-vehicle',
    label: 'Add Multi-Vehicle',
    description: 'Add a vehicle to an active multi-vehicle movement.',
    example: _addMultiVehicleExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'change-eway-bill-multi-vehicle',
    label: 'Change Multi-Vehicle',
    description: 'Change vehicle details in a multi-vehicle movement.',
    example: _changeMultiVehicleExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'close-eway-bill',
    label: 'Close Multi-Vehicle',
    description: 'Close an active multi-vehicle movement.',
    example: _closeEwayBillExample,
    requiresGstin: true,
  ),
  _GstOperation(
    action: 'get-eway-bill-transporter-view',
    label: 'Transporter View',
    description: 'View e-way bills assigned to a transporter.',
    example: '{"gstin": "27ABCDE1234F1Z5"}',
  ),
  _GstOperation(
    action: 'get-eway-bill-transporter-state-view',
    label: 'Transporter State View',
    description: 'View transporter records for a state.',
    example: '{"gstin": "27ABCDE1234F1Z5", "stateCode": "27"}',
  ),
  _GstOperation(
    action: 'get-eway-bill-transporter-gstin-view',
    label: 'Transporter GSTIN View',
    description: 'View transporter records for a GSTIN.',
    example: '{"gstin": "27ABCDE1234F1Z5"}',
  ),
];
