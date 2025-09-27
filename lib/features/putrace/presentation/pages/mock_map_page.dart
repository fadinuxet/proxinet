import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MockMapPage extends StatefulWidget {
  const MockMapPage({super.key});

  @override
  State<MockMapPage> createState() => _MockMapPageState();
}

class _MockMapPageState extends State<MockMapPage> {
  // LatLng? _currentLocation; // Removed unused field
  String _selectedVenue = '';
  String _customMessage = '';
  bool _isMapView = true;
  
  // Mock venue data
  final List<Map<String, dynamic>> _venues = [
    {
      'name': 'Starbucks Downtown',
      'location': const LatLng(37.7749, -122.4194),
      'type': 'Coffee Shop',
      'networkingScore': 4.5,
      'busyLevel': 'Medium',
    },
    {
      'name': 'Tech Conference Center',
      'location': const LatLng(37.7849, -122.4094),
      'type': 'Conference Center',
      'networkingScore': 4.8,
      'busyLevel': 'High',
    },
    {
      'name': 'CoWorking Space SF',
      'location': const LatLng(37.7649, -122.4294),
      'type': 'CoWorking',
      'networkingScore': 4.2,
      'busyLevel': 'Low',
    },
  ];

  @override
  void initState() {
    super.initState();
    // _currentLocation = const LatLng(37.7749, -122.4194); // Removed unused field assignment
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Location Mode (Mock)',
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
                  'Location-based networking active',
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
          
          // Mock Map or List View
          Expanded(
            child: _isMapView ? _buildMockMapView() : _buildListView(),
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

  Widget _buildMockMapView() {
    return Container(
      color: Colors.grey[100],
      child: Stack(
        children: [
          // Mock map background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[100]!,
                  Colors.green[100]!,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mock Map View',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap anywhere to test venue discovery',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _testVenueDiscovery(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Test Venue Discovery'),
                  ),
                ],
              ),
            ),
          ),
          
          // Mock venue markers
          ..._venues.asMap().entries.map((entry) {
            final index = entry.key;
            final venue = entry.value;
            // final position = venue['location'] as LatLng; // Removed unused variable
            
            return Positioned(
              left: 50 + (index * 80.0),
              top: 100 + (index * 60.0),
              child: GestureDetector(
                onTap: () => _selectVenue(venue),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getVenueIcon(venue['type']),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
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

  void _testVenueDiscovery() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Venue Discovery Test'),
        content: const Text('This would trigger OSM venue discovery in the real implementation. The OSM service is ready to use!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _selectVenue(Map<String, dynamic> venue) {
    setState(() {
      _selectedVenue = venue['name'];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${venue['name']}'),
        backgroundColor: Colors.green,
      ),
    );
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
