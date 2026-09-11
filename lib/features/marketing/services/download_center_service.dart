import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MobileAppAvailability { comingSoon, available }

@immutable
class DownloadCenterSettings {
  const DownloadCenterSettings({
    this.androidUrl = '',
    this.iosUrl = '',
    this.webAppUrl = '',
    this.androidStatus = MobileAppAvailability.comingSoon,
    this.iosStatus = MobileAppAvailability.comingSoon,
    this.androidVersion = '',
    this.iosVersion = '',
    this.releaseNotes = '',
  });

  final String androidUrl;
  final String iosUrl;
  final String webAppUrl;
  final MobileAppAvailability androidStatus;
  final MobileAppAvailability iosStatus;
  final String androidVersion;
  final String iosVersion;
  final String releaseNotes;

  bool get androidAvailable =>
      androidStatus == MobileAppAvailability.available &&
      isValidExternalUrl(androidUrl);

  bool get iosAvailable =>
      iosStatus == MobileAppAvailability.available &&
      isValidExternalUrl(iosUrl);

  bool get hasWebAppUrl => isValidExternalUrl(webAppUrl);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'androidUrl': androidUrl,
    'iosUrl': iosUrl,
    'webAppUrl': webAppUrl,
    'androidStatus': androidStatus.name,
    'iosStatus': iosStatus.name,
    'androidVersion': androidVersion,
    'iosVersion': iosVersion,
    'releaseNotes': releaseNotes,
  };

  factory DownloadCenterSettings.fromJson(Map<String, dynamic> json) {
    MobileAppAvailability availability(String key) {
      return MobileAppAvailability.values.firstWhere(
        (value) => value.name == json[key]?.toString(),
        orElse: () => MobileAppAvailability.comingSoon,
      );
    }

    return DownloadCenterSettings(
      androidUrl: json['androidUrl']?.toString().trim() ?? '',
      iosUrl: json['iosUrl']?.toString().trim() ?? '',
      webAppUrl: json['webAppUrl']?.toString().trim() ?? '',
      androidStatus: availability('androidStatus'),
      iosStatus: availability('iosStatus'),
      androidVersion: json['androidVersion']?.toString().trim() ?? '',
      iosVersion: json['iosVersion']?.toString().trim() ?? '',
      releaseNotes: json['releaseNotes']?.toString().trim() ?? '',
    );
  }

  static bool isValidExternalUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}

class DownloadCenterService extends ChangeNotifier {
  DownloadCenterService({SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'admin_download_center_settings_v1';

  final SharedPreferences? _preferences;
  DownloadCenterSettings _settings = const DownloadCenterSettings();

  DownloadCenterSettings get settings => _settings;

  Future<void> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final stored = preferences.getString(storageKey);
    if (stored != null && stored.trim().isNotEmpty) {
      final decoded = jsonDecode(stored);
      if (decoded is Map) {
        _settings = DownloadCenterSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    }
    notifyListeners();
  }

  Future<void> save(DownloadCenterSettings settings) async {
    _validateAvailableUrl(
      platform: 'Android',
      status: settings.androidStatus,
      url: settings.androidUrl,
    );
    _validateAvailableUrl(
      platform: 'iOS',
      status: settings.iosStatus,
      url: settings.iosUrl,
    );
    if (settings.webAppUrl.trim().isNotEmpty && !settings.hasWebAppUrl) {
      throw const FormatException('Enter a valid Web App URL.');
    }

    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(settings.toJson()));
    _settings = settings;
    notifyListeners();
  }

  void _validateAvailableUrl({
    required String platform,
    required MobileAppAvailability status,
    required String url,
  }) {
    if (status == MobileAppAvailability.available &&
        !DownloadCenterSettings.isValidExternalUrl(url)) {
      throw FormatException(
        '$platform URL is required when status is Available.',
      );
    }
  }
}
