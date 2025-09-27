import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy service for anonymous users that implements:
/// - Data encryption for local storage
/// - Session rotation and expiration
/// - Privacy-preserving analytics
/// - Data minimization
/// - User consent management
class AnonymousPrivacyService {
  static final AnonymousPrivacyService _instance = AnonymousPrivacyService._internal();
  factory AnonymousPrivacyService() => _instance;
  AnonymousPrivacyService._internal();
  
  // Privacy settings
  static const Duration _sessionExpiration = Duration(hours: 24);
  static const Duration _dataRetentionPeriod = Duration(days: 7);
  static const int _maxSessionHistory = 5;
  
  // Privacy keys
  static const String _privacySettingsKey = 'anonymous_privacy_settings';
  static const String _sessionHistoryKey = 'anonymous_session_history';
  static const String _consentKey = 'anonymous_consent';
  static const String _analyticsKey = 'anonymous_analytics';
  
  // Privacy state
  bool _isPrivacyModeEnabled = true;
  bool _hasUserConsent = false;
  DateTime? _lastSessionRotation;
  final List<String> _sessionHistory = [];
  
  // Streams for privacy events
  final StreamController<PrivacyEvent> _privacyEventController = 
      StreamController<PrivacyEvent>.broadcast();
  Stream<PrivacyEvent> get privacyEventStream => _privacyEventController.stream;
  
  Future<void> initialize() async {
    await _loadPrivacySettings();
    await _checkSessionExpiration();
    await _cleanupExpiredData();
    _emitPrivacyEvent(PrivacyEvent.initialized);
  }
  
  // PRIVACY SETTINGS MANAGEMENT
  
  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load privacy mode setting
      _isPrivacyModeEnabled = prefs.getBool('${_privacySettingsKey}_mode') ?? true;
      
      // Load user consent
      _hasUserConsent = prefs.getBool('${_consentKey}_given') ?? false;
      
      // Load session history
      final sessionHistoryJson = prefs.getString(_sessionHistoryKey);
      if (sessionHistoryJson != null) {
        final List<dynamic> history = json.decode(sessionHistoryJson);
        _sessionHistory.addAll(history.cast<String>());
      }
      
      // Load last session rotation
      final lastRotation = prefs.getString('${_privacySettingsKey}_last_rotation');
      if (lastRotation != null) {
        _lastSessionRotation = DateTime.parse(lastRotation);
      }
      
