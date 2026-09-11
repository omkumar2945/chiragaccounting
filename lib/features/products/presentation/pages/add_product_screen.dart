import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/constants/import_template_content.dart';
import 'package:chirag_accounting/features/compat/screens/client_data_exchange_screen_compat.dart';

import 'package:chirag_accounting/features/products/hsn_lookup_service.dart';
import 'package:chirag_accounting/features/products/product_catalog.dart';
import 'package:chirag_accounting/features/products/models/product.dart';
import 'package:chirag_accounting/features/products/presentation/pages/barcode_scan_screen.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class AddProductScreen extends StatefulWidget {
  final Product? initialProduct;
  const AddProductScreen({super.key, this.initialProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hsnLookupService = HsnLookupService();

  // ── Controllers ────────────────────────────────────────────────────────────
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _hsnCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _purchaseCtrl;
  late TextEditingController _salesCtrl;
  late TextEditingController _openingStockCtrl;
  late TextEditingController _minStockCtrl;

  // ── State ──────────────────────────────────────────────────────────────────
  String _selectedUnit = 'Nos';
  String _selectedCategory = '';
  bool _isActive = true;

  // HSN auto-fill state
  List<HsnLookupResult> _suggestions = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  String? _autoFilledSource; // 'FastGST API' or 'local-catalog'
  bool _showAutoFilledBanner = false;
  bool _nameAutoFilledFromHsn = false;

  // HSN code field lookup (when HSN typed manually)
  int _hsnLookupSeq = 0;
  String? _hsnMatchDesc;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    _codeCtrl = TextEditingController(text: p?.productCode ?? '');
    _nameCtrl = TextEditingController(text: p?.productName ?? '');
    _hsnCtrl = TextEditingController(text: p?.hsnCode ?? '');
    _gstCtrl = TextEditingController(
        text: _fmt(p?.gstPercentage ?? 18));
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _purchaseCtrl = TextEditingController(
        text: p != null && p.purchaseRate > 0
            ? _fmt(p.purchaseRate)
            : '');
    _salesCtrl = TextEditingController(
        text: p != null && p.salesRate > 0 ? _fmt(p.salesRate) : '');
    _openingStockCtrl = TextEditingController(
        text: p != null && p.openingStock > 0
            ? _fmt(p.openingStock)
            : '');
    _minStockCtrl = TextEditingController(
        text: p != null && p.minimumStock > 0
            ? _fmt(p.minimumStock)
            : '');
    _selectedUnit = p?.unit ?? 'Nos';
    _selectedCategory = p?.category ?? '';
    _isActive = p?.isActive ?? true;

    _nameCtrl.addListener(_onNameChanged);
    _hsnCtrl.addListener(_onHsnChanged);
    if (p?.hsnCode.isNotEmpty ?? false) _onHsnChanged();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _hsnCtrl.removeListener(_onHsnChanged);
    _searchTimer?.cancel();
    for (final c in [
      _codeCtrl, _nameCtrl, _hsnCtrl, _gstCtrl, _descCtrl,
      _purchaseCtrl, _salesCtrl, _openingStockCtrl, _minStockCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(2);

  // ── Name search → API ───────────────────────────────────────────────────

  void _onNameChanged() {
    final q = _nameCtrl.text.trim();
    if (_nameAutoFilledFromHsn && q.isNotEmpty && q != _hsnMatchDesc) {
      _nameAutoFilledFromHsn = false;
    }
    _searchTimer?.cancel();
    if (q.length < 2) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _showAutoFilledBanner = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _showAutoFilledBanner = false;
    });
    _searchTimer = Timer(const Duration(milliseconds: 500), () async {
      final results = await _hsnLookupService.searchByProductName(q);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
      if (results.isNotEmpty && _shouldAutoApplyNameSuggestion(q, results.first)) {
        _applySuggestion(results.first);
      }
    });
  }

  void _applySuggestion(HsnLookupResult r) {
    _hsnCtrl.text = r.hsnCode;
    _gstCtrl.text = _fmt(r.gstPercentage);
    if (_descCtrl.text.trim().isEmpty) {
      _descCtrl.text = r.description;
    }
    if (_nameCtrl.text.trim().isEmpty || _nameAutoFilledFromHsn) {
      _nameCtrl.text = r.description;
      _nameAutoFilledFromHsn = true;
    }
    setState(() {
      _suggestions = [];
      _isSearching = false;
      _hsnMatchDesc = r.description;
      _autoFilledSource =
          r.source == 'government-endpoint' ? 'FastGST API' : 'Local Catalog';
      _showAutoFilledBanner = true;
    });
  }

  String _matchLabelForQuery(String query, HsnLookupResult result) {
    final normalizedQuery = _normalizeText(query);
    final normalizedDescription = _normalizeText(result.description);
    if (normalizedQuery.isEmpty || normalizedDescription.isEmpty) {
      return 'Near match';
    }

    if (normalizedDescription == normalizedQuery) {
      return 'Exact match';
    }

    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final descriptionTokens = normalizedDescription.split(' ');
    final allQueryTokensFound = queryTokens.every((token) {
      return descriptionTokens.any((descriptionToken) => descriptionToken.contains(token));
    });

    return allQueryTokensFound ? 'Near match' : 'Near match';
  }

  // ── HSN manual lookup ───────────────────────────────────────────────────

  void _onHsnChanged() async {
    final seq = ++_hsnLookupSeq;
    final result = await _hsnLookupService.lookup(_hsnCtrl.text);
    if (!mounted || seq != _hsnLookupSeq) return;
    if (result == null) {
      setState(() {
        _hsnMatchDesc = null;
        _showAutoFilledBanner = false;
      });
      return;
    }
    final gstStr = _fmt(result.gstPercentage);
    if (_gstCtrl.text != gstStr) _gstCtrl.text = gstStr;
    if (_descCtrl.text.trim().isEmpty) _descCtrl.text = result.description;
    if (_nameCtrl.text.trim().isEmpty || _nameAutoFilledFromHsn) {
      _nameCtrl.text = result.description;
      _nameAutoFilledFromHsn = true;
    }
    setState(() => _hsnMatchDesc = result.description);
  }

  bool _shouldAutoApplyNameSuggestion(String query, HsnLookupResult result) {
    final normalizedQuery = _normalizeText(query);
    final normalizedDescription = _normalizeText(result.description);
    if (normalizedQuery.isEmpty || normalizedDescription.isEmpty) return false;

    final queryTokens = normalizedQuery.split(' ').where((token) => token.isNotEmpty).toList(growable: false);
    if (queryTokens.length == 1) {
      return normalizedDescription == normalizedQuery;
    }

    if (normalizedDescription == normalizedQuery) return true;
    if (!normalizedDescription.contains(normalizedQuery)) return false;

    var matchedTokens = 0;
    for (final token in queryTokens) {
      if (normalizedDescription.contains(token)) {
        matchedTokens++;
      }
    }

    return matchedTokens == queryTokens.length;
  }

  String _normalizeText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  // ── Save ────────────────────────────────────────────────────────────────

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final cur = widget.initialProduct;
    final productName = _nameCtrl.text.trim();
    final product = Product(
      id: cur?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      productCode: _codeCtrl.text.trim(),
      productName: productName,
      hsnCode: _hsnCtrl.text.trim(),
      gstPercentage: double.tryParse(_gstCtrl.text.trim()) ?? 18,
      description: _descCtrl.text.trim(),
      category: _selectedCategory,
      unit: _selectedUnit,
      purchaseRate: double.tryParse(_purchaseCtrl.text.trim()) ?? 0,
      salesRate: double.tryParse(_salesCtrl.text.trim()) ?? 0,
      openingStock: double.tryParse(_openingStockCtrl.text.trim()) ?? 0,
      minimumStock: double.tryParse(_minStockCtrl.text.trim()) ?? 0,
      isActive: _isActive,
    );
    final svc = context.read<ProductService>();
    final excludeProductId = cur?.id;
    final identityMatch = svc.findIdentityMatch(product, excludeProductId);

    if (cur == null && identityMatch != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Duplicate prevented. Matched existing product: ${identityMatch.productName}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (cur == null) {
        svc.addProduct(product);
      } else {
        svc.updateProduct(cur.id, product);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cur == null
                ? 'Product ${product.productName} added'
                : 'Product ${product.productName} updated',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      final matched = svc.findIdentityMatch(product, excludeProductId);
      if (matched != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duplicate prevented. Matched existing product: ${matched.productName}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product validation failed: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanProductCode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );

    if (!mounted || scannedCode == null || scannedCode.trim().isEmpty) return;

    setState(() {
      _codeCtrl.text = scannedCode.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product code scanned successfully.')),
    );
  }

  void _openProductImportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientDataExchangeScreen(initialTabIndex: 0),
      ),
    );
  }

  Future<void> _downloadInventoryCsvTemplate() async {
    await _saveTemplateFile(
      fileName: 'inventory_import_template.csv',
      content: ImportTemplateContent.inventoryCsv,
      extension: 'csv',
    );
  }

  Future<void> _downloadInventoryJsonTemplate() async {
    await _saveTemplateFile(
      fileName: 'inventory_import_template.json',
      content: ImportTemplateContent.inventoryJson,
      extension: 'json',
    );
  }

  Future<void> _saveTemplateFile({
    required String fileName,
    required String content,
    required String extension,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Save Import Template',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [extension],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template downloaded: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Widget _buildProductImportCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openProductImportScreen,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import Product Data'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Product Import Templates',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fill columns: product_name, hsn, unit, opening_stock, purchase_rate, sales_rate, category',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _downloadInventoryCsvTemplate,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Inventory CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: _downloadInventoryJsonTemplate,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Inventory JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialProduct != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
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
              // 1 ── Basic Info ─────────────────────────────────────────────
              _sectionTitle('Basic Information'),
              const SizedBox(height: 10),
              _card(child: Column(children: [
                _buildProductImportCard(),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_codeCtrl, 'Product Code',
                      required: true,
                      icon: Icons.qr_code_scanner,
                      suffix: IconButton(
                        onPressed: _scanProductCode,
                        icon: const Icon(Icons.document_scanner_outlined),
                        tooltip: 'Scan barcode',
                      ))),
                  const SizedBox(width: 12),
                    Expanded(child: _field(_nameCtrl, 'Product Name',
                      required: true,
                      icon: Icons.inventory_2_outlined,
                      suffix: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : null)),
                ]),
                // Name → HSN suggestion panel
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _suggestionPanel(),
                ],
              ])),
              const SizedBox(height: 16),

              // 2 ── HSN / GST (auto-filled from API) ──────────────────────
              _sectionTitle('HSN / GST Details'),
              const SizedBox(height: 4),
              // Auto-filled banner
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showAutoFilledBanner
                    ? _autoFilledBanner()
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              _card(child: Column(children: [
                Row(children: [
                  Expanded(
                    child: _field(_hsnCtrl, 'HSN / SAC Code',
                        icon: Icons.tag,
                        helperText: _hsnMatchDesc ?? 'Auto-fills product name when HSN / SAC is entered'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_gstCtrl, 'GST %',
                        number: true,
                        icon: Icons.percent,
                        helperText: 'Auto-filled from HSN master'),
                  ),
                ]),
                const SizedBox(height: 12),
                _field(_descCtrl, 'HSN Description',
                    icon: Icons.description_outlined,
                    helperText:
                        'Auto-filled from FastGST API — you may edit'),
              ])),
              const SizedBox(height: 16),

              // 3 ── Pricing ────────────────────────────────────────────────
              _sectionTitle('Pricing'),
              const SizedBox(height: 8),
              _card(
                child: Row(children: [
                  Expanded(
                    child: _field(_purchaseCtrl, 'Purchase Rate',
                        number: true, icon: Icons.shopping_cart_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_salesCtrl, 'Sales Rate',
                        number: true,
                        icon: Icons.sell_outlined),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // 4 ── Inventory & Classification ────────────────────────────
              _sectionTitle('Inventory & Classification'),
              const SizedBox(height: 8),
              _card(child: Column(children: [
                Row(children: [
                  Expanded(child: _unitField()),
                  const SizedBox(width: 12),
                  Expanded(child: _categoryField()),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _field(_openingStockCtrl, 'Opening Stock',
                        number: true,
                        icon: Icons.warehouse_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_minStockCtrl, 'Minimum Stock',
                        number: true,
                        icon: Icons.warning_amber_outlined,
                        helperText: 'Alert when stock falls below this'),
                  ),
                ]),
              ])),
              const SizedBox(height: 16),

              // 5 ── Status ─────────────────────────────────────────────────
              _card(
                child: SwitchListTile(
                  title: const Text('Active'),
                  subtitle:
                      const Text('Inactive products hide from sale/purchase'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? 'Update Product' : 'Add Product',
                      style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
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

  // ── Suggestion panel ──────────────────────────────────────────────────────

  Widget _suggestionPanel() {
    final query = _nameCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 14, color: Colors.blue),
          const SizedBox(width: 6),
          Text(
            '${_suggestions.length} HSN suggestion${_suggestions.length == 1 ? '' : 's'} found — tap to auto-fill',
            style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: 6),
        ...List.generate(
          _suggestions.length > 5 ? 5 : _suggestions.length,
          (i) {
            final s = _suggestions[i];
            final gstStr = s.gstPercentage.truncateToDouble() ==
                    s.gstPercentage
                ? s.gstPercentage.toInt().toString()
                : s.gstPercentage.toStringAsFixed(2);
            final isApi = s.source == 'government-endpoint';
            final matchLabel = _matchLabelForQuery(query, s);
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _applySuggestion(s),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isApi
                      ? Colors.blue.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isApi
                        ? Colors.blue.shade200
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.description,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Row(children: [
                          _chip(matchLabel,
                            matchLabel == 'Exact match'
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                            matchLabel == 'Exact match'
                              ? Colors.green.shade800
                              : Colors.orange.shade800),
                          const SizedBox(width: 6),
                          _chip('HSN: ${s.hsnCode}',
                              Colors.indigo.shade100,
                              Colors.indigo.shade700),
                          const SizedBox(width: 6),
                          _chip('GST: $gstStr%',
                              Colors.green.shade100,
                              Colors.green.shade800),
                          const SizedBox(width: 6),
                          _chip(
                              isApi
                                  ? 'FastGST API'
                                  : 'Local Catalog',
                              isApi
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade200,
                              isApi
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade700),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.blue),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _autoFilledBanner() {
    return Container(
      key: const ValueKey('banner'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(children: [
        Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'HSN Code, GST % and Description auto-filled from $_autoFilledSource.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _showAutoFilledBanner = false),
          child: Icon(Icons.close,
              size: 16, color: Colors.green.shade600),
        ),
      ]),
    );
  }

  // ── Unit autocomplete ─────────────────────────────────────────────────────

  Widget _unitField() => Autocomplete<String>(
        initialValue: TextEditingValue(text: _selectedUnit),
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          return q.isEmpty
              ? ProductCatalog.units
              : ProductCatalog.units
                  .where((u) => u.toLowerCase().contains(q));
        },
        onSelected: (v) => setState(() => _selectedUnit = v),
        optionsViewBuilder: (context, onSelected, options) =>
            _buildStringOptionsView(context, onSelected, options),
        fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) => TextFormField(
          controller: ctrl,
          focusNode: fn,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Unit',
            prefixIcon: Icon(Icons.straighten_outlined),
            helperText: 'Nos, Kg, Box, Bag, Ltr, Mtr…',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _selectedUnit = v.trim(),
          onFieldSubmitted: (_) => onFieldSubmitted(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Unit is required' : null,
        ),
      );

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
          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
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

  // ── Category field ────────────────────────────────────────────────────────

  Widget _categoryField() {
    final cats = context.watch<ProductService>().allCategories;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SearchableDropdownFormField<String>(
            value: _selectedCategory.isEmpty ? null : _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
            ),
            hintText: 'Select',
            items: cats,
            itemLabelBuilder: (c) => c,
            onChanged: (v) => setState(() => _selectedCategory = v ?? ''),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Add new category',
          child: IconButton.filled(
            onPressed: () => _showCategoryDialog(context),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                context.read<ProductService>().addCategory(name);
                setState(() => _selectedCategory = name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Shared builders ───────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(t,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        child: Padding(
            padding: const EdgeInsets.all(14), child: child),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    bool number = false,
    IconData? icon,
    Widget? suffix,
    String? helperText,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          suffixIcon: suffix,
          helperText: helperText,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
        validator: (v) =>
            required && (v == null || v.trim().isEmpty)
                ? '$label is required'
                : null,
      );

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg)),
      );
}
