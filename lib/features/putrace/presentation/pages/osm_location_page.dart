import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../widgets/venue_pinning_sheet.dart';
import '../../data/services/osm_venue_service.dart';

class OSMLocationPage extends StatefulWidget {
  const OSMLocationPage({super.key});

  @override
  State<OSMLocationPage> createState() => _OSMLocationPageState();
}

class _OSMLocationPageState extends State<OSMLocationPage> {
  final MapController _mapController = MapController();
  latlong.LatLng? _currentLocation;
  String _selectedVenue = '';
  String _customMessage = '';
  bool _isMapView = true;
  
  // Venue discovery
  final OSMVenueService _venueService = OSMVenueService();
  List<OSMVenue> _discoveredVenues = [];
  bool _isSearchingVenues = false;
  
  // Mock venue data
  final List<Map<String, dynamic>> _venues = [
    {
      'name': 'Starbucks Downtown',
      'location': const latlong.LatLng(37.7749, -122.4194),
      'type': 'Coffee Shop',
      'networkingScore': 4.5,
      'busyLevel': 'Medium',
    },
    {
      'name': 'Tech Conference Center',
      'location': const latlong.LatLng(37.7849, -122.4094),
      'type': 'Conference Center',
      'networkingScore': 4.8,
      'busyLevel': 'High',
    },
    {
      'name': 'CoWorking Space SF',
      'location': const latlong.LatLng(37.7649, -122.4294),
      'type': 'CoWorking',
      'networkingScore': 4.2,
      'busyLevel': 'Low',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentLocation = const latlong.LatLng(37.7749, -122.4194);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Location Mode (OSM)',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          // Map/List toggle
          IconButton(
            onPressed: () => _toggleView(),
            icon: Icon(_isMapView ? Icons.list : Icons.map),
            tooltip: _isMapView ? 'Switch to List View' : 'Switch to Map View',
          ),
          // Settings
          IconButton(
            onPressed: () => _showLocationSettings(),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'OSM-based networking active',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'DISCOVERABLE',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // OSM Map or List View
          Expanded(
            child: _isMapView ? _buildOSMMapView() : _buildListView(),
          ),
          
          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showVenueList(),
                    icon: const Icon(Icons.list),
                    label: const Text('View Venues'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAvailabilityHistory(),
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOSMMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? const latlong.LatLng(37.7749, -122.4194),
        initialZoom: 15.0,
        onTap: (tapPosition, point) => _onMapTapped(point),
      ),
      children: [
        // OpenStreetMap tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.putrace.putrace',
        ),
        
        // Venue markers
        MarkerLayer(
          markers: _venues.map((venue) {
            final isUserCreated = venue['isUserCreated'] ?? false;
            final isOSMVenue = venue['osmVenueId'] != null;
            
            return Marker(
              point: venue['location'],
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => _selectVenue(venue),
                child: Container(
                  decoration: BoxDecoration(
                    color: isUserCreated ? Colors.green : 
                           isOSMVenue ? Colors.blue : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getVenueIcon(venue['type']),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        // Availability circle
        if (_currentLocation != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _currentLocation!,
                radius: 1000, // 1km radius
                color: Colors.orange.withValues(alpha: 0.3),
                borderColor: Colors.orange,
                borderStrokeWidth: 2,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildListView() {
    return Container(
      color: Colors.grey[50],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _venues.length,
        itemBuilder: (context, index) {
          final venue = _venues[index];
          return _buildVenueCard(venue);
        },
      ),
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _selectVenue(venue),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Venue icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getVenueIcon(venue['type']),
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Venue details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue['name'],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        venue['type'],
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Networking score
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.green, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${venue['networkingScore']}',
                                  style: GoogleFonts.inter(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Busy level
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getBusyLevelColor(venue['busyLevel']).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              venue['busyLevel'],
                              style: GoogleFonts.inter(
                                color: _getBusyLevelColor(venue['busyLevel']),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleView() {
    setState(() {
      _isMapView = !_isMapView;
    });
  }

  // OSM venue discovery methods
  void _onMapTapped(latlong.LatLng point) {
    _searchNearbyVenues(point);
  }

  Future<void> _searchNearbyVenues(latlong.LatLng position) async {
    setState(() {
      _isSearchingVenues = true;
    });

    try {
      // Search for existing venues nearby using OSM
      final venues = await _venueService.searchNearbyVenues(
        position: position,
        radius: 500, // 500m radius
      );

      setState(() {
        _discoveredVenues = venues;
        _isSearchingVenues = false;
      });

      // Show venue discovery options
      _showVenueDiscoveryOptions(position, venues);
    } catch (e) {
      setState(() {
        _isSearchingVenues = false;
      });
      
      // Show error and still allow pinning
      _showVenueDiscoveryOptions(position, []);
    }
  }

  void _showVenueDiscoveryOptions(latlong.LatLng position, List<OSMVenue> existingVenues) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => VenuePinningSheet(
        position: position,
        existingVenues: existingVenues.isNotEmpty ? existingVenues : null,
        onVenueCreated: _addVenueToDatabase,
      ),
    );
  }

  void _addVenueToDatabase(VenueData venueData) {
    // Add venue to local database
    final newVenue = {
      'name': venueData.name,
      'location': venueData.location,
      'type': venueData.type,
      'category': venueData.category,
      'description': venueData.description,
      'networkingScore': 4.0, // Default score for user-created venues
      'busyLevel': 'Medium',
      'isUserCreated': venueData.isUserCreated,
      'osmVenueId': venueData.googlePlaceId, // Reuse field for OSM ID
    };

    setState(() {
      _venues.add(newVenue);
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${venueData.name} added to the map!'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Focus on the new venue
            _focusOnVenue(venueData.location);
          },
        ),
      ),
    );
  }

  void _focusOnVenue(latlong.LatLng location) {
    _mapController.move(location, 16.0);
  }

  void _selectVenue(Map<String, dynamic> venue) {
    setState(() {
      _selectedVenue = venue['name'];
    });
    
    // Show venue details and availability options
    _showVenueDetails(venue);
  }

  void _showVenueDetails(Map<String, dynamic> venue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildVenueDetailsSheet(venue),
    );
  }

  Widget _buildVenueDetailsSheet(Map<String, dynamic> venue) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Venue header
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getVenueIcon(venue['type']),
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue['name'],
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      venue['type'],
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${venue['networkingScore']}',
                      style: GoogleFonts.inter(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _setAvailability(venue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Set Availability'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setAvailability(Map<String, dynamic> venue) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Availability set at ${venue['name']}'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  void _showVenueList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildVenueListSheet(),
    );
  }

  Widget _buildVenueListSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Venues',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._venues.map((venue) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _selectVenue(venue);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getVenueIcon(venue['type']),
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              venue['name'],
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${venue['type']} • ${venue['networkingScore']}★ • ${venue['busyLevel']}',
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showAvailabilityHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Availability history coming soon!')),
    );
  }

  void _showLocationSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location settings coming soon!')),
    );
  }

  IconData _getVenueIcon(String type) {
    switch (type) {
      case 'Coffee Shop':
        return Icons.local_cafe;
      case 'Conference Center':
        return Icons.business;
      case 'CoWorking':
        return Icons.work;
      default:
        return Icons.location_on;
    }
  }

  Color _getBusyLevelColor(String busyLevel) {
    switch (busyLevel.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
