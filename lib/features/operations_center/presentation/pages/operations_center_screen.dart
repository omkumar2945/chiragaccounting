import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/presentation/pages/login_screen.dart';
import 'package:chirag_accounting/features/clients/Profile/client_profile_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/clients/Uplads/client_uploads_screen.dart';
import 'package:chirag_accounting/features/customers/presentation/pages/customers_screen.dart';
import 'package:chirag_accounting/features/inbox/presentation/pages/universal_inbox_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/client_360_detail_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/my_work_queue_screen.dart';
import 'package:chirag_accounting/features/operations_center/presentation/pages/operations_metric_detail_screen.dart';
import 'package:chirag_accounting/features/operations_center/services/operations_center_service.dart';
import 'package:chirag_accounting/features/purchase/presentation/pages/purchase_screen.dart';
import 'package:chirag_accounting/features/sales/models/sales_invoice.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/sales_screen.dart';

class OperationsCenterScreen extends StatefulWidget {
  const OperationsCenterScreen({super.key});

  @override
  State<OperationsCenterScreen> createState() => _OperationsCenterScreenState();
}

class _OperationsCenterScreenState extends State<OperationsCenterScreen> {
  static const List<String> _tabs = <String>[
    'Overview',
    'Operations',
    'Clients',
    'Compliance',
    'Accounting',
    'Documents',
    'Tasks',
    'Assignments',
    'Queries',
    'Analytics',
    'AI Center',
    'Notifications',
    'System Health',
  ];

  static const List<String> _businessHealthKeys = <String>[
    'Clients',
    'Active Clients',
    'Inactive',
    'New This Month',
    'Suspended',
    'Monthly Revenue (L)',
    'Quarterly Revenue (L)',
    'Yearly Revenue (L)',
    'Outstanding (L)',
    'Recovery This Month (L)',
    'Bank Balance (L)',
    'Cash Flow Score',
    "Today's Tasks",
    'Completed Today',
  ];

  static const List<String> _operationsKeys = <String>[
    'Invoices Created',
    'Purchase Bills',
    'OCR Completed',
    'OCR Failed',
    'Pending Uploads',
    'Pending Verification',
    'Pending Approvals',
    'Pending Filing',
    'Today Collections (L)',
    'Today Payments (L)',
    'Today Queries',
    'Today Audit Tasks',
  ];

  static const List<String> _aiKeys = <String>[
    'OCR Queue',
    'Ai Classification',
    'Duplicate Detections',
    'Gst Mismatch Flags',
    'Ledger Suggestions',
    'Hsn Suggestions',
    'Missing Documents',
    'Compliance Prediction Alerts',
    'Risk Detections',
    'Fraud Alerts',
  ];

  static const List<String> _analyticsKeys = <String>[
    'Revenue Growth (%)',
    'Client Growth (%)',
    'OCR Accuracy (%)',
    'Automation Coverage (%)',
    'Avg Response Time (m)',
    'Outstanding (L)',
  ];

  static const List<String> _workflow = <String>[
    'Upload',
    'OCR',
    'Verification',
    'Ledger Suggestion',
    'Approval',
    'Accounting',
    'GST',
    'Reports',
    'Archive',
  ];

  static const List<String> _taskQueueKeys = <String>[
    'Pending OCR',
    'Waiting Client',
    'Waiting Accountant',
    'Waiting CA',
    'Waiting Auditor',
    'Waiting Approval',
    'Completed Today Queue',
    'Overdue',
    'Escalated',
  ];

