import 'dart:async';
import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class SessionService {
  static Timer? _sessionTimer;
  static const Duration sessionTimeout = Duration(minutes: 30);
  static VoidCallback? _onSessionExpired;

  static void setOnSessionExpired(VoidCallback callback) {
    _onSessionExpired = callback;
  }

  static void startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(sessionTimeout, () {
      _onSessionExpired?.call();
    });
  }

  static void resetTimer() {
    if (_sessionTimer != null) {
      startSessionTimer();
    }
  }

  static void stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  static Future<bool> isSessionValid() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null) return false;

    final refreshToken = await SecureStorageService.getRefreshToken();
    final expiry = await SecureStorageService.getTokenExpiry();

    // If expiry metadata is unavailable, keep the user logged in as long as
    // at least one token is present. API layer can refresh as needed.
    if (expiry == null) {
      return refreshToken != null && refreshToken.isNotEmpty;
    }

    if (DateTime.now().isBefore(expiry)) return true;

    // If access token is expired but refresh token exists, do not force logout
    // during app refresh/startup.
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  static Future<void> clearSession() async {
    stopSessionTimer();
    await SecureStorageService.clearAll();
  }
}
