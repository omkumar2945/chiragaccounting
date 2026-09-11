import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/vouchers/presentation/models/voucher_entry_type.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_form_screen.dart';

class VoucherEntryDashboardScreen extends StatelessWidget {
  const VoucherEntryDashboardScreen({super.key});

  static const List<VoucherEntryType> _allTypes = <VoucherEntryType>[
    VoucherEntryType.payment,
    VoucherEntryType.receipt,
    VoucherEntryType.contra,
    VoucherEntryType.journal,
    VoucherEntryType.purchase,
    VoucherEntryType.sales,
    VoucherEntryType.debitNote,
    VoucherEntryType.creditNote,
    VoucherEntryType.expense,
    VoucherEntryType.income,
    VoucherEntryType.bankTransfer,
    VoucherEntryType.cashTransfer,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Voucher Entry Dashboard'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voucher Entry',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a voucher type to open a professional entry form.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  var columns = 1;
                  if (width >= 1200) {
                    columns = 4;
                  } else if (width >= 900) {
                    columns = 3;
                  } else if (width >= 600) {
                    columns = 2;
                  }

                  return GridView.builder(
                    itemCount: _allTypes.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.22,
                    ),
                    itemBuilder: (context, index) {
                      final type = _allTypes[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VoucherEntryFormScreen(type: type),
                            ),
                          );
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD9E2F2)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F0A3A86),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9F1FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    type.icon,
                                    color: const Color(0xFF1A237E),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  type.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  type.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
