import 'flutter_tts_provider.dart';
import 'tts_provider.dart';

class TextToSpeechService {
  TextToSpeechService({required TtsProvider provider}) : _provider = provider;

  factory TextToSpeechService.withDefaultProvider() {
    return TextToSpeechService(provider: FlutterTtsProvider());
  }

  final TtsProvider _provider;

  Future<void> initialize() => _provider.initialize();

  Future<void> speak(String text) => _provider.speak(text);

  Future<void> stop() => _provider.stop();

  Future<void> pause() => _provider.pause();

  Future<void> resume() => _provider.resume();

  Future<void> setLanguage(String language) => _provider.setLanguage(language);

  Future<void> setRate(double rate) => _provider.setRate(rate);

  Future<void> setVolume(double volume) => _provider.setVolume(volume);

  Future<void> setPitch(double pitch) => _provider.setPitch(pitch);

  bool get isSpeaking => _provider.isSpeaking;
}
