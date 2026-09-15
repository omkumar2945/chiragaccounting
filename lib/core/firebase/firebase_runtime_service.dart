import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_environment_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && FirebaseEnvironmentOptions.isConfigured) {
    await Firebase.initializeApp(options: FirebaseEnvironmentOptions.current);
  }
}

enum FirebaseFeatureState {
  active,
  permissionRequired,
  notConfigured,
  unsupported,
  failed,
}

class FirebaseFeatureStatus {
  const FirebaseFeatureStatus(this.state, this.message);

  final FirebaseFeatureState state;
  final String message;
}

class FirebaseRuntimeService extends ChangeNotifier {
  FirebaseRuntimeService._();

  static final FirebaseRuntimeService instance = FirebaseRuntimeService._();

  bool _initialized = false;
  String? _messagingToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  final Map<String, FirebaseFeatureStatus> _statuses = {};

  bool get initialized => _initialized;
  String? get messagingToken => _messagingToken;
  Map<String, FirebaseFeatureStatus> get statuses =>
      Map.unmodifiable(_statuses);
  bool get isAuthenticationAvailable =>
      _statuses['Authentication']?.state == FirebaseFeatureState.active;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!FirebaseEnvironmentOptions.platformSupported) {
      _setAllUnsupported('Firebase is not supported on this platform.');
      return;
    }
    if (!FirebaseEnvironmentOptions.isConfigured) {
      _setAllNotConfigured();
      return;
    }

    try {
      await Firebase.initializeApp(options: FirebaseEnvironmentOptions.current);
      _initialized = true;
      _statuses['Authentication'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.active,
        'Firebase phone OTP is ready. Chirag roles remain authoritative.',
      );
      _initializeStorage();
      await _initializeMessaging();
      await _initializeAnalytics();
      await _initializeCrashlytics();
    } catch (error) {
      _statuses['Core'] = FirebaseFeatureStatus(
        FirebaseFeatureState.failed,
        'Firebase initialization failed: $error',
      );
    }
    notifyListeners();
  }

  Future<void> refreshMessagingPermission() async {
    if (!_initialized || !_supportsMessaging) return;
    await _initializeMessaging();
    notifyListeners();
  }

  void _initializeStorage() {
    try {
      final bucket = FirebaseStorage.instance.bucket;
      _statuses['Storage'] = FirebaseFeatureStatus(
        FirebaseFeatureState.active,
        bucket.isEmpty ? 'Firebase Storage is ready.' : 'Bucket: $bucket',
      );
    } catch (error) {
      _statuses['Storage'] = FirebaseFeatureStatus(
        FirebaseFeatureState.failed,
        'Storage unavailable: $error',
      );
    }
  }

  Future<void> _initializeMessaging() async {
    if (!_supportsMessaging) {
      _statuses['Cloud Messaging'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.unsupported,
        'FCM is not supported on Windows.',
      );
      _statuses['Push Notification Status'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.unsupported,
        'Push notifications are unavailable on this platform.',
      );
      return;
    }
    if (kIsWeb && FirebaseEnvironmentOptions.webVapidKey.isEmpty) {
      _statuses['Cloud Messaging'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.notConfigured,
        'Firebase Cloud Messaging is not configured for web.',
      );
      _statuses['Push Notification Status'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.notConfigured,
        'Web push notifications are not configured.',
      );
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        _statuses['Cloud Messaging'] = const FirebaseFeatureStatus(
          FirebaseFeatureState.permissionRequired,
          'Notification permission is not granted.',
        );
        _statuses['Push Notification Status'] = const FirebaseFeatureStatus(
          FirebaseFeatureState.permissionRequired,
          'Ask the user to enable notifications.',
        );
        return;
      }
      _messagingToken = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb && FirebaseEnvironmentOptions.webVapidKey.isNotEmpty
            ? FirebaseEnvironmentOptions.webVapidKey
            : null,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((token) {
            _messagingToken = token;
            notifyListeners();
          });
      _statuses['Cloud Messaging'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.active,
        'FCM is connected.',
      );
      _statuses['Push Notification Status'] = FirebaseFeatureStatus(
        FirebaseFeatureState.active,
        _messagingToken == null
            ? 'Permission granted; token pending.'
            : 'Permission granted and token issued.',
      );
    } catch (error) {
      _statuses['Cloud Messaging'] = FirebaseFeatureStatus(
        FirebaseFeatureState.failed,
        'FCM unavailable: $error',
      );
      _statuses['Push Notification Status'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.failed,
        'Push notification setup failed.',
      );
    }
  }

  Future<void> _initializeAnalytics() async {
    if (!_supportsAnalytics) {
      _statuses['Analytics'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.unsupported,
        'Firebase Analytics is not supported on Windows.',
      );
      return;
    }
    if (FirebaseEnvironmentOptions.measurementId.isEmpty) {
      _statuses['Analytics'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.notConfigured,
        'Firebase Analytics is not configured for this app.',
      );
      return;
    }
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      _statuses['Analytics'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.active,
        'Analytics collection is enabled.',
      );
    } catch (error) {
      _statuses['Analytics'] = FirebaseFeatureStatus(
        FirebaseFeatureState.failed,
        'Analytics unavailable: $error',
      );
    }
  }

  Future<void> _initializeCrashlytics() async {
    if (!_supportsCrashlytics) {
      _statuses['Crashlytics'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.unsupported,
        'Crashlytics is supported on Android, iOS, and macOS only.',
      );
      return;
    }
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _statuses['Crashlytics'] = const FirebaseFeatureStatus(
        FirebaseFeatureState.active,
        'Crash reporting is enabled.',
      );
    } catch (error) {
      _statuses['Crashlytics'] = FirebaseFeatureStatus(
        FirebaseFeatureState.failed,
        'Crashlytics unavailable: $error',
      );
    }
  }

  bool get _supportsMessaging =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  bool get _supportsAnalytics =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  bool get _supportsCrashlytics =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  void _setAllNotConfigured() {
    const status = FirebaseFeatureStatus(
      FirebaseFeatureState.notConfigured,
      'Add Firebase project options to activate this service.',
    );
    for (final name in _featureNames) {
      _statuses[name] = status;
    }
    notifyListeners();
  }

  void _setAllUnsupported(String message) {
    final status = FirebaseFeatureStatus(
      FirebaseFeatureState.unsupported,
      message,
    );
    for (final name in _featureNames) {
      _statuses[name] = status;
    }
    notifyListeners();
  }

  static const _featureNames = <String>[
    'Authentication',
    'Cloud Messaging',
    'Push Notification Status',
    'Storage',
    'Analytics',
    'Crashlytics',
  ];

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
