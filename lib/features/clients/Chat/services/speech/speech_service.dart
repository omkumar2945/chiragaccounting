import 'speech_provider.dart';
import 'speech_to_text_provider.dart';

class SpeechService {
  SpeechService({required SpeechProvider provider}) : _provider = provider;

  factory SpeechService.withDefaultProvider() {
    return SpeechService(provider: SpeechToTextProvider());
  }

  final SpeechProvider _provider;

  Future<bool> initializeProvider({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      return await _provider.initialize().timeout(timeout);
    } catch (_) {
      return false;
    }
  }

  Future<bool> startListening({
    String? localeId,
    String? sessionId,
    void Function(SpeechDebugEvent event)? onDebugEvent,
  }) {
    return _provider.startListening(
      localeId: localeId,
      sessionId: sessionId,
      onDebugEvent: onDebugEvent,
    );
  }

  Future<void> stopListening() => _provider.stopListening();

  Future<void> cancelListening() => _provider.cancelListening();

  Future<String> stopListeningAndAwaitTranscript({
    Duration timeout = const Duration(seconds: 4),
  }) => _provider.stopListeningAndAwaitTranscript(timeout: timeout);

  Future<String> getTranscript() async => _provider.transcript.trim();

  double getConfidence() => _provider.confidence;

  String getDetectedLanguage() => _provider.detectedLanguage;

  bool get isListening => _provider.isListening;

  bool get isInitialized => _provider.isInitialized;

  bool get isAvailable => _provider.isAvailable;

  String getLastErrorCode() => _provider.lastErrorCode;

  String getLastErrorMessage() => _provider.lastErrorMessage;

  bool get isSpeechApiAvailable => _provider.isSpeechApiAvailable;

  bool get isMicrophoneAvailable => _provider.isMicrophoneAvailable;

  String get permissionStatus => _provider.permissionStatus;

  String get activeSessionId => _provider.activeSessionId;
}
