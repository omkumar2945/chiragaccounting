import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/client_360_detail_screen.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/uni_desk/services/uni_desk_service.dart';

class UniDeskScreen extends StatelessWidget {
  const UniDeskScreen({super.key});

  String _roleKey(UserRole role) {
    if (role == UserRole.client) return 'client';
    if (role == UserRole.accountant) return 'accountant';
    return 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final directory = context.watch<AdminUserService>();
    final service = context.watch<UniDeskService>();
    final roleKey = _roleKey(user.role);
    final isAuthenticated = service.isUserAuthenticatedForRole(
      roleKey: roleKey,
      userId: user.id,
    );

    if (!isAuthenticated) {
      return _UniDeskAccessGate(user: user, roleKey: roleKey);
    }

    final isClient = user.role.isClient;
    final isAdmin = user.role == UserRole.superAdmin;
    final clients = directory.users
        .where((candidate) => candidate.role.isClient)
        .toList(growable: false);
    final visibleClientIds = isAdmin
        ? clients.map((client) => client.id).toSet()
        : clients
              .where(
                (client) =>
                    directory
                        .accountingAccessFor(client.id)
                        .assignedAccountantId ==
                    user.id,
              )
              .map((client) => client.id)
              .toSet();
    final requests = List<UniDeskRequest>.from(
      isClient
          ? service.requestsForClient(user.id)
          : service.requests.where(
              (request) => visibleClientIds.contains(request.clientId),
            ),
    )..sort((left, right) => right.requestedAt.compareTo(left.requestedAt));
    final now = DateTime.now();
    final active = requests.where((request) => request.isActiveAt(now)).length;
    final awaiting = requests
        .where(
          (request) =>
              request.status == UniDeskRequestStatus.awaitingStaff ||
              request.status == UniDeskRequestStatus.pendingClientApproval,
        )
        .length;
    final expired = requests
        .where(
          (request) =>
              request.status == UniDeskRequestStatus.active &&
              !request.isActiveAt(now),
        )
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: Text(
          isClient ? 'Uni-Desk Assistance' : 'Uni-Desk System Monitor',
        ),
        backgroundColor: const Color(0xFF243B53),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRequestForm(
          context,
          user: user,
          clients: clients
              .where(
                (client) => isAdmin || visibleClientIds.contains(client.id),
              )
              .toList(growable: false),
        ),
        icon: const Icon(Icons.support_agent_outlined),
        label: Text(isClient ? 'Raise request' : 'Request permission'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isClient) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MonitorTile(
                  label: 'Visible clients',
                  value: visibleClientIds.length,
                ),
                _MonitorTile(label: 'Awaiting action', value: awaiting),
                _MonitorTile(label: 'Active sessions', value: active),
                _MonitorTile(label: 'Expired sessions', value: expired),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Access starts only after client consent. Assigned accountants can handle their clients; admins can handle all clients. Every action is time-bound and logged.',
            ),
            const SizedBox(height: 18),
          ],
          if (requests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text('No Uni-Desk assistance requests.')),
              ),
            )
          else
            ...requests.map((request) {
              final client = clients
                  .where((candidate) => candidate.id == request.clientId)
                  .firstOrNull;
              return _RequestCard(
                request: request,
                clientName: client?.firmName.isNotEmpty == true
                    ? client!.firmName
                    : client?.name ?? request.clientId,
                currentUser: user,
                isAdmin: isAdmin,
                assignedAccountantId: directory
                    .accountingAccessFor(request.clientId)
                    .assignedAccountantId,
                onOpenWorkspace: client == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Client360DetailScreen(
                            clientName: client.firmName.isEmpty
                                ? client.name
                                : client.firmName,
                          ),
                        ),
                      ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _openRequestForm(
    BuildContext context, {
    required UserModel user,
    required List<UserModel> clients,
  }) async {
    if (!user.role.isClient && clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assigned client is available for Uni-Desk.'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _UniDeskRequestForm(user: user, clients: clients),
      ),
    );
  }
}

