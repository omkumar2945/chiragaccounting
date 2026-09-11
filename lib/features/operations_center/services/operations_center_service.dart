import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/realtime/realtime_gateway_service.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/customers/models/customer.dart';
import 'package:chirag_accounting/features/purchase/models/purchase_bill.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';
import 'package:chirag_accounting/features/tasks/models/work_task.dart';
import 'package:chirag_accounting/features/tasks/services/task_engine_service.dart';
import 'package:chirag_accounting/features/timeline/services/timeline_engine_service.dart';

class OperationsCenterService extends ChangeNotifier {
  OperationsCenterService({
    required SalesService salesService,
    required PurchaseService purchaseService,
    required CustomerService customerService,
    required TaskEngineService taskEngineService,
    required TimelineEngineService timelineEngineService,
    required RealtimeGatewayService realtimeGatewayService,
    Dio? dio,
  })  : _salesService = salesService,
        _purchaseService = purchaseService,
        _customerService = customerService,
        _taskEngineService = taskEngineService,
        _timelineEngineService = timelineEngineService,
      _realtimeGatewayService = realtimeGatewayService,
        _dio = dio ?? ApiClient.dio {
    _salesService.addListener(_onSourceDataChanged);
    _purchaseService.addListener(_onSourceDataChanged);
    _customerService.addListener(_onSourceDataChanged);
    _taskEngineService.addListener(_onSourceDataChanged);
    _timelineEngineService.addListener(_onSourceDataChanged);
    _rebuildSnapshot();
  }

  final SalesService _salesService;
  final PurchaseService _purchaseService;
  final CustomerService _customerService;
  final TaskEngineService _taskEngineService;
  final TimelineEngineService _timelineEngineService;
  final RealtimeGatewayService _realtimeGatewayService;
  final Dio _dio;

  final StreamController<OperationsSnapshot> _streamController =
      StreamController<OperationsSnapshot>.broadcast();

  StreamSubscription<List<int>>? _sseSubscription;
  StreamSubscription<Map<String, dynamic>>? _dashboardChannelSubscription;
  Timer? _refreshTimer;

  OperationsSnapshot _snapshot = OperationsSnapshot.empty();
  OperationsSnapshot get snapshot => _snapshot;

  Stream<OperationsSnapshot> get updates => _streamController.stream;

  bool _streamingStarted = false;
  bool _sseConnected = false;

  bool get sseConnected => _sseConnected;

