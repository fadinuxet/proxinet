import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BLEDiscoveryService {
  static final BLEDiscoveryService _instance = BLEDiscoveryService._internal();
  factory BLEDiscoveryService() => _instance;
  BLEDiscoveryService._internal();

  final StreamController<List<BLEDevice>> _nearbyDevicesController = StreamController<List<BLEDevice>>.broadcast();
  Stream<List<BLEDevice>> get nearbyDevicesStream => _nearbyDevicesController.stream;

  final StreamController<bool> _scanningStatusController = StreamController<bool>.broadcast();
  Stream<bool> get scanningStatusStream => _scanningStatusController.stream;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  Timer? _scanTimer;
  final Map<String, BLEDevice> _discoveredDevices = {};

  // BLE Service UUID for Putrace (must match PutraceBleConstants)
  static const String putraceServiceUuid = "12345678-1234-1234-1234-123456789abc";
  static const String putraceCharacteristicUuid = "87654321-4321-4321-4321-cba987654321";

  Future<bool> initialize() async {
    try {
      // Check BLE permissions
      if (!await _checkBLEPermissions()) {
        return false;
      }

      // Listen to adapter state changes
      FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        if (state == BluetoothAdapterState.on) {
          _startAdvertising();
        }
      });

      // Start advertising if BLE is already on
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
        await _startAdvertising();
      }

      return true;
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error checking BLE permissions: $e');
      return false;
    }
  }

  Future<bool> _checkBLEPermissions() async {
    // Check location permission (required for BLE scanning)
    var locationStatus = await Permission.locationWhenInUse.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.locationWhenInUse.request();
    }

    // Check Bluetooth permission
    var bluetoothStatus = await Permission.bluetoothScan.status;
    if (!bluetoothStatus.isGranted) {
      bluetoothStatus = await Permission.bluetoothScan.request();
    }

    return locationStatus.isGranted && bluetoothStatus.isGranted;
  }

  Future<void> startScanning() async {
    if (_isScanning || _adapterState != BluetoothAdapterState.on) return;

    try {
      _isScanning = true;
      _scanningStatusController.add(true);
      _discoveredDevices.clear();

      // Start BLE scan
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        withServices: [Guid(putraceServiceUuid)],
      );

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.platformName.isNotEmpty) {
            _processDiscoveredDevice(result);
          }
        }
      });

      // Auto-stop scanning after 30 seconds
      _scanTimer = Timer(const Duration(seconds: 30), () {
        stopScanning();
      });

    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error starting BLE scan: $e');
      _isScanning = false;
      _scanningStatusController.add(false);
    }
  }

  void _processDiscoveredDevice(ScanResult result) {
    try {
      // Extract Putrace data from advertisement
      String? userData = _extractPutraceData(result.advertisementData);
      if (userData == null) return;

      // Calculate approximate distance based on RSSI
      double distance = _calculateDistanceFromRSSI(result.rssi);
      String proximity = _getProximityLevel(distance);

      BLEDevice device = BLEDevice(
        id: result.device.remoteId.toString(),
        name: result.device.platformName,
        rssi: result.rssi,
        distance: distance,
        proximity: proximity,
        userData: userData,
        lastSeen: DateTime.now(),
      );

      _discoveredDevices[device.id] = device;
      _nearbyDevicesController.add(_discoveredDevices.values.toList());
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error processing discovered device: $e');
    }
  }

  String? _extractPutraceData(AdvertisementData advertisementData) {
    // Look for Putrace service in advertisement data
    if (advertisementData.serviceUuids.contains(Guid(putraceServiceUuid))) {
      // In a real implementation, you'd extract user data from service data
      // For now, return mock data
      return '{"name": "Professional User", "title": "Software Engineer", "company": "Tech Corp"}';
    }
    return null;
  }

  double _calculateDistanceFromRSSI(int rssi) {
    // Approximate distance calculation based on RSSI
    // This is a simplified formula - real implementation would be more complex
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
    if (distance < 0) return 'Unknown';
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
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error stopping BLE scan: $e');
    }
  }

  Future<void> _startAdvertising() async {
    try {
      // TODO: Implement BLE advertising when flutter_blue_plus API is stable
      
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error starting BLE advertising: $e');
    }
  }

  // List<int> _getUserAdvertisementData() {
  //   // In a real implementation, this would contain encrypted user data
  //   // For now, return mock data
  //   return 'Putrace User'.codeUnits;
  // }

  Future<void> stopAdvertising() async {
    try {
      // TODO: Implement BLE advertising stop when flutter_blue_plus API is stable
      
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error stopping BLE advertising: $e');
    }
  }

  void dispose() {
    _nearbyDevicesController.close();
    _scanningStatusController.close();
    _scanTimer?.cancel();
  }
}

class BLEDevice {
  final String id;
  final String name;
  final int rssi;
  final double distance;
  final String proximity;
  final String userData;
  final DateTime lastSeen;

  BLEDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.distance,
    required this.proximity,
    required this.userData,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rssi': rssi,
      'distance': distance,
      'proximity': proximity,
      'userData': userData,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }
}
