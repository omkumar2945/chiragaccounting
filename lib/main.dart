import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/accounting/accounting_policy_service.dart';
import 'core/integrations/integration_hub_service.dart';
import 'core/navigation/app_lifecycle_state_keeper.dart';
import 'core/navigation/app_navigation_history.dart';
import 'core/navigation/end_of_screen_navigation.dart';
import 'core/realtime/realtime_gateway_service.dart';
import 'core/firebase/firebase_runtime_service.dart';
import 'features/authentication/controllers/auth_controller.dart';
import 'features/authentication/presentation/pages/splash_screen.dart';
import 'features/accountant/services/accountant_profile_service.dart';
import 'features/gst_scrutiny/services/gst_scrutiny_service.dart';
import 'features/gst_library/services/gst_library_service.dart';
import 'features/gst_notices/services/gst_notice_management_service.dart';
import 'features/marketing/services/marketing_service.dart';
import 'features/marketing/services/download_center_service.dart';
import 'features/hr/services/hr_service.dart';
import 'features/uni_desk/services/uni_desk_service.dart';
import 'features/dashboard/controllers/dashboard_controller.dart';
import 'features/inbox/services/universal_inbox_service.dart';
import 'features/operations_center/services/operations_center_service.dart';
import 'features/ca_workspace/services/ca_workspace_service.dart';
import 'features/products/product_service.dart';
import 'features/tasks/services/task_engine_service.dart';
import 'features/tasks/services/task_engine_api_service.dart';
import 'features/timeline/services/timeline_engine_service.dart';
import 'features/timeline/services/timeline_api_service.dart';
import 'features/sales/services/sales_voucher_calculation_api_service.dart';
import 'features/services/purchase_service.dart';
import 'features/roles/controllers/role_controller.dart';
import 'features/services/customer_service.dart';
import 'features/services/sales_service.dart';
import 'features/services/vendor_service.dart';
import 'features/ai_workbench/services/workbench_queue_service.dart';
import 'features/admin/services/admin_user_service.dart';
import 'features/client_portal/services/client_portal_access_service.dart';
import 'features/clients/financial_planning/services/client_financial_planning_service.dart';
import 'features/clients/Referral/client_referral_service.dart';
import 'features/clients/services/referral_program_service.dart';
import 'features/clients/services/document_hub_service.dart';
import 'features/clients/Chat/authenticated_support_chat_shell.dart';
import 'features/billing_print_setup/services/billing_print_setup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseRuntimeService.instance.initialize();
  runApp(const ChiragAccountingApp());
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final AppNavigationHistory appNavigationHistory = AppNavigationHistory();

