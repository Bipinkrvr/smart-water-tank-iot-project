// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import the new package
import '../providers/tank_provider.dart';
import '../widgets/app_drawer.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a Consumer widget to listen for changes in the TankProvider
    return Consumer<TankProvider>(
      builder: (context, tankProvider, child) {
        // Get the history list from the provider
        final history = tankProvider.history;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Motor History'),
          ),
          drawer: const AppDrawer(),
          body: history.isEmpty
              ? const Center(
                  child: Text(
                    'No motor history yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final event = history[index];
                    final isMotorOn = event.event == 'Motor Turned ON';

                    // Format the timestamp into a nice, readable string
                    final formattedDate = DateFormat('MMM d, yyyy, hh:mm a')
                        .format(event.timestamp);

                    return ListTile(
                      leading: Icon(
                        isMotorOn ? Icons.power : Icons.power_off,
                        color:
                            isMotorOn ? Colors.greenAccent : Colors.redAccent,
                      ),
                      title: Text(
                        event.event,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(formattedDate),
                    );
                  },
                ),
        );
      },
    );
  }
}
