import 'package:latlong2/latlong.dart' as latlong;

class OSMVenue {
  final String id;
  final String name;
  final latlong.LatLng location;
  final String? amenity;
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
  final Map<String, String> tags;

  OSMVenue({
    required this.id,
    required this.name,
    required this.location,
    this.amenity,
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
    this.tags = const {},
  });

  // Networking score (0-5) based on venue type and amenities
  double get networkingScore {
    double score = 2.0; // Base score
    
    // Venue type scoring
    switch (amenity?.toLowerCase()) {
      case 'cafe':
      case 'coffee_shop':
        score += 2.0;
        break;
      case 'restaurant':
        score += 1.5;
        break;
      case 'library':
        score += 2.5;
        break;
      case 'coworking_space':
        score += 3.0;
        break;
      case 'office':
        score += 1.0;
        break;
      case 'conference_centre':
        score += 2.0;
        break;
      case 'community_centre':
        score += 1.5;
        break;
      case 'bar':
      case 'pub':
        score += 1.0;
        break;
      default:
        score += 0.5;
    }
    
    // Amenity bonuses
    if (wifi) score += 0.5;
    if (outdoorSeating) score += 0.3;
    if (wheelchair) score += 0.2;
    
    return score.clamp(0.0, 5.0);
  }

  // Whether this venue is networking-friendly
  bool get isNetworkingFriendly {
    return networkingScore >= 3.0;
  }
}
