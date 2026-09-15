import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/location/indian_location_options.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/core/utils/password_policy.dart';
import 'package:chirag_accounting/shared/widgets/searchable_dropdown_form_field.dart';
import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/authentication/presentation/pages/post_login_destination.dart';
import 'package:chirag_accounting/features/clients/services/referral_program_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firmNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  UserRole _selectedRole = UserRole.client;
  String? _selectedState;
  String? _selectedCity;

  StaffLoginMode get _loginMode => switch (_selectedRole) {
    UserRole.accountant => StaffLoginMode.accountant,
    UserRole.partner => StaffLoginMode.caAuditor,
    _ => StaffLoginMode.client,
  };

  String get _roleLabel => switch (_selectedRole) {
    UserRole.accountant => 'Accountant',
    UserRole.partner => 'CA / Auditor',
    _ => 'Client (Business Owner)',
  };

  @override
  void dispose() {
    _firmNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms & Conditions'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final auth = context.read<AuthController>();
    final success = await auth.registerUser(
      name: _ownerNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobile: normalizeIndianMobile(_mobileCtrl.text),
      password: _passwordCtrl.text,
      firmName: _firmNameCtrl.text.trim(),
      role: _selectedRole,
      gstin: _gstinCtrl.text,
      pan: _panCtrl.text,
      state: _stateCtrl.text,
      city: _cityCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await context.read<ReferralProgramService>().markRegistrationCompleted(
      mobileNumber: normalizeIndianMobile(_mobileCtrl.text),
      email: _emailCtrl.text.trim(),
    );

    final autoLoginSuccess = await auth.loginWithPassword(
      emailOrMobile: normalizeIndianMobile(_mobileCtrl.text),
      password: _passwordCtrl.text,
      allowedRoles: <UserRole>{_selectedRole},
    );
    if (!mounted) return;
    if (autoLoginSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PostLoginDestination()),
        (_) => false,
      );
      return;
    }

    await context.read<AdminUserService>().load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Registration received. Your $_roleLabel account is pending admin approval. Login credentials will be sent after onboarding.',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialMode: _loginMode),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final minContentHeight = viewport.maxHeight > 48
                ? viewport.maxHeight - 48
                : 0.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        Text(
                          _roleLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose the account type you want to register.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        DropdownButtonFormField<UserRole>(
                          key: const ValueKey<String>('registration-role'),
                          initialValue: _selectedRole,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Account Type',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: UserRole.client,
                              child: Text('Client (Business Owner)'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.partner,
                              child: Text('CA / Auditor'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.accountant,
                              child: Text('Accountant'),
                            ),
                          ],
                          onChanged: (role) {
                            if (role != null) {
                              setState(() => _selectedRole = role);
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        _buildField(
                          controller: _firmNameCtrl,
                          label: _selectedRole == UserRole.client
                              ? 'Company / Firm Name'
                              : 'Firm / Practice Name',
                          icon: Icons.business,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _ownerNameCtrl,
                          label: _selectedRole == UserRole.client
                              ? 'Business Owner Name'
                              : 'Full Name',
                          icon: Icons.person_outline,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _emailCtrl,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              validateEmailAddress(value, required: true),
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _mobileCtrl,
                          label: 'Mobile Number',
                          icon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          prefixText: '+91 ',
                          inputFormatters: indianMobileInputFormatters(),
                          validator: (v) {
                            return validateIndianMobile(v, required: true);
                          },
                        ),
                        ...[
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _gstinCtrl,
                            label: 'GSTIN (Optional)',
                            icon: Icons.receipt_long_outlined,
                            maxLength: 15,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(15),
                            ],
                            validator: (value) {
                              final gstin = value?.trim().toUpperCase() ?? '';
                              if (gstin.isEmpty) return null;
                              return RegExp(
                                    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$',
                                  ).hasMatch(gstin)
                                  ? null
                                  : 'Enter a valid GSTIN';
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _panCtrl,
                            label: 'PAN (Optional)',
                            icon: Icons.badge_outlined,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (value) {
                              final pan = value?.trim().toUpperCase() ?? '';
                              if (pan.isEmpty) return null;
                              return RegExp(
                                    r'^[A-Z]{5}[0-9]{4}[A-Z]$',
                                  ).hasMatch(pan)
                                  ? null
                                  : 'Enter a valid PAN';
                            },
                          ),
                          const SizedBox(height: 14),
                          SearchableDropdownFormField<String>(
                            value: _selectedState,
                            items: indianStateOptions,
                            itemLabelBuilder: (state) => state,
                            dialogTitle: 'Select State',
                            hintText: 'Select State',
                            decoration: const InputDecoration(
                              labelText: 'State',
                              prefixIcon: Icon(Icons.map_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null ? 'Select a state' : null,
                            onChanged: (state) => setState(() {
                              _selectedState = state;
                              _selectedCity = null;
                              _stateCtrl.text = state ?? '';
                              _cityCtrl.clear();
                            }),
                          ),
                          const SizedBox(height: 14),
                          SearchableDropdownFormField<String>(
                            value: _selectedCity,
                            items: indianCitiesByState[_selectedState] ??
                                const <String>[],
                            itemLabelBuilder: (city) => city,
                            dialogTitle: 'Select City',
                            hintText: _selectedState == null
                                ? 'Select State First'
                                : 'Select City',
                            decoration: const InputDecoration(
                              labelText: 'City',
                              prefixIcon: Icon(Icons.location_city_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null ? 'Select a city' : null,
                            onChanged: _selectedState == null
                                ? null
                                : (city) => setState(() {
                                      _selectedCity = city;
                                      _cityCtrl.text = city ?? '';
                                    }),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          validator: validatePassword,
                        ),
                        const SizedBox(height: 8),
                        PasswordStrengthGuide(password: _passwordCtrl.text),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (v) =>
                                  setState(() => _acceptedTerms = v ?? false),
                              visualDensity: VisualDensity.compact,
                            ),
                            const Expanded(
                              child: Text(
                                'I accept the Terms & Conditions and Privacy Policy',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    color: Color(0xFF4A5568),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1565C0),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                icon: const Icon(Icons.login_rounded, size: 18),
                                label: const Text('Login'),
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
              ),
            );
          },
            ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        prefixText: prefixText,
        counterText: maxLength != null ? '' : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: validator,
    );
  }
}
