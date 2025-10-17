// lib/models/tank_level_event.dart

class TankLevelEvent {
  final String event; // e.g., "Tank is Full"
  final DateTime timestamp;

  TankLevelEvent({required this.event, required this.timestamp});
}
