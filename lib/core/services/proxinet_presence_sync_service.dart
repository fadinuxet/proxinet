import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/geohash.dart';

class ProxinetPresenceSyncService extends ChangeNotifier {
  static final ProxinetPresenceSyncService _instance = ProxinetPresenceSyncService._internal();
  factory ProxinetPresenceSyncService() => _instance;
  ProxinetPresenceSyncService._internal();

  bool _isPresenceEnabled = false;
  double _radiusKm = 1.0;
  double? _latitude;
  double? _longitude;
  String? _currentGeohash;
  DateTime? _lastUpdated;

  // Getters
  bool get isPresenceEnabled => _isPresenceEnabled;
  double get radiusKm => _radiusKm;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get currentGeohash => _currentGeohash;
  DateTime? get lastUpdated => _lastUpdated;

  // Initialize from Firestore if user is authenticated
  Future<void> initializeFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('presence_geo')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final expireAt = data['expireAt'] as Timestamp?;
        
        if (expireAt != null && expireAt.toDate().isAfter(DateTime.now())) {
          _isPresenceEnabled = true;
          _radiusKm = (data['precisionM'] ?? 1000) / 1000.0;
          _latitude = data['lat'] as double?;
          _longitude = data['lng'] as double?;
          _currentGeohash = data['geohash'] as String?;
          _lastUpdated = data['updatedAt']?.toDate();
          notifyListeners();
        } else {
          // Presence expired, reset state
          _isPresenceEnabled = false;
          _latitude = null;
          _longitude = null;
          _currentGeohash = null;
          _lastUpdated = null;
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing presence sync service: $e');
      }
    }
  }

  // Enable presence
  Future<void> enablePresence({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _radiusKm = radiusKm;
      _latitude = latitude;
      _longitude = longitude;
      _isPresenceEnabled = true;
      _lastUpdated = DateTime.now();

      // Calculate geohash
      final precision = Geohash.precisionForRadiusKm(radiusKm);
      _currentGeohash = Geohash.encode(latitude, longitude, precision: precision);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('presence_geo')
          .doc(user.uid)
          .set({
        'geohash': _currentGeohash,
        'lat': latitude,
        'lng': longitude,
        'precisionM': (radiusKm * 1000).toInt(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(
          DateTime.now().toUtc().add(const Duration(minutes: 15)),
        ),
        'userId': user.uid,
      });

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling presence: $e');
      }
      rethrow;
    }
  }

  // Disable presence
  Future<void> disablePresence() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _isPresenceEnabled = false;
      _latitude = null;
      _longitude = null;
      _currentGeohash = null;
      _lastUpdated = null;

      // Remove from Firestore
      await FirebaseFirestore.instance
          .collection('presence_geo')
          .doc(user.uid)
          .delete();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling presence: $e');
      }
      rethrow;
    }
  }

  // Update radius
  Future<void> updateRadius(double radiusKm) async {
    if (_isPresenceEnabled && _latitude != null && _longitude != null) {
      await enablePresence(
        latitude: _latitude!,
        longitude: _longitude!,
        radiusKm: radiusKm,
      );
    } else {
      _radiusKm = radiusKm;
      notifyListeners();
    }
  }

  // Check if presence is expired
  bool get isPresenceExpired {
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!) > const Duration(minutes: 15);
  }

  // Refresh presence if needed
  Future<void> refreshPresenceIfNeeded() async {
    if (_isPresenceEnabled && isPresenceExpired) {
      await disablePresence();
    }
  }
}
