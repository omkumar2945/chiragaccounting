import 'package:flutter/material.dart';

class UnsupportedWebScreen extends StatelessWidget {
  final String title;
  final String message;

  const UnsupportedWebScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}