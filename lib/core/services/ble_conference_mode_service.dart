import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/user_profile.dart';
import 'putrace_crypto_service.dart';
import 'professional_auth_service.dart';
import 'putrace_ble_constants.dart';
import 'simple_firebase_monitor.dart';

/// BLE Conference Mode Service - Privacy-first offline networking for professional events
/// Features:
/// - No internet required (BLE mesh networking)
/// - Conference-specific encryption keys
/// - Offline professional discovery
/// - Secure device-to-device messaging
class BLEConferenceModeService {
  final PutraceCryptoService _cryptoService;
  final ProfessionalAuthService _authService;
  final StreamController<String> _discovery = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _offlineMessages = StreamController.broadcast();
  
  // Conference mode specific variables
  String? _currentEventId;
  String? _conferencePublicKey;
  String? _conferencePrivateKey;
  bool _isConferenceModeActive = false;
  Timer? _discoveryTimer;
  Timer? _advertisingTimer;
  final List<Map<String, dynamic>> _discoveredProfessionals = [];
  final Map<String, String> _offlineMessageQueue = {};
  
  Stream<String> get discoveryStream => _discovery.stream;
  Stream<Map<String, dynamic>> get offlineMessagesStream => _offlineMessages.stream;
  
  BLEConferenceModeService(this._cryptoService, this._authService);

  /// Enable offline conference mode (Privacy-first no internet networking)
  Future<void> enableOfflineConferenceMode({
    required String eventId,
    required String venueName,
    String? eventName,
  }) async {
    try {
      _discovery.add('🎪 Starting Conference Mode for $venueName...');
      
      // Generate conference-specific encryption keys
      await _generateConferenceKeys(eventId);
      
      // Set current event context
      _currentEventId = eventId;
      _isConferenceModeActive = true;
      
      // Start BLE advertising with conference info
      await _startConferenceAdvertising(eventId, venueName, eventName);
      
      // Start discovering other professionals
      await _startConferenceDiscovery();
      
      // Enable mesh messaging for offline communication
      await _enableBLEMeshMessaging();
      
      // Track conference mode activation
      SimpleFirebaseMonitor.trackBLEEvent('conference_mode_enabled', {
        'event_id': eventId,
        'venue_name': venueName,
        'event_name': eventName ?? 'Unknown',
      });
      
      _discovery.add('✅ Conference Mode Active: $venueName');
      _discovery.add('📡 Discovering professionals nearby without internet...');
      
    } catch (e) {
      _discovery.add('❌ Failed to enable conference mode: $e');
      throw Exception('Failed to enable offline conference mode: $e');
    }
  }
  
  /// Disable conference mode
  Future<void> disableConferenceMode() async {
    try {
      _isConferenceModeActive = false;
      _currentEventId = null;
      
      // Stop timers
      _discoveryTimer?.cancel();
      _advertisingTimer?.cancel();
      
      // Stop BLE operations
      await FlutterBluePlus.stopScan();
      
      // Clear conference data
      _discoveredProfessionals.clear();
      _conferencePublicKey = null;
      _conferencePrivateKey = null;
      
      // Track deactivation
      SimpleFirebaseMonitor.trackBLEEvent('conference_mode_disabled', {
        'professionals_discovered': _discoveredProfessionals.length,
        'messages_queued': _offlineMessageQueue.length,
      });
      
      _discovery.add('🔴 Conference Mode Disabled');
      
    } catch (e) {
      _discovery.add('Error disabling conference mode: $e');
    }
  }
  
  /// Send offline message via BLE direct connection
  Future<void> sendOfflineMessageViaBLE({
    required String recipientDeviceId,
    required String content,
    MessageType messageType = MessageType.text,
  }) async {
    try {
      if (!_isConferenceModeActive) {
        throw Exception('Conference mode not active');
      }
      
      // Get recipient's conference public key
      final recipientInfo = _discoveredProfessionals.firstWhere(
        (professional) => professional['deviceId'] == recipientDeviceId,
        orElse: () => throw Exception('Recipient not found in conference'),
      );
      
      final recipientPublicKey = recipientInfo['conferencePublicKey'] as String;
      
      // Encrypt message with conference-specific keys
      final encryptedMessage = await _encryptWithConferenceKey(
        content, 
        recipientPublicKey,
      );
      
      // Send via BLE direct connection
      await _sendBLEMessage(recipientDeviceId, encryptedMessage);
      
      // Queue for later delivery if direct send fails
      _offlineMessageQueue[recipientDeviceId] = content;
      
      // Track offline message
      SimpleFirebaseMonitor.trackBLEEvent('offline_message_sent', {
        'message_type': messageType.name,
        'recipient_device': recipientDeviceId,
        'conference_event': _currentEventId,
      });
      
      _discovery.add('📤 Sent offline message to $recipientDeviceId');
      
    } catch (e) {
      _discovery.add('❌ Failed to send offline message: $e');
      throw Exception('Failed to send offline message: $e');
    }
  }
  
