import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/core/events/event_types.dart';

import '../purchase/models/purchase_bill.dart';

class PurchaseService extends ChangeNotifier {
  final List<PurchaseBill> _bills = [];

  List<PurchaseBill> get bills => List.unmodifiable(_bills);
  int get totalBills => _bills.length;

  String nextBillNumber() {
    final next = _bills.length + 1;
    return 'PB-${next.toString().padLeft(4, '0')}';
  }

  PurchaseBill? findByBillNumber(String billNumber) {
    final key = billNumber.trim().toLowerCase();
    if (key.isEmpty) return null;

    try {
      return _bills.firstWhere(
        (bill) => bill.billNumber.trim().toLowerCase() == key,
      );
    } catch (_) {
      return null;
    }
  }

  List<PurchaseBill> searchBills(String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) {
      return List.unmodifiable(_bills);
    }

    return _bills
        .where((bill) {
          return bill.billNumber.toLowerCase().contains(query) ||
              bill.vendorName.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  List<PurchaseBill> filterByMode(PurchaseEntryMode mode) {
    return _bills.where((bill) => bill.mode == mode).toList(growable: false);
  }

  void addBill(PurchaseBill bill) {
    _bills.add(bill);
    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.purchaseBillCreated,
        module: 'purchase',
        action: 'created',
        entityType: 'purchase_bill',
        entityId: bill.id,
        clientId: bill.vendorName,
        role: 'client',
        payload: <String, dynamic>{
          'vendorName': bill.vendorName,
          'billNumber': bill.billNumber,
          'grandTotal': bill.grandTotal,
          'summary': 'Purchase bill ${bill.billNumber} created',
        },
      ),
    );
    notifyListeners();
  }

  void deleteBill(String billId) {
    PurchaseBill? existing;
    for (final bill in _bills) {
      if (bill.id == billId) {
        existing = bill;
        break;
      }
    }
    _bills.removeWhere((bill) => bill.id == billId);
    if (existing != null) {
      AppEventBus.instance.publish(
        AppEvent.create(
          eventType: EventTypes.purchaseBillDeleted,
          module: 'purchase',
          action: 'deleted',
          entityType: 'purchase_bill',
          entityId: billId,
          clientId: existing.vendorName,
          role: 'accountant',
          payload: <String, dynamic>{
            'vendorName': existing.vendorName,
            'billNumber': existing.billNumber,
            'summary': 'Purchase bill ${existing.billNumber} deleted',
          },
        ),
      );
    }
    notifyListeners();
  }
}
