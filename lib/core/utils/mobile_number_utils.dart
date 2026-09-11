import 'package:flutter/services.dart';

String normalizeIndianMobile(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 10) return digits;
  return digits.substring(digits.length - 10);
}

bool isValidIndianMobile(String value) {
  return normalizeIndianMobile(value).length == 10;
}

List<TextInputFormatter> indianMobileInputFormatters() {
  return <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];
}

String? validateIndianMobile(
  String? value, {
  bool required = false,
  String requiredMessage = 'Mobile number is required',
}) {
  final normalized = normalizeIndianMobile(value ?? '');
  if (normalized.isEmpty) {
    return required ? requiredMessage : null;
  }
  if (normalized.length != 10) {
    return 'Enter a valid 10-digit mobile number';
  }
  return null;
}

String? validateEmailAddress(
  String? value, {
  bool required = false,
  String requiredMessage = 'Email address is required',
}) {
  final email = (value ?? '').trim();
  if (email.isEmpty) {
    return required ? requiredMessage : null;
  }
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  if (!ok) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validateEmailOrIndianMobile(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Required';
  if (raw.contains('@')) {
    return validateEmailAddress(raw, required: true);
  }
  return validateIndianMobile(raw, required: true);
}
