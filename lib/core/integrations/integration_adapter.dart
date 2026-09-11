abstract class IntegrationAdapter {
  String get id;
  String get name;

  Future<IntegrationHealth> health();
  Future<Map<String, dynamic>> execute({
    required String action,
    required Map<String, dynamic> payload,
  });
}

class IntegrationHealth {
  const IntegrationHealth({
    required this.status,
    required this.message,
    this.latencyMs,
  });

  final String status;
  final String message;
  final int? latencyMs;
}
