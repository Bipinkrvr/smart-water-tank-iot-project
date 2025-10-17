// lib/models/history_event.dart

class HistoryEvent {
  final String event; // e.g., "Motor Turned ON" or "Motor Turned OFF"
  final DateTime timestamp;

  HistoryEvent({required this.event, required this.timestamp});
}
