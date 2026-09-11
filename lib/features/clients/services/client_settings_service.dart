import 'package:shared_preferences/shared_preferences.dart';

class ClientSettingsService {
  static String _multipleLoginKey(String userId) =>
      'client_multiple_login_allowed_$userId';

  Future<bool> isMultipleLoginAllowed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_multipleLoginKey(userId)) ?? false;
  }

  Future<void> setMultipleLoginAllowed(String userId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_multipleLoginKey(userId), value);
  }
}
