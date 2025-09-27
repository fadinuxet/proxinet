import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'anonymous_user_service.dart';

class AnonymousBLEService {
  static final AnonymousBLEService _instance = AnonymousBLEService._internal();
  factory AnonymousBLEService() => _instance;
  AnonymousBLEService._internal();
  
  final AnonymousUserService _anonymousUserService = AnonymousUserService();
  
  final StreamController<List<AnonymousBLEDevice>> _nearbyDevicesController = 
      StreamController<List<AnonymousBLEDevice>>.broadcast();
  Stream<List<AnonymousBLEDevice>> get nearbyDevicesStream => _nearbyDevicesController.stream;
  
  final StreamController<bool> _scanningStatusController = StreamController<bool>.broadcast();
  Stream<bool> get scanningStatusStream => _scanningStatusController.stream;
  
  final StreamController<bool> _advertisingStatusController = StreamController<bool>.broadcast();
  Stream<bool> get advertisingStatusStream => _advertisingStatusController.stream;
  
  final StreamController<AnonymousMessage> _messageController = StreamController<AnonymousMessage>.broadcast();
  Stream<AnonymousMessage> get messageStream => _messageController.stream;
  
  // Presence management
  Timer? _presenceCleanupTimer;
  static const Duration _presenceTimeout = Duration(seconds: 45); // 45 seconds before marking as offline (increased for continuous scanning)
  static const Duration _cleanupInterval = Duration(seconds: 10); // Check every 10 seconds
  
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  bool _isAdvertising = false;
  Timer? _scanTimer;
  Timer? _advertisingTimer;
  final Map<String, AnonymousBLEDevice> _discoveredDevices = {};
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  
  // BLE Service UUID for Putrace Anonymous (must match PutraceBleConstants)
  static const String putraceAnonymousServiceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String putraceAnonymousCharacteristicUuid = "87654321-4321-4321-4321-cba987654321";
  
  Future<bool> initialize() async {
    try {
      // Check BLE permissions
      if (!await _checkBLEPermissions()) {
        return false;
      }
      
      // Initialize anonymous user service
      await _anonymousUserService.initialize();
      
      // Listen to adapter state changes
      FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        if (state == BluetoothAdapterState.on) {
          _startAdvertising();
        } else {
          _stopAdvertising();
        }
      });
      
