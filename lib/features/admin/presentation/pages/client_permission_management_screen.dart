import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart'
    hide ClientAccountingMode;
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/client_portal/registry/client_portal_module_registry.dart';
import 'package:chirag_accounting/features/clients/services/referral_program_service.dart';

class ClientPermissionManagementScreen extends StatefulWidget {
  const ClientPermissionManagementScreen({super.key, this.initialClientId});

  final String? initialClientId;

  @override
  State<ClientPermissionManagementScreen> createState() =>
      _ClientPermissionManagementScreenState();
}

class _ClientPermissionManagementScreenState
    extends State<ClientPermissionManagementScreen> {
  final Set<String> _selectedClientIds = <String>{};
  ClientPermissionTemplate _template = ClientPermissionTemplate.gst;

  @override
  void initState() {
    super.initState();
    if (widget.initialClientId != null) {
      _selectedClientIds.add(widget.initialClientId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<AdminUserService>();
    final access = context.watch<ClientPortalAccessService>();
    final clients = directory.users
        .where((user) => user.role.isClient)
        .toList(growable: false);
    final selectedId = _selectedClientIds.length == 1
        ? _selectedClientIds.single
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Portal Permissions'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final selector = _ClientSelector(
            clients: clients,
            selectedIds: _selectedClientIds,
            onChanged: (clientId, selected) {
              setState(() {
                if (selected) {
                  _selectedClientIds.add(clientId);
                } else {
                  _selectedClientIds.remove(clientId);
                }
              });
            },
          );
          final editor = selectedId == null
              ? _BulkTemplatePanel(
                  selectedCount: _selectedClientIds.length,
                  selectedTemplate: _template,
                  onTemplateChanged: (value) {
                    if (value != null) setState(() => _template = value);
                  },
                  onApply: _selectedClientIds.isEmpty
                      ? null
                      : () => _applyTemplate(access),
                )
              : _ClientAccessEditor(clientId: selectedId, access: access);

          if (compact) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [selector, const SizedBox(height: 16), editor],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 330,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: selector,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: editor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyTemplate(ClientPortalAccessService access) async {
    await access.applyTemplate(_selectedClientIds, _template);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_template.displayName} applied to ${_selectedClientIds.length} client(s).',
        ),
      ),
    );
  }
}

class _ClientSelector extends StatelessWidget {
  const _ClientSelector({
    required this.clients,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<dynamic> clients;
  final Set<String> selectedIds;
  final void Function(String clientId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Clients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: clients.isEmpty
                  ? null
                  : () {
                      final selectAll = selectedIds.length != clients.length;
                      for (final client in clients) {
                        onChanged(client.id as String, selectAll);
                      }
                    },
              child: Text(
                selectedIds.length == clients.length ? 'Clear' : 'Select all',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (clients.isEmpty)
          const Text('No client accounts are available.')
        else
          ...clients.map(
            (client) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: selectedIds.contains(client.id),
              title: Text(client.firmName as String),
              subtitle: Text(client.email as String),
              onChanged: (value) =>
                  onChanged(client.id as String, value ?? false),
            ),
          ),
      ],
    );
  }
}

class _BulkTemplatePanel extends StatelessWidget {
  const _BulkTemplatePanel({
    required this.selectedCount,
    required this.selectedTemplate,
    required this.onTemplateChanged,
    required this.onApply,
  });

  final int selectedCount;
  final ClientPermissionTemplate selectedTemplate;
  final ValueChanged<ClientPermissionTemplate?> onTemplateChanged;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bulk Access Template',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text('$selectedCount clients selected'),
        const SizedBox(height: 16),
        DropdownButtonFormField<ClientPermissionTemplate>(
          initialValue: selectedTemplate,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Service template',
            border: OutlineInputBorder(),
          ),
          items: ClientPermissionTemplate.values
              .map(
                (template) => DropdownMenuItem(
                  value: template,
                  child: Text(template.displayName),
                ),
              )
              .toList(growable: false),
          onChanged: onTemplateChanged,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Apply to selected clients'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Select one client to edit login, platform, module, action, and widget permissions in detail.',
        ),
      ],
    );
  }
}

class _ClientAccessEditor extends StatelessWidget {
  const _ClientAccessEditor({required this.clientId, required this.access});

  final String clientId;
  final ClientPortalAccessService access;

