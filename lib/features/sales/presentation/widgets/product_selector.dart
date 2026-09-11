import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/products/models/product.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/products/presentation/pages/add_product_screen.dart';

// ─── ProductRow model ──────────────────────────────────────────────────────────

class ProductRow {
  final String id;
  String productCode;
  String? productName;
  String description;
  String? hsnCode;
  String? unit;
  String accountingLedger;
  double quantity;
  double rate;
  double? extractedAmount;
  double discount;
  double gstPercentage;
  double stockAvailable;
  bool taxCodeVerified;
  bool isCharge;

  ProductRow({
    required this.id,
    this.productCode = '',
    this.productName,
    this.description = '',
    this.hsnCode,
    this.unit,
    this.accountingLedger = '',
    this.quantity = 0,
    this.rate = 0,
    this.extractedAmount,
    this.discount = 0,
    this.gstPercentage = 18,
    this.stockAvailable = 0,
    this.taxCodeVerified = false,
    this.isCharge = false,
  });

  double get taxableAmount {
    final gross = quantity * rate;
    return gross - (gross * discount / 100);
  }

  double get gstAmount => taxableAmount * gstPercentage / 100;
  double get cgst => gstAmount / 2;
  double get sgst => gstAmount / 2;
  double get lineTotal => taxableAmount + gstAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'productCode': productCode,
        'productName': productName,
        'description': description,
        'hsnCode': hsnCode,
        'unit': unit,
        'accountingLedger': accountingLedger,
        'quantity': quantity,
        'rate': rate,
        'extractedAmount': extractedAmount,
        'discount': discount,
        'gstPercentage': gstPercentage,
        'taxCodeVerified': taxCodeVerified,
        'isCharge': isCharge,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'lineTotal': lineTotal,
      };
}

// ─── ProductSelector ──────────────────────────────────────────────────────────

class ProductSelector extends StatefulWidget {
  final List<ProductRow> initialRows;
  final Function(List<ProductRow>) onProductsChanged;
  final VoidCallback? onAddProduct;
  final Function(String)? onRemoveProduct;
  final bool operatorCompact;
  /// Customer place of supply – used to decide CGST/SGST vs IGST.
  final String placeOfSupply;
  /// Company home state. Change via Settings when needed.
  final String companyState;

  const ProductSelector({
    super.key,
    this.initialRows = const [],
    required this.onProductsChanged,
    this.onAddProduct,
    this.onRemoveProduct,
    this.operatorCompact = false,
    this.placeOfSupply = 'Karnataka',
    this.companyState = 'Karnataka',
  });

  @override
  State<ProductSelector> createState() => _ProductSelectorState();
}

class _ProductSelectorState extends State<ProductSelector> {
  late List<ProductRow> _rows;

