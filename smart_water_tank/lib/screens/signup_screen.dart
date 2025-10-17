// lib/screens/signup_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// ✅ ADD THESE IMPORTS
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // ✅ THIS IS THE UPDATED AND SECURE SIGN-UP FUNCTION
  Future<void> _signUp() async {
    final currentContext = context;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Create the new user
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // --- ✅ START: NEW SECURE FCM TOKEN LOGIC ---
      print("Sign up successful. Saving initial FCM token...");

      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        // Call the secure Cloud Function to save the token.
        final callable = FirebaseFunctions.instance.httpsCallable('saveFCMToken');
        await callable.call({'token': fcmToken});
        print("Initial FCM token saved successfully via Cloud Function!");
      }
      // --- ✅ END: NEW SECURE FCM TOKEN LOGIC ---

    } on FirebaseAuthException catch (e) {
      String errorMessage = "An unknown error occurred.";
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'network-request-failed':
          errorMessage =
          'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again later.';
      }
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 25, 49),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_add_alt_1, color: Colors.white, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Create Account',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email',
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.1),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: 'Password (at least 6 characters)',
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.1),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _signUp,
                child: const Text('SIGN UP', style: TextStyle(fontSize: 18)),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Login'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}