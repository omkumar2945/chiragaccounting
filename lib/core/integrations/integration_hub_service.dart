import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/integrations/adapters/bank_integration_adapter.dart';
import 'package:chirag_accounting/core/integrations/adapters/email_integration_adapter.dart';
import 'package:chirag_accounting/core/integrations/adapters/gst_integration_adapter.dart';
import 'package:chirag_accounting/core/integrations/adapters/tally_integration_adapter.dart';
import 'package:chirag_accounting/core/integrations/adapters/whatsapp_integration_adapter.dart';
import 'package:chirag_accounting/core/integrations/integration_adapter.dart';

class IntegrationHubService extends ChangeNotifier {
  IntegrationHubService({List<IntegrationAdapter>? adapters})
      : _adapters = adapters ??
            <IntegrationAdapter>[
              GstIntegrationAdapter(),
              BankIntegrationAdapter(),
              WhatsAppIntegrationAdapter(),
              EmailIntegrationAdapter(),
              TallyIntegrationAdapter(),
            ] {
    _startHealthPolling();
  }

  final List<IntegrationAdapter> _adapters;
  final Map<String, IntegrationHealth> _healthByAdapter =
      <String, IntegrationHealth>{};

  Timer? _healthTimer;

  Map<String, IntegrationHealth> get healthByAdapter =>
      Map<String, IntegrationHealth>.unmodifiable(_healthByAdapter);

  List<IntegrationAdapter> get adapters =>
      List<IntegrationAdapter>.unmodifiable(_adapters);

  Future<Map<String, dynamic>> execute({
    required String adapterId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final adapter = _adapters.where((a) => a.id == adapterId).first;
    return adapter.execute(action: action, payload: payload);
  }

  Future<void> refreshHealth() async {
    for (final adapter in _adapters) {
      final health = await adapter.health();
      _healthByAdapter[adapter.id] = health;
    }
    notifyListeners();
  }

  void _startHealthPolling() {
    refreshHealth();
    _healthTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      refreshHealth();
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }
}
