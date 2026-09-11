import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/core/events/event_types.dart';

import '../sales/models/sales_invoice.dart';

class SalesService extends ChangeNotifier {
  final List<SalesInvoice> _invoices = [];

  List<SalesInvoice> get invoices => List.unmodifiable(_invoices);

  int get totalInvoices => _invoices.length;

  String generateNextInvoiceNumber() {
    final next = _invoices.length + 1;
    return 'INV-${next.toString().padLeft(4, '0')}';
  }

  String generateNextTaxInvoiceNumber() {
    final next =
        _invoices
            .where((invoice) => invoice.invoiceType == SalesInvoiceType.tax)
            .length +
        1;
    return 'TAX-${next.toString().padLeft(4, '0')}';
  }

  SalesInvoice? findByInvoiceNumber(String invoiceNumber) {
    final key = invoiceNumber.trim().toLowerCase();
    if (key.isEmpty) return null;

    try {
      return _invoices.firstWhere(
        (invoice) => invoice.invoiceNumber.trim().toLowerCase() == key,
      );
    } catch (_) {
      return null;
    }
  }

  double get totalSales {
    return _invoices.fold(0.0, (sum, invoice) => sum + invoice.grandTotal);
  }

  void addInvoice(SalesInvoice invoice) {
    _invoices.add(invoice);
    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.salesInvoiceCreated,
        module: 'sales',
        action: 'created',
        entityType: 'sales_invoice',
        entityId: invoice.id,
        clientId: invoice.customerName,
        role: 'client',
        payload: <String, dynamic>{
          'clientName': invoice.customerName,
          'invoiceNumber': invoice.invoiceNumber,
          'grandTotal': invoice.grandTotal,
          'postingStatus': invoice.postingStatus.name,
          'summary': 'Sales invoice ${invoice.invoiceNumber} created',
        },
      ),
    );
    notifyListeners();
  }

  void postInvoice(
    String invoiceId, {
    required bool lockAfterPosting,
    required String actorRole,
  }) {
    final index = _invoices.indexWhere((invoice) => invoice.id == invoiceId);
    if (index < 0) return;

    final invoice = _invoices[index];
    final posted = invoice.copyWith(
      status: InvoiceStatus.pending,
      postingStatus: lockAfterPosting
          ? SalesPostingStatus.locked
          : SalesPostingStatus.posted,
      postedAt: DateTime.now(),
      lockedAfterPosting: lockAfterPosting,
    );
    _invoices[index] = posted;

    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.salesInvoicePosted,
        module: 'sales',
        action: 'posted',
        entityType: 'sales_invoice',
        entityId: posted.id,
        clientId: posted.customerName,
        role: actorRole,
        payload: <String, dynamic>{
          'clientName': posted.customerName,
          'invoiceNumber': posted.invoiceNumber,
          'locked': posted.lockedAfterPosting,
          'summary': 'Sales invoice ${posted.invoiceNumber} posted',
        },
      ),
    );

    if (lockAfterPosting) {
      AppEventBus.instance.publish(
        AppEvent.create(
          eventType: EventTypes.salesInvoiceLocked,
          module: 'sales',
          action: 'locked',
          entityType: 'sales_invoice',
          entityId: posted.id,
          clientId: posted.customerName,
          role: actorRole,
          payload: <String, dynamic>{
            'clientName': posted.customerName,
            'invoiceNumber': posted.invoiceNumber,
            'summary':
                'Sales invoice ${posted.invoiceNumber} locked after posting',
          },
        ),
      );
    }

    notifyListeners();
  }

  void requestInvoiceCorrection(
    String invoiceId, {
    required String reason,
    required String requestedBy,
  }) {
    final index = _invoices.indexWhere((invoice) => invoice.id == invoiceId);
    if (index < 0) return;
    final invoice = _invoices[index];
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return;

    final updated = invoice.copyWith(
      postingStatus: SalesPostingStatus.correctionRequested,
      correctionRequestReason: trimmedReason,
      correctionRequestedBy: requestedBy,
      correctionRequestedAt: DateTime.now(),
    );
    _invoices[index] = updated;

    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.salesInvoiceCorrectionRequested,
        module: 'sales',
        action: 'correction_requested',
        entityType: 'sales_invoice',
        entityId: updated.id,
        clientId: updated.customerName,
        role: requestedBy,
        payload: <String, dynamic>{
          'clientName': updated.customerName,
          'invoiceNumber': updated.invoiceNumber,
          'reason': trimmedReason,
          'summary':
              'Correction requested for sales invoice ${updated.invoiceNumber}',
        },
      ),
    );
    notifyListeners();
  }

  void resolveInvoiceCorrection(String invoiceId, {required String actorRole}) {
    approveInvoiceCorrection(invoiceId, actorRole: actorRole);
  }

  void approveInvoiceCorrection(String invoiceId, {required String actorRole}) {
    final index = _invoices.indexWhere((invoice) => invoice.id == invoiceId);
    if (index < 0) return;
    final invoice = _invoices[index];
    if (invoice.postingStatus != SalesPostingStatus.correctionRequested) {
      return;
    }

    final updated = invoice.copyWith(
      postingStatus: SalesPostingStatus.corrected,
      correctionResolvedAt: DateTime.now(),
      lockedAfterPosting: false,
    );
    _invoices[index] = updated;

    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.salesInvoiceCorrectionApproved,
        module: 'sales',
        action: 'correction_approved',
        entityType: 'sales_invoice',
        entityId: updated.id,
        clientId: updated.customerName,
        role: actorRole,
        payload: <String, dynamic>{
          'clientName': updated.customerName,
          'invoiceNumber': updated.invoiceNumber,
          'summary':
              'Correction approved for sales invoice ${updated.invoiceNumber}',
        },
      ),
    );
    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.salesInvoiceCorrectionResolved,
        module: 'sales',
        action: 'correction_resolved',
        entityType: 'sales_invoice',
        entityId: updated.id,
        clientId: updated.customerName,
        role: actorRole,
        payload: <String, dynamic>{
          'clientName': updated.customerName,
          'invoiceNumber': updated.invoiceNumber,
          'summary':
              'Correction resolved for sales invoice ${updated.invoiceNumber}',
        },
      ),
    );
    notifyListeners();
  }

  void rejectInvoiceCorrection(
    String invoiceId, {
    required String actorRole,
    required String reason,
  }) {
    final index = _invoices.indexWhere((invoice) => invoice.id == invoiceId);
    if (index < 0) return;
    final invoice = _invoices[index];
    if (invoice.postingStatus != SalesPostingStatus.correctionRequested) {
      return;
    }

    final trimmedReason = reason.trim();
    final updated = invoice.copyWith(
      postingStatus: SalesPostingStatus.correctionRejected,
      correctionResolvedAt: DateTime.now(),
      lockedAfterPosting: true,
      correctionRequestReason: trimmedReason.isEmpty
          ? invoice.correctionRequestReason
          : '${invoice.correctionRequestReason}\nRejected: $trimmedReason',
    );
    _invoices[index] = updated;

    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.salesInvoiceCorrectionRejected,
        module: 'sales',
        action: 'correction_rejected',
        entityType: 'sales_invoice',
        entityId: updated.id,
        clientId: updated.customerName,
        role: actorRole,
        payload: <String, dynamic>{
          'clientName': updated.customerName,
          'invoiceNumber': updated.invoiceNumber,
          'reason': trimmedReason,
          'summary':
              'Correction rejected for sales invoice ${updated.invoiceNumber}',
        },
      ),
    );
    notifyListeners();
  }

  void updateInvoice(String invoiceId, SalesInvoice updatedInvoice) {
    final index = _invoices.indexWhere((e) => e.id == invoiceId);

    if (index != -1) {
      _invoices[index] = updatedInvoice;
      AppEventBus.instance.publish(
        AppEvent.create(
          eventType: EventTypes.salesInvoiceUpdated,
          module: 'sales',
          action: 'updated',
          entityType: 'sales_invoice',
          entityId: updatedInvoice.id,
          clientId: updatedInvoice.customerName,
          role: 'accountant',
          payload: <String, dynamic>{
            'clientName': updatedInvoice.customerName,
            'invoiceNumber': updatedInvoice.invoiceNumber,
            'status': updatedInvoice.status.name,
            'summary': 'Sales invoice ${updatedInvoice.invoiceNumber} updated',
          },
        ),
      );
      notifyListeners();
    }
  }

  void deleteInvoice(String invoiceId) {
    final invoice = getInvoiceById(invoiceId);
    _invoices.removeWhere((invoice) => invoice.id == invoiceId);

    if (invoice != null) {
      AppEventBus.instance.publish(
        AppEvent.create(
          eventType: EventTypes.salesInvoiceDeleted,
          module: 'sales',
          action: 'deleted',
          entityType: 'sales_invoice',
          entityId: invoiceId,
          clientId: invoice.customerName,
          role: 'accountant',
          payload: <String, dynamic>{
            'clientName': invoice.customerName,
            'invoiceNumber': invoice.invoiceNumber,
            'summary': 'Sales invoice ${invoice.invoiceNumber} deleted',
          },
        ),
      );
    }

    notifyListeners();
  }

  SalesInvoice? getInvoiceById(String invoiceId) {
    try {
      return _invoices.firstWhere((invoice) => invoice.id == invoiceId);
    } catch (_) {
      return null;
    }
  }

  List<SalesInvoice> searchInvoices(String keyword) {
    final query = keyword.toLowerCase();

    return _invoices.where((invoice) {
      return invoice.invoiceNumber.toLowerCase().contains(query) ||
          invoice.customerName.toLowerCase().contains(query);
    }).toList();
  }

  List<SalesInvoice> filterByStatus(InvoiceStatus status) {
    return _invoices.where((invoice) => invoice.status == status).toList();
  }

  List<SalesInvoice> filterByType(SalesInvoiceType type) {
    return _invoices.where((invoice) => invoice.invoiceType == type).toList();
  }

  List<SalesInvoice> searchInvoicesByType(
    String keyword,
    SalesInvoiceType type,
  ) {
    final query = keyword.toLowerCase();
    return _invoices.where((invoice) {
      if (invoice.invoiceType != type) return false;
      return invoice.invoiceNumber.toLowerCase().contains(query) ||
          invoice.customerName.toLowerCase().contains(query);
    }).toList();
  }

  void continueInvoiceNumbering({
    bool? isTaxInvoice,
    String? currentInvoiceNumber,
    SalesInvoiceType? type,
    String? previousInvoiceNumber,
  }) {
    // Compatibility shim for older screens; numbering remains derived from in-memory invoices.
  }

  void clearInvoices() {
    _invoices.clear();
    notifyListeners();
  }
}