  bool get _interState =>
      widget.placeOfSupply.trim().toLowerCase() !=
      widget.companyState.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows.isNotEmpty
        ? List.of(widget.initialRows)
        : [_newRow()];
  }

  @override
  void didUpdateWidget(ProductSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeOfSupply != widget.placeOfSupply) {
      setState(() {});
    }
  }

  ProductRow _newRow() =>
      ProductRow(id: DateTime.now().microsecondsSinceEpoch.toString());

  void _addRow() {
    setState(() => _rows.add(_newRow()));
    widget.onProductsChanged(_rows);
    widget.onAddProduct?.call();
  }

  void _removeRow(String id) {
    if (_rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('At least one product line is required')),
      );
      return;
    }
    setState(() => _rows.removeWhere((r) => r.id == id));
    widget.onProductsChanged(_rows);
    widget.onRemoveProduct?.call(id);
  }

  void _onRowChanged(ProductRow updated) {
    setState(() {
      final i = _rows.indexWhere((r) => r.id == updated.id);
      if (i != -1) _rows[i] = updated;
    });
    widget.onProductsChanged(_rows);
  }

  @override
  Widget build(BuildContext context) {
    final master = context.watch<ProductService>().products;

    return Card(
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Row(children: [
              const Text('Product Details',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddProductScreen())),
                icon: const Icon(Icons.add_circle_outline, size: 15),
                label: const Text('New Product  Ctrl+N',
                    style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            // Keyboard hint bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6)),
              child: const Text(
                '↑ ↓  Navigate    Enter  Select    Tab  Next Field    Ctrl+N  New Product',
                style: TextStyle(fontSize: 11, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 12),
            // GST mode badge
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _interState
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _interState
                      ? 'Inter-State  →  IGST'
                      : 'Intra-State  →  CGST + SGST',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _interState
                          ? Colors.orange.shade800
                          : Colors.green.shade800),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            // Scrollable table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const Divider(height: 1, thickness: 1),
                  for (final row in _rows)
                    _InvoiceRow(
                      key: ValueKey(row.id),
                      row: row,
                      master: master,
                      interState: _interState,
                      onChanged: _onRowChanged,
                      onRemove: () => _removeRow(row.id),
                      onAddRow: _addRow,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('+ Add Product'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSummary(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(children: [
      _hdr(w: 30, label: ''),
      _hdr(w: 200, label: 'Product'),
      _hdr(w: 88, label: 'HSN'),
      _hdr(w: 65, label: 'Unit'),
      _hdr(w: 72, label: 'Qty'),
      _hdr(w: 80, label: 'Rate'),
      _hdr(w: 65, label: 'Disc%'),
      _hdr(w: 85, label: 'Taxable'),
      _hdr(w: 52, label: 'GST%'),
      if (!_interState) ...[
        _hdr(w: 72, label: 'CGST'),
        _hdr(w: 72, label: 'SGST'),
      ] else
        _hdr(w: 80, label: 'IGST'),
      _hdr(w: 80, label: 'GST Amt'),
      _hdr(w: 90, label: 'Total'),
      _hdr(w: 40, label: ''),
    ]);
  }

  Widget _hdr({required double w, required String label}) => SizedBox(
        width: w,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87)),
        ),
      );

  // ── Summary ──────────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final subtotal =
        _rows.fold<double>(0, (s, r) => s + r.taxableAmount);
    final totalGst = _rows.fold<double>(0, (s, r) => s + r.gstAmount);
    final cgst = _rows.fold<double>(0, (s, r) => s + r.cgst);
    final sgst = _rows.fold<double>(0, (s, r) => s + r.sgst);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sumItem('Subtotal', subtotal),
          if (_interState)
            _sumItem('IGST', totalGst, color: Colors.orange.shade700)
          else ...[
            _sumItem('CGST', cgst, color: Colors.orange.shade700),
            _sumItem('SGST', sgst, color: Colors.orange.shade700),
          ],
          _sumItem('Total GST', totalGst),
          _sumItem('Grand Total', subtotal + totalGst, highlight: true),
        ],
      ),
    );
  }

  Widget _sumItem(String label, double val,
      {bool highlight = false, Color? color}) =>
      Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 3),
        Text('₹ ${val.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color ??
                    (highlight ? Colors.blue : Colors.black87))),
      ]);
}

// ─── Per-row widget ──────────────────────────────────────────────────────────

class _InvoiceRow extends StatefulWidget {
  final ProductRow row;
  final List<Product> master;
  final bool interState;
  final ValueChanged<ProductRow> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddRow;

  const _InvoiceRow({
    super.key,
    required this.row,
    required this.master,
    required this.interState,
    required this.onChanged,
    required this.onRemove,
    required this.onAddRow,
  });

  @override
  State<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends State<_InvoiceRow> {
  late ProductRow _row;
  late TextEditingController _hsnCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _discCtrl;
  late TextEditingController _gstCtrl;

  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _rateFocus = FocusNode();
  final FocusNode _discFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _row = widget.row;
    _hsnCtrl = TextEditingController(text: _row.hsnCode ?? '');
    _qtyCtrl = TextEditingController(
        text: _row.quantity > 0 ? _fmtNum(_row.quantity) : '');
    _rateCtrl = TextEditingController(
        text: _row.rate > 0 ? _fmtNum(_row.rate) : '');
    _discCtrl = TextEditingController(
        text: _row.discount > 0 ? _fmtNum(_row.discount) : '');
    _gstCtrl = TextEditingController(text: _fmtNum(_row.gstPercentage));
  }

  String _fmtNum(double v) =>
      v.truncateToDouble() == v
          ? v.toInt().toString()
          : v.toStringAsFixed(2);

  @override
  void dispose() {
    _hsnCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _discCtrl.dispose();
    _gstCtrl.dispose();
    _qtyFocus.dispose();
    _rateFocus.dispose();
    _discFocus.dispose();
    super.dispose();
  }

