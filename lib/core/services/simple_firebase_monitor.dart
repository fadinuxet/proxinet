import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class SimpleFirebaseMonitor {
  // static final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Removed unused field
  // static final FirebaseAuth _auth = FirebaseAuth.instance; // Removed unused field
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Cost tracking thresholds
  static const double dailyReadLimit = 10000;
  static const double dailyWriteLimit = 10000;
  static const double dailyDeleteLimit = 1000;
  
  static int _dailyReads = 0;
  static int _dailyWrites = 0;
  static int _dailyDeletes = 0;
  
  static DateTime? _lastResetDate;
  static Timer? _monitoringTimer;
  
  /// Initialize simple monitoring
  static Future<void> initialize() async {
    
    
    try {
      // Skip Firestore operations for demo to avoid permission errors
      _resetIfNewDay();
      _startMonitoring();
      
      // print('✅ Simple Firebase monitoring initialized (demo mode)'); // Removed print statement
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error initializing Firebase monitoring: $e');
    }
  }
  
  /// Start monitoring timer
  static void _startMonitoring() {
    _monitoringTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _checkThresholds();
      // Skip save operations in demo mode
      // print('📊 Demo mode: Monitoring timer tick (no Firestore operations)'); // Removed print statement
    });
  }
  
  /// Track a read operation
  static void trackRead() {
    _dailyReads++;
    _checkThresholds();
  }
  
  /// Track a write operation
  static void trackWrite() {
    _dailyWrites++;
    _checkThresholds();
  }
  
  /// Track a delete operation
  static void trackDelete() {
    _dailyDeletes++;
    _checkThresholds();
  }
  
  /// Check if usage is approaching limits
  static void _checkThresholds() {
    // Alert at 80% usage
    if (_dailyReads > dailyReadLimit * 0.8) {
      _logCostAlert('READS', _dailyReads, dailyReadLimit);
    }
    
    if (_dailyWrites > dailyWriteLimit * 0.8) {
      _logCostAlert('WRITES', _dailyWrites, dailyWriteLimit);
    }
    
    if (_dailyDeletes > dailyDeleteLimit * 0.8) {
      _logCostAlert('DELETES', _dailyDeletes, dailyDeleteLimit);
    }
  }
  
  /// Log cost alerts
  static void _logCostAlert(String operation, int current, double limit) {
    final percentage = (current/limit*100).toStringAsFixed(1);
    // print('🚨 FIREBASE COST ALERT: $operation usage at $percentage% ($current/$limit)'); // Removed print statement
    
    // Log to Firestore for monitoring
    _logToFirestore('cost_alert', {
      'operation': operation,
      'current_usage': current,
      'limit': limit,
      'percentage': double.parse(percentage),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Log events to Firestore
  static void _logToFirestore(String eventType, Map<String, dynamic> data) {
    try {
      // Skip Firestore operations for demo to avoid permission errors
      
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error logging to Firestore: $e');
    }
  }
  
  /// Get current usage statistics
  static Map<String, dynamic> getUsageStats() {
    return {
      'dailyReads': _dailyReads,
      'dailyWrites': _dailyWrites,
      'dailyDeletes': _dailyDeletes,
      'readLimit': dailyReadLimit,
      'writeLimit': dailyWriteLimit,
      'deleteLimit': dailyDeleteLimit,
      'readPercentage': (_dailyReads / dailyReadLimit * 100).toStringAsFixed(1),
      'writePercentage': (_dailyWrites / dailyWriteLimit * 100).toStringAsFixed(1),
      'deletePercentage': (_dailyDeletes / dailyDeleteLimit * 100).toStringAsFixed(1),
    };
  }
  
  /// Reset daily counts if it's a new day
  static void _resetIfNewDay() {
    final now = DateTime.now();
    if (_lastResetDate == null || 
        _lastResetDate!.day != now.day || 
        _lastResetDate!.month != now.month || 
        _lastResetDate!.year != now.year) {
      _dailyReads = 0;
      _dailyWrites = 0;
      _dailyDeletes = 0;
      _lastResetDate = now;
      
    }
  }
  
  // /// Load daily counts from storage
  // static Future<void> _loadDailyCounts() async {
  //   try {
  //     // Skip Firestore operations for demo to avoid permission errors
  //     
  //     _resetIfNewDay();
  //   } catch (e) {
  //     // Log error but don't throw - this is a background operation
  //     debugPrint('Error loading daily counts: $e');
  //   }
  // }
  
  // /// Save daily counts to storage
  // static Future<void> _saveDailyCounts() async {
  //   try {
  //     // Skip Firestore operations for demo to avoid permission errors
  //     
  //   } catch (e) {
  //     // Log error but don't throw - this is a background operation
  //     debugPrint('Error saving daily counts: $e');
  //   }
  // }
  
  /// Track Putrace-specific events
  static void trackPutraceEvent(String eventName, Map<String, dynamic> parameters) {
    _logToFirestore('putrace_$eventName', {
      ...parameters,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Track BLE events
  static void trackBLEEvent(String eventType, Map<String, dynamic> data) {
    _logToFirestore('ble_$eventType', {
      ...data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Track location events
  static void trackLocationEvent(String eventType, Map<String, dynamic> data) {
    _logToFirestore('location_$eventType', {
      ...data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Track user engagement
  static void trackUserEngagement(String action, String screen, int timeSpentSeconds) {
    _logToFirestore('user_engagement', {
      'action': action,
      'screen': screen,
      'time_spent_seconds': timeSpentSeconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Get device information
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'isLowEnd': androidInfo.version.sdkInt < 24,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'version': iosInfo.systemVersion,
          'model': iosInfo.model,
          'name': iosInfo.name,
          'isLowEnd': iosInfo.systemVersion.compareTo('13.0') < 0,
        };
      }
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error getting device info: $e');
    }
    
    return {'platform': 'Unknown', 'isLowEnd': true};
  }
  
  /// Dispose monitoring
  static void dispose() {
    _monitoringTimer?.cancel();
  }
}