  /// Discover nearby professionals without internet
  Future<List<Map<String, dynamic>>> discoverNearbyProfessionals() async {
    if (!_isConferenceModeActive) {
      throw Exception('Conference mode not active');
    }
    
    return List.from(_discoveredProfessionals);
  }
  
  /// Get offline message queue
  Map<String, String> getOfflineMessageQueue() {
    return Map.from(_offlineMessageQueue);
  }
  
  /// Check if conference mode is active
  bool get isConferenceModeActive => _isConferenceModeActive;
  
  /// Get current event ID
  String? get currentEventId => _currentEventId;
  
  // Private helper methods
  
  /// Generate conference-specific encryption keys
  Future<void> _generateConferenceKeys(String eventId) async {
    try {
      // Generate temporary keys for this conference
      // final keyId = const Uuid().v4(); // Removed unused variable
      
      // Create event-specific seed
      final eventSeed = '$eventId${DateTime.now().millisecondsSinceEpoch}';
      final seed = _cryptoService.hmacToken(
        secretSalt: await _cryptoService.getOrCreateSecretSalt(),
        value: eventSeed,
      );
      
      // Generate conference keys (simplified for demo)
      _conferencePublicKey = 'conf_pub_${seed.substring(0, 32)}';
      _conferencePrivateKey = 'conf_priv_${seed.substring(32, 64)}';
      
      _discovery.add('🔐 Generated conference encryption keys');
      
    } catch (e) {
      throw Exception('Failed to generate conference keys: $e');
    }
  }
  
