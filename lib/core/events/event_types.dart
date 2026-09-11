class EventTypes {
  EventTypes._();

  static const String salesInvoiceCreated = 'sales.invoice.created';
  static const String salesInvoiceUpdated = 'sales.invoice.updated';
  static const String salesInvoiceDeleted = 'sales.invoice.deleted';
  static const String salesInvoicePosted = 'sales.invoice.posted';
  static const String salesInvoiceLocked = 'sales.invoice.locked';
  static const String salesInvoiceCorrectionRequested =
      'sales.invoice.correction.requested';
  static const String salesInvoiceCorrectionApproved =
      'sales.invoice.correction.approved';
  static const String salesInvoiceCorrectionRejected =
      'sales.invoice.correction.rejected';
  static const String salesInvoiceCorrectionResolved =
      'sales.invoice.correction.resolved';

  static const String purchaseBillCreated = 'purchase.bill.created';
  static const String purchaseBillDeleted = 'purchase.bill.deleted';

  static const String customerCreated = 'customer.created';
  static const String customerUpdated = 'customer.updated';
  static const String customerDeleted = 'customer.deleted';

  static const String taskCreated = 'task.created';
  static const String taskUpdated = 'task.updated';
  static const String clientFinancialPlanUpdated =
      'client.financial_plan.updated';

  static const String workflowStageChanged = 'workflow.stage.changed';
  static const String notificationCreated = 'notification.created';
  static const String adminUserLifecycleChanged =
      'admin.user.lifecycle.changed';
}
