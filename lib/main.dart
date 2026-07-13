import 'package:flutter/material.dart';
import 'features/authentication/presentation/pages/login_screen.dart';
void main() {
  runApp(const ChiragAccountingApp());
}

class ChiragAccountingApp extends StatelessWidget {
  const ChiragAccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chirag Accounting',
     home: const LoginScreen(),
    );
  }
}