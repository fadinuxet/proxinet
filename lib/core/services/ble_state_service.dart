import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service to manage BLE state across the app
/// Ensures BLE settings and Nearby mode stay in sync
class BLEStateService {
  static final BLEStateService _instance = BLEStateService._internal();
  factory BLEStateService() => _instance;
  BLEStateService._internal();

  final StreamController<bool> _bleEnabledController = StreamController<bool>.broadcast();
  Stream<bool> get bleEnabledStream => _bleEnabledController.stream;

  bool _isBLEEnabled = false;
  bool get isBLEEnabled => _isBLEEnabled;

  /// Enable BLE and notify all listeners
  void enableBLE() {
    if (!_isBLEEnabled) {
      _isBLEEnabled = true;
      _bleEnabledController.add(_isBLEEnabled);
      debugPrint('BLE enabled via BLEStateService');
    }
  }

  /// Disable BLE and notify all listeners
  void disableBLE() {
    if (_isBLEEnabled) {
      _isBLEEnabled = false;
      _bleEnabledController.add(_isBLEEnabled);
      debugPrint('BLE disabled via BLEStateService');
    }
  }

  /// Set BLE state (used by settings page)
  void setBLEState(bool enabled) {
    if (_isBLEEnabled != enabled) {
      _isBLEEnabled = enabled;
      _bleEnabledController.add(_isBLEEnabled);
      debugPrint('BLE state set to: $enabled via BLEStateService');
    }
  }

  /// Initialize with current state
  void initialize(bool initialState) {
    _isBLEEnabled = initialState;
    _bleEnabledController.add(_isBLEEnabled);
    debugPrint('BLEStateService initialized with state: $initialState');
  }

  Future<void> dispose() async {
    await _bleEnabledController.close();
  }
}
