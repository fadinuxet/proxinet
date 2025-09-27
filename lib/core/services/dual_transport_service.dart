import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'anonymous_ble_service.dart';
import '../../features/putrace/data/services/user_discovery_service.dart';

/// Dual Transport Service - Inspired by Bitchat's architecture
/// Provides BLE + Internet fallback for maximum reliability
class DualTransportService {
  static final DualTransportService _instance = DualTransportService._internal();
  factory DualTransportService() => _instance;
  DualTransportService._internal();
  
  final AnonymousBLEService _anonymousBLEService = AnonymousBLEService();
  final UserDiscoveryService _userDiscoveryService = UserDiscoveryService();
  final Connectivity _connectivity = Connectivity();
  
  // Transport state
  TransportMode _currentMode = TransportMode.ble;
  bool _isInternetAvailable = false;
  bool _isBLEAvailable = false;
  bool _isScanning = false;
  
  // Streams for transport events
  final StreamController<TransportEvent> _transportEventController = 
      StreamController<TransportEvent>.broadcast();
  Stream<TransportEvent> get transportEventStream => _transportEventController.stream;
  
  // Discovery results
  final StreamController<List<DiscoveredUser>> _discoveryController = 
      StreamController<List<DiscoveredUser>>.broadcast();
  Stream<List<DiscoveredUser>> get discoveryStream => _discoveryController.stream;
  
  // Combined results
  final Map<String, DiscoveredUser> _combinedResults = {};
  
  Future<void> initialize() async {
    await _checkConnectivity();
    await _checkBLEAvailability();
    _startConnectivityMonitoring();
    _emitTransportEvent(TransportEvent.initialized);
  }
  
  // CONNECTIVITY MONITORING
  
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      _isInternetAvailable = !connectivityResults.contains(ConnectivityResult.none);
      debugPrint('Internet connectivity: $_isInternetAvailable');
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isInternetAvailable = false;
    }
  }
  
  Future<void> _checkBLEAvailability() async {
    try {
      // Check if BLE is available and enabled
      _isBLEAvailable = await _anonymousBLEService.initialize();
      debugPrint('BLE availability: $_isBLEAvailable');
    } catch (e) {
      debugPrint('Error checking BLE availability: $e');
      _isBLEAvailable = false;
    }
  }
  
  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasInternetAvailable = _isInternetAvailable;
      _isInternetAvailable = !results.contains(ConnectivityResult.none);
      
      if (wasInternetAvailable != _isInternetAvailable) {
        _onConnectivityChanged();
      }
    });
  }
  
  void _onConnectivityChanged() {
    debugPrint('Connectivity changed: internet=$_isInternetAvailable');
    _emitTransportEvent(TransportEvent.connectivityChanged);
    
    // Adjust transport mode based on new connectivity
    _adjustTransportMode();
  }
  
  // TRANSPORT MODE MANAGEMENT
  
  void _adjustTransportMode() {
    TransportMode newMode;
    
    if (_isInternetAvailable && _isBLEAvailable) {
      newMode = TransportMode.hybrid;
    } else if (_isInternetAvailable) {
      newMode = TransportMode.internet;
    } else if (_isBLEAvailable) {
      newMode = TransportMode.ble;
    } else {
      newMode = TransportMode.offline;
    }
    
    if (newMode != _currentMode) {
      _currentMode = newMode;
      _emitTransportEvent(TransportEvent.modeChanged);
      debugPrint('Transport mode changed to: $_currentMode');
    }
  }
  
  // DISCOVERY METHODS
  
  Future<void> startDiscovery() async {
    if (_isScanning) return;
    
    _isScanning = true;
    _combinedResults.clear();
    _emitTransportEvent(TransportEvent.discoveryStarted);
    
    try {
      switch (_currentMode) {
        case TransportMode.hybrid:
          await _startHybridDiscovery();
          break;
        case TransportMode.internet:
          await _startInternetDiscovery();
          break;
        case TransportMode.ble:
          await _startBLEDiscovery();
          break;
        case TransportMode.offline:
          debugPrint('No transport available for discovery');
          break;
      }
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      _isScanning = false;
      _emitTransportEvent(TransportEvent.discoveryError);
    }
  }
  
  Future<void> _startHybridDiscovery() async {
    debugPrint('Starting hybrid discovery (BLE + Internet)');
    
    // Start both BLE and Internet discovery simultaneously
    final futures = <Future>[];
    
    if (_isBLEAvailable) {
      futures.add(_startBLEDiscovery());
    }
    
    if (_isInternetAvailable) {
      futures.add(_startInternetDiscovery());
    }
    
    // Wait for both to complete
    await Future.wait(futures);
  }
  
  Future<void> _startBLEDiscovery() async {
    try {
      await _anonymousBLEService.startScanning();
      
      // Listen to BLE discovery results
      _anonymousBLEService.nearbyDevicesStream.listen((devices) {
        for (final device in devices) {
          final user = DiscoveredUser(
            id: device.id,
            name: '${device.userData.role} from ${device.userData.company ?? 'Unknown'}',
            proximity: device.proximity,
            distance: device.distance,
            source: DiscoverySource.ble,
            lastSeen: device.lastSeen,
          );
          
          _addDiscoveredUser(user);
        }
      });
      
      debugPrint('BLE discovery started');
    } catch (e) {
      debugPrint('Error starting BLE discovery: $e');
    }
  }
  
  Future<void> _startInternetDiscovery() async {
    try {
      // Start Internet-based discovery
      // Note: UserDiscoveryService doesn't have startDiscovery method
      // This would need to be implemented or use existing methods
      
      // Listen to Internet discovery results
      _userDiscoveryService.nearbyUsersStream.listen((users) {
        for (final user in users) {
          final discoveredUser = DiscoveredUser(
            id: user.id,
            name: user.name,
            proximity: 'Online',
            distance: 0.0,
            source: DiscoverySource.internet,
            lastSeen: DateTime.now(),
          );
          
          _addDiscoveredUser(discoveredUser);
        }
      });
      
      debugPrint('Internet discovery started');
    } catch (e) {
      debugPrint('Error starting Internet discovery: $e');
    }
  }
  
  void _addDiscoveredUser(DiscoveredUser user) {
    // Add or update user in combined results
    _combinedResults[user.id] = user;
    
    // Emit updated results
    _discoveryController.add(_combinedResults.values.toList());
  }
  
  Future<void> stopDiscovery() async {
    if (!_isScanning) return;
    
    try {
      await _anonymousBLEService.stopScanning();
      // Stop Internet-based discovery
      // Note: UserDiscoveryService doesn't have stopDiscovery method
      // This would need to be implemented or use existing methods
      
      _isScanning = false;
      _emitTransportEvent(TransportEvent.discoveryStopped);
      debugPrint('Discovery stopped');
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
  }
  
  // TRANSPORT STATUS
  
  TransportMode get currentMode => _currentMode;
  bool get isInternetAvailable => _isInternetAvailable;
  bool get isBLEAvailable => _isBLEAvailable;
  bool get isScanning => _isScanning;
  
  String get transportStatus {
    switch (_currentMode) {
      case TransportMode.hybrid:
        return 'Hybrid (BLE + Internet)';
      case TransportMode.internet:
        return 'Internet Only';
      case TransportMode.ble:
        return 'BLE Only';
      case TransportMode.offline:
        return 'Offline';
    }
  }
  
  // RELIABILITY METRICS
  
  Future<TransportReliabilityReport> getReliabilityReport() async {
    return TransportReliabilityReport(
      currentMode: _currentMode,
      isInternetAvailable: _isInternetAvailable,
      isBLEAvailable: _isBLEAvailable,
      discoveryResults: _combinedResults.length,
      lastModeChange: DateTime.now(),
      uptime: Duration.zero, // TODO: Implement uptime tracking
    );
  }
  
  // TRANSPORT EVENT EMISSION
  
  void _emitTransportEvent(TransportEvent event) {
    _transportEventController.add(event);
  }
  
  Future<void> dispose() async {
    await _transportEventController.close();
    await _discoveryController.close();
    await _anonymousBLEService.dispose();
  }
}

