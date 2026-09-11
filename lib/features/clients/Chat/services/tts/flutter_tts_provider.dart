import 'package:flutter_tts/flutter_tts.dart';

import 'tts_provider.dart';

class FlutterTtsProvider implements TtsProvider {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
    });
    _initialized = true;
  }

  @override
  Future<void> pause() async {
    await initialize();
    await _tts.pause();
    _isSpeaking = false;
  }

  @override
  Future<void> resume() async {
    await initialize();
  }

  @override
  Future<void> setLanguage(String language) async {
    await initialize();
    await _tts.setLanguage(language);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await initialize();
    await _tts.setPitch(pitch);
  }

  @override
  Future<void> setRate(double rate) async {
    await initialize();
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    await initialize();
    await _tts.setVolume(volume);
  }

  @override
  Future<void> speak(String text) async {
    await initialize();
    await _tts.stop();
    _isSpeaking = false;
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await initialize();
    await _tts.stop();
    _isSpeaking = false;
  }

  @override
  bool get isSpeaking => _isSpeaking;
}
