import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  static Future<void> _writePref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> _readPref(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    final expiry = expiresAt.toIso8601String();

    // Persist in secure storage first.
    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
        _storage.write(key: _tokenExpiryKey, value: expiry),
      ]);
    } catch (_) {
      // Fallback path is handled below.
    }

    // Mirror tokens in SharedPreferences as fallback for platforms/environments
    // where secure storage may not be available during startup.
    await Future.wait([
      _writePref(_accessTokenKey, accessToken),
      _writePref(_refreshTokenKey, refreshToken),
      _writePref(_tokenExpiryKey, expiry),
    ]);
  }

  static Future<String?> getAccessToken() async {
    try {
      final secure = await _storage.read(key: _accessTokenKey);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {}
    return _readPref(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    try {
      final secure = await _storage.read(key: _refreshTokenKey);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {}
    return _readPref(_refreshTokenKey);
  }

  static Future<DateTime?> getTokenExpiry() async {
    String? expiry;
    try {
      expiry = await _storage.read(key: _tokenExpiryKey);
    } catch (_) {
      expiry = null;
    }
    expiry ??= await _readPref(_tokenExpiryKey);
    return expiry != null ? DateTime.tryParse(expiry) : null;
  }

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_tokenExpiryKey),
    ]);
  }
}
