import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/geohash.dart';
import 'package:geolocator/geolocator.dart';
import 'serendipity_models.dart';

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

  // Set presence enabled/disabled
  Future<void> setPresenceEnabled(bool enabled) async {
    if (enabled == _isPresenceEnabled) return;
    
    if (enabled) {
      // Get current location and enable presence
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        await enablePresence(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusKm: _radiusKm,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error enabling presence: $e');
        }
        rethrow;
      }
    } else {
      await disablePresence();
    }
  }

  // Check if user is currently available
  bool get isCurrentlyAvailable => _isPresenceEnabled && !isPresenceExpired;

  // Check if user is available for connections
  bool _isAvailableForConnections = false;
  bool get isAvailableForConnections => _isAvailableForConnections;

  // Set availability for connections
  Future<void> setAvailabilityForConnections(bool available, {
    VisibilityAudience audience = VisibilityAudience.firstDegree,
    int hours = 2,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _isAvailableForConnections = available;

      if (available) {
        // Get current location
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error getting location for availability: $e');
          }
          // Continue without location if geolocation fails
        }

        // Set availability in Firestore with location data
        await FirebaseFirestore.instance
            .collection('availability')
            .doc(user.uid)
            .set({
          'isAvailable': true,
          'audience': audience.name,
          'until': Timestamp.fromDate(
            DateTime.now().toUtc().add(Duration(hours: hours)),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
          'userId': user.uid,
          // Add location data if available
          if (position != null) ...{
            'latitude': position.latitude,
            'longitude': position.longitude,
            'locationUpdatedAt': FieldValue.serverTimestamp(),
          },
        });

        // Also update the user's profile with current location
        if (position != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'lastLocationUpdate': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            if (kDebugMode) {
              print('Error updating user profile location: $e');
            }
          }
        }
      } else {
        // Remove availability
        await FirebaseFirestore.instance
            .collection('availability')
            .doc(user.uid)
            .delete();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error setting availability for connections: $e');
      }
      rethrow;
    }
  }

  // Initialize availability status from Firestore
  Future<void> initializeAvailabilityFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('availability')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final expireAt = data['until'] as Timestamp?;
        
        if (expireAt != null && expireAt.toDate().isAfter(DateTime.now())) {
          _isAvailableForConnections = true;
        } else {
          _isAvailableForConnections = false;
        }
      } else {
        _isAvailableForConnections = false;
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing availability: $e');
      }
    }
  }

  // Refresh location for already available users
  Future<void> refreshAvailabilityLocation() async {
    if (!_isAvailableForConnections) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Update availability document with new location
      await FirebaseFirestore.instance
          .collection('availability')
          .doc(user.uid)
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Also update user profile
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('Location refreshed for availability');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing availability location: $e');
      }
    }
  }

  // Debug methods for troubleshooting
  Future<Map<String, dynamic>?> getAvailabilityStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('availability')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting availability status: $e');
      }
      return null;
    }
  }

  VisibilityAudience? get currentAudience {
    // This would need to be implemented based on your current logic
    // For now, return null
    return null;
  }

  Future<VisibilityAudience?> getVisibilityAudience() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('availability')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final audienceStr = data['audience'] as String?;
        if (audienceStr != null) {
          return VisibilityAudience.values.firstWhere(
            (e) => e.name == audienceStr,
            orElse: () => VisibilityAudience.firstDegree,
          );
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting visibility audience: $e');
      }
      return null;
    }
  }

  Future<VisibilityAudience?> getCurrentAudience() async {
    return getVisibilityAudience();
  }

  Future<void> setAvailabilityLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update both availability and user profile
      await FirebaseFirestore.instance
          .collection('availability')
          .doc(user.uid)
          .update({
        'latitude': latitude,
        'longitude': longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'latitude': latitude,
        'longitude': longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error setting availability location: $e');
      }
      rethrow;
    }
  }

  // Contact Request Methods
  Future<bool> sendContactRequest(String targetUserId, {
    String? message,
    String? context, // e.g., "Met at conference", "Found on map"
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if request already exists
      final existingRequest = await FirebaseFirestore.instance
          .collection('contact_requests')
          .where('fromUserId', isEqualTo: user.uid)
          .where('toUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        if (kDebugMode) {
          print('Contact request already sent');
        }
        return false;
      }

      // Check if already connected
      final existingConnection = await FirebaseFirestore.instance
          .collection('graph_edges')
          .where('ownerId', isEqualTo: user.uid)
          .where('peerId', isEqualTo: targetUserId)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        if (kDebugMode) {
          print('Already connected to this user');
        }
        return false;
      }

      // Create contact request
      await FirebaseFirestore.instance
          .collection('contact_requests')
          .add({
        'fromUserId': user.uid,
        'toUserId': targetUserId,
        'status': 'pending', // pending, approved, rejected
        'message': message ?? 'Would like to connect with you',
        'context': context ?? 'Found on ProxiNet map',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('Contact request sent successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending contact request: $e');
      }
      return false;
    }
  }

  // Get pending contact requests for current user
  Future<List<Map<String, dynamic>>> getPendingContactRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final requestsQuery = await FirebaseFirestore.instance
          .collection('contact_requests')
          .where('toUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      final requests = <Map<String, dynamic>>[];
      
      for (final doc in requestsQuery.docs) {
        final data = doc.data();
        final fromUserId = data['fromUserId'] as String;
        
        // Get sender's profile
        try {
          final profileDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(fromUserId)
              .get();
          
          if (profileDoc.exists) {
            final profile = profileDoc.data()!;
            requests.add({
              'requestId': doc.id,
              'fromUserId': fromUserId,
              'fromUserName': profile['displayName'] ?? 'Unknown User',
              'fromUserEmail': profile['email'] ?? '',
              'message': data['message'] ?? '',
              'context': data['context'] ?? '',
              'createdAt': data['createdAt'],
              'status': data['status'],
            });
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading profile for user $fromUserId: $e');
          }
        }
      }

      return requests;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting pending contact requests: $e');
      }
      return [];
    }
  }

  // Approve contact request
  Future<bool> approveContactRequest(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final requestDoc = await FirebaseFirestore.instance
          .collection('contact_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;
      final fromUserId = requestData['fromUserId'] as String;
      final toUserId = requestData['toUserId'] as String;

      // Verify this request is for the current user
      if (toUserId != user.uid) return false;

      // Update request status
      await FirebaseFirestore.instance
          .collection('contact_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create bidirectional connection in graph_edges
      final batch = FirebaseFirestore.instance.batch();
      
      // Connection from requester to current user
      final connection1 = FirebaseFirestore.instance
          .collection('graph_edges')
          .doc();
      batch.set(connection1, {
        'ownerId': fromUserId,
        'peerId': user.uid,
        'degree': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'contact_request',
      });

      // Connection from current user to requester
      final connection2 = FirebaseFirestore.instance
          .collection('graph_edges')
          .doc();
      batch.set(connection2, {
        'ownerId': user.uid,
        'peerId': fromUserId,
        'degree': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'contact_request',
      });

      await batch.commit();

      if (kDebugMode) {
        print('Contact request approved and connection created');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error approving contact request: $e');
      }
      return false;
    }
  }

  // Reject contact request
  Future<bool> rejectContactRequest(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final requestDoc = await FirebaseFirestore.instance
          .collection('contact_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;
      final toUserId = requestData['toUserId'] as String;

      // Verify this request is for the current user
      if (toUserId != user.uid) return false;

      // Update request status
      await FirebaseFirestore.instance
          .collection('contact_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('Contact request rejected');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error rejecting contact request: $e');
      }
      return false;
    }
  }

  // Check if contact request already sent to a user
  Future<bool> hasContactRequestSent(String targetUserId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final requestQuery = await FirebaseFirestore.instance
          .collection('contact_requests')
          .where('fromUserId', isEqualTo: user.uid)
          .where('toUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      return requestQuery.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking contact request status: $e');
      }
      return false;
    }
  }

  // Check if already connected to a user
  Future<bool> isAlreadyConnected(String targetUserId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final connectionQuery = await FirebaseFirestore.instance
          .collection('graph_edges')
          .where('ownerId', isEqualTo: user.uid)
          .where('peerId', isEqualTo: targetUserId)
          .get();

      return connectionQuery.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connection status: $e');
      }
      return false;
    }
  }
}
