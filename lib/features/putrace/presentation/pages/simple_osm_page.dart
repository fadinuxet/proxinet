import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import '../../data/services/osm_venue_service.dart';
import '../../data/services/bounds_venue_service.dart';
import '../../data/services/venue_persistence_service.dart';
import '../../data/models/venue_data.dart';

class SimpleOSMPage extends StatefulWidget {
  const SimpleOSMPage({super.key});

  @override
  State<SimpleOSMPage> createState() => _SimpleOSMPageState();
}

class _SimpleOSMPageState extends State<SimpleOSMPage> {
  final MapController _mapController = MapController();
  final OSMVenueService _venueService = OSMVenueService();
  final BoundsVenueService _boundsService = BoundsVenueService();
  late final VenuePersistenceService _persistenceService;
  latlong.LatLng? _currentLocation;
  bool _isMapView = true;
  bool _isLoading = false;
  String _searchQuery = '';
  List<OSMVenue> _discoveredVenues = [];
  List<OSMVenue> _visibleVenues = []; // Only venues visible on map
  OSMVenue? _selectedVenue;
  
  // Discover-based interface state
  bool _isDiscovering = false;
  Timer? _discoveryTimer;
  bool _isButtonBlinking = false;
  bool _isSelectingVenue = false; // Prevent discovery during venue selection
  bool _isInitialLoading = true; // Show loading indicator on map startup
  
  // My Places feature
  List<OSMVenue> _myPlaces = [];
  String _venueCustomMessage = ''; // Custom message for the selected venue
  Map<String, double>? _lastBounds; // Store bounds as map
  OSMVenue? _currentLocationVenue; // Currently selected venue for location mode

