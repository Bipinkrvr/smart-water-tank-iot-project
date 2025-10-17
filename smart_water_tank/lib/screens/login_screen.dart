// lib/screens/login_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// ✅ ADD THESE IMPORTS
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../providers/tank_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // ✅ ADD THIS METHOD TO CLEAR OLD DATA SAFELY
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // When the Login Screen is shown, clear out any data from a previous user.
      Provider.of<TankProvider>(context, listen: false).clearData();
    });
  }

  Future<void> _resetPassword() async {
    final resetEmailController = TextEditingController();
    final currentContext = context;

    await showDialog(
      context: currentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: resetEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration:
            const InputDecoration(hintText: "Enter your registered email"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Send Reset Link'),
              onPressed: () async {
                if (resetEmailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(content: Text('Please enter an email.')),
                  );
                  return;
                }
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: resetEmailController.text.trim(),
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(
                        content:
                        Text('Password reset link sent to your email.')),
                  );
                } on FirebaseAuthException catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(content: Text(e.message ?? "An error occurred")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ✅ THIS IS THE UPDATED AND SECURE SIGN-IN FUNCTION
  Future<void> _signIn() async {
    final currentContext = context;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Sign in the user
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // --- ✅ START: NEW SECURE FCM TOKEN LOGIC ---
      // This code runs ONLY if the login above was successful.
      print("Login successful. Saving FCM token to database...");

      // Get the fresh FCM token for this specific device.
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        // Call the secure Cloud Function to save the token.
        final callable = FirebaseFunctions.instance.httpsCallable('saveFCMToken');
        await callable.call({'token': fcmToken});
        print("FCM token saved successfully via Cloud Function!");
      }
      // --- ✅ END: NEW SECURE FCM TOKEN LOGIC ---

    } on FirebaseAuthException catch (e) {
      String errorMessage = "An unknown error occurred.";
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found for that email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password. Please try again.';
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                const Icon(Icons.local_drink, color: Colors.white, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'Welcome Back',
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.1),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 10),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _signIn,
                    child: const Text('LOGIN', style: TextStyle(fontSize: 18)),
                  ),
                const Spacer(flex: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/signup');
                      },
                      child: const Text('Sign Up'),
                    )
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}