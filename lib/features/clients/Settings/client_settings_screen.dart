import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/services/client_settings_service.dart';

class ClientSettingsScreen extends StatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final ClientSettingsService _settingsService = ClientSettingsService();

  bool _isLoading = true;
  bool _isSendingOtp = false;
  bool _isChangingPassword = false;
  bool _multipleLoginAllowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final value = await _settingsService.isMultipleLoginAllowed(user.id);
    if (!mounted) return;
    setState(() {
      _multipleLoginAllowed = value;
      _isLoading = false;
    });
  }

  Future<void> _sendPasswordOtp() async {
    final auth = context.read<AuthController>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isSendingOtp = true);
    final ok = await auth.forgotPassword(user.mobile);
    if (!mounted) return;
    setState(() => _isSendingOtp = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'OTP sent to registered mobile for password change.'
            : (auth.errorMessage ?? 'Failed to send OTP')),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    setState(() => _isChangingPassword = true);

    final success = await auth.resetPassword(
      otp: _otpCtrl.text.trim(),
      newPassword: _newPasswordCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isChangingPassword = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Password changed successfully.'
            : (auth.errorMessage ?? 'Password change failed.')),
      ),
    );

    if (success) {
      _otpCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
    }
  }

  Future<void> _toggleMultipleLogin(bool value) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    setState(() => _multipleLoginAllowed = value);
    await _settingsService.setMultipleLoginAllowed(user.id, value);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'Multiple mobile login enabled for this account.'
            : 'Multiple mobile login disabled for this account.'),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required field';
    return null;
  }

  String? _confirmValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required field';
    if (value.trim() != _newPasswordCtrl.text.trim()) {
      return 'Password does not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Settings'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('Allow Multiple Login (Mobile App)'),
                subtitle: const Text(
                  'Enable same account login on multiple mobile devices.',
                ),
                value: _multipleLoginAllowed,
                onChanged: _toggleMultipleLogin,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change Password (OTP based)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Send OTP first, then submit OTP and new password.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSendingOtp ? null : _sendPasswordOtp,
                        icon: _isSendingOtp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sms_outlined),
                        label:
                            Text(_isSendingOtp ? 'Sending OTP...' : 'Send OTP'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Form(
                      key: _passwordFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'OTP'),
                            validator: _required,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _newPasswordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'New Password'),
                            validator: _required,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Confirm Password'),
                            validator: _confirmValidator,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isChangingPassword ? null : _changePassword,
                              icon: _isChangingPassword
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.lock_reset_outlined),
                              label: Text(_isChangingPassword
                                  ? 'Updating...'
                                  : 'Update Password'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