class _MonitorTile extends StatelessWidget {
  const _MonitorTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD8E1E8)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text('$value', style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.clientName,
    required this.currentUser,
    required this.isAdmin,
    required this.assignedAccountantId,
    required this.onOpenWorkspace,
  });

  final UniDeskRequest request;
  final String clientName;
  final UserModel currentUser;
  final bool isAdmin;
  final String assignedAccountantId;
  final VoidCallback? onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    final isClient = currentUser.role.isClient;
    final isActive = request.isActiveAt(DateTime.now());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Icon(
          isActive
              ? Icons.desktop_windows_outlined
              : Icons.support_agent_outlined,
          color: isActive ? Colors.green.shade700 : const Color(0xFF486581),
        ),
        title: Text(request.subject),
        subtitle: Text(
          '$clientName | ${request.status.name}\n'
          '${request.scopes.map((scope) => scope.name).join(', ')} | ${request.durationHours} hour(s)',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(request.details)),
          if (request.expiresAt != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Access expires ${DateFormat('dd MMM yyyy HH:mm').format(request.expiresAt!)}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isClient &&
                  request.status == UniDeskRequestStatus.pendingClientApproval)
                FilledButton.icon(
                  onPressed: () =>
                      context.read<UniDeskService>().approveByClient(
                        requestId: request.id,
                        clientId: currentUser.id,
                      ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve permission'),
                ),
              if (isClient &&
                  request.status != UniDeskRequestStatus.ended &&
                  request.status != UniDeskRequestStatus.revoked)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.read<UniDeskService>().revokeByClient(
                        requestId: request.id,
                        clientId: currentUser.id,
                      ),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Revoke access'),
                ),
              if (!isClient &&
                  request.status == UniDeskRequestStatus.awaitingStaff)
                FilledButton.icon(
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start assistance'),
                ),
              if (!isClient &&
                  isActive &&
                  request.assignedUserId == currentUser.id &&
                  onOpenWorkspace != null)
                FilledButton.icon(
                  onPressed: onOpenWorkspace,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    request.grantsFullControl
                        ? 'Open full-control workspace'
                        : 'Open assisted workspace',
                  ),
                ),
              if (!isClient &&
                  isActive &&
                  request.assignedUserId == currentUser.id)
                OutlinedButton.icon(
                  onPressed: () => context.read<UniDeskService>().endSession(
                    requestId: request.id,
                    staffUserId: currentUser.id,
                  ),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End session'),
                ),
            ],
          ),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Audit history',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...request.events.reversed.map(
            (event) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 18),
              title: Text(event.action),
              subtitle: Text(
                '${event.actorUserId} | ${DateFormat('dd MMM yyyy HH:mm').format(event.occurredAt)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    try {
      await context.read<UniDeskService>().startSession(
        requestId: request.id,
        staffUserId: currentUser.id,
        isAdmin: isAdmin,
        assignedAccountantId: assignedAccountantId,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }
}

class _UniDeskRequestForm extends StatefulWidget {
  const _UniDeskRequestForm({required this.user, required this.clients});

  final UserModel user;
  final List<UserModel> clients;

  @override
  State<_UniDeskRequestForm> createState() => _UniDeskRequestFormState();
}

