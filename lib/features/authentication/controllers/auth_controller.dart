import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/firebase/firebase_phone_otp_service.dart';
import 'package:chirag_accounting/core/services/secure_storage_service.dart';
import 'package:chirag_accounting/core/services/session_service.dart';
import 'package:chirag_accounting/features/authentication/models/auth_token_model.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/authentication/services/auth_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

AuthUserType resolveAuthUserTypeForRoles(
  Set<UserRole>? allowedRoles, {
  UserRole? currentRole,
}) {
  if (allowedRoles != null && allowedRoles.isNotEmpty) {
    if (allowedRoles.any((role) => role.isStaff)) return AuthUserType.staff;
    if (allowedRoles.any((role) => role.isBusinessOwner)) {
      return AuthUserType.business;
    }
    return AuthUserType.client;
  }
  if (currentRole?.isBusinessOwner == true) return AuthUserType.business;
  if (currentRole?.isStaff == true) return AuthUserType.staff;
  return AuthUserType.client;
}

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebasePhoneOtpService _firebasePhoneOtp = FirebasePhoneOtpService();

  AuthState _state = AuthState.initial;
  UserModel? _currentUser;
  AuthTokenModel? _currentToken;
  String? _errorMessage;
  String? _pendingOtpTarget;
  String? _pendingPasswordResetChallengeId;
  String? _pendingPasswordResetToken;
  Set<UserRole>? _pendingAllowedRoles;

  AuthState get state => _state;
  UserModel? get currentUser => _currentUser;
  AuthTokenModel? get currentToken => _currentToken;
  String? get errorMessage => _errorMessage;
  String? get pendingOtpTarget => _pendingOtpTarget;
  String? get pendingPasswordResetToken => _pendingPasswordResetToken;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  bool _shouldUseSessionTimeout(UserRole? role) {
    if (role == null) return true;
    return role != UserRole.client;
  }

  void _configureSessionLifecycle(UserRole? role) {
    SessionService.setOnSessionExpired(logout);
    if (_shouldUseSessionTimeout(role)) {
      SessionService.startSessionTimer();
    } else {
      // Client sessions stay persistent on mobile-style flows.
      SessionService.stopSessionTimer();
    }
  }

  Future<void> checkSession() async {
    _state = AuthState.loading;
    notifyListeners();
    try {
      final isValid = await SessionService.isSessionValid();
      if (isValid) {
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString('current_user');
        if (userJson != null) {
          _currentUser = UserModel.fromJson(jsonDecode(userJson));
          _configureSessionLifecycle(_currentUser?.role);
          _state = AuthState.authenticated;
        } else {
          _state = AuthState.unauthenticated;
        }
      } else {
        await SessionService.clearSession();
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> sendOTP(String mobile, {Set<UserRole>? allowedRoles}) async {
    _setState(AuthState.loading);
    try {
      if (ApiConstants.useMockApi) {
        await _authService.sendOTP(
          mobile,
          userType: resolveAuthUserTypeForRoles(
            allowedRoles,
            currentRole: _currentUser?.role,
          ),
          channel: AuthOtpChannel.sms,
          purpose: AuthOtpPurpose.login,
        );
      } else {
        await _firebasePhoneOtp.sendOtp(mobile);
      }
      _pendingOtpTarget = mobile;
      _pendingAllowedRoles = allowedRoles;
      _setState(AuthState.initial);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Failed to send OTP. Please try again.');
      return false;
    }
  }

  Future<bool> verifyOTP(String otp) async {
    if (_pendingOtpTarget == null) return false;
    _setState(AuthState.loading);
    try {
      final result = ApiConstants.useMockApi
          ? await _authService.verifyOTP(
              mobile: _pendingOtpTarget!,
              otp: otp,
              purpose: AuthOtpPurpose.login,
            )
          : await _authService.loginWithFirebasePhone(
              idToken: await _firebasePhoneOtp.verifyOtp(otp),
              userType: resolveAuthUserTypeForRoles(
                _pendingAllowedRoles,
                currentRole: _currentUser?.role,
              ),
            );

      if (!_isAllowedRole(result.user.role, _pendingAllowedRoles)) {
        _pendingAllowedRoles = null;
        throw const AuthException(
          'This account is not allowed for the selected login option.',
        );
      }

      await _onLoginSuccess(result.user, result.token);
      _pendingAllowedRoles = null;
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('OTP verification failed. Please try again.');
      return false;
    }
  }

  Future<bool> loginWithPassword({
    required String emailOrMobile,
    required String password,
    Set<UserRole>? allowedRoles,
  }) async {
    _setState(AuthState.loading);
    try {
      final roleType = resolveAuthUserTypeForRoles(
        allowedRoles,
        currentRole: _currentUser?.role,
      );
      final result = await _authService.loginWithPassword(
        emailOrMobile: emailOrMobile,
        password: password,
        userType: roleType,
      );

      if (!_isAllowedRole(result.user.role, allowedRoles)) {
        throw const AuthException(
          'This account is not allowed for the selected login option.',
        );
      }

      await _onLoginSuccess(result.user, result.token);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Login failed. Please try again.');
      return false;
    }
  }

  Future<bool> forgotPassword(String emailOrMobile) async {
    _setState(AuthState.loading);
    try {
      _pendingPasswordResetChallengeId =
          await _authService.forgotPassword(emailOrMobile);
      _pendingPasswordResetToken = null;
      _pendingOtpTarget = emailOrMobile.trim();
      _setState(AuthState.initial);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Failed to initiate password reset. Please try again.');
      return false;
    }
  }

  Future<bool> verifyPasswordResetOtp(String otp) async {
    final challengeId = _pendingPasswordResetChallengeId;
    if (challengeId == null) {
      _setError('Please request a new password reset code.');
      return false;
    }
    _setState(AuthState.loading);
    try {
      _pendingPasswordResetToken = await _authService.verifyPasswordResetOtp(
        challengeId: challengeId,
        otp: otp,
      );
      _pendingPasswordResetChallengeId = null;
      _setState(AuthState.initial);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('OTP verification failed. Please try again.');
      return false;
    }
  }

  Future<bool> sendPasswordChangeOtp(String mobile) async {
    _setState(AuthState.loading);
    try {
      if (ApiConstants.useMockApi) {
        throw const AuthException('Firebase OTP is not available with the mock API.');
      }
      await _firebasePhoneOtp.sendOtp(mobile);
      _setState(AuthState.initial);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Failed to send password-change OTP. Please try again.');
      return false;
    }
  }

  Future<bool> changePasswordWithFirebaseOtp({
    required String otp,
    required String newPassword,
  }) async {
    _setState(AuthState.loading);
    try {
      if (ApiConstants.useMockApi) {
        throw const AuthException('Firebase OTP is not available with the mock API.');
      }
      final idToken = await _firebasePhoneOtp.verifyOtp(otp);
      await _authService.changePasswordWithFirebaseOtp(
        idToken: idToken,
        newPassword: newPassword,
      );
      _setState(AuthState.initial);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Password change verification failed. Please try again.');
      return false;
    }
  }

  Future<bool> resetPassword({
    required String newPassword,
  }) async {
    final resetToken = _pendingPasswordResetToken;
    if (resetToken == null) {
      _setError('Please verify the password reset code again.');
      return false;
    }
    _setState(AuthState.loading);
    try {
      await _authService.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      _pendingOtpTarget = null;
      _pendingPasswordResetChallengeId = null;
      _pendingPasswordResetToken = null;
      _setState(AuthState.initial);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Failed to reset password. Please try again.');
      return false;
    }
  }

  Future<bool> registerUser({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required String firmName,
    required UserRole role,
    String? gstin,
    String? pan,
    String? state,
    String? city,
  }) async {
    _setState(AuthState.loading);
    try {
      await _authService.register(
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        firmName: firmName,
        role: role,
        gstin: gstin,
        pan: pan,
        state: state,
        city: city,
      );
      _setState(AuthState.initial);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Registration failed. Please try again.');
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logoutApi();
    if (!ApiConstants.useMockApi) await _firebasePhoneOtp.signOut();
    await SessionService.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    _currentUser = null;
    _currentToken = null;
    _pendingOtpTarget = null;
    _pendingPasswordResetChallengeId = null;
    _pendingPasswordResetToken = null;
    _pendingAllowedRoles = null;
    _errorMessage = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> _onLoginSuccess(UserModel user, AuthTokenModel token) async {
    _currentUser = user;
    _currentToken = token;
    await SecureStorageService.saveTokens(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
      expiresAt: token.expiresAt,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toJson()));
    _configureSessionLifecycle(user.role);
    _state = AuthState.authenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) _state = AuthState.initial;
    notifyListeners();
  }

  void _setState(AuthState s) {
    _state = s;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _state = AuthState.error;
    notifyListeners();
  }

  bool _isAllowedRole(UserRole role, Set<UserRole>? allowedRoles) {
    if (allowedRoles == null || allowedRoles.isEmpty) return true;
    return allowedRoles.contains(role);
  }
}