class ChiragAccountingApp extends StatelessWidget {
  const ChiragAccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: FirebaseRuntimeService.instance),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(
          create: (_) => AccountantProfileService()..load(),
        ),
        ChangeNotifierProvider(create: (_) => GstScrutinyService()),
        ChangeNotifierProvider(create: (_) => GstLibraryService()),
        ChangeNotifierProvider(
          create: (_) => GstNoticeManagementService()..load(),
        ),
        ChangeNotifierProvider(create: (_) => MarketingService()..load()),
        ChangeNotifierProvider(create: (_) => DownloadCenterService()..load()),
        ChangeNotifierProvider(create: (_) => HrService()..load()),
        ChangeNotifierProvider(create: (_) => UniDeskService()..load()),
        ChangeNotifierProxyProvider<AuthController, RoleController>(
          create: (_) => RoleController(),
          update: (_, auth, role) {
            role!.setUser(auth.currentUser);
            return role;
          },
        ),
        ChangeNotifierProvider(create: (_) => CustomerService()),
        ChangeNotifierProvider(create: (_) => SalesService()),
        ChangeNotifierProvider(create: (_) => ProductService()),
        ChangeNotifierProvider(create: (_) => VendorService()),
        ChangeNotifierProvider(create: (_) => ClientReferralService()..load()),
        ChangeNotifierProvider(create: (_) => ReferralProgramService()..load()),
        ChangeNotifierProvider(create: (_) => WorkbenchQueueService()),
        ChangeNotifierProvider(create: (_) => PurchaseService()),
        Provider(create: (_) => TaskEngineApiService()),
        Provider(create: (_) => TimelineApiService()),
        Provider(create: (_) => SalesVoucherCalculationApiService()),
        ChangeNotifierProvider(create: (_) => TaskEngineService()),
        ChangeNotifierProvider(create: (_) => TimelineEngineService()),
        Provider(create: (_) => RealtimeGatewayService()),
        ChangeNotifierProvider(create: (_) => UniversalInboxService()),
        ChangeNotifierProvider(create: (_) => IntegrationHubService()),
        ChangeNotifierProvider(create: (_) => BillingPrintSetupService()),
        ChangeNotifierProvider(create: (_) => CaWorkspaceService()..load()),
        ChangeNotifierProvider(
          create: (_) => AccountingPolicyService()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => EndOfScreenNavigationController(),
        ),
        ChangeNotifierProvider(
          create: (_) => ClientPortalAccessService()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ClientFinancialPlanningService()..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => AdminUserService(
            integrationHub: context.read<IntegrationHubService>(),
            clientPortalAccess: context.read<ClientPortalAccessService>(),
            referralService: context.read<ClientReferralService>(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => DocumentHubService(
            queueService: context.read<WorkbenchQueueService>(),
            accessService: context.read<ClientPortalAccessService>(),
            salesService: context.read<SalesService>(),
            purchaseService: context.read<PurchaseService>(),
            assignedAccountantIdFor: (clientId) => context
                .read<AdminUserService>()
                .accountingAccessFor(clientId)
                .assignedAccountantId,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => OperationsCenterService(
            salesService: context.read<SalesService>(),
            purchaseService: context.read<PurchaseService>(),
            customerService: context.read<CustomerService>(),
            taskEngineService: context.read<TaskEngineService>(),
            timelineEngineService: context.read<TimelineEngineService>(),
            realtimeGatewayService: context.read<RealtimeGatewayService>(),
          ),
        ),
        ChangeNotifierProxyProvider3<
          SalesService,
          CustomerService,
          ProductService,
          DashboardController
        >(
          create: (context) => DashboardController(
            salesService: context.read<SalesService>(),
            customerService: context.read<CustomerService>(),
            productService: context.read<ProductService>(),
          ),
          update: (context, sales, customers, products, previous) {
            return previous ??
                DashboardController(
                  salesService: sales,
                  customerService: customers,
                  productService: products,
                );
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [appNavigationHistory],
        restorationScopeId: 'chirag_accounting_app',
        debugShowCheckedModeBanner: false,
        title: 'Chirag Accounting',
        scrollBehavior: const AppScrollBehavior(),
        builder: (context, child) => Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.f4): ActivateIntent(),
          },
          child: AppLifecycleStateKeeper(
            child: _GlobalSelectionShell(
              child: _KeyboardScrollShell(
                navigationHistory: appNavigationHistory,
                child: AuthenticatedSupportChatShell(
                  navigationHistory: appNavigationHistory,
                  navigatorKey: rootNavigatorKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            primary: const Color(0xFF1565C0),
            onPrimary: Colors.white,
            secondary: const Color(0xFFF9A825),
            onSecondary: const Color(0xFF1A1A1A),
            surface: Colors.white,
            onSurface: const Color(0xFF172033),
          ),
          useMaterial3: true,
          fontFamily: 'Arial',
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 16,
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            titleTextStyle: TextStyle(
              color: Color(0xFF032D60),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            contentTextStyle: TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              height: 1.45,
            ),
            actionsPadding: EdgeInsets.fromLTRB(20, 12, 20, 16),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1565C0),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          scrollbarTheme: ScrollbarThemeData(
            thumbVisibility: const WidgetStatePropertyAll(true),
            trackVisibility: const WidgetStatePropertyAll(true),
            interactive: true,
            radius: const Radius.circular(8),
            crossAxisMargin: 3,
            mainAxisMargin: 6,
            minThumbLength: 48,
            thickness: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.dragged)) return 10;
              if (states.contains(WidgetState.hovered)) return 8;
              return 6;
            }),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.dragged)) {
                return const Color(0xFF0D47A1);
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF1565C0);
              }
              return const Color(0xFF5079A8);
            }),
            trackColor: const WidgetStatePropertyAll(Color(0xFFE7EDF5)),
            trackBorderColor: const WidgetStatePropertyAll(Color(0xFFCDD8E6)),
          ),
          tabBarTheme: const TabBarThemeData(
            labelColor: Color(0xFF0D47A1),
            unselectedLabelColor: Color(0xFF455A64),
            indicatorColor: Color(0xFF0D47A1),
            dividerColor: Color(0xFFB8C6D9),
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFF8A96A8);
                }
                return const Color(0xFF0D47A1);
              }),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFF7B8798);
                }
                return const Color(0xFF0D47A1);
              }),
              side: WidgetStateProperty.resolveWith((states) {
                final color = states.contains(WidgetState.disabled)
                    ? const Color(0xFFB0BAC8)
                    : const Color(0xFF1565C0);
                return BorderSide(color: color, width: 1.2);
              }),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            labelStyle: TextStyle(color: Color(0xFF37474F)),
            hintStyle: TextStyle(color: Color(0xFF667385)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final isVertical =
        details.direction == AxisDirection.up ||
        details.direction == AxisDirection.down;
    if (!isVertical) {
      return super.buildScrollbar(context, child, details);
    }

    final hasClients = details.controller?.hasClients ?? false;

    return Scrollbar(
      controller: details.controller,
      thumbVisibility: hasClients,
      trackVisibility: hasClients,
      interactive: hasClients,
      child: child,
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class _GlobalSelectionShell extends StatefulWidget {
  const _GlobalSelectionShell({required this.child});

  final Widget child;

  @override
  State<_GlobalSelectionShell> createState() => _GlobalSelectionShellState();
}

class _GlobalSelectionShellState extends State<_GlobalSelectionShell> {
  late final OverlayEntry _selectionEntry;

  @override
  void initState() {
    super.initState();
    _selectionEntry = OverlayEntry(
      builder: (context) => SelectionArea(child: widget.child),
    );
  }

  @override
  void didUpdateWidget(_GlobalSelectionShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectionEntry.markNeedsBuild();
  }

  @override
  void dispose() {
    _selectionEntry.remove();
    _selectionEntry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_selectionEntry]);
  }
}

