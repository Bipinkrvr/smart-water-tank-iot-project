// lib/screens/splash_screen.dart

// --- THESE ARE THE MISSING LINES THAT WILL FIX ALL ERRORS ---
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? const SplashUI() : const AuthGate();
  }
}

class SplashUI extends StatelessWidget {
  const SplashUI({super.key});

  @override
  Widget build(BuildContext context) {
    const List<String> quotes = [
      "जल संरक्षण, हमारा संरक्षण।",
      "पानी का मूल्य समझें, भविष्य को सुरक्षित रखें।"
    ];

    final randomQuote = quotes[Random().nextInt(quotes.length)];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 25, 49),
      body: SizedBox(
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                const Icon(Icons.local_drink, color: Colors.white, size: 100),
                const SizedBox(height: 20),
                const Text(
                  'Smart Water Tank',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor | Control | Conserve',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey[200],
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  randomQuote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Color.fromRGBO(255, 255, 255, 0.8),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
