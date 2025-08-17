import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'proxinet_ble_constants.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class ProxinetBleService {
  final StreamController<String> _discovery = StreamController.broadcast();
  Stream<String> get discoveryStream => _discovery.stream;
  final _peripheral = FlutterBlePeripheral();
  String? _currentToken;
  Timer? _tokenTimer;

  Future<bool> _ensurePermissions() async {
    try {
      // Check Bluetooth permissions with better error handling
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      final locationWhenInUse = await Permission.locationWhenInUse.request();

      // Check if Bluetooth is supported
      if (!await FlutterBluePlus.isSupported) {
        _discovery.add('Bluetooth not supported on this device');
        return false;
      }

      // Check if Bluetooth is enabled
      if (!await FlutterBluePlus.isOn) {
        _discovery.add('Please turn on Bluetooth');
        return false;
      }

      // Check if all permissions are granted
      final ok = bluetoothScan.isGranted &&
          bluetoothAdvertise.isGranted &&
          bluetoothConnect.isGranted &&
          locationWhenInUse.isGranted;

      if (!ok) {
        String missingPermissions = '';
        if (!bluetoothScan.isGranted) missingPermissions += 'Bluetooth Scan, ';
        if (!bluetoothAdvertise.isGranted) missingPermissions += 'Bluetooth Advertise, ';
        if (!bluetoothConnect.isGranted) missingPermissions += 'Bluetooth Connect, ';
        if (!locationWhenInUse.isGranted) missingPermissions += 'Location, ';
        
        missingPermissions = missingPermissions.replaceAll(RegExp(r', $'), '');
        
        _discovery.add(
            'BLE permissions not granted: $missingPermissions. Please grant all required permissions in settings.');
      }
      return ok;
    } catch (e) {
      _discovery.add('Permission check error: $e');
      return false;
    }
  }

  Future<void> startEventMode() async {
    try {
      if (kIsWeb) {
        _discovery.add('BLE not supported on Web');
        return;
      }

      if (!await _ensurePermissions()) {
        _discovery.add('Cannot start Event Mode: permissions not granted');
        return;
      }

      final serviceGuid = Guid(ProxinetBleConstants.serviceUuid);

      // Start advertising an ephemeral token for Proxinet peers
      try {
        _discovery.add('Starting BLE advertising with service UUID: ${serviceGuid.toString()}');
        await _startAdvertising(serviceGuid);
        _discovery.add('✅ Started advertising Proxinet service successfully');
      } catch (e) {
        _discovery.add('❌ Advertising failed: $e');
        _discovery.add('⚠️ Continuing with scanning only (passive mode)');
        // Continue with scanning even if advertising fails
      }

      // Start scanning
      try {
        _discovery.add('🔍 Starting BLE scan for service UUID: ${serviceGuid.toString()}');
        await FlutterBluePlus.startScan(
          withServices: [serviceGuid],
          timeout: const Duration(seconds: 0),
        );
        _discovery.add('✅ Scanning for Proxinet peers started successfully');

        FlutterBluePlus.scanResults.listen((results) {
          _discovery.add('📡 Scan results: ${results.length} devices found');
          for (final r in results) {
            try {
              final ad = r.advertisementData;
              _discovery.add('🔍 Device: ${r.device.name ?? 'Unknown'} (${r.device.id})');
              _discovery.add('   Services: ${ad.serviceUuids.map((g) => g.toString()).join(', ')}');
              _discovery.add('   Service Data: ${ad.serviceData.keys.map((g) => g.toString()).join(', ')}');
              
              final hasService = ad.serviceUuids
                      .map((g) => g.toString().toLowerCase())
                      .contains(serviceGuid.toString().toLowerCase()) ||
                  ad.serviceData.keys
                      .map((g) => g.toString().toLowerCase())
                      .contains(serviceGuid.toString().toLowerCase());
              
              if (!hasService) {
                _discovery.add('   ❌ Not a Proxinet device (no matching service)');
                continue;
              }

              final tokenBytes = ad.serviceData[serviceGuid];
              final token = tokenBytes == null
                  ? ''
                  : tokenBytes
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join();
              final rssi = r.rssi;
              final peerLabel = token.isNotEmpty
                  ? 'Proxinet peer (token $token…)'
                  : 'Proxinet peer';
              _discovery.add('✅ $peerLabel • RSSI $rssi');
              if (token.isNotEmpty) {
                _discovery.add('🎯 TOKEN:$token');
              }
            } catch (e) {
              _discovery.add('Error processing scan result: $e');
            }
          }
        });
      } catch (e) {
        _discovery.add('Scan start error: $e');
      }
    } catch (e) {
      _discovery.add('BLE scan error: $e');
    }
  }

  Future<void> stopEventMode() async {
    try {
      if (!kIsWeb) {
        await FlutterBluePlus.stopScan();
      }
      _discovery.add('Scanning stopped');
      await _stopAdvertising();
    } catch (e) {
      _discovery.add('BLE stop error: $e');
    }
  }

  void dispose() {
    _discovery.close();
    _tokenTimer?.cancel();
  }

  Future<void> _startAdvertising(Guid serviceGuid) async {
    try {
      final token = _rotateToken();
      await _upsertTokenMapping(token);

      // Try multiple advertising configurations to handle plugin compatibility issues
      List<Exception> errors = [];

      // Configuration 1: Minimal settings
      try {
        final advertiseData = AdvertiseData(
          includeDeviceName: false,
          serviceUuid: serviceGuid.toString(),
          serviceData: Uint8List.fromList(utf8.encode(token)),
        );

        final advertiseSettings = AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeLowPower,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
          timeout: 0,
          connectable: false,
        );

        await _peripheral.start(
          advertiseData: advertiseData,
          advertiseSettings: advertiseSettings,
        );

        _discovery.add('Advertising Proxinet token (config 1)…');
        _setupTokenRotation(serviceGuid, advertiseSettings);
        return; // Success, exit early
      } catch (e) {
        errors.add(Exception('Config 1 failed: $e'));
        print('Advertising config 1 failed: $e');
      }

      // Configuration 2: Even more minimal
      try {
        final advertiseData = AdvertiseData(
          includeDeviceName: false,
          serviceUuid: serviceGuid.toString(),
        );

        final advertiseSettings = AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeLowPower,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
          timeout: 0,
          connectable: false,
        );

        await _peripheral.start(
          advertiseData: advertiseData,
          advertiseSettings: advertiseSettings,
        );

        _discovery.add('Advertising Proxinet token (config 2)…');
        _setupTokenRotation(serviceGuid, advertiseSettings);
        return; // Success, exit early
      } catch (e) {
        errors.add(Exception('Config 2 failed: $e'));
        print('Advertising config 2 failed: $e');
      }

      // Configuration 3: Most basic possible
      try {
        final advertiseData = AdvertiseData(
          includeDeviceName: false,
        );

        final advertiseSettings = AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeLowPower,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
          timeout: 0,
          connectable: false,
        );

        await _peripheral.start(
          advertiseData: advertiseData,
          advertiseSettings: advertiseSettings,
        );

        _discovery.add('Advertising Proxinet token (config 3)…');
        _setupTokenRotation(serviceGuid, advertiseSettings);
        return; // Success, exit early
      } catch (e) {
        errors.add(Exception('Config 3 failed: $e'));
        print('Advertising config 3 failed: $e');
      }

      // If all configurations failed, throw a comprehensive error
      final errorMessage =
          'All advertising configurations failed:\n${errors.map((e) => e.toString()).join('\n')}';
      _discovery.add(errorMessage);
      throw Exception(errorMessage);
    } catch (e) {
      _discovery.add('Advertising start error: $e');
      rethrow;
    }
  }

  void _setupTokenRotation(
      Guid serviceGuid, AdvertiseSettings advertiseSettings) {
    _tokenTimer?.cancel();
    _tokenTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      try {
        final newToken = _rotateToken();
        await _upsertTokenMapping(newToken);

        // Use the same configuration that worked
        final newData = AdvertiseData(
          includeDeviceName: false,
          serviceUuid: serviceGuid.toString(),
          serviceData: Uint8List.fromList(utf8.encode(newToken)),
        );

        await _peripheral.start(
          advertiseData: newData,
          advertiseSettings: advertiseSettings,
        );

        _discovery.add('Rotated Proxinet token');
      } catch (e) {
        _discovery.add('Token rotation error: $e');
      }
    });
  }

  Future<void> _stopAdvertising() async {
    _tokenTimer?.cancel();
    await _peripheral.stop();
  }

  String _rotateToken() {
    final uid = const Uuid().v4().replaceAll('-', '');
    _currentToken = uid.substring(0, 16); // 8 bytes hex
    return _currentToken!;
  }

  Future<void> _upsertTokenMapping(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final expireAt = DateTime.now().toUtc().add(const Duration(minutes: 15));
      await FirebaseFirestore.instance.collection('ble_tokens').doc(token).set({
        'userId': uid,
        'expireAt': Timestamp.fromDate(expireAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
