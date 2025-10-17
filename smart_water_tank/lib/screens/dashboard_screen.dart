// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ 1. ADD THIS IMPORT
import '../providers/tank_provider.dart';
import '../widgets/app_drawer.dart';
import '../provisioning/provisioning_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();

    // Load the tank data when the dashboard is first shown.
    Provider.of<TankProvider>(context, listen: false).checkConnectivityAndInitialize();

    // Set up the listener for notifications that arrive when the app is open.
    _setupForegroundNotificationListener();

    // ✅ 2. ADD THIS CALL TO ASK FOR PERMISSION
    _requestNotificationPermission();
  }

  // ✅ 3. ADD THIS NEW FUNCTION
  Future<void> _requestNotificationPermission() async {
    // Check the current status of the notification permission
    final status = await Permission.notification.status;

    // If permission is not yet granted, request it
    if (status.isDenied) {
      // This will open the system's permission request dialog
      await Permission.notification.request();
    }
  }

  void _setupForegroundNotificationListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.notification!.title ?? 'New Message'),
              duration: const Duration(seconds: 5),
            )
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TankProvider>(
      builder: (context, tankProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Set up new device',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProvisioningScreen()),
                  );
                },
              ),
            ],
          ),
          drawer: const AppDrawer(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  if (tankProvider.connectionState == ConnectionStatus.connecting)
                    const ConnectingWidget()
                  else if (tankProvider.connectionState == ConnectionStatus.offline)
                    const OfflineWidget()
                  else if (tankProvider.connectionState == ConnectionStatus.error)
                      const Text("Error: Could not connect to your device's data.")
                    else
                      const DashboardContent(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class OfflineWidget extends StatelessWidget {
  const OfflineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final tankProvider = Provider.of<TankProvider>(context, listen: false);
    return SizedBox(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'No Internet Connection',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
          const SizedBox(height: 10),
          Text(
            'Please check your connection.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              tankProvider.checkConnectivityAndInitialize();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class ConnectingWidget extends StatelessWidget {
  const ConnectingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Connecting to sensor...',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final tankProvider = Provider.of<TankProvider>(context);
    return Column(
      children: [
        Text(
          'Live Water Tank Level',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[200],
          ),
        ),
        const SizedBox(height: 10),
        WaveTankIndicator(
          waterLevel: tankProvider.waterLevel,
        ),
        const SizedBox(height: 40),
        Card(
          elevation: 4,
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Automatic Mode',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  value: tankProvider.isAutoModeOn,
                  onChanged: (value) {
                    tankProvider.toggleAutoMode(value);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Manual Pump Control',
                      style: TextStyle(fontSize: 18)),
                  subtitle: Text(
                    tankProvider.isAutoModeOn
                        ? 'Disabled in Auto Mode'
                        : (tankProvider.isPumpOn
                        ? 'Pump is ON'
                        : 'Pump is OFF'),
                    style: TextStyle(
                        color: tankProvider.isAutoModeOn
                            ? Colors.orange
                            : (tankProvider.isPumpOn
                            ? Colors.green
                            : Colors.red)),
                  ),
                  value: tankProvider.isPumpOn,
                  onChanged: tankProvider.isAutoModeOn
                      ? null
                      : (value) {
                    tankProvider.togglePump(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WaveTankIndicator extends StatelessWidget {
  final double waterLevel;
  const WaveTankIndicator({Key? key, required this.waterLevel})
      : super(key: key);

  Color _getWaterColor() {
    if (waterLevel <= 15) return Colors.redAccent;
    if (waterLevel <= 40) return Colors.orangeAccent;
    if (waterLevel >= 90) return Colors.greenAccent;
    return Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: LiquidLinearProgressIndicator(
        value: waterLevel / 100.0,
        valueColor: AlwaysStoppedAnimation(_getWaterColor()),
        backgroundColor: Colors.grey[800],
        borderColor: Colors.blueGrey,
        borderWidth: 5.0,
        direction: Axis.vertical,
        borderRadius: 12.0,
        center: Text(
          '${waterLevel.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 40.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}