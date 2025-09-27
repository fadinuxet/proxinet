import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VenueDiscoveryService {
  static const String _googlePlacesApiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  
  // Cache for venue data
  final Map<String, List<Venue>> _venueCache = {};
  
  /// Search for venues near a specific location
  Future<List<Venue>> searchNearbyVenues({
    required LatLng position,
    double radius = 500, // meters
    List<String> types = const ['cafe', 'restaurant', 'coffee_shop', 'establishment'],
  }) async {
    final cacheKey = '${position.latitude}_${position.longitude}_$radius';
    
    // Check cache first
    if (_venueCache.containsKey(cacheKey)) {
      return _venueCache[cacheKey]!;
    }
    
    try {
      final url = Uri.parse(
        '$_baseUrl/nearbysearch/json?'
        'location=${position.latitude},${position.longitude}'
        '&radius=$radius'
        '&type=${types.join('|')}'
        '&key=$_googlePlacesApiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final venues = _parseVenuesFromResponse(data);
        
        // Cache the results
        _venueCache[cacheKey] = venues;
        
        return venues;
      } else {
        throw Exception('Failed to load venues: ${response.statusCode}');
      }
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error loading venues: $e');
      return [];
    }
  }
  
  /// Get detailed information about a specific venue
  Future<VenueDetails?> getVenueDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?'
        'place_id=$placeId'
        '&fields=name,rating,formatted_phone_number,opening_hours,photos,reviews,website'
        '&key=$_googlePlacesApiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseVenueDetailsFromResponse(data);
      }
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error getting venue details: $e');
    }
    return null;
  }
  
  /// Search for venues by text query
  Future<List<Venue>> searchVenuesByText({
    required String query,
    required LatLng position,
    double radius = 1000,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/textsearch/json?'
        'query=${Uri.encodeComponent(query)}'
        '&location=${position.latitude},${position.longitude}'
        '&radius=$radius'
        '&key=$_googlePlacesApiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseVenuesFromResponse(data);
      }
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error searching venues by text: $e');
    }
    return [];
  }
  
  List<Venue> _parseVenuesFromResponse(Map<String, dynamic> data) {
    final results = data['results'] as List<dynamic>? ?? [];
    
    return results.map((venue) {
      final location = venue['geometry']['location'];
      final photos = venue['photos'] as List<dynamic>? ?? [];
      
      return Venue(
        id: venue['place_id'],
        name: venue['name'],
        location: LatLng(
          location['lat'].toDouble(),
          location['lng'].toDouble(),
        ),
        rating: venue['rating']?.toDouble() ?? 0.0,
        priceLevel: venue['price_level'] ?? 0,
        types: List<String>.from(venue['types'] ?? []),
        photos: photos.map((photo) => photo['photo_reference'] as String).toList(),
        isOpen: venue['opening_hours']?['open_now'] ?? false,
        vicinity: venue['vicinity'] ?? '',
      );
    }).toList();
  }
  
  VenueDetails? _parseVenueDetailsFromResponse(Map<String, dynamic> data) {
    final result = data['result'];
    if (result == null) return null;
    
    final openingHours = result['opening_hours'];
    final reviews = result['reviews'] as List<dynamic>? ?? [];
    
    return VenueDetails(
      placeId: result['place_id'],
      name: result['name'],
      rating: result['rating']?.toDouble() ?? 0.0,
      phoneNumber: result['formatted_phone_number'],
      website: result['website'],
      openingHours: openingHours != null ? OpeningHours(
        isOpenNow: openingHours['open_now'] ?? false,
        weekdayText: List<String>.from(openingHours['weekday_text'] ?? []),
      ) : null,
      photos: (result['photos'] as List<dynamic>? ?? [])
          .map((photo) => photo['photo_reference'] as String)
          .toList(),
      reviews: reviews.map((review) => Review(
        authorName: review['author_name'],
        rating: review['rating']?.toInt() ?? 0,
        text: review['text'],
        time: DateTime.fromMillisecondsSinceEpoch(
          (review['time'] as int) * 1000,
        ),
      )).toList(),
    );
  }
  
  /// Clear cache to free memory
  void clearCache() {
    _venueCache.clear();
  }
}

/// Venue model for basic venue information
class Venue {
  final String id;
  final String name;
  final LatLng location;
  final double rating;
  final int priceLevel;
  final List<String> types;
  final List<String> photos;
  final bool isOpen;
  final String vicinity;
  
  Venue({
    required this.id,
    required this.name,
    required this.location,
    required this.rating,
    required this.priceLevel,
    required this.types,
    required this.photos,
    required this.isOpen,
    required this.vicinity,
  });
  
  /// Get the primary venue type
  String get primaryType {
    if (types.contains('cafe') || types.contains('coffee_shop')) {
      return 'Coffee Shop';
    } else if (types.contains('restaurant')) {
      return 'Restaurant';
    } else if (types.contains('establishment')) {
      return 'Business';
    } else if (types.contains('gym')) {
      return 'Gym';
    } else if (types.contains('library')) {
      return 'Library';
    } else {
      return 'Venue';
    }
  }
  
  /// Check if venue is suitable for networking
  bool get isNetworkingFriendly {
    return types.any((type) => [
      'cafe',
      'coffee_shop',
      'restaurant',
      'establishment',
      'library',
      'gym',
      'park',
    ].contains(type));
  }
}

/// Detailed venue information
class VenueDetails {
  final String placeId;
  final String name;
  final double rating;
  final String? phoneNumber;
  final String? website;
  final OpeningHours? openingHours;
  final List<String> photos;
  final List<Review> reviews;
  
  VenueDetails({
    required this.placeId,
    required this.name,
    required this.rating,
    this.phoneNumber,
    this.website,
    this.openingHours,
    required this.photos,
    required this.reviews,
  });
}

/// Opening hours information
class OpeningHours {
  final bool isOpenNow;
  final List<String> weekdayText;
  
  OpeningHours({
    required this.isOpenNow,
    required this.weekdayText,
  });
}

/// Review information
class Review {
  final String authorName;
  final int rating;
  final String text;
  final DateTime time;
  
  Review({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.time,
  });
}
