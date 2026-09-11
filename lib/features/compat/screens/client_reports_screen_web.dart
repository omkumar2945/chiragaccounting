import 'package:flutter/material.dart';
import 'package:chirag_accounting/features/compat/screens/unsupported_web_screen.dart';

class ClientReportsScreen extends StatelessWidget {
  const ClientReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnsupportedWebScreen(
      title: 'Client Reports',
      message:
          'Report attachment ZIP export uses local file APIs and is currently available on desktop/mobile builds only.',
    );
  }
}