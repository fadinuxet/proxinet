import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dart_geohash/dart_geohash.dart';

class UserDiscoveryService {
  static final UserDiscoveryService _instance = UserDiscoveryService._internal();
  factory UserDiscoveryService() => _instance;
  UserDiscoveryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StreamController<List<NearbyUser>> _nearbyUsersController = StreamController<List<NearbyUser>>.broadcast();
  Stream<List<NearbyUser>> get nearbyUsersStream => _nearbyUsersController.stream;

  Position? _currentPosition;
  Timer? _positionUpdateTimer;
  Timer? _discoveryTimer;

  Future<bool> initialize() async {
    try {
      // Get current location
      await _updateCurrentPosition();
      
      // Start periodic position updates
      _positionUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _updateCurrentPosition();
      });

      // Start periodic user discovery
      _discoveryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _discoverNearbyUsers();
      });

      return true;
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error checking location permissions: $e');
      return false;
    }
  }

  Future<void> _updateCurrentPosition() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentPosition = position;

      // Update user's location in Firestore
      await _updateUserLocation(position);

    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error updating current position: $e');
    }
  }

  Future<void> _updateUserLocation(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping location update');
        return;
      }
      
      String userId = user.uid;
      String geohash = GeoHasher().encode(position.longitude, position.latitude, precision: 7);
      
      await _firestore.collection('presence_geo').doc(userId).set({
        'userId': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'geohash': geohash,
        'timestamp': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
        'isAvailable': true,
        'modes': ['nearby', 'location'], // Active modes
      }, SetOptions(merge: true));

    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error updating user location: $e');
    }
  }

  Future<void> _discoverNearbyUsers() async {
    if (_currentPosition == null) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping nearby users discovery');
        return;
      }

      // Get geohash for current position
      String currentGeohash = GeoHasher().encode(_currentPosition!.longitude, _currentPosition!.latitude, precision: 7);
      
      // Get nearby geohashes (including neighbors)
      Map<String, String> neighborsMap = GeoHasher().neighbors(currentGeohash);
      List<String> nearbyGeohashes = neighborsMap.values.toList();
      nearbyGeohashes.add(currentGeohash);

      // Query Firestore for nearby users
      QuerySnapshot snapshot = await _firestore
          .collection('presence_geo')
          .where('geohash', whereIn: nearbyGeohashes)
          .where('expireAt', isGreaterThan: Timestamp.now())
          .where('isAvailable', isEqualTo: true)
          .get();

      List<NearbyUser> nearbyUsers = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Skip current user
          final currentUser = _auth.currentUser;
          if (currentUser != null && data['userId'] == currentUser.uid) continue;

          double userLat = data['latitude']?.toDouble() ?? 0.0;
          double userLng = data['longitude']?.toDouble() ?? 0.0;
          
          // Calculate distance
          double distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            userLat,
            userLng,
          );

          // Only include users within 50 meters
          if (distance <= 50) {
            String proximity = _getProximityLevel(distance);
            
            NearbyUser user = NearbyUser(
              id: data['userId'] ?? doc.id,
              name: data['name'] ?? 'Professional User',
              title: data['title'] ?? 'Professional',
              company: data['company'] ?? 'Company',
              distance: distance,
              proximity: proximity,
              latitude: userLat,
              longitude: userLng,
              lastSeen: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              activeModes: List<String>.from(data['modes'] ?? []),
            );

            nearbyUsers.add(user);
          }
        } catch (e) {
          // Log error but don't throw - this is a background operation
          debugPrint('Error processing user data: $e');
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) => a.distance.compareTo(b.distance));

      // Limit to 10 nearby users
      if (nearbyUsers.length > 10) {
        nearbyUsers = nearbyUsers.take(10).toList();
      }

      _nearbyUsersController.add(nearbyUsers);

    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error discovering nearby users: $e');
    }
  }

  String _getProximityLevel(double distance) {
    if (distance <= 5) return 'Very Close';   // 0-5 meters
    if (distance <= 15) return 'Close';       // 5-15 meters
    if (distance <= 30) return 'Nearby';      // 15-30 meters
    return 'In Range';                        // 30-50 meters
  }

  Future<void> setUserAvailability(bool isAvailable, List<String> activeModes) async {
    if (_currentPosition == null) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated, skipping availability update');
        return;
      }
      
      String userId = user.uid;
      String geohash = GeoHasher().encode(_currentPosition!.longitude, _currentPosition!.latitude, precision: 7);
      
      await _firestore.collection('presence_geo').doc(userId).set({
        'userId': userId,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'geohash': geohash,
        'timestamp': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
        'isAvailable': isAvailable,
        'modes': activeModes,
      }, SetOptions(merge: true));

    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error updating availability status: $e');
    }
  }

  Future<void> stopDiscovery() async {
    _positionUpdateTimer?.cancel();
    _discoveryTimer?.cancel();
  }

  void dispose() {
    _nearbyUsersController.close();
    _positionUpdateTimer?.cancel();
    _discoveryTimer?.cancel();
  }
}

class NearbyUser {
  final String id;
  final String name;
  final String title;
  final String company;
  final double distance;
  final String proximity;
  final double latitude;
  final double longitude;
  final DateTime lastSeen;
  final List<String> activeModes;

  NearbyUser({
    required this.id,
    required this.name,
    required this.title,
    required this.company,
    required this.distance,
    required this.proximity,
    required this.latitude,
    required this.longitude,
    required this.lastSeen,
    required this.activeModes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'company': company,
      'distance': distance,
      'proximity': proximity,
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': lastSeen.toIso8601String(),
      'activeModes': activeModes,
    };
  }
}