  @override
  Widget build(BuildContext context) {
    final profile = access.profileFor(clientId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Login & Platform Access',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _AccessSwitch(
              label: 'Portal login',
              value: profile.loginEnabled,
              onChanged: (value) =>
                  access.updateLoginAccess(clientId, loginEnabled: value),
            ),
            _AccessSwitch(
              label: 'Mobile / tablet',
              value: profile.mobileLoginEnabled,
              onChanged: (value) =>
                  access.updateLoginAccess(clientId, mobileLoginEnabled: value),
            ),
            _AccessSwitch(
              label: 'Web',
              value: profile.webLoginEnabled,
              onChanged: (value) =>
                  access.updateLoginAccess(clientId, webLoginEnabled: value),
            ),
            _AccessSwitch(
              label: 'Require 2FA',
              value: profile.twoFactorRequired,
              onChanged: (value) =>
                  access.updateLoginAccess(clientId, twoFactorRequired: value),
            ),
            _AccessSwitch(
              label: 'Account locked',
              value: profile.accountLocked,
              onChanged: (value) =>
                  access.updateLoginAccess(clientId, accountLocked: value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: profile.subscriptionPlan,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Subscription plan',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'standard', child: Text('Standard')),
            DropdownMenuItem(value: 'premium', child: Text('Premium')),
            DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
          ],
          onChanged: (value) {
            if (value != null) {
              access.updateLoginAccess(clientId, subscriptionPlan: value);
            }
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Client Workflow Setup',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ClientBillingMode>(
          initialValue: profile.billingMode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Billing mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: ClientBillingMode.imageUploadAccountantEntry,
              child: Text('Image Upload Only (Accountant Handles Accounting)'),
            ),
            DropdownMenuItem(
              value: ClientBillingMode.fullBillingSoftware,
              child: Text('Complete Billing Software'),
            ),
            DropdownMenuItem(
              value: ClientBillingMode.hybrid,
              child: Text('Hybrid (Upload + Billing)'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              access.updateWorkflowAccess(clientId, billingMode: value);
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ClientAccountingMode>(
          initialValue: profile.accountingMode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Accounting mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: ClientAccountingMode.accountsOnly,
              child: Text('Accounts Only'),
            ),
            DropdownMenuItem(
              value: ClientAccountingMode.accountsWithInventory,
              child: Text('Accounts + Inventory'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              access.updateWorkflowAccess(clientId, accountingMode: value);
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ClientVoucherEntryMode>(
                initialValue: profile.salesEntryMode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sales entry mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ClientVoucherEntryMode.manual,
                    child: Text('Manual Billing'),
                  ),
                  DropdownMenuItem(
                    value: ClientVoucherEntryMode.ocr,
                    child: Text('OCR Only'),
                  ),
                  DropdownMenuItem(
                    value: ClientVoucherEntryMode.both,
                    child: Text('Both'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    access.updateWorkflowAccess(
                      clientId,
                      salesEntryMode: value,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<ClientVoucherEntryMode>(
                initialValue: profile.purchaseEntryMode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Purchase entry mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ClientVoucherEntryMode.manual,
                    child: Text('Manual'),
                  ),
                  DropdownMenuItem(
                    value: ClientVoucherEntryMode.ocr,
                    child: Text('AI OCR'),
                  ),
                  DropdownMenuItem(
                    value: ClientVoucherEntryMode.both,
                    child: Text('Both'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    access.updateWorkflowAccess(
                      clientId,
                      purchaseEntryMode: value,
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Document Hub Controls',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _AccessSwitch(
          label: 'Enable WhatsApp Upload',
          value: profile.documentHubAccess.enableWhatsAppUpload,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(enableWhatsAppUpload: value),
          ),
        ),
        _AccessSwitch(
          label: 'Auto OCR',
          value: profile.documentHubAccess.autoOcr,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(autoOcr: value),
          ),
        ),
        _AccessSwitch(
          label: 'Auto Classification',
          value: profile.documentHubAccess.autoClassification,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(autoClassification: value),
          ),
        ),
        _AccessSwitch(
          label: 'Allow Voice Notes',
          value: profile.documentHubAccess.allowVoiceNotes,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(allowVoiceNotes: value),
          ),
        ),
        _AccessSwitch(
          label: 'Auto Reply',
          value: profile.documentHubAccess.autoReply,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(autoReply: value),
          ),
        ),
        _AccessSwitch(
          label: 'WhatsApp Commands',
          value: profile.documentHubAccess.enableWhatsAppCommands,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(enableWhatsAppCommands: value),
          ),
        ),
        _AccessSwitch(
          label: 'AI Chat',
          value: profile.documentHubAccess.enableAiChat,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(enableAiChat: value),
          ),
        ),
        _AccessSwitch(
          label: 'Document Status Notifications',
          value: profile.documentHubAccess.documentStatusNotifications,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(
              documentStatusNotifications: value,
            ),
          ),
        ),
        _AccessSwitch(
          label: 'Daily Reminder',
          value: profile.documentHubAccess.dailyReminder,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(dailyReminder: value),
          ),
        ),
        _AccessSwitch(
          label: 'Monthly Reminder',
          value: profile.documentHubAccess.monthlyReminder,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(monthlyReminder: value),
          ),
        ),
        _AccessSwitch(
          label: 'Auto Follow-up for Missing Bills',
          value: profile.documentHubAccess.autoFollowUpMissingBills,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(autoFollowUpMissingBills: value),
          ),
        ),
        _AccessSwitch(
          label: 'Enable Email Inbox Import',
          value: profile.documentHubAccess.enableEmailImport,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(enableEmailImport: value),
          ),
        ),
        _AccessSwitch(
          label: 'Enable Cloud Folder Sync',
          value: profile.documentHubAccess.enableCloudSync,
          onChanged: (value) => access.updateDocumentHubAccess(
            clientId,
            profile.documentHubAccess.copyWith(enableCloudSync: value),
          ),
        ),
        const SizedBox(height: 24),
        _ReferralCampaignSection(clientId: clientId),
        const SizedBox(height: 24),
        const Text(
          'Dashboard Widgets',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...ClientPortalModuleRegistry.dashboardWidgets.map(
          (widget) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(widget.icon),
            title: Text(widget.displayName),
            subtitle: widget.requiredModuleId == null
                ? null
                : Text('Requires ${widget.requiredModuleId} module access'),
            value: access.widgetEnabled(clientId, widget.id),
            onChanged: (value) =>
                access.setDashboardWidget(clientId, widget.id, value),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Modules & Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...access.registeredModules.map((module) {
          final moduleAccess = access.moduleAccess(clientId, module.id);
          return ExpansionTile(
            leading: Icon(module.icon),
            title: Text(module.displayName),
            subtitle: Text('${module.category} · ${module.route}'),
            trailing: Switch(
              value: moduleAccess.enabled,
              onChanged: (value) => access.updateModuleAccess(
                clientId,
                moduleAccess.copyWith(enabled: value),
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              Wrap(
                spacing: 12,
                children: [
                  _AccessSwitch(
                    label: 'Mobile',
                    value: moduleAccess.mobileAccess,
                    onChanged: (value) => access.updateModuleAccess(
                      clientId,
                      moduleAccess.copyWith(mobileAccess: value),
                    ),
                  ),
                  _AccessSwitch(
                    label: 'Web',
                    value: moduleAccess.webAccess,
                    onChanged: (value) => access.updateModuleAccess(
                      clientId,
                      moduleAccess.copyWith(webAccess: value),
                    ),
                  ),
                  _AccessSwitch(
                    label: 'Tablet',
                    value: moduleAccess.tabletAccess,
                    onChanged: (value) => access.updateModuleAccess(
                      clientId,
                      moduleAccess.copyWith(tabletAccess: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ClientModuleAction.values
                    .map((action) {
                      final selected = moduleAccess.actions.contains(action);
                      return FilterChip(
                        label: Text(action.name),
                        selected: selected,
                        onSelected: (value) {
                          final actions = <ClientModuleAction>{
                            ...moduleAccess.actions,
                          };
                          value ? actions.add(action) : actions.remove(action);
                          access.updateModuleAccess(
                            clientId,
                            moduleAccess.copyWith(actions: actions),
                          );
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              if (module.dashboardWidgetId != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show dashboard widget'),
                  value: access.widgetEnabled(
                    clientId,
                    module.dashboardWidgetId!,
                  ),
                  onChanged: (value) => access.setDashboardWidget(
                    clientId,
                    module.dashboardWidgetId!,
                    value,
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _ReferralCampaignSection extends StatelessWidget {
  const _ReferralCampaignSection({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ReferralProgramService>();
    final campaign = service.campaign;
    final referrals = service.referralsForClient(clientId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Referral Reward Program',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openCampaignDialog(context, campaign),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit reward'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.campaignName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${campaign.rewardAmountLabel} ${campaign.yourAwardType} for client, ${campaign.rewardAmountLabel} ${campaign.contactAwardType} for the referred contact.',
                ),
                const SizedBox(height: 4),
                Text(
                  campaign.contactAwardDetail,
                  style: const TextStyle(color: Color(0xFF5F7188)),
                ),
                const SizedBox(height: 8),
                Text(
                  campaign.active ? 'Campaign active' : 'Campaign paused',
                  style: TextStyle(
                    color: campaign.active
                        ? const Color(0xFF11895C)
                        : const Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Client Referral History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (referrals.isEmpty)
          const Text('No referral records for this client yet.')
        else
          ...referrals.map((record) => _ReferralAdminCard(record: record)),
      ],
    );
  }

  Future<void> _openCampaignDialog(
    BuildContext context,
    ReferralCampaign campaign,
  ) async {
    final campaignNameCtrl = TextEditingController(text: campaign.campaignName);
    final rewardAmountCtrl = TextEditingController(
      text: campaign.rewardAmount.toString(),
    );
    final yourAwardTypeCtrl = TextEditingController(
      text: campaign.yourAwardType,
    );
    final contactAwardTypeCtrl = TextEditingController(
      text: campaign.contactAwardType,
    );
    final contactAwardDetailCtrl = TextEditingController(
      text: campaign.contactAwardDetail,
    );
    var active = campaign.active;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Referral Reward'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: campaignNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Campaign name',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter campaign name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: rewardAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reward amount',
                          ),
                          validator: (value) {
                            final amount = int.tryParse(value ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Enter valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: yourAwardTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Client reward type',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactAwardTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contact reward type',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactAwardDetailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contact reward detail',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          onChanged: (value) => setState(() => active = value),
                          title: const Text('Campaign active'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await context.read<ReferralProgramService>().updateCampaign(
                      campaign.copyWith(
                        campaignName: campaignNameCtrl.text.trim(),
                        rewardAmount: int.parse(rewardAmountCtrl.text.trim()),
                        yourAwardType: yourAwardTypeCtrl.text.trim(),
                        contactAwardType: contactAwardTypeCtrl.text.trim(),
                        contactAwardDetail: contactAwardDetailCtrl.text.trim(),
                        active: active,
                      ),
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    campaignNameCtrl.dispose();
    rewardAmountCtrl.dispose();
    yourAwardTypeCtrl.dispose();
    contactAwardTypeCtrl.dispose();
    contactAwardDetailCtrl.dispose();
  }
}

class _ReferralAdminCard extends StatelessWidget {
  const _ReferralAdminCard({required this.record});

  final ReferralRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.contactName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<ReferralStatus>(
                    initialValue: record.status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: ReferralStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.displayLabel),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      context
                          .read<ReferralProgramService>()
                          .updateReferralStatus(record.id, value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${record.businessName} · ${record.mobileNumber}'),
            if (record.email.trim().isNotEmpty) Text(record.email),
            const SizedBox(height: 6),
            Text(
              'Created ${DateFormat('dd MMM yyyy, hh:mm a').format(record.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F7188)),
            ),
            Text(
              'Updated ${DateFormat('dd MMM yyyy, hh:mm a').format(record.updatedAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F7188)),
            ),
            if (record.rewardAmount != null) ...[
              const SizedBox(height: 6),
              Text(
                'Reward mapped: Rs. ${record.rewardAmount}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openAdminNoteDialog(context, record),
                  icon: const Icon(Icons.note_alt_outlined),
                  label: Text(
                    record.adminNote.trim().isEmpty
                        ? 'Add admin note'
                        : 'Edit admin note',
                  ),
                ),
                if (record.status != ReferralStatus.rewardPaid)
                  FilledButton.tonalIcon(
                    onPressed: () => context
                        .read<ReferralProgramService>()
                        .updateReferralStatus(
                          record.id,
                          ReferralStatus.rewardPaid,
                        ),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Mark reward paid'),
                  ),
              ],
            ),
            if (record.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Client note: ${record.notes}'),
            ],
            if (record.adminNote.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Admin note: ${record.adminNote}',
                style: const TextStyle(color: Color(0xFF8A4D00)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAdminNoteDialog(
    BuildContext context,
    ReferralRecord record,
  ) async {
    final noteCtrl = TextEditingController(text: record.adminNote);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Admin Note'),
          content: TextField(
            controller: noteCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Note for referral timeline',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await context
                    .read<ReferralProgramService>()
                    .updateReferralStatus(
                      record.id,
                      record.status,
                      adminNote: noteCtrl.text.trim(),
                    );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Save note'),
            ),
          ],
        );
      },
    );
    noteCtrl.dispose();
  }
}

class _AccessSwitch extends StatelessWidget {
  const _AccessSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: value, onChanged: onChanged),
        Text(label),
      ],
    );
  }
}
