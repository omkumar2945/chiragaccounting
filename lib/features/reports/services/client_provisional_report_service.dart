import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/reports/services/provisional_report_service.dart';

enum ClientProvisionalReportStatus { submitted, finalized }

class ClientProvisionalReport {
  const ClientProvisionalReport({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.preparedBy,
    required this.createdAt,
    required this.status,
    required this.growthPercent,
    required this.projections,
    this.finalizedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String preparedBy;
  final DateTime createdAt;
  final ClientProvisionalReportStatus status;
  final double growthPercent;
  final List<ClientProvisionalProjection> projections;
  final DateTime? finalizedAt;

  ClientProvisionalReport copyWith({
    ClientProvisionalReportStatus? status,
    DateTime? finalizedAt,
  }) => ClientProvisionalReport(
    id: id,
    clientId: clientId,
    clientName: clientName,
    preparedBy: preparedBy,
    createdAt: createdAt,
    status: status ?? this.status,
    growthPercent: growthPercent,
    projections: projections,
    finalizedAt: finalizedAt ?? this.finalizedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'preparedBy': preparedBy,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'growthPercent': growthPercent,
    'projections': projections.map((item) => item.toJson()).toList(),
    'finalizedAt': finalizedAt?.toIso8601String(),
  };

  factory ClientProvisionalReport.fromJson(Map<String, dynamic> json) {
    return ClientProvisionalReport(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? 'Client',
      preparedBy: json['preparedBy']?.toString() ?? 'CA',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      status: ClientProvisionalReportStatus.values.firstWhere(
        (item) => item.name == json['status']?.toString(),
        orElse: () => ClientProvisionalReportStatus.submitted,
      ),
      growthPercent: (json['growthPercent'] as num?)?.toDouble() ?? 0,
      projections: (json['projections'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ClientProvisionalProjection.fromJson)
          .toList(growable: false),
      finalizedAt: DateTime.tryParse(json['finalizedAt']?.toString() ?? ''),
    );
  }
}

class ClientProvisionalProjection {
  const ClientProvisionalProjection({
    required this.label,
    required this.totalIncome,
    required this.netProfit,
    required this.totalAssets,
    required this.netCashFlow,
  });

  final String label;
  final double totalIncome;
  final double netProfit;
  final double totalAssets;
  final double netCashFlow;

  factory ClientProvisionalProjection.fromReport(FinancialProjectionYear item) =>
      ClientProvisionalProjection(
        label: item.label,
        totalIncome: item.totalIncome,
        netProfit: item.netProfit,
        totalAssets: item.totalAssets,
        netCashFlow: item.netCashFlow,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'totalIncome': totalIncome,
    'netProfit': netProfit,
    'totalAssets': totalAssets,
    'netCashFlow': netCashFlow,
  };

  factory ClientProvisionalProjection.fromJson(Map<String, dynamic> json) =>
      ClientProvisionalProjection(
        label: json['label']?.toString() ?? 'Year',
        totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0,
        netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0,
        totalAssets: (json['totalAssets'] as num?)?.toDouble() ?? 0,
        netCashFlow: (json['netCashFlow'] as num?)?.toDouble() ?? 0,
      );
}

class ClientProvisionalReportService {
  const ClientProvisionalReportService();

  static const _storageKey = 'client_finalized_provisional_reports_v1';

  Future<List<ClientProvisionalReport>> reportsForClient(String clientId) async {
    final reports = await _read();
    return reports
        .where(
          (item) =>
              item.clientId == clientId &&
              item.status == ClientProvisionalReportStatus.finalized,
        )
        .toList(growable: false);
  }

  Future<void> submit({
    required String clientId,
    required String clientName,
    required String preparedBy,
    required FinancialProjectionReport report,
  }) async {
    final reports = await _read();
    reports.add(
      ClientProvisionalReport(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        clientId: clientId,
        clientName: clientName,
        preparedBy: preparedBy,
        createdAt: DateTime.now(),
        status: ClientProvisionalReportStatus.submitted,
        growthPercent: report.growthPercent,
        projections: report.projections
            .map(ClientProvisionalProjection.fromReport)
            .toList(growable: false),
      ),
    );
    await _write(reports);
  }

  Future<void> finalizeLatestForClient(String clientId) async {
    final reports = await _read();
    final index = reports.lastIndexWhere(
      (item) =>
          item.clientId == clientId &&
          item.status == ClientProvisionalReportStatus.submitted,
    );
    if (index < 0) return;
    reports[index] = reports[index].copyWith(
      status: ClientProvisionalReportStatus.finalized,
      finalizedAt: DateTime.now(),
    );
    await _write(reports);
  }

  Future<List<ClientProvisionalReport>> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <ClientProvisionalReport>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ClientProvisionalReport.fromJson)
          .toList(growable: true);
    } catch (_) {
      return <ClientProvisionalReport>[];
    }
  }

  Future<void> _write(List<ClientProvisionalReport> reports) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(reports.map((item) => item.toJson()).toList()),
    );
  }
}