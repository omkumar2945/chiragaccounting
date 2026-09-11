class NormalizedDto {
  const NormalizedDto({
    required this.id,
    required this.module,
    required this.type,
    required this.status,
    required this.amount,
    required this.partyName,
    required this.createdAt,
    required this.meta,
  });

  final String id;
  final String module;
  final String type;
  final String status;
  final double amount;
  final String partyName;
  final DateTime createdAt;
  final Map<String, dynamic> meta;
}
