import 'package:flutter/material.dart';
import '../../models/sales_invoice.dart';
import '../../models/sales_item.dart';

/// A screen to create and configure a new [SalesInvoice].
class AddSalesInvoiceScreen extends StatefulWidget {
  const AddSalesInvoiceScreen({super.key});

  @override
  State<AddSalesInvoiceScreen> createState() => _AddSalesInvoiceScreenState();
}

class _AddSalesInvoiceScreenState extends State<AddSalesInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Field Controllers
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerEmailController;
  late final TextEditingController _taxRateController;

  // Invoice State Variables
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  InvoiceStatus _status = InvoiceStatus.draft;
  final List<SalesItem> _items = [];

  @override
  void initState() {
    super.initState();
    // Pre-populate with a generated invoice number
    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    _invoiceNumberController = TextEditingController(text: 'INV-2026-$uniqueId');
    _customerNameController = TextEditingController();
    _customerEmailController = TextEditingController();
    _taxRateController = TextEditingController(text: '15.0'); // 15% default tax
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  // Getters for totals
  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.total);
  double get _taxRate => (double.tryParse(_taxRateController.text) ?? 0.0) / 100.0;
  double get _taxAmount => _subtotal * _taxRate;
  double get _totalAmount => _subtotal + _taxAmount;

  // Pick Date helper
  Future<void> _selectDate(BuildContext context, bool isInvoiceDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInvoiceDate ? _invoiceDate : _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              primary: Colors.indigo,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isInvoiceDate) {
          _invoiceDate = picked;
          // Set due date to 14 days after invoice date as default
          _dueDate = picked.add(const Duration(days: 14));
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  // Add Item Dialog
  void _showAddItemDialog() {
    final itemFormKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController();
    final discountController = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.add_shopping_cart, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Add Invoice Item'),
            ],
          ),
          content: Form(
            key: itemFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter item name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Unit Price',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          validator: (v) {
                            if (v == null || double.tryParse(v) == null) {
                              return 'Invalid price';
                            }
                            if (double.parse(v) < 0) return 'Cannot be negative';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          validator: (v) {
                            if (v == null || int.tryParse(v) == null) {
                              return 'Invalid quantity';
                            }
                            if (int.parse(v) <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Item Discount (\$)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off),
                    ),
                    validator: (v) {
                      if (v == null || double.tryParse(v) == null) {
                        return 'Invalid discount';
                      }
                      if (double.parse(v) < 0) return 'Cannot be negative';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (itemFormKey.currentState!.validate()) {
                  final newItem = SalesItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    unitPrice: double.parse(priceController.text),
                    quantity: int.parse(qtyController.text),
                    discount: double.parse(discountController.text),
                  );
                  setState(() {
                    _items.add(newItem);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // Form submission
  void _saveInvoice() {
    if (_formKey.currentState!.validate()) {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one line item to the invoice.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final invoice = SalesInvoice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        invoiceNumber: _invoiceNumberController.text.trim(),
        customerName: _customerNameController.text.trim(),
        customerEmail: _customerEmailController.text.trim().isEmpty
            ? null
            : _customerEmailController.text.trim(),
        date: _invoiceDate,
        dueDate: _dueDate,
        items: List.from(_items),
        status: _status,
        taxRate: _taxRate,
      );

      // Return the new invoice to previous screen
      Navigator.pop(context, invoice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Sales Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveInvoice,
            tooltip: 'Save Invoice',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildClientSection(),
                            const SizedBox(height: 16),
                            _buildInvoiceDetailsSection(),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(child: _buildItemsSection()),
                          _buildSummarySection(),
                        ],
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildClientSection(),
                        const SizedBox(height: 16),
                        _buildInvoiceDetailsSection(),
                        const SizedBox(height: 16),
                        _buildItemsSectionMobile(),
                        const SizedBox(height: 16),
                        _buildSummarySection(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              onPressed: _saveInvoice,
              icon: const Icon(Icons.save),
              label: const Text('Save Invoice'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  // CLIENT CARD
  Widget _buildClientSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.person, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Client Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name *',
                prefixIcon: Icon(Icons.account_box_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter customer name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Customer Email (Optional)',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(v)) {
                    return 'Please enter a valid email';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // INVOICE DETAILS CARD
  Widget _buildInvoiceDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.receipt_long, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Invoice Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                labelText: 'Invoice Number *',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter invoice number'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Invoice Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_invoiceDate.day}/${_invoiceDate.month}/${_invoiceDate.year}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      child: Text(
                        '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<InvoiceStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Invoice Status',
                prefixIcon: Icon(Icons.pending_actions),
                border: OutlineInputBorder(),
              ),
              items: InvoiceStatus.values.map((status) {
                return DropdownMenuItem<InvoiceStatus>(
                  value: status,
                  child: Text(status.displayName),
                );
              }).toList(),
              onChanged: (newVal) {
                if (newVal != null) {
                  setState(() {
                    _status = newVal;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taxRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tax Rate (%)',
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || double.tryParse(v) == null) {
                  return 'Invalid tax rate';
                }
                if (double.parse(v) < 0) return 'Cannot be negative';
                return null;
              },
              onChanged: (_) {
                // Recompute invoice total on tax change
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  // ITEMS SECTION - DESKTOP VIEW
  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    'Line Items (${_items.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddItemDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No items added yet.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildItemRow(item, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ITEMS SECTION - MOBILE VIEW
  Widget _buildItemsSectionMobile() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                      'Line Items (${_items.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const Divider(height: 16),
            _items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No items added.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      return Column(
                        children: [
                          _buildItemRow(item, index),
                          if (index < _items.length - 1) const Divider(),
                        ],
                      );
                    }),
                  ),
          ],
        ),
      ),
    );
  }

  // SINGLE ITEM ROW
  Widget _buildItemRow(SalesItem item, int index) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() {
          _items.removeAt(index);
        });
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Qty: ${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}' +
              (item.discount > 0 ? ' (Discount: -\$${item.discount.toStringAsFixed(2)})' : ''),
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${item.total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _items.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // SUMMARY PANEL WITH GRADIENT GRAND TOTAL
  Widget _buildSummarySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal:', style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
              Text(
                '\$${_subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Tax (${(_taxRate * 100).toStringAsFixed(1)}%):',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
              Text(
                '\$${_taxAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade800, Colors.indigo.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total:',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
