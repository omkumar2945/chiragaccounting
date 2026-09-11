import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/services/referral_program_service.dart';

class ClientReferralScreen extends StatefulWidget {
  const ClientReferralScreen({super.key});

  @override
  State<ClientReferralScreen> createState() => _ClientReferralScreenState();
}

class _ClientReferralScreenState extends State<ClientReferralScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final service = context.watch<ReferralProgramService>();
    final campaign = service.campaign;
    final referrals = user == null
        ? const <ReferralRecord>[]
        : service.referralsForClient(user.id);
    final rewards = user == null
        ? const <ReferralRecord>[]
        : service.rewardHistoryForClient(user.id);
    final eligibleRewards = user == null
      ? const <ReferralRecord>[]
      : service.eligibleRewardsForClient(user.id);
    final claimHistory = user == null
      ? const <ReferralRecord>[]
      : service.claimHistoryForClient(user.id);
    final upcomingRewards = user == null
      ? const <ReferralRecord>[]
      : service.upcomingRewardsForClient(user.id);
    final eligibleAmount = user == null
      ? 0
      : service.totalEligibleRewardAmountForClient(user.id);
    final claimedAmount = user == null
      ? 0
      : service.totalClaimedRewardAmountForClient(user.id);
    final upcomingAmount = user == null
      ? 0
      : service.totalUpcomingRewardAmountForClient(user.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Rewards'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Referrals'),
            Tab(text: 'Rewards'),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: Text('Client session not available.'))
          : TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                  campaign: campaign,
                  referralCount: referrals.length,
                  convertedCount: referrals
                      .where(
                        (record) => record.status == ReferralStatus.converted ||
                            record.status.rewardEligible,
                      )
                      .length,
                  rewardsCount: rewards.length,
                  eligibleCount: eligibleRewards.length,
                  claimedCount: claimHistory
                      .where((record) => record.status == ReferralStatus.rewardPaid)
                      .length,
                  upcomingCount: upcomingRewards.length,
                  eligibleAmount: eligibleAmount,
                  claimedAmount: claimedAmount,
                  upcomingAmount: upcomingAmount,
                  onStartReferral: () => _openReferralForm(context, user),
                  onOpenReferrals: () => _tabController.animateTo(1),
                  onOpenRewards: () => _tabController.animateTo(2),
                ),
                _ReferralsTab(
                  referrals: referrals,
                  onStartReferral: () => _openReferralForm(context, user),
                ),
                _RewardsTab(
                  rewards: rewards,
                  campaign: campaign,
                  eligibleRewards: eligibleRewards,
                  claimHistory: claimHistory,
                  upcomingRewards: upcomingRewards,
                ),
              ],
            ),
    );
  }

  Future<void> _openReferralForm(BuildContext context, dynamic user) async {
    final contactNameCtrl = TextEditingController();
    final businessNameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? submitError;

    final createdReferral = await showDialog<ReferralRecord?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Start Referral'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: contactNameCtrl,
                          decoration: const InputDecoration(labelText: 'Contact name'),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter contact name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: businessNameCtrl,
                          decoration: const InputDecoration(labelText: 'Business name'),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter business name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: mobileCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number (or email)',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                            final email = emailCtrl.text.trim();
                            if (digits.isEmpty && email.isEmpty) {
                              return 'Enter mobile number or email address';
                            }
                            if (digits.isNotEmpty && digits.length != 10) {
                              return 'Enter a valid 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email address'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            final digits =
                                mobileCtrl.text.replaceAll(RegExp(r'\D'), '');
                            if (text.isEmpty && digits.isEmpty) {
                              return 'Enter email address or mobile number';
                            }
                            if (text.isEmpty) return null;
                            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                                ? null
                                : 'Enter a valid email address';
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(labelText: 'Notes'),
                          maxLines: 3,
                        ),
                        if (submitError != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              submitError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            saving = true;
                            submitError = null;
                          });
                          try {
                            final referral =
                                await context.read<ReferralProgramService>().createReferral(
                              clientId: user.id,
                              clientName: user.firmName,
                              contactName: contactNameCtrl.text,
                              businessName: businessNameCtrl.text,
                              mobileNumber: mobileCtrl.text,
                              email: emailCtrl.text,
                              notes: notesCtrl.text,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext, referral);
                          } catch (error) {
                            setDialogState(() {
                              saving = false;
                              submitError = error.toString().replaceFirst('Invalid argument(s): ', '');
                            });
                          }
                        },
                  child: Text(saving ? 'Creating...' : 'Create Referral'),
                ),
              ],
            );
          },
        );
      },
    );

    contactNameCtrl.dispose();
    businessNameCtrl.dispose();
    mobileCtrl.dispose();
    emailCtrl.dispose();
    notesCtrl.dispose();

    if (createdReferral != null && mounted) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral created and sent for admin follow-up.')),
      );
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Registration Link Ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send this link to the referred customer for registration:',
              ),
              const SizedBox(height: 10),
              SelectableText(createdReferral.registrationLink),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: createdReferral.registrationLink),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registration link copied.')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy Link'),
            ),
          ],
        ),
      );
    }
  }
}

