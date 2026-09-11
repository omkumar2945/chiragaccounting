import 'package:flutter/material.dart';

class InvoiceSummary extends StatelessWidget {
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double discount;
  final double roundOff;
  final double grandTotal;

  const InvoiceSummary({
    super.key,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.discount,
    required this.roundOff,
    required this.grandTotal,
  });

  Widget _buildRow(
    String title,
    double value, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isTotal ? 18 : 15,
                fontWeight:
                    isTotal ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            "₹ ${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight:
                  isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.blue : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Invoice Summary",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(height: 30),

            _buildRow(
              "Taxable Amount",
              taxableAmount,
            ),

            _buildRow(
              "Discount",
              discount,
            ),

            _buildRow(
              "CGST",
              cgst,
            ),

            _buildRow(
              "SGST",
              sgst,
            ),

            _buildRow(
              "IGST",
              igst,
            ),

            _buildRow(
              "Round Off",
              roundOff,
            ),

            const Divider(height: 30),

            _buildRow(
              "Grand Total",
              grandTotal,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}