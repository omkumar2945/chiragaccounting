enum ActivityType { sale, purchase, payment, receipt, gst, bank }

class ActivityModel {
  final String id;
  final String title;
  final String subtitle;
  final ActivityType type;
  final double amount;
  final DateTime timestamp;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.amount,
    required this.timestamp,
  });
}
