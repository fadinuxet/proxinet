import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../models/osm_venue.dart';

class MyPlacesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _collection = 'my_places';
  
  /// Save a venue to user's My Places
  Future<void> savePlace(OSMVenue venue) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        
        return;
      }
      
      final placeData = {
        'id': venue.id,
        'name': venue.name,
        'location': {
          'latitude': venue.location.latitude,
          'longitude': venue.location.longitude,
        },
        'amenity': venue.amenity,
        'type': venue.type,
        'address': venue.address,
        'phone': venue.phone,
        'website': venue.website,
        'openingHours': venue.openingHours,
        'cuisine': venue.cuisine,
        'capacity': venue.capacity,
        'wifi': venue.wifi,
        'outdoorSeating': venue.outdoorSeating,
        'smoking': venue.smoking,
        'wheelchair': venue.wheelchair,
        'tags': venue.tags,
        'savedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };
      
      await _firestore
          .collection(_collection)
          .doc('${user.uid}_${venue.id}')
          .set(placeData, SetOptions(merge: true));
      
      
    } catch (e) {
      
      rethrow;
    }
  }
  
  /// Load all user's My Places
  Future<List<OSMVenue>> loadPlaces() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        
        return [];
      }
      
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: user.uid)
          .orderBy('savedAt', descending: true)
          .get();
      
      final places = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return OSMVenue(
          id: data['id'] ?? '',
          name: data['name'] ?? 'Unknown',
          location: latlong.LatLng(
            data['location']['latitude'] ?? 0.0,
            data['location']['longitude'] ?? 0.0,
          ),
          amenity: data['amenity'],
          type: data['type'] ?? 'Unknown',
          address: data['address'],
          phone: data['phone'],
          website: data['website'],
          openingHours: data['openingHours'],
          cuisine: data['cuisine'],
          capacity: data['capacity'],
          wifi: data['wifi'] ?? false,
          outdoorSeating: data['outdoorSeating'] ?? false,
          smoking: data['smoking'] ?? false,
          wheelchair: data['wheelchair'] ?? false,
          tags: Map<String, String>.from(data['tags'] ?? {}),
        );
      }).toList();
      
      
      return places;
    } catch (e) {
      
      return [];
    }
  }
  
  /// Remove a place from My Places
  Future<void> removePlace(String venueId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        
        return;
      }
      
      await _firestore
          .collection(_collection)
          .doc('${user.uid}_$venueId')
          .delete();
      
      
    } catch (e) {
      
      rethrow;
    }
  }
  
  /// Check if a place is already saved
  Future<bool> isPlaceSaved(String venueId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final doc = await _firestore
          .collection(_collection)
          .doc('${user.uid}_$venueId')
          .get();
      
      return doc.exists;
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get places count
  Future<int> getPlacesCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;
      
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: user.uid)
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      
      return 0;
    }
  }
}