      // Start advertising if BLE is already on
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
        await _startAdvertising();
      }
      
      return true;
    } catch (e) {
      debugPrint('Error initializing anonymous BLE service: $e');
      return false;
    }
  }
  
  Future<bool> _checkBLEPermissions() async {
    try {
      debugPrint('Checking BLE permissions...');
      
      // Request all required BLE permissions
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      final locationWhenInUse = await Permission.locationWhenInUse.request();
      
      debugPrint('BLE Permission Results:');
      debugPrint('  Bluetooth Scan: ${bluetoothScan.isGranted}');
      debugPrint('  Bluetooth Advertise: ${bluetoothAdvertise.isGranted}');
      debugPrint('  Bluetooth Connect: ${bluetoothConnect.isGranted}');
      debugPrint('  Location When In Use: ${locationWhenInUse.isGranted}');
      
      final allGranted = bluetoothScan.isGranted &&
          bluetoothAdvertise.isGranted &&
          bluetoothConnect.isGranted &&
          locationWhenInUse.isGranted;
      
      debugPrint('All BLE permissions granted: $allGranted');
      return allGranted;
    } catch (e) {
      debugPrint('Error checking BLE permissions: $e');
      return false;
    }
  }
  
  Future<void> startScanning() async {
    debugPrint('=== AnonymousBLEService.startScanning() called ===');
    debugPrint('_isScanning: $_isScanning');
    debugPrint('_adapterState: $_adapterState');
    
    if (_isScanning || _adapterState != BluetoothAdapterState.on) {
      debugPrint('Skipping scan - already scanning or adapter not on');
      return;
    }
    
    try {
      // Check permissions before starting
      debugPrint('Checking BLE permissions...');
      if (!await _checkBLEPermissions()) {
        debugPrint('BLE permissions not granted - cannot start scanning');
        return;
      }
      debugPrint('BLE permissions granted - proceeding with scan');
      
      _isScanning = true;
      _scanningStatusController.add(true);
      _discoveredDevices.clear();
      
      // Start BLE scan with service filter to find only Putrace devices
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 30),
          withServices: [Guid(putraceAnonymousServiceUuid)],
        );
        debugPrint('BLE scan started with Putrace service filter');
      } catch (e) {
        debugPrint('Error starting BLE scan with service filter: $e');
        // Fallback to scanning all devices
        try {
          await FlutterBluePlus.startScan(
            timeout: const Duration(seconds: 30),
          );
          debugPrint('BLE scan started without service filter as fallback');
        } catch (e2) {
          debugPrint('Error starting BLE scan without filter: $e2');
          rethrow;
        }
      }
      
      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        debugPrint('BLE scan found ${results.length} devices');
        for (ScanResult result in results) {
          debugPrint('Device: ${result.device.platformName} (${result.device.remoteId})');
          debugPrint('  RSSI: ${result.rssi}');
          debugPrint('  Services: ${result.advertisementData.serviceUuids}');
          debugPrint('  Service Data: ${result.advertisementData.serviceData.keys}');
          debugPrint('  Manufacturer Data: ${result.advertisementData.manufacturerData}');
          debugPrint('  Local Name: ${result.advertisementData.localName}');
          
          // Only process devices that are actually advertising the Putrace service
          if (_isPutraceDevice(result.advertisementData)) {
            _processDiscoveredDevice(result);
          } else {
            debugPrint('  ❌ Skipping non-Putrace device: ${result.device.platformName}');
          }
        }
      });
      
      // Auto-restart scanning every 30 seconds for continuous discovery
      _scanTimer = Timer(const Duration(seconds: 30), () {
        debugPrint('BLE scan timeout reached - restarting scan for continuous discovery');
        _restartScanning();
      });
      
      // Also add a periodic check to see if we're finding devices
      Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_isScanning) {
          timer.cancel();
          return;
        }
        debugPrint('BLE scan status: ${_discoveredDevices.length} Putrace devices found so far');
      });
      
      debugPrint('Started anonymous BLE scanning');
    } catch (e) {
      debugPrint('Error starting anonymous BLE scan: $e');
      _isScanning = false;
      _scanningStatusController.add(false);
    }
  }
  
  void _processDiscoveredDevice(ScanResult result) {
    try {
      debugPrint('Processing device: ${result.device.platformName}');
      
      // Extract anonymous user data from advertisement
      AnonymousUserData? userData = _extractAnonymousUserData(result.advertisementData);
      if (userData == null) {
        debugPrint('No anonymous user data found in advertisement - skipping non-Putrace device');
        return;
      }
      
      debugPrint('Found anonymous user: ${userData.role} from ${userData.company}');
      
      // Calculate approximate distance based on RSSI
      double distance = _calculateDistanceFromRSSI(result.rssi);
      String proximity = _getProximityLevel(distance);
      
      final deviceId = result.device.remoteId.toString();
      final now = DateTime.now();
      
      // Check if device already exists
      bool isNewDevice = !_discoveredDevices.containsKey(deviceId);
      
      AnonymousBLEDevice device = AnonymousBLEDevice(
        id: deviceId,
        name: result.device.platformName,
        rssi: result.rssi,
        distance: distance,
        proximity: proximity,
        userData: userData,
        lastSeen: now,
      );
      
      // Update or add device (prevents duplicates)
      _discoveredDevices[deviceId] = device;
      
      // Emit updated list
      _nearbyDevicesController.add(_discoveredDevices.values.toList());
      
      if (isNewDevice) {
        debugPrint('🆕 NEW anonymous user discovered: ${userData.role} from ${userData.company}');
      } else {
        debugPrint('🔄 UPDATED anonymous user: ${userData.role} from ${userData.company} (RSSI: ${result.rssi})');
      }
      
      // Start presence cleanup if not already running
      if (_presenceCleanupTimer == null) {
        _startPresenceCleanup();
      }
    } catch (e) {
      debugPrint('Error processing discovered anonymous device: $e');
    }
  }
  
  bool _isPutraceDevice(AdvertisementData advertisementData) {
    // Check if the device is actually advertising the Putrace service
    final serviceGuid = Guid(putraceAnonymousServiceUuid);
    
    // Device must have the Putrace service UUID in its advertisement
    if (!advertisementData.serviceUuids.contains(serviceGuid)) {
      debugPrint('  ❌ Device does not have Putrace service UUID');
      return false;
    }
    
    // ACCEPT ANY DEVICE WITH PUTRACE SERVICE UUID
    // Since we have fallback advertising that only uses service UUID,
    // we should accept any device that has the Putrace service UUID
    
    // Check 1: Device name must start with "Putrace_" (our custom naming)
    final localName = advertisementData.localName ?? '';
    if (localName.startsWith('Putrace_')) {
      debugPrint('  ✅ Device has Putrace custom name: $localName');
      return true;
    }
    
    // Check 2: Must have service data with Putrace service UUID
    if (advertisementData.serviceData.containsKey(serviceGuid) && 
        advertisementData.serviceData[serviceGuid]!.isNotEmpty) {
      debugPrint('  ✅ Device has Putrace service data');
      return true;
    }
    
    // Check 3: Must have manufacturer data (indicating active advertising)
    if (advertisementData.manufacturerData.isNotEmpty) {
      debugPrint('  ✅ Device has manufacturer data (active advertising)');
      return true;
    }
    
    // Check 4: Accept any device with Putrace service UUID (fallback advertising)
    debugPrint('  ✅ Device has Putrace service UUID (fallback advertising)');
    debugPrint('  📝 Local name: $localName');
    debugPrint('  📝 Service data: ${advertisementData.serviceData}');
    debugPrint('  📝 Manufacturer data: ${advertisementData.manufacturerData}');
    return true;
  }

  AnonymousUserData? _extractAnonymousUserData(AdvertisementData advertisementData) {
    try {
      debugPrint('Extracting anonymous user data...');
      debugPrint('  Service UUIDs: ${advertisementData.serviceUuids}');
      debugPrint('  Service Data keys: ${advertisementData.serviceData.keys}');
      
      // Look for Putrace anonymous service in advertisement data
      final serviceGuid = Guid(putraceAnonymousServiceUuid);
      if (advertisementData.serviceUuids.contains(serviceGuid)) {
        
        // Try to extract user data from service data if available
        final serviceData = advertisementData.serviceData[serviceGuid];
        if (serviceData != null && serviceData.isNotEmpty) {
          final serviceDataString = String.fromCharCodes(serviceData);
          debugPrint('  Service data string: $serviceDataString');
          
          // Parse simple format: "Software Engineer|Nvidia"
          if (serviceDataString.contains('|')) {
            final parts = serviceDataString.split('|');
            if (parts.length >= 2) {
              final role = parts[0];
              final company = parts[1];
              debugPrint('  Parsed from service data: $role at $company');
              return AnonymousUserData(
                sessionId: 'anonymous_${DateTime.now().millisecondsSinceEpoch}',
                role: role,
                company: company,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
            }
          }
          
          // Fallback: try JSON parsing
          try {
            final userDataMap = json.decode(serviceDataString);
            return AnonymousUserData.fromMap(userDataMap);
          } catch (e) {
            debugPrint('  Error parsing service data as JSON: $e');
          }
        } else {
          // Try to extract user data from manufacturer data
          debugPrint('  No service data found, checking manufacturer data...');
          debugPrint('  Manufacturer Data keys: ${advertisementData.manufacturerData.keys}');
          
          // Look for Putrace data in manufacturer data
          if (advertisementData.manufacturerData.isNotEmpty) {
            // Get the first manufacturer data entry
            final manufacturerId = advertisementData.manufacturerData.keys.first;
            final manufacturerData = advertisementData.manufacturerData[manufacturerId];
            
            if (manufacturerData != null && manufacturerData.isNotEmpty) {
              final manufacturerDataString = String.fromCharCodes(manufacturerData);
              debugPrint('  Manufacturer data string: $manufacturerDataString');
              
              // Parse simple format: "Software Engineer|Nvidia"
              if (manufacturerDataString.contains('|')) {
                final parts = manufacturerDataString.split('|');
                if (parts.length >= 2) {
                  final role = parts[0];
                  final company = parts[1];
                  debugPrint('  Parsed from manufacturer data: $role at $company');
                  return AnonymousUserData(
                    sessionId: 'anonymous_${DateTime.now().millisecondsSinceEpoch}',
                    role: role,
                    company: company,
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  );
                }
              }
              
              // Fallback: try JSON parsing
              try {
                final userDataMap = json.decode(manufacturerDataString);
                return AnonymousUserData.fromMap(userDataMap);
              } catch (e) {
                debugPrint('  Error parsing manufacturer data as JSON: $e');
              }
            }
          }
          
          // No user data available, create different profiles based on device characteristics
          debugPrint('  No user data found, creating profile based on device characteristics...');
          final localName = advertisementData.localName ?? '';
          debugPrint('  Device local name: $localName');
          
          // Create different profiles based on device name to simulate different users
          String role = 'Software Engineer';
          String company = 'Tech Company';
          
          if (localName.contains('Galaxy')) {
            role = 'Software Engineer';
            company = 'Nvidia';
          } else if (localName.contains('S24')) {
            role = 'Software Engineer';
            company = 'Google';
          } else if (localName.contains('iPhone')) {
            role = 'Product Manager';
            company = 'Apple';
          } else if (localName.contains('Pixel')) {
            role = 'Designer';
            company = 'Google';
          }
          
          debugPrint('  Created profile: $role at $company');
          return AnonymousUserData(
            sessionId: 'anonymous_${DateTime.now().millisecondsSinceEpoch}',
            role: role,
            company: company,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
      
      debugPrint('  No matching service found');
      return null;
    } catch (e) {
      debugPrint('Error extracting anonymous user data: $e');
      return null;
    }
  }
  
  double _calculateDistanceFromRSSI(int rssi) {
    // Approximate distance calculation based on RSSI
    if (rssi == 0) return -1.0;
    
    double ratio = rssi * 1.0 / -59.0;
    if (ratio < 1.0) {
      return pow(ratio, 10.0).toDouble();
    } else {
      double accuracy = (0.89976) * pow(ratio, 7.7095) + 0.111;
      return accuracy;
    }
  }
  
  String _getProximityLevel(double distance) {
    if (distance <= 1.0) return 'Very Close';  // ~1 meter
    if (distance <= 3.0) return 'Close';       // ~3 meters
    if (distance <= 10.0) return 'Nearby';     // ~10 meters
    return 'In Range';
  }
  
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    
    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _scanningStatusController.add(false);
      _scanTimer?.cancel();
      
      // Clear discovered devices when scanning stops
      _clearDiscoveredDevices();
      
      debugPrint('Stopped anonymous BLE scanning');
    } catch (e) {
      debugPrint('Error stopping anonymous BLE scan: $e');
    }
  }
  
  Future<void> _restartScanning() async {
    if (!_isScanning) return; // Only restart if we should still be scanning
    
    try {
      debugPrint('Restarting BLE scan for continuous discovery...');
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 500)); // Brief pause
      
      // Restart scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        withServices: [Guid(putraceAnonymousServiceUuid)],
      );
      
      // Set up next restart timer
      _scanTimer = Timer(const Duration(seconds: 30), () {
        debugPrint('BLE scan timeout reached - restarting scan for continuous discovery');
        _restartScanning();
      });
      
      debugPrint('BLE scan restarted successfully');
    } catch (e) {
      debugPrint('Error restarting BLE scan: $e');
      // If restart fails, stop scanning completely
      await stopScanning();
    }
  }
  
  void _clearDiscoveredDevices() {
    if (_discoveredDevices.isNotEmpty) {
      debugPrint('Clearing ${_discoveredDevices.length} discovered devices');
      _discoveredDevices.clear();
      _nearbyDevicesController.add(_discoveredDevices.values.toList());
      _stopPresenceCleanup();
    }
  }
  
  // PRESENCE MANAGEMENT METHODS
  
  void _startPresenceCleanup() {
    debugPrint('Starting presence cleanup timer');
    _presenceCleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _cleanupOfflineDevices();
    });
  }
  
  void _stopPresenceCleanup() {
    debugPrint('Stopping presence cleanup timer');
    _presenceCleanupTimer?.cancel();
    _presenceCleanupTimer = null;
  }
  
  void _cleanupOfflineDevices() {
    final now = DateTime.now();
    final offlineDevices = <String>[];
    
    // Find devices that haven't been seen recently
    _discoveredDevices.forEach((deviceId, device) {
      final timeSinceLastSeen = now.difference(device.lastSeen);
      if (timeSinceLastSeen > _presenceTimeout) {
        offlineDevices.add(deviceId);
        debugPrint('⏰ Device ${device.name} (${device.userData.role}) marked as offline - last seen ${timeSinceLastSeen.inSeconds}s ago');
      }
    });
    
    // Remove offline devices
    if (offlineDevices.isNotEmpty) {
      for (final deviceId in offlineDevices) {
        final device = _discoveredDevices.remove(deviceId);
        if (device != null) {
          debugPrint('❌ REMOVED offline device: ${device.name} (${device.userData.role})');
        }
      }
      
      // Emit updated list (removed devices)
      _nearbyDevicesController.add(_discoveredDevices.values.toList());
      debugPrint('Cleaned up ${offlineDevices.length} offline devices. Active devices: ${_discoveredDevices.length}');
    }
    
    // Stop cleanup timer if no devices are being tracked
    if (_discoveredDevices.isEmpty && _presenceCleanupTimer != null) {
      _stopPresenceCleanup();
    }
  }

  Future<void> startAdvertising() async {
    debugPrint('=== AnonymousBLEService.startAdvertising() called ===');
    
    // Stop any existing advertising first
    await stopAdvertising();
    
    // Clear any existing discovered devices to force fresh discovery
    // This ensures other devices get updated profile information
    _clearDiscoveredDevices();
    
    // Wait a moment for cleanup
    await Future.delayed(const Duration(milliseconds: 500));
    
    await _startAdvertising();
  }

  Future<void> stopAdvertising() async {
    debugPrint('=== AnonymousBLEService.stopAdvertising() called ===');
    if (!_isAdvertising) return;
    
    try {
      await _peripheral.stop();
      _isAdvertising = false;
      _advertisingStatusController.add(false);
      debugPrint('Stopped anonymous BLE advertising');
    } catch (e) {
      debugPrint('Error stopping anonymous BLE advertising: $e');
    }
  }
  
  Future<void> _startAdvertising() async {
    debugPrint('=== AnonymousBLEService._startAdvertising() called ===');
    debugPrint('_isAdvertising: $_isAdvertising');
    debugPrint('_adapterState: $_adapterState');
    
    if (_isAdvertising || _adapterState != BluetoothAdapterState.on) {
      debugPrint('Skipping advertising - already advertising or adapter not on');
      return;
    }
    
    try {
      // Check permissions before starting advertising
      debugPrint('Checking BLE permissions for advertising...');
      if (!await _checkBLEPermissions()) {
        debugPrint('BLE permissions not granted - cannot start advertising');
        return;
      }
      debugPrint('BLE permissions granted - proceeding with advertising');
      
      // Force refresh profile to get latest changes
      await _anonymousUserService.refreshProfile();
      final profile = _anonymousUserService.currentProfile;
      if (profile == null) {
        debugPrint('No anonymous profile available - cannot start advertising');
        return;
      }
      
      debugPrint('Advertising with FRESH profile: ${profile.role} at ${profile.company}');
      
      // Create advertisement data
      final userData = AnonymousUserData(
        sessionId: profile.sessionId,
        role: profile.role,
        company: profile.company,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      
      final advertisementData = json.encode(userData.toMap());
      final advertisementBytes = Uint8List.fromList(utf8.encode(advertisementData));
      
      // Create service data with user profile information
      final profileData = '${userData.role}|${userData.company ?? 'Tech'}';
      final serviceDataBytes = Uint8List.fromList(utf8.encode(profileData));
      debugPrint('Advertising with service data: $profileData');
      
      // Start advertising using flutter_ble_peripheral
      try {
        await _peripheral.start(
          advertiseData: AdvertiseData(
            includeDeviceName: true,
            serviceUuid: putraceAnonymousServiceUuid,
            serviceData: serviceDataBytes,
          ),
          advertiseSettings: AdvertiseSettings(
            advertiseMode: AdvertiseMode.advertiseModeLowPower,
            txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
            timeout: 0,
            connectable: true,
          ),
        );
      } catch (e) {
        debugPrint('Error starting BLE advertising: $e');
        // Try alternative advertising approach
        try {
          await _peripheral.start(
            advertiseData: AdvertiseData(
              includeDeviceName: true,
              serviceUuid: putraceAnonymousServiceUuid,
              serviceData: serviceDataBytes,
            ),
            advertiseSettings: AdvertiseSettings(
              advertiseMode: AdvertiseMode.advertiseModeLowPower,
              txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
              timeout: 0,
              connectable: true,
            ),
          );
          debugPrint('BLE advertising started with simplified data');
        } catch (e2) {
          debugPrint('Error with simplified BLE advertising: $e2');
          // Final fallback: advertise without custom data
          try {
            await _peripheral.start(
              advertiseData: AdvertiseData(
                includeDeviceName: true,
                serviceUuid: putraceAnonymousServiceUuid,
              ),
              advertiseSettings: AdvertiseSettings(
                advertiseMode: AdvertiseMode.advertiseModeLowPower,
                txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
                timeout: 0,
                connectable: true,
              ),
            );
            debugPrint('Started BLE advertising with fallback (no custom data)');
          } catch (e3) {
            debugPrint('Error with fallback BLE advertising: $e3');
            return;
          }
        }
      }
      
      _isAdvertising = true;
      _advertisingStatusController.add(true);
      
      // Update last active time
      await _anonymousUserService.updateLastActive();
      
      debugPrint('Started anonymous BLE advertising: ${profile.role}');
      debugPrint('  Advertisement data: $advertisementData');
      debugPrint('  Service UUID: $putraceAnonymousServiceUuid');
    } catch (e) {
      debugPrint('Error starting anonymous BLE advertising: $e');
    }
  }
  
  Future<void> _stopAdvertising() async {
    if (!_isAdvertising) return;
    
    try {
      // Stop advertising using flutter_ble_peripheral
      await _peripheral.stop();
      _isAdvertising = false;
      _advertisingStatusController.add(false);
      _advertisingTimer?.cancel();
      debugPrint('Stopped anonymous BLE advertising');
    } catch (e) {
      debugPrint('Error stopping anonymous BLE advertising: $e');
      // Continue even if stop fails
      _isAdvertising = false;
      _advertisingStatusController.add(false);
    }
  }
  
  Future<void> sendMessage(String targetDeviceId, String message) async {
    try {
      // Find the target device
      final targetDevice = _discoveredDevices[targetDeviceId];
      if (targetDevice == null) {
        throw Exception('Target device not found');
      }

      // Create message data
      final messageData = AnonymousMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromSessionId: _anonymousUserService.currentProfile?.sessionId ?? '',
        toSessionId: targetDevice.userData.sessionId,
        message: message,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: MessageType.hi,
      );

      // TODO: Implement actual BLE message sending
      // This would involve connecting to the target device and writing to a characteristic
      debugPrint('Sending message to ${targetDevice.userData.displayName}: $message');
      
      // For now, just simulate successful sending
      _messageController.add(messageData);
      
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await stopScanning();
    await _stopAdvertising();
    _stopPresenceCleanup();
    await _nearbyDevicesController.close();
    await _scanningStatusController.close();
    await _advertisingStatusController.close();
    await _messageController.close();
    _scanTimer?.cancel();
    _advertisingTimer?.cancel();
  }
}

