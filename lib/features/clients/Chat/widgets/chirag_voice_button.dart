import 'package:flutter/material.dart';

import 'package:chirag_accounting/services/chirag_voice_service.dart';

class ChiragVoiceButton extends StatefulWidget {
  const ChiragVoiceButton({super.key, required this.onTranscript});

  final ValueChanged<String> onTranscript;

  @override
  State<ChiragVoiceButton> createState() => _ChiragVoiceButtonState();
}

class _ChiragVoiceButtonState extends State<ChiragVoiceButton> {
  late final ChiragVoiceService _voice;

  @override
  void initState() {
    super.initState();
    _voice = ChiragVoiceService();
    _voice.addListener(_handleVoiceChanged);
  }

  void _handleVoiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleVoice() async {
    if (_voice.isListening) {
      await _voice.stopListening();
      return;
    }

    final initialized = await _voice.initialize();
    if (!initialized) {
      return;
    }

    await _voice.startListening(onTranscript: widget.onTranscript);
  }

  @override
  Widget build(BuildContext context) {
    final listening = _voice.isListening;

    return IconButton(
      tooltip: listening ? 'Stop voice input' : 'Voice command',
      onPressed: _toggleVoice,
      icon: Icon(listening ? Icons.stop_circle : Icons.mic),
    );
  }

  @override
  void dispose() {
    _voice.removeListener(_handleVoiceChanged);
    _voice.dispose();
    super.dispose();
  }
}