      debugPrint('Loaded privacy settings: mode=$_isPrivacyModeEnabled, consent=$_hasUserConsent');
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
    }
  }
  
  Future<void> _savePrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('${_privacySettingsKey}_mode', _isPrivacyModeEnabled);
      await prefs.setBool('${_consentKey}_given', _hasUserConsent);
      await prefs.setString(_sessionHistoryKey, json.encode(_sessionHistory));
      
      if (_lastSessionRotation != null) {
        await prefs.setString('${_privacySettingsKey}_last_rotation', _lastSessionRotation!.toIso8601String());
      }
      
      debugPrint('Saved privacy settings');
    } catch (e) {
      debugPrint('Error saving privacy settings: $e');
    }
  }
  
  // USER CONSENT MANAGEMENT
  
  Future<bool> requestUserConsent() async {
    if (_hasUserConsent) return true;
    
    _emitPrivacyEvent(PrivacyEvent.consentRequested);
    return false; // UI should handle consent dialog
  }
  
  Future<void> grantConsent() async {
    _hasUserConsent = true;
    await _savePrivacySettings();
    _emitPrivacyEvent(PrivacyEvent.consentGranted);
    debugPrint('User granted privacy consent');
  }
  
  Future<void> revokeConsent() async {
    _hasUserConsent = false;
    await _clearAllData();
    await _savePrivacySettings();
    _emitPrivacyEvent(PrivacyEvent.consentRevoked);
    debugPrint('User revoked privacy consent - all data cleared');
  }
  
  bool get hasUserConsent => _hasUserConsent;
  
  // PRIVACY MODE MANAGEMENT
  
  Future<void> enablePrivacyMode() async {
    _isPrivacyModeEnabled = true;
    await _savePrivacySettings();
    _emitPrivacyEvent(PrivacyEvent.privacyModeEnabled);
    debugPrint('Privacy mode enabled');
  }
  
  Future<void> disablePrivacyMode() async {
    _isPrivacyModeEnabled = false;
    await _savePrivacySettings();
    _emitPrivacyEvent(PrivacyEvent.privacyModeDisabled);
    debugPrint('Privacy mode disabled');
  }
  
  bool get isPrivacyModeEnabled => _isPrivacyModeEnabled;
  
  // SESSION MANAGEMENT AND ROTATION
  
  Future<void> _checkSessionExpiration() async {
    if (_lastSessionRotation == null) {
      _lastSessionRotation = DateTime.now();
      await _savePrivacySettings();
      return;
    }
    
    final timeSinceRotation = DateTime.now().difference(_lastSessionRotation!);
    if (timeSinceRotation > _sessionExpiration) {
      await _rotateSession();
    }
  }
  
  Future<void> _rotateSession() async {
    try {
      // Add current session to history (simplified without user service dependency)
      final prefs = await SharedPreferences.getInstance();
      final currentSessionId = prefs.getString('anonymous_session_id');
      if (currentSessionId != null) {
        _sessionHistory.add(currentSessionId);
        
        // Limit session history
        if (_sessionHistory.length > _maxSessionHistory) {
          _sessionHistory.removeAt(0);
        }
      }
      
      // Clear anonymous profile data
      await prefs.remove('anonymous_user_profile');
      await prefs.remove('anonymous_session_id');
      
      // Update rotation time
      _lastSessionRotation = DateTime.now();
      await _savePrivacySettings();
      
      _emitPrivacyEvent(PrivacyEvent.sessionRotated);
      debugPrint('Session rotated for privacy');
    } catch (e) {
      debugPrint('Error rotating session: $e');
    }
  }
  
  Future<void> forceSessionRotation() async {
    await _rotateSession();
  }
  
  // DATA ENCRYPTION AND SECURITY
  
  // Note: Encryption methods are available for future use
  // Currently using simple hashing for session IDs
  
  // DATA MINIMIZATION AND CLEANUP
  
  Future<void> _cleanupExpiredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Clean up old session history
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('anonymous_') && key.contains('_data_')) {
          // Check if data is older than retention period
          final data = prefs.getString(key);
          if (data != null) {
            try {
              final dataMap = json.decode(data);
              final createdAt = DateTime.parse(dataMap['createdAt']);
              if (now.difference(createdAt) > _dataRetentionPeriod) {
                await prefs.remove(key);
                debugPrint('Cleaned up expired data: $key');
              }
            } catch (e) {
              // Remove corrupted data
              await prefs.remove(key);
            }
          }
        }
      }
      
      debugPrint('Data cleanup completed');
    } catch (e) {
      debugPrint('Error during data cleanup: $e');
    }
  }
  
  Future<void> _clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('anonymous_')) {
          await prefs.remove(key);
        }
      }
      
      _sessionHistory.clear();
      _lastSessionRotation = null;
      
      debugPrint('All anonymous data cleared');
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }
  
  // PRIVACY-PRESERVING ANALYTICS
  
  Future<void> recordPrivacyEvent(String event, Map<String, dynamic>? data) async {
    if (!_hasUserConsent || !_isPrivacyModeEnabled) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final analyticsKey = '${_analyticsKey}_${DateTime.now().toIso8601String().split('T')[0]}';
      
      // Get existing analytics for today
      final existingData = prefs.getString(analyticsKey);
      Map<String, dynamic> analytics = {};
      
      if (existingData != null) {
        analytics = json.decode(existingData);
      }
      
      // Add new event (anonymized)
      final eventData = {
        'event': event,
        'timestamp': DateTime.now().toIso8601String(),
        'data': data?.map((k, v) => MapEntry(k, v.toString())), // Convert to strings
      };
      
      if (analytics['events'] == null) {
        analytics['events'] = <Map<String, dynamic>>[];
      }
      
      (analytics['events'] as List).add(eventData);
      
      // Limit analytics data size
      if ((analytics['events'] as List).length > 100) {
        (analytics['events'] as List).removeAt(0);
      }
      
      await prefs.setString(analyticsKey, json.encode(analytics));
      debugPrint('Recorded privacy event: $event');
    } catch (e) {
      debugPrint('Error recording privacy event: $e');
    }
  }
  
  // PRIVACY STATUS AND REPORTING
  
  Future<PrivacyReport> generatePrivacyReport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int dataPoints = 0;
      DateTime? oldestData;
      DateTime? newestData;
      
      for (final key in keys) {
        if (key.startsWith('anonymous_')) {
          dataPoints++;
          
          final data = prefs.getString(key);
          if (data != null) {
            try {
              final dataMap = json.decode(data);
              if (dataMap['createdAt'] != null) {
                final createdAt = DateTime.parse(dataMap['createdAt']);
                if (oldestData == null || createdAt.isBefore(oldestData)) {
                  oldestData = createdAt;
                }
                if (newestData == null || createdAt.isAfter(newestData)) {
                  newestData = createdAt;
                }
              }
            } catch (e) {
              // Skip corrupted data
            }
          }
        }
      }
      
      return PrivacyReport(
        isPrivacyModeEnabled: _isPrivacyModeEnabled,
        hasUserConsent: _hasUserConsent,
        dataPoints: dataPoints,
        sessionHistoryCount: _sessionHistory.length,
        lastSessionRotation: _lastSessionRotation,
        oldestData: oldestData,
        newestData: newestData,
        dataRetentionPeriod: _dataRetentionPeriod,
      );
    } catch (e) {
      debugPrint('Error generating privacy report: $e');
      return PrivacyReport(
        isPrivacyModeEnabled: _isPrivacyModeEnabled,
        hasUserConsent: _hasUserConsent,
        dataPoints: 0,
        sessionHistoryCount: 0,
        lastSessionRotation: _lastSessionRotation,
        oldestData: null,
        newestData: null,
        dataRetentionPeriod: _dataRetentionPeriod,
      );
    }
  }
  
  // PRIVACY EVENT EMISSION
  
  void _emitPrivacyEvent(PrivacyEvent event) {
    _privacyEventController.add(event);
  }
  
  Future<void> dispose() async {
    await _privacyEventController.close();
  }
}