  // ── Product selection ───────────────────────────────────────────────────

  void _selectProduct(Product p) {
    _row
      ..productCode = p.productCode
      ..productName = p.productName
      ..hsnCode = p.hsnCode
      ..unit = p.unit
      ..gstPercentage = p.gstPercentage
      ..stockAvailable = p.openingStock;
    if (_row.rate <= 0) {
      _row.rate = p.salesRate;
      _rateCtrl.text = p.salesRate > 0 ? _fmtNum(p.salesRate) : '';
    }
    _hsnCtrl.text = p.hsnCode;
    _gstCtrl.text = _fmtNum(p.gstPercentage);
    setState(() {});
    widget.onChanged(_row);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _qtyFocus.requestFocus());
  }

  void _notify() {
    widget.onChanged(_row);
    setState(() {});
  }

  Iterable<Product> _filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.master.take(12);
    return widget.master.where((p) =>
        p.productName.toLowerCase().contains(q) ||
        p.productCode.toLowerCase().contains(q) ||
        p.hsnCode.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stockOk =
        _row.stockAvailable == 0 || _row.stockAvailable >= _row.quantity;

    return Column(children: [
      Row(children: [
        // Stock dot
        SizedBox(
          width: 30,
          child: _row.stockAvailable > 0
              ? Tooltip(
                  message:
                      'Available: ${_row.stockAvailable.toStringAsFixed(0)} ${_row.unit ?? ''}',
                  child: Icon(Icons.circle,
                      size: 10,
                      color: stockOk ? Colors.green : Colors.red),
                )
              : const SizedBox.shrink(),
        ),

        // ── Product autocomplete ─────────────────────────────────────────
        SizedBox(
          width: 200,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyN,
                    control: true): () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddProductScreen()),
                    ),
              },
              child: Autocomplete<Product>(
                displayStringForOption: (p) => p.productName,
                initialValue:
                    TextEditingValue(text: _row.productName ?? ''),
                optionsBuilder: (v) => _filter(v.text),
                onSelected: _selectProduct,
                fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) {
                  return TextFormField(
                    controller: ctrl,
                    focusNode: fn,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Search product…',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: ctrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                ctrl.clear();
                                _row
                                  ..productName = null
                                  ..hsnCode = null
                                  ..unit = null
                                  ..stockAvailable = 0;
                                _hsnCtrl.clear();
                                _notify();
                              },
                              child: const Icon(Icons.close, size: 14),
                            )
                          : null,
                    ),
                    onChanged: (v) =>
                        _row.productName = v.isEmpty ? null : v,
                    onFieldSubmitted: (_) => onFieldSubmitted(),
                  );
                },
                optionsViewBuilder: (ctx, onSel, opts) => _OptionsPopup(
                  options: opts.toList(),
                  query: _row.productName ?? '',
                  onSelected: onSel,
                ),
              ),
            ),
          ),
        ),

        // HSN (editable, auto-filled from master)
        _textCell(
          width: 88,
          ctrl: _hsnCtrl,
          onChanged: (v) {
            _row.hsnCode = v;
            _notify();
          },
        ),

        // Unit (read-only — from product master)
        _readOnlyCell(
          width: 65,
          text: _row.unit ?? 'Nos',
        ),

        // Qty
        _numCell(
          width: 72,
          ctrl: _qtyCtrl,
          focus: _qtyFocus,
          next: _rateFocus,
          onSet: (v) => _row.quantity = v,
        ),

        // Rate
        _numCell(
          width: 80,
          ctrl: _rateCtrl,
          focus: _rateFocus,
          next: _discFocus,
          onSet: (v) => _row.rate = v,
        ),

        // Disc%
        _numCell(
          width: 65,
          ctrl: _discCtrl,
          focus: _discFocus,
          onSet: (v) => _row.discount = v,
        ),

        // Taxable amount
        _badge(width: 85, text: _row.taxableAmount.toStringAsFixed(2)),

        // GST%
        _numCell(
          width: 52,
          ctrl: _gstCtrl,
          onSet: (v) => _row.gstPercentage = v,
        ),

        // CGST + SGST or IGST
        if (!widget.interState) ...[
          _badge(
              width: 72,
              text: _row.cgst.toStringAsFixed(2),
              bg: Colors.orange.shade50),
          _badge(
              width: 72,
              text: _row.sgst.toStringAsFixed(2),
              bg: Colors.orange.shade50),
        ] else
          _badge(
              width: 80,
              text: _row.gstAmount.toStringAsFixed(2),
              bg: Colors.orange.shade50),

        // GST Amount total
        _badge(width: 80, text: _row.gstAmount.toStringAsFixed(2)),

        // Line total
        _badge(
          width: 90,
          text: _row.lineTotal.toStringAsFixed(2),
          bg: Colors.green.shade50,
          bold: true,
          textColor: Colors.green.shade800,
        ),

        // Delete
        SizedBox(
          width: 40,
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            onPressed: widget.onRemove,
            padding: EdgeInsets.zero,
            tooltip: 'Remove',
          ),
        ),
      ]),
      const Divider(height: 1, color: Color(0xFFEEEEEE)),
    ]);
  }

  // ── Cell helpers ─────────────────────────────────────────────────────────

  Widget _textCell({
    required double width,
    required TextEditingController ctrl,
    required ValueChanged<String> onChanged,
    FocusNode? focus,
  }) =>
      SizedBox(
        width: width,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextFormField(
            controller: ctrl,
            focusNode: focus,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      );

  Widget _readOnlyCell({required double width, required String text}) =>
      SizedBox(
        width: width,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border:
                    Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4)),
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

  Widget _numCell({
    required double width,
    required TextEditingController ctrl,
    required void Function(double) onSet,
    FocusNode? focus,
    FocusNode? next,
  }) =>
      SizedBox(
        width: width,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TextFormField(
            controller: ctrl,
            focusNode: focus,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: next != null
                ? TextInputAction.next
                : TextInputAction.done,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              onSet(double.tryParse(v) ?? 0);
              _notify();
            },
            onEditingComplete: () {
              if (next != null) {
                next.requestFocus();
              } else {
                FocusScope.of(context).nextFocus();
              }
            },
          ),
        ),
      );

  Widget _badge({
    required double width,
    required String text,
    Color? bg,
    bool bold = false,
    Color? textColor,
  }) =>
      SizedBox(
        width: width,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              color: bg ?? Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: textColor ?? Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
}