class _UniDeskRequestFormState extends State<_UniDeskRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _details = TextEditingController();
  final Set<UniDeskScope> _scopes = <UniDeskScope>{UniDeskScope.viewOnly};
  String? _clientId;
  int _durationHours = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clientId = widget.user.role.isClient
        ? widget.user.id
        : widget.clients.firstOrNull?.id;
  }

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.user.role.isClient
            ? 'Raise Uni-Desk Request'
            : 'Request Client Permission',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.user.role.isClient)
            DropdownButtonFormField<String>(
              initialValue: _clientId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Client',
                border: OutlineInputBorder(),
              ),
              items: widget.clients
                  .map(
                    (client) => DropdownMenuItem(
                      value: client.id,
                      child: Text(
                        client.firmName.isEmpty ? client.name : client.firmName,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _clientId = value),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subject,
            decoration: const InputDecoration(
              labelText: 'Assistance subject',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.trim().isEmpty ?? true ? 'Enter a subject.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _details,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Issue and assistance required',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Permissions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: UniDeskScope.values
                .map(
                  (scope) => FilterChip(
                    label: Text(scope.name),
                    selected: _scopes.contains(scope),
                    onSelected: (selected) => setState(() {
                      selected ? _scopes.add(scope) : _scopes.remove(scope);
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _durationHours,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Access duration',
              border: OutlineInputBorder(),
            ),
            items: const <int>[1, 2, 4, 8, 24]
                .map(
                  (hours) => DropdownMenuItem(
                    value: hours,
                    child: Text('$hours hour${hours == 1 ? '' : 's'}'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _durationHours = value ?? 1),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(
              widget.user.role.isClient
                  ? 'Grant permission and raise request'
                  : 'Send permission request to client',
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null || _scopes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a client and at least one permission.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final service = context.read<UniDeskService>();
      if (widget.user.role.isClient) {
        await service.raiseByClient(
          clientId: widget.user.id,
          subject: _subject.text,
          details: _details.text,
          scopes: _scopes,
          durationHours: _durationHours,
        );
      } else {
        await service.requestPermissionByStaff(
          clientId: _clientId!,
          requestedBy: widget.user.id,
          subject: _subject.text,
          details: _details.text,
          scopes: _scopes,
          durationHours: _durationHours,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _UniDeskAccessGate extends StatefulWidget {
  const _UniDeskAccessGate({required this.user, required this.roleKey});

  final UserModel user;
  final String roleKey;

  @override
  State<_UniDeskAccessGate> createState() => _UniDeskAccessGateState();
}

class _UniDeskAccessGateState extends State<_UniDeskAccessGate> {
  final TextEditingController _accessIdController = TextEditingController();
  bool _submitting = false;
  bool _autoGenerating = false;

  bool get _canGenerate {
    const caAuditorRoles = <UserRole>{
      UserRole.firmAdmin,
      UserRole.partner,
      UserRole.checker,
    };
    return widget.user.role == UserRole.superAdmin ||
        widget.user.role == UserRole.admin ||
        widget.user.role == UserRole.accountant ||
        widget.user.role.isClient ||
        caAuditorRoles.contains(widget.user.role);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureAccessIdOnOpen();
    });
  }

  Future<void> _ensureAccessIdOnOpen() async {
    if (!_canGenerate) return;
    final service = context.read<UniDeskService>();
    if (service.hasActiveAccessId) return;
    setState(() => _autoGenerating = true);
    try {
      final newId = await service.rotateAccessId(
        generatedByUserId: widget.user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uni-Desk ID auto-generated: $newId')),
      );
    } finally {
      if (mounted) {
        setState(() => _autoGenerating = false);
      }
    }
  }

  @override
  void dispose() {
    _accessIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<UniDeskService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: const Text('Uni-Desk Access Authentication'),
        backgroundColor: const Color(0xFF243B53),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHIRAG -> Generate Random ID -> Share with team -> Authenticate -> Uni-Desk',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  if (_canGenerate) ...[
                    FilledButton.icon(
                      onPressed: _autoGenerating
                          ? null
                          : () async {
                        final newId = await context
                            .read<UniDeskService>()
                            .rotateAccessId(generatedByUserId: widget.user.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Uni-Desk ID regenerated: $newId')),
                        );
                      },
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: Text(
                        service.hasActiveAccessId
                            ? 'Regenerate Uni-Desk ID'
                            : 'Generate Uni-Desk ID',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (service.hasActiveAccessId)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: service.activeAccessId),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Uni-Desk ID copied for sharing')),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: Text('Share ID: ${service.activeAccessId}'),
                      ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _accessIdController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Enter Shared Uni-Desk ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _submitting
                        ? null
                        : () async {
                            setState(() => _submitting = true);
                            try {
                              final ok = await context
                                  .read<UniDeskService>()
                                  .authenticateWithAccessId(
                                    roleKey: widget.roleKey,
                                    userId: widget.user.id,
                                    accessId: _accessIdController.text,
                                  );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Authentication successful. Uni-Desk unlocked.'
                                        : 'Invalid Uni-Desk ID. Please use the shared ID.',
                                  ),
                                  backgroundColor: ok ? null : Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _submitting = false);
                            }
                          },
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Authenticate and Open Uni-Desk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
