import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/presentation/pages/admin_user_management_screen.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/clients/Referral/client_referral_service.dart';
import 'package:chirag_accounting/features/marketing/services/marketing_service.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';

class MarketingPipelineScreen extends StatelessWidget {
  const MarketingPipelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final marketing = context.watch<MarketingService>();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        title: const Text('Marketing & Lead Pipeline'),
        backgroundColor: const Color(0xFF315D4B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Import client referrals',
            onPressed: () async {
              final count = await context
                  .read<MarketingService>()
                  .importReferrals(
                    context.read<ClientReferralService>().referrals,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$count referral lead(s) imported.')),
                );
              }
            },
            icon: const Icon(Icons.sync_outlined),
          ),
          IconButton(
            tooltip: 'Add lead',
            onPressed: () => _addLead(context),
            icon: const Icon(Icons.person_add_alt_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MarketingLeadStatus.values
                .map((status) {
                  final count = marketing.leads
                      .where((lead) => lead.status == status)
                      .length;
                  return Chip(label: Text('${_label(status)}  $count'));
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          if (marketing.leads.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Text('No leads. Add one or import client referrals.'),
              ),
            )
          else
            for (final lead in marketing.leads) _leadCard(context, lead),
        ],
      ),
    );
  }

  Widget _leadCard(BuildContext context, MarketingLead lead) {
    final matchingClients = context.read<AdminUserService>().users.where(
      (user) => user.role.isClient && user.mobile == lead.mobile,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    lead.name.isEmpty ? '?' : lead.name[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${lead.mobile} | ${lead.source.name}${lead.gstin.isEmpty ? '' : ' | ${lead.gstin}'}',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<MarketingLeadStatus>(
                    initialValue: lead.status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Stage',
                      isDense: true,
                    ),
                    items: MarketingLeadStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              _label(status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (status) {
                      if (status != null) {
                        context.read<MarketingService>().changeStatus(
                          lead.id,
                          status,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            if (lead.followUps.isNotEmpty) ...[
              const Divider(),
              ...lead.followUps.reversed
                  .take(2)
                  .map(
                    (item) => Text(
                      '${DateFormat('dd MMM yyyy').format(item.followUpAt)}: ${item.note}',
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addFollowUp(context, lead),
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Follow-up'),
                ),
                if (matchingClients.isEmpty &&
                    lead.status != MarketingLeadStatus.onboarded)
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminUserManagementScreen(
                          initialAction:
                              AdminClientManagementAction.onboardClient,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.rocket_launch_outlined),
                    label: const Text('Open onboarding'),
                  ),
                if (matchingClients.isNotEmpty &&
                    lead.status != MarketingLeadStatus.onboarded)
                  FilledButton.icon(
                    onPressed: () async {
                      final client = matchingClients.first;
                      await context.read<MarketingService>().markOnboarded(
                        lead.id,
                        client.id,
                      );
                      if (lead.referralId.isNotEmpty && context.mounted) {
                        await context
                            .read<ClientReferralService>()
                            .rewardReferral(
                              lead.referralId,
                              onboardedClientId: client.id,
                            );
                      }
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Confirm onboarded'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _label(MarketingLeadStatus status) => switch (status) {
    MarketingLeadStatus.newLead => 'New',
    MarketingLeadStatus.followUp => 'Follow-up',
    _ => status.name[0].toUpperCase() + status.name.substring(1),
  };

  static Future<void> _addFollowUp(
    BuildContext context,
    MarketingLead lead,
  ) async {
    final note = TextEditingController();
    var date = DateTime.now().add(const Duration(days: 1));
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Follow-up: ${lead.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              ListTile(
                title: const Text('Next follow-up'),
                trailing: Text(DateFormat('dd MMM yyyy').format(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2200),
                    initialDate: date,
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<MarketingService>().addFollowUp(
        leadId: lead.id,
        note: note.text,
        followUpAt: date,
      );
    }
    note.dispose();
  }

  static Future<void> _addLead(BuildContext context) async {
    final name = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final gstin = TextEditingController();
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add marketing lead'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name / firm'),
              ),
              TextField(
                controller: mobile,
                decoration: const InputDecoration(labelText: 'Mobile'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: gstin,
                decoration: const InputDecoration(labelText: 'GSTIN'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add lead'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await context.read<MarketingService>().addLead(
          name: name.text,
          mobile: mobile.text,
          email: email.text,
          gstin: gstin.text,
        );
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    name.dispose();
    mobile.dispose();
    email.dispose();
    gstin.dispose();
  }
}
