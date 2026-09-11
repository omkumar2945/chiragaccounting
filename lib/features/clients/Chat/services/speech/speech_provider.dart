abstract class SpeechProvider {
  static const String errorPermissionDenied = 'PERMISSION_DENIED';
  static const String errorDeviceNotFound = 'DEVICE_NOT_FOUND';
  static const String errorDeviceBusy = 'DEVICE_BUSY';
  static const String errorNotSupported = 'NOT_SUPPORTED';
  static const String errorSpeechApiUnavailable = 'SPEECH_API_UNAVAILABLE';
  static const String errorNoSpeech = 'NO_SPEECH';
  static const String errorNetwork = 'NETWORK_ERROR';
  static const String errorUnknown = 'UNKNOWN';
  static const String errorInitializationTimeout =
      'VOICE_PROVIDER_INITIALIZATION_TIMEOUT';
  static const String errorPlatformNotSupported = 'CURRENT_RUNTIME_NOT_SUPPORTED';

  Future<bool> initialize();

  Future<bool> startListening({
    String? localeId,
    Duration listenFor = const Duration(seconds: 25),
    Duration pauseFor = const Duration(seconds: 3),
    String? sessionId,
    void Function(SpeechDebugEvent event)? onDebugEvent,
  });

  Future<void> stopListening();

  Future<void> cancelListening();

  Future<String> stopListeningAndAwaitTranscript({
    Duration timeout = const Duration(seconds: 4),
  });

  bool get isListening;

  bool get isInitialized;

  bool get isAvailable;

  String get transcript;

  double get confidence;

  String get detectedLanguage;

  String get lastErrorCode;

  String get lastErrorMessage;

  bool get isSpeechApiAvailable;

  bool get isMicrophoneAvailable;

  String get permissionStatus;

  String get activeSessionId;
}

class SpeechDebugEvent {
  const SpeechDebugEvent(this.code, [this.data = const <String, Object?>{}]);

  final String code;
  final Map<String, Object?> data;
}
