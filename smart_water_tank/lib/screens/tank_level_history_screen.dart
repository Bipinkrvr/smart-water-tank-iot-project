// lib/screens/tank_level_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tank_provider.dart';
import '../widgets/app_drawer.dart';

class TankLevelHistoryScreen extends StatelessWidget {
  const TankLevelHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TankProvider>(
      builder: (context, tankProvider, child) {
        final levelHistory = tankProvider.levelHistory;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tank Level History'),
          ),
          drawer: const AppDrawer(),
          body: levelHistory.isEmpty
              ? const Center(
            child: Text(
              'No tank level events yet.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
              : ListView.builder(
            itemCount: levelHistory.length,
            itemBuilder: (context, index) {
              final event = levelHistory[index];
              final formattedDate =
              DateFormat('MMM d, yyyy, hh:mm a').format(event.timestamp);

              IconData iconData = Icons.help_outline;
              Color iconColor = Colors.grey;

              // --- THIS IS THE CORRECTED LOGIC ---
              if (event.event == 'Tank is Full') {
                iconData = Icons.water_drop;
                iconColor = Colors.blue;
              }
              // We now check if the event text CONTAINS "50%"
              else if (event.event.contains('50%')) {
                iconData = Icons.opacity;
                iconColor = Colors.lightBlueAccent;
              }
              else if (event.event == 'Tank is Empty') {
                iconData = Icons.water_drop_outlined;
                iconColor = Colors.orangeAccent;
              }

              return ListTile(
                leading: Icon(iconData, color: iconColor),
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