  void startStreaming() {
    if (_streamingStarted) return;
    _streamingStarted = true;

    _rebuildSnapshot();
    const scope = RealtimeScope(
      tenantId: 'default-tenant',
      businessId: 'chirag-main',
      userId: 'system',
      role: 'system',
    );
    _realtimeGatewayService.connect(scope: scope);
    _dashboardChannelSubscription = _realtimeGatewayService
        .subscribeScoped(
          topic: RealtimeTopic.dashboardUpdates,
          scope: scope,
        )
        .listen((payload) {
      _applyServerPayload(payload);
    });
    _connectSse();

    // Fallback cadence keeps counters fresh even when SSE is unavailable.
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _rebuildSnapshot();
      _pullMissionSnapshot();
    });
  }

  Future<void> refreshNow() async {
    _rebuildSnapshot();
    await _pullMissionSnapshot();
  }

  List<String> get knownClientNames {
    final names = <String>{};
    for (final c in _customerService.customers) {
      final name = c.customerName.trim();
      if (name.isNotEmpty) names.add(name);
    }
    for (final invoice in _salesService.invoices) {
      final name = invoice.customerName.trim();
      if (name.isNotEmpty) names.add(name);
    }
    final result = names.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Customer? findCustomerByName(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final customer in _customerService.customers) {
      if (customer.customerName.trim().toLowerCase() == key) {
        return customer;
      }
    }
    return null;
  }

  List<OperationTimelineEvent> timelineForClient(String clientName) {
    final key = clientName.trim().toLowerCase();
    final events = _timelineEngineService
        .forClient(clientName)
        .where((event) => event.clientName.trim().toLowerCase() == key)
        .toList(growable: false)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (events.isNotEmpty) return events;
    final fallback = timelineFeed()
        .where((event) => event.clientName.trim().toLowerCase() == key)
        .toList(growable: false)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return fallback;
  }

  List<OperationTimelineEvent> timelineFeed() {
    final liveEvents = _timelineEngineService.allEvents;
    if (liveEvents.isNotEmpty) {
      return List<OperationTimelineEvent>.from(liveEvents)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    final events = _derivedTimelineFeed();
    return events;
  }

  List<OperationTimelineEvent> _derivedTimelineFeed() {
    final events = <OperationTimelineEvent>[];
    for (final invoice in _salesService.invoices) {
      events.add(
        OperationTimelineEvent(
          title: 'Invoice Uploaded',
          detail: 'Invoice ${invoice.invoiceNumber} (${invoice.status.displayName})',
          timestamp: invoice.invoiceDate,
          clientName: invoice.customerName,
          source: 'Sales',
          severity: _severityFromInvoice(invoice),
        ),
      );
      if (invoice.paymentDate != null) {
        events.add(
          OperationTimelineEvent(
            title: 'Payment Received',
            detail:
                'Received ${invoice.receivedAmount.toStringAsFixed(2)} against ${invoice.invoiceNumber}',
            timestamp: invoice.paymentDate!,
            clientName: invoice.customerName,
            source: 'Collections',
            severity: OperationSeverity.info,
          ),
        );
      }
    }

    for (final bill in _purchaseService.bills) {
      events.add(
        OperationTimelineEvent(
          title: 'Purchase Uploaded',
          detail: 'Bill ${bill.billNumber} (${bill.mode.name})',
          timestamp: bill.billDate,
          clientName: bill.vendorName,
          source: 'Purchase',
          severity:
              bill.mode == PurchaseEntryMode.upload ? OperationSeverity.info : OperationSeverity.success,
        ),
      );
      if (bill.paymentDate != null) {
        events.add(
          OperationTimelineEvent(
            title: 'Payment Processed',
            detail: 'Paid ${bill.paidAmount.toStringAsFixed(2)} against ${bill.billNumber}',
            timestamp: bill.paymentDate!,
            clientName: bill.vendorName,
            source: 'Payments',
            severity: OperationSeverity.info,
          ),
        );
      }
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  OperationSeverity _severityFromInvoice(SalesInvoice invoice) {
    if (invoice.status == InvoiceStatus.cancelled) {
      return OperationSeverity.warning;
    }
    if (invoice.status == InvoiceStatus.pending) {
      return OperationSeverity.warning;
    }
    if (invoice.status == InvoiceStatus.paid) {
      return OperationSeverity.success;
    }
    return OperationSeverity.info;
  }

  void _onSourceDataChanged() {
    _rebuildSnapshot();
  }

  void _rebuildSnapshot() {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final quarterStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
    final yearStart = DateTime(now.year, 1, 1);

    double sumSalesInRange(DateTime start) {
      return _salesService.invoices
          .where((invoice) => !invoice.invoiceDate.isBefore(start))
          .fold<double>(0, (sum, invoice) => sum + invoice.grandTotal);
    }

    final clients = _customerService.totalCustomers;
    final activeClients = _customerService.activeCustomers;
    final inactiveClients = (clients - activeClients).clamp(0, clients);

    final newThisMonth = _salesService.invoices
        .where((invoice) => !invoice.invoiceDate.isBefore(currentMonthStart))
        .map((invoice) => invoice.customerName.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;

    final salesRevenueMonth = sumSalesInRange(currentMonthStart);
    final salesRevenueQuarter = sumSalesInRange(quarterStart);
    final salesRevenueYear = sumSalesInRange(yearStart);

    final salesOutstanding = _salesService.invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.outstandingAmount,
    );

    final purchaseOutstanding = _purchaseService.bills.fold<double>(
      0,
      (sum, bill) => sum + bill.outstandingAmount,
    );

    final recoveryThisMonth = _salesService.invoices
        .where((invoice) {
          final paymentDate = invoice.paymentDate;
          return paymentDate != null && !paymentDate.isBefore(currentMonthStart);
        })
        .fold<double>(0, (sum, invoice) => sum + invoice.receivedAmount);

    final invoicesToday = _salesService.invoices.where((invoice) {
      final d = invoice.invoiceDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final purchaseBillsToday = _purchaseService.bills.where((bill) {
      final d = bill.billDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final ocrCompleted = _purchaseService.bills
            .where((bill) => bill.mode == PurchaseEntryMode.upload)
            .length +
        _salesService.invoices
            .where((invoice) => invoice.attachmentPaths.isNotEmpty)
            .length;

    final ocrFailed = _purchaseService.bills
            .where((bill) => bill.notes.toLowerCase().contains('ocr fail'))
            .length +
        _salesService.invoices
            .where((invoice) => invoice.notes.toLowerCase().contains('ocr fail'))
            .length;

    final pendingVerification = _salesService.invoices
        .where((invoice) => invoice.status == InvoiceStatus.draft)
        .length;

    final pendingApprovals = _salesService.invoices
            .where((invoice) => invoice.status == InvoiceStatus.pending)
            .length +
        _purchaseService.bills
            .where((bill) => bill.paymentStatus != PurchasePaymentStatus.fullyPaid)
            .length;

    final pendingUploads = _customerService.totalCustomers > 0
        ? (_customerService.totalCustomers -
                _salesService.invoices
                    .map((invoice) => invoice.customerName.trim().toLowerCase())
                    .where((name) => name.isNotEmpty)
                    .toSet()
                    .length)
            .clamp(0, _customerService.totalCustomers)
        : 0;

    final todayCollections = _salesService.invoices
        .where((invoice) {
          final d = invoice.paymentDate;
          return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
        })
        .fold<double>(0, (sum, invoice) => sum + invoice.receivedAmount);

    final todayPayments = _purchaseService.bills
        .where((bill) {
          final d = bill.paymentDate;
          return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
        })
        .fold<double>(0, (sum, bill) => sum + bill.paidAmount);

    final pendingFiling = pendingApprovals + pendingVerification;
    final todayQueries = pendingApprovals.clamp(0, 9999);
    final todayAuditTasks = (_purchaseService.totalBills - purchaseBillsToday).clamp(0, 9999);
    final pendingOcr = _taskEngineService.countByBucket(WorkQueueBucket.pendingOcr);
    final waitingClient = _taskEngineService.countByBucket(WorkQueueBucket.waitingClient);
    final waitingAccountant = _taskEngineService.countByBucket(WorkQueueBucket.waitingAccountant);
    final waitingCa = _taskEngineService.countByBucket(WorkQueueBucket.waitingCa);
    final waitingAuditor = _taskEngineService.countByBucket(WorkQueueBucket.waitingAuditor);
    final waitingApproval = _taskEngineService.countByBucket(WorkQueueBucket.waitingApproval);
    final completedTodayQueue = _taskEngineService.countByBucket(WorkQueueBucket.completedToday);
    final overdueQueue = _taskEngineService.countByBucket(WorkQueueBucket.overdue);
    final escalatedQueue = _taskEngineService.countByBucket(WorkQueueBucket.escalated);

    final tasks = pendingApprovals + pendingVerification + pendingFiling;
    final completed = invoicesToday + purchaseBillsToday;

    final ocrTotal = (ocrCompleted + ocrFailed).clamp(1, 1 << 30);
    final ocrAccuracy = ((ocrCompleted / ocrTotal) * 100).round();

    final metrics = <String, num>{
      'Clients': clients,
      'Active Clients': activeClients,
      'Inactive': inactiveClients,
      'New This Month': newThisMonth,
      'Suspended': inactiveClients,
      'Monthly Revenue (L)': _inLakhs(salesRevenueMonth),
      'Quarterly Revenue (L)': _inLakhs(salesRevenueQuarter),
      'Yearly Revenue (L)': _inLakhs(salesRevenueYear),
      'Outstanding (L)': _inLakhs(salesOutstanding + purchaseOutstanding),
      'Recovery This Month (L)': _inLakhs(recoveryThisMonth),
      'Bank Balance (L)': _inLakhs((salesRevenueMonth - todayPayments).clamp(0, double.maxFinite)),
      'Cash Flow Score': ((salesRevenueMonth + 1) / (todayPayments + 1) * 50)
          .round()
          .clamp(1, 100),
      'Pending Uploads': pendingUploads,
      'Invoices Created': invoicesToday,
      'Purchase Bills': purchaseBillsToday,
      'OCR Completed': ocrCompleted,
      'OCR Failed': ocrFailed,
      'Pending Verification': pendingVerification,
      'OCR Queue': (pendingUploads + ocrFailed).clamp(0, 9999),
      'Pending Approvals': pendingApprovals,
      'Pending Filing': pendingFiling,
      'Today Collections (L)': _inLakhs(todayCollections),
      'Today Payments (L)': _inLakhs(todayPayments),
      'Today Queries': todayQueries,
      'Today Audit Tasks': todayAuditTasks,
      'Ai Classification': ocrCompleted,
      'Duplicate Detections': _estimateDuplicateDetections(),
      'Gst Mismatch Flags': pendingFiling,
      'Ledger Suggestions': _salesService.totalInvoices,
      'Hsn Suggestions': _purchaseService.totalBills,
      'Missing Documents': pendingUploads,
      'Compliance Prediction Alerts': pendingFiling,
      'Risk Detections': (pendingApprovals / 2).round(),
      'Fraud Alerts': _estimateFraudAlerts(),
      'GST Returns Due': pendingFiling,
      'Income Tax Due': (clients / 4).round(),
      'ROC Due': (clients / 10).round(),
      'TDS Returns': (clients / 6).round(),
      'TCS Returns': (clients / 25).round(),
      'Audit Pending': todayAuditTasks,
      'Books Pending': pendingApprovals,
      'Bank Reconciliation': (todayPayments > 0 ? 1 : 0) + (pendingApprovals / 3).round(),
      'Outstanding Queries': todayQueries,
      'Unread Client Messages': (pendingApprovals / 2).round(),
      "Today's Tasks": tasks,
      'Completed Today': completed,
      'Revenue Growth (%)': _estimateGrowthPercent(salesRevenueMonth, salesRevenueQuarter),
      'Client Growth (%)': clients == 0 ? 0 : ((newThisMonth / clients) * 100).round(),
      'OCR Accuracy (%)': ocrAccuracy,
      'Automation Coverage (%)': _estimateAutomationCoverage(ocrCompleted, _purchaseService.totalBills + _salesService.totalInvoices),
      'Avg Response Time (m)': 18,
      'System Errors': ocrFailed,
      'Background Jobs': tasks,
      'Pending OCR': pendingOcr,
      'Waiting Client': waitingClient,
      'Waiting Accountant': waitingAccountant,
      'Waiting CA': waitingCa,
      'Waiting Auditor': waitingAuditor,
      'Waiting Approval': waitingApproval,
      'Completed Today Queue': completedTodayQueue,
      'Overdue': overdueQueue,
      'Escalated': escalatedQueue,
    };

    final mission = <String, String>{
      'Server': 'LIVE',
      'API': _sseConnected ? 'STREAMING' : 'POLLING',
      'OCR': '${metrics['OCR Queue']} QUEUE',
      'GST API': ApiConstants.useMockApi ? 'MOCK' : 'UP',
      'Bank API': ApiConstants.useMockApi ? 'MOCK' : 'UP',
      'WhatsApp API': 'DELAY',
      'Email Queue': '${(metrics['Outstanding Queries'] as num).round()}',
      'SMS Queue': '${(metrics['Unread Client Messages'] as num).round()}',
      'Notification Queue': '${(metrics['Pending Approvals'] as num).round()}',
      'Jobs': '${(metrics["Today's Tasks"] as num).round()}',
      'CPU': '63%',
      'Memory': '58%',
      'Errors': '${(metrics['System Errors'] as num).round()}',
    };

    _snapshot = _snapshot.copyWith(
      generatedAt: now,
      metrics: metrics,
      mission: mission,
      timeline: timelineFeed(),
      streamState: _sseConnected ? 'sse-connected' : 'polling',
    );

    notifyListeners();
    _streamController.add(_snapshot);
  }

  int _estimateDuplicateDetections() {
    var duplicates = 0;
    final seen = <String>{};
    for (final invoice in _salesService.invoices) {
      final key = '${invoice.customerName.trim().toLowerCase()}|${invoice.grandTotal.toStringAsFixed(2)}';
      if (!seen.add(key)) {
        duplicates += 1;
      }
    }
    return duplicates;
  }

  int _estimateFraudAlerts() {
    return _salesService.invoices
        .where((invoice) => invoice.outstandingAmount > invoice.grandTotal * 0.8)
        .length;
  }

  int _estimateGrowthPercent(double month, double quarter) {
    if (quarter <= 0) return 0;
    return ((month / quarter) * 100).round().clamp(0, 999);
  }

  int _estimateAutomationCoverage(int autoCount, int totalCount) {
    if (totalCount <= 0) return 0;
    return ((autoCount / totalCount) * 100).round().clamp(0, 100);
  }

  int _inLakhs(double value) {
    return (value / 100000).round();
  }

  Future<void> _pullMissionSnapshot() async {
    if (ApiConstants.useMockApi) return;
    try {
      final response = await _dio.get<Map<String, dynamic>>('/ops/mission-control');
      final payload = response.data;
      if (payload == null) return;
      _applyServerPayload(payload);
    } catch (_) {
      // Silent fallback to local module-driven stream.
    }
  }

  Future<void> _connectSse() async {
    if (ApiConstants.useMockApi) {
      _sseConnected = false;
      return;
    }
    try {
      final response = await _dio.get<ResponseBody>(
        '/ops/stream/sse',
        options: Options(responseType: ResponseType.stream),
      );
      final body = response.data;
      if (body == null) {
        _sseConnected = false;
        return;
      }

      _sseConnected = true;
      notifyListeners();

      _sseSubscription = body.stream.listen(
        (chunk) {
          final text = utf8.decode(chunk);
          final lines = const LineSplitter().convert(text);
          for (final line in lines) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('data:')) continue;
            final payload = trimmed.substring(5).trim();
            if (payload.isEmpty || payload == '[DONE]') continue;
            try {
              final map = jsonDecode(payload);
              if (map is Map<String, dynamic>) {
                _applyServerPayload(map);
              }
            } catch (_) {
              // Ignore malformed events.
            }
          }
        },
        onError: (_) {
          _sseConnected = false;
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (_) {
      _sseConnected = false;
      notifyListeners();
    }
  }

  void _applyServerPayload(Map<String, dynamic> payload) {
    final rawMission = payload['mission'];
    final rawKpi = payload['kpi'];

    final nextMission = Map<String, String>.from(_snapshot.mission);
    final nextMetrics = Map<String, num>.from(_snapshot.metrics);

    if (rawMission is Map) {
      for (final entry in rawMission.entries) {
        final key = entry.key.toString();
        nextMission[key] = entry.value.toString();
      }
    }

    if (rawKpi is Map) {
      for (final entry in rawKpi.entries) {
        final key = entry.key.toString();
        final value = num.tryParse(entry.value.toString());
        if (value != null) {
          nextMetrics[key] = value;
        }
      }
    }

    _snapshot = _snapshot.copyWith(
      generatedAt: DateTime.now(),
      mission: nextMission,
      metrics: nextMetrics,
      streamState: _sseConnected ? 'sse-connected' : _snapshot.streamState,
    );

    notifyListeners();
    _streamController.add(_snapshot);
  }

  @override
  void dispose() {
    _salesService.removeListener(_onSourceDataChanged);
    _purchaseService.removeListener(_onSourceDataChanged);
    _customerService.removeListener(_onSourceDataChanged);
    _taskEngineService.removeListener(_onSourceDataChanged);
    _timelineEngineService.removeListener(_onSourceDataChanged);
    _sseSubscription?.cancel();
    _dashboardChannelSubscription?.cancel();
    _refreshTimer?.cancel();
    _streamController.close();
    super.dispose();
  }
}

@immutable
class OperationsSnapshot {
  const OperationsSnapshot({
    required this.metrics,
    required this.mission,
    required this.timeline,
    required this.generatedAt,
    required this.streamState,
  });

  final Map<String, num> metrics;
  final Map<String, String> mission;
  final List<OperationTimelineEvent> timeline;
  final DateTime generatedAt;
  final String streamState;

  static OperationsSnapshot empty() {
    return OperationsSnapshot(
      metrics: const <String, num>{},
      mission: const <String, String>{},
      timeline: const <OperationTimelineEvent>[],
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      streamState: 'initializing',
    );
  }

  OperationsSnapshot copyWith({
    Map<String, num>? metrics,
    Map<String, String>? mission,
    List<OperationTimelineEvent>? timeline,
    DateTime? generatedAt,
    String? streamState,
  }) {
    return OperationsSnapshot(
      metrics: metrics ?? this.metrics,
      mission: mission ?? this.mission,
      timeline: timeline ?? this.timeline,
      generatedAt: generatedAt ?? this.generatedAt,
      streamState: streamState ?? this.streamState,
    );
  }
}

enum OperationSeverity { info, success, warning, critical }

@immutable
class OperationTimelineEvent {
  const OperationTimelineEvent({
    required this.title,
    required this.detail,
    required this.timestamp,
    required this.clientName,
    required this.source,
    required this.severity,
  });

  final String title;
  final String detail;
  final DateTime timestamp;
  final String clientName;
  final String source;
  final OperationSeverity severity;
}