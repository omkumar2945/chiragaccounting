import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/clients/Chat/client_chat_screen.dart';

class AuthenticatedSupportChatShell extends StatelessWidget {
  const AuthenticatedSupportChatShell({
    super.key,
    this.navigationHistory,
    this.navigatorKey,
    required this.child,
  });

  final Object? navigationHistory;
  final GlobalKey<NavigatorState>? navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class OpenSupportChatRedirect extends StatelessWidget {
  const OpenSupportChatRedirect({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClientChatScreen();
  }
}
