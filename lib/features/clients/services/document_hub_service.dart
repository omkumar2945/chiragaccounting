import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/services/purchase_service.dart';
import 'package:chirag_accounting/features/services/sales_service.dart';

class DocumentHubReceipt {
  const DocumentHubReceipt({
    required this.reference,
    required this.message,
    required this.channel,
    required this.detectedTypeLabel,
  });

  final String reference;
  final String message;
  final ClientDocumentIntakeChannel channel;
  final String detectedTypeLabel;
}

class DocumentHubService extends ChangeNotifier {
  DocumentHubService({
    required WorkbenchQueueService queueService,
    required ClientPortalAccessService accessService,
    required SalesService salesService,
    required PurchaseService purchaseService,
    required String Function(String clientId) assignedAccountantIdFor,
  }) : _queueService = queueService,
       _accessService = accessService,
       _salesService = salesService,
       _purchaseService = purchaseService,
       _assignedAccountantIdFor = assignedAccountantIdFor;

  final WorkbenchQueueService _queueService;
  final ClientPortalAccessService _accessService;
  final SalesService _salesService;
  final PurchaseService _purchaseService;
  final String Function(String clientId) _assignedAccountantIdFor;

  static const Set<String> _supportedCommands = <String>{
    'pending',
    "today's uploads",
    'todays uploads',
    'last voucher',
    'sales today',
    "show today's sales",
    'purchase today',
    'outstanding',
    'gst summary',
    'how much gst this month?',
    'cash balance',
    'bank balance',
    'profit',
  };

  Future<DocumentHubReceipt> ingestDocument({
    required String clientId,
    required ClientDocumentIntakeChannel channel,
    required String fileName,
    String? filePath,
    Uint8List? fileBytes,
    String? sourceIdentity,
  }) async {
    final hub = _accessService.profileFor(clientId).documentHubAccess;
    _validateChannelEnabled(channel, hub);
    final assignedAccountantId = _resolveAssignedAccountant(clientId);
    final canAutoProcess =
        hub.autoOcr &&
        ((filePath != null && filePath.trim().isNotEmpty) ||
            (fileBytes != null && fileBytes.isNotEmpty));

    final job = await _queueService.addJob(
      fileName: fileName,
      filePath: filePath,
      fileBytes: fileBytes,
      autoProcess: canAutoProcess,
      clientId: clientId,
      assignedAccountantId: assignedAccountantId,
      intakeChannel: channel,
      sourceIdentity: sourceIdentity,
    );

    final detectedType = _detectTypeFromName(fileName);
    final statusLine = canAutoProcess
        ? 'Pending Accountant Review'
        : 'Received. Waiting for media/processing trigger';
    final reference = job.externalReference ?? job.id;

    return DocumentHubReceipt(
      reference: reference,
      channel: channel,
      detectedTypeLabel: detectedType,
      message:
          'Invoice received.\nDocument Type: $detectedType\nStatus: $statusLine\nReference: $reference',
    );
  }

  Future<List<DocumentHubReceipt>> ingestBatch({
    required String clientId,
    required ClientDocumentIntakeChannel channel,
    required List<BatchUploadFile> files,
    String? sourceIdentity,
  }) async {
    final hub = _accessService.profileFor(clientId).documentHubAccess;
    _validateChannelEnabled(channel, hub);
    final assignedAccountantId = _resolveAssignedAccountant(clientId);
    final hasAnyMedia = files.any(
      (file) =>
          (file.filePath != null && file.filePath!.trim().isNotEmpty) ||
          (file.fileBytes != null && file.fileBytes!.isNotEmpty),
    );

    final batchId = await _queueService.addBatchJobs(
      files,
      autoProcess: hub.autoOcr && hasAnyMedia,
      clientId: clientId,
      assignedAccountantId: assignedAccountantId,
      intakeChannel: channel,
      sourceIdentity: sourceIdentity,
    );
    final jobs = _queueService.batchJobs(batchId);

    final receipts = <DocumentHubReceipt>[];
    for (final job in jobs) {
      final detectedType = _detectTypeFromName(job.fileName);
      final reference = job.externalReference ?? job.id;
      receipts.add(
        DocumentHubReceipt(
          reference: reference,
          channel: channel,
          detectedTypeLabel: detectedType,
          message:
              'Received: ${job.fileName}\nType: $detectedType\nReference: $reference',
        ),
      );
    }
    return receipts;
  }

  String _resolveAssignedAccountant(String clientId) {
    final assignedAccountantId = _assignedAccountantIdFor(clientId).trim();
    if (assignedAccountantId.isEmpty) {
      throw const FormatException(
        'No accountant is assigned. Ask your CA firm to assign one first.',
      );
    }
    return assignedAccountantId;
  }

