import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_runtime_service.dart';

class FirebasePhoneOtpException implements Exception {
  const FirebasePhoneOtpException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebasePhoneOtpService {
  FirebasePhoneOtpService({FirebaseAuth? auth}) : _auth = auth;

  FirebaseAuth? _auth;
  ConfirmationResult? _webConfirmation;
  String? _verificationId;

  FirebaseAuth get _activeAuth {
    if (!FirebaseRuntimeService.instance.isAuthenticationAvailable) {
      throw const FirebasePhoneOtpException(
        'Firebase authentication is not configured for this app.',
      );
    }
    return _auth ??= FirebaseAuth.instance;
  }

  Future<void> sendOtp(String mobile) async {
    if (!FirebaseRuntimeService.instance.isAuthenticationAvailable) {
      throw const FirebasePhoneOtpException(
        'Firebase authentication is not configured for this app.',
      );
    }

    final phoneNumber = _toE164IndianNumber(mobile);
    try {
      if (kIsWeb) {
        _webConfirmation = await _activeAuth.signInWithPhoneNumber(phoneNumber);
        return;
      }

      final completer = Completer<void>();
      await _activeAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          try {
            await _activeAuth.signInWithCredential(credential);
            if (!completer.isCompleted) completer.complete();
          } on FirebaseAuthException catch (error) {
            if (!completer.isCompleted) {
              completer.completeError(_friendlyError(error));
            }
          }
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) completer.completeError(_friendlyError(error));
        },
        codeSent: (verificationId, _) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
      await completer.future;
    } on FirebaseAuthException catch (error) {
      throw _friendlyError(error);
    }
  }

  Future<String> verifyOtp(String otp) async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        final confirmation = _webConfirmation;
        if (confirmation == null) {
          throw const FirebasePhoneOtpException('Please request a new OTP.');
        }
        credential = await confirmation.confirm(otp);
      } else {
        final verificationId = _verificationId;
        if (verificationId == null) {
          throw const FirebasePhoneOtpException('Please request a new OTP.');
        }
        credential = await _activeAuth.signInWithCredential(
          PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: otp,
          ),
        );
      }

      final idToken = await credential.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const FirebasePhoneOtpException('Firebase did not return a login token.');
      }
      return idToken;
    } on FirebaseAuthException catch (error) {
      throw _friendlyError(error);
    }
  }

  Future<void> signOut() async {
    if (!FirebaseRuntimeService.instance.isAuthenticationAvailable) return;
    await _activeAuth.signOut();
  }

  String _toE164IndianNumber(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    throw const FirebasePhoneOtpException('Enter a valid 10-digit Indian mobile number.');
  }

  FirebasePhoneOtpException _friendlyError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return const FirebasePhoneOtpException('Enter a valid mobile number.');
      case 'too-many-requests':
        return const FirebasePhoneOtpException('Too many OTP attempts. Please try again later.');
      case 'invalid-verification-code':
        return const FirebasePhoneOtpException('The OTP is invalid. Please try again.');
      case 'session-expired':
        return const FirebasePhoneOtpException('The OTP has expired. Please request a new one.');
      default:
        return FirebasePhoneOtpException(error.message ?? 'Firebase OTP verification failed.');
    }
  }
}