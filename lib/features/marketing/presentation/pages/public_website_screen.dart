import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chirag_accounting/features/authentication/presentation/pages/login_screen.dart';
import 'package:chirag_accounting/features/authentication/presentation/pages/register_screen.dart';
import 'package:chirag_accounting/features/marketing/services/marketing_service.dart';
import 'package:chirag_accounting/features/marketing/services/download_center_service.dart';

enum _PublicSection {
  about,
  features,
  solutions,
  howItWorks,
  testimonials,
  pricing,
  downloads,
  support,
  contact,
}

class PublicWebsiteScreen extends StatefulWidget {
  const PublicWebsiteScreen({super.key});

  @override
  State<PublicWebsiteScreen> createState() => _PublicWebsiteScreenState();
}

class _PublicWebsiteScreenState extends State<PublicWebsiteScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<_PublicSection, GlobalKey> _sectionKeys = {
    for (final section in _PublicSection.values) section: GlobalKey(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(_PublicSection section) async {
    final target = _sectionKeys[section]?.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: .04,
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(initialMode: StaffLoginMode.client),
      ),
    );
  }

  void _openSignUp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1040;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 68,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF032D60),
        surfaceTintColor: Colors.white,
        titleSpacing: wide ? 28 : 8,
        title: _Brand(dark: true, compact: !wide),
        actions: [
          if (wide) ...[
            _NavLink(
              label: 'About',
              onTap: () => _scrollTo(_PublicSection.about),
            ),
            _NavLink(
              label: 'Features',
              onTap: () => _scrollTo(_PublicSection.features),
            ),
            _NavLink(
              label: 'Solutions',
              onTap: () => _scrollTo(_PublicSection.solutions),
            ),
            _NavLink(
              label: 'How It Works',
              onTap: () => _scrollTo(_PublicSection.howItWorks),
            ),
            _NavLink(
              label: 'Testimonials',
              onTap: () => _scrollTo(_PublicSection.testimonials),
            ),
            _NavLink(
              label: 'Pricing',
              onTap: () => _scrollTo(_PublicSection.pricing),
            ),
            _NavLink(
              label: 'Download Center',
              onTap: () => _scrollTo(_PublicSection.downloads),
            ),
            _NavLink(
              label: 'Support',
              onTap: () => _scrollTo(_PublicSection.support),
            ),
            _NavLink(
              label: 'Contact',
              onTap: () => _scrollTo(_PublicSection.contact),
            ),
          ],
          TextButton(onPressed: _openLogin, child: const Text('Login')),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton(
              onPressed: _openSignUp,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0176D3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(wide ? 'Try for free' : 'Try free'),
            ),
          ),
        ],
      ),
      drawer: wide ? null : _mobileDrawer(),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _ProductRibbon(onTap: _openSignUp),
            _Hero(onLogin: _openLogin, onSignUp: _openSignUp),
            const _TrustStrip(),
            _EcosystemSection(key: _sectionKeys[_PublicSection.about]),
            const _UniversalBusinessTemplateSection(),
            _RoleSection(
              key: _sectionKeys[_PublicSection.solutions],
              onExplore: () => _scrollTo(_PublicSection.howItWorks),
            ),
            _WorkflowSection(key: _sectionKeys[_PublicSection.howItWorks]),
            _FeatureSection(key: _sectionKeys[_PublicSection.features]),
            const _OcrShowcase(),
            const _BusinessOwnerShowcase(),
            const _PerformanceShowcase(),
            const _CollaborationSection(),
            _TestimonialsSection(
              key: _sectionKeys[_PublicSection.testimonials],
            ),
            const _WhyAndTrustSection(),
            _PricingSection(
              key: _sectionKeys[_PublicSection.pricing],
              onSignUp: _openSignUp,
              onLogin: _openLogin,
            ),
            _DownloadCenterSection(
              key: _sectionKeys[_PublicSection.downloads],
              onOpenWebFallback: _openLogin,
            ),
            _SupportSection(key: _sectionKeys[_PublicSection.support]),
            _FinalCta(
              key: _sectionKeys[_PublicSection.contact],
              onSignUp: _openSignUp,
              onLogin: _openLogin,
            ),
            _Footer(onOpenDownloads: () => _scrollTo(_PublicSection.downloads)),
          ],
        ),
      ),
    );
  }

  Widget _mobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: _Brand(dark: true),
            ),
            const Divider(),
            for (final entry in const <(_PublicSection, String)>[
              (_PublicSection.about, 'About'),
              (_PublicSection.features, 'Features'),
              (_PublicSection.solutions, 'Solutions'),
              (_PublicSection.howItWorks, 'How It Works'),
              (_PublicSection.testimonials, 'Testimonials'),
              (_PublicSection.pricing, 'Pricing'),
              (_PublicSection.downloads, 'Download Center'),
              (_PublicSection.support, 'Support'),
              (_PublicSection.contact, 'Contact'),
            ])
              ListTile(
                title: Text(entry.$2),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.pop(context);
                  _scrollTo(entry.$1);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.dark = false, this.compact = false});
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? const Color(0xFF102A43) : Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Color(0xFF1864D6),
            size: 20,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chirag Accounting',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Smart Accounting. Better Business.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: .68),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onLogin, required this.onSignUp});
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF1FAFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: _Bounded(
        padding: const EdgeInsets.fromLTRB(22, 54, 22, 52),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Eyebrow(
                  icon: Icons.auto_graph_rounded,
                  text: 'THE CONNECTED FINANCE PLATFORM',
                ),
                const SizedBox(height: 20),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Grow with a clear\n'),
                      TextSpan(
                        text: 'view of your business.',
                        style: TextStyle(color: Color(0xFF0176D3)),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: Color(0xFF032D60),
                    fontSize: 48,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bring accounting, GST, documents and team workflows into one intelligent workspace. Make every financial decision with confidence.',
                  style: TextStyle(
                    color: Color(0xFF42526E),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _CheckLabel('GST-ready workflows'),
                    _CheckLabel('OCR processing'),
                    _CheckLabel('Role-based access'),
                    _CheckLabel('CA connected'),
                  ],
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onSignUp,
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: const Text('Start your free trial'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0176D3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onLogin,
                      icon: const Icon(Icons.login_rounded, size: 17),
                      label: const Text('Login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0176D3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        side: const BorderSide(color: Color(0xFF0176D3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
            final visual = const _HeroDashboard();
            if (constraints.maxWidth < 820) {
              return Column(
                children: [copy, const SizedBox(height: 30), visual],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: 46),
                const Expanded(flex: 6, child: _HeroDashboard()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroDashboard extends StatelessWidget {
  const _HeroDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC9E4F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F032D60),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Business Overview',
                  style: TextStyle(
                    color: Color(0xFF032D60),
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              _Pill('LIVE WORKSPACE'),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _DashboardMetric(
                    'Sales',
                    Icons.trending_up,
                    Color(0xFF12A875),
                  ),
                  _DashboardMetric(
                    'Purchase',
                    Icons.shopping_bag_outlined,
                    Color(0xFFF59E0B),
                  ),
                  _DashboardMetric(
                    'Profit',
                    Icons.insights_outlined,
                    Color(0xFF4F46E5),
                  ),
                  _DashboardMetric(
                    'GST',
                    Icons.verified_outlined,
                    Color(0xFF0EA5A4),
                  ),
                  _DashboardMetric(
                    'Banking',
                    Icons.account_balance_outlined,
                    Color(0xFF2563EB),
                  ),
                  _DashboardMetric(
                    'Documents',
                    Icons.file_copy_outlined,
                    Color(0xFFDB2777),
                  ),
                ].map((item) => SizedBox(width: width, child: item)).toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            height: 116,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const CustomPaint(
              painter: _MarketingChartPainter(),
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .14)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Connected',
                style: TextStyle(color: Color(0xFF7C8AA0), fontSize: 8),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();
  @override
  Widget build(BuildContext context) => _Bounded(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: const [
        _TrustBadge(Icons.calculate_outlined, 'Accounting', Color(0xFF2563EB)),
        _TrustBadge(
          Icons.receipt_long_outlined,
          'GST Ready',
          Color(0xFFF59E0B),
        ),
        _TrustBadge(
          Icons.account_balance_outlined,
          'Banking',
          Color(0xFF0EA5A4),
        ),
        _TrustBadge(Icons.document_scanner_outlined, 'OCR', Color(0xFF7C3AED)),
        _TrustBadge(
          Icons.security_outlined,
          'Controlled Access',
          Color(0xFF16A673),
        ),
        _TrustBadge(Icons.groups_outlined, 'CA Connected', Color(0xFFDB2777)),
      ],
    ),
  );
}

class _EcosystemSection extends StatelessWidget {
  const _EcosystemSection({super.key});
  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'ONE PLATFORM',
    title: 'Your complete accounting ecosystem',
    subtitle:
        'Business operations, professional review and financial visibility come together in one connected workspace.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        const modules = <(IconData, String, Color)>[
          (Icons.point_of_sale_outlined, 'Sales', Color(0xFF2563EB)),
          (Icons.shopping_cart_outlined, 'Purchase', Color(0xFFF59E0B)),
          (Icons.account_balance_outlined, 'Banking', Color(0xFF0EA5A4)),
          (Icons.calculate_outlined, 'Accounting', Color(0xFF4F46E5)),
          (Icons.receipt_long_outlined, 'GST', Color(0xFF16A673)),
          (Icons.document_scanner_outlined, 'OCR', Color(0xFF7C3AED)),
          (Icons.folder_copy_outlined, 'Documents', Color(0xFFDB2777)),
          (Icons.bar_chart_outlined, 'Reports', Color(0xFF0284C7)),
          (Icons.people_outline, 'Customers', Color(0xFF0F766E)),
          (Icons.verified_user_outlined, 'CA & Accountant', Color(0xFFB45309)),
        ];
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: modules
              .map(
                (module) => _ModuleTile(
                  icon: module.$1,
                  label: module.$2,
                  color: module.$3,
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _UniversalBusinessTemplateSection extends StatelessWidget {
  const _UniversalBusinessTemplateSection();

  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'UNIVERSAL BUSINESS TEMPLATE',
    title: 'Set up vouchers around the way your business works',
    subtitle:
        'Every business does not need the same accounting screens. Start with the voucher types you use today, then add more as your workflow grows.',
    tinted: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const examples = <_TemplateExample>[
          _TemplateExample(
            icon: Icons.storefront_outlined,
            title: 'Trading & Retail',
            detail:
                'Sales, Purchase, Receipt, Payment and Credit Note vouchers.',
            color: Color(0xFF0F766E),
          ),
          _TemplateExample(
            icon: Icons.design_services_outlined,
            title: 'Service Business',
            detail: 'Sales, Receipt, Payment, Journal and Debit Note vouchers.',
            color: Color(0xFF2563EB),
          ),
          _TemplateExample(
            icon: Icons.precision_manufacturing_outlined,
            title: 'Manufacturing',
            detail:
                'Sales, Purchase, Stock Journal and Manufacturing vouchers.',
            color: Color(0xFFB45309),
          ),
        ];
        final explanation = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Choose only the voucher types your team needs',
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Universal Business Template lets you configure Sales, Purchase, Payment, Receipt, Journal, Contra, Debit Note, Credit Note, Stock Journal and Manufacturing vouchers to match your actual process. Your selected vouchers become the focused billing and accounting workspace for your client and accountant.',
              style: TextStyle(
                color: Color(0xFF53657A),
                fontSize: 14,
                height: 1.55,
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _VoucherTypeChip('Sales'),
                _VoucherTypeChip('Purchase'),
                _VoucherTypeChip('Payment'),
                _VoucherTypeChip('Receipt'),
                _VoucherTypeChip('Journal'),
                _VoucherTypeChip('Stock'),
              ],
            ),
          ],
        );
        final templateExamples = Column(
          children: [
            for (final example in examples) ...[
              _TemplateExampleCard(example: example),
              if (example != examples.last) const SizedBox(height: 10),
            ],
          ],
        );

        if (constraints.maxWidth < 880) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              explanation,
              const SizedBox(height: 18),
              templateExamples,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: explanation),
            const SizedBox(width: 32),
            Expanded(flex: 5, child: templateExamples),
          ],
        );
      },
    ),
  );
}

