import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/authentication/models/auth_token_model.dart';
import 'package:chirag_accounting/features/authentication/models/user_model.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

export 'package:chirag_accounting/core/services/api_client.dart' show ApiError;

enum AuthUserType { client, business, staff }

enum AuthOtpChannel { sms, email }

enum AuthOtpPurpose { login, twoFactor, passwordReset }

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// Authentication service.
/// When [ApiConstants.useMockApi] is [true], all calls use local mock data
/// (no backend required). Set it to [false] and update [ApiConstants.baseUrl]
/// to switch to your real backend.
class AuthService {
  final Dio _dio = ApiClient.dio;

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _normalizeIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }

    // Keep only digits so users can enter values like "+91 98765 43210".
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return digits;
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return trimmed;
  }

  // ── Mock data (used only when useMockApi == true) ──────────────

  static final Map<String, String> _otpStore = {};

  static final List<UserModel> _mockUsers = [
    UserModel(
      id: 'u001',
      name: 'Chirag Mehta',
      email: 'admin@chiragca.com',
      mobile: '9876543210',
      role: UserRole.admin,
      firmId: 'f001',
      firmName: 'Chirag CA & Associates',
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    UserModel(
      id: 'u002',
      name: 'Priya Sharma',
      email: 'accountant@chiragca.com',
      mobile: '9876543211',
      role: UserRole.accountant,
      firmId: 'f001',
      firmName: 'Chirag CA & Associates',
      isActive: true,
      createdAt: DateTime(2024, 1, 2),
    ),
    UserModel(
      id: 'u003',
      name: 'Ravi Kumar',
      email: 'operator@chiragca.com',
      mobile: '9876543212',
      role: UserRole.manager,
      firmId: 'f001',
      firmName: 'Chirag CA & Associates',
      isActive: true,
      createdAt: DateTime(2024, 2, 1),
    ),
    UserModel(
      id: 'u004',
      name: 'Sanjay Patel',
      email: 'client@example.com',
      mobile: '9876543213',
      role: UserRole.client,
      firmId: 'f001',
      firmName: 'Chirag CA & Associates',
      isActive: true,
      createdAt: DateTime(2024, 3, 1),
    ),
    UserModel(
      id: 'u005',
      name: 'Arjun Shah',
      email: 'owner@acme.com',
      mobile: '9876543214',
      role: UserRole.businessOwner,
      firmId: 'f002',
      firmName: 'Acme Retail Pvt Ltd',
      isActive: true,
      createdAt: DateTime(2024, 3, 3),
    ),
    UserModel(
      id: 'u006',
      name: 'Neha Joshi',
      email: 'partner@chiragca.com',
      mobile: '9876543215',
      role: UserRole.partner,
      firmId: 'f001',
      firmName: 'Chirag CA & Associates',
      isActive: true,
      createdAt: DateTime(2024, 3, 10),
    ),
    UserModel(
      id: 'u007',
      name: 'Vikram Rao',
      email: 'checker@chiragca.com',
      mobile: '9876543216',
      role: UserRole.checker,
      firmId: 'f001',
      firmName: 'Chirag CA & Associates',
      isActive: true,
      createdAt: DateTime(2024, 3, 12),
    ),
  ];

  static final Map<String, String> _passwordStore = <String, String>{};

  static List<UserModel> get mockUsers => List<UserModel>.unmodifiable(_mockUsers);

  static String _hashPassword(String password) {
    final bytes = utf8.encode('${password}chirag_salt_2024');
    return sha256.convert(bytes).toString();
  }

  static String _mockJwt(Map<String, dynamic> payload) {
    final h = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final p = base64Url.encode(utf8.encode(jsonEncode(payload)));
    final s = base64Url.encode(
        utf8.encode('sig_${Random().nextInt(999999)}'));
    return '$h.$p.$s';
  }

  // ── Public API ─────────────────────────────────────────────────

  Future<void> sendOTP(
    String mobile, {
    AuthUserType userType = AuthUserType.client,
    AuthOtpChannel channel = AuthOtpChannel.sms,
    AuthOtpPurpose purpose = AuthOtpPurpose.login,
  }) async {
    if (ApiConstants.useMockApi) {
      await Future.delayed(const Duration(seconds: 1));
      final exists = _mockUsers.any((u) => u.mobile == mobile);
      if (!exists) {
        throw const AuthException(
            'Mobile number not registered. Please register first.');
      }
      final otp = (100000 + Random().nextInt(900000)).toString();
      _otpStore[mobile] = otp;
      assert(() {
        // ignore: avoid_print
        print('[MOCK] OTP for $mobile → $otp');
        return true;
      }());
      return;
    }
    try {
      await _dio.post(ApiConstants.loginOtpSend,
          data: {
            'mobile': mobile,
            'userType': userType.name,
            'channel': channel.name,
            'purpose': purpose.name,
          });
    } on DioException catch (e) {
      throw AuthException(ApiError.fromDioException(e).message);
    }
  }

  Future<({UserModel user, AuthTokenModel token})> verifyOTP({
    required String mobile,
    required String otp,
    AuthOtpPurpose purpose = AuthOtpPurpose.login,
  }) async {
    if (ApiConstants.useMockApi) {
      await Future.delayed(const Duration(seconds: 1));
      final stored = _otpStore[mobile];
      if (stored == null) {
        throw const AuthException('OTP expired. Please request a new one.');
      }
      if (stored != otp) {
        throw const AuthException('Invalid OTP. Please try again.');
      }
      _otpStore.remove(mobile);
      final user = _mockUsers.firstWhere(
        (u) => u.mobile == mobile,
        orElse: () => throw const AuthException('User not found.'),
      );
      return _mockAuthResponse(user);
    }
    try {
      final res = await _dio.post(ApiConstants.loginOtpVerify,
          data: {'mobile': mobile, 'otp': otp, 'purpose': purpose.name});
      return _parseAuthResponse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(ApiError.fromDioException(e).message);
    }
  }

  Future<({UserModel user, AuthTokenModel token})> loginWithFirebasePhone({
    required String idToken,
    required AuthUserType userType,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.firebasePhoneLogin,
        data: {'idToken': idToken, 'userType': userType.name},
      );
      return _parseAuthResponse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(ApiError.fromDioException(e).message);
    }
  }

  Future<({UserModel user, AuthTokenModel token})> loginWithPassword({
    required String emailOrMobile,
    required String password,
    AuthUserType userType = AuthUserType.staff,
  }) async {
    final normalizedIdentifier = _normalizeIdentifier(emailOrMobile);

    if (ApiConstants.useMockApi) {
      await Future.delayed(const Duration(seconds: 1));
      final key = normalizedIdentifier;
      final stored = _passwordStore[key];
      if (stored == null) {
        throw const AuthException(
            'Account not found. Please check your credentials.');
      }
      if (stored != _hashPassword(password)) {
        throw const AuthException('Invalid password. Please try again.');
      }
      final user = _mockUsers.firstWhere(
        (u) => u.email == key || u.mobile == key,
        orElse: () => throw const AuthException('User not found.'),
      );
      return _mockAuthResponse(user);
    }
    try {
      final isEmail = normalizedIdentifier.contains('@');
      final payload = <String, dynamic>{
        'identifier': normalizedIdentifier,
        'emailOrMobile': normalizedIdentifier,
        'password': password,
        'userType': userType.name,
      };
      if (isEmail) {
        payload['email'] = normalizedIdentifier;
      } else {
        payload['mobile'] = normalizedIdentifier;
        payload['phone'] = normalizedIdentifier;
      }

      final res = await _dio.post(ApiConstants.login, data: payload);
      return _parseAuthResponse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(ApiError.fromDioException(e).message);
    }
  }

  Future<void> register({
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
    final normalizedEmail = _normalizeIdentifier(email);
    final normalizedMobile = _normalizeIdentifier(mobile);

    if (ApiConstants.useMockApi) {
      await Future.delayed(const Duration(milliseconds: 700));

      final exists = _mockUsers.any(
        (u) => u.email == normalizedEmail || u.mobile == normalizedMobile,
      );
      if (exists) {
        throw const AuthException(
            'Account already exists with this email or mobile.');
      }

      final nextId = 'u${(_mockUsers.length + 1).toString().padLeft(3, '0')}';
      final user = UserModel(
        id: nextId,
        name: name.trim(),
        email: normalizedEmail,
        mobile: normalizedMobile,
        role: role,
        firmId: 'f${(100 + _mockUsers.length + 1).toString()}',
        firmName: firmName.trim(),
        isActive: true,
        createdAt: DateTime.now(),
      );

      _mockUsers.add(user);
      final hashed = _hashPassword(password);
      _passwordStore[normalizedEmail] = hashed;
      _passwordStore[normalizedMobile] = hashed;
      return;
    }

    try {
      await _dio.post(ApiConstants.register, data: {
        'name': name.trim(),
        'fullName': name.trim(),
        'email': normalizedEmail,
        'mobile': normalizedMobile,
        'phone': normalizedMobile,
        'phoneNumber': normalizedMobile,
        'password': password,
        'firmName': firmName.trim(),
        'companyName': firmName.trim(),
        'role': role.name,
        if (gstin != null && gstin.trim().isNotEmpty)
          'gstin': gstin.trim().toUpperCase(),
        if (pan != null && pan.trim().isNotEmpty)
          'pan': pan.trim().toUpperCase(),
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      });
    } on DioException catch (e) {
      throw AuthException(ApiError.fromDioException(e).message);
    }
  }

  Future<void> forgotPassword(String emailOrMobile) async {
    if (ApiConstants.useMockApi) {
      await Future.delayed(const Duration(seconds: 1));
      final key = emailOrMobile.toLowerCase().trim();
      final exists = _mockUsers.any(
          (u) => u.email == key || u.mobile == emailOrMobile.trim());
      if (!exists) {
        throw const AuthException(
            'No account found with this email or mobile.');
      }
      final otp = (100000 + Random().nextInt(900000)).toString();
      _otpStore[emailOrMobile.trim()] = otp;
      assert(() {
        // ignore: avoid_print
        print('[MOCK] Reset OTP for ${emailOrMobile.trim()} → $otp');
        return true;
      }());
      return;
    }
    try {
      await _dio.post(ApiConstants.forgotPassword,
          data: {
            'identifier': emailOrMobile.trim(),
            'emailOrMobile': emailOrMobile.trim(),
          });
    } on DioException catch (e) {
      throw AuthException(ApiError.fromDioException(e).message);
    }
  }

  Future<void> resetPassword({
    required String emailOrMobile,
    required String otp,
    required String newPassword,
  }) async {
    if (ApiConstants.useMockApi) {
      await Future.delayed(const Duration(seconds: 1));
      final stored = _otpStore[emailOrMobile.trim()];
      if (stored == null || stored != otp) {
        throw const AuthException('Invalid or expired OTP.');
      }
      _otpStore.remove(emailOrMobile.trim());
      final key = emailOrMobile.toLowerCase().trim();
      _passwordStore[key] = _hashPassword(newPassword);
      return;
    }
    try {
      await _dio.post(ApiConstants.resetPassword, data: {
        'identifier': emailOrMobile.trim(),
        'emailOrMobile': emailOrMobile.trim(),
        'otp': otp,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      throw AuthException(ApiError.fromDioException(e).message);
    }
  }

  Future<void> logoutApi() async {
    if (ApiConstants.useMockApi) return;
    try {
      await _dio.post(ApiConstants.logout);
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────

  ({UserModel user, AuthTokenModel token}) _mockAuthResponse(UserModel user) {
    final now = DateTime.now();
    final exp = now.add(const Duration(hours: 1));
    return (
      user: user,
      token: AuthTokenModel(
        accessToken: _mockJwt({
          'sub': user.id,
          'role': user.role.name,
          'firmId': user.firmId,
          'email': user.email,
          'iat': now.millisecondsSinceEpoch ~/ 1000,
          'exp': exp.millisecondsSinceEpoch ~/ 1000,
        }),
        refreshToken: _mockJwt({
          'sub': user.id,
          'type': 'refresh',
          'iat': now.millisecondsSinceEpoch ~/ 1000,
        }),
        expiresAt: exp,
      ),
    );
  }

  ({UserModel user, AuthTokenModel token}) _parseAuthResponse(
      Map<String, dynamic> data) {
    try {
      final root =
          (data['data'] is Map<String, dynamic>) ? data['data'] as Map<String, dynamic> : data;
      final tokenNode =
          (root['token'] is Map<String, dynamic>) ? root['token'] as Map<String, dynamic> : root;
      final userJson = (root['user'] is Map<String, dynamic>)
          ? root['user'] as Map<String, dynamic>
          : (data['user'] is Map<String, dynamic>)
              ? data['user'] as Map<String, dynamic>
              : <String, dynamic>{};

      final accessToken = _readString(tokenNode, ['accessToken', 'access_token', 'token']) ??
          _readString(root, ['accessToken', 'access_token', 'token']);
      final refreshToken = _readString(tokenNode, ['refreshToken', 'refresh_token']) ??
          _readString(root, ['refreshToken', 'refresh_token']) ??
          '';
      final expiresAtRaw = _readString(tokenNode, ['expiresAt', 'expires_at']) ??
          _readString(root, ['expiresAt', 'expires_at']);
      final expiresAt = expiresAtRaw != null
          ? DateTime.tryParse(expiresAtRaw) ?? DateTime.now().add(const Duration(hours: 1))
          : DateTime.now().add(const Duration(hours: 1));

      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthException('Missing access token in server response.');
      }

      return (
        user: UserModel.fromJson(userJson),
        token: AuthTokenModel(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
        ),
      );
    } catch (_) {
      throw const AuthException(
          'Unexpected server response. Please contact support.');
    }
  }
}
