import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/clients/Chat/authenticated_support_chat_shell.dart';
import 'package:chirag_accounting/features/clients/Chat/client_document_hub_screen.dart';
import 'package:chirag_accounting/features/compat/screens/client_documents_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/client_uploads_screen_compat.dart';
import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/invoice_intelligence_workspace_screen.dart';
import 'package:chirag_accounting/features/vouchers/presentation/pages/voucher_entry_dashboard_screen.dart';

class ClientVoucherWorkspaceScreen extends StatelessWidget {
  const ClientVoucherWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final profile = user == null
        ? null
        : context.watch<ClientPortalAccessService>().profileFor(user.id);

    if (user == null || profile == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to load client voucher workspace.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(_titleFor(profile.billingMode)),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModeHeader(profile: profile),
            const SizedBox(height: 14),
            Expanded(
              child: switch (profile.billingMode) {
                ClientBillingMode.imageUploadAccountantEntry =>
                  _TypeOneBody(profile: profile),
                ClientBillingMode.fullBillingSoftware =>
                  _TypeTwoBody(profile: profile),
                ClientBillingMode.hybrid => _HybridBody(profile: profile),
              },
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(ClientBillingMode mode) {
    return switch (mode) {
      ClientBillingMode.imageUploadAccountantEntry => 'Simple Client Upload App',
      ClientBillingMode.fullBillingSoftware => 'Billing and Accounting Workspace',
      ClientBillingMode.hybrid => 'Hybrid Upload and Billing Workspace',
    };
  }
}

class _ModeHeader extends StatelessWidget {
  const _ModeHeader({required this.profile});

  final ClientPortalAccessProfile profile;

  @override
  Widget build(BuildContext context) {
    final title = profile.billingMode.displayName;
    final subtitle = switch (profile.billingMode) {
      ClientBillingMode.imageUploadAccountantEntry =>
        'Client only uploads files. Accountant verifies and posts accounting entries.',
      ClientBillingMode.fullBillingSoftware =>
        'Client creates invoices and vouchers directly with AI/manual workflow.',
      ClientBillingMode.hybrid =>
        'Client can upload documents and also create billing entries as needed.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E2F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A3A86),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF486581)),
          ),
        ],
      ),
    );
  }
}

class _TypeOneBody extends StatelessWidget {
  const _TypeOneBody({required this.profile});

  final ClientPortalAccessProfile profile;

  @override
  Widget build(BuildContext context) {
    final clientId = context.read<AuthController>().currentUser?.id ?? '';
    return ListView(
      children: [
        _ActionTile(
          icon: Icons.camera_alt_outlined,
          title: 'Capture Invoice',
          subtitle: 'Take photo and send directly to pending document queue.',
          color: const Color(0xFF1976D2),
          prominent: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientUploadsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.upload_file_outlined,
          title: 'Upload Files',
          subtitle: 'Upload invoices, receipts, bank statements, and bills.',
          color: const Color(0xFF00897B),
          prominent: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientUploadsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.hub_outlined,
          title: 'WhatsApp / Document Hub',
          subtitle: 'Use WhatsApp, email, and cloud sync intake into one queue.',
          color: const Color(0xFF0D47A1),
          prominent: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientDocumentHubScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.folder_copy_outlined,
          title: 'My Uploaded Documents',
          subtitle: 'Open all uploaded files, status, and history.',
          color: const Color(0xFF5E35B1),
          prominent: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientDocumentsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.chat_bubble_outline,
          title: 'Chat With Accountant',
          subtitle: 'Share queries and track replies from accounting team.',
          color: const Color(0xFF6D4C41),
          prominent: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OpenSupportChatRedirect()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.notifications_active_outlined,
          title: 'Notifications',
          subtitle: 'Get updates when voucher is verified, posted, and archived.',
          color: const Color(0xFFEF6C00),
          prominent: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification center will open here.'),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _PendingQueueCard(clientId: clientId),
        const SizedBox(height: 12),
        _WorkflowFooter(profile: profile),
      ],
    );
  }
}

class _HybridBody extends StatelessWidget {
  const _HybridBody({required this.profile});

  final ClientPortalAccessProfile profile;

