class KpiModel {
  final String title;
  final String value;
  final String? subtitle;
  final KpiTrend? trend;
  final double? trendPercent;
  final KpiType type;

  const KpiModel({
    required this.title,
    required this.value,
    this.subtitle,
    this.trend,
    this.trendPercent,
    required this.type,
  });
}

enum KpiTrend { up, down, neutral }

enum KpiType {
  sales,
  purchase,
  cash,
  bank,
  gstPayable,
  gstReceivable,
  debtors,
  creditors,
  profit,
  clients,
  tasks,
}
