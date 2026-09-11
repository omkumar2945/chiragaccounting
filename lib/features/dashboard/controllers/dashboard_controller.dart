import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/core/events/event_types.dart';
import 'package:chirag_accounting/features/dashboard/models/activity_model.dart';
import 'package:chirag_accounting/features/dashboard/models/kpi_model.dart';
import 'package:chirag_accounting/features/dashboard/models/notification_model.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    required this._salesService,
    required this._customerService,
    required this._productService,
  }) {
    _salesService.addListener(_onSourceDataChanged);
    _customerService.addListener(_onSourceDataChanged);
    _productService.addListener(_onSourceDataChanged);
    _eventSub = AppEventBus.instance.stream.listen(_onAppEvent);
  }

  final SalesService _salesService;
  final CustomerService _customerService;
  final ProductService _productService;
  late final StreamSubscription<AppEvent> _eventSub;

  bool _isLoading = false;
  List<KpiModel> _kpiCards = [];
  List<ActivityModel> _recentActivities = [];
  List<NotificationModel> _notifications = [];
  List<double> _monthlySales = [];
  List<double> _monthlyPurchase = [];
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  List<KpiModel> get kpiCards => _kpiCards;
  List<ActivityModel> get recentActivities => _recentActivities;
  List<NotificationModel> get notifications => _notifications;
  List<double> get monthlySales => _monthlySales;
  List<double> get monthlyPurchase => _monthlyPurchase;
  String get searchQuery => _searchQuery;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadDashboard() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 150));
    _loadLiveData();
    _isLoading = false;
    notifyListeners();
  }

  void markNotificationRead(String id) {
    _notifications = _notifications
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    notifyListeners();
  }

  void markAllRead() {
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void _loadLiveData() {
    final now = DateTime.now();
    final totalSales = _salesService.totalSales;
    final totalInvoices = _salesService.totalInvoices;
    final totalClients = _customerService.totalCustomers;
    final totalProducts = _productService.totalProducts;

    _kpiCards = [
      KpiModel(
        title: "Today's Sales",
        value: _currency(totalSales),
        subtitle: '$totalInvoices invoices',
        trend: KpiTrend.neutral,
        trendPercent: 0,
        type: KpiType.sales,
      ),
      KpiModel(
        title: "Today's Purchase",
        value: _currency(0),
        subtitle: '0 bills',
        trend: KpiTrend.neutral,
        trendPercent: 0,
        type: KpiType.purchase,
      ),
      KpiModel(
        title: 'Total Clients',
        value: '$totalClients',
        subtitle: totalClients == 1 ? '1 customer' : '$totalClients customers',
        trend: KpiTrend.neutral,
        trendPercent: 0,
        type: KpiType.clients,
      ),
      KpiModel(
        title: 'Total Products',
        value: '$totalProducts',
        subtitle: totalProducts == 1 ? '1 product' : '$totalProducts products',
        trend: KpiTrend.neutral,
        trendPercent: 0,
        type: KpiType.tasks,
      ),
      KpiModel(
        title: 'Net Profit',
        value: _currency(totalSales),
        subtitle: 'Based on sales entries',
        trend: KpiTrend.neutral,
        trendPercent: 0,
        type: KpiType.profit,
      ),
    ];

    _monthlySales = List<double>.filled(12, 0);
    _monthlyPurchase = List<double>.filled(12, 0);
    for (final invoice in _salesService.invoices) {
      final monthIndex = invoice.invoiceDate.month - 1;
      if (monthIndex >= 0 && monthIndex < 12) {
        _monthlySales[monthIndex] += invoice.grandTotal;
      }
    }

    _recentActivities = _salesService.invoices
        .map(
          (invoice) => ActivityModel(
            id: invoice.id,
            title: 'Sales Invoice #${invoice.invoiceNumber}',
            subtitle: invoice.customerName,
            type: ActivityType.sale,
            amount: invoice.grandTotal,
            timestamp: invoice.invoiceDate,
          ),
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_recentActivities.length > 5) {
      _recentActivities = _recentActivities.take(5).toList();
    }

    final pendingInvoices = _salesService.invoices
      .where((invoice) => invoice.status == InvoiceStatus.pending)
      .length;
    _notifications = [
      if (pendingInvoices > 0)
        NotificationModel(
          id: 'pending-invoices',
          title: 'Pending Invoices',
          message: '$pendingInvoices invoices are pending payment',
          type: NotificationType.pendingBills,
          createdAt: now,
        ),
      if (totalClients == 0)
        NotificationModel(
          id: 'no-clients',
          title: 'No Clients Added',
          message: 'Add your first client to start creating invoices',
          type: NotificationType.general,
          createdAt: now,
        ),
    ];
  }

  String _currency(double value) {
    return '₹${NumberFormat('#,##,##0', 'en_IN').format(value)}';
  }

  void _onSourceDataChanged() {
    if (_isLoading) return;
    _loadLiveData();
    notifyListeners();
  }

  void _onAppEvent(AppEvent event) {
    if (event.eventType != EventTypes.clientFinancialPlanUpdated) return;
    _notifications = <NotificationModel>[
      NotificationModel(
        id: event.eventId,
        title: 'Client Financial Plan Updated',
        message: event.payload['summary']?.toString() ??
            '${event.payload['clientName'] ?? 'Client'} updated a financial plan.',
        type: NotificationType.general,
        createdAt: event.timestamp.toLocal(),
      ),
      ..._notifications.where((item) => item.id != event.eventId),
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _salesService.removeListener(_onSourceDataChanged);
    _customerService.removeListener(_onSourceDataChanged);
    _productService.removeListener(_onSourceDataChanged);
    _eventSub.cancel();
    super.dispose();
  }
}