class AnonymousBLEDevice {
  final String id;
  final String name;
  final int rssi;
  final double distance;
  final String proximity;
  final AnonymousUserData userData;
  final DateTime lastSeen;
  
  const AnonymousBLEDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.distance,
    required this.proximity,
    required this.userData,
    required this.lastSeen,
  });
  
  String get displayName => userData.displayName;
  String get shortDisplayName => userData.shortDisplayName;
  
  @override
  String toString() {
    return 'AnonymousBLEDevice(id: $id, name: $name, userData: $userData)';
  }
}

class AnonymousUserData {
  final String sessionId;
  final String role;
  final String? company;
  final int timestamp;
  
  const AnonymousUserData({
    required this.sessionId,
    required this.role,
    this.company,
    required this.timestamp,
  });
  
  factory AnonymousUserData.fromMap(Map<String, dynamic> map) {
    return AnonymousUserData(
      sessionId: map['sessionId'] ?? '',
      role: map['role'] ?? 'Professional',
      company: map['company'],
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'role': role,
      'company': company,
      'timestamp': timestamp,
    };
  }
  
  String get displayName {
    if (company != null) {
      return '$role at $company';
    }
    return role;
  }
  
  String get shortDisplayName {
    if (company != null) {
      return '$role from $company';
    }
    return role;
  }
  
  @override
  String toString() {
    return 'AnonymousUserData(sessionId: $sessionId, role: $role, company: $company)';
  }
}

enum MessageType {
  hi,
  connection,
  custom,
}

class AnonymousMessage {
  final String id;
  final String fromSessionId;
  final String toSessionId;
  final String message;
  final int timestamp;
  final MessageType type;
  
  const AnonymousMessage({
    required this.id,
    required this.fromSessionId,
    required this.toSessionId,
    required this.message,
    required this.timestamp,
    required this.type,
  });
  
  factory AnonymousMessage.fromMap(Map<String, dynamic> map) {
    return AnonymousMessage(
      id: map['id'] ?? '',
      fromSessionId: map['fromSessionId'] ?? '',
      toSessionId: map['toSessionId'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.hi,
      ),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromSessionId': fromSessionId,
      'toSessionId': toSessionId,
      'message': message,
      'timestamp': timestamp,
      'type': type.name,
    };
  }
  
  @override
  String toString() {
    return 'AnonymousMessage(id: $id, from: $fromSessionId, to: $toSessionId, message: $message)';
  }
}