  String handleChatCommand(String rawCommand) {
    final command = _normalizeCommand(rawCommand);
    final now = DateTime.now();

    if (command == 'pending') {
      return 'Pending Documents\n${_queueService.pendingCount} items in queue';
    }

    if (command == "today's uploads" || command == 'todays uploads') {
      final count = _queueService.allJobs.where((job) {
        final t = job.uploadedAt;
        return t.year == now.year && t.month == now.month && t.day == now.day;
      }).length;
      return "Today's Uploads\n$count file(s) received";
    }

    if (command == 'last voucher') {
      if (_queueService.completedJobs.isEmpty) {
        return 'Last Voucher\nNo completed voucher yet.';
      }
      final last = _queueService.completedJobs.first;
      return 'Last Voucher\n${last.fileName}\nStatus: Completed';
    }

    if (command == 'sales today' || command == 'show today\'s sales') {
      final list = _salesService.invoices
          .where((invoice) {
            final d = invoice.invoiceDate;
            return d.year == now.year &&
                d.month == now.month &&
                d.day == now.day;
          })
          .toList(growable: false);
      final total = list.fold<double>(0, (sum, e) => sum + e.grandTotal);
      return "Today's Sales\n${list.length} invoice(s)\n${_rupee(total)}";
    }

    if (command == 'purchase today') {
      final list = _purchaseService.bills
          .where((bill) {
            final d = bill.billDate;
            return d.year == now.year &&
                d.month == now.month &&
                d.day == now.day;
          })
          .toList(growable: false);
      final total = list.fold<double>(0, (sum, e) => sum + e.grandTotal);
      return "Today's Purchase\n${list.length} bill(s)\n${_rupee(total)}";
    }

    if (command == 'outstanding') {
      final receivable = _salesService.invoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.outstandingAmount,
      );
      final payable = _purchaseService.bills.fold<double>(
        0,
        (sum, bill) => sum + bill.outstandingAmount,
      );
      return 'Outstanding\nReceivable: ${_rupee(receivable)}\nPayable: ${_rupee(payable)}';
    }

    if (command == 'gst summary' || command == 'how much gst this month?') {
      final tax = _salesService.invoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.totalGST,
      );
      return 'GST Summary\nEstimated GST from sales: ${_rupee(tax)}';
    }

    if (command == 'cash balance') {
      return 'Cash Balance\nWill be available from ledger posting pipeline.';
    }

    if (command == 'bank balance') {
      return 'Bank Balance\nWill be available from bank integration feed.';
    }

    if (command == 'profit') {
      final sales = _salesService.totalSales;
      final purchase = _purchaseService.bills.fold<double>(
        0,
        (sum, bill) => sum + bill.grandTotal,
      );
      final profit = sales - purchase;
      return 'Profit Snapshot\nSales: ${_rupee(sales)}\nPurchase: ${_rupee(purchase)}\nEstimated Profit: ${_rupee(profit)}';
    }

    return 'Supported commands:\nPending\nToday\'s Uploads\nLast Voucher\nOutstanding\nGST Summary\nCash Balance\nBank Balance\nProfit\nSales Today\nPurchase Today';
  }

  bool isSupportedChatCommand(String rawCommand) {
    final command = _normalizeCommand(rawCommand);
    return _supportedCommands.contains(command);
  }

  void _validateChannelEnabled(
    ClientDocumentIntakeChannel channel,
    ClientDocumentHubAccess hub,
  ) {
    switch (channel) {
      case ClientDocumentIntakeChannel.mobileApp:
        return;
      case ClientDocumentIntakeChannel.whatsapp:
        if (!hub.enableWhatsAppUpload) {
          throw Exception('WhatsApp upload is disabled for this client.');
        }
      case ClientDocumentIntakeChannel.email:
        if (!hub.enableEmailImport) {
          throw Exception('Email import is disabled for this client.');
        }
      case ClientDocumentIntakeChannel.cloudSync:
        if (!hub.enableCloudSync) {
          throw Exception('Cloud sync import is disabled for this client.');
        }
    }
  }

  String _detectTypeFromName(String fileName) {
    final name = fileName.toLowerCase();
    if (name.contains('sales') || name.contains('invoice')) {
      return 'Sales Invoice';
    }
    if (name.contains('purchase') || name.contains('supplier')) {
      return 'Purchase Invoice';
    }
    if (name.contains('expense')) return 'Expense Bill';
    if (name.contains('bank') || name.contains('statement')) {
      return 'Bank Statement';
    }
    if (name.contains('debit')) return 'Debit Note';
    if (name.contains('credit')) return 'Credit Note';
    if (name.contains('receipt')) return 'Receipt';
    if (name.contains('payment')) return 'Payment';
    if (name.contains('quotation')) return 'Quotation';
    if (name.contains('challan')) return 'Delivery Challan';
    if (name.contains('eway') || name.contains('e-way')) return 'E-way Bill';
    return 'Other';
  }

  String _rupee(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  String _normalizeCommand(String raw) {
    var command = raw.trim().toLowerCase();
    if (command.startsWith('/')) {
      command = command.substring(1).trim();
    }
    return command;
  }
}
