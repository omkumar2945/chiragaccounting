import 'package:flutter/material.dart';

class InvoiceItemTile extends StatelessWidget {
  final String productName;
  final String hsnCode;
  final String unit;
  final double quantity;
  final double rate;
  final double gst;
  final double amount;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const InvoiceItemTile({
    super.key,
    required this.productName,
    required this.hsnCode,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.gst,
    required this.amount,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Row(
              children: [

                const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(
                    Icons.inventory_2,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "HSN : $hsnCode",
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.blue,
                  ),
                ),

                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [

                _buildValue(
                  "Unit",
                  unit,
                ),

                _buildValue(
                  "Qty",
                  quantity.toString(),
                ),

                _buildValue(
                  "Rate",
                  "₹${rate.toStringAsFixed(2)}",
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [

                _buildValue(
                  "GST",
                  "${gst.toStringAsFixed(0)}%",
                ),

                _buildValue(
                  "Amount",
                  "₹${amount.toStringAsFixed(2)}",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValue(
    String title,
    String value,
  ) {
    return Column(
      children: [

        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}