// ─── Search options popup ─────────────────────────────────────────────────────

class _OptionsPopup extends StatelessWidget {
  final List<Product> options;
  final String query;
  final void Function(Product) onSelected;

  const _OptionsPopup({
    required this.options,
    required this.query,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Expanded(
                child: Text(
                  'No matching product found.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddProductScreen()),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add  Ctrl+N',
                    style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 460, maxHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Column header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8)),
                ),
                child: Row(children: [
                  const Expanded(
                    flex: 5,
                    child: Text('Product',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    flex: 3,
                    child: Text('HSN / Unit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Rate  |  GST  |  Stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54),
                        textAlign: TextAlign.right),
                  ),
                ]),
              ),
              const Divider(height: 1),
              // Rows
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = options[i];
                    return Builder(
                      builder: (itemContext) {
                        final isHighlighted =
                            AutocompleteHighlightedOption.of(itemContext) == i;
                        if (isHighlighted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Scrollable.ensureVisible(
                              itemContext,
                              alignment: 0.5,
                              duration: Duration.zero,
                            );
                          });
                        }

                        return ColoredBox(
                          color: isHighlighted
                              ? Theme.of(itemContext)
                                  .colorScheme
                                  .primaryContainer
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(p),
                            hoverColor: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _highlightText(p.productName, query),
                                      if (p.productCode.isNotEmpty)
                                        Text(p.productCode,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black38)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.hsnCode.isEmpty ? '—' : p.hsnCode,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54),
                                      ),
                                      Text(
                                        p.unit,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black38),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹ ${p.salesRate.toStringAsFixed(2)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        'GST ${p.gstPercentage.toStringAsFixed(0)}%  •  Stk: ${p.openingStock.toStringAsFixed(0)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black38),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Footer hint
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                color: Colors.grey.shade50,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: const Text(
                    '↑ ↓  Navigate    Enter  Select    Esc  Close',
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 10, color: Colors.black38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlightText(String text, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13));
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx == -1) {
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13));
    }
    final end = idx + q.length;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13),
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, end),
            style: TextStyle(
              backgroundColor: Colors.yellow.shade300,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (end < text.length) TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
