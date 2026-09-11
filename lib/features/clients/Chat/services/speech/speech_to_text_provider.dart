import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_provider.dart';
import 'web_mic_probe.dart';

class SpeechToTextProvider implements SpeechProvider {
  final stt.SpeechToText _engine = stt.SpeechToText();

  String _transcript = '';
  double _confidence = 0;
  String _detectedLanguage = 'unknown';
  String _lastErrorCode = '';
  String _lastErrorMessage = '';
  bool _isSpeechApiAvailable = true;
  bool _isMicrophoneAvailable = false;
  bool _isAvailable = false;
  String _permissionStatus = 'not_requested';
  String _activeSessionId = '';
  bool _audioStarted = false;
  bool _isInitialized = false;
  Completer<String>? _pendingTranscriptCompleter;
  void Function(SpeechDebugEvent event)? _debugEventHandler;

  void _emit(
    String code, [
    Map<String, Object?> data = const <String, Object?>{},
  ]) {
    _debugEventHandler?.call(SpeechDebugEvent(code, data));
  }

  void _setError(String code, String message) {
    _lastErrorCode = code;
    _lastErrorMessage = message;
  }

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;

    _emit('VOICE INIT START');

    if (kIsWeb) {
      _isSpeechApiAvailable = await probeWebSpeechApiAvailability();
      _isMicrophoneAvailable = false;
      _permissionStatus = 'not_requested';

      if (!_isSpeechApiAvailable) {
        _isInitialized = false;
        _isAvailable = false;
        _setError(
          SpeechProvider.errorSpeechApiUnavailable,
          'Web Speech API is unavailable in this browser/runtime.',
        );
        _emit('VOICE INIT FAILED', <String, Object?>{
          'errorCode': _lastErrorCode,
          'errorMessage': _lastErrorMessage,
        });
        return false;
      }
    }

    try {
      _isInitialized = await _engine.initialize(
        onStatus: (status) {
          _emit('VOICE STATUS', <String, Object?>{'status': status});
          _emit('onstatus', <String, Object?>{'status': status});
          if ((status == 'done' || status == 'notListening') &&
              _pendingTranscriptCompleter != null &&
              !_pendingTranscriptCompleter!.isCompleted) {
            _pendingTranscriptCompleter!.complete(_transcript.trim());
            _pendingTranscriptCompleter = null;
          }
        },
        onError: (error) {
          final code = error.permanent
              ? SpeechProvider.errorNotSupported
              : (error.errorMsg.toLowerCase().contains('network')
                    ? SpeechProvider.errorNetwork
                    : SpeechProvider.errorUnknown);

          _setError(code, error.errorMsg);
          if (code == SpeechProvider.errorPermissionDenied) {
            _permissionStatus = 'denied';
          }
          _emit('VOICE ERROR', <String, Object?>{
            'errorCode': code,
            'errorMessage': error.errorMsg,
          });
          _emit('onerror', <String, Object?>{
            'error': error.errorMsg,
            'permanent': error.permanent,
          });

          if (_pendingTranscriptCompleter != null &&
              !_pendingTranscriptCompleter!.isCompleted) {
            _pendingTranscriptCompleter!.complete(_transcript.trim());
            _pendingTranscriptCompleter = null;
          }
        },
      );
    } catch (error) {
      _isInitialized = false;
      _isAvailable = false;
      final message = error.toString();
      final lower = message.toLowerCase();
      final code =
          lower.contains('speechrecognition') || lower.contains('webkit')
          ? SpeechProvider.errorSpeechApiUnavailable
          : SpeechProvider.errorNotSupported;
      _setError(code, message);
      _emit('VOICE INIT FAILED', <String, Object?>{
        'errorCode': _lastErrorCode,
        'errorMessage': _lastErrorMessage,
      });
      return false;
    }

    _isAvailable = _isInitialized;
    if (!kIsWeb) {
      _isSpeechApiAvailable = _isInitialized;
    }

    if (_isInitialized) {
      _emit('VOICE INIT SUCCESS');
    } else {
      _setError(
        SpeechProvider.errorSpeechApiUnavailable,
        'Speech engine unavailable during initialization.',
      );
      _emit('VOICE INIT FAILED', <String, Object?>{
        'errorCode': _lastErrorCode,
        'errorMessage': _lastErrorMessage,
      });
    }

