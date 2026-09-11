import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/services/client_profile_service.dart';
import 'package:chirag_accounting/features/clients/services/gst_returns_service.dart';
import 'package:chirag_accounting/features/services/gst_portal_lookup_service.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';

class ClientGstScreen extends StatefulWidget {
  const ClientGstScreen({super.key});

  @override
  State<ClientGstScreen> createState() => _ClientGstScreenState();
}

class _ClientGstScreenState extends State<ClientGstScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ClientProfileService _profileService = ClientProfileService();
  final GstPortalLookupService _gstLookupService = GstPortalLookupService();
  final GstReturnsService _gstReturnsService = GstReturnsService();

  static const List<_GstReturnItem> _returnStatus = [
    _GstReturnItem(
      title: 'GSTR-1',
      subtitle: 'Outward supplies and invoice summary',
      status: 'Pending',
      dueDate: '11th of next month',
      color: Color(0xFF1565C0),
    ),
    _GstReturnItem(
      title: 'GSTR-3B',
      subtitle: 'Monthly tax liability and ITC summary',
      status: 'Pending',
      dueDate: '20th of next month',
      color: Color(0xFF0D47A1),
    ),
    _GstReturnItem(
      title: 'GSTR-2B Matching',
      subtitle: 'Purchase matching and input tax review',
      status: 'Review Needed',
      dueDate: 'Before filing',
      color: Color(0xFF00897B),
    ),
  ];

  final List<String> _gstinOptions = <String>[];
  String? _selectedGstin;
  bool _loadingGstin = true;
  bool _loadingProfile = false;
  GstTaxpayerProfile? _taxpayerProfile;

  @override
  void initState() {
    super.initState();
    _loadClientGstins();
  }

  Future<void> _loadClientGstins() async {
    final user = context.read<AuthController>().currentUser;
    final profile = user == null ? null : await _profileService.load(user.id);

    final fromProfile = (profile?.gstin ?? '').trim().toUpperCase();
    final options = <String>[];
    if (fromProfile.isNotEmpty) {
      options.add(fromProfile);
    }

    if (options.isEmpty) {
      options.addAll(<String>[
        '27ABCDE1234F1Z5',
        '24AAACS1234D1Z2',
      ]);
    }

    setState(() {
      _gstinOptions
        ..clear()
        ..addAll(options.toSet().toList());
      _selectedGstin = _gstinOptions.first;
      _loadingGstin = false;
    });

    await _fetchTaxpayerProfile();
  }

  Future<void> _fetchTaxpayerProfile() async {
    final gstin = _selectedGstin;
    if (gstin == null || gstin.isEmpty) return;

    setState(() {
      _loadingProfile = true;
    });

    final result = await _gstLookupService.fetchTaxpayerByGstin(gstin);
    if (!mounted) return;

    setState(() {
      _taxpayerProfile = result.profile;
      _loadingProfile = false;
    });
  }

  Future<void> _showModuleDialog({
    required String title,
    required Widget child,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final screen = MediaQuery.sizeOf(context);
        final width = screen.width < 700 ? screen.width - 28 : 620.0;
        final height = screen.height < 760 ? screen.height - 64 : 620.0;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openApiModuleDialog({
    required String title,
    required Future<GstModuleApiResult> Function(String gstin, String clientId)
        loader,
  }) async {
    final gstin = (_selectedGstin ?? '').trim().toUpperCase();
    final user = context.read<AuthController>().currentUser;

    await _showModuleDialog(
      title: title,
      child: _GstApiModuleContent(
        load: () => loader(gstin, user?.id ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;

    final modules = <_GstDashboardModule>[
      _GstDashboardModule(
        title: 'Taxpayer Profile',
        subtitle: 'View legal name, trade name and GST status',
        icon: Icons.account_box_outlined,
        color: const Color(0xFF1565C0),
        onTap: () {
          _showModuleDialog(
            title: 'Taxpayer Profile',
            child: _buildTaxpayerProfileCard(),
          );
        },
      ),
      _GstDashboardModule(
        title: 'GSTR-1',
        subtitle: 'Outward supply invoices and summary upload',
        icon: Icons.upload_file_outlined,
        color: const Color(0xFF0D47A1),
        onTap: () {
          _openApiModuleDialog(
            title: 'GSTR-1',
            loader: (gstin, clientId) =>
                _gstReturnsService.fetchGstr1(gstin: gstin, clientId: clientId),
          );
        },
      ),
      _GstDashboardModule(
        title: 'GSTR-3B',
        subtitle: 'Tax liability, ITC and monthly return filing',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF1E88E5),
        onTap: () {
          _openApiModuleDialog(
            title: 'GSTR-3B',
            loader: (gstin, clientId) =>
                _gstReturnsService.fetchGstr3b(gstin: gstin, clientId: clientId),
          );
        },
      ),
      _GstDashboardModule(
        title: 'GSTR-2B Matching',
        subtitle: 'Match purchase register with 2B ITC',
        icon: Icons.compare_arrows_outlined,
        color: const Color(0xFF00897B),
        onTap: () {
          _openApiModuleDialog(
            title: 'GSTR-2B Matching',
            loader: (gstin, clientId) => _gstReturnsService.fetchGstr2bMatching(
              gstin: gstin,
              clientId: clientId,
            ),
          );
        },
      ),
      _GstDashboardModule(
        title: 'Return Status',
        subtitle: 'Track filing status, due dates and pending actions',
        icon: Icons.track_changes_outlined,
        color: const Color(0xFF6A1B9A),
        onTap: () {
          _openApiModuleDialog(
            title: 'Return Status',
            loader: (gstin, clientId) => _gstReturnsService.fetchReturnStatus(
              gstin: gstin,
              clientId: clientId,
            ),
          );
        },
      ),
      _GstDashboardModule(
        title: 'GST Analytics',
        subtitle: 'Monthly trends, tax outflow and ITC analysis',
        icon: Icons.analytics_outlined,
        color: const Color(0xFFEF6C00),
        onTap: () {
          _openApiModuleDialog(
            title: 'GST Analytics',
            loader: (gstin, clientId) =>
                _gstReturnsService.fetchAnalytics(gstin: gstin, clientId: clientId),
          );
        },
      ),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      key: _scaffoldKey,
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: _gstNavigation(modules, closeDrawer: true),
              ),
            ),
      appBar: AppBar(
        title: const Text('GST Dashboard'),
        leading: wide
            ? null
            : IconButton(
                tooltip: 'Open GST modules',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
      ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 236,
              child: _gstNavigation(modules, closeDrawer: false),
            ),
          Expanded(
            child: ListView(
              key: const ValueKey('gst-dashboard-scroll'),
              padding: EdgeInsets.all(wide ? 16 : 12),
              children: [
                Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF0E4C92), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0E4C92).withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Client GST Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Track profile, return filing, matching and analytics in one place.',
                  style: TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Client: ${user?.name ?? 'Client'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_loadingGstin)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else
            SearchableDropdownFormField<String>(
              value: _selectedGstin,
              decoration: const InputDecoration(
                labelText: 'Select GSTIN',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _gstinOptions,
              itemLabelBuilder: (gstin) => gstin,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedGstin = value);
                _fetchTaxpayerProfile();
              },
            ),
          const SizedBox(height: 16),
          const Text(
            'Quick Return Snapshot',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ..._returnStatus.map((item) => _GstStatusCard(item: item)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gstNavigation(
    List<_GstDashboardModule> modules, {
    required bool closeDrawer,
  }) {
    return ColoredBox(
      color: const Color(0xFF102A43),
      child: ListView(
        key: const ValueKey('gst-module-menu'),
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 20),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Text(
              'GST MODULES',
              style: TextStyle(
                color: Color(0xFF9FB3C8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: ListTile(
                key: ValueKey(
                  'gst-module-${module.title.toLowerCase().replaceAll(' ', '-')}',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                leading: Icon(module.icon, color: const Color(0xFFB8C7DB)),
                title: Text(
                  module.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  if (closeDrawer) await Navigator.of(context).maybePop();
                  if (mounted) module.onTap();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaxpayerProfileCard() {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = _taxpayerProfile;
    if (profile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile could not be fetched from GST portal.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('GSTIN: ${_selectedGstin ?? '-'}'),
          const SizedBox(height: 12),
          const Text(
            'You can continue with return modules. Profile sync may require active GST portal session/network access.',
          ),
        ],
      );
    }

    return ListView(
      children: [
        _kv('GSTIN', profile.gstin),
        _kv('Legal Name', profile.legalName.isEmpty ? '-' : profile.legalName),
        _kv('Trade Name', profile.tradeName.isEmpty ? '-' : profile.tradeName),
        _kv('Status', profile.status.isEmpty ? '-' : profile.status),
        _kv('State', profile.state.isEmpty ? '-' : profile.state),
        _kv('Pincode', profile.pincode.isEmpty ? '-' : profile.pincode),
        _kv('Email', profile.email.isEmpty ? '-' : profile.email),
        _kv('Mobile', profile.mobile.isEmpty ? '-' : profile.mobile),
        _kv('Address', profile.address.isEmpty ? '-' : profile.address),
      ],
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _GstDashboardModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GstDashboardModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _GstReturnItem {
  final String title;
  final String subtitle;
  final String status;
  final String dueDate;
  final Color color;

  const _GstReturnItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.dueDate,
    required this.color,
  });
}

class _GstStatusCard extends StatelessWidget {
  final _GstReturnItem item;

  const _GstStatusCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.color.withValues(alpha: 0.12),
          child: Icon(Icons.receipt_long_outlined, color: item.color),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${item.subtitle}\nDue: ${item.dueDate}'),
        isThreeLine: true,
        trailing: Chip(
          label: Text(item.status),
          backgroundColor: item.color.withValues(alpha: 0.10),
          labelStyle: TextStyle(color: item.color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GstApiModuleContent extends StatefulWidget {
  final Future<GstModuleApiResult> Function() load;

  const _GstApiModuleContent({required this.load});

  @override
  State<_GstApiModuleContent> createState() => _GstApiModuleContentState();
}

class _GstApiModuleContentState extends State<_GstApiModuleContent> {
  late Future<GstModuleApiResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _reload() {
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GstModuleApiResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _GstErrorView(
            message: 'Failed to load data. Please try again.',
            onRetry: _reload,
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return _GstErrorView(
            message: 'No data returned from server.',
            onRetry: _reload,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.message,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: _reload,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (result.hasError)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6, bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF4B4B4)),
                ),
                child: Text(
                  result.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB71C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  if (result.kpis.isNotEmpty) ...[
                    const Text(
                      'Summary',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: result.kpis
                          .map((kpi) => _GstKpiTile(kpi: kpi))
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (result.records.isNotEmpty) ...[
                    const Text(
                      'Records',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...result.records
                        .map((record) => _GstApiRecordCard(record: record)),
                  ],
                  if (result.kpis.isEmpty && result.records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'No records available for selected GSTIN and period.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Last synced: ${_formatDateTime(result.fetchedAt)}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}-${two(value.month)}-${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _GstKpiTile extends StatelessWidget {
  final GstModuleKpi kpi;

  const _GstKpiTile({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final tileWidth = MediaQuery.sizeOf(context).width < 420 ? 146.0 : 170.0;
    return Container(
      width: tileWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kpi.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kpi.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _GstApiRecordCard extends StatelessWidget {
  final GstModuleRecord record;

  const _GstApiRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (record.status != null && record.status!.trim().isNotEmpty) {
      chips.add(
        Chip(
          label: Text(record.status!),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (record.amount != null && record.amount!.trim().isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Amount: ${record.amount!}'),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (record.dueDate != null && record.dueDate!.trim().isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Due: ${record.dueDate!}'),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(record.subtitle),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: chips),
            ],
          ],
        ),
      ),
    );
  }
}

class _GstErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _GstErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}