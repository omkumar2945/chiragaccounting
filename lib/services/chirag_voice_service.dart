import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceStatus {
  idle,
  initializing,
  ready,
  listening,
  processing,
  success,
  error,
}

class ChiragVoiceService extends ChangeNotifier {
  ChiragVoiceService();

  final SpeechToText _speech = SpeechToText();

  VoiceStatus _status = VoiceStatus.idle;
  String _transcript = '';
  String _errorMessage = '';

  bool _initialized = false;
  bool _available = false;
  bool _sessionActive = false;

  int _sessionCounter = 0;
  int? _activeSession;

  Timer? _safetyTimer;

  VoiceStatus get status => _status;
  String get transcript => _transcript;
  String get errorMessage => _errorMessage;

  bool get initialized => _initialized;
  bool get available => _available;
  bool get isListening => _speech.isListening;

  String get statusText {
    switch (_status) {
      case VoiceStatus.idle:
        return 'IDLE';
      case VoiceStatus.initializing:
        return 'INITIALIZING';
      case VoiceStatus.ready:
        return 'READY';
      case VoiceStatus.listening:
        return 'LISTENING';
      case VoiceStatus.processing:
        return 'PROCESSING';
      case VoiceStatus.success:
        return 'SUCCESS';
      case VoiceStatus.error:
        return 'ERROR';
    }
  }

  Future<bool> initialize() async {
    if (_initialized) {
      return _available;
    }

    _setStatus(VoiceStatus.initializing);
    _errorMessage = '';

    try {
      debugPrint('[CHIRAG VOICE] INITIALIZE START');

      final available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );

      _available = available;
      _initialized = true;

      if (available) {
        debugPrint('[CHIRAG VOICE] INITIALIZE SUCCESS');
        _setStatus(VoiceStatus.ready);
        return true;
      }

      debugPrint('[CHIRAG VOICE] SPEECH UNAVAILABLE');
      _setError('Speech recognition is not available on this device/browser.');
      return false;
    } catch (error, stack) {
      debugPrint('[CHIRAG VOICE] INITIALIZE ERROR: $error');
      debugPrintStack(stackTrace: stack);
      _setError(_friendlySpeechError(error));
      return false;
    }
  }

  Future<bool> toggleListening({
    String? localeId,
    required ValueChanged<String> onTranscript,
  }) async {
    if (_sessionActive) {
      await stopListening();
      return true;
    }

    return startListening(localeId: localeId, onTranscript: onTranscript);
  }

  Future<bool> startListening({
    String? localeId,
    required ValueChanged<String> onTranscript,
  }) async {
    if (_sessionActive) {
      return false;
    }

    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        return false;
      }
    }

    if (!_available) {
      _setError('Voice recognition is not available on this device.');
      return false;
    }

    _sessionCounter++;
    _activeSession = _sessionCounter;
    final currentSession = _activeSession!;

    _sessionActive = true;
    _transcript = '';
    _errorMessage = '';

    _setStatus(VoiceStatus.listening);

    debugPrint('[CHIRAG VOICE] SESSION START: $currentSession');

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!_isCurrentSession(currentSession)) {
            return;
          }

          final text = result.recognizedWords.trim();
          if (text.isEmpty) {
            return;
          }

          _transcript = text;

          debugPrint(
            '[CHIRAG VOICE] RESULT: $text FINAL=${result.finalResult}',
          );
          notifyListeners();

          if (result.finalResult) {
            onTranscript(text);
            _setStatus(VoiceStatus.success);
          }
        },
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );

      if (!_speech.isListening) {
        _sessionActive = false;

        if (_transcript.isEmpty) {
          _setError('Microphone could not start listening.');
          return false;
        }
      }

      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(seconds: 60), () async {
        if (_isCurrentSession(currentSession)) {
          await stopListening();
        }
      });

      return true;
    } catch (error, stack) {
      debugPrint('[CHIRAG VOICE] LISTEN ERROR: $error');
      debugPrintStack(stackTrace: stack);

      _sessionActive = false;
      _setError(_friendlySpeechError(error));
      return false;
    }
  }

  Future<void> stopListening() async {
    _safetyTimer?.cancel();
    _safetyTimer = null;

    if (!_sessionActive && !_speech.isListening) {
      return;
    }

    debugPrint('[CHIRAG VOICE] STOP');

    try {
      _setStatus(VoiceStatus.processing);
      await _speech.stop();
    } catch (error) {
      debugPrint('[CHIRAG VOICE] STOP ERROR: $error');
    }

    _sessionActive = false;

    if (_transcript.trim().isNotEmpty) {
      _setStatus(VoiceStatus.success);
    } else {
      _setError('I could not hear any speech. Please try again.');
    }
  }

  Future<void> cancelListening() async {
    _safetyTimer?.cancel();
    _safetyTimer = null;

    try {
      await _speech.cancel();
    } catch (_) {}

    _sessionActive = false;
    _transcript = '';
    _setStatus(VoiceStatus.ready);
  }

  Future<List<LocaleName>> getLocales() async {
    if (!_initialized) {
      await initialize();
    }

    return _speech.locales();
  }

  void clearError() {
    _errorMessage = '';

    if (_available) {
      _setStatus(_sessionActive ? VoiceStatus.listening : VoiceStatus.ready);
    } else {
      _setStatus(VoiceStatus.idle);
    }
  }

  bool _isCurrentSession(int session) {
    return _sessionActive && _activeSession == session;
  }

  void _handleStatus(String status) {
    debugPrint('[CHIRAG VOICE] STATUS: $status');

    final normalized = status.toLowerCase();

    if (normalized.contains('listening')) {
      _setStatus(VoiceStatus.listening);
      return;
    }

    if (normalized.contains('not listening') || normalized.contains('done')) {
      if (_sessionActive) {
        _sessionActive = false;

        if (_transcript.trim().isNotEmpty) {
          _setStatus(VoiceStatus.success);
        }
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint(
      '[CHIRAG VOICE] ERROR: ${error.errorMsg} PERMANENT=${error.permanent}',
    );

    _sessionActive = false;
    _setError(_friendlySpeechError(error.errorMsg));
  }

  String _friendlySpeechError(Object error) {
    final value = error.toString().toLowerCase();

    if (value.contains('notfound') || value.contains('device_not_found')) {
      return 'No microphone was found. Please connect or enable a microphone.';
    }

    if (value.contains('permission')) {
      return 'Microphone permission is required for voice commands.';
    }

    if (value.contains('not supported') || value.contains('unsupported')) {
      return 'Voice recognition is not supported on this browser/device.';
    }

    if (value.contains('network')) {
      return 'Voice recognition network service is unavailable.';
    }

    return 'Voice recognition failed. Please try again.';
  }

  void _setStatus(VoiceStatus value) {
    _status = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = VoiceStatus.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();

    try {
      _speech.cancel();
    } catch (_) {}

    super.dispose();
  }
}
