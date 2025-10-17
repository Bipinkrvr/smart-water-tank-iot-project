// lib/providers/tank_provider.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/daily_stat.dart';
import '../models/history_event.dart';
import '../models/tank_level_event.dart';

enum ConnectionStatus { connecting, connected, offline, error }

class TankProvider with ChangeNotifier {
  ConnectionStatus _connectionState = ConnectionStatus.connecting;
  double _tankHeight = 30.0;
  double _waterLevel = 0.0;
  double _lastWaterLevel = 0.0;
  bool _isPumpOn = false;
  bool _isAutoModeOn = true;
  bool _notificationsEnabled = true; // This will now be our initial/default value

  final List<HistoryEvent> _history = [];
  final List<TankLevelEvent> _levelHistory = [];
  final List<DailyStat> _dailyStats = [];

  DatabaseReference? _userRef;

  StreamSubscription<DatabaseEvent>? _sensorDataSubscription;
  StreamSubscription<DatabaseEvent>? _motorHistorySubscription;
  StreamSubscription<DatabaseEvent>? _levelHistorySubscription;
  StreamSubscription<DatabaseEvent>? _statsSubscription;

  // ✅ ADDED a subscription for the settings
  StreamSubscription<DatabaseEvent>? _settingsSubscription;


  bool _loggedFull = false;
  bool _loggedRising50 = false;
  bool _loggedFalling50 = true;
  bool _loggedEmpty = true;

  ConnectionStatus get connectionState => _connectionState;
  double get tankHeight => _tankHeight;
  double get waterLevel => _waterLevel;
  bool get isPumpOn => _isPumpOn;
  bool get isAutoModeOn => _isAutoModeOn;
  bool get notificationsEnabled => _notificationsEnabled;
  List<HistoryEvent> get history => _history;
  List<TankLevelEvent> get levelHistory => _levelHistory;
  List<DailyStat> get dailyStats => _dailyStats;