  @override
  Widget build(BuildContext context) {
    final clientId = context.read<AuthController>().currentUser?.id ?? '';
    return ListView(
      children: [
        _ActionTile(
          icon: Icons.upload_file_outlined,
          title: 'Upload Documents (AI Queue)',
          subtitle: 'Send files to pending queue with AI classification.',
          color: const Color(0xFF1976D2),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientUploadsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.hub_outlined,
          title: 'Open Document Hub',
          subtitle: 'Unified intake via App, WhatsApp, Email, and Cloud folder.',
          color: const Color(0xFF0D47A1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientDocumentHubScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.request_quote_outlined,
          title: 'Create Sales Invoice',
          subtitle: _salesSubtitle(profile.salesEntryMode),
          color: const Color(0xFF1565C0),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InvoiceIntelligenceWorkspaceScreen(
                  voucherType: InvoiceWorkspaceVoucherType.sales,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.shopping_cart_outlined,
          title: 'Create Purchase Voucher',
          subtitle: _purchaseSubtitle(profile.purchaseEntryMode),
          color: const Color(0xFF00897B),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InvoiceIntelligenceWorkspaceScreen(
                  voucherType: InvoiceWorkspaceVoucherType.purchase,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _PendingQueueCard(clientId: clientId),
        const SizedBox(height: 12),
        _WorkflowFooter(profile: profile),
      ],
    );
  }

  String _salesSubtitle(ClientVoucherEntryMode mode) {
    return switch (mode) {
      ClientVoucherEntryMode.manual =>
        'Manual billing enabled for sales invoices.',
      ClientVoucherEntryMode.ocr =>
        'OCR-assisted sales entry enabled from upload.',
      ClientVoucherEntryMode.both =>
        'Manual + OCR both enabled for sales invoices.',
    };
  }

  String _purchaseSubtitle(ClientVoucherEntryMode mode) {
    return switch (mode) {
      ClientVoucherEntryMode.manual => 'Manual purchase entry mode enabled.',
      ClientVoucherEntryMode.ocr =>
        'AI OCR purchase mode enabled for supplier invoices.',
      ClientVoucherEntryMode.both =>
        'Manual + AI OCR both enabled for purchase vouchers.',
    };
  }
}

class _TypeTwoBody extends StatelessWidget {
  const _TypeTwoBody({required this.profile});

  final ClientPortalAccessProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _ActionTile(
          icon: Icons.request_quote_outlined,
          title: 'Create Sales Invoice',
          subtitle: _salesSubtitle(profile.salesEntryMode),
          color: const Color(0xFF1565C0),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InvoiceIntelligenceWorkspaceScreen(
                  voucherType: InvoiceWorkspaceVoucherType.sales,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.shopping_cart_outlined,
          title: 'Create Purchase Voucher',
          subtitle: _purchaseSubtitle(profile.purchaseEntryMode),
          color: const Color(0xFF00897B),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InvoiceIntelligenceWorkspaceScreen(
                  voucherType: InvoiceWorkspaceVoucherType.purchase,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.hub_outlined,
          title: 'Open Document Hub',
          subtitle: 'Collect documents from App, WhatsApp, Email, and Cloud.',
          color: const Color(0xFF0D47A1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientDocumentHubScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.menu_book_outlined,
          title: 'Open Voucher Dashboard',
          subtitle: 'Payment, Receipt, Journal, Contra, Notes and adjustments.',
          color: const Color(0xFF6D4C41),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoucherEntryDashboardScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _WorkflowFooter(profile: profile),
      ],
    );
  }

  String _salesSubtitle(ClientVoucherEntryMode mode) {
    return switch (mode) {
      ClientVoucherEntryMode.manual =>
        'Manual billing enabled for sales invoices.',
      ClientVoucherEntryMode.ocr =>
        'OCR-assisted sales entry enabled from upload.',
      ClientVoucherEntryMode.both =>
        'Manual + OCR both enabled for sales invoices.',
    };
  }

  String _purchaseSubtitle(ClientVoucherEntryMode mode) {
    return switch (mode) {
      ClientVoucherEntryMode.manual => 'Manual purchase entry mode enabled.',
      ClientVoucherEntryMode.ocr =>
        'AI OCR purchase mode enabled for supplier invoices.',
      ClientVoucherEntryMode.both =>
        'Manual + AI OCR both enabled for purchase vouchers.',
    };
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(prominent ? 18 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD9E2F2)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: prominent ? 24 : 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: prominent ? 17 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: prominent ? 13 : 12,
                        color: Color(0xFF486581),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingQueueCard extends StatelessWidget {
  const _PendingQueueCard({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final jobs = context
        .watch<WorkbenchQueueService>()
        .allJobs
        .where((job) => job.clientId == clientId)
        .toList(growable: false);

    final pending = jobs.where((job) => job.status.isActive).toList(growable: false);
    final sales = pending
        .where((job) => job.queueBucket == ClientDocumentQueueBucket.sales)
        .length;
    final purchase = pending
        .where(
          (job) =>
              job.queueBucket == ClientDocumentQueueBucket.purchase ||
              job.queueBucket == ClientDocumentQueueBucket.expense,
        )
        .length;
    final receipt = pending
        .where((job) => job.queueBucket == ClientDocumentQueueBucket.receipt)
        .length;
    final totalPending = pending.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E2F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Documents Queue',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Total Pending: $totalPending'),
          Text('Sales: $sales pending'),
          Text('Purchase/Expense: $purchase pending'),
          Text('Receipt: $receipt pending'),
          const SizedBox(height: 6),
          const Text(
            'AI classifies uploaded files automatically before accountant verification.',
            style: TextStyle(color: Color(0xFF486581)),
          ),
        ],
      ),
    );
  }
}

class _WorkflowFooter extends StatelessWidget {
  const _WorkflowFooter({required this.profile});

  final ClientPortalAccessProfile profile;

  @override
  Widget build(BuildContext context) {
    final accountingModeLabel =
        profile.accountingMode == ClientAccountingMode.accountsOnly
        ? 'Accounts Only'
        : 'Accounts + Inventory';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_suggest_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Current accounting mode: $accountingModeLabel',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
