import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import '../models/venue_data.dart';

/// Service for persisting venue data to Firestore
class VenuePersistenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _collectionName = 'user_venues';
  
  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;
  
  /// Get user's venues collection reference
  CollectionReference get _userVenuesRef {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection(_collectionName).doc(_userId).collection('venues');
  }

  /// Save venue to user's collection
  Future<void> saveVenue(VenueData venue) async {
    try {
      await _userVenuesRef.doc(venue.id).set(venue.toMap());
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Update existing venue
  Future<void> updateVenue(VenueData venue) async {
    try {
      await _userVenuesRef.doc(venue.id).update(venue.toMap());
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Get all user's venues
  Future<List<VenueData>> getUserVenues() async {
    try {
      final snapshot = await _userVenuesRef.get();
      return snapshot.docs
          .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      
      return [];
    }
  }

  /// Get user's My Places (favorite venues)
  Future<List<VenueData>> getMyPlaces() async {
    try {
      final snapshot = await _userVenuesRef
          .where('isFavorite', isEqualTo: true)
          .orderBy('addedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      
      return [];
    }
  }

  /// Get currently available venues
  Future<List<VenueData>> getAvailableVenues() async {
    try {
      final snapshot = await _userVenuesRef
          .where('isAvailable', isEqualTo: true)
          .orderBy('lastUsedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      
      return [];
    }
  }

  /// Get future scheduled venues
  Future<List<VenueData>> getFutureVenues() async {
    try {
      final now = DateTime.now();
      final snapshot = await _userVenuesRef
          .where('isFutureLocation', isEqualTo: true)
          .where('scheduledFor', isGreaterThan: now)
          .orderBy('scheduledFor', descending: false)
          .get();
      return snapshot.docs
          .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      
      return [];
    }
  }

  /// Set venue as available
  Future<void> setVenueAvailable(String venueId, String customMessage) async {
    try {
      await _userVenuesRef.doc(venueId).update({
        'isAvailable': true,
        'customMessage': customMessage,
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Set venue as unavailable
  Future<void> setVenueUnavailable(String venueId) async {
    try {
      await _userVenuesRef.doc(venueId).update({
        'isAvailable': false,
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Add venue to My Places
  Future<void> addToMyPlaces(String venueId) async {
    try {
      await _userVenuesRef.doc(venueId).update({
        'isFavorite': true,
        'addedAt': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Remove venue from My Places
  Future<void> removeFromMyPlaces(String venueId) async {
    try {
      await _userVenuesRef.doc(venueId).update({
        'isFavorite': false,
      });
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Update venue custom message
  Future<void> updateVenueMessage(String venueId, String customMessage) async {
    try {
      await _userVenuesRef.doc(venueId).update({
        'customMessage': customMessage,
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Schedule future venue
  Future<void> scheduleFutureVenue(
    String venueId, 
    DateTime scheduledFor, 
    String futureMessage,
  ) async {
    try {
      await _userVenuesRef.doc(venueId).update({
        'isFutureLocation': true,
        'scheduledFor': scheduledFor.toIso8601String(),
        'futureMessage': futureMessage,
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
      // print('📅 Scheduled future venue: $venueId for ${scheduledFor.toIso8601String()}'); // Removed print statement
    } catch (e) {
      
      rethrow;
    }
  }

  /// Cancel future venue
  Future<void> cancelFutureVenue(String venueId) async {
    try {
      await _userVenuesRef.doc(venueId).update({
        'isFutureLocation': false,
        'scheduledFor': null,
        'futureMessage': null,
      });
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Delete venue completely
  Future<void> deleteVenue(String venueId) async {
    try {
      await _userVenuesRef.doc(venueId).delete();
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Get venue by ID
  Future<VenueData?> getVenueById(String venueId) async {
    try {
      final doc = await _userVenuesRef.doc(venueId).get();
      if (doc.exists) {
        return VenueData.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      
      return null;
    }
  }

  /// Stream of user's venues (real-time updates)
  Stream<List<VenueData>> getUserVenuesStream() {
    return _userVenuesRef
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Stream of My Places (real-time updates)
  Stream<List<VenueData>> getMyPlacesStream() {
    return _userVenuesRef
        .where('isFavorite', isEqualTo: true)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Stream of available venues (real-time updates)
  Stream<List<VenueData>> getAvailableVenuesStream() {
    return _userVenuesRef
        .where('isAvailable', isEqualTo: true)
        .orderBy('lastUsedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Stream of future venues (real-time updates)
  Stream<List<VenueData>> getFutureVenuesStream() {
    final now = DateTime.now();
    return _userVenuesRef
        .where('isFutureLocation', isEqualTo: true)
        .where('scheduledFor', isGreaterThan: now)
        .orderBy('scheduledFor', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VenueData.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }
}

/// Register service with GetIt
void registerVenuePersistenceService() {
  GetIt.instance.registerLazySingleton<VenuePersistenceService>(
    () => VenuePersistenceService(),
  );
}