class _ReferralHero extends StatelessWidget {
  const _ReferralHero({required this.offer});

  final ReferralCampaign offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4FD9), Color(0xFF2A5DF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'New! ${offer.campaignName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Refer Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Get Rewarded!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Get ${offer.rewardAmountLabel} ${offer.yourAwardType} for every successful referral. Your contact also gets ${offer.rewardAmountLabel} ${offer.contactAwardType}.',
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Managed below'),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.campaign,
    required this.referralCount,
    required this.convertedCount,
    required this.rewardsCount,
    required this.eligibleCount,
    required this.claimedCount,
    required this.upcomingCount,
    required this.eligibleAmount,
    required this.claimedAmount,
    required this.upcomingAmount,
    required this.onStartReferral,
    required this.onOpenReferrals,
    required this.onOpenRewards,
  });

  final ReferralCampaign campaign;
  final int referralCount;
  final int convertedCount;
  final int rewardsCount;
  final int eligibleCount;
  final int claimedCount;
  final int upcomingCount;
  final int eligibleAmount;
  final int claimedAmount;
  final int upcomingAmount;
  final VoidCallback onStartReferral;
  final VoidCallback onOpenReferrals;
  final VoidCallback onOpenRewards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ReferralHero(offer: campaign),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _RewardTypeCard(
                title: 'Your Award Type',
                value: '${campaign.rewardAmountLabel} ${campaign.yourAwardType}',
                icon: Icons.card_giftcard_outlined,
                tint: const Color(0xFFDCEBFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RewardTypeCard(
                title: 'Contact Award Type',
                value: '${campaign.rewardAmountLabel} ${campaign.contactAwardType}',
                subtitle: campaign.contactAwardDetail,
                icon: Icons.redeem_outlined,
                tint: const Color(0xFFE4F8EE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total referrals',
                value: '$referralCount',
                color: const Color(0xFF1A4FD9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Successful',
                value: '$convertedCount',
                color: const Color(0xFF11895C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Reward entries',
                value: '$rewardsCount',
                color: const Color(0xFF8A4D00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Eligible rewards',
                value: '$eligibleCount / Rs. $eligibleAmount',
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Claimed rewards',
                value: '$claimedCount / Rs. $claimedAmount',
                color: const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Upcoming rewards',
                value: '$upcomingCount / Rs. $upcomingAmount',
                color: const Color(0xFFEF6C00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ActionTile(
          title: 'Start Referral',
          subtitle: 'Invite a business contact to join Chirag Accounting.',
          icon: Icons.send_outlined,
          onTap: onStartReferral,
        ),
        _ActionTile(
          title: 'My Referral List',
          subtitle: 'Track invited contacts and conversion status.',
          icon: Icons.list_alt_outlined,
          onTap: onOpenReferrals,
        ),
        _ActionTile(
          title: 'Reward History',
          subtitle: 'View approved awards and payout history.',
          icon: Icons.card_giftcard_outlined,
          onTap: onOpenRewards,
        ),
      ],
    );
  }
}

class _ReferralsTab extends StatelessWidget {
  const _ReferralsTab({
    required this.referrals,
    required this.onStartReferral,
  });

  final List<ReferralRecord> referrals;
  final VoidCallback onStartReferral;

  @override
  Widget build(BuildContext context) {
    if (referrals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_add_outlined, size: 48, color: Color(0xFF5F7188)),
              const SizedBox(height: 12),
              const Text('No referrals yet.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onStartReferral,
                icon: const Icon(Icons.add),
                label: const Text('Start Referral'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onStartReferral,
            icon: const Icon(Icons.add),
            label: const Text('New Referral'),
          ),
        ),
        const SizedBox(height: 12),
        ...referrals.map((record) => _ReferralRecordCard(record: record)),
      ],
    );
  }
}

class _RewardsTab extends StatelessWidget {
  const _RewardsTab({
    required this.rewards,
    required this.campaign,
    required this.eligibleRewards,
    required this.claimHistory,
    required this.upcomingRewards,
  });

  final List<ReferralRecord> rewards;
  final ReferralCampaign campaign;
  final List<ReferralRecord> eligibleRewards;
  final List<ReferralRecord> claimHistory;
  final List<ReferralRecord> upcomingRewards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _RewardSection(
          title: 'Eligible Rewards',
          emptyMessage:
              'No eligible rewards yet. Once admin approves a referral reward, it will appear here.',
          records: eligibleRewards,
          campaign: campaign,
          tint: const Color(0xFFE8F5E9),
          icon: Icons.verified_outlined,
        ),
        const SizedBox(height: 12),
        _RewardSection(
          title: 'Claim History',
          emptyMessage:
              'No claim history available yet. Paid and approved rewards will be listed here.',
          records: claimHistory,
          campaign: campaign,
          tint: const Color(0xFFEAF2FF),
          icon: Icons.history_outlined,
        ),
        const SizedBox(height: 12),
        _RewardSection(
          title: 'Upcoming Rewards',
          emptyMessage:
              'No upcoming rewards right now. Converted or progressing referrals will show here.',
          records: upcomingRewards,
          campaign: campaign,
          tint: const Color(0xFFFFF3E0),
          icon: Icons.schedule_outlined,
        ),
      ],
    );
  }
}

