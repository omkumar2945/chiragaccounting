import 'web_mic_probe.dart';

Future<bool> probeWebSpeechApiAvailabilityImpl() async => true;

Future<WebMicProbeResult> probeWebMicrophoneAndSpeechApiImpl() async {
  return const WebMicProbeResult(
    isWeb: false,
    speechApiAvailable: true,
    permissionGranted: true,
    microphoneAvailable: true,
    audioTrackLive: false,
  );
}
