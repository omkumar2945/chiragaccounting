import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum MicrophonePermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
  unknown,
}

class MicrophonePermissionDecision {
  const MicrophonePermissionDecision({
    required this.status,
    this.wasRequested = false,
    this.deniedBySystemDialog = false,
    this.settingsOpened = false,
  });

  final MicrophonePermissionStatus status;
  final bool wasRequested;
  final bool deniedBySystemDialog;
  final bool settingsOpened;
}

class MicrophonePermissionService {
  MicrophonePermissionService({stt.SpeechToText? speechEngine})
    : _speechEngine = speechEngine ?? stt.SpeechToText();

  final stt.SpeechToText _speechEngine;

  MicrophonePermissionDecision _lastDecision =
      const MicrophonePermissionDecision(status: MicrophonePermissionStatus.unknown);

  MicrophonePermissionDecision get lastDecision => _lastDecision;

  Future<MicrophonePermissionStatus> checkPermission() async {
    try {
      if (!_supportsPermissionApi) {
        return MicrophonePermissionStatus.unknown;
      }
      final status = await ph.Permission.microphone.status;
      return _mapPermissionStatus(status);
    } catch (_) {
      return MicrophonePermissionStatus.unknown;
    }
  }

  Future<MicrophonePermissionStatus> requestPermission() async {
    try {
      if (!_supportsPermissionApi) {
        return await checkPermission();
      }
      final status = await ph.Permission.microphone.request();
      return _mapPermissionStatus(status);
    } catch (_) {
      return MicrophonePermissionStatus.unknown;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      if (!_supportsSettingsOpen) return false;
      return ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isMicrophoneAvailable() async {
    try {
      final available = await _speechEngine.initialize();
      return available;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureMicrophoneReady() async {
    final decision = await ensureMicrophoneReadyWithDecision();
    return decision.status == MicrophonePermissionStatus.granted;
  }

  Future<MicrophonePermissionDecision> ensureMicrophoneReadyWithDecision() async {
    if (kIsWeb) {
      final available = await isMicrophoneAvailable();
      _lastDecision = MicrophonePermissionDecision(
        status: available
            ? MicrophonePermissionStatus.granted
            : MicrophonePermissionStatus.unknown,
      );
      return _lastDecision;
    }

    final current = await checkPermission();

    if (current == MicrophonePermissionStatus.granted) {
      final available = await isMicrophoneAvailable();
      _lastDecision = MicrophonePermissionDecision(
        status: available
            ? MicrophonePermissionStatus.granted
            : MicrophonePermissionStatus.unavailable,
      );
      return _lastDecision;
    }

    if (current == MicrophonePermissionStatus.permanentlyDenied ||
        current == MicrophonePermissionStatus.restricted) {
      final opened = await openAppSettings();
      _lastDecision = MicrophonePermissionDecision(
        status: current,
        settingsOpened: opened,
      );
      return _lastDecision;
    }

    if (current == MicrophonePermissionStatus.denied) {
      final requested = await requestPermission();
      if (requested == MicrophonePermissionStatus.granted) {
        final available = await isMicrophoneAvailable();
        _lastDecision = MicrophonePermissionDecision(
          status: available
              ? MicrophonePermissionStatus.granted
              : MicrophonePermissionStatus.unavailable,
          wasRequested: true,
        );
        return _lastDecision;
      }

      if (requested == MicrophonePermissionStatus.permanentlyDenied ||
          requested == MicrophonePermissionStatus.restricted) {
        final opened = await openAppSettings();
        _lastDecision = MicrophonePermissionDecision(
          status: requested,
          wasRequested: true,
          deniedBySystemDialog: true,
          settingsOpened: opened,
        );
        return _lastDecision;
      }

      final opened = await openAppSettings();
      _lastDecision = MicrophonePermissionDecision(
        status: MicrophonePermissionStatus.denied,
        wasRequested: true,
        deniedBySystemDialog: true,
        settingsOpened: opened,
      );
      return _lastDecision;
    }

    _lastDecision = MicrophonePermissionDecision(status: current);
    return _lastDecision;
  }

  bool get _supportsPermissionApi {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  bool get _supportsSettingsOpen {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static MicrophonePermissionStatus _mapPermissionStatus(
    ph.PermissionStatus status,
  ) {
    if (status.isGranted || status.isLimited) {
      return MicrophonePermissionStatus.granted;
    }
    if (status.isDenied) {
      return MicrophonePermissionStatus.denied;
    }
    if (status.isPermanentlyDenied) {
      return MicrophonePermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return MicrophonePermissionStatus.restricted;
    }
    return MicrophonePermissionStatus.unknown;
  }
}