import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/clients/services/referral_program_service.dart';
import 'package:chirag_accounting/features/marketing/presentation/pages/marketing_pipeline_screen.dart';
import 'package:chirag_accounting/features/marketing/services/marketing_service.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';

class AdminReferralManagementScreen extends StatefulWidget {
  const AdminReferralManagementScreen({super.key});

  @override
  State<AdminReferralManagementScreen> createState() =>
      _AdminReferralManagementScreenState();
}

class _AdminReferralManagementScreenState
    extends State<AdminReferralManagementScreen> {
  String _query = '';
  ReferralStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ReferralProgramService>().load();
      if (mounted) await context.read<AdminUserService>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final referralService = context.watch<ReferralProgramService>();
    final directory = context.watch<AdminUserService>();
    final marketing = context.watch<MarketingService>();
    final allReferrals = referralService.allRecords;
    final campaign = referralService.campaign;
    final query = _query.toLowerCase();
    final referrals = allReferrals
        .where((referral) {
          final referrer = _referrerName(directory, referral.clientId);
          final matchesQuery =
              query.isEmpty ||
              referral.contactName.toLowerCase().contains(query) ||
              referral.businessName.toLowerCase().contains(query) ||
              referral.mobileNumber.contains(query) ||
              referrer.toLowerCase().contains(query) ||
              referral.clientId.toLowerCase().contains(query);
          return matchesQuery &&
              (_statusFilter == null || referral.status == _statusFilter);
        })
        .toList(growable: false);
    final rewarded = allReferrals
        .where((item) => item.status == ReferralStatus.rewardPaid)
        .length;
    final totalRewards = allReferrals.fold<int>(
      0,
      (total, referral) => total + (referral.rewardAmount ?? 0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Referral Reward Management'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _campaignCard(referralService, campaign),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReferralMetric(
                label: 'Total referrals',
                value: allReferrals.length,
              ),
              _ReferralMetric(
                label: 'Pending review',
                value: allReferrals.length - rewarded,
              ),
              _ReferralMetric(label: 'Rewarded', value: rewarded),
              _ReferralMetric(label: 'Rewards paid', value: totalRewards),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD8E2F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search referrer, client, mobile, or GSTIN',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ),
                SegmentedButton<ReferralStatus?>(
                  segments: const [
                    ButtonSegment<ReferralStatus?>(
                      value: null,
                      label: Text('All'),
                    ),
                    ButtonSegment<ReferralStatus?>(
                      value: ReferralStatus.invited,
                      label: Text('Invited'),
                    ),
                    ButtonSegment<ReferralStatus?>(
                      value: ReferralStatus.rewardApproved,
                      label: Text('Approved'),
                    ),
                    ButtonSegment<ReferralStatus?>(
                      value: ReferralStatus.rewardPaid,
                      label: Text('Paid'),
                    ),
                  ],
                  selected: <ReferralStatus?>{_statusFilter},
                  onSelectionChanged: (selection) =>
                      setState(() => _statusFilter = selection.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (referrals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('No referrals match this view.')),
            )
          else
            for (final referral in referrals)
              _referralCard(referral, directory, referralService, marketing),
        ],
      ),
    );
  }

  Widget _referralCard(
    ReferralRecord referral,
    AdminUserService directory,
    ReferralProgramService referralService,
    MarketingService marketing,
  ) {
    final rewardPaid = referral.status == ReferralStatus.rewardPaid;
    final approved = referral.status == ReferralStatus.rewardApproved;
    final readyForClaim = approved || rewardPaid;
    final rewardAmount = referral.rewardAmount ?? referralService.campaign.rewardAmount;
    final hasMarketingLead = marketing.leads.any(
      (lead) => lead.referralId == referral.id,
    );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: rewardPaid
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              foregroundColor: rewardPaid
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFEF6C00),
              child: Icon(
                rewardPaid ? Icons.redeem_outlined : Icons.hourglass_top,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    referral.contactName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Referred by: ${_referrerName(directory, referral.clientId)}',
                  ),
                  Text(
                    '${referral.mobileNumber}  |  ${referral.businessName}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (referral.email.trim().isNotEmpty)
                    Text(
                      referral.email,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  Text(
                    'Submitted: ${_shortDate(referral.createdAt)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  if (referral.registrationLink.trim().isNotEmpty)
                    Text(
                      'Registration link generated',
                      style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12),
                    ),
                  if (referral.registeredAt != null)
                    Text(
                      'Registered: ${_shortDate(referral.registeredAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (readyForClaim)
                    Text(
                      'Reward: Rs. $rewardAmount (${referral.status.displayLabel})',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                IconButton(
                  tooltip: 'Copy referral contact',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${referral.contactName}, ${referral.mobileNumber}, ${referral.businessName}',
                      ),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Referral contact copied.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
                if (referral.registrationLink.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'Copy registration link',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: referral.registrationLink),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Registration link copied.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.link_outlined),
                  ),
                if (!hasMarketingLead)
                  FilledButton.tonalIcon(
                    onPressed: () => _sendToMarketing(
                      referral: referral,
                      referralService: referralService,
                      marketing: marketing,
                    ),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Send to Marketing'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MarketingPipelineScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.trending_up_outlined),
                    label: const Text('Open Marketing'),
                  ),
                if (!rewardPaid)
                  FilledButton.icon(
                    onPressed: () => _awardPoints(referral, referralService),
                    icon: const Icon(Icons.redeem_outlined),
                    label: Text(
                      approved ? 'Mark Paid' : 'Approve Reward',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendToMarketing({
    required ReferralRecord referral,
    required ReferralProgramService referralService,
    required MarketingService marketing,
  }) async {
    await marketing.addLead(
      name: referral.contactName,
      mobile: referral.mobileNumber,
      email: referral.email,
      source: MarketingLeadSource.referral,
      referralId: referral.id,
    );
    await referralService.updateReferralStatus(
      referral.id,
      ReferralStatus.contacted,
      adminNote: 'Shared with marketing team for onboarding follow-up.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral sent to marketing pipeline.'),
      ),
    );
  }

  Widget _campaignCard(
    ReferralProgramService service,
    ReferralCampaign campaign,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.campaignName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Offer: ${campaign.rewardAmountLabel} ${campaign.yourAwardType}',
                ),
                Text('Contact benefit: ${campaign.contactAwardType}'),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _editCampaignOffer(service, campaign),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Offer'),
          ),
        ],
      ),
    );
  }

  Future<void> _awardPoints(
    ReferralRecord referral,
    ReferralProgramService service,
  ) async {
    final nextStatus = referral.status == ReferralStatus.rewardApproved
        ? ReferralStatus.rewardPaid
        : ReferralStatus.rewardApproved;
    final confirmed = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          nextStatus == ReferralStatus.rewardPaid
              ? 'Mark Reward as Paid'
              : 'Approve Referral Reward',
        ),
        content: Text(
          nextStatus == ReferralStatus.rewardPaid
              ? 'Mark reward as paid for ${referral.contactName}.'
              : 'Approve reward for ${referral.contactName}. This will make it eligible in client reward dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await service.updateReferralStatus(referral.id, nextStatus);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          nextStatus == ReferralStatus.rewardPaid
              ? 'Reward marked as paid.'
              : 'Reward approved and visible to client as eligible.',
        ),
      ),
    );
  }

  Future<void> _editCampaignOffer(
    ReferralProgramService service,
    ReferralCampaign campaign,
  ) async {
    final nameCtrl = TextEditingController(text: campaign.campaignName);
    final amountCtrl = TextEditingController(
      text: campaign.rewardAmount.toString(),
    );
    final yourAwardCtrl = TextEditingController(text: campaign.yourAwardType);
    final contactAwardCtrl = TextEditingController(
      text: campaign.contactAwardType,
    );
    final contactDetailCtrl = TextEditingController(
      text: campaign.contactAwardDetail,
    );
    bool active = campaign.active;

    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Reward Offer'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Campaign name',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reward amount',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: yourAwardCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your award type',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contactAwardCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact award type',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contactDetailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact award detail',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      title: const Text('Offer active'),
                      onChanged: (value) {
                        setDialogState(() => active = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save Offer'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final amount = int.tryParse(amountCtrl.text.trim()) ?? campaign.rewardAmount;
      await service.updateCampaign(
        campaign.copyWith(
          campaignName: nameCtrl.text.trim(),
          rewardAmount: amount,
          yourAwardType: yourAwardCtrl.text.trim(),
          contactAwardType: contactAwardCtrl.text.trim(),
          contactAwardDetail: contactDetailCtrl.text.trim(),
          active: active,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reward offer updated.')),
        );
      }
    }

    nameCtrl.dispose();
    amountCtrl.dispose();
    yourAwardCtrl.dispose();
    contactAwardCtrl.dispose();
    contactDetailCtrl.dispose();
  }

  String _referrerName(AdminUserService directory, String clientId) {
    for (final user in directory.users) {
      if (user.id == clientId) return '${user.name} ($clientId)';
    }
    return clientId;
  }

  String _shortDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _ReferralMetric extends StatelessWidget {
  const _ReferralMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
