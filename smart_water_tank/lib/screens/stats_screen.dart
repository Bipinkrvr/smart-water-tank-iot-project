// lib/screens/stats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tank_provider.dart';
import '../widgets/app_drawer.dart';
import '../models/daily_stat.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  // Helper function to format seconds into a readable string
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return "${hours}h ${minutes}m ${seconds}s";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TankProvider>(
      builder: (context, tankProvider, child) {
        final stats = tankProvider.dailyStats;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Daily Statistics'),
          ),
          drawer: const AppDrawer(),
          body: stats.isEmpty
              ? const Center(
            child: Text(
              'No daily statistics have been calculated yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final DailyStat stat = stats[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.date,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                        title: const Text('Total Motor Run Time'),
                        subtitle: Text(
                          _formatDuration(stat.motorRunTimeSeconds),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.water_drop_outlined, color: Colors.lightBlueAccent),
                        title: const Text('Estimated Water Used'),
                        subtitle: Text(
                          '${stat.waterUsedPercent}% of tank capacity',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}