// TRANSPORT MODES

enum TransportMode {
  hybrid,    // BLE + Internet
  internet,  // Internet only
  ble,       // BLE only
  offline,   // No transport available
}

// DISCOVERY SOURCES

enum DiscoverySource {
  ble,
  internet,
  hybrid,
}

// TRANSPORT EVENTS

enum TransportEvent {
  initialized,
  connectivityChanged,
  modeChanged,
  discoveryStarted,
  discoveryStopped,
  discoveryError,
}

// DISCOVERED USER MODEL

class DiscoveredUser {
  final String id;
  final String name;
  final String proximity;
  final double distance;
  final DiscoverySource source;
  final DateTime lastSeen;
  
  const DiscoveredUser({
    required this.id,
    required this.name,
    required this.proximity,
    required this.distance,
    required this.source,
    required this.lastSeen,
  });
  
  @override
  String toString() {
    return 'DiscoveredUser(id: $id, name: $name, proximity: $proximity, source: $source)';
  }
}

// RELIABILITY REPORT MODEL

class TransportReliabilityReport {
  final TransportMode currentMode;
  final bool isInternetAvailable;
  final bool isBLEAvailable;
  final int discoveryResults;
  final DateTime lastModeChange;
  final Duration uptime;
  
  const TransportReliabilityReport({
    required this.currentMode,
    required this.isInternetAvailable,
    required this.isBLEAvailable,
    required this.discoveryResults,
    required this.lastModeChange,
    required this.uptime,
  });
  
  String get reliabilityScore {
    if (currentMode == TransportMode.hybrid) return 'High';
    if (currentMode == TransportMode.internet) return 'Medium';
    if (currentMode == TransportMode.ble) return 'Medium';
    return 'Low';
  }
  
  @override
  String toString() {
    return 'TransportReliabilityReport(mode: $currentMode, score: $reliabilityScore, results: $discoveryResults)';
  }
}
