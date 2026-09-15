import 'package:flutter/material.dart';

enum PasswordStrength { low, medium, strong }

bool isPasswordValid(String value) =>
    value.length >= 8 &&
    RegExp(r'[A-Z]').hasMatch(value) &&
    RegExp(r'[a-z]').hasMatch(value) &&
    RegExp(r'[0-9]').hasMatch(value) &&
    RegExp(r'[^A-Za-z0-9]').hasMatch(value);

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Password is required';
  if (password.length < 8) return 'Use at least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Add an uppercase letter';
  if (!RegExp(r'[a-z]').hasMatch(password)) return 'Add a lowercase letter';
  if (!RegExp(r'[0-9]').hasMatch(password)) return 'Add a number';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) return 'Add a special character';
  return null;
}

PasswordStrength passwordStrength(String value) {
  var score = 0;
  if (value.length >= 8) score++;
  if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) score++;
  if (RegExp(r'[0-9]').hasMatch(value)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
  return score >= 4
      ? PasswordStrength.strong
      : score >= 2
      ? PasswordStrength.medium
      : PasswordStrength.low;
}

class PasswordStrengthGuide extends StatelessWidget {
  const PasswordStrengthGuide({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(password);
    final color = switch (strength) {
      PasswordStrength.low => const Color(0xFFC62828),
      PasswordStrength.medium => const Color(0xFFEF6C00),
      PasswordStrength.strong => const Color(0xFF2E7D32),
    };
    final label = switch (strength) {
      PasswordStrength.low => 'Low',
      PasswordStrength.medium => 'Medium',
      PasswordStrength.strong => 'Strong',
    };
    final progress = switch (strength) {
      PasswordStrength.low => 0.33,
      PasswordStrength.medium => 0.66,
      PasswordStrength.strong => 1.0,
    };

    return Semantics(
      label: 'Password strength: $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Password strength', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: progress, color: color, backgroundColor: const Color(0xFFE0E0E0)),
          const SizedBox(height: 8),
          const Text(
            'Use 8+ characters, uppercase, lowercase, number, and special character.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
          ),
        ],
      ),
    );
  }
}