  @override
  void initState() {
    super.initState();
    _persistenceService = VenuePersistenceService();
    _getCurrentLocation();
    _loadMyPlaces();
    
    // Force initial venue discovery after map loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _currentLocation != null) {
          _discoverInitialVenues();
        }
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentLocation = latlong.LatLng(position.latitude, position.longitude);
      });
      // Auto-discover venues when location is available (discover-based!)
      _discoverInitialVenues();
    } catch (e) {
      
      // Don't set a fallback location - let user know they need to enable location
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Location permission required. Please enable location services.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _getCurrentLocation(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _discoveryTimer?.cancel();
    super.dispose();
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
          // Map/List toggle only
          IconButton(
            onPressed: () => _toggleView(),
            icon: Icon(_isMapView ? Icons.list : Icons.map),
            tooltip: _isMapView ? 'Switch to List View' : 'Switch to Map View',
          ),
        ],
      ),
      body: Column(
        children: [
          // Discovery status header
          Container(
            padding: const EdgeInsets.all(16),
            color: _isDiscovering ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  _isDiscovering ? Icons.explore : Icons.location_on,
                  color: _isDiscovering ? Colors.blue : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isDiscovering ? 'Discovering venues in area...' : 'OSM-based networking active',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _isDiscovering ? Colors.blue : Colors.orange,
                  ),
                ),
                const Spacer(),
                if (_isDiscovering)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
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
                // Info icon
                GestureDetector(
                  onTap: () => _showVenueInfoDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Venues button - smaller and centered with flexible width
                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      color: _isButtonBlinking ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isButtonBlinking ? Icons.new_releases : Icons.location_on,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Venues (${_visibleVenues.length})',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 230), // Move down 100px more towards navigation bar
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // My Places button - 75% size
            Transform.scale(
              scale: 0.75,
              child: FloatingActionButton(
                onPressed: () => _showMyPlaces(),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                heroTag: "my_places",
                child: const Icon(Icons.bookmark),
              ),
            ),
            const SizedBox(height: 8),
            // My Location button - 75% size
            Transform.scale(
              scale: 0.75,
              child: FloatingActionButton(
                onPressed: () => _goToMyLocation(),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                heroTag: "my_location",
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOSMMapView() {
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? const latlong.LatLng(37.7749, -122.4194),
        initialZoom: 15.0,
        onTap: (tapPosition, point) {
          
          _onMapTapped(point);
        },
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && !_isSelectingVenue) {
            
            // User is actively moving the map - discover venues in new bounds
            _discoverVenuesInCurrentView();
          }
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // OpenStreetMap tiles - NO API KEY NEEDED!
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.putrace.putrace',
        ),
        
        // Loading overlay
        if (_isInitialLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Discovering venues...',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Finding networking opportunities near you',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Venue markers
        if (_discoveredVenues.isNotEmpty)
          MarkerLayer(
            markers: _discoveredVenues.map((venue) {
              final isSelected = _selectedVenue?.id == venue.id;
            return Marker(
              point: venue.location,
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () {
                  
                  _selectVenue(venue);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getVenueIcon(venue.amenity),
                      color: Colors.white,
                      size: 28,
                    ),
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Search field for list view
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  'Search Venues',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, type, or address...',
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.clear, color: Colors.orange),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.orange.withValues(alpha: 0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Found ${_getFilteredVenues().length} venues',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Venues list
          Expanded(
            child: _discoveredVenues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No venues found',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the search button to find venues',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _getFilteredVenues().length,
                    itemBuilder: (context, index) {
                      final venue = _getFilteredVenues()[index];
                      return _buildVenueCard(venue);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueCard(OSMVenue venue) {
    final isSelected = _selectedVenue?.id == venue.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isSelected ? 4 : 2,
        color: isSelected ? Colors.orange.withValues(alpha: 0.1) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected ? BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
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
                    color: isSelected ? Colors.orange : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getVenueIcon(venue.amenity),
                    color: isSelected ? Colors.white : Colors.orange,
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
                        venue.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        venue.amenity,
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (venue.address != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          venue.address!,
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                                  '${venue.networkingScore.toStringAsFixed(1)}',
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
                          // Networking friendly
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: venue.isNetworkingFriendly ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              venue.isNetworkingFriendly ? 'Networking' : 'General',
                              style: GoogleFonts.inter(
                                color: venue.isNetworkingFriendly ? Colors.blue : Colors.grey,
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
                
                // Selection indicator
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.orange,
                    size: 24,
                  )
                else
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

  void _onMapTapped(latlong.LatLng point) {
    // Only search for venues if no venue is currently selected
    // This prevents discovery when user is just selecting venues
    if (_selectedVenue == null) {
      _searchVenuesAtLocation(point);
    } else {
      // Clear selection when tapping empty area
      setState(() {
        _selectedVenue = null;
      });
    }
  }

  /// Discover venues in the current map view (discover-based interface)
  void _discoverVenuesInCurrentView() {
    // Cancel previous discovery timer to debounce
    _discoveryTimer?.cancel();
    
    // Set discovering state
    setState(() {
      _isDiscovering = true;
    });
    
    // Debounce discovery to avoid too many API calls
    _discoveryTimer = Timer(const Duration(milliseconds: 1200), () async {
      await _performVenueDiscoveryAtMapCenter();
    });
  }

  /// Perform venue discovery at the current map center
  Future<void> _performVenueDiscoveryAtMapCenter() async {
    try {
      // Get the current map center
      final mapCenter = _mapController.camera.center;
      
      
      // Create bounds around map center
      final north = mapCenter.latitude + 0.01;
      final south = mapCenter.latitude - 0.01;
      final east = mapCenter.longitude + 0.01;
      final west = mapCenter.longitude - 0.01;
      
      
      
      final venues = await _boundsService.getVenuesInBounds(
        north: north,
        south: south,
        east: east,
        west: west,
      );
      
      // Filter venues to only show those visible on the current map
      final mapBounds = _mapController.camera.visibleBounds;
      final visibleVenues = venues.where((venue) {
        return venue.location.latitude >= mapBounds.south &&
               venue.location.latitude <= mapBounds.north &&
               venue.location.longitude >= mapBounds.west &&
               venue.location.longitude <= mapBounds.east;
      }).toList();
      
      setState(() {
        _discoveredVenues = venues; // Keep all discovered venues
        _visibleVenues = visibleVenues; // Only venues visible on map
        _isDiscovering = false;
        _isInitialLoading = false; // Hide loading indicator when venues are found
        _lastBounds = {
          'north': north,
          'south': south,
          'east': east,
          'west': west,
        };
      });
      
      if (venues.isNotEmpty) {
        // Blink the venues button instead of showing snackbar
        _blinkVenuesButton();
        
      }
    } catch (e) {
      
      setState(() {
        _isDiscovering = false;
        _isInitialLoading = false; // Hide loading indicator on error
      });
    }
  }

  /// Initial venue discovery when map loads
  Future<void> _discoverInitialVenues() async {
    if (_currentLocation == null) {
      
      return;
    }
    
    
    await _performVenueDiscoveryAtMapCenter();
  }

  /// Go to user's current location
  Future<void> _goToMyLocation() async {
    if (_currentLocation == null) {
      // Try to get current location first
      await _getCurrentLocation();
    }
    
    if (_currentLocation != null) {
      // Center map on current location
      _mapController.move(_currentLocation!, 16.0);
      
      // Discover venues around current location
      await _discoverInitialVenues();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Centered on your location'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Could not get your location. Please check permissions.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Blink the venues button to indicate new venues found
  void _blinkVenuesButton() {
    setState(() {
      _isButtonBlinking = true;
    });
    
    // Stop blinking after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isButtonBlinking = false;
        });
      }
    });
  }

  /// Load My Places from persistence
  Future<void> _loadMyPlaces() async {
    try {
      final venues = await _persistenceService.getMyPlaces();
      setState(() {
        _myPlaces = venues.map((v) => OSMVenue.fromVenueData(v)).toList();
      });
      
    } catch (e) {
      
    }
  }

  /// Add venue to My Places with persistence
  Future<void> _addToMyPlaces(OSMVenue venue) async {
    try {
      
      
      
      // Check if already exists locally
      if (!_myPlaces.any((place) => place.id == venue.id)) {
        
        
        // Create VenueData from OSMVenue
        final venueData = VenueData.fromOSMVenue(
          venue,
          customMessage: _venueCustomMessage,
          isFavorite: true,
          isAvailable: true,
        );
        
        
        
        // Save to persistence
        
        await _persistenceService.saveVenue(venueData);
        
        
        // Update local state
        setState(() {
          _myPlaces.add(venue);
        });
        
        
        
      } else {
        
      }
    } catch (e) {
      
      
      
      // Fallback to local storage only
      setState(() {
        if (!_myPlaces.any((place) => place.id == venue.id)) {
          _myPlaces.add(venue);
          // print('📌 Added ${venue.name} to local My Places (fallback)'); // Removed print statement
        }
      });
    }
  }

  void _setCurrentLocationVenue(OSMVenue venue, DateTime? scheduledTime) {
    setState(() {
      _currentLocationVenue = venue;
    });
    
    
    // Return the venue, custom message, and scheduled time to the previous screen
    Navigator.pop(context, {
      'venue': venue,
      'message': _venueCustomMessage,
      'scheduledTime': scheduledTime,
    });
  }

  /// Show My Places dialog
  void _showMyPlaces() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                Text(
                  'My Places',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_myPlaces.length} saved',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_myPlaces.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No places saved yet',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Set Available" on any venue to save it here',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _myPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _myPlaces[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _selectVenue(place);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getVenueIcon(place.amenity),
                                  color: Colors.purple,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      place.type,
                                      style: GoogleFonts.inter(
                                        color: Colors.purple,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (place.address != null)
                                      Text(
                                        place.address!,
                                        style: GoogleFonts.inter(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchVenuesAtLocation(latlong.LatLng location) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final venues = await _venueService.searchNearbyVenues(
        position: location,
        radius: 500, // 500m radius for tapped location
      );
      
      // Filter venues to only show those visible on the current map
      final mapBounds = _mapController.camera.visibleBounds;
      final visibleVenues = venues.where((venue) {
        return venue.location.latitude >= mapBounds.south &&
               venue.location.latitude <= mapBounds.north &&
               venue.location.longitude >= mapBounds.west &&
               venue.location.longitude <= mapBounds.east;
      }).toList();
      
      setState(() {
        _discoveredVenues = venues; // Keep all discovered venues
        _visibleVenues = visibleVenues; // Only venues visible on map
        _isLoading = false;
      });
      
      if (venues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No venues found at this location. Try another spot.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${venues.length} venues at this location!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Center map on tapped location
      _mapController.move(location, 16.0);
    } catch (e) {
      
      setState(() {
        _discoveredVenues = [];
        _visibleVenues = [];
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading venues: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _selectVenue(OSMVenue venue) {
    
    
    setState(() {
      _selectedVenue = venue;
      _isSelectingVenue = true; // Prevent discovery during selection
    });
    
    // Center map on selected venue WITHOUT triggering discovery
    _mapController.move(venue.location, 16.0);
    
    // Reset selection flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSelectingVenue = false;
        });
      }
    });
    
    // Show merged venue info and availability dialog with custom message input
    _showVenueSelectionDialog(venue);
  }

  void _showVenueSelectionDialog(OSMVenue venue) {
    final messageController = TextEditingController(text: _venueCustomMessage);
    bool useDefaultSettings = true;
    double locationRange = 1000.0;
    double autoDisconnectTimer = 60.0;
    String locationPrecision = 'City Level';
    String availabilityType = 'Now'; // 'Now' or 'Schedule'
    DateTime? scheduledDateTime;
    bool _highlightMessageField = false;
    bool _highlightScheduleField = false;
    bool _isDisposed = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  venue.name,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Venue Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.type,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                      if (venue.address != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                venue.address!,
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
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
                                  '${venue.networkingScore.toStringAsFixed(1)}',
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: venue.isNetworkingFriendly ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              venue.isNetworkingFriendly ? 'Networking' : 'General',
                              style: GoogleFonts.inter(
                                color: venue.isNetworkingFriendly ? Colors.blue : Colors.grey,
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
                
                const SizedBox(height: 20),
                
                // Custom Message Section
                Row(
                  children: [
                    Text(
                      'Custom Message',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: _highlightMessageField 
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                    boxShadow: _highlightMessageField 
                        ? [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: TextField(
                    controller: _isDisposed ? null : messageController,
                    decoration: InputDecoration(
                      hintText: 'e.g., "Meet me for coffee", "Come pitch your idea"',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.orange, width: 2),
                      ),
                      filled: true,
                      fillColor: _highlightMessageField 
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 2,
                    maxLength: 100,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Availability Type Section
                Row(
                  children: [
                    Text(
                      'Availability',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Now vs Schedule Toggle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _highlightScheduleField 
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _highlightScheduleField 
                          ? Colors.red
                          : Colors.green.withValues(alpha: 0.3),
                      width: _highlightScheduleField ? 2 : 1,
                    ),
                    boxShadow: _highlightScheduleField 
                        ? [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            availabilityType == 'Now' ? Icons.access_time : Icons.schedule,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Availability Type',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  availabilityType = 'Now';
                                  scheduledDateTime = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: availabilityType == 'Now' ? Colors.green : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: availabilityType == 'Now' ? Colors.green : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: availabilityType == 'Now' ? Colors.white : Colors.grey[600],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Now',
                                        style: GoogleFonts.inter(
                                          color: availabilityType == 'Now' ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  availabilityType = 'Schedule';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: availabilityType == 'Schedule' ? Colors.green : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: availabilityType == 'Schedule' ? Colors.green : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      color: availabilityType == 'Schedule' ? Colors.white : Colors.grey[600],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Schedule',
                                        style: GoogleFonts.inter(
                                          color: availabilityType == 'Schedule' ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      if (availabilityType == 'Schedule') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Select Date & Time',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: scheduledDateTime ?? DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(scheduledDateTime ?? DateTime.now().add(const Duration(hours: 1))),
                              );
                              if (time != null) {
                                setState(() {
                                  scheduledDateTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  scheduledDateTime != null
                                      ? '${scheduledDateTime!.day}/${scheduledDateTime!.month}/${scheduledDateTime!.year} at ${scheduledDateTime!.hour.toString().padLeft(2, '0')}:${scheduledDateTime!.minute.toString().padLeft(2, '0')}'
                                      : 'Select date and time',
                                  style: GoogleFonts.inter(
                                    color: scheduledDateTime != null ? Colors.grey[800] : Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Settings Section
                Text(
                  'Networking Settings',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Use Default Settings Toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use Default Settings',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Switch(
                        value: useDefaultSettings,
                        onChanged: (value) {
                          setState(() {
                            useDefaultSettings = value;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
                
                if (!useDefaultSettings) ...[
                  const SizedBox(height: 16),
                  
                  // Location Range
                  Text(
                    'Location Range: ${locationRange.round()}m',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Slider(
                    value: locationRange,
                    min: 50,
                    max: 2000,
                    divisions: 39,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      setState(() {
                        locationRange = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Auto-Disconnect Timer
                  Text(
                    'Auto-Disconnect Timer: ${autoDisconnectTimer.round()} minutes',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Slider(
                    value: autoDisconnectTimer,
                    min: 15,
                    max: 480,
                    divisions: 31,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      setState(() {
                        autoDisconnectTimer = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Location Precision
                  Text(
                    'Location Precision',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: locationPrecision,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: ['High', 'Medium', 'Low', 'City Level']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            locationPrecision = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Availability Question
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Set your availability at this venue?',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isDisposed = true;
                messageController.dispose();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Add haptic feedback
                HapticFeedback.mediumImpact();
                
                // Validate required fields with visual highlighting
                bool hasErrors = false;
                
                if (messageController.text.trim().isEmpty) {
                  hasErrors = true;
                  // Highlight the message field
                  setState(() {
                    _highlightMessageField = true;
                  });
                  // Reset highlight after animation
                  Future.delayed(const Duration(milliseconds: 2000), () {
                    if (mounted) {
                      setState(() {
                        _highlightMessageField = false;
                      });
                    }
                  });
                }
                
                if (availabilityType == 'Schedule' && scheduledDateTime == null) {
                  hasErrors = true;
                  // Highlight the schedule section
                  setState(() {
                    _highlightScheduleField = true;
                  });
                  // Reset highlight after animation
                  Future.delayed(const Duration(milliseconds: 2000), () {
                    if (mounted) {
                      setState(() {
                        _highlightScheduleField = false;
                      });
                    }
                  });
                }
                
                if (hasErrors) {
                  // Show brief error message without tooltip
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                // Capture all settings
                _venueCustomMessage = messageController.text.trim();
                _isDisposed = true;
                messageController.dispose();
                
                
                Navigator.pop(context);
                
                // Add to My Places and set availability
                _addToMyPlaces(venue);
                _setCurrentLocationVenue(venue, scheduledDateTime);
                
                // Show success message with settings info
                String availabilityInfo = availabilityType == 'Now' 
                    ? 'available now'
                    : 'scheduled for ${scheduledDateTime!.day}/${scheduledDateTime!.month}/${scheduledDateTime!.year} at ${scheduledDateTime!.hour.toString().padLeft(2, '0')}:${scheduledDateTime!.minute.toString().padLeft(2, '0')}';
                
                String settingsInfo = useDefaultSettings 
                    ? 'using default settings'
                    : 'with custom settings (${locationRange.round()}m range, ${autoDisconnectTimer.round()}min timer, $locationPrecision precision)';
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Added ${venue.name} to My Places & set availability $availabilityInfo $settingsInfo!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Set Available'),
            ),
          ],
        ),
      ),
    );
  }


  void _showVenueList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildVenueListSheet(),
    );
  }
  
  /// Search venues in the list
  List<OSMVenue> _getFilteredVenues() {
    
    
    
    if (_searchQuery.isEmpty) {
      return _visibleVenues;
    }
    
    final filtered = _visibleVenues.where((venue) {
      final query = _searchQuery.toLowerCase();
      final matches = venue.name.toLowerCase().contains(query) ||
             venue.type.toLowerCase().contains(query) ||
             (venue.address?.toLowerCase().contains(query) ?? false) ||
             (venue.amenity?.toLowerCase().contains(query) ?? false);
      
      if (matches) {
        
      }
      
      return matches;
    }).toList();
    
    
    return filtered;
  }
  
  /// Show info dialog explaining venue discovery
  void _showVenueInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              'How Venues Work',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Venue Discovery:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              Icons.explore,
              'Auto-Discovery',
              'Venues appear automatically as you pan and zoom the map',
            ),
            _buildInfoItem(
              Icons.visibility,
              'Visible Count',
              'The number shows only venues currently visible on your map',
            ),
            _buildInfoItem(
              Icons.search,
              'Search & Filter',
              'Use the search bar in the venues list to find specific places',
            ),
            _buildInfoItem(
              Icons.location_on,
              'Real-Time Data',
              'All venues come from OpenStreetMap - completely free and privacy-focused',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Pan around to discover more venues in different areas!',
                      style: GoogleFonts.inter(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build info item for the dialog
  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueListSheet() {
    
    
    return StatefulBuilder(
      builder: (context, setState) {
        // final filteredVenues = _getFilteredVenues(); // Removed unused variable
        
        
        
        
        
        return Container(
      height: MediaQuery.of(context).size.height * 0.7, // Limit height to 70% of screen
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with search
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discovered Venues (${_visibleVenues.length})',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Venues list - Use Expanded to prevent overflow
          Expanded(
            child: _VenueSearchList(
              venues: _visibleVenues, // Show all visible venues without filtering
              onDiscoverVenues: () {
                Navigator.pop(context);
                _discoverInitialVenues();
              },
              onVenueSelected: (venue) {
                Navigator.pop(context); // Close the venue list sheet
                _selectVenue(venue); // Show the venue selection popup
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  IconData _getVenueIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'cafe':
      case 'coffee_shop':
        return Icons.local_cafe;
      case 'restaurant':
        return Icons.restaurant;
      case 'bar':
      case 'pub':
        return Icons.local_bar;
      case 'library':
        return Icons.local_library;
      case 'gym':
      case 'fitness_center':
        return Icons.fitness_center;
      case 'park':
        return Icons.park;
      case 'bank':
        return Icons.account_balance;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'hospital':
        return Icons.local_hospital;
      case 'school':
      case 'university':
        return Icons.school;
      case 'office':
      case 'coworking_space':
        return Icons.business;
      case 'conference_centre':
        return Icons.meeting_room;
      case 'community_centre':
        return Icons.people;
      case 'hotel':
        return Icons.hotel;
      case 'beauty':
        return Icons.content_cut;
      case 'shopping':
        return Icons.shopping_cart;
      default:
        return Icons.location_on;
    }
  }
}

/// Separate widget for venue search list to prevent map rebuilds
class _VenueSearchList extends StatelessWidget {
  final List<OSMVenue> venues;
  final VoidCallback onDiscoverVenues;
  final Function(OSMVenue) onVenueSelected;

  const _VenueSearchList({
    required this.venues,
    required this.onDiscoverVenues,
    required this.onVenueSelected,
  });

  @override
  Widget build(BuildContext context) {
    
    
    return venues.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off, 
                  size: 48, 
                  color: Colors.grey[400]
                ),
                const SizedBox(height: 8),
                Text(
                  'No venues match your search',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try a different search term',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            itemCount: venues.length,
            itemBuilder: (context, index) {
              final venue = venues[index];
              return _buildVenueCard(venue);
            },
          );
  }

  Widget _buildVenueCard(OSMVenue venue) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          child: Icon(
            _getVenueIcon(venue.amenity),
            color: Colors.orange,
            size: 20,
          ),
        ),
        title: Text(
          venue.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (venue.amenity != null) ...[
              Text(
                venue.amenity!.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
            ],
            if (venue.address != null && venue.address!.isNotEmpty) ...[
              Text(
                venue.address!,
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (venue.wifi)
              Icon(
                Icons.wifi,
                color: Colors.green,
                size: 16,
              ),
            if (venue.outdoorSeating)
              Icon(
                Icons.outdoor_grill,
                color: Colors.blue,
                size: 16,
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
        onTap: () {
          
          onVenueSelected(venue);
        },
      ),
    );
  }

  IconData _getVenueIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'cafe':
      case 'coffee_shop':
        return Icons.local_cafe;
      case 'restaurant':
        return Icons.restaurant;
      case 'library':
        return Icons.local_library;
      case 'gym':
        return Icons.fitness_center;
      case 'park':
        return Icons.park;
      case 'bank':
        return Icons.account_balance;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'hospital':
        return Icons.local_hospital;
      case 'school':
      case 'university':
        return Icons.school;
      case 'office':
      case 'coworking_space':
        return Icons.business;
      case 'conference_centre':
        return Icons.event;
      case 'community_centre':
        return Icons.people;
      case 'bar':
      case 'pub':
        return Icons.local_bar;
      case 'hotel':
        return Icons.hotel;
      default:
        return Icons.location_on;
    }
  }
}
