import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/core/constants/feature_flags.dart';
import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';
import 'package:chirag_accounting/features/compat/screens/client_reports_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/client_uploads_screen_compat.dart';
import 'package:chirag_accounting/features/clients/Uplads/smart_invoice_upload_screen.dart';
import 'package:chirag_accounting/features/clients/Billing/presentation/pages/sales_voucher_system_screen.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workbench_screen.dart';
import 'package:chirag_accounting/features/compat/screens/purchase_screen_compat.dart';
import 'package:chirag_accounting/features/customers/presentation/pages/add_customer_screen.dart';
import 'package:chirag_accounting/features/products/presentation/pages/add_product_screen.dart';
import 'package:chirag_accounting/features/sales/presentation/pages/add_sales_invoice_screen.dart';
import 'package:chirag_accounting/features/vendors/presentation/pages/add_vendor_screen.dart';
import 'package:chirag_accounting/features/purchase/presentation/pages/add_purchase_bill_screen.dart';
import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/roles/controllers/role_controller.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/reports/presentation/pages/quick_provisional_report_screen.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/features/customers/presentation/pages/customers_screen.dart';

class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<RoleController>();
    final auth = context.watch<AuthController>();
    final isClientUser = auth.currentUser?.role.isClient ?? false;
    final userRole = auth.currentUser?.role;
    final isCaAuditorUser =
        userRole == UserRole.firmAdmin ||
        userRole == UserRole.partner ||
        userRole == UserRole.checker;

    if (isCaAuditorUser) {
      final actions = [
        _QuickAction(
          icon: Icons.bar_chart,
          label: 'Reports',
          color: Colors.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientReportsScreen()),
          ),
        ),
        _QuickAction(
          icon: Icons.flash_on_outlined,
          label: 'Provisional',
          color: const Color(0xFF1A237E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QuickProvisionalReportScreen(),
            ),
          ),
        ),
      ];
      return _buildQuickActionsContainer(actions, compact: compact);
    }

    final actions = [
      if (isClientUser)
        _QuickAction(
          icon: Icons.point_of_sale_rounded,
          label: 'Sales Voucher',
          color: const Color(0xFF0F6CBD),
          highlighted: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SalesVoucherSystemScreen(
                initialVoucherType: 'Sales',
              ),
            ),
          ),
        ),
      _QuickAction(
        icon: Icons.auto_awesome,
        label: 'Workbench',
        color: const Color(0xFF1A237E),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiWorkbenchScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.add_circle_outline,
        label: '+ New',
        color: Colors.deepPurple,
        onTap: () => _openSmartActionMenu(context, isClientUser),
      ),
      if (FeatureFlags.bankingEnabled && role.canAccess(AppModule.banking))
        _QuickAction(
          icon: Icons.payments_outlined,
          label: 'Payment',
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientBankScreen(
                initialVoucherType: VoucherType.payment,
              ),
            ),
          ),
        ),
      if (FeatureFlags.bankingEnabled && role.canAccess(AppModule.banking))
        _QuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Receipt',
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientBankScreen(
                initialVoucherType: VoucherType.receipt,
              ),
            ),
          ),
        ),
      if (role.canEdit(AppModule.purchase))
        _QuickAction(
          icon: Icons.receipt_long,
          label: 'New Bill',
          color: Colors.orange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PurchaseScreen()),
          ),
        ),
      if (role.canEdit(AppModule.customers))
        _QuickAction(
          icon: Icons.person_add_outlined,
          label: 'Customers',
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomersScreen()),
          ),
        ),
      if (role.canAccess(AppModule.gst))
        _QuickAction(
          icon: Icons.file_upload_outlined,
          label: 'Upload Bill',
          color: Colors.purple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientUploadsScreen(
                autoPickOnOpen: true,
                autoRouteAfterDetect: true,
                autoRouteSource: isClientUser ? 'quick-action' : 'manual',
              ),
            ),
          ),
        ),
      if (role.canAccess(AppModule.uploads))
        _QuickAction(
          icon: Icons.auto_awesome_outlined,
          label: 'Smart V2',
          color: const Color(0xFF1A237E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SmartInvoiceUploadScreen()),
          ),
        ),
      if (role.canAccess(AppModule.reports))
        _QuickAction(
          icon: Icons.bar_chart,
          label: 'Reports',
          color: Colors.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClientReportsScreen()),
          ),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return _buildQuickActionsContainer(actions, compact: compact);
  }

  Widget _buildQuickActionsContainer(
    List<_QuickAction> actions, {
    required bool compact,
  }) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFF1D4ED8), size: 20),
              SizedBox(width: 7),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF12213A),
                ),
              ),
              SizedBox(width: 8),
              Expanded(child: Divider(color: Color(0xFFDCE4EF))),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) =>
                  _CompactActionTile(action: actions[index]),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF6F9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF102A43),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap a shortcut to jump straight into work',
                      style: TextStyle(fontSize: 12, color: Color(0xFF627D98)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth >= 520 ? 1.45 : 1.15,
                ),
                itemBuilder: (context, index) =>
                    _ActionButton(action: actions[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openSmartActionMenu(BuildContext context, bool isClientUser) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('Create Sales Invoice'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddSalesInvoiceScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Create Purchase Invoice'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddPurchaseBillScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Receive Payment'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClientBankScreen(
                        initialVoucherType: VoucherType.receipt,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Make Payment'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClientBankScreen(
                        initialVoucherType: VoucherType.payment,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Upload Document'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientUploadsScreen(
                        autoPickOnOpen: true,
                        autoRouteAfterDetect: true,
                        autoRouteSource: isClientUser
                            ? 'smart-action'
                            : 'manual',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Create Customer'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddCustomerScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Create Supplier'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddVendorScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Create Product'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddProductScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.highlighted = false,
    required this.onTap,
  });
}

class _ActionButton extends StatelessWidget {
  final _QuickAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final accent = action.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.96),
                accent.withValues(alpha: 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(action.icon, color: Colors.white, size: 19),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Go now',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactActionTile extends StatelessWidget {
  const _CompactActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      child: Material(
        color: action.highlighted ? const Color(0xFF0F6CBD) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: action.highlighted
                ? const Color(0xFF0B5CAD)
                : const Color(0xFFDCE4EF),
            width: action.highlighted ? 1.5 : 1,
          ),
        ),
        elevation: action.highlighted ? 3 : 0,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: action.highlighted
                        ? Colors.white.withValues(alpha: 0.18)
                        : action.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    action.icon,
                    color: action.highlighted ? Colors.white : action.color,
                    size: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: action.highlighted
                        ? Colors.white
                        : const Color(0xFF344054),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