class _VoucherTypeChip extends StatelessWidget {
  const _VoucherTypeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD8E4F5)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF194B85),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _TemplateExample {
  const _TemplateExample({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
}

class _TemplateExampleCard extends StatelessWidget {
  const _TemplateExampleCard({required this.example});

  final _TemplateExample example;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: example.color.withValues(alpha: .22)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: example.color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(example.icon, size: 18, color: example.color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                example.title,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                example.detail,
                style: const TextStyle(
                  color: Color(0xFF61738A),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({super.key, required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'ROLE-BASED PLATFORM',
    title: 'Built for everyone in your accounting ecosystem',
    subtitle:
        'Purpose-built workspaces keep each role focused without weakening permissions or controls.',
    tinted: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const roles = <_RoleData>[
          _RoleData(
            'Client',
            'Run your business with confidence.',
            Icons.storefront_outlined,
            Color(0xFF0F9F75),
            [
              'Sales & purchase',
              'Banking & payments',
              'GST & documents',
              'Reports and CA chat',
            ],
          ),
          _RoleData(
            'Accountant',
            'Work faster. Stay organized.',
            Icons.calculate_outlined,
            Color(0xFF2563EB),
            [
              'OCR entry',
              'Voucher processing',
              'Client work queue',
              'Tally sync & approvals',
            ],
          ),
          _RoleData(
            'CA / Admin',
            'Manage the entire operation.',
            Icons.admin_panel_settings_outlined,
            Color(0xFF7C3AED),
            [
              'Client management',
              'Work allocation',
              'Compliance & reports',
              'Targets and performance',
            ],
          ),
        ];
        final columns = constraints.maxWidth >= 850 ? 3 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: roles
              .map(
                (role) => SizedBox(
                  width: width,
                  child: _RoleCard(data: role, onExplore: onExplore),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection({super.key});
  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'HOW IT WORKS',
    title: 'From document to decision',
    subtitle:
        'A visual explanation of the existing workflow. Actual access and approvals remain role controlled.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        const steps = <(IconData, String, String)>[
          (
            Icons.cloud_upload_outlined,
            'Client Upload',
            'Share an invoice, bill or document.',
          ),
          (
            Icons.document_scanner_outlined,
            'OCR Processing',
            'Extract structured accounting information.',
          ),
          (
            Icons.fact_check_outlined,
            'Accountant Review',
            'Verify the draft and existing masters.',
          ),
          (
            Icons.post_add_outlined,
            'Voucher Creation',
            'Create the accounting entry.',
          ),
          (
            Icons.verified_outlined,
            'CA Approval',
            'Review and approve where configured.',
          ),
          (
            Icons.insights_outlined,
            'Reports',
            'Use completed records for reporting.',
          ),
        ];
        final columns = constraints.maxWidth >= 900
            ? 6
            : constraints.maxWidth >= 560
            ? 3
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < steps.length; i++)
              SizedBox(
                width: width,
                child: _WorkflowStep(number: i + 1, data: steps[i]),
              ),
          ],
        );
      },
    ),
  );
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({super.key});
  @override
  Widget build(BuildContext context) => const _Section(
    eyebrow: 'PLATFORM CAPABILITIES',
    title: 'Powerful features for modern accounting',
    subtitle:
        'Everything you need to organize work, collaborate and understand the business.',
    child: _FeatureGrid(),
  );
}

class _OcrShowcase extends StatelessWidget {
  const _OcrShowcase();
  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'DOCUMENT INTELLIGENCE',
    title: 'Turn documents into accounting entries',
    subtitle:
        'Move from source document to reviewed accounting entry through the existing OCR workflow.',
    tinted: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const stages = <(IconData, String)>[
          (Icons.description_outlined, 'Document'),
          (Icons.document_scanner_outlined, 'OCR'),
          (Icons.data_object_outlined, 'Extraction'),
          (Icons.account_tree_outlined, 'Voucher Mapping'),
          (Icons.rate_review_outlined, 'Review'),
          (Icons.check_circle_outline, 'Accounting Entry'),
        ];
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 12,
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              _ProcessNode(icon: stages[i].$1, label: stages[i].$2),
              if (i < stages.length - 1)
                const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF9CB0CA),
                  size: 18,
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _BusinessOwnerShowcase extends StatelessWidget {
  const _BusinessOwnerShowcase();
  @override
  Widget build(BuildContext context) => const _Section(
    eyebrow: 'BUSINESS VISIBILITY',
    title: 'Know your business at a glance',
    subtitle:
        'An illustrative view of the categories available in the business dashboard. Values shown after login come only from recorded data.',
    child: _IllustrativeMetrics(),
  );
}

class _PerformanceShowcase extends StatelessWidget {
  const _PerformanceShowcase();
  @override
  Widget build(BuildContext context) => const _Section(
    eyebrow: 'TEAM PERFORMANCE',
    title: 'Turn targets into accountable progress',
    subtitle:
        'Organizations can configure targets and review supported productivity indicators without inventing scores.',
    tinted: true,
    child: _PerformanceFlow(),
  );
}

class _CollaborationSection extends StatelessWidget {
  const _CollaborationSection();
  @override
  Widget build(BuildContext context) => const _Section(
    eyebrow: 'CONNECTED WORKSPACE',
    title: 'Everyone works from one connected workspace',
    subtitle:
        'Clients, accountants and CA teams coordinate through documents, messages, tasks, approvals and reports.',
    child: _CollaborationFlow(),
  );
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({super.key});
  @override
  Widget build(BuildContext context) => const _Section(
    eyebrow: 'CLIENT EXPERIENCES',
    title: 'Trusted stories, when clients choose to share them',
    subtitle:
        'Published testimonials will appear here after genuine client feedback is configured and approved.',
    tinted: true,
    child: _EmptyTestimonials(),
  );
}

class _WhyAndTrustSection extends StatelessWidget {
  const _WhyAndTrustSection();
  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'WHY CHIRAG ACCOUNTING',
    title: 'Professional workflows with clear controls',
    subtitle:
        'A connected platform built around the capabilities already present in Chirag Accounting.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        const points = <(IconData, String)>[
          (Icons.hub_outlined, 'One connected platform'),
          (Icons.groups_outlined, 'Client, Accountant & CA collaboration'),
          (Icons.document_scanner_outlined, 'OCR document processing'),
          (Icons.account_balance_outlined, 'Banking workflows'),
          (Icons.receipt_long_outlined, 'GST-ready operations'),
          (Icons.task_alt_outlined, 'Task and approval tracking'),
          (Icons.lock_person_outlined, 'Role-based access'),
          (Icons.history_outlined, 'Audit-friendly workflows'),
        ];
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: points
              .map(
                (point) => SizedBox(
                  width: width,
                  child: _ValueTile(icon: point.$1, text: point.$2),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _PricingSection extends StatelessWidget {
  const _PricingSection({
    super.key,
    required this.onSignUp,
    required this.onLogin,
  });
  final VoidCallback onSignUp;
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'GET STARTED',
    title: 'Choose the right way to begin',
    subtitle:
        'No invented public pricing. Talk to the team for a plan designed around your business and workflow.',
    tinted: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final form = _LeadFormCard(onLogin: onLogin);
        final options = Column(
          children: [
            _PricingOption(
              icon: Icons.rocket_launch_outlined,
              title: 'Free Trial / Get Started',
              text:
                  'Create your account through the existing registration workflow.',
              action: 'Start Free',
              onTap: onSignUp,
            ),
            const SizedBox(height: 10),
            _PricingOption(
              icon: Icons.support_agent_outlined,
              title: 'Talk to Our Team',
              text: 'Share your requirements using the existing enquiry form.',
              action: null,
              onTap: null,
            ),
            const SizedBox(height: 10),
            _PricingOption(
              icon: Icons.apartment_outlined,
              title: 'Custom Business Plan',
              text: 'Discuss role access, modules and implementation needs.',
              action: null,
              onTap: null,
            ),
          ],
        );
        if (constraints.maxWidth < 820) {
          return Column(children: [options, const SizedBox(height: 16), form]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: options),
            const SizedBox(width: 18),
            Expanded(child: form),
          ],
        );
      },
    ),
  );
}