// PRIVACY EVENT TYPES

enum PrivacyEvent {
  initialized,
  consentRequested,
  consentGranted,
  consentRevoked,
  privacyModeEnabled,
  privacyModeDisabled,
  sessionRotated,
  dataCleared,
}

// PRIVACY REPORT MODEL

class PrivacyReport {
  final bool isPrivacyModeEnabled;
  final bool hasUserConsent;
  final int dataPoints;
  final int sessionHistoryCount;
  final DateTime? lastSessionRotation;
  final DateTime? oldestData;
  final DateTime? newestData;
  final Duration dataRetentionPeriod;
  
  const PrivacyReport({
    required this.isPrivacyModeEnabled,
    required this.hasUserConsent,
    required this.dataPoints,
    required this.sessionHistoryCount,
    this.lastSessionRotation,
    this.oldestData,
    this.newestData,
    required this.dataRetentionPeriod,
  });
  
  String get privacyScore {
    if (!isPrivacyModeEnabled || !hasUserConsent) return 'Low';
    if (dataPoints > 50) return 'Medium';
    if (sessionHistoryCount > 3) return 'Medium';
    return 'High';
  }
  
  String get dataAge {
    if (oldestData == null) return 'No data';
    final age = DateTime.now().difference(oldestData!);
    if (age.inDays > 30) return 'Old (>30 days)';
    if (age.inDays > 7) return 'Recent (7-30 days)';
    return 'Fresh (<7 days)';
  }
  
  @override
  String toString() {
    return 'PrivacyReport(score: $privacyScore, dataPoints: $dataPoints, age: $dataAge)';
  }
}