  StreamSubscription<OperationsSnapshot>? _streamSub;
  bool _streamBannerVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<OperationsCenterService>();
      service.startStreaming();
      service.refreshNow();
      _streamSub = service.updates.listen((_) {
        if (!mounted) return;
        if (_streamBannerVisible) return;
        _streamBannerVisible = true;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Operations stream active: counters are now live.'),
              duration: Duration(milliseconds: 1300),
            ),
          );
      });
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<OperationsCenterService>();
    final snapshot = service.snapshot;
    final user = context.watch<AuthController>().currentUser;

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F6FF),
        appBar: AppBar(
          title: const Text('Chirag Associates - Firm Operating System'),
          backgroundColor: const Color(0xFF0A3A86),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Universal Search',
              icon: const Icon(Icons.search),
              onPressed: () => _openGlobalSearch(snapshot.metrics.keys.toList(growable: false)),
            ),
            PopupMenuButton<String>(
              tooltip: 'Account',
              onSelected: (value) => _handleProfileMenuAction(
                value,
                snapshot,
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'my-profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 10),
                      Text('My Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'change-password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Change Password'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'activity-log',
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18),
                      SizedBox(width: 10),
                      Text('Activity Log'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'help-support',
                  child: Row(
                    children: [
                      Icon(Icons.support_agent_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Help & Support'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        user?.name ?? 'User',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(growable: false),
          ),
        ),
        body: TabBarView(
          children: [
            _buildBusinessHealthTab(snapshot),
            _buildOperationsTab(snapshot),
            _buildClientsTab(service),
            _buildComplianceTab(snapshot),
            _buildAccountingTab(snapshot),
            _buildDocumentsTab(snapshot),
            _buildTasksTab(snapshot),
            _buildAssignmentsTab(snapshot),
            _buildQueriesTab(snapshot),
            _buildAnalyticsTab(snapshot),
            _buildAiTab(snapshot),
            _buildAlertsTab(snapshot),
            _buildSystemHealthTab(snapshot),
          ],
        ),
      ),
    );
  }

  void _openGlobalSearch(List<String> keys) {
    showSearch<void>(
      context: context,
      delegate: _OperationsSearchDelegate(keys),
    );
  }

  Future<void> _handleProfileMenuAction(
    String value,
    OperationsSnapshot snapshot,
  ) async {
    if (value == 'my-profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClientProfileScreen()),
      );
      return;
    }

    if (value == 'settings' || value == 'change-password') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClientSettingsScreen()),
      );
      return;
    }

    if (value == 'activity-log') {
      _showActivityLog(snapshot.timeline);
      return;
    }

    if (value == 'help-support') {
      _showHelpAndSupport();
      return;
    }

    if (value == 'logout') {
      await _logout();
    }
  }

  void _showActivityLog(List<OperationTimelineEvent> timeline) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Activity Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: timeline.isEmpty
                    ? const Center(
                        child: Text(
                          'No activity available yet.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: timeline.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final event = timeline[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.timeline, size: 20),
                            title: Text(event.title),
                            subtitle: Text(
                              '${event.detail}\n${event.clientName} • ${event.source}',
                            ),
                            isThreeLine: true,
                            trailing: Text(_formatTime(event.timestamp)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpAndSupport() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need assistance with the admin panel?'),
            SizedBox(height: 12),
            Text('Support Email: support@chiragca.com'),
            Text('Support Phone: +91 98765 43210'),
            SizedBox(height: 8),
            Text('Availability: Mon-Sat, 10:00 AM - 7:00 PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthController>().logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildBusinessHealthTab(OperationsSnapshot snapshot) {
    return RefreshIndicator(
      onRefresh: () => context.read<OperationsCenterService>().refreshNow(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Mission Control'),
          _missionRibbon(snapshot),
          const SizedBox(height: 12),
          _sectionTitle('Business Health'),
          _metricGrid(snapshot, _businessHealthKeys),
          const SizedBox(height: 14),
          _sectionTitle('Client 360'),
          _client360Card(),
          const SizedBox(height: 14),
          _sectionTitle('Workflow Engine'),
          _workflowTrack(),
        ],
      ),
    );
  }

  Widget _buildOperationsTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle("Today's Operations"),
        _metricGrid(snapshot, _operationsKeys),
        const SizedBox(height: 14),
        _listCard(
          title: 'Assignment Center',
          lines: const <String>[
            'Client Assignment, Document Assignment, Audit Assignment, GST Assignment, IT Assignment, Payroll Assignment, ROC Assignment, Review Assignment, Approval Assignment',
            'Each assignment includes Assigned By, Assigned To, Priority, Deadline, Expected Hours, Completion, Remarks, Files, Communication.',
          ],
        ),
      ],
    );
  }

  Widget _buildComplianceTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Compliance Control Tower'),
        _metricGrid(snapshot, const <String>[
          'GST Returns Due',
          'Income Tax Due',
          'ROC Due',
          'TDS Returns',
          'TCS Returns',
          'Audit Pending',
          'Books Pending',
          'Bank Reconciliation',
          'Pending Filing',
        ]),
        const SizedBox(height: 14),
        _listCard(
          title: 'Compliance Scope',
          lines: const <String>[
            'GST, Income Tax, ROC, PF, ESI, Professional Tax, Labour, MSME, Factory, Trade License, FSSAI',
            'Track status: Pending, Completed, Delayed, Notice, Penalty, Responsible, Files, Remarks',
          ],
        ),
      ],
    );
  }

  Widget _buildAccountingTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Accounting Command View'),
        _metricGrid(snapshot, const <String>[
          'Invoices Created',
          'Purchase Bills',
          'Outstanding (L)',
          'Today Collections (L)',
          'Today Payments (L)',
          'Pending Approvals',
          'Completed Today',
        ]),
        const SizedBox(height: 14),
        _workflowTrack(),
      ],
    );
  }

  Widget _buildDocumentsTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Document Intelligence'),
        _metricGrid(snapshot, const <String>[
          'OCR Completed',
          'OCR Failed',
          'OCR Queue',
          'Missing Documents',
          'Hsn Suggestions',
          'Ledger Suggestions',
        ]),
        const SizedBox(height: 14),
        _listCard(
          title: 'Document Classes',
          lines: const <String>[
            'Invoices, Purchase Bills, GST, Audit, Legal, Payroll, ROC, IT, Bank, Agreements, Other',
            'Each file tracks OCR, AI Summary, Assigned, Verified, Approved, History and Versions.',
          ],
        ),
      ],
    );
  }

  Widget _buildTasksTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Universal Task Engine'),
        _metricGrid(snapshot, _taskQueueKeys),
        const SizedBox(height: 14),
        _listCard(
          title: 'Task Lifecycle',
          lines: const <String>[
            'Draft -> Submitted -> Verified -> Approved -> Completed -> Archived',
            'Applies to Sales, Purchase, GST, Audit, Uploads, Queries, Documents and Payroll.',
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentsTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Smart Assignment Engine'),
        _listCard(
          title: 'Assignable Work',
          lines: const <String>[
            'Client, Compliance, GST, IT, Payroll, Audit, Review, Document, Query, Notice',
            'Each assignment tracks Owner, Reviewer, Due Date, SLA and Status.',
          ],
        ),
        const SizedBox(height: 14),
        _metricGrid(snapshot, const <String>[
          'Waiting Accountant',
          'Waiting CA',
          'Waiting Auditor',
          'Waiting Approval',
          'Overdue',
          'Escalated',
        ]),
      ],
    );
  }

  Widget _buildQueriesTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Query Center'),
        _metricGrid(snapshot, const <String>[
          'Outstanding Queries',
          'Unread Client Messages',
          'Pending Approvals',
          'Today Queries',
        ]),
        const SizedBox(height: 14),
        _listCard(
          title: 'Query Buckets',
          lines: const <String>[
            'Open, In Progress, Waiting, Resolved, Escalated, Closed',
            'Sources: Client, Internal Team, Government, Vendor',
          ],
        ),
      ],
    );
  }

  Widget _buildClientsTab(OperationsCenterService service) {
    final clients = service.knownClientNames;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Client Portfolio and Practice Management'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            Chip(label: Text('By Accountant')),
            Chip(label: Text('By CA')),
            Chip(label: Text('By Auditor')),
            Chip(label: Text('By Industry')),
            Chip(label: Text('By Turnover')),
            Chip(label: Text('By GST Status')),
            Chip(label: Text('By Risk')),
            Chip(label: Text('By State')),
            Chip(label: Text('By Partner')),
            Chip(label: Text('By Branch')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Client 360 List', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (clients.isEmpty)
                  const Text('No client records available yet.')
                else
                  ...clients.take(20).map(
                        (name) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.business_outlined),
                          title: Text(name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Client360DetailScreen(clientName: name),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('AI Command Center'),
        _metricGrid(snapshot, _aiKeys),
        const SizedBox(height: 14),
        _listCard(
          title: 'AI Work Engine',
          lines: const <String>[
            'OCR Queue, AI Classification, Duplicate Detection, GST Mismatch, Ledger Suggestions, HSN Suggestions, Missing Documents, Compliance Prediction, Risk Detection, Fraud Alerts.',
            'Use these counters to prioritize daily work and auto follow-up suggestions.',
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Analytics and BI'),
        _metricGrid(snapshot, _analyticsKeys),
        const SizedBox(height: 14),
        _listCard(
          title: 'Drilldown Tracks',
          lines: const <String>[
            'Revenue, Client Growth, Employee Productivity, Compliance, OCR Accuracy, Response Time, Recovery, Outstanding, Profitability, Industry Mix',
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Alerts, Query Center, Communication Center'),
        _metricGrid(snapshot, const <String>[
          'Outstanding Queries',
          'Unread Client Messages',
          'System Errors',
          'Fraud Alerts',
          'Risk Detections',
        ]),
        const SizedBox(height: 14),
        _listCard(
          title: 'Query and Communication',
          lines: const <String>[
            'Query sources: Client, Internal Team, Government, Vendor',
            'Status buckets: Open, In Progress, Waiting, Resolved, Escalated, Closed',
            'Communication channels: Chat, Email, SMS, Notifications, Announcements, Internal Notes, Voice Notes',
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UniversalInboxScreen()),
            );
          },
          icon: const Icon(Icons.inbox_outlined),
          label: const Text('Open Universal Inbox'),
        ),
      ],
    );
  }

  Widget _buildSystemHealthTab(OperationsSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('System Health'),
        _missionRibbon(snapshot),
        const SizedBox(height: 14),
        _metricGrid(snapshot, const <String>[
          'System Errors',
          'Background Jobs',
          'OCR Queue',
          'Pending Filing',
          'Overdue',
          'Escalated',
        ]),
      ],
    );
  }

  Widget _missionRibbon(OperationsSnapshot snapshot) {
    final missionEntries = snapshot.mission.entries.toList(growable: false);
    if (missionEntries.isEmpty) {
      return const SizedBox(
        height: 94,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: missionEntries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = missionEntries[i];
          final color = _missionColor(item.value);
          return InkWell(
            onTap: () => _openMissionDrilldown(item.key, item.value, snapshot),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: 132,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.key, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _metricGrid(OperationsSnapshot snapshot, List<String> keys) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2,
      ),
      itemBuilder: (_, index) {
        final key = keys[index];
        final value = _metricValue(snapshot, key);
        final valueText = value is int || value == value.roundToDouble()
            ? value.round().toString()
            : value.toStringAsFixed(2);
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openMetricDrilldown(key, valueText, snapshot),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    key,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    valueText,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _client360Card() {
    final service = context.watch<OperationsCenterService>();
    final firstClient = service.knownClientNames.isEmpty ? null : service.knownClientNames.first;

    return Card(
      child: ListTile(
        title: Text(firstClient == null ? 'Client 360' : 'Client 360 - $firstClient'),
        subtitle: const Text('Open dedicated Client 360 with full timeline feed and scorecards.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: firstClient == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Client360DetailScreen(clientName: firstClient),
                  ),
                );
              },
      ),
    );
  }

  Widget _workflowTrack() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _workflow
              .map(
                (step) => ActionChip(
                  label: Text(step),
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Workflow stage selected: $step'),
                          duration: const Duration(milliseconds: 1000),
                        ),
                      );
                  },
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _listCard({required String title, required List<String> lines}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...lines.map((line) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _metricValue(OperationsSnapshot snapshot, String key) {
    return (snapshot.metrics[key] ?? 0).toDouble();
  }

  Color _missionColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('down') || normalized.contains('error')) {
      return Colors.red;
    }
    if (normalized.contains('delay') || normalized.contains('queue') || normalized.contains('pending')) {
      return Colors.orange;
    }
    if (normalized.contains('up') || normalized.contains('live') || normalized.contains('healthy') || normalized.contains('stream')) {
      return Colors.green;
    }
    return Colors.blue;
  }

  void _openMissionDrilldown(String key, String value, OperationsSnapshot snapshot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OperationsMetricDetailScreen(
          metricTitle: key,
          value: value,
          events: snapshot.timeline.take(40).toList(growable: false),
        ),
      ),
    );
  }

  void _openMetricDrilldown(String key, String value, OperationsSnapshot snapshot) {
    switch (key) {
      case 'Clients':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomersScreen()),
        );
        return;
      case 'Active Clients':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CustomersScreen(activeFilter: true),
          ),
        );
        return;
      case 'Inactive':
      case 'Suspended':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CustomersScreen(activeFilter: false),
          ),
        );
        return;
      case 'Invoices Created':
      case 'Monthly Revenue (L)':
      case 'Quarterly Revenue (L)':
      case 'Yearly Revenue (L)':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesScreen()),
        );
        return;
      case 'Pending Approvals':
      case 'Pending Filing':
      case 'Outstanding (L)':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SalesScreen(initialStatus: InvoiceStatus.pending),
          ),
        );
        return;
      case 'Purchase Bills':
      case 'Today Payments (L)':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PurchaseScreen()),
        );
        return;
      case 'OCR Completed':
      case 'OCR Failed':
      case 'OCR Queue':
      case 'Pending Uploads':
      case 'Pending Verification':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientUploadsScreen(),
          ),
        );
        return;
      case 'Pending OCR':
      case 'Waiting Client':
      case 'Waiting Accountant':
      case 'Waiting CA':
      case 'Waiting Auditor':
      case 'Waiting Approval':
      case 'Completed Today Queue':
      case 'Overdue':
      case 'Escalated':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyWorkQueueScreen()),
        );
        return;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OperationsMetricDetailScreen(
              metricTitle: key,
              value: value,
              events: snapshot.timeline.take(50).toList(growable: false),
            ),
          ),
        );
    }
  }
}

class _OperationsSearchDelegate extends SearchDelegate<void> {
  _OperationsSearchDelegate(this._items);

  final List<String> _items;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _resultList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _resultList(context);
  }

  Widget _resultList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final results = q.isEmpty
        ? _items
        : _items.where((item) => item.toLowerCase().contains(q)).toList(growable: false);

    if (results.isEmpty) {
      return const Center(child: Text('No matching result found.'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) {
        final item = results[i];
        return ListTile(
          title: Text(item),
          trailing: const Icon(Icons.search),
          onTap: () => close(context, null),
        );
      },
    );
  }
}
