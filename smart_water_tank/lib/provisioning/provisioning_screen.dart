// lib/provisioning/provisioning_screen.dart

import 'package:cloud_functions/cloud_functions.dart'; // <-- NEW
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_water_tank/provisioning/ble_service.dart';

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bleService = BleService();
  final _functions = FirebaseFunctions.instance; // <-- NEW

  String _statusMessage = "Enter your Wi-Fi details to set up the device.";
  bool _isLoading = false;

  // --- MODIFIED: The entire provisioning logic is updated ---
  Future<void> _startProvisioning() async {
    // 1. Request Permissions
    if (!await _requestPermissions()) return;

    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _statusMessage = "Please enter both Wi-Fi name and password.");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Starting...";
    });

    // 2. Connect to device, send Wi-Fi, and get back its MAC address
    final provisionResult = await _bleService.connectAndProvisionWifi(
      _ssidController.text.trim(),
      _passwordController.text,
          (status) => setState(() => _statusMessage = status),
    );

    if (provisionResult == null) {
      setState(() => _isLoading = false); // Error message is already set by the service
      return;
    }

    // 3. Call Cloud Function to register the device and get a permanent API key
    try {
      setState(() => _statusMessage = "Registering device with the server...");
      final callable = _functions.httpsCallable('registerDevice');
      final result = await callable.call<Map<String, dynamic>>({
        'hardwareId': provisionResult.macAddress,
      });

      final String apiKey = result.data['apiKey'];
      if (apiKey.isEmpty) throw "Received an empty API key from the server.";

      // 4. Send the permanent API key to the device and disconnect
      final success = await _bleService.sendApiKeyAndDisconnect(
        provisionResult.device,
        apiKey,
            (status) => setState(() => _statusMessage = status),
      );

      setState(() => _isLoading = false);

      if (success) _showSuccessDialog();

    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Server Error: ${e.message}";
      });
      // Disconnect if the server part fails
      await provisionResult.device.disconnect();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "An error occurred: ${e.toString()}";
      });
      await provisionResult.device.disconnect();
    }
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.location]!.isGranted) {
      return true;
    } else {
      setState(() => _statusMessage = "Permissions are required to find your device.");
      return false;
    }
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Success!"),
        content: const Text("Your device has been configured and is now securely registered to your account."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back from provisioning screen
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Up New Device"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: "Wi-Fi Name (SSID)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Wi-Fi Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _startProvisioning,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Configure and Register Device"),
              ),
              const SizedBox(height: 32),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Center(child: Text(_statusMessage, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}