abstract class TtsProvider {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> setLanguage(String language);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setPitch(double pitch);
  bool get isSpeaking;
}
