import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/firebase/firebase_runtime_service.dart';

class FirebaseServicesStatusScreen extends StatelessWidget {
  const FirebaseServicesStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebase = context.watch<FirebaseRuntimeService>();
    final statuses = firebase.statuses.entries.toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Services'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh notification permission',
            onPressed: firebase.initialized
                ? firebase.refreshMessagingPermission
                : firebase.initialize,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            firebase.initialized
                ? 'Firebase is connected. OTP identity is verified by Firebase; Client/Admin/CA roles and account status are verified by Chirag Accounting.'
                : 'Firebase project configuration is required. Existing authentication remains active until Firebase connects.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD8E2F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var index = 0; index < statuses.length; index++) ...[
                  _FirebaseStatusTile(
                    name: statuses[index].key,
                    status: statuses[index].value,
                  ),
                  if (index < statuses.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          if (firebase.messagingToken != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              'FCM token: ${firebase.messagingToken}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirebaseStatusTile extends StatelessWidget {
  const _FirebaseStatusTile({required this.name, required this.status});

  final String name;
  final FirebaseFeatureStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status.state) {
      FirebaseFeatureState.active => (
        Icons.check_circle_outline,
        const Color(0xFF2E7D32),
        'Active',
      ),
      FirebaseFeatureState.permissionRequired => (
        Icons.notifications_off_outlined,
        const Color(0xFFEF6C00),
        'Permission required',
      ),
      FirebaseFeatureState.notConfigured => (
        Icons.settings_outlined,
        const Color(0xFF455A64),
        'Not configured',
      ),
      FirebaseFeatureState.unsupported => (
        Icons.block_outlined,
        const Color(0xFF616161),
        'Unsupported',
      ),
      FirebaseFeatureState.failed => (
        Icons.error_outline,
        const Color(0xFFC62828),
        'Failed',
      ),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(status.message),
      trailing: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
