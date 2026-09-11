// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'web_mic_probe.dart';

bool _hasSpeechRecognitionApi() {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('chrome') ||
      userAgent.contains('edg') ||
      userAgent.contains('safari');
}

Future<bool> probeWebSpeechApiAvailabilityImpl() async {
  return _hasSpeechRecognitionApi();
}

Future<WebMicProbeResult> probeWebMicrophoneAndSpeechApiImpl() async {
  if (html.window.isSecureContext != true) {
    return const WebMicProbeResult(
      isWeb: true,
      speechApiAvailable: false,
      permissionGranted: false,
      microphoneAvailable: false,
      audioTrackLive: false,
      errorCode: 'SECURE_CONTEXT_REQUIRED',
      errorMessage:
          'Microphone access requires a secure context (HTTPS or localhost).',
    );
  }

  final hasSpeechRecognition = _hasSpeechRecognitionApi();

  if (!hasSpeechRecognition) {
    return const WebMicProbeResult(
      isWeb: true,
      speechApiAvailable: false,
      permissionGranted: false,
      microphoneAvailable: false,
      audioTrackLive: false,
      errorCode: 'SPEECH_API_UNAVAILABLE',
      errorMessage: 'Web Speech API is unavailable in this browser.',
    );
  }

  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    return const WebMicProbeResult(
      isWeb: true,
      speechApiAvailable: false,
      permissionGranted: false,
      microphoneAvailable: false,
      audioTrackLive: false,
      errorCode: 'BROWSER_NOT_SUPPORTED',
      errorMessage: 'navigator.mediaDevices is unavailable.',
    );
  }

  try {
    final stream = await mediaDevices.getUserMedia(<String, dynamic>{
      'audio': true,
    });

    final tracks = stream.getAudioTracks();
    final trackCount = tracks.length;
    final microphoneAvailable = trackCount > 0;
    final audioTrackLive = tracks.any(
      (track) => track.readyState == 'live' && (track.enabled == true),
    );

    for (final track in tracks) {
      track.stop();
    }

    return WebMicProbeResult(
      isWeb: true,
      speechApiAvailable: true,
      permissionGranted: true,
      microphoneAvailable: microphoneAvailable,
      audioTrackLive: audioTrackLive,
      trackCount: trackCount,
      errorCode: microphoneAvailable ? '' : 'DEVICE_NOT_FOUND',
      errorMessage: microphoneAvailable
          ? ''
          : 'No active microphone audio track was returned.',
    );
  } catch (error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    String code = 'UNKNOWN';
    if (lower.contains('notallowederror') ||
        lower.contains('permission denied') ||
        lower.contains('denied')) {
      code = 'PERMISSION_DENIED';
    } else if (lower.contains('notfounderror') ||
        lower.contains('device not found') ||
        lower.contains('found no microphone')) {
      code = 'DEVICE_NOT_FOUND';
    } else if (lower.contains('notreadableerror') ||
        lower.contains('trackstarterror') ||
        lower.contains('could not start audio source')) {
      code = 'DEVICE_BUSY';
    } else if (lower.contains('notsupportederror')) {
      code = 'NOT_SUPPORTED';
    }

    return WebMicProbeResult(
      isWeb: true,
      speechApiAvailable: true,
      permissionGranted: false,
      microphoneAvailable: false,
      audioTrackLive: false,
      errorCode: code,
      errorMessage: message,
    );
  }
}
