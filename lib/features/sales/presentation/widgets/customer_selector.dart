import 'package:flutter/material.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class CustomerSelector extends StatelessWidget {
  final TextEditingController customerNameController;
  final TextEditingController mobileController;
  final TextEditingController gstController;
  final TextEditingController billingAddressController;
  final TextEditingController shippingAddressController;

  final List<String> customers;
  final String? selectedCustomer;
  final ValueChanged<String?> onCustomerChanged;

  const CustomerSelector({
    super.key,
    required this.customerNameController,
    required this.mobileController,
    required this.gstController,
    required this.billingAddressController,
    required this.shippingAddressController,
    required this.customers,
    required this.selectedCustomer,
    required this.onCustomerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Customer Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            SearchableDropdownFormField<String>(
              value: selectedCustomer,
              decoration: const InputDecoration(
                labelText: "Select Customer",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              items: customers,
              itemLabelBuilder: (customer) => customer,
              onChanged: onCustomerChanged,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              inputFormatters: indianMobileInputFormatters(),
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: gstController,
              decoration: const InputDecoration(
                labelText: "GSTIN",
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: billingAddressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Billing Address",
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: shippingAddressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Shipping Address",
                prefixIcon: Icon(Icons.local_shipping),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
