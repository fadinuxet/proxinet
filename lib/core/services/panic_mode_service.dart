import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'anonymous_privacy_service.dart';
import 'anonymous_user_service.dart';

/// Panic Mode Service - Inspired by Bitchat's panic mode
/// Provides instant data wipe functionality for enterprise-grade security
class PanicModeService {
  static final PanicModeService _instance = PanicModeService._internal();
  factory PanicModeService() => _instance;
  PanicModeService._internal();
  
  final AnonymousPrivacyService _privacyService = AnonymousPrivacyService();
  final AnonymousUserService _anonymousUserService = AnonymousUserService();
  
  // Panic mode state
  bool _isPanicModeActive = false;
  DateTime? _lastPanicActivation;
  int _panicActivationCount = 0;
  
  // Streams for panic mode events
  final StreamController<PanicModeEvent> _panicEventController = 
      StreamController<PanicModeEvent>.broadcast();
  Stream<PanicModeEvent> get panicEventStream => _panicEventController.stream;
  
  // Panic mode settings
  static const String _panicSettingsKey = 'panic_mode_settings';
  // static const String _panicHistoryKey = 'panic_mode_history'; // Unused for now
  static const String _auditLogKey = 'panic_mode_audit_log';
  
  Future<void> initialize() async {
    await _loadPanicSettings();
    _emitPanicEvent(PanicModeEvent.initialized);
  }
  
  // PANIC MODE ACTIVATION
  
  Future<void> activatePanicMode({String? reason, bool auditLog = true}) async {
    if (_isPanicModeActive) {
      debugPrint('Panic mode already active');
      return;
    }
    
    try {
      _isPanicModeActive = true;
      _lastPanicActivation = DateTime.now();
      _panicActivationCount++;
      
      // Log panic activation
      if (auditLog) {
        await _logPanicActivation(reason ?? 'User initiated');
      }
      
      // Immediate data wipe
      await _performImmediateDataWipe();
      
      // Clear all anonymous data
      await _anonymousUserService.clearProfile();
      await _privacyService.revokeConsent();
      
      // Clear all local storage
      await _clearAllLocalData();
      
      _emitPanicEvent(PanicModeEvent.activated);
      debugPrint('Panic mode activated - all data wiped');
      
    } catch (e) {
      debugPrint('Error activating panic mode: $e');
      _isPanicModeActive = false;
    }
  }
  
  Future<void> _performImmediateDataWipe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Wipe all anonymous data
      for (final key in keys) {
        if (key.startsWith('anonymous_') || 
            key.startsWith('putrace_') ||
            key.startsWith('user_') ||
            key.startsWith('session_')) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('Immediate data wipe completed');
    } catch (e) {
      debugPrint('Error during immediate data wipe: $e');
    }
  }
  
  Future<void> _clearAllLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('All local data cleared');
    } catch (e) {
      debugPrint('Error clearing all local data: $e');
    }
  }
  
  // AUDIT LOGGING
  
  Future<void> _logPanicActivation(String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auditLog = prefs.getStringList(_auditLogKey) ?? [];
      
      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'reason': reason,
        'activationCount': _panicActivationCount,
        'deviceInfo': await _getDeviceInfo(),
      };
      
      auditLog.add(logEntry.toString());
      
      // Keep only last 10 entries
      if (auditLog.length > 10) {
        auditLog.removeAt(0);
      }
      
      await prefs.setStringList(_auditLogKey, auditLog);
      debugPrint('Panic activation logged: $reason');
    } catch (e) {
      debugPrint('Error logging panic activation: $e');
    }
  }
  
  Future<String> _getDeviceInfo() async {
    // Basic device info for audit purposes
    return 'Platform: ${defaultTargetPlatform.name}';
  }
  
  // PANIC MODE SETTINGS
  
  Future<void> _loadPanicSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isPanicModeActive = prefs.getBool('${_panicSettingsKey}_active') ?? false;
      _panicActivationCount = prefs.getInt('${_panicSettingsKey}_count') ?? 0;
      
      final lastActivation = prefs.getString('${_panicSettingsKey}_last_activation');
      if (lastActivation != null) {
        _lastPanicActivation = DateTime.parse(lastActivation);
      }
      
      debugPrint('Loaded panic mode settings: active=$_isPanicModeActive, count=$_panicActivationCount');
    } catch (e) {
      debugPrint('Error loading panic mode settings: $e');
    }
  }
  
  Future<void> _savePanicSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('${_panicSettingsKey}_active', _isPanicModeActive);
      await prefs.setInt('${_panicSettingsKey}_count', _panicActivationCount);
      
      if (_lastPanicActivation != null) {
        await prefs.setString('${_panicSettingsKey}_last_activation', _lastPanicActivation!.toIso8601String());
      }
      
      debugPrint('Saved panic mode settings');
    } catch (e) {
      debugPrint('Error saving panic mode settings: $e');
    }
  }
  
  // PANIC MODE STATUS
  
  bool get isPanicModeActive => _isPanicModeActive;
  DateTime? get lastPanicActivation => _lastPanicActivation;
  int get panicActivationCount => _panicActivationCount;
  
  // ENTERPRISE FEATURES
  
  Future<void> resetPanicMode() async {
    _isPanicModeActive = false;
    await _savePanicSettings();
    _emitPanicEvent(PanicModeEvent.reset);
    debugPrint('Panic mode reset');
  }
  
  Future<List<Map<String, dynamic>>> getAuditLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auditLog = prefs.getStringList(_auditLogKey) ?? [];
      
      return auditLog.map((entry) {
        // Parse log entry (simplified)
        return {
          'entry': entry,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting audit log: $e');
      return [];
    }
  }
  
  Future<void> clearAuditLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_auditLogKey);
      debugPrint('Audit log cleared');
    } catch (e) {
      debugPrint('Error clearing audit log: $e');
    }
  }
  
  // PRIVACY EVENT EMISSION
  
  void _emitPanicEvent(PanicModeEvent event) {
    _panicEventController.add(event);
  }
  
  Future<void> dispose() async {
    await _panicEventController.close();
  }
}

// PANIC MODE EVENT TYPES

enum PanicModeEvent {
  initialized,
  activated,
  reset,
  auditLogCleared,
}

// PANIC MODE CONFIGURATION

class PanicModeConfig {
  final bool enableAuditLogging;
  final bool enableEnterpriseFeatures;
  final Duration auditLogRetention;
  final int maxAuditLogEntries;
  
  const PanicModeConfig({
    this.enableAuditLogging = true,
    this.enableEnterpriseFeatures = false,
    this.auditLogRetention = const Duration(days: 90),
    this.maxAuditLogEntries = 100,
  });
}
