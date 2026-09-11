import 'package:flutter/material.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class InvoiceHeader extends StatelessWidget {
  final TextEditingController invoiceNumberController;
  final TextEditingController invoiceDateController;
  final TextEditingController dueDateController;
  final TextEditingController paymentTermsController;

  final String placeOfSupply;
  final ValueChanged<String?> onPlaceChanged;

  const InvoiceHeader({
    super.key,
    required this.invoiceNumberController,
    required this.invoiceDateController,
    required this.dueDateController,
    required this.paymentTermsController,
    required this.placeOfSupply,
    required this.onPlaceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Invoice Information",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: invoiceNumberController,
              decoration: const InputDecoration(
                labelText: "Invoice Number",
                prefixIcon: Icon(Icons.receipt_long),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: invoiceDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Invoice Date",
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: TextFormField(
                    controller: dueDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Due Date",
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SearchableDropdownFormField<String>(
              value: placeOfSupply,
              decoration: const InputDecoration(
                labelText: "Place of Supply",
                border: OutlineInputBorder(),
              ),
              items: const [
                "Karnataka",
                "Maharashtra",
                "Tamil Nadu",
                "Gujarat",
                "Rajasthan",
              ],
              itemLabelBuilder: (place) => place,
              onChanged: onPlaceChanged,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: paymentTermsController,
              decoration: const InputDecoration(
                labelText: "Payment Terms",
                prefixIcon: Icon(Icons.payment),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}