import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';

// ── Amount to Indian words ────────────────────────────────────────────────────
String _amountToWords(double amount) {
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
    'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];

  String below100(int n) {
    if (n < 20) return ones[n];
    return tens[n ~/ 10] + (n % 10 != 0 ? ' ${ones[n % 10]}' : '');
  }

  String below1000(int n) {
    if (n < 100) return below100(n);
    return '${ones[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${below100(n % 100)}' : ''}';
  }

  String indian(int n) {
    if (n == 0) return 'Zero';
    var result = '';
    if (n >= 10000000) { result += '${below1000(n ~/ 10000000)} Crore '; n %= 10000000; }
    if (n >= 100000) { result += '${below1000(n ~/ 100000)} Lakh '; n %= 100000; }
    if (n >= 1000) { result += '${below1000(n ~/ 1000)} Thousand '; n %= 1000; }
    if (n > 0) result += below1000(n);
    return result.trim();
  }

  final rupees = amount.floor();
  final paise = ((amount - rupees) * 100).round();
  var words = 'Rupees ${indian(rupees)}';
  if (paise > 0) words += ' and ${indian(paise)} Paise';
  return '$words Only';
}

// ── Screen ────────────────────────────────────────────────────────────────────
class InvoiceOutputScreen extends StatelessWidget {
  const InvoiceOutputScreen({super.key, required this.invoice});

  final SalesInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),
      appBar: AppBar(
        title: Text('Invoice ${invoice.invoiceNumber}'),
        backgroundColor: const Color(0xFF0E4C92),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share / Export PDF',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF export coming soon.')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Print workflow coming soon.')),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48 : 12,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 36 : 18),
                    child: _InvoiceBody(invoice: invoice, isWide: isWide),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Invoice document ──────────────────────────────────────────────────────────
