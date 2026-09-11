import 'package:flutter/foundation.dart';

class LedgerService extends ChangeNotifier {
  Future<void> ensureCustomerLedger({
    required String customerName,
    required String ledgerGroup,
  }) async {
    // Compatibility stub: ledger creation can be wired to accounting module later.
  }
}