class _KeyboardScrollShell extends StatefulWidget {
  const _KeyboardScrollShell({
    required this.navigationHistory,
    required this.child,
  });

  final AppNavigationHistory navigationHistory;
  final Widget child;

  @override
  State<_KeyboardScrollShell> createState() => _KeyboardScrollShellState();
}

class _KeyboardScrollShellState extends State<_KeyboardScrollShell> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'app_keyboard_scroll');
  ScrollPosition? _lastVerticalPosition;
  ScrollPosition? _lastHorizontalPosition;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_revealFocusedEditable);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_revealFocusedEditable);
    _lastVerticalPosition = null;
    _lastHorizontalPosition = null;
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _requestFocus,
              child: Focus(
                autofocus: true,
                focusNode: _focusNode,
                onKeyEvent: _onKeyEvent,
                child: widget.child,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 2),
              child: Center(
                child: _EndOfScreenNavigationBar(
                  history: widget.navigationHistory,
                  localNavigation: context
                      .watch<EndOfScreenNavigationController>(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return KeyEventResult.ignored;

    // Keep arrow keys available for text fields/dropdowns when they have focus.
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final isEditingText =
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (isEditingText) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final position = _resolveScrollPositionForKey(key);
    if (position == null || !_isActiveScrollPosition(position)) {
      return KeyEventResult.ignored;
    }

    double? delta;

    if (key == LogicalKeyboardKey.arrowDown) {
      delta = 72;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      delta = -72;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      delta = 72;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      delta = -72;
    } else if (key == LogicalKeyboardKey.pageDown) {
      delta = position.viewportDimension * 0.9;
    } else if (key == LogicalKeyboardKey.pageUp) {
      delta = -position.viewportDimension * 0.9;
    } else if (key == LogicalKeyboardKey.home) {
      position.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.end) {
      position.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    }

    if (delta == null) return KeyEventResult.ignored;

    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );

    if (position.axis == Axis.vertical) {
      _lastVerticalPosition = position;
    } else {
      _lastHorizontalPosition = position;
    }

    return KeyEventResult.handled;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final notificationContext = notification.context;
    if (notificationContext == null) return false;

    final scrollable = Scrollable.maybeOf(notificationContext);
    if (scrollable == null) return false;

    final position = scrollable.position;
    final axis = axisDirectionToAxis(scrollable.axisDirection);
    if (axis == Axis.vertical) {
      _lastVerticalPosition = position;
    } else {
      _lastHorizontalPosition = position;
    }

    return false;
  }

  ScrollPosition? _resolveScrollPositionForKey(LogicalKeyboardKey key) {
    final needsHorizontal =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    final axis = needsHorizontal ? Axis.horizontal : Axis.vertical;

    final focusContext = FocusManager.instance.primaryFocus?.context;
    final focusedScrollable = focusContext == null
        ? null
        : Scrollable.maybeOf(focusContext);
    if (focusedScrollable != null &&
        _isActiveScrollPosition(focusedScrollable.position)) {
      final focusedAxis = axisDirectionToAxis(focusedScrollable.axisDirection);
      if (focusedAxis == axis) {
        return focusedScrollable.position;
      }
    }

    if (!needsHorizontal) {
      final primary = PrimaryScrollController.maybeOf(context);
      if (primary != null && primary.hasClients) {
        final primaryPosition = primary.position;
        if (primaryPosition.axis == Axis.vertical &&
            _isActiveScrollPosition(primaryPosition)) {
          return primaryPosition;
        }
      }
    }

    final cached = needsHorizontal
        ? _lastHorizontalPosition
        : _lastVerticalPosition;
    return cached != null && _isActiveScrollPosition(cached) ? cached : null;
  }

  bool _isActiveScrollPosition(ScrollPosition position) {
    final notificationContext = position.context.notificationContext;
    return position.hasPixels &&
        notificationContext != null &&
        notificationContext.mounted;
  }

  void _requestFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _revealFocusedEditable() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !focusContext.mounted) return;
      Scrollable.ensureVisible(
        focusContext,
        alignment: 0.22,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _EndOfScreenNavigationBar extends StatelessWidget {
  const _EndOfScreenNavigationBar({
    required this.history,
    required this.localNavigation,
  });

  final AppNavigationHistory history;
  final EndOfScreenNavigationController localNavigation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: history,
      builder: (context, _) => Material(
        elevation: 6,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: localNavigation.previousLabel,
                onPressed: localNavigation.hasPrevious
                    ? localNavigation.previous
                    : !localNavigation.hasActiveRegistration &&
                          history.canGoBack
                    ? history.goBack
                    : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: localNavigation.nextLabel,
                onPressed: localNavigation.hasNext
                    ? localNavigation.next
                    : !localNavigation.hasActiveRegistration &&
                          history.canGoForward
                    ? history.goForward
                    : null,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