class _DownloadCenterSection extends StatelessWidget {
  const _DownloadCenterSection({super.key, required this.onOpenWebFallback});

  final VoidCallback onOpenWebFallback;

  Future<void> _openUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the configured link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<DownloadCenterService>().settings;
    return _Section(
      eyebrow: 'DOWNLOAD CENTER',
      title: 'Download Chirag Accounting',
      subtitle: 'Access Chirag Accounting anywhere — on Web, Android and iOS.',
      tinted: true,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850 ? 3 : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 14)) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: width,
                    child: _DownloadCard(
                      icon: Icons.language_rounded,
                      title: 'WEB APP',
                      description:
                          'Access Chirag Accounting from your browser.',
                      color: const Color(0xFF2563EB),
                      actionLabel: 'Open Web App',
                      onPressed: settings.hasWebAppUrl
                          ? () => _openUrl(context, settings.webAppUrl)
                          : onOpenWebFallback,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _DownloadCard(
                      icon: Icons.android,
                      title: 'ANDROID',
                      description:
                          'Chirag Accounting mobile application for Android.',
                      color: const Color(0xFF0F9F75),
                      version: settings.androidVersion,
                      actionLabel: settings.androidAvailable
                          ? 'Download for Android'
                          : null,
                      onPressed: settings.androidAvailable
                          ? () => _openUrl(context, settings.androidUrl)
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _DownloadCard(
                      icon: Icons.apple,
                      title: 'iOS',
                      description:
                          'Chirag Accounting mobile application for iPhone and iPad.',
                      color: const Color(0xFF4F46E5),
                      version: settings.iosVersion,
                      actionLabel: settings.iosAvailable
                          ? 'Download on App Store'
                          : null,
                      onPressed: settings.iosAvailable
                          ? () => _openUrl(context, settings.iosUrl)
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _MobileAppShowcase(settings: settings),
          const SizedBox(height: 24),
          _QrDownloadPanel(settings: settings),
          if (settings.releaseNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Release Notes',
                    style: TextStyle(
                      color: Color(0xFF102A43),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    settings.releaseNotes,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.actionLabel,
    required this.onPressed,
    this.version = '',
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final String version;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 218),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F2A44),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 25),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 11,
            height: 1.45,
          ),
        ),
        if (version.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            'Version ${version.trim()}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (actionLabel != null)
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.open_in_new, size: 17),
            label: Text(actionLabel!),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFF5D58A)),
            ),
            child: const Text(
              'Coming Soon',
              style: TextStyle(
                color: Color(0xFF9A6700),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    ),
  );
}

