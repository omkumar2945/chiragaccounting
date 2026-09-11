import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/sales/presentation/pages/add_sales_invoice_screen.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

class TaxInvoiceScreen extends StatelessWidget {
  const TaxInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Invoice'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AddSalesInvoiceScreen(invoiceType: SalesInvoiceType.tax),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Tax Invoice'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Consumer<SalesService>(
        builder: (context, salesService, _) {
          final invoices = salesService
              .filterByType(SalesInvoiceType.tax)
              .reversed
              .toList(growable: false);

          if (invoices.isEmpty) {
            return const Center(
              child: Text(
                'No tax invoices yet.\nCreate one using New Tax Invoice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.receipt_long, color: Colors.orange),
                  ),
                  title: Text('Invoice #${invoice.invoiceNumber}'),
                  subtitle: Text(
                    '${invoice.customerName}\n₹ ${invoice.grandTotal.toStringAsFixed(2)}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoice.status.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${invoice.items.length} items',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
