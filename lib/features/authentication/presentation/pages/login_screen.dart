import 'dart:ui';

import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'post_login_destination.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

enum StaffLoginMode { client, accountant, caAuditor, admin }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialMode = StaffLoginMode.client});

  final StaffLoginMode initialMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Password login
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // OTP login
  final _otpFormKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _mobileFocusNode = FocusNode();
  StaffLoginMode _staffLoginMode = StaffLoginMode.client;

  Set<UserRole> get _allowedRoles {
    switch (_staffLoginMode) {
      case StaffLoginMode.accountant:
        return {UserRole.accountant};
      case StaffLoginMode.caAuditor:
        return {UserRole.firmAdmin, UserRole.partner, UserRole.checker};
      case StaffLoginMode.admin:
        return {UserRole.admin, UserRole.superAdmin, UserRole.firmAdmin};
      case StaffLoginMode.client:
        return {UserRole.client};
    }
  }

  String get _modeTitle {
    switch (_staffLoginMode) {
      case StaffLoginMode.client:
        return 'Client Portal Login';
      case StaffLoginMode.accountant:
        return 'Accountant Workspace Login';
      case StaffLoginMode.caAuditor:
        return 'CA/Auditor Login';
      case StaffLoginMode.admin:
        return 'Admin Control Login';
    }
  }

  String get _modeSubtitle {
    switch (_staffLoginMode) {
      case StaffLoginMode.client:
        return 'Access billing, uploads, GST and report workflows.';
      case StaffLoginMode.accountant:
        return 'Track pending queues, assigned checks, and uploaded entries in one place.';
      case StaffLoginMode.caAuditor:
        return 'Open compliance review and audit command center workflows.';
      case StaffLoginMode.admin:
        return 'Manage users, controls, and enterprise operations.';
    }
  }

  @override
  void initState() {
    super.initState();
    _staffLoginMode = widget.initialMode;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _mobileCtrl.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final success = await auth.loginWithPassword(
      emailOrMobile: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      allowedRoles: _allowedRoles,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PostLoginDestination(
            openAdminPanel: _staffLoginMode == StaffLoginMode.admin,
            openUniDesk: false,
          ),
        ),
        (_) => false,
      );
    } else {
      _showError(auth.errorMessage ?? 'Login failed');
    }
  }

  Future<void> _sendOTP() async {
    if (!_otpFormKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final success = await auth.sendOTP(
      normalizeIndianMobile(_mobileCtrl.text),
      allowedRoles: _allowedRoles,
    );
    if (!mounted) return;
    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            mobileNumber: normalizeIndianMobile(_mobileCtrl.text),
            mode: OtpMode.login,
            allowedRoles: _allowedRoles,
            openAdminPanelAfterLogin: _staffLoginMode == StaffLoginMode.admin,
            openUniDeskAfterLogin: false,
          ),
        ),
      );
    } else {
      _showError(auth.errorMessage ?? 'Failed to send OTP');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071A3D), Color(0xFF0E4C92), Color(0xFFEAF2FF)],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -30,
              child: _GlowOrb(
                color: Colors.cyanAccent.withValues(alpha: 0.22),
                size: 180,
              ),
            ),
            Positioned(
              bottom: 120,
              left: -60,
              child: _GlowOrb(
                color: Colors.white.withValues(alpha: 0.12),
                size: 220,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeight = constraints.maxHeight < 820;
                  final veryCompactHeight = constraints.maxHeight < 700;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: veryCompactHeight
                              ? 8
                              : (compactHeight ? 12 : 18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHero(compact: veryCompactHeight),
                            SizedBox(
                              height: veryCompactHeight
                                  ? 8
                                  : (compactHeight ? 10 : 16),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 20,
                                    sigmaY: 20,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(26),
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.20,
                                          ),
                                          blurRadius: 28,
                                          offset: const Offset(0, 18),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        veryCompactHeight
                                            ? 14
                                            : (compactHeight ? 16 : 22),
                                        veryCompactHeight
                                            ? 12
                                            : (compactHeight ? 14 : 22),
                                        veryCompactHeight
                                            ? 14
                                            : (compactHeight ? 16 : 22),
                                        veryCompactHeight
                                            ? 10
                                            : (compactHeight ? 12 : 18),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          TabBar(
                                            controller: _tabController,
                                            labelColor: const Color(0xFF0E4C92),
                                            unselectedLabelColor:
                                                Colors.black54,
                                            indicatorColor: const Color(
                                              0xFF0E4C92,
                                            ),
                                            indicatorWeight: 3,
                                            labelStyle: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            unselectedLabelStyle:
                                                const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                            tabs: const [
                                              Tab(text: 'Password Login'),
                                              Tab(text: 'OTP Login'),
                                            ],
                                          ),
                                          SizedBox(
                                            height: compactHeight ? 10 : 14,
                                          ),
                                          if (veryCompactHeight)
                                            DropdownButtonFormField<
                                              StaffLoginMode
                                            >(
                                              value: _staffLoginMode,
                                              decoration: _inputDecoration(
                                                'Select login mode',
                                                Icons.badge_outlined,
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: StaffLoginMode.client,
                                                  child: Text('Client'),
                                                ),
                                                DropdownMenuItem(
                                                  value:
                                                      StaffLoginMode.accountant,
                                                  child: Text('Accountant'),
                                                ),
                                                DropdownMenuItem(
                                                  value:
                                                      StaffLoginMode.caAuditor,
                                                  child: Text('CA/Auditor'),
                                                ),
                                                DropdownMenuItem(
                                                  value: StaffLoginMode.admin,
                                                  child: Text('Admin'),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                if (value == null) return;
                                                setState(
                                                  () => _staffLoginMode = value,
                                                );
                                              },
                                            )
                                          else
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _ModeButton(
                                                  label: 'Client',
                                                  icon: Icons.person_outline,
                                                  selected:
                                                      _staffLoginMode ==
                                                      StaffLoginMode.client,
                                                  onTap: () => setState(
                                                    () => _staffLoginMode =
                                                        StaffLoginMode.client,
                                                  ),
                                                ),
                                                _ModeButton(
                                                  label: 'Accountant',
                                                  icon:
                                                      Icons.calculate_outlined,
                                                  accent: true,
                                                  selected:
                                                      _staffLoginMode ==
                                                      StaffLoginMode.accountant,
                                                  onTap: () => setState(
                                                    () => _staffLoginMode =
                                                        StaffLoginMode
                                                            .accountant,
                                                  ),
                                                ),
                                                _ModeButton(
                                                  label: 'CA/Auditor',
                                                  icon: Icons
                                                      .verified_user_outlined,
                                                  selected:
                                                      _staffLoginMode ==
                                                      StaffLoginMode.caAuditor,
                                                  onTap: () => setState(
                                                    () => _staffLoginMode =
                                                        StaffLoginMode
                                                            .caAuditor,
                                                  ),
                                                ),
                                                _ModeButton(
                                                  label: 'Admin',
                                                  icon: Icons
                                                      .admin_panel_settings_outlined,
                                                  selected:
                                                      _staffLoginMode ==
                                                      StaffLoginMode.admin,
                                                  onTap: () => setState(
                                                    () => _staffLoginMode =
                                                        StaffLoginMode.admin,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (!veryCompactHeight) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEDF4FF),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFCEE0FF,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.info_outline,
                                                    color: Color(0xFF0E4C92),
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _modeSubtitle,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF0E4C92,
                                                        ),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          SizedBox(
                                            height: veryCompactHeight
                                                ? 8
                                                : (compactHeight ? 10 : 16),
                                          ),
                                          Expanded(
                                            child: TabBarView(
                                              controller: _tabController,
                                              children: [
                                                _PasswordTab(
                                                  formKey: _passwordFormKey,
                                                  emailCtrl: _emailCtrl,
                                                  emailFocusNode:
                                                      _emailFocusNode,
                                                  passwordCtrl: _passwordCtrl,
                                                  passwordFocusNode:
                                                      _passwordFocusNode,
                                                  obscurePassword:
                                                      _obscurePassword,
                                                  rememberMe: _rememberMe,
                                                  onTogglePassword: () =>
                                                      setState(
                                                        () => _obscurePassword =
                                                            !_obscurePassword,
                                                      ),
                                                  onToggleRemember: (v) =>
                                                      setState(
                                                        () => _rememberMe =
                                                            v ?? false,
                                                      ),
                                                  onForgotPassword: () =>
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              const ForgotPasswordScreen(),
                                                        ),
                                                      ),
                                                  onLogin: _loginWithPassword,
                                                  modeLabel: _modeTitle,
                                                  compact: veryCompactHeight,
                                                ),
                                                _OtpTab(
                                                  formKey: _otpFormKey,
                                                  mobileCtrl: _mobileCtrl,
                                                  mobileFocusNode:
                                                      _mobileFocusNode,
                                                  onSendOtp: _sendOTP,
                                                  compact: veryCompactHeight,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: veryCompactHeight
                                  ? 6
                                  : (compactHeight ? 10 : 14),
                            ),
                            if (!compactHeight)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  _MetaChip(
                                    icon: Icons.lock_outline,
                                    label: 'Secure portal',
                                  ),
                                  _MetaChip(
                                    icon: Icons.speed_outlined,
                                    label: 'Fast login',
                                  ),
                                  _MetaChip(
                                    icon: Icons.auto_awesome_outlined,
                                    label: 'Auto-entry ready',
                                  ),
                                  _MetaChip(
                                    icon: Icons.chat_bubble_outline,
                                    label: 'Chat enabled',
                                  ),
                                ],
                              ),
                            if (!compactHeight) const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account? ",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: veryCompactHeight ? 2 : 6),
                            const Text(
                              'Powered by Chirag Accounting System',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0E4C92).withValues(alpha: 0.95),
            const Color(0xFF1B74D1).withValues(alpha: 0.92),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E4C92).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          _LoginBrandLogo(compact: compact),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chirag Accounting System',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _modeTitle,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.90),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    _modeSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBrandLogo extends StatelessWidget {
  const _LoginBrandLogo({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 56.0 : 72.0;

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Text(
          'CA',
          style: TextStyle(
            fontSize: compact ? 18 : 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0E4C92),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// --------------- Password Tab ---------------

class _PasswordTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final FocusNode emailFocusNode;
  final TextEditingController passwordCtrl;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final bool rememberMe;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onForgotPassword;
  final VoidCallback onLogin;
  final String modeLabel;
  final bool compact;

  const _PasswordTab({
    required this.formKey,
    required this.emailCtrl,
    required this.emailFocusNode,
    required this.passwordCtrl,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.rememberMe,
    required this.onTogglePassword,
    required this.onToggleRemember,
    required this.onForgotPassword,
    required this.onLogin,
    required this.modeLabel,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthController, bool>((c) => c.isLoading);
    return Form(
      key: formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = compact || constraints.maxHeight < 430;
          final sectionGap = isCompact ? 8.0 : 14.0;
          final actionGap = isCompact ? 6.0 : 10.0;
          final actionHeight = isCompact ? 44.0 : 50.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                modeLabel,
                style: const TextStyle(
                  color: Color(0xFF0E4C92),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: isCompact ? 6 : 10),
              TextFormField(
                controller: emailCtrl,
                focusNode: emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  'Email or Mobile',
                  Icons.person_outline,
                ),
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(passwordFocusNode);
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: sectionGap),
              TextFormField(
                controller: passwordCtrl,
                focusNode: passwordFocusNode,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: _inputDecoration('Password', Icons.lock_outline)
                    .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: onTogglePassword,
                      ),
                    ),
                onFieldSubmitted: (_) => onLogin(),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              SizedBox(height: isCompact ? 2 : 4),
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: onToggleRemember,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('Remember Me', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: onForgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 4 : 8),
              SizedBox(height: actionGap),
              SizedBox(
                height: actionHeight,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E4C92),
                    foregroundColor: Colors.white,
                    shadowColor: const Color(
                      0xFF0E4C92,
                    ).withValues(alpha: 0.35),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.login_rounded, size: 20),
                  label: Text(
                    isLoading ? 'Logging in...' : 'Login to Portal',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --------------- OTP Tab ---------------

class _OtpTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController mobileCtrl;
  final FocusNode mobileFocusNode;
  final VoidCallback onSendOtp;
  final bool compact;

  const _OtpTab({
    required this.formKey,
    required this.mobileCtrl,
    required this.mobileFocusNode,
    required this.onSendOtp,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthController, bool>((c) => c.isLoading);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: compact ? 4 : 8),
          if (!compact)
            const Text(
              'Enter your registered mobile number to receive OTP',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: compact ? 12 : 20),
          TextFormField(
            controller: mobileCtrl,
            focusNode: mobileFocusNode,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: indianMobileInputFormatters(),
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              'Mobile Number',
              Icons.phone_android,
            ).copyWith(prefixText: '+91 '),
            onFieldSubmitted: (_) => onSendOtp(),
            validator: (v) {
              return validateIndianMobile(v, required: true);
            },
          ),
          SizedBox(height: compact ? 12 : 20),
          SizedBox(
            height: compact ? 44 : 50,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shadowColor: const Color(0xFF1565C0).withValues(alpha: 0.30),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.sms_outlined, size: 20),
              label: Text(
                isLoading ? 'Sending OTP...' : 'Send OTP',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    this.accent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF0E4C92);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? activeColor : const Color(0xFFF2F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFFD4E1FB),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : activeColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : activeColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            if (accent && !selected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E4C92).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E4C92),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF0E4C92)),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0E4C92),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: const Color(0xFFF8FBFF),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD5E3F6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF0E4C92), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  );
}
