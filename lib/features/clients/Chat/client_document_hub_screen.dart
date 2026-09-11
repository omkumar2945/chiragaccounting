import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/clients/services/document_hub_service.dart';

class ClientDocumentHubScreen extends StatefulWidget {
  const ClientDocumentHubScreen({super.key});

  @override
  State<ClientDocumentHubScreen> createState() => _ClientDocumentHubScreenState();
}

class _ClientDocumentHubScreenState extends State<ClientDocumentHubScreen> {
  final TextEditingController _commandCtrl = TextEditingController();
  String _lastBotResponse =
      'Try commands: Pending, Today\'s Uploads, Outstanding, Sales Today';

  @override
  void dispose() {
    _commandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login again to open Document Hub.')),
      );
    }

    final profile = context.watch<ClientPortalAccessService>().profileFor(user.id);
    final hub = profile.documentHubAccess;
    final clientCode = user.id.length >= 6
        ? user.id.substring(user.id.length - 6).toUpperCase()
        : user.id.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Hub'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hero(hub, clientCode),
          const SizedBox(height: 14),
          _methodTile(
            title: 'Mobile App Upload',
            subtitle: 'Capture photo, upload PDF/image directly from app.',
            icon: Icons.phone_android_outlined,
            enabled: true,
          ),
          const SizedBox(height: 8),
          _methodTile(
            title: 'WhatsApp Upload',
            subtitle: 'Send invoice images/PDFs to mapped WhatsApp number.',
            icon: Icons.chat_outlined,
            enabled: hub.enableWhatsAppUpload,
          ),
          const SizedBox(height: 8),
          _methodTile(
            title: 'Email Inbox Import',
            subtitle: 'Pull invoice attachments from registered email inbox.',
            icon: Icons.email_outlined,
            enabled: hub.enableEmailImport,
          ),
          const SizedBox(height: 8),
          _methodTile(
            title: 'Cloud Folder Sync',
            subtitle: 'Monitor cloud folders and import new files automatically.',
            icon: Icons.cloud_sync_outlined,
            enabled: hub.enableCloudSync,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _flagChip('Auto OCR', hub.autoOcr),
              _flagChip('Auto Classification', hub.autoClassification),
              _flagChip('Voice Notes', hub.allowVoiceNotes),
              _flagChip('Auto Reply', hub.autoReply),
              _flagChip('WA Commands', hub.enableWhatsAppCommands),
              _flagChip('AI Chat', hub.enableAiChat),
              _flagChip('Status Notifications', hub.documentStatusNotifications),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'WhatsApp Command Console',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commandCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Type command (e.g., Outstanding)',
            ),
            onSubmitted: (_) => _runCommand(),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _runCommand,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Run Command'),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD9E5FF)),
            ),
            child: Text(_lastBotResponse),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _simulateWhatsAppReceipt(user.id),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Simulate WhatsApp Document Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _hero(ClientDocumentHubAccess hub, String clientCode) {
    final status = hub.enableWhatsAppUpload ? 'Enabled' : 'Disabled';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1948C7), Color(0xFF2B62F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WhatsApp Primary Intake',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Send invoices, bank statements, and bills directly over WhatsApp.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            'Business Number: +91-98XXXXXX01\nClient Code: CA$clientCode\nStatus: $status',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _methodTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE4F2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A4FD9)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF54687F))),
              ],
            ),
          ),
          Chip(
            label: Text(enabled ? 'ON' : 'OFF'),
            backgroundColor: enabled ? const Color(0xFFDFF7E8) : const Color(0xFFF5E3E3),
          ),
        ],
      ),
    );
  }

  Widget _flagChip(String label, bool enabled) {
    return Chip(
      label: Text(label),
      backgroundColor: enabled ? const Color(0xFFDFF2FF) : const Color(0xFFEDEDED),
      side: BorderSide(
        color: enabled ? const Color(0xFF9EC7FF) : const Color(0xFFD0D0D0),
      ),
    );
  }

  void _runCommand() {
    final cmd = _commandCtrl.text.trim();
    if (cmd.isEmpty) return;
    final response = context.read<DocumentHubService>().handleChatCommand(cmd);
    setState(() => _lastBotResponse = response);
  }

  Future<void> _simulateWhatsAppReceipt(String clientId) async {
    try {
      final receipt = await context.read<DocumentHubService>().ingestDocument(
        clientId: clientId,
        channel: ClientDocumentIntakeChannel.whatsapp,
        fileName: 'purchase_invoice_sample.jpg',
        sourceIdentity: '+91 9876543210',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(receipt.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }
}