    return _isAvailable;
  }

  @override
  Future<bool> startListening({
    String? localeId,
    Duration listenFor = const Duration(seconds: 25),
    Duration pauseFor = const Duration(seconds: 3),
    String? sessionId,
    void Function(SpeechDebugEvent event)? onDebugEvent,
  }) async {
    _debugEventHandler = onDebugEvent;
    _activeSessionId = sessionId ?? '';
    _audioStarted = false;
    _lastErrorCode = '';
    _lastErrorMessage = '';
    _isSpeechApiAvailable = true;
    _isMicrophoneAvailable = false;
    _isAvailable = _isInitialized;

    if (_engine.isListening) {
      _setError(
        SpeechProvider.errorUnknown,
        'Recognition is already active for another session.',
      );
      _emit('start-blocked-already-listening', <String, Object?>{
        'sessionId': _activeSessionId,
      });
      return false;
    }

    _emit('permission-check', <String, Object?>{'sessionId': _activeSessionId});
    _emit('VOICE PERMISSION CHECK');
    if (kIsWeb) {
      final probe = await probeWebMicrophoneAndSpeechApi();
      _isSpeechApiAvailable = probe.speechApiAvailable;
      _isMicrophoneAvailable =
        probe.microphoneAvailable && probe.audioTrackLive;
      _permissionStatus = probe.permissionGranted
        ? 'granted'
        : (probe.errorCode == SpeechProvider.errorPermissionDenied
          ? 'denied'
          : 'prompt');

      _emit('mic-probe', <String, Object?>{
        'speechApiAvailable': probe.speechApiAvailable,
        'permissionGranted': probe.permissionGranted,
        'microphoneAvailable': probe.microphoneAvailable,
        'audioTrackLive': probe.audioTrackLive,
        'trackCount': probe.trackCount,
        'errorCode': probe.errorCode,
      });

      if (!probe.speechApiAvailable) {
        _setError(SpeechProvider.errorSpeechApiUnavailable, probe.errorMessage);
        _emit('VOICE INIT FAILED', <String, Object?>{
          'errorCode': SpeechProvider.errorSpeechApiUnavailable,
          'errorMessage': probe.errorMessage,
        });
        return false;
      }

      if (!probe.permissionGranted) {
        _setError(
          probe.errorCode.isEmpty
              ? SpeechProvider.errorPermissionDenied
              : probe.errorCode,
          probe.errorMessage,
        );
        _emit('VOICE ERROR', <String, Object?>{
          'errorCode': _lastErrorCode,
          'errorMessage': _lastErrorMessage,
        });
        return false;
      }

      if (!probe.microphoneAvailable || !probe.audioTrackLive) {
        _setError(
          probe.errorCode.isEmpty
              ? SpeechProvider.errorDeviceNotFound
              : probe.errorCode,
          probe.errorMessage.isEmpty
              ? 'Microphone audio track is unavailable.'
              : probe.errorMessage,
        );
        _emit('VOICE MICROPHONE CHECK', <String, Object?>{
          'microphoneAvailable': probe.microphoneAvailable,
          'audioTrackLive': probe.audioTrackLive,
          'errorCode': _lastErrorCode,
        });
        return false;
      }

      _emit('VOICE MICROPHONE CHECK', <String, Object?>{
        'microphoneAvailable': probe.microphoneAvailable,
        'audioTrackLive': probe.audioTrackLive,
      });
    }

    final ready = await initialize();
    if (!ready) {
      _setError(
        SpeechProvider.errorNotSupported,
        'Speech engine initialization failed.',
      );
      _emit('VOICE INIT FAILED', <String, Object?>{
        'errorCode': _lastErrorCode,
        'errorMessage': _lastErrorMessage,
      });
      return false;
    }

    _isAvailable = true;
    if (_permissionStatus == 'unknown' ||
        _permissionStatus == 'not_requested') {
      _permissionStatus = 'granted';
    }
    _emit('VOICE READY');

    _transcript = '';
    _confidence = 0;
    _detectedLanguage = localeId ?? 'en-IN';

    _pendingTranscriptCompleter?.complete(_transcript);
    _pendingTranscriptCompleter = Completer<String>();

    _emit('recognition-created', <String, Object?>{
      'sessionId': _activeSessionId,
      'localeId': _detectedLanguage,
    });

    await _engine.listen(
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,
      onSoundLevelChange: (level) {
        final absLevel = level < 0 ? -level : level;
        if (!_audioStarted && absLevel > 0.001) {
          _audioStarted = true;
          _emit('onaudiostart', <String, Object?>{'level': level});
        }
      },
      onResult: (result) {
        final recognized = result.recognizedWords.trim();
        if (result.recognizedWords.trim().isNotEmpty) {
          _transcript = recognized;
          _confidence = result.hasConfidenceRating ? result.confidence : 0;
          _detectedLanguage = _detectedLanguage.isNotEmpty
              ? _detectedLanguage
              : 'unknown';
        }

        _emit('onresult', <String, Object?>{
          'resultsLength': 1,
          'transcriptLength': recognized.length,
          'transcript': recognized,
          'isFinal': result.finalResult,
          'confidence': _confidence,
        });

        if (result.finalResult &&
            _pendingTranscriptCompleter != null &&
            !_pendingTranscriptCompleter!.isCompleted) {
          _pendingTranscriptCompleter!.complete(_transcript);
          _pendingTranscriptCompleter = null;
          _emit('VOICE RESULT', <String, Object?>{'transcript': _transcript});
          _emit('onspeechend');
        }
      },
    );

    _emit('VOICE LISTEN START', <String, Object?>{'sessionId': _activeSessionId});
    _emit('recognition-start', <String, Object?>{'sessionId': _activeSessionId});

    return _engine.isListening;
  }

  @override
  Future<void> stopListening() async {
    if (!_engine.isListening) {
      _emit('stop-skipped-not-listening', <String, Object?>{
        'sessionId': _activeSessionId,
      });
      return;
    }
    _emit('onstopsignal', <String, Object?>{'sessionId': _activeSessionId});
    await _engine.stop();
    _emit('VOICE LISTEN END', <String, Object?>{'sessionId': _activeSessionId});
  }

  @override
  Future<void> cancelListening() async {
    if (!_engine.isListening) return;
    await _engine.cancel();
    _setError(SpeechProvider.errorUnknown, 'Speech recognition was cancelled.');
    _emit('VOICE ERROR', <String, Object?>{
      'errorCode': _lastErrorCode,
      'errorMessage': _lastErrorMessage,
    });
    _emit('oncancel', <String, Object?>{'sessionId': _activeSessionId});
    if (_pendingTranscriptCompleter != null &&
        !_pendingTranscriptCompleter!.isCompleted) {
      _pendingTranscriptCompleter!.complete(_transcript);
    }
    _pendingTranscriptCompleter = null;
  }

  @override
  Future<String> stopListeningAndAwaitTranscript({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!_engine.isListening) {
      return _transcript.trim();
    }

    final completer = _pendingTranscriptCompleter ??= Completer<String>();

    await _engine.stop();
    _emit('onaudioend', <String, Object?>{'sessionId': _activeSessionId});

    try {
      final value = await completer.future.timeout(timeout);
      return value.trim();
    } catch (_) {
      if (completer.isCompleted) {
        return _transcript.trim();
      }
      if (_pendingTranscriptCompleter != null && !_pendingTranscriptCompleter!.isCompleted) {
        _pendingTranscriptCompleter!.complete(_transcript.trim());
      }
      _pendingTranscriptCompleter = null;
      return _transcript.trim();
    }
  }

  @override
  bool get isListening => _engine.isListening;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isAvailable => _isAvailable;

  @override
  String get transcript => _transcript;

  @override
  double get confidence => _confidence;

  @override
  String get detectedLanguage => _detectedLanguage;

  @override
  String get lastErrorCode => _lastErrorCode;

  @override
  String get lastErrorMessage => _lastErrorMessage;

  @override
  bool get isSpeechApiAvailable => _isSpeechApiAvailable;

  @override
  bool get isMicrophoneAvailable => _isMicrophoneAvailable;

  @override
  String get permissionStatus => _permissionStatus;

  @override
  String get activeSessionId => _activeSessionId;
}
