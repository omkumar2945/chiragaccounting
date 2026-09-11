// AI Workspace Screen – split view document workspace
//
// Layout (wide ≥ 900px):
//   ┌────────────────────────────────────┬────────────────────────┬─────────┐
//   │  LEFT: AI Extracted Accounting     │  RIGHT: Invoice        │ AI Asst │
//   │  Verified fields with checkmarks   │  Preview / OCR text    │  Chat   │
//   │  Click field → highlights right    │  Highlighted section   │         │
//   └────────────────────────────────────┴────────────────────────┴─────────┘
//
// Layout (narrow):
//   Tabs: [Accounting Form] [Preview] [AI Chat]

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/services/ocr_module_api_service.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/add_sales_invoice_screen.dart';
import 'package:chirag_accounting/features/purchase/presentation/pages/add_purchase_bill_screen.dart';
import 'package:chirag_accounting/features/services/invoice_ocr_service.dart';
import 'package:chirag_accounting/features/services/smart_invoice_engine.dart';
import 'package:chirag_accounting/features/vouchers/presentation/models/voucher_entry_type.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_form_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class AiWorkspaceScreen extends StatefulWidget {
  final String jobId;

  /// When opened from review queue, pass the full ordered list of job IDs
  /// and the current index so "Next →" can jump to the next exception.
  final List<String> reviewQueue;
  final int reviewIndex;

  const AiWorkspaceScreen({
    super.key,
    required this.jobId,
    this.reviewQueue = const [],
    this.reviewIndex = 0,
  });

  @override
  State<AiWorkspaceScreen> createState() => _AiWorkspaceScreenState();
}