  TankProvider() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        if (_connectionState == ConnectionStatus.offline) {
          checkConnectivityAndInitialize();
        }
      } else {
        _connectionState = ConnectionStatus.offline;
        notifyListeners();
      }
    });
  }

  Future<void> checkConnectivityAndInitialize() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _connectionState = ConnectionStatus.offline;
      notifyListeners();
    } else {
      _connectionState = ConnectionStatus.connecting;
      notifyListeners();
      _initializeListeners();
    }
  }

  Future<void> _performAuthenticatedOperation(
      Future<void> Function(DatabaseReference userRef) databaseOperation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _connectionState = ConnectionStatus.error;
      notifyListeners();
      print("Error: User is not authenticated.");
      return;
    }

    try {
      await user.getIdToken(true);
      final userRef = FirebaseDatabase.instance.ref('tanks/${user.uid}');
      await databaseOperation(userRef);
    } catch (e) {
      _connectionState = ConnectionStatus.error;
      notifyListeners();
      print("An authentication or database error occurred: $e");
    }
  }

  void _initializeListeners() {
    _performAuthenticatedOperation((userRef) async {
      _userRef = userRef;
      _listenToSensorData();
      _listenToMotorHistory();
      _listenToLevelHistory();
      _listenToDailyStats();
      _listenToSettings(); // ✅ ADDED listener for settings
    });
  }

  void clearData() {
    _connectionState = ConnectionStatus.connecting;
    _sensorDataSubscription?.cancel();
    _motorHistorySubscription?.cancel();
    _levelHistorySubscription?.cancel();
    _statsSubscription?.cancel();
    _settingsSubscription?.cancel(); // ✅ ADDED cancellation
    _waterLevel = 0.0;
    _lastWaterLevel = 0.0;
    _isPumpOn = false;
    _isAutoModeOn = true;
    _notificationsEnabled = true; // Reset to default
    _history.clear();
    _levelHistory.clear();
    _dailyStats.clear();
    notifyListeners();
  }

  // ✅ ADDED THIS NEW FUNCTION to listen for settings changes
  void _listenToSettings() {
    _settingsSubscription?.cancel();
    _settingsSubscription =
        _userRef?.child('settings').onValue.listen((event) {
          try {
            if (event.snapshot.exists && event.snapshot.value != null) {
              final settings =
              Map<String, dynamic>.from(event.snapshot.value as Map);
              // Get the value, default to 'true' if it doesn't exist yet.
              _notificationsEnabled = settings['notifications_enabled'] ?? true;
            } else {
              // If no settings node exists, default to true.
              _notificationsEnabled = true;
            }
            notifyListeners();
          } catch (e) {
            print("Error parsing settings data: $e");
            // Default to true on error to be safe
            _notificationsEnabled = true;
            notifyListeners();
          }
        });
  }


  void _listenToSensorData() {
    _sensorDataSubscription?.cancel();
    _sensorDataSubscription = _userRef?.onValue.listen((event) {
      if (!event.snapshot.exists) {
        _connectionState = ConnectionStatus.error;
        notifyListeners();
        return;
      }
      try {
        if (_connectionState != ConnectionStatus.connected) {
          _connectionState = ConnectionStatus.connected;
        }

        final liveData = event.snapshot.child('live_data').value as Map<dynamic, dynamic>? ?? {};
        final controlsData = event.snapshot.child('controls').value as Map<dynamic, dynamic>? ?? {};

        _tankHeight = (controlsData['tank_height_cm'] as num? ?? 30.0).toDouble();
        _isPumpOn = (controlsData['pump_status'] as bool? ?? false);
        _isAutoModeOn = (controlsData['auto_mode'] as bool? ?? true);

        final bool oldPumpStatus = _isPumpOn;
        _lastWaterLevel = _waterLevel;
        _waterLevel = (liveData['water_level'] as num? ?? 0.0).toDouble();

        if (_isPumpOn != oldPumpStatus) {
          _addMotorHistoryEvent(_isPumpOn ? 'Motor Turned ON' : 'Motor Turned OFF');
        }
        _checkAndLogTankLevelEvents();
        notifyListeners();
      } catch (e) {
        print("Error parsing sensor data: $e");
        _connectionState = ConnectionStatus.error;
        notifyListeners();
      }
    });
  }


  Future<void> updateTankHeight(double newHeight) async {
    await _performAuthenticatedOperation((userRef) async {
      await userRef.child('controls/tank_height_cm').set(newHeight);
    });
  }
  void _listenToMotorHistory() {
    _motorHistorySubscription?.cancel();
    _motorHistorySubscription =
        _userRef?.child('motor_history').onValue.listen((event) {
          try {
            if (event.snapshot.value == null) {
              _history.clear();
              notifyListeners();
              return;
            }
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            _history.clear();
            data.forEach((key, value) {
              final historyEntry = Map<String, dynamic>.from(value as Map);
              final int timestampInMillis = historyEntry['timestamp'] as int;
              final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(timestampInMillis);

              _history.add(HistoryEvent(
                event: historyEntry['event'],
                timestamp: timestamp,
              ));
            });
            _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            notifyListeners();
          } catch (e) {
            print("Error parsing motor history: $e");
          }
        });
  }

  void _listenToLevelHistory() {
    _levelHistorySubscription?.cancel();
    _levelHistorySubscription =
        _userRef?.child('level_history').onValue.listen((event) {
          try {
            if (event.snapshot.value == null) {
              _levelHistory.clear();
              notifyListeners();
              return;
            }
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            _levelHistory.clear();
            data.forEach((key, value) {
              final historyEntry = Map<String, dynamic>.from(value as Map);
              final int timestampInMillis = historyEntry['timestamp'] as int;
              final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(timestampInMillis);

              _levelHistory.add(TankLevelEvent(
                event: historyEntry['event'],
                timestamp: timestamp,
              ));
            });
            _levelHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            notifyListeners();
          } catch (e) {
            print("Error parsing level history: $e");
          }
        });
  }
  void _listenToDailyStats() {
    _statsSubscription?.cancel();
    _statsSubscription =
        _userRef?.child('daily_stats').onValue.listen((event) {
          if (event.snapshot.value == null) {
            _dailyStats.clear();
            notifyListeners();
            return;
          }
          try {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            _dailyStats.clear();
            data.forEach((dateKey, value) {
              final statData = Map<String, dynamic>.from(value as Map);
              _dailyStats.add(DailyStat(
                date: dateKey,
                motorRunTimeSeconds: statData['motor_run_time_seconds'] ?? 0,
                waterUsedPercent: statData['water_used_percent'] ?? 0,
              ));
            });
            _dailyStats.sort((a, b) => b.date.compareTo(a.date));
            notifyListeners();
          } catch (e) {
            print("Error parsing daily stats: $e");
          }
        });
  }
  Future<void> togglePump(bool value) async {
    if (!_isAutoModeOn) {
      await _performAuthenticatedOperation((userRef) async {
        await userRef.child('controls/pump_status').set(value);
      });
    }
  }

  Future<void> toggleAutoMode(bool value) async {
    await _performAuthenticatedOperation((userRef) async {
      await userRef.child('controls/auto_mode').set(value);
      if (!value) {
        await userRef.child('controls/pump_status').set(false);
      }
    });
  }

  // ✅ THIS FUNCTION IS NOW UPGRADED TO WRITE TO FIREBASE
  Future<void> toggleNotifications(bool value) async {
    await _performAuthenticatedOperation((userRef) async {
      await userRef.child('settings/notifications_enabled').set(value);
    });
    // The listener will automatically update the local state,
    // so we don't need to call notifyListeners() here.
  }

  Future<void> _addMotorHistoryEvent(String event) async {
    await _performAuthenticatedOperation((userRef) async {
      await userRef.child('motor_history').push().set({
        'event': event,
        'timestamp': ServerValue.timestamp,
      });
    });
  }

  Future<void> _addLevelHistoryEvent(String event) async {
    await _performAuthenticatedOperation((userRef) async {
      await userRef.child('level_history').push().set({
        'event': event,
        'timestamp': ServerValue.timestamp,
      });
    });
  }

  void _checkAndLogTankLevelEvents() {
    bool isFilling = _waterLevel > _lastWaterLevel;
    bool isDraining = _waterLevel < _lastWaterLevel;

    if (isFilling) {
      if (_waterLevel >= 100 && !_loggedFull) {
        _addLevelHistoryEvent('Tank is Full');
        _loggedFull = true;
      }
      if (_waterLevel >= 50 && !_loggedRising50) {
        _addLevelHistoryEvent('Tank rose past 50%');
        _loggedRising50 = true;
        _loggedFalling50 = false;
      }
      if (_waterLevel > 5) {
        _loggedEmpty = false;
      }
    } else if (isDraining) {
      if (_waterLevel < 50 && !_loggedFalling50) {
        _addLevelHistoryEvent('Tank fell below 50%');
        _loggedFalling50 = true;
        _loggedRising50 = false;
      }
      if (_waterLevel <= 5 && !_loggedEmpty) {
        _addLevelHistoryEvent('Tank is Empty');
        _loggedEmpty = true;
      }
      if (_waterLevel < 100) {
        _loggedFull = false;
      }
    }
  }

  @override
  void dispose() {
    clearData();
    super.dispose();
  }
}