import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final sales = context.watch<SalesService>().invoices;
    final purchases = context.watch<PurchaseService>().bills;

    final filteredSales = _clientSales(sales, user);
    final filteredPurchases = _clientPurchases(purchases, user);

    final totalSales = filteredSales.fold<double>(
      0,
      (sum, item) => sum + item.grandTotal,
    );
    final totalPurchases = filteredPurchases.fold<double>(
      0,
      (sum, item) => sum + item.grandTotal,
    );
    final totalReceipts = filteredSales.fold<double>(
      0,
      (sum, item) => sum + item.receivedAmount,
    );
    final totalPayments = filteredPurchases.fold<double>(
      0,
      (sum, item) => sum + item.paidAmount,
    );
    final bankBalance = totalReceipts - totalPayments;
    final receivables = filteredSales.fold<double>(
      0,
      (sum, item) => sum + item.outstandingAmount,
    );
    final payables = filteredPurchases.fold<double>(
      0,
      (sum, item) => sum + item.outstandingAmount,
    );

    final recentTransactions = <_TransactionRow>[
      ...filteredSales.map(
        (invoice) => _TransactionRow(
          title: 'Sales Invoice #${invoice.invoiceNumber}',
          subtitle: invoice.customerName,
          amount: invoice.grandTotal,
          type: 'sale',
          time: invoice.invoiceDate,
        ),
      ),
      ...filteredPurchases.map(
        (bill) => _TransactionRow(
          title: 'Purchase Bill #${bill.billNumber}',
          subtitle: bill.vendorName,
          amount: -bill.grandTotal,
          type: 'purchase',
          time: bill.billDate,
        ),
      ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    final flow = _buildCashFlow(filteredSales, filteredPurchases);
    final insights = <_InsightRow>[
      _InsightRow(
        label: 'Cash flow',
        value: 'Healthy this month',
        tone: Colors.green,
      ),
      _InsightRow(
        label: 'Top customer',
        value: _topCustomer(filteredSales),
        tone: Colors.blue,
      ),
      _InsightRow(
        label: 'Pending payments',
        value: '₹${_formatCurrency(payables)}',
        tone: Colors.orange,
      ),
      _InsightRow(
        label: 'GST filing',
        value: 'Due in 5 days',
        tone: Colors.purple,
      ),
    ];

    final clientName = user?.name.isNotEmpty == true ? user!.name : 'Client';

    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      body: SafeArea(
        child: Column(
          children: [
            _TopHeader(clientName: clientName),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome, $clientName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D2A3A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 1100
                            ? 4
                            : constraints.maxWidth >= 560
                            ? 2
                            : 1;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 166,
                          children: [
                            _MetricCard(
                              title: 'Sales',
                              value: '₹${_formatCurrency(totalSales)}',
                              trend: '+12.5%',
                              tone: const Color(0xFF3DAE87),
                              icon: Icons.sell_outlined,
                              subtitle: 'vs last month',
                            ),
                            _MetricCard(
                              title: 'Purchases',
                              value: '₹${_formatCurrency(totalPurchases)}',
                              trend: '+8.2%',
                              tone: const Color(0xFFEC9B2F),
                              icon: Icons.shopping_bag_outlined,
                              subtitle: 'vs last month',
                            ),
                            _MetricCard(
                              title: 'Receipts',
                              value: '₹${_formatCurrency(totalReceipts)}',
                              trend: '+6.3%',
                              tone: const Color(0xFF4B7CE9),
                              icon: Icons.account_balance_wallet_outlined,
                              subtitle: 'cash in',
                            ),
                            _MetricCard(
                              title: 'Payments',
                              value: '₹${_formatCurrency(totalPayments)}',
                              trend: '+4.1%',
                              tone: const Color(0xFFE76868),
                              icon: Icons.payments_outlined,
                              subtitle: 'cash out',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cash Flow Overview',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D2A3A),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    _LegendPill(
                                      label: 'Income',
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 16),
                                    _LegendPill(
                                      label: 'Expense',
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 220,
                                  child: CustomPaint(
                                    painter: _CashFlowChartPainter(flow),
                                    child: Container(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 1,
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI Insights',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D2A3A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...insights.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: item.tone.withOpacity(0.14),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            item.label == 'Cash flow'
                                                ? Icons.trending_up
                                                : item.label == 'Top customer'
                                                ? Icons.person
                                                : item.label ==
                                                      'Pending payments'
                                                ? Icons.pending_actions
                                                : Icons.receipt_long,
                                            size: 16,
                                            color: item.tone,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.label,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.value,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF1D2A3A),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Recent Transactions',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1D2A3A),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('View All'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...recentTransactions
                                    .take(4)
                                    .map(
                                      (txn) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: txn.amount >= 0
                                                    ? Colors.green.withOpacity(
                                                        0.12,
                                                      )
                                                    : Colors.red.withOpacity(
                                                        0.12,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                txn.type == 'sale'
                                                    ? Icons.arrow_downward
                                                    : Icons.arrow_upward,
                                                color: txn.amount >= 0
                                                    ? Colors.green
                                                    : Colors.red,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    txn.title,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF1D2A3A),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    txn.subtitle,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${txn.amount >= 0 ? '+' : '-'}₹${_formatCurrency(txn.amount.abs())}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: txn.amount >= 0
                                                        ? Colors.green.shade700
                                                        : Colors.red.shade700,
                                                  ),
                                                ),
                                                Text(
                                                  _stamp(txn.time),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Client Snapshot',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D2A3A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _SnapshotRow(
                                  label: 'Bank balance',
                                  value: '₹${_formatCurrency(bankBalance)}',
                                ),
                                _SnapshotRow(
                                  label: 'Outstanding receivables',
                                  value: '₹${_formatCurrency(receivables)}',
                                ),
                                _SnapshotRow(
                                  label: 'Outstanding payables',
                                  value: '₹${_formatCurrency(payables)}',
                                ),
                                _SnapshotRow(
                                  label: 'GST status',
                                  value: 'Returns due soon',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CashFlowPoint> _buildCashFlow(
    List<SalesInvoice> sales,
    List<PurchaseBill> purchases,
  ) {
    final income = List<double>.filled(12, 0);
    final expense = List<double>.filled(12, 0);

    for (final invoice in sales) {
      final index = invoice.invoiceDate.month - 1;
      if (index >= 0 && index < 12) {
        income[index] += invoice.grandTotal;
      }
    }

    for (final bill in purchases) {
      final index = bill.billDate.month - 1;
      if (index >= 0 && index < 12) {
        expense[index] += bill.grandTotal;
      }
    }

    return [
      for (int i = 0; i < 12; i++)
        _CashFlowPoint(income: income[i], expense: expense[i]),
    ];
  }

  List<SalesInvoice> _clientSales(List<SalesInvoice> sales, UserModel? user) {
    if (user == null) return const <SalesInvoice>[];
    final clientId = user.id;
    final fallbackName = user.firmName.isNotEmpty ? user.firmName : user.name;
    return sales
        .where((invoice) {
          if (invoice.createdByUserId.isNotEmpty &&
              invoice.createdByUserId == clientId) {
            return true;
          }
          if (invoice.createdByClient) return true;
          final customerName = invoice.customerName.trim();
          final sellerName = invoice.sellerName.trim();
          return customerName.toLowerCase() == fallbackName.toLowerCase() ||
              sellerName.toLowerCase() == fallbackName.toLowerCase();
        })
        .toList(growable: false);
  }

  List<PurchaseBill> _clientPurchases(
    List<PurchaseBill> purchases,
    UserModel? user,
  ) {
    if (user == null) return const <PurchaseBill>[];
    final clientId = user.id;
    final fallbackName = user.firmName.isNotEmpty ? user.firmName : user.name;
    return purchases
        .where((bill) {
          if (bill.notes.toString().contains(clientId)) return true;
          final vendorName = bill.vendorName.trim();
          return vendorName.toLowerCase() == fallbackName.toLowerCase();
        })
        .toList(growable: false);
  }

  static String _formatCurrency(num value) {
    return NumberFormat('#,##,##0', 'en_IN').format(value);
  }

  static String _stamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return '1 day ago';
    return '$diff days ago';
  }

  static String _topCustomer(List<SalesInvoice> sales) {
    if (sales.isEmpty) return 'No sales yet';
    final map = <String, double>{};
    for (final invoice in sales) {
      map[invoice.customerName] =
          (map[invoice.customerName] ?? 0) + invoice.grandTotal;
    }
    final top = map.entries.reduce(
      (best, current) => best.value >= current.value ? best : current,
    );
    return top.key;
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.clientName});

  final String clientName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1000;
        return Container(
          color: const Color(0xFFF8FAFF),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C4D9F),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'C',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'CHIRAG ACCOUNTING',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: Color(0xFF163057),
                  ),
                ),
              ),
              if (!compact) ...[
                Container(
                  width: 220,
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E7F3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Color(0xFF7D8AA5), size: 19),
                      SizedBox(width: 8),
                      Text(
                        'Search anything...',
                        style: TextStyle(
                          color: Color(0xFF7D8AA5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              _MiniActionButton(
                label: compact ? '' : 'Quick Actions',
                icon: Icons.flash_on_rounded,
                filled: true,
              ),
              const SizedBox(width: 12),
              const _MiniActionButton(
                label: '',
                icon: Icons.notifications_none_outlined,
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    this.label = '',
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF0E6F5E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E7F3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : const Color(0xFF1D2A3A),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : const Color(0xFF1D2A3A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    return child;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.tone,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String trend;
  final Color tone;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFe7edf8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tone, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 11,
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D2A3A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E9F5)),
      ),
      child: child,
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1D2A3A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowChartPainter extends CustomPainter {
  _CashFlowChartPainter(this.points);

  final List<_CashFlowPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final incomePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final expensePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final gridPaint = Paint()
      ..color = const Color(0xFFE7ECF5)
      ..style = PaintingStyle.stroke;

    final width = size.width;
    final height = size.height;
    final maxValue =
        points.fold<double>(
          0,
          (sum, item) => math.max(sum, math.max(item.income, item.expense)),
        ) *
        1.15;

    final zeroY = height - 22;
    final xStep = width / (points.length - 1);

    void drawSeries(List<double> values, Paint paint) {
      final path = Path();
      for (int i = 0; i < values.length; i++) {
        final x = i * xStep;
        final y = zeroY - ((values[i] / maxValue) * (height - 40));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    for (int i = 0; i < 5; i++) {
      final y = (height - 20) - (i / 4) * (height - 35);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    drawSeries(points.map((p) => p.income).toList(), incomePaint);
    drawSeries(points.map((p) => p.expense).toList(), expensePaint);
  }

  @override
  bool shouldRepaint(covariant _CashFlowChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _CashFlowPoint {
  const _CashFlowPoint({required this.income, required this.expense});

  final double income;
  final double expense;
}

class _TransactionRow {
  const _TransactionRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.time,
  });

  final String title;
  final String subtitle;
  final double amount;
  final String type;
  final DateTime time;
}

class _InsightRow {
  const _InsightRow({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;
}
