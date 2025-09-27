import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import 'osm_venue_service.dart';

/// Service for discovering venues based on map bounds (discover-based interface)
class BoundsVenueService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';
  
  /// Get venues within visible map bounds
  Future<List<OSMVenue>> getVenuesInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
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
      'bar',
      'pub',
      'hotel',
    ],
  }) async {
    try {
      final overpassQuery = _buildBoundsQuery(
        north: north,
        south: south,
        east: east,
        west: west,
        amenityTypes: amenityTypes,
      );
      
      
      
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
        
        return [];
      }
    } catch (e) {
      
      return [];
    }
  }
  
  /// Build Overpass query for bounds-based search
  String _buildBoundsQuery({
    required double north,
    required double south,
    required double east,
    required double west,
    required List<String> amenityTypes,
  }) {
    final amenityFilter = amenityTypes.join('|');
    
    return '''
[out:json][timeout:25];
(
  node["amenity"~"^($amenityFilter)\$"]($south,$west,$north,$east);
  way["amenity"~"^($amenityFilter)\$"]($south,$west,$north,$east);
);
out center;
''';
  }
  
  /// Parse OSM response into venue objects
  List<OSMVenue> _parseOSMResponse(Map<String, dynamic> data) {
    final elements = data['elements'] as List<dynamic>? ?? [];
    
    return elements.map((element) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final lat = element['lat']?.toDouble() ?? element['center']?['lat']?.toDouble() ?? 0.0;
      final lng = element['lon']?.toDouble() ?? element['center']?['lon']?.toDouble() ?? 0.0;
      
      if (lat == 0.0 || lng == 0.0) return null;
      
      return OSMVenue(
        id: element['id']?.toString() ?? '',
        name: tags['name'] ?? 'Unnamed Venue',
        location: latlong.LatLng(lat, lng),
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
    }).where((venue) => venue != null).cast<OSMVenue>().toList();
  }
  
  /// Get human-readable venue type
  String _getVenueType(String? amenity) {
    switch (amenity) {
      case 'cafe':
      case 'coffee_shop':
        return 'Coffee Shop';
      case 'restaurant':
        return 'Restaurant';
      case 'bar':
      case 'pub':
        return 'Bar & Pub';
      case 'hotel':
        return 'Hotel';
      case 'library':
        return 'Library';
      case 'university':
      case 'college':
        return 'University';
      case 'office':
        return 'Office';
      case 'coworking_space':
        return 'CoWorking Space';
      case 'conference_centre':
        return 'Conference Center';
      case 'park':
        return 'Park';
      case 'hospital':
        return 'Hospital';
      case 'bank':
        return 'Bank';
      case 'pharmacy':
        return 'Pharmacy';
      case 'gym':
        return 'Gym';
      case 'school':
        return 'School';
      case 'community_centre':
        return 'Community Center';
      default:
        return 'Venue';
    }
  }
  
  /// Build address from OSM tags
  String? _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];
    
    if (tags['addr:housenumber'] != null) parts.add(tags['addr:housenumber']);
    if (tags['addr:street'] != null) parts.add(tags['addr:street']);
    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    if (tags['addr:state'] != null) parts.add(tags['addr:state']);
    if (tags['addr:postcode'] != null) parts.add(tags['addr:postcode']);
    
    return parts.isNotEmpty ? parts.join(' ') : null;
  }
}
