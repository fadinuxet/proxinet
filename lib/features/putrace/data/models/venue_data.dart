import 'package:latlong2/latlong.dart';
import '../services/osm_venue_service.dart';

/// Model for storing venue data with user customizations
class VenueData {
  final String id;
  final String name;
  final String type;
  final String? address;
  final String? phone;
  final String? website;
  final LatLng location;
  final double networkingScore;
  final bool isNetworkingFriendly;
  final String? amenity;
  final String? cuisine;
  final int? capacity;
  final bool? wifi;
  final bool? outdoorSeating;
  final bool? wheelchairAccessible;
  final String? openingHours;
  
  // User customizations
  final String customMessage;
  final DateTime addedAt;
  final DateTime? lastUsedAt;
  final bool isFavorite;
  final bool isAvailable; // Currently set as available
  
  // Future location data
  final DateTime? scheduledFor;
  final String? futureMessage;
  final bool isFutureLocation;

  VenueData({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.phone,
    this.website,
    required this.location,
    required this.networkingScore,
    required this.isNetworkingFriendly,
    this.amenity,
    this.cuisine,
    this.capacity,
    this.wifi,
    this.outdoorSeating,
    this.wheelchairAccessible,
    this.openingHours,
    this.customMessage = '',
    required this.addedAt,
    this.lastUsedAt,
    this.isFavorite = false,
    this.isAvailable = false,
    this.scheduledFor,
    this.futureMessage,
    this.isFutureLocation = false,
  });

  /// Create VenueData from OSMVenue
  factory VenueData.fromOSMVenue(OSMVenue venue, {
    String customMessage = '',
    bool isAvailable = false,
    bool isFavorite = false,
    DateTime? scheduledFor,
    String? futureMessage,
    bool isFutureLocation = false,
  }) {
    return VenueData(
      id: venue.id,
      name: venue.name,
      type: venue.type,
      address: venue.address,
      phone: venue.phone,
      website: venue.website,
      location: venue.location,
      networkingScore: venue.networkingScore,
      isNetworkingFriendly: venue.isNetworkingFriendly,
      amenity: venue.amenity,
      cuisine: venue.cuisine,
      capacity: venue.capacity != null ? int.tryParse(venue.capacity!) : null,
      wifi: venue.wifi,
      outdoorSeating: venue.outdoorSeating,
      wheelchairAccessible: venue.wheelchair,
      openingHours: venue.openingHours,
      customMessage: customMessage,
      addedAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
      isFavorite: isFavorite,
      isAvailable: isAvailable,
      scheduledFor: scheduledFor,
      futureMessage: futureMessage,
      isFutureLocation: isFutureLocation,
    );
  }

  /// Convert to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'address': address,
      'phone': phone,
      'website': website,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'networkingScore': networkingScore,
      'isNetworkingFriendly': isNetworkingFriendly,
      'amenity': amenity,
      'cuisine': cuisine,
      'capacity': capacity,
      'wifi': wifi,
      'outdoorSeating': outdoorSeating,
      'wheelchairAccessible': wheelchairAccessible,
      'openingHours': openingHours,
      'customMessage': customMessage,
      'addedAt': addedAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'isAvailable': isAvailable,
      'scheduledFor': scheduledFor?.toIso8601String(),
      'futureMessage': futureMessage,
      'isFutureLocation': isFutureLocation,
    };
  }

  /// Create from Map (Firestore data)
  factory VenueData.fromMap(Map<String, dynamic> map) {
    return VenueData(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      address: map['address'],
      phone: map['phone'],
      website: map['website'],
      location: LatLng(
        map['location']['latitude'] ?? 0.0,
        map['location']['longitude'] ?? 0.0,
      ),
      networkingScore: (map['networkingScore'] ?? 0.0).toDouble(),
      isNetworkingFriendly: map['isNetworkingFriendly'] ?? false,
      amenity: map['amenity'],
      cuisine: map['cuisine'],
      capacity: map['capacity'],
      wifi: map['wifi'],
      outdoorSeating: map['outdoorSeating'],
      wheelchairAccessible: map['wheelchairAccessible'],
      openingHours: map['openingHours'],
      customMessage: map['customMessage'] ?? '',
      addedAt: DateTime.parse(map['addedAt'] ?? DateTime.now().toIso8601String()),
      lastUsedAt: map['lastUsedAt'] != null 
          ? DateTime.parse(map['lastUsedAt']) 
          : null,
      isFavorite: map['isFavorite'] ?? false,
      isAvailable: map['isAvailable'] ?? false,
      scheduledFor: map['scheduledFor'] != null 
          ? DateTime.parse(map['scheduledFor']) 
          : null,
      futureMessage: map['futureMessage'],
      isFutureLocation: map['isFutureLocation'] ?? false,
    );
  }

  /// Create a copy with updated fields
  VenueData copyWith({
    String? customMessage,
    DateTime? lastUsedAt,
    bool? isFavorite,
    bool? isAvailable,
    DateTime? scheduledFor,
    String? futureMessage,
    bool? isFutureLocation,
  }) {
    return VenueData(
      id: id,
      name: name,
      type: type,
      address: address,
      phone: phone,
      website: website,
      location: location,
      networkingScore: networkingScore,
      isNetworkingFriendly: isNetworkingFriendly,
      amenity: amenity,
      cuisine: cuisine,
      capacity: capacity,
      wifi: wifi,
      outdoorSeating: outdoorSeating,
      wheelchairAccessible: wheelchairAccessible,
      openingHours: openingHours,
      customMessage: customMessage ?? this.customMessage,
      addedAt: addedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isAvailable: isAvailable ?? this.isAvailable,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      futureMessage: futureMessage ?? this.futureMessage,
      isFutureLocation: isFutureLocation ?? this.isFutureLocation,
    );
  }
}

