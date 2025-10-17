// lib/main.dart

import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'providers/tank_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';


// ✅ This function connects your app to the local emulators for testing
void _connectToFirebaseEmulators() {
  // IMPORTANT: Replace with your computer's local IPv4 address
  final String host = '10.98.73.67';

  print("--- App is in Debug Mode: Connecting to Local Emulators ---");

  FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  // NOTE: You don't have Firestore in your app's code, so this line is optional.
  // FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
}

// This function handles notifications that arrive when the app is CLOSED.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ This connects to emulators ONLY when running in debug mode
  if (kDebugMode) {
   // _connectToFirebaseEmulators();
  }

  final fcmToken = await FirebaseMessaging.instance.getToken();
  print("✅ FCM Token: $fcmToken");

  // Set the background message handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications and set up the foreground listener.
  await setupForegroundNotifications();

  runApp(const MyApp());
}

// NEW FUNCTION TO SET UP FOREGROUND NOTIFICATIONS
Future<void> setupForegroundNotifications() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  // This is the crucial part: listen for messages that arrive while the app is OPEN.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // Must match the ID in AndroidManifest.xml
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TankProvider(),
      child: MaterialApp(
        title: 'Smart Water Tank',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color.fromARGB(255, 12, 25, 49),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 23, 44, 85),
            elevation: 0,
          ),
        ),
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
        },
      ),
    );
  }
}