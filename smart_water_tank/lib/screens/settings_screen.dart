// lib/screens/settings_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tank_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // This is the new method to show the pop-up dialog
  void _showUpdateTankHeightDialog(BuildContext context, TankProvider provider) {
    final textController = TextEditingController(text: provider.tankHeight.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Tank Height (cm)'),
          content: TextField(
            controller: textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: "Enter height in cm"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final double? newHeight = double.tryParse(textController.text);
                if (newHeight != null && newHeight > 0) {
                  provider.updateTankHeight(newHeight);
                  Navigator.of(context).pop();
                } else {
                  // Optional: Show an error if the input is not a valid number
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Consumer<TankProvider>(
      builder: (context, tankProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            children: [
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive alerts for tank status'),
                value: tankProvider.notificationsEnabled,
                onChanged: (newValue) {
                  tankProvider.toggleNotifications(newValue);
                },
                secondary: const Icon(Icons.notifications),
              ),
              const Divider(),
              // --- THIS IS THE NEW TANK HEIGHT SETTING ---
              ListTile(
                leading: const Icon(Icons.straighten_outlined),
                title: const Text('Tank Height'),
                subtitle: Text('${tankProvider.tankHeight.toStringAsFixed(1)} cm'),
                onTap: () => _showUpdateTankHeightDialog(context, tankProvider),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_pin_rounded),
                title: const Text('My User ID'),
                subtitle: Text(user?.uid ?? 'Not available'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    if (user?.uid != null) {
                      Clipboard.setData(ClipboardData(text: user!.uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('User ID copied to clipboard')),
                      );
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  final provider = Provider.of<TankProvider>(context, listen: false);
                  provider.clearData();
                  FirebaseAuth.instance.signOut();
                },
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('App Version'),
                subtitle: Text('1.0.0'),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.developer_mode),
                title: Text('Created by'),
                subtitle: Text('Bipin kumar'),
              ),
            ],
          ),
        );
      },
    );
  }
}