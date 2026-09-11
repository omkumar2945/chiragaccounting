import 'web_mic_probe_stub.dart'
    if (dart.library.html) 'web_mic_probe_web.dart';

Future<bool> probeWebSpeechApiAvailability() =>
  probeWebSpeechApiAvailabilityImpl();

class WebMicProbeResult {
  const WebMicProbeResult({
    required this.isWeb,
    required this.speechApiAvailable,
    required this.permissionGranted,
    required this.microphoneAvailable,
    required this.audioTrackLive,
    this.errorCode = '',
    this.errorMessage = '',
    this.trackCount = 0,
  });

  final bool isWeb;
  final bool speechApiAvailable;
  final bool permissionGranted;
  final bool microphoneAvailable;
  final bool audioTrackLive;
  final String errorCode;
  final String errorMessage;
  final int trackCount;
}

Future<WebMicProbeResult> probeWebMicrophoneAndSpeechApi() =>
    probeWebMicrophoneAndSpeechApiImpl();