class _RewardSection extends StatelessWidget {
  const _RewardSection({
    required this.title,
    required this.emptyMessage,
    required this.records,
    required this.campaign,
    required this.tint,
    required this.icon,
  });

  final String title;
  final String emptyMessage;
  final List<ReferralRecord> records;
  final ReferralCampaign campaign;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: tint,
                child: Icon(icon, size: 18, color: const Color(0xFF1A4FD9)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(color: Color(0xFF5F7188)),
            )
          else
            ...records.map(
              (record) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tint,
                    child: Icon(icon, color: const Color(0xFF1A4FD9)),
                  ),
                  title: Text(record.contactName),
                  subtitle: Text(
                    '${record.businessName}\n${record.status.displayLabel} on ${DateFormat('dd MMM yyyy').format(record.updatedAt)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    'Rs. ${record.rewardAmount ?? campaign.rewardAmount}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardTypeCard extends StatelessWidget {
  const _RewardTypeCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1A4FD9)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: Color(0xFF5F7188), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF1A4FD9)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5F7188), fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _ReferralRecordCard extends StatelessWidget {
  const _ReferralRecordCard({required this.record});

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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(status: record.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(record.businessName, style: const TextStyle(color: Color(0xFF425466))),
            const SizedBox(height: 6),
            Text('Mobile: ${record.mobileNumber}'),
            if (record.email.trim().isNotEmpty) Text('Email: ${record.email}'),
            const SizedBox(height: 8),
            Text(
              'Created ${DateFormat('dd MMM yyyy, hh:mm a').format(record.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F7188)),
            ),
            Text(
              'Last update ${DateFormat('dd MMM yyyy, hh:mm a').format(record.updatedAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F7188)),
            ),
            if (record.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(record.notes),
            ],
            if (record.adminNote.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ReferralStatus status;

  @override
  Widget build(BuildContext context) {
    final background = switch (status) {
      ReferralStatus.invited => const Color(0xFFEAF2FF),
      ReferralStatus.contacted => const Color(0xFFEAF6FF),
      ReferralStatus.registered => const Color(0xFFF5EEFF),
      ReferralStatus.converted => const Color(0xFFE6F7EF),
      ReferralStatus.rewardApproved => const Color(0xFFFFF3D9),
      ReferralStatus.rewardPaid => const Color(0xFFDFF7E8),
      ReferralStatus.declined => const Color(0xFFFBE7E7),
    };
    final foreground = switch (status) {
      ReferralStatus.invited => const Color(0xFF1A4FD9),
      ReferralStatus.contacted => const Color(0xFF0B7285),
      ReferralStatus.registered => const Color(0xFF6C3EC1),
      ReferralStatus.converted => const Color(0xFF11895C),
      ReferralStatus.rewardApproved => const Color(0xFF8A4D00),
      ReferralStatus.rewardPaid => const Color(0xFF146C43),
      ReferralStatus.declined => const Color(0xFFB42318),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
