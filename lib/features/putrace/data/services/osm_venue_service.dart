import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import '../models/venue_data.dart';

class OSMVenueService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  
  // Cache for venue data
  final Map<String, List<OSMVenue>> _venueCache = {};
  
  /// Search for venues near a specific location using OpenStreetMap
  Future<List<OSMVenue>> searchNearbyVenues({
    required latlong.LatLng position,
    double radius = 500, // meters
    List<String> amenityTypes = const [
      'cafe',
      'restaurant', 
      'coffee_shop',
      'library',
      'gym',
      'park',
      'bank',
      'pharmacy',
      'hospital',
      'school',
      'university',
      'office',
      'coworking_space',
      'conference_centre',
      'community_centre',
    ],
  }) async {
    final cacheKey = '${position.latitude}_${position.longitude}_$radius';
    
    // Check cache first
    if (_venueCache.containsKey(cacheKey)) {
      return _venueCache[cacheKey]!;
    }
    
    try {
      // Build Overpass QL query
      final query = _buildOverpassQuery(position, radius, amenityTypes);
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final venues = _parseOSMResponse(data);
        
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
  
  /// Search for venues by name using OpenStreetMap
  Future<List<OSMVenue>> searchVenuesByName({
    required String query,
    required latlong.LatLng position,
    double radius = 1000,
  }) async {
    try {
      final overpassQuery = '''
[out:json][timeout:25];
(
  node["name"~"$query",i]["amenity"](around:$radius,${position.latitude},${position.longitude});
  way["name"~"$query",i]["amenity"](around:$radius,${position.latitude},${position.longitude});
  relation["name"~"$query",i]["amenity"](around:$radius,${position.latitude},${position.longitude});
);
out center;
''';
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': overpassQuery},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final venues = _parseOSMResponse(data);
        
        return venues;
      } else {
        // print('OSM API Error (by name): ${response.statusCode} - ${response.body}'); // Removed print statement
      }
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error searching venues by name: $e');
    }
    return [];
  }
  
  String _buildOverpassQuery(latlong.LatLng position, double radius, List<String> amenityTypes) {
    final amenityFilter = amenityTypes.join('|');
    
    // Simplified query that should work
    final query = '''
[out:json][timeout:25];
(
  node["amenity"~"^($amenityFilter)\$"](around:$radius,${position.latitude},${position.longitude});
  way["amenity"~"^($amenityFilter)\$"](around:$radius,${position.latitude},${position.longitude});
);
out center;
''';
    
    
    return query;
  }
  
  List<OSMVenue> _parseOSMResponse(Map<String, dynamic> data) {
    final elements = data['elements'] as List<dynamic>? ?? [];
    
    return elements.map((element) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final lat = element['lat']?.toDouble() ?? element['center']?['lat']?.toDouble() ?? 0.0;
      final lon = element['lon']?.toDouble() ?? element['center']?['lon']?.toDouble() ?? 0.0;
      
      return OSMVenue(
        id: element['id'].toString(),
        name: tags['name'] ?? 'Unnamed Venue',
        location: latlong.LatLng(lat, lon),
        amenity: tags['amenity'] ?? 'unknown',
        type: _getVenueType(tags['amenity']),
        address: _buildAddress(tags),
        phone: tags['phone'],
        website: tags['website'],
        openingHours: tags['opening_hours'],
        cuisine: tags['cuisine'],
        capacity: tags['capacity'],
        wifi: tags['wifi'] == 'yes',
        outdoorSeating: tags['outdoor_seating'] == 'yes',
        smoking: tags['smoking'] == 'yes',
        wheelchair: tags['wheelchair'] == 'yes',
        tags: tags,
      );
    }).toList();
  }
  
  String _getVenueType(String amenity) {
    switch (amenity) {
      case 'cafe':
      case 'coffee_shop':
        return 'Coffee Shop';
      case 'restaurant':
        return 'Restaurant';
      case 'library':
        return 'Library';
      case 'gym':
      case 'fitness_center':
        return 'Gym';
      case 'park':
        return 'Park';
      case 'bank':
        return 'Bank';
      case 'pharmacy':
        return 'Pharmacy';
      case 'hospital':
        return 'Hospital';
      case 'school':
      case 'university':
        return 'Educational';
      case 'office':
        return 'Office';
      case 'coworking_space':
        return 'Co-Working Space';
      case 'conference_centre':
        return 'Conference Center';
      case 'community_centre':
        return 'Community Center';
      default:
        return 'Venue';
    }
  }
  
  String _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];
    
    if (tags['addr:housenumber'] != null) parts.add(tags['addr:housenumber']);
    if (tags['addr:street'] != null) parts.add(tags['addr:street']);
    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    if (tags['addr:postcode'] != null) parts.add(tags['addr:postcode']);
    
    return parts.join(' ');
  }
  
  /// Clear cache to free memory
  void clearCache() {
    _venueCache.clear();
  }
}

/// OSM Venue model
class OSMVenue {
  final String id;
  final String name;
  final latlong.LatLng location;
  final String amenity;
  final String type;
  final String? address;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? cuisine;
  final String? capacity;
  final bool wifi;
  final bool outdoorSeating;
  final bool smoking;
  final bool wheelchair;
  final Map<String, dynamic> tags;
  
  OSMVenue({
    required this.id,
    required this.name,
    required this.location,
    required this.amenity,
    required this.type,
    this.address,
    this.phone,
    this.website,
    this.openingHours,
    this.cuisine,
    this.capacity,
    this.wifi = false,
    this.outdoorSeating = false,
    this.smoking = false,
    this.wheelchair = false,
    required this.tags,
  });
  
  /// Check if venue is suitable for networking
  bool get isNetworkingFriendly {
    return ['cafe', 'restaurant', 'library', 'gym', 'park', 'office', 'coworking_space', 'conference_centre'].contains(amenity);
  }
  
  /// Get networking score based on amenities
  double get networkingScore {
    double score = 3.0; // Base score
    
    if (wifi) score += 0.5;
    if (outdoorSeating) score += 0.3;
    if (wheelchair) score += 0.2;
    if (amenity == 'coworking_space') score += 1.0;
    if (amenity == 'conference_centre') score += 0.8;
    if (amenity == 'library') score += 0.6;
    if (amenity == 'cafe') score += 0.4;
    
    return score.clamp(1.0, 5.0);
  }
  
  /// Get busy level based on capacity and type
  String get busyLevel {
    if (amenity == 'coworking_space' || amenity == 'conference_centre') {
      return 'High';
    } else if (amenity == 'cafe' || amenity == 'restaurant') {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  /// Create OSMVenue from VenueData
  factory OSMVenue.fromVenueData(VenueData venueData) {
    return OSMVenue(
      id: venueData.id,
      name: venueData.name,
      location: venueData.location,
      amenity: venueData.amenity ?? '',
      type: venueData.type,
      address: venueData.address,
      phone: venueData.phone,
      website: venueData.website,
      openingHours: venueData.openingHours,
      wifi: venueData.wifi ?? false,
      outdoorSeating: venueData.outdoorSeating ?? false,
      smoking: false, // Default value
      wheelchair: venueData.wheelchairAccessible ?? false,
      tags: {}, // Empty tags for now
    );
  }
}
