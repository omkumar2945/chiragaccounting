import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'post_login_destination.dart';
import 'forgot_password_screen.dart';

enum OtpMode { login, passwordReset }

class OtpScreen extends StatefulWidget {
  final String mobileNumber;
  final OtpMode mode;
  final bool openAdminPanelAfterLogin;
  final bool openUniDeskAfterLogin;
  final Set<UserRole> allowedRoles;

  const OtpScreen({
    super.key,
    required this.mobileNumber,
    this.mode = OtpMode.login,
    this.openAdminPanelAfterLogin = false,
    this.openUniDeskAfterLogin = false,
    this.allowedRoles = const <UserRole>{},
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  int _secondsLeft = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _secondsLeft = 60;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpValue.length != 6) {
      _showSnack('Please enter the 6-digit OTP');
      return;
    }
    final auth = context.read<AuthController>();
    if (widget.mode == OtpMode.login) {
      final success = await auth.verifyOTP(_otpValue);
      if (!mounted) return;
      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => PostLoginDestination(
              openAdminPanel: widget.openAdminPanelAfterLogin,
              openUniDesk: widget.openUniDeskAfterLogin,
            ),
          ),
          (_) => false,
        );
      } else {
        _showSnack(auth.errorMessage ?? 'Invalid OTP');
        _clearOtp();
      }
    } else {
      final success = await auth.verifyPasswordResetOtp(_otpValue);
      if (!mounted) return;
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      } else {
        _showSnack(auth.errorMessage ?? 'Invalid OTP');
        _clearOtp();
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    final auth = context.read<AuthController>();
    final success = widget.mode == OtpMode.passwordReset
        ? await auth.forgotPassword(widget.mobileNumber)
        : await auth.sendOTP(
            widget.mobileNumber,
            allowedRoles: widget.allowedRoles,
          );
    if (!mounted) return;
    if (success) {
      _startResendTimer();
      _showSnack('OTP resent successfully');
    } else {
      _showSnack(auth.errorMessage ?? 'Failed to resend OTP');
    }
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthController, bool>((c) => c.isLoading);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('OTP Verification'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1565C0,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_open,
                          size: 38,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Enter OTP',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'OTP sent to ${widget.mobileNumber}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (i) => _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            onChanged: (val) {
                              if (val.length == 1 && i < 5) {
                                _focusNodes[i + 1].requestFocus();
                              }
                              if (val.isEmpty && i > 0) {
                                _focusNodes[i - 1].requestFocus();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Verify OTP',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _canResend ? _resendOtp : null,
                        child: Text(
                          _canResend
                              ? 'Resend OTP'
                              : 'Resend in $_secondsLeft s',
                          style: TextStyle(
                            fontSize: 14,
                            color: _canResend
                                ? const Color(0xFF1565C0)
                                : Colors.grey,
                            fontWeight: _canResend
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 52,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