class _MobileAppShowcase extends StatelessWidget {
  const _MobileAppShowcase({required this.settings});
  final DownloadCenterSettings settings;

  @override
  Widget build(BuildContext context) {
    const features = <(IconData, String, Color)>[
      (Icons.point_of_sale_outlined, 'Sales', Color(0xFF2563EB)),
      (Icons.receipt_long_outlined, 'Invoices & Bills', Color(0xFF7C3AED)),
      (Icons.upload_file_outlined, 'Document Upload', Color(0xFF0F9F75)),
      (Icons.account_balance_outlined, 'Banking', Color(0xFF0EA5A4)),
      (Icons.bar_chart_outlined, 'Reports', Color(0xFFF59E0B)),
      (Icons.chat_bubble_outline, 'Chat with CA', Color(0xFFDB2777)),
      (Icons.notifications_none, 'Notifications', Color(0xFF4F46E5)),
      (Icons.folder_outlined, 'Documents', Color(0xFF0284C7)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF082B59), Color(0xFF174EA6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR BUSINESS, ANYWHERE',
                style: TextStyle(
                  color: Color(0xFF8FC5FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A connected mobile workspace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: features
                    .map(
                      (feature) => Container(
                        width: 142,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(feature.$1, color: feature.$3, size: 17),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                feature.$2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
          const phone = _PhoneIllustration();
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 22), phone],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              phone,
            ],
          );
        },
      ),
    );
  }
}

