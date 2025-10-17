// lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';

// We need to import all the screens we want to navigate to
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/tank_level_history_screen.dart';
import '../screens/stats_screen.dart'; // <-- Add the import for our new screen

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
              image: DecorationImage(
                fit: BoxFit.cover,
                image: AssetImage('assets/images/drawer_header.jpg'),
              ),
            ),
            child: Text(
              'Smart Water Tank',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 10.0, color: Colors.black)],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (context) => const DashboardScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Motor History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Tank Level History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const TankLevelHistoryScreen()),
              );
            },
          ),

          // --- THIS IS THE NEW BUTTON FOR YOUR STATS SCREEN ---
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Daily Stats'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const StatsScreen()),
              );
            },
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}