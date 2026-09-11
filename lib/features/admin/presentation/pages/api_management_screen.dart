import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/core/integrations/integration_adapter.dart';
import 'package:chirag_accounting/core/integrations/integration_hub_service.dart';

class ApiManagementScreen extends StatefulWidget {
  const ApiManagementScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ApiManagementScreen> createState() => _ApiManagementScreenState();
}

class _ApiManagementScreenState extends State<ApiManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = <String>[
    'API Dashboard',
    'API Keys',
    'API Usage',
    'API Billing',
    'Renewal Reminders',
    'Payment History',
    'Vendor Management',
    'Webhooks',
    'Error Logs',
    'Settings',
  ];

  static const _subscriptions = <_ApiSubscription>[
    _ApiSubscription('OCR API', '7 days', '₹2,500', 'Renew'),
    _ApiSubscription('OpenAI', 'Balance ₹950', 'Usage based', 'Top-up'),
    _ApiSubscription('GST API', '18 days', '₹1,800', 'View'),
    _ApiSubscription('SMS API', '1,240 credits', '₹0.18 / SMS', 'Recharge'),
    _ApiSubscription('WhatsApp API', '3 days', '₹1,499', 'Renew'),
  ];

  late final TabController _tabController;
  final Set<String> _visibleKeys = <String>{};
  bool _renewalAlerts = true;
  bool _errorAlerts = true;
  bool _usageLimits = true;
  bool _webhookRetries = true;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab.clamp(0, _tabs.length - 1);
    _tabController = TabController(
      length: _tabs.length,
      initialIndex: initialIndex,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('API Management'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh API health',
            onPressed: _refreshHealth,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((label) => Tab(text: label)).toList(growable: false),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _dashboard(),
          _apiKeys(),
          _apiUsage(),
          _apiBilling(),
          _renewals(),
          _paymentHistory(),
          _vendors(),
          _webhooks(),
          _errorLogs(),
          _settings(),
        ],
      ),
    );
  }

  Future<void> _refreshHealth() async {
    await context.read<IntegrationHubService>().refreshHealth();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API health refreshed.')));
  }

  Widget _dashboard() {
    final hub = context.watch<IntegrationHubService>();
    final liveCount = hub.healthByAdapter.values
        .where((health) => health.status.toUpperCase() == 'UP')
        .length;
    final alertCount = _subscriptions
        .where((item) => item.action == 'Renew' || item.action == 'Recharge')
        .length;

    return _page(
      children: [
        _sectionHeader(
          'API Control Center',
          'Live adapter health and configured subscription overview',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metric('Configured APIs', '${hub.adapters.length}', Icons.hub),
            _metric('Services Online', '$liveCount', Icons.cloud_done_outlined),
            _metric('Renewal Alerts', '$alertCount', Icons.event_repeat),
            _metric('Monthly API Cost', '₹7,299', Icons.payments_outlined),
            _metric('Credits Remaining', '1,240', Icons.data_usage_outlined),
            _metric('Pending Payments', '2', Icons.pending_actions_outlined),
          ],
        ),
        const SizedBox(height: 18),
        _sectionHeader(
          'Live Integration Health',
          'Updated from configured adapters',
        ),
        if (hub.adapters.isEmpty)
          const _EmptyState('No integration adapters are configured.')
        else
          ...hub.adapters.map((adapter) {
            final health = hub.healthByAdapter[adapter.id];
            return _healthRow(adapter.name, health);
          }),
        const SizedBox(height: 18),
        _sectionHeader(
          'API Subscription & Reminder',
          'Commercial values are configuration data until billing APIs are connected',
        ),
        _subscriptionTable(),
      ],
    );
  }

  Widget _apiKeys() {
    final hub = context.watch<IntegrationHubService>();
    return _page(
      children: [
        _sectionHeader(
          'API Keys',
          'Credentials are masked. Store production secrets in secure backend storage.',
        ),
        ...hub.adapters.map((adapter) {
          final visible = _visibleKeys.contains(adapter.id);
          return Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(adapter.name),
              subtitle: Text(
                visible
                    ? 'demo_${adapter.id}_key_not_configured'
                    : '••••••••••••••••',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: visible ? 'Hide key' : 'Show key',
                    onPressed: () => setState(() {
                      visible
                          ? _visibleKeys.remove(adapter.id)
                          : _visibleKeys.add(adapter.id);
                    }),
                    icon: Icon(
                      visible ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Configure key',
                    onPressed: () => _notConnected('Secure key configuration'),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _apiUsage() => _page(
    children: [
      _sectionHeader('API Usage', 'Current-cycle request and quota summary'),
      _dataTable(
        columns: const ['API', 'Requests', 'Success', 'Failed', 'Quota'],
        rows: const [
          ['GST API', '2,480', '2,431', '49', '62%'],
          ['OCR API', '1,146', '1,098', '48', '76%'],
          ['Bank API', '830', '817', '13', '41%'],
          ['WhatsApp API', '692', '681', '11', '58%'],
          ['Email API', '1,904', '1,887', '17', '38%'],
        ],
      ),
    ],
  );

  Widget _apiBilling() => _page(
    children: [
      _sectionHeader('API Billing', 'Monthly cost, plan, and payment status'),
      _subscriptionTable(),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => _notConnected('API payment gateway'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Review Pending Payments'),
        ),
      ),
    ],
  );

  Widget _renewals() => _page(
    children: [
      _sectionHeader(
        'Renewal Reminders',
        'Upcoming expiry and low-credit alerts',
      ),
      ..._subscriptions.map(
        (item) => Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(
              item.action == 'View'
                  ? Icons.check_circle_outline
                  : Icons.warning_amber,
              color: item.action == 'View'
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFEF6C00),
            ),
            title: Text(item.name),
            subtitle: Text('${item.expiry} • ${item.cost}'),
            trailing: OutlinedButton(
              onPressed: () =>
                  _notConnected('${item.name} ${item.action.toLowerCase()}'),
              child: Text(item.action),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _paymentHistory() => _page(
    children: [
      _sectionHeader('Payment History', 'Recorded API subscription payments'),
      _dataTable(
        columns: const ['Date', 'Vendor', 'Reference', 'Amount', 'Status'],
        rows: const [
          ['18 Jul 2026', 'OCR Cloud', 'API-260718-04', '₹2,500', 'Paid'],
          ['01 Jul 2026', 'GST Network', 'API-260701-11', '₹1,800', 'Paid'],
          ['28 Jun 2026', 'Meta', 'API-260628-08', '₹1,499', 'Paid'],
          ['20 Jun 2026', 'SMS Gateway', 'API-260620-17', '₹1,000', 'Paid'],
        ],
      ),
    ],
  );

  Widget _vendors() => _page(
    children: [
      _sectionHeader(
        'Vendor Management',
        'Provider ownership and support contacts',
      ),
      _dataTable(
        columns: const ['Vendor', 'Services', 'Contact', 'Agreement'],
        rows: const [
          [
            'GST Network Partner',
            'GST API',
            'api-support@gst.example',
            'Active',
          ],
          ['OCR Cloud', 'OCR API', 'support@ocr.example', 'Renewal due'],
          ['Meta BSP', 'WhatsApp API', 'support@bsp.example', 'Active'],
          ['Messaging Hub', 'SMS API', 'care@sms.example', 'Credits low'],
          ['Mail Provider', 'Email API', 'ops@mail.example', 'Active'],
        ],
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => _notConnected('Vendor creation'),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Add Vendor'),
        ),
      ),
    ],
  );

  Widget _webhooks() => _page(
    children: [
      _sectionHeader(
        'Webhooks',
        'Inbound and outbound event delivery endpoints',
      ),
      _dataTable(
        columns: const ['Event', 'Endpoint', 'Last Delivery', 'Status'],
        rows: const [
          ['invoice.processed', '/hooks/ocr', '2 min ago', 'Healthy'],
          ['gst.return.updated', '/hooks/gst', '18 min ago', 'Healthy'],
          ['payment.received', '/hooks/payment', '1 hr ago', 'Healthy'],
          ['message.delivered', '/hooks/message', '3 hr ago', 'Retrying'],
        ],
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => _notConnected('Webhook editor'),
          icon: const Icon(Icons.add_link),
          label: const Text('Add Webhook'),
        ),
      ),
    ],
  );

  Widget _errorLogs() => _page(
    children: [
      _sectionHeader('API Error Logs', 'Recent failed or degraded requests'),
      _dataTable(
        columns: const ['Time', 'API', 'Code', 'Message', 'State'],
        rows: const [
          ['10:42', 'OCR API', '429', 'Credit threshold reached', 'Open'],
          ['09:18', 'WhatsApp API', '408', 'Provider timeout', 'Retrying'],
          ['Yesterday', 'GST API', '401', 'Token refresh required', 'Resolved'],
          ['Yesterday', 'Bank API', '503', 'Provider maintenance', 'Resolved'],
        ],
      ),
    ],
  );

  Widget _settings() => _page(
    children: [
      _sectionHeader(
        'API Settings',
        'Monitoring, retry, and alert preferences',
      ),
      Card(
        elevation: 0,
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Renewal reminders'),
              subtitle: const Text(
                'Notify admins before expiry or low balance.',
              ),
              value: _renewalAlerts,
              onChanged: (value) => setState(() => _renewalAlerts = value),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('API error alerts'),
              subtitle: const Text(
                'Notify admins for degraded or failed integrations.',
              ),
              value: _errorAlerts,
              onChanged: (value) => setState(() => _errorAlerts = value),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Usage limit alerts'),
              subtitle: const Text(
                'Warn when a provider reaches 80% of quota.',
              ),
              value: _usageLimits,
              onChanged: (value) => setState(() => _usageLimits = value),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Automatic webhook retries'),
              subtitle: const Text('Retry failed deliveries with backoff.'),
              value: _webhookRetries,
              onChanged: (value) => setState(() => _webhookRetries = value),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _healthRow(String name, IntegrationHealth? health) {
    final status = health?.status.toUpperCase() ?? 'CHECKING';
    final healthy = status == 'UP';
    final color = healthy
        ? const Color(0xFF2E7D32)
        : status == 'CHECKING'
        ? const Color(0xFF455A64)
        : const Color(0xFFC62828);
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(
          healthy ? Icons.check_circle : Icons.error_outline,
          color: color,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(health?.message ?? 'Waiting for health check'),
        trailing: Text(
          health?.latencyMs == null
              ? status
              : '$status • ${health!.latencyMs} ms',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _subscriptionTable() => _dataTable(
    columns: const ['API', 'Expires / Balance', 'Cost', 'Action'],
    rows: _subscriptions
        .map((item) => [item.name, item.expiry, item.cost, item.action])
        .toList(growable: false),
  );

  Widget _page({required List<Widget> children}) =>
      ListView(padding: const EdgeInsets.all(16), children: children);

  Widget _sectionHeader(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Color(0xFF52627A))),
      ],
    ),
  );

  Widget _metric(String label, String value, IconData icon) => Container(
    width: 210,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD8E2F0)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF52627A)),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dataTable({
    required List<String> columns,
    required List<List<String>> rows,
  }) => Card(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map((label) => DataColumn(label: Text(label)))
            .toList(growable: false),
        rows: rows
            .map(
              (row) => DataRow(
                cells: row
                    .map((value) => DataCell(Text(value)))
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      ),
    ),
  );

  void _notConnected(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature requires backend provider configuration.'),
      ),
    );
  }
}

class _ApiSubscription {
  const _ApiSubscription(this.name, this.expiry, this.cost, this.action);

  final String name;
  final String expiry;
  final String cost;
  final String action;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: Text(message)),
  );
}