class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.invoice, required this.isWide});

  final SalesInvoice invoice;
  final bool isWide;

  String get _sellerAddress =>
      invoice.sellerLocation?.enteredAddress.isNotEmpty == true
      ? invoice.sellerLocation!.enteredAddress
      : invoice.sellerAddress;

  String get _billingAddress =>
      invoice.billingLocation?.enteredAddress.isNotEmpty == true
      ? invoice.billingLocation!.enteredAddress
      : invoice.billingAddress;

  String get _shippingAddress =>
      invoice.shippingLocation?.enteredAddress.isNotEmpty == true
      ? invoice.shippingLocation!.enteredAddress
      : invoice.shippingAddress;

  bool get _isInterState {
    final sellerState = invoice.sellerLocation?.stateName.trim().toLowerCase();
    if (sellerState != null && sellerState.isNotEmpty) {
      return invoice.placeOfSupply.trim().toLowerCase() != sellerState;
    }
    return invoice.placeOfSupply.trim().toLowerCase() !=
        invoice.sellerAddress.toLowerCase().split(',').last.trim().toLowerCase();
  }

  bool get _hasTransport =>
      invoice.transporterName.isNotEmpty ||
      invoice.vehicleNumber.isNotEmpty ||
      invoice.ewayBillNo.isNotEmpty;

  bool get _hasEInvoice =>
      invoice.eInvoiceApplicable && invoice.irn.isNotEmpty;

  bool get _hasShipTo =>
      invoice.shipToDifferent &&
      _shippingAddress.trim().isNotEmpty &&
      _shippingAddress.trim() != _billingAddress.trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const _HRule(),
        isWide ? _buildMetaRow() : _buildMetaColumn(),
        const _HRule(),
        isWide ? _buildAddressRow() : _buildAddressColumn(),
        const _HRule(),
        _buildItemsTable(),
        const _HRule(),
        isWide ? _buildTotalsRow() : _buildTotalsColumn(),
        const _HRule(),
        _buildAmountInWords(),
        if (_hasTransport) ...[const _HRule(), _buildTransportBlock()],
        if (_hasEInvoice) ...[const _HRule(), _buildEInvoiceBlock()],
        const _HRule(),
        _buildFooter(),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invoice.sellerName.isNotEmpty
                    ? invoice.sellerName
                    : 'Chirag Accounting Solutions',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0E4C92),
                ),
              ),
              if (_sellerAddress.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  _sellerAddress,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 4),
              if (invoice.sellerGstin.isNotEmpty)
                _LabelValue(label: 'GSTIN', value: invoice.sellerGstin),
              if (invoice.sellerPan.isNotEmpty)
                _LabelValue(label: 'PAN', value: invoice.sellerPan),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E4C92),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                invoice.invoiceType.displayName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (invoice.status == InvoiceStatus.paid) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade500,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── Invoice meta ───────────────────────────────────────────────────────────
  Widget _buildMetaRow() {
    return Row(
      children: [
        Expanded(child: _MetaItem(label: 'Invoice No', value: invoice.invoiceNumber)),
        Expanded(child: _MetaItem(label: 'Invoice Date', value: _fmt(invoice.invoiceDate))),
        Expanded(
          child: _MetaItem(
            label: 'Place of Supply',
            value: invoice.placeOfSupply.isEmpty ? '—' : invoice.placeOfSupply,
          ),
        ),
        Expanded(child: _MetaItem(label: 'Due Date', value: _fmt(invoice.dueDate))),
      ],
    );
  }

  Widget _buildMetaColumn() {
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: [
        _MetaItem(label: 'Invoice No', value: invoice.invoiceNumber),
        _MetaItem(label: 'Invoice Date', value: _fmt(invoice.invoiceDate)),
        _MetaItem(
          label: 'Place of Supply',
          value: invoice.placeOfSupply.isEmpty ? '—' : invoice.placeOfSupply,
        ),
        _MetaItem(label: 'Due Date', value: _fmt(invoice.dueDate)),
      ],
    );
  }

  // ── Addresses ──────────────────────────────────────────────────────────────
  Widget _buildAddressRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildBillToBlock()),
        if (_hasShipTo) ...[
          const SizedBox(width: 24),
          Expanded(child: _buildShipToBlock()),
        ],
      ],
    );
  }

  Widget _buildAddressColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBillToBlock(),
        if (_hasShipTo) ...[const SizedBox(height: 12), _buildShipToBlock()],
      ],
    );
  }

  Widget _buildBillToBlock() => _AddressBlock(
        heading: 'Bill To',
        name: invoice.customerName,
        address: _billingAddress,
        gstin: invoice.gstNumber,
        pan: invoice.panNumber,
        state: invoice.placeOfSupply,
      );

  Widget _buildShipToBlock() => _AddressBlock(
        heading: 'Ship To',
        name: invoice.shippingCustomerName.isEmpty
            ? invoice.customerName
            : invoice.shippingCustomerName,
        address: _shippingAddress,
      );

  // ── Items table ────────────────────────────────────────────────────────────
  Widget _buildItemsTable() {
    final items = invoice.items;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(const Color(0xFFF0F4FA)),
        dataRowMinHeight: 36,
        dataRowMaxHeight: 60,
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('#', style: _kHdrStyle)),
          DataColumn(label: Text('Item / HSN', style: _kHdrStyle)),
          DataColumn(
              label: Text('Qty', style: _kHdrStyle), numeric: true),
          DataColumn(
              label: Text('Rate (₹)', style: _kHdrStyle), numeric: true),
          DataColumn(
              label: Text('GST%', style: _kHdrStyle), numeric: true),
          DataColumn(
              label: Text('Amount (₹)', style: _kHdrStyle),
              numeric: true),
        ],
        rows: [
          for (var i = 0; i < items.length; i++)
            DataRow(cells: [
              DataCell(Text('${i + 1}',
                  style: const TextStyle(fontSize: 12))),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      items[i].productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    if (items[i].hsnCode.isNotEmpty)
                      Text(
                        'HSN: ${items[i].hsnCode}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                      ),
                    if (items[i].description.isNotEmpty)
                      Text(
                        items[i].description,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black45),
                      ),
                  ],
                ),
              ),
              DataCell(Text(_qty(items[i].quantity),
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(_rs(items[i].rate),
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(
                  '${items[i].gstPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(_rs(items[i].taxableAmount),
                  style: const TextStyle(fontSize: 12))),
            ]),
        ],
      ),
    );
  }

  // ── Totals ────────────────────────────────────────────────────────────────
  Widget _buildTotalsRow() {
    return Row(
      children: [
        const Spacer(),
        SizedBox(width: 320, child: _buildTotalsBlock()),
      ],
    );
  }

  Widget _buildTotalsColumn() => _buildTotalsBlock();

  Widget _buildTotalsBlock() {
    // IGST for inter-state, CGST+SGST for intra-state
    final cgst = _isInterState ? 0.0 : invoice.totalCGST;
    final sgst = _isInterState ? 0.0 : invoice.totalSGST;
    final igst = _isInterState ? invoice.totalIGST : 0.0;
    final adjusted = invoice.adjustedTotal;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        border: Border.all(color: const Color(0xFFDDE5F2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _TotalRow(
              label: 'Taxable Amount', value: _rs(invoice.taxableAmount)),
          const Divider(height: 1),
          if (!_isInterState) ...[
            _TotalRow(label: 'CGST', value: _rs(cgst), sub: true),
            _TotalRow(label: 'SGST', value: _rs(sgst), sub: true),
          ] else
            _TotalRow(label: 'IGST', value: _rs(igst), sub: true),
          if (invoice.roundOff != 0) ...[
            const Divider(height: 1),
            _TotalRow(
              label: 'Round Off',
              value:
                  '${invoice.roundOff >= 0 ? '+' : ''}${invoice.roundOff.toStringAsFixed(2)}',
              sub: true,
            ),
          ],
          const Divider(height: 1),
          _TotalRow(
            label: 'Grand Total',
            value: _rs(adjusted),
            bold: true,
            highlight: true,
          ),
        ],
      ),
    );
  }

  // ── Amount in words ───────────────────────────────────────────────────────
  Widget _buildAmountInWords() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'Amount in Words:  ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            TextSpan(
              text: _amountToWords(invoice.adjustedTotal),
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Transport ─────────────────────────────────────────────────────────────
  Widget _buildTransportBlock() {
    return _SectionBlock(
      icon: Icons.local_shipping_outlined,
      title: 'Transport Details',
      iconColor: Colors.orange.shade700,
      child: Wrap(
        spacing: 24,
        runSpacing: 6,
        children: [
          if (invoice.transportMode.isNotEmpty)
            _LabelValue(label: 'Mode', value: invoice.transportMode),
          if (invoice.transporterName.isNotEmpty)
            _LabelValue(
                label: 'Transporter', value: invoice.transporterName),
          if (invoice.transporterGstin.isNotEmpty)
            _LabelValue(
                label: 'Transporter GSTIN', value: invoice.transporterGstin),
          if (invoice.vehicleNumber.isNotEmpty)
            _LabelValue(label: 'Vehicle No', value: invoice.vehicleNumber),
          if (invoice.vehicleType.isNotEmpty &&
              invoice.vehicleType != 'Regular')
            _LabelValue(label: 'Vehicle Type', value: invoice.vehicleType),
          if (invoice.distanceKm.isNotEmpty)
            _LabelValue(
                label: 'Distance', value: '${invoice.distanceKm} km'),
          if (invoice.transportDocNo.isNotEmpty)
            _LabelValue(
                label: 'LR / Doc No', value: invoice.transportDocNo),
          if (invoice.transportDate.isNotEmpty)
            _LabelValue(
                label: 'Transport Date', value: invoice.transportDate),
          if (invoice.ewayBillNo.isNotEmpty)
            _LabelValue(
                label: 'E-Way Bill No', value: invoice.ewayBillNo),
          if (invoice.ewayBillDate.isNotEmpty)
            _LabelValue(
                label: 'E-Way Bill Date', value: invoice.ewayBillDate),
        ],
      ),
    );
  }

  // ── E-Invoice ─────────────────────────────────────────────────────────────
  Widget _buildEInvoiceBlock() {
    return _SectionBlock(
      icon: Icons.verified_outlined,
      title: 'E-Invoice Details (IRP)',
      iconColor: Colors.green.shade700,
      child: Wrap(
        spacing: 24,
        runSpacing: 6,
        children: [
          if (invoice.irn.isNotEmpty)
            _LabelValue(label: 'IRN', value: invoice.irn),
          if (invoice.ackNo.isNotEmpty)
            _LabelValue(label: 'Ack No', value: invoice.ackNo),
          if (invoice.ackDate != null)
            _LabelValue(label: 'Ack Date', value: _fmt(invoice.ackDate!)),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bank Details',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bank Name: —\nAccount No: —\nIFSC: —\nBranch: —',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 44),
            Container(width: 160, height: 1, color: Colors.black38),
            const SizedBox(height: 4),
            Text(
              invoice.sellerName.isNotEmpty
                  ? invoice.sellerName
                  : 'Authorised Signatory',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11),
            ),
            const Text(
              'Authorised Signatory',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.year}';

  String _rs(double v) => '₹${v.toStringAsFixed(2)}';

  String _qty(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ── Shared styles ─────────────────────────────────────────────────────────────
const TextStyle _kHdrStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 12,
  color: Color(0xFF0E4C92),
);

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HRule extends StatelessWidget {
  const _HRule();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Divider(height: 1, color: Color(0xFFDDE5F2)),
      );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: Colors.black45)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      );
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({
    required this.heading,
    required this.name,
    required this.address,
    this.gstin = '',
    this.pan = '',
    this.state = '',
  });

  final String heading;
  final String name;
  final String address;
  final String gstin;
  final String pan;
  final String state;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: Color(0xFF0E4C92),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          if (address.isNotEmpty)
            Text(address,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black87)),
          if (state.isNotEmpty)
            Text(state,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54)),
          if (gstin.isNotEmpty) _LabelValue(label: 'GSTIN', value: gstin),
          if (pan.isNotEmpty) _LabelValue(label: 'PAN', value: pan),
        ],
      );
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                  fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
      );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.sub = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool sub;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        color: highlight
            ? const Color(0xFF0E4C92).withValues(alpha: 0.08)
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: highlight ? 10 : 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: bold ? 13 : 12,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w500,
                  color:
                      sub ? Colors.black54 : Colors.black87,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight:
                    bold ? FontWeight.w800 : FontWeight.w500,
                color: bold
                    ? const Color(0xFF0E4C92)
                    : Colors.black87,
              ),
            ),
          ],
        ),
      );
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor = Colors.black54,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
}

