import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebasePhoneAuthGateway {
  FirebasePhoneAuthGateway._();

  static final FirebasePhoneAuthGateway instance = FirebasePhoneAuthGateway._();

  String? _verificationId;
  ConfirmationResult? _webConfirmation;

  Future<void> sendCode(String mobile) async {
    final phone = '+91${mobile.replaceAll(RegExp(r'\D'), '')}';
    if (kIsWeb) {
      _webConfirmation = await FirebaseAuth.instance.signInWithPhoneNumber(
        phone,
      );
      return;
    }

    final completer = Completer<void>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  Future<String> verifyCode(String code) async {
    UserCredential credential;
    if (kIsWeb) {
      final confirmation = _webConfirmation;
      if (confirmation == null) throw StateError('Request a new OTP first.');
      credential = await confirmation.confirm(code);
    } else {
      final verificationId = _verificationId;
      if (verificationId == null) throw StateError('Request a new OTP first.');
      credential = await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
    }
    final token = await credential.user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase did not return an identity token.');
    }
    _verificationId = null;
    _webConfirmation = null;
    return token;
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