class _AiWorkspaceScreenState extends State<AiWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String? _selectedField; // drives highlighting in preview
  bool _assistantOpen = true;
  final _assistantCtrl = TextEditingController();
  final List<_ChatMessage> _chatMessages = [];
  final _chatScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    // Welcome message from AI assistant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<WorkbenchQueueService>();
      final job = _findJob(svc);
      if (job?.result != null) {
        _addAssistantMsg(
          'I have analysed this document. It appears to be a '
          '${job!.documentTypeLabel} with ${(job.result!.confidence.overall * 100).round()}% confidence. '
          'You can ask me anything about this document.',
        );
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _assistantCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  WorkbenchJob? _findJob(WorkbenchQueueService svc) {
    try {
      return svc.allJobs.firstWhere((j) => j.id == widget.jobId);
    } catch (_) {
      return null;
    }
  }

  void _addAssistantMsg(String text) {
    setState(() {
      _chatMessages.add(_ChatMessage(text: text, isUser: false));
    });
    _scrollChat();
  }

  void _addUserMsg(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _chatMessages.add(_ChatMessage(text: text, isUser: true));
    });
    _assistantCtrl.clear();
    _scrollChat();
    _respondToUser(text.trim());
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _respondToUser(String question) {
    final svc = context.read<WorkbenchQueueService>();
    final job = _findJob(svc);
    final r = job?.result;
    final q = question.toLowerCase();

    String response;
    if (r == null) {
      response = 'The document is still being analysed. Please wait.';
    } else if (q.contains('invoice') || q.contains('what is')) {
      response =
          'This is a ${job!.documentTypeLabel}. Invoice number: '
          '${r.parsedData.billNumber.isNotEmpty ? r.parsedData.billNumber : "not found"}. '
          'Date: ${r.parsedData.billDate.isNotEmpty ? r.parsedData.billDate : "not found"}. '
          'Amount: ${r.parsedData.totalAmount > 0 ? "₹${r.parsedData.totalAmount.toStringAsFixed(2)}" : "not found"}.';
    } else if (q.contains('gst')) {
      response = r.gstResult.warnings.isEmpty
          ? 'GST appears valid. Seller GSTIN: ${r.gstResult.detectedSellerGstin.isNotEmpty ? r.gstResult.detectedSellerGstin : "not detected"}.'
          : 'GST warnings: ${r.gstResult.warnings.join("; ")}';
    } else if (q.contains('customer') ||
        q.contains('supplier') ||
        q.contains('party')) {
      response = r.partyMatch == null
          ? 'No matching party found in masters.'
          : r.partyMatch!.isNewMaster
          ? 'New party detected: "${r.partyMatch!.matchedName}". You can create it as a master.'
          : 'Party matched: "${r.partyMatch!.matchedName}" (${(r.partyMatch!.confidence * 100).round()}% confidence).';
    } else if (q.contains('product')) {
      if (r.productMatches.isEmpty) {
        response = 'No products detected in this document.';
      } else {
        final names = r.productMatches
            .take(3)
            .map((p) => p.matchedName)
            .join(', ');
        response =
            '${r.productMatches.length} product(s) found: $names${r.productMatches.length > 3 ? "..." : ""}';
      }
    } else if (q.contains('duplicate')) {
      response = r.duplicateResult.isDuplicate
          ? 'WARNING: This appears to be a duplicate! Already uploaded${r.duplicateResult.matchedDate != null ? " on ${r.duplicateResult.matchedDate}" : ""}.'
          : 'No duplicate detected. This is a new document.';
    } else if (q.contains('ledger')) {
      response = r.ledgerSuggestion == null
          ? 'No ledger could be suggested for this document type.'
          : 'Suggested ledger: "${r.ledgerSuggestion!.ledgerName}" (${r.ledgerSuggestion!.group}). Reason: ${r.ledgerSuggestion!.reason}.';
    } else if (q.contains('tax') ||
        q.contains('cgst') ||
        q.contains('sgst') ||
        q.contains('igst')) {
      response =
          'CGST: ₹${r.taxResult.extractedCgst.toStringAsFixed(2)}, '
          'SGST: ₹${r.taxResult.extractedSgst.toStringAsFixed(2)}, '
          'IGST: ₹${r.taxResult.extractedIgst.toStringAsFixed(2)}. '
          'Tax calculation ${r.taxResult.taxCalcMatch ? "matches" : "does not match"} extracted total.';
    } else if (q.contains('confiden')) {
      response =
          'Overall confidence: ${(r.confidence.overall * 100).round()}%. '
          'Invoice: ${(r.confidence.invoice * 100).round()}%, '
          'Customer: ${(r.confidence.customer * 100).round()}%, '
          'Products: ${(r.confidence.products * 100).round()}%, '
          'GST: ${(r.confidence.gst * 100).round()}%.';
    } else if (q.contains('highlight') || q.contains('why')) {
      response =
          'Classification reason: ${r.detectionReason}. '
          'Signals: ${r.classificationReasons.take(3).join(", ")}.';
    } else if (q.contains('approve') || q.contains('save')) {
      response = r.confidence.overall >= 0.85
          ? 'Confidence is high (${(r.confidence.overall * 100).round()}%). You can approve and save this document.'
          : 'Confidence is ${(r.confidence.overall * 100).round()}%. I recommend reviewing highlighted fields before saving.';
    } else {
      response =
          'I can answer questions about: invoice details, GST, customer/supplier, products, duplicate check, ledger, tax, confidence. Try asking one of those.';
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _addAssistantMsg(response);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<WorkbenchQueueService>();
    final job = _findJob(svc);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Workspace')),
        body: const Center(child: Text('Document not found.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: _buildAppBar(job, svc),
      body: wide ? _buildWideLayout(job, svc) : _buildNarrowLayout(job, svc),
      // "Next →" bar when in review queue mode
      bottomNavigationBar: widget.reviewQueue.length > 1
          ? _buildReviewNavBar(svc)
          : null,
    );
  }

  AppBar _buildAppBar(WorkbenchJob job, WorkbenchQueueService svc) {
    return AppBar(
      backgroundColor: const Color(0xFF1A237E),
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.shortName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Text(
            '${job.documentTypeLabel} · ${job.status.label} · ${job.intakeChannelLabel}${job.externalReference == null ? '' : ' · ${job.externalReference}'}',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        if (job.result != null) ...[
          _confidenceChip(job.result!.confidence.overall),
          const SizedBox(width: 4),
        ],
        IconButton(
          icon: Icon(
            _assistantOpen ? Icons.chat_bubble : Icons.chat_bubble_outline,
            size: 20,
          ),
          tooltip: 'AI Assistant',
          onPressed: () => setState(() => _assistantOpen = !_assistantOpen),
        ),
        _appBarActionMenu(job, svc),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _confidenceChip(double c) {
    final color = c >= 0.95
        ? Colors.green
        : c >= 0.75
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${(c * 100).round()}%',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Widget _appBarActionMenu(WorkbenchJob job, WorkbenchQueueService svc) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (v) async {
        switch (v) {
          case 'approve':
            svc.approveJob(job.id);
            Navigator.pop(context);
            break;
          case 'reject':
            svc.rejectJob(job.id);
            break;
          case 'complete':
            if (await _completeAccountantJob(job, svc) && mounted) {
              Navigator.pop(context);
            }
            break;
          case 'archive':
            svc.archiveJob(job.id);
            Navigator.pop(context);
            break;
          case 'open_entry':
            _openEntryScreen(job);
            break;
        }
      },
      itemBuilder: (_) => [
        if (job.status == WorkbenchJobStatus.verification)
          const PopupMenuItem(
            value: 'approve',
            child: ListTile(
              leading: Icon(Icons.check, color: Colors.green),
              title: Text('Approve'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        if (job.status == WorkbenchJobStatus.approved)
          const PopupMenuItem(
            value: 'complete',
            child: ListTile(
              leading: Icon(Icons.done_all, color: Colors.teal),
              title: Text('Mark Complete'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        if (job.result != null)
          const PopupMenuItem(
            value: 'open_entry',
            child: ListTile(
              leading: Icon(Icons.open_in_new, color: Colors.indigo),
              title: Text('Open Entry Screen'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        const PopupMenuItem(
          value: 'archive',
          child: ListTile(
            leading: Icon(Icons.archive_outlined, color: Colors.blueGrey),
            title: Text('Archive'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }

  // ── Review Queue Navigation Bar ──────────────────────────────────────────

  Widget _buildReviewNavBar(WorkbenchQueueService svc) {
    final queue = widget.reviewQueue;
    final idx = widget.reviewIndex;
    final hasNext = idx < queue.length - 1;
    final hasPrev = idx > 0;
    final remaining = queue.length - idx - 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        child: Row(
          children: [
            if (hasPrev)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A237E),
                  side: const BorderSide(color: Color(0xFF1A237E)),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiWorkspaceScreen(
                        jobId: queue[idx - 1],
                        reviewQueue: queue,
                        reviewIndex: idx - 1,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('Prev', style: TextStyle(fontSize: 13)),
              ),
            const Spacer(),
            Text(
              '${idx + 1} / ${queue.length}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (hasNext)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                ),
                onPressed: () {
                  // Approve current job before going to next
                  svc.approveJob(widget.jobId);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiWorkspaceScreen(
                        jobId: queue[idx + 1],
                        reviewQueue: queue,
                        reviewIndex: idx + 1,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chevron_right, size: 16),
                label: Text(
                  'Next  ($remaining left)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  svc.approveJob(widget.jobId);
                  Navigator.pop(context); // back to review queue
                },
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text(
                  'Done',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Wide layout ───────────────────────────────────────────────────────────

  Widget _buildWideLayout(WorkbenchJob job, WorkbenchQueueService svc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Accounting form
        Expanded(flex: 5, child: _buildAccountingPanel(job, svc)),
        const VerticalDivider(width: 1),
        // Right: Invoice preview
        Expanded(flex: 4, child: _buildPreviewPanel(job)),
        // AI Assistant (collapsible)
        if (_assistantOpen) ...[
          const VerticalDivider(width: 1),
          SizedBox(width: 280, child: _buildAssistantPanel()),
        ],
      ],
    );
  }

  // ── Narrow layout ─────────────────────────────────────────────────────────

  Widget _buildNarrowLayout(WorkbenchJob job, WorkbenchQueueService svc) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF1A237E),
          indicatorColor: const Color(0xFF1A237E),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'AI Form'),
            Tab(text: 'Preview'),
            Tab(text: 'Ask AI'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildAccountingPanel(job, svc),
              _buildPreviewPanel(job),
              _buildAssistantPanel(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Accounting Panel (LEFT) ───────────────────────────────────────────────

  Widget _buildAccountingPanel(WorkbenchJob job, WorkbenchQueueService svc) {
    final r = job.result;
    if (r == null) {
      return _buildProcessingPlaceholder(job);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document type badge
          _sectionHeader('AI Extracted Accounting', Icons.auto_awesome),
          const SizedBox(height: 4),
          _detectionBanner(r),
          const SizedBox(height: 16),

          // Core fields
          _sectionHeader('Invoice Details', Icons.receipt_outlined),
          const SizedBox(height: 8),
          _verifiedField(
            label: 'Invoice No.',
            value: r.parsedData.billNumber,
            verified: r.parsedData.billNumber.isNotEmpty,
            field: 'invoiceNo',
          ),
          _verifiedField(
            label: 'Date',
            value: r.parsedData.billDate,
            verified: r.parsedData.billDate.isNotEmpty,
            field: 'date',
          ),
          _verifiedField(
            label: 'Total Amount',
            value: r.parsedData.totalAmount > 0
                ? '₹ ${r.parsedData.totalAmount.toStringAsFixed(2)}'
                : '',
            verified: r.parsedData.totalAmount > 0,
            field: 'totalAmount',
          ),

          const SizedBox(height: 16),
          _sectionHeader('Party', Icons.person_outlined),
          const SizedBox(height: 8),
          _verifiedField(
            label: 'Party Name',
            value: r.partyMatch?.matchedName ?? r.parsedData.partyName,
            verified: r.partyMatch != null && !r.partyMatch!.isNewMaster,
            warn: r.partyMatch?.isNewMaster == true,
            field: 'partyName',
          ),
          _verifiedField(
            label: 'GSTIN',
            value: r.parsedData.gstin,
            verified: r.gstResult.formatValid && r.parsedData.gstin.isNotEmpty,
            field: 'gstin',
          ),

          const SizedBox(height: 16),
          _sectionHeader('Tax', Icons.percent_outlined),
          const SizedBox(height: 8),
          _verifiedField(
            label: 'CGST',
            value: r.taxResult.extractedCgst > 0
                ? '₹ ${r.taxResult.extractedCgst.toStringAsFixed(2)}'
                : '—',
            verified: r.taxResult.extractedCgst > 0,
            field: 'cgst',
          ),
          _verifiedField(
            label: 'SGST',
            value: r.taxResult.extractedSgst > 0
                ? '₹ ${r.taxResult.extractedSgst.toStringAsFixed(2)}'
                : '—',
            verified: r.taxResult.extractedSgst > 0,
            field: 'sgst',
          ),
          _verifiedField(
            label: 'IGST',
            value: r.taxResult.extractedIgst > 0
                ? '₹ ${r.taxResult.extractedIgst.toStringAsFixed(2)}'
                : '—',
            verified: r.taxResult.extractedIgst > 0,
            field: 'igst',
          ),
          _verifiedField(
            label: 'Tax Calc',
            value: r.taxResult.taxCalcMatch ? 'Verified' : 'Mismatch',
            verified: r.taxResult.taxCalcMatch,
            field: 'taxCalc',
          ),

          if (r.parsedData.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader('Products', Icons.inventory_2_outlined),
            const SizedBox(height: 8),
            ...r.productMatches.take(8).map((pm) => _productRow(pm)),
          ],

          if (r.ledgerSuggestion != null) ...[
            const SizedBox(height: 16),
            _sectionHeader('Ledger', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 8),
            _verifiedField(
              label: 'Suggested',
              value: r.ledgerSuggestion!.ledgerName,
              verified: true,
              info: r.ledgerSuggestion!.reason,
              field: 'ledger',
            ),
          ],

          if (r.missingMasters.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMissingMastersPanel(r.missingMasters),
          ],

          // Confidence
          const SizedBox(height: 16),
          _buildConfidencePanel(r.confidence),

          // Action buttons
          const SizedBox(height: 20),
          _buildActionRow(job, svc),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProcessingPlaceholder(WorkbenchJob job) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              job.status == WorkbenchJobStatus.error
                  ? 'Error: ${job.errorMessage ?? "Unknown error"}'
                  : 'AI is analysing your document...\n${job.currentStage.label}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1A237E)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF1A237E),
          ),
        ),
      ],
    );
  }

  Widget _detectionBanner(SmartInvoiceResult r) {
    final c = r.confidence.overall;
    final color = c >= 0.95
        ? Colors.green
        : c >= 0.75
        ? Colors.orange
        : Colors.red;
    final level = c >= 0.95
        ? 'Enterprise Verified'
        : c >= 0.85
        ? 'Needs Review'
        : 'Manual Required';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected: ${_kindLabel(r.detectedKind)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                Text(
                  r.detectionReason,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(c * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: color,
                ),
              ),
              Text(level, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verifiedField({
    required String label,
    required String value,
    required bool verified,
    bool warn = false,
    String? info,
    required String field,
  }) {
    final isSelected = _selectedField == field;
    return GestureDetector(
      onTap: () => setState(
        () => _selectedField = _selectedField == field ? null : field,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A237E).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A237E) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isNotEmpty ? value : '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value.isEmpty ? Colors.black26 : Colors.black87,
                ),
              ),
            ),
            if (info != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: info,
                child: const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.blueGrey,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              verified
                  ? Icons.verified_outlined
                  : warn
                  ? Icons.warning_amber_rounded
                  : Icons.radio_button_unchecked,
              size: 16,
              color: verified
                  ? Colors.green
                  : warn
                  ? Colors.orange
                  : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _productRow(SmartProductMatch pm) {
    final verified = !pm.isNewMaster && pm.confidence > 0.7;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pm.matchedName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pm.ocrText != pm.matchedName)
                  Text(
                    'OCR: ${pm.ocrText}',
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  ),
              ],
            ),
          ),
          Text(
            '${(pm.confidence * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: pm.confidence > 0.7 ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            verified ? Icons.check_circle : Icons.add_circle_outline,
            size: 16,
            color: verified ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildMissingMastersPanel(List<SmartMissingMaster> masters) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.amber, size: 16),
              SizedBox(width: 6),
              Text(
                'AI Found New Masters',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...masters.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      m.type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.suggestedName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A237E),
                      side: const BorderSide(color: Color(0xFF1A237E)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 12),
                    label: const Text('Create', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidencePanel(SmartConfidenceBreakdown c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Confidence',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _confBar('Invoice', c.invoice),
          _confBar('Customer', c.customer),
          _confBar('Products', c.products),
          _confBar('GST', c.gst),
          _confBar('Total', c.total),
          const SizedBox(height: 4),
          const Divider(),
          _confBar('Overall', c.overall, bold: true),
        ],
      ),
    );
  }

  Widget _confBar(String label, double v, {bool bold = false}) {
    final color = v >= 0.95
        ? Colors.green
        : v >= 0.75
        ? Colors.orange
        : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                color: bold ? Colors.black87 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: v,
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 7,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(v * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(WorkbenchJob job, WorkbenchQueueService svc) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (job.result != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
            ),
            onPressed: () => _openEntryScreen(job),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Entry Screen'),
          ),
        if (job.status == WorkbenchJobStatus.verification)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              svc.approveJob(job.id);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Approve'),
          ),
        if (job.status == WorkbenchJobStatus.approved)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              if (await _completeAccountantJob(job, svc) && mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Save & Complete'),
          ),
      ],
    );
  }

  Future<bool> _completeAccountantJob(
    WorkbenchJob job,
    WorkbenchQueueService svc,
  ) async {
    try {
      final remoteDocumentId = job.remoteDocumentId;
      if (remoteDocumentId != null && remoteDocumentId.isNotEmpty) {
        final clientId = job.clientId?.trim() ?? '';
        final accountantId = job.assignedAccountantId?.trim() ?? '';
        if (clientId.isEmpty || accountantId.isEmpty) {
          throw const FormatException(
            'Document assignment is incomplete. Refresh the OCR queue.',
          );
        }
        await OcrModuleApiService().complete(
          documentId: remoteDocumentId,
          clientId: clientId,
          assignedAccountantId: accountantId,
        );
      }
      svc.completeJob(job.id);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete document: $error')),
        );
      }
      return false;
    }
  }

  // ── Preview Panel (RIGHT) ─────────────────────────────────────────────────

  Widget _buildPreviewPanel(WorkbenchJob job) {
    final r = job.result;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Original Invoice', Icons.description_outlined),
          const SizedBox(height: 12),
          if (r == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Show OCR text with selected field highlighted
            _buildOcrTextPreview(r.parsedData.rawText, r),
          ],
        ],
      ),
    );
  }

  Widget _buildOcrTextPreview(String rawText, SmartInvoiceResult r) {
    if (rawText.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'No OCR text available for preview.',
          style: TextStyle(color: Colors.black38, fontSize: 13),
        ),
      );
    }

    // Determine which substring to highlight based on selected field.
    String? highlight;
    if (_selectedField != null) {
      switch (_selectedField) {
        case 'invoiceNo':
          highlight = r.parsedData.billNumber;
          break;
        case 'date':
          highlight = r.parsedData.billDate;
          break;
        case 'partyName':
          highlight = r.parsedData.partyName;
          break;
        case 'gstin':
          highlight = r.parsedData.gstin;
          break;
        case 'totalAmount':
          highlight = r.parsedData.totalAmount > 0
              ? r.parsedData.totalAmount.toStringAsFixed(2)
              : null;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _HighlightedText(text: rawText, highlight: highlight),
    );
  }

  // ── AI Assistant Panel (RIGHT SIDEBAR) ───────────────────────────────────

  Widget _buildAssistantPanel() {
    return Container(
      color: const Color(0xFFF8F9FF),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1A237E),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Ask AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_chatMessages.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ask me anything about this document.\n\nTry:\n• What is this invoice?\n• Is there a duplicate?\n• What ledger to use?\n• Explain GST.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black38),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _chatScrollCtrl,
                padding: const EdgeInsets.all(10),
                itemCount: _chatMessages.length,
                itemBuilder: (_, i) {
                  final msg = _chatMessages[i];
                  return Align(
                    alignment: msg.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(maxWidth: 230),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? const Color(0xFF1A237E)
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(10),
                          topRight: const Radius.circular(10),
                          bottomLeft: msg.isUser
                              ? const Radius.circular(10)
                              : Radius.zero,
                          bottomRight: msg.isUser
                              ? Radius.zero
                              : const Radius.circular(10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 12,
                          color: msg.isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Quick question chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children:
                  [
                        'What is this?',
                        'Explain GST',
                        'Duplicate?',
                        'Suggest Ledger',
                        'Products',
                        'Confidence',
                      ]
                      .map(
                        (q) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _addUserMsg(q),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EAF6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                q,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _assistantCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask AI about this document...',
                      hintStyle: TextStyle(fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: null,
                    onSubmitted: _addUserMsg,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Color(0xFF1A237E),
                    size: 18,
                  ),
                  onPressed: () => _addUserMsg(_assistantCtrl.text),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation to entry screens ───────────────────────────────────────────

  void _openEntryScreen(WorkbenchJob job) {
    final r = job.result;
    if (r == null) return;
    final isPdf = job.fileName.toLowerCase().endsWith('.pdf');
    final analysis = OcrDocumentAnalysis(
      kind: r.detectedKind,
      confidence: r.confidence.overall,
      signals: r.classificationReasons,
    );

    switch (r.detectedKind) {
      case OcrDocumentKind.salesInvoice:
      case OcrDocumentKind.creditNote:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddSalesInvoiceScreen(
              prefillParsedData: r.parsedData,
              prefillAnalysis: analysis,
              prefillPreviewBytes: job.fileBytes,
              prefillPreviewFilePath: job.filePath,
              prefillPreviewFileName: job.fileName,
              prefillPreviewIsPdf: isPdf,
              autoEntryMode: true,
            ),
          ),
        );
        break;
      case OcrDocumentKind.purchaseBill:
      case OcrDocumentKind.debitNote:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddPurchaseBillScreen(
              prefillParsedData: r.parsedData,
              prefillAnalysis: analysis,
              autoEntryMode: true,
            ),
          ),
        );
        break;
      case OcrDocumentKind.paymentVoucher:
      case OcrDocumentKind.chequeGiven:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoucherEntryFormScreen(
              type: VoucherEntryType.payment,
              prefillParsedData: r.parsedData,
              sourceFileName: job.fileName,
              autoEntryMode: true,
            ),
          ),
        );
        break;
      case OcrDocumentKind.receiptVoucher:
      case OcrDocumentKind.chequeReceived:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoucherEntryFormScreen(
              type: VoucherEntryType.receipt,
              prefillParsedData: r.parsedData,
              sourceFileName: job.fileName,
              autoEntryMode: true,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please open the appropriate module manually for this document type.',
            ),
          ),
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _kindLabel(OcrDocumentKind kind) {
    switch (kind) {
      case OcrDocumentKind.salesInvoice:
        return 'Sales Invoice';
      case OcrDocumentKind.purchaseBill:
        return 'Purchase Bill';
      case OcrDocumentKind.creditNote:
        return 'Credit Note';
      case OcrDocumentKind.debitNote:
        return 'Debit Note';
      case OcrDocumentKind.chequeGiven:
        return 'Cheque Given';
      case OcrDocumentKind.chequeReceived:
        return 'Cheque Received';
      case OcrDocumentKind.paymentVoucher:
        return 'Payment Voucher';
      case OcrDocumentKind.receiptVoucher:
        return 'Receipt Voucher';
      case OcrDocumentKind.unknown:
        return 'Unknown';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HighlightedText – renders OCR text with a highlighted substring
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String? highlight;

  const _HighlightedText({required this.text, this.highlight});

  @override
  Widget build(BuildContext context) {
    if (highlight == null || highlight!.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          height: 1.6,
        ),
      );
    }

    final idx = text.toLowerCase().indexOf(highlight!.toLowerCase());
    if (idx < 0) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          height: 1.6,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
          height: 1.6,
        ),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + highlight!.length),
            style: const TextStyle(
              backgroundColor: Color(0xFFFFE082),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(idx + highlight!.length)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