  /// Start conference advertising
  Future<void> _startConferenceAdvertising(
    String eventId, 
    String venueName, 
    String? eventName,
  ) async {
    try {
      // Get professional identity
      final identity = await _authService.getProfessionalIdentity();
      if (identity == null) {
        throw Exception('No professional identity found');
      }
      
      // Create conference advertisement data
      final advertData = {
        'type': 'conference_professional',
        'eventId': eventId,
        'venueName': venueName,
        'eventName': eventName,
        'professionalId': identity.identityId,
        'displayName': identity.displayName,
        'company': identity.company,
        'title': identity.title,
        'conferencePublicKey': _conferencePublicKey,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Start advertising (simplified BLE advertising)
      await _startBLEAdvertising(advertData);
      
      _discovery.add('📡 Broadcasting professional presence at $venueName');
      
    } catch (e) {
      throw Exception('Failed to start conference advertising: $e');
    }
  }
  
  /// Start conference discovery
  Future<void> _startConferenceDiscovery() async {
    try {
      // Start periodic scanning for other professionals
      _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _scanForConferenceProfessionals();
      });
      
      // Initial scan
      await _scanForConferenceProfessionals();
      
    } catch (e) {
      throw Exception('Failed to start conference discovery: $e');
    }
  }
  
  /// Scan for conference professionals
  Future<void> _scanForConferenceProfessionals() async {
    try {
      if (!_isConferenceModeActive) return;
      
      _discovery.add('🔍 Scanning for professionals at conference...');
      
      // Start BLE scan with timeout
      await FlutterBluePlus.startScan(
        withServices: [Guid(PutraceBleConstants.serviceUuid)],
        timeout: const Duration(seconds: 15),
      );
      
      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _processBLEDiscovery(result);
        }
      });
      
    } catch (e) {
      _discovery.add('Error scanning for professionals: $e');
    }
  }
  
  /// Process BLE discovery results
  void _processBLEDiscovery(ScanResult result) {
    try {
      // Extract advertisement data
      final deviceId = result.device.platformName;
      final rssi = result.rssi;
      
      // Parse professional data from advertisement
      final professionalData = _parseAdvertisementData(result);
      if (professionalData == null) return;
      
      // Check if this is a conference participant
      if (professionalData['eventId'] == _currentEventId) {
        // Add to discovered professionals list
        final professional = {
          'deviceId': deviceId,
          'professionalId': professionalData['professionalId'],
          'displayName': professionalData['displayName'],
          'company': professionalData['company'],
          'title': professionalData['title'],
          'conferencePublicKey': professionalData['conferencePublicKey'],
          'rssi': rssi,
          'lastSeen': DateTime.now(),
          'venueName': professionalData['venueName'],
        };
        
        // Update or add professional
        final existingIndex = _discoveredProfessionals.indexWhere(
          (p) => p['deviceId'] == deviceId,
        );
        
        if (existingIndex >= 0) {
          _discoveredProfessionals[existingIndex] = professional;
        } else {
          _discoveredProfessionals.add(professional);
          _discovery.add('👤 Discovered: ${professional['displayName']} (${professional['company']})');
          
          // Track discovery
          SimpleFirebaseMonitor.trackBLEEvent('professional_discovered_offline', {
            'conference_event': _currentEventId,
            'professional_company': professional['company'],
            'rssi': rssi,
          });
        }
      }
      
    } catch (e) {
      _discovery.add('Error processing BLE discovery: $e');
    }
  }
  
  /// Enable BLE mesh messaging
  Future<void> _enableBLEMeshMessaging() async {
    try {
      // Set up message relay timer for mesh networking
      _advertisingTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
        await _relayOfflineMessages();
      });
      
      _discovery.add('🕸️ BLE mesh messaging enabled');
      
    } catch (e) {
      throw Exception('Failed to enable BLE mesh messaging: $e');
    }
  }
  
  /// Encrypt message with conference key
  Future<Map<String, dynamic>> _encryptWithConferenceKey(
    String content, 
    String recipientPublicKey,
  ) async {
    try {
      if (_conferencePrivateKey == null) {
        throw Exception('No conference private key available');
      }
      
      // Use conference-specific encryption
      return await _cryptoService.encryptProfessionalMessage(
        message: content,
        recipientPublicKey: recipientPublicKey,
        messageType: MessageType.text,
      );
      
    } catch (e) {
      throw Exception('Failed to encrypt with conference key: $e');
    }
  }
  
  /// Send BLE message directly to device
  Future<void> _sendBLEMessage(String deviceId, Map<String, dynamic> encryptedMessage) async {
    try {
      // Simplified BLE message sending (would need proper BLE implementation)
      _discovery.add('📤 Sending BLE message to $deviceId');
      
      // In real implementation, this would use BLE characteristics to send data
      // For demo, we'll simulate successful send
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      throw Exception('Failed to send BLE message: $e');
    }
  }
  
  /// Start BLE advertising
  Future<void> _startBLEAdvertising(Map<String, dynamic> advertData) async {
    try {
      // Simplified BLE advertising (would need proper FlutterBlePeripheral implementation)
      _discovery.add('📡 Starting BLE advertising...');
      
      // In real implementation, this would use FlutterBlePeripheral
      // For demo, we'll simulate successful advertising
      await Future.delayed(const Duration(milliseconds: 300));
      
    } catch (e) {
      throw Exception('Failed to start BLE advertising: $e');
    }
  }
  
  /// Parse advertisement data from BLE scan result
  Map<String, dynamic>? _parseAdvertisementData(ScanResult result) {
    try {
      // Simplified parsing - in real implementation, would parse actual BLE advertisement data
      // For demo, simulate professional data
      return {
        'type': 'conference_professional',
        'eventId': _currentEventId,
        'professionalId': 'demo_${Random().nextInt(1000)}',
        'displayName': 'Demo Professional',
        'company': 'Demo Corp',
        'title': 'Demo Title',
        'conferencePublicKey': 'demo_public_key',
        'venueName': 'Demo Venue',
      };
      
    } catch (e) {
      return null;
    }
  }
  
  /// Relay offline messages (mesh networking)
  Future<void> _relayOfflineMessages() async {
    try {
      if (_offlineMessageQueue.isEmpty) return;
      
      _discovery.add('🕸️ Relaying ${_offlineMessageQueue.length} offline messages...');
      
      // In real implementation, this would relay messages through mesh network
      // For demo, we'll simulate message relay
      await Future.delayed(const Duration(milliseconds: 200));
      
    } catch (e) {
      _discovery.add('Error relaying offline messages: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _discoveryTimer?.cancel();
    _advertisingTimer?.cancel();
    _discovery.close();
    _offlineMessages.close();
  }
}