class _PhoneIllustration extends StatelessWidget {
  const _PhoneIllustration();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 190,
      height: 310,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF071A38),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF7798C4), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 54,
                child: Divider(color: Color(0xFF12213A), thickness: 3),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Business Overview',
              style: TextStyle(
                color: Color(0xFF102A43),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: _PhoneMetric(Icons.trending_up, Color(0xFF16A673)),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: _PhoneMetric(Icons.receipt_long, Color(0xFF7C3AED)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E8F2)),
                ),
                child: const CustomPaint(
                  painter: _MarketingChartPainter(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 9),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(Icons.home_outlined, size: 18, color: Color(0xFF2563EB)),
                Icon(Icons.add_circle, size: 25, color: Color(0xFF2563EB)),
                Icon(Icons.person_outline, size: 18, color: Color(0xFF667085)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhoneMetric extends StatelessWidget {
  const _PhoneMetric(this.icon, this.color);
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 55,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

class _QrDownloadPanel extends StatelessWidget {
  const _QrDownloadPanel({required this.settings});
  final DownloadCenterSettings settings;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration,
    child: Column(
      children: [
        const Text(
          'SCAN TO DOWNLOAD',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 40,
          runSpacing: 20,
          children: [
            _QrItem(
              label: 'Android QR Code',
              data: settings.androidAvailable ? settings.androidUrl : null,
              color: const Color(0xFF0F9F75),
            ),
            _QrItem(
              label: 'iOS QR Code',
              data: settings.iosAvailable ? settings.iosUrl : null,
              color: const Color(0xFF4F46E5),
            ),
          ],
        ),
      ],
    ),
  );
}

class _QrItem extends StatelessWidget {
  const _QrItem({required this.label, required this.data, required this.color});
  final String label;
  final String? data;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 150,
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: data == null ? const Color(0xFFF4F7FB) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .22)),
          ),
          child: data == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, color: Color(0xFF98A2B3)),
                    SizedBox(height: 7),
                    Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : QrImageView(
                  data: data!,
                  size: 132,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: color,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: const Color(0xFF102A43),
                  ),
                ),
        ),
      ],
    ),
  );
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({super.key});
  @override
  Widget build(BuildContext context) => const _Section(
    eyebrow: 'SUPPORT',
    title: 'Need help?',
    subtitle:
        'Use the configured support channels for onboarding and assistance.',
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _SupportTile(Icons.menu_book_outlined, 'Knowledge Base'),
        _SupportTile(Icons.chat_outlined, 'WhatsApp'),
        _SupportTile(Icons.email_outlined, 'Email'),
        _SupportTile(Icons.support_agent_outlined, 'Support'),
        _SupportTile(Icons.verified_user_outlined, 'CA Assistance'),
      ],
    ),
  );
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({super.key, required this.onSignUp, required this.onLogin});
  final VoidCallback onSignUp;
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => _Bounded(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0759D1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Business. Your Accounting.\nOne Connected Platform.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Join Chirag Accounting and connect your business, accountant and CA in one platform.',
                style: TextStyle(color: Color(0xFFDCEBFF), fontSize: 12),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: onSignUp,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC928),
                  foregroundColor: const Color(0xFF102A43),
                ),
                child: const Text('Get Started'),
              ),
              OutlinedButton(
                onPressed: onLogin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('Login'),
              ),
            ],
          );
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 18), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ],
          );
        },
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onOpenDownloads});
  final VoidCallback onOpenDownloads;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFF041F43),
    child: _Bounded(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
      child: Column(
        children: [
          Wrap(
            spacing: 38,
            runSpacing: 24,
            children: [
              const SizedBox(
                width: 330,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Brand(),
                    SizedBox(height: 12),
                    Text(
                      'A connected accounting and business management platform for clients, accountants and CA firms.',
                      style: TextStyle(
                        color: Color(0xFFBFD0E5),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const _FooterColumn('Platform', [
                'Client',
                'Accountant',
                'CA / Admin',
                'OCR',
                'Banking',
                'GST',
                'Reports',
              ]),
              const _FooterColumn('Company', [
                'About',
                'Features',
                'Services',
                'Pricing',
                'Support',
                'Contact',
              ]),
              _FooterDownloadColumn(onTap: onOpenDownloads),
              const _FooterColumn('Contact', [
                'RT Street, Bengaluru - 560053',
                '8884784603 / 9742015817',
                'Support@chiragaccounting.com',
                'Mon-Sat · 9:30 AM to 7:00 PM',
              ]),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF214267)),
          const SizedBox(height: 12),
          const Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 14,
            runSpacing: 8,
            children: [
              Text(
                '© 2026 Chirag Accounting. All rights reserved.',
                style: TextStyle(color: Color(0xFF9DB1CA), fontSize: 10),
              ),
              Text(
                'Privacy Policy  ·  Terms & Conditions',
                style: TextStyle(color: Color(0xFF9DB1CA), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LeadFormCard extends StatefulWidget {
  const _LeadFormCard({required this.onLogin});
  final VoidCallback onLogin;
  @override
  State<_LeadFormCard> createState() => _LeadFormCardState();
}

class _LeadFormCardState extends State<_LeadFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLead() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await context.read<MarketingService>().addLead(
        name: _companyCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        source: MarketingLeadSource.website,
        owner: 'public-website',
      );
      if (!mounted) return;
      _companyCtrl.clear();
      _mobileCtrl.clear();
      _emailCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request received. Our team will contact you immediately via call, WhatsApp, or email.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit request: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Talk to Our Team',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Share your details and we will discuss suitable trial and plan options.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 11),
        ),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _companyCtrl,
                decoration: _inputDecoration(
                  'Company Name',
                  Icons.business_outlined,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter company name'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _mobileCtrl,
                decoration: _inputDecoration(
                  'Mobile Number',
                  Icons.phone_android_outlined,
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    (value ?? '').replaceAll(RegExp(r'\D'), '').length != 10
                    ? 'Enter valid 10-digit mobile number'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: _inputDecoration(
                  'Email Address',
                  Icons.email_outlined,
                ),
                keyboardType: TextInputType.emailAddress,
                onFieldSubmitted: (_) => _submitLead(),
                validator: (value) =>
                    !RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value?.trim() ?? '')
                    ? 'Enter valid email address'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _submitting ? null : _submitLead,
              icon: _submitting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 17),
              label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onLogin,
              icon: const Icon(Icons.login, size: 17),
              label: const Text('Open Login Page'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const features = <(IconData, String, String, Color)>[
        (
          Icons.calculate_outlined,
          'Smart Accounting',
          'Organize everyday accounting workflows.',
          Color(0xFF2563EB),
        ),
        (
          Icons.document_scanner_outlined,
          'OCR & Document AI',
          'Convert documents into structured draft data.',
          Color(0xFF7C3AED),
        ),
        (
          Icons.account_balance_outlined,
          'Banking',
          'Manage payment, receipt and statement workflows.',
          Color(0xFF0EA5A4),
        ),
        (
          Icons.receipt_long_outlined,
          'GST',
          'Keep accounting organized for GST-ready operations.',
          Color(0xFFF59E0B),
        ),
        (
          Icons.insights_outlined,
          'Reports',
          'Understand recorded business activity through reports.',
          Color(0xFF16A673),
        ),
        (
          Icons.forum_outlined,
          'Client Collaboration',
          'Connect clients, accountants and CA teams.',
          Color(0xFFDB2777),
        ),
        (
          Icons.task_alt_outlined,
          'Task Management',
          'Assign, track and complete accounting work.',
          Color(0xFF0284C7),
        ),
        (
          Icons.sync_alt_outlined,
          'Tally / Accounting Sync',
          'Connect supported accounting workflows.',
          Color(0xFF4F46E5),
        ),
      ];
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: features
            .map(
              (item) => SizedBox(
                width: width,
                child: _FeatureTile(data: item),
              ),
            )
            .toList(),
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.tinted = false,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: tinted ? const Color(0xFFF0F6FF) : Colors.transparent,
    child: _Bounded(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 36),
      child: Column(
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF102A43),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    ),
  );
}

class _Bounded extends StatelessWidget {
  const _Bounded({required this.child, required this.padding});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF032D60),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ProductRibbon extends StatelessWidget {
  const _ProductRibbon({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFF032D60),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        const Text(
          'Chirag Accounting brings your business and finance team together.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          ),
          child: const Text(
            'Explore the platform',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      ],
    ),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2FF),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFD5E4FC)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF2563EB)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _CheckLabel extends StatelessWidget {
  const _CheckLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.check_circle, color: Color(0xFF16A673), size: 15),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(
          color: Color(0xFF40546C),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2FF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2563EB),
        fontSize: 7,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: _cardDecoration,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 142,
    height: 100,
    padding: const EdgeInsets.all(12),
    decoration: _cardDecoration,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _RoleData {
  const _RoleData(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.features,
  );
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> features;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.data, required this.onExplore});
  final _RoleData data;
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: data.color.withValues(alpha: .2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(data.icon, color: data.color, size: 21),
        ),
        const SizedBox(height: 12),
        Text(
          data.title,
          style: TextStyle(
            color: data.color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          data.subtitle,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
        ),
        const SizedBox(height: 13),
        for (final feature in data.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: data.color, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onExplore,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward, size: 15),
          label: const Text('Explore workspace'),
        ),
      ],
    ),
  );
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({required this.number, required this.data});
  final int number;
  final (IconData, String, String) data;
  @override
  Widget build(BuildContext context) => Container(
    height: 160,
    padding: const EdgeInsets.all(12),
    decoration: _cardDecoration,
    child: Column(
      children: [
        Text(
          number.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF2FF),
            shape: BoxShape.circle,
          ),
          child: Icon(data.$1, color: const Color(0xFF2563EB), size: 19),
        ),
        const SizedBox(height: 8),
        Text(
          data.$2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.$3,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 8,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.data});
  final (IconData, String, String, Color) data;
  @override
  Widget build(BuildContext context) => Container(
    height: 112,
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: data.$4.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(data.$1, color: data.$4, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  data.$3,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 9,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProcessNode extends StatelessWidget {
  const _ProcessNode({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 120,
    height: 94,
    padding: const EdgeInsets.all(10),
    decoration: _cardDecoration,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 2),
        Icon(icon, color: Color(0xFF2563EB), size: 26),
        const SizedBox(height: 9),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _IllustrativeMetrics extends StatelessWidget {
  const _IllustrativeMetrics();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const metrics = <(IconData, String, Color)>[
        (Icons.trending_up, 'Sales', Color(0xFF16A673)),
        (Icons.shopping_bag_outlined, 'Purchase', Color(0xFFF59E0B)),
        (Icons.call_received, 'Receivables', Color(0xFF2563EB)),
        (Icons.call_made, 'Payables', Color(0xFFDB2777)),
        (Icons.insights, 'Net Profit', Color(0xFF7C3AED)),
        (Icons.account_balance, 'Bank Balance', Color(0xFF0EA5A4)),
        (Icons.verified, 'GST', Color(0xFF16A673)),
      ];
      final columns = constraints.maxWidth >= 850
          ? 7
          : constraints.maxWidth >= 520
          ? 3
          : 2;
      final width = (constraints.maxWidth - ((columns - 1) * 8)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: metrics
            .map(
              (metric) => SizedBox(
                width: width,
                child: Container(
                  height: 90,
                  padding: const EdgeInsets.all(10),
                  decoration: _cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(metric.$1, color: metric.$3, size: 19),
                      const SizedBox(height: 7),
                      Text(
                        metric.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF102A43),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Available after login',
                        style: TextStyle(color: Color(0xFF98A2B3), fontSize: 7),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _PerformanceFlow extends StatelessWidget {
  const _PerformanceFlow();
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 10,
    children: const [
      _FlowChip(Icons.flag_outlined, 'Target'),
      Icon(Icons.arrow_forward, color: Color(0xFF9CB0CA), size: 17),
      _FlowChip(Icons.task_alt, 'Achievement'),
      Icon(Icons.arrow_forward, color: Color(0xFF9CB0CA), size: 17),
      _FlowChip(Icons.percent, 'Performance'),
      Icon(Icons.arrow_forward, color: Color(0xFF9CB0CA), size: 17),
      _FlowChip(Icons.star_outline, 'Rating'),
      Icon(Icons.arrow_forward, color: Color(0xFF9CB0CA), size: 17),
      _FlowChip(Icons.leaderboard_outlined, 'Ranking'),
      Icon(Icons.arrow_forward, color: Color(0xFF9CB0CA), size: 17),
      _FlowChip(Icons.workspace_premium_outlined, 'Reward'),
    ],
  );
}

class _FlowChip extends StatelessWidget {
  const _FlowChip(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 118,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: _cardDecoration,
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 22),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _CollaborationFlow extends StatelessWidget {
  const _CollaborationFlow();
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 14,
    children: const [
      _CollabNode(Icons.storefront_outlined, 'CLIENT', Color(0xFF16A673)),
      Icon(Icons.sync_alt, color: Color(0xFF9CB0CA)),
      _CollabNode(Icons.calculate_outlined, 'ACCOUNTANT', Color(0xFF2563EB)),
      Icon(Icons.sync_alt, color: Color(0xFF9CB0CA)),
      _CollabNode(
        Icons.admin_panel_settings_outlined,
        'CA / ADMIN',
        Color(0xFF7C3AED),
      ),
    ],
  );
}

class _CollabNode extends StatelessWidget {
  const _CollabNode(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    height: 105,
    decoration: _cardDecoration,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _EmptyTestimonials extends StatelessWidget {
  const _EmptyTestimonials();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: _cardDecoration,
    child: const Column(
      children: [
        Icon(Icons.format_quote_rounded, color: Color(0xFF9CB0CA), size: 34),
        SizedBox(height: 8),
        Text(
          'No published testimonials yet',
          style: TextStyle(
            color: Color(0xFF102A43),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Only genuine, approved client testimonials will be displayed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF667085), fontSize: 10),
        ),
      ],
    ),
  );
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    height: 74,
    padding: const EdgeInsets.all(11),
    decoration: _cardDecoration,
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF2FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PricingOption extends StatelessWidget {
  const _PricingOption({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: _cardDecoration,
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF2FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF102A43),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 9),
              ),
            ],
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

class _SupportTile extends StatelessWidget {
  const _SupportTile(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 160,
    height: 82,
    decoration: _cardDecoration,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 22),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn(this.title, this.items);
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              item,
              style: const TextStyle(color: Color(0xFFBFD0E5), fontSize: 9),
            ),
          ),
      ],
    ),
  );
}

class _FooterDownloadColumn extends StatelessWidget {
  const _FooterDownloadColumn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Downloads',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        for (final label in const [
          'Download Center',
          'Android App',
          'iOS App',
          'Web App',
        ])
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFBFD0E5),
              padding: const EdgeInsets.symmetric(vertical: 3),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label, style: const TextStyle(fontSize: 9)),
          ),
      ],
    ),
  );
}

class _MarketingChartPainter extends CustomPainter {
  const _MarketingChartPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE0E8F2)
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      canvas.drawLine(
        Offset(0, size.height * row / 4),
        Offset(size.width, size.height * row / 4),
        grid,
      );
    }
    final line = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, size.height * .75)
      ..lineTo(size.width * .14, size.height * .58)
      ..lineTo(size.width * .28, size.height * .67)
      ..lineTo(size.width * .43, size.height * .34)
      ..lineTo(size.width * .58, size.height * .48)
      ..lineTo(size.width * .74, size.height * .2)
      ..lineTo(size.width, size.height * .28);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

InputDecoration _inputDecoration(
  String label,
  IconData icon, {
  String? prefixText,
}) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, size: 18),
  prefixText: prefixText,
  filled: true,
  fillColor: const Color(0xFFF8FAFD),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFD9E2EC)),
  ),
);

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(color: const Color(0xFFE0E8F2)),
  boxShadow: const [
    BoxShadow(color: Color(0x0A0F2A44), blurRadius: 16, offset: Offset(0, 5)),
  ],
);
