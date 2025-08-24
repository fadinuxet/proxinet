import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'dart:math';
import '../../../../core/ui/proxinet_design.dart';
import '../../../../core/utils/geohash.dart';
import '../../../../core/services/proxinet_presence_sync_service.dart';
import '../../../../core/services/serendipity_models.dart';
import 'package:google_fonts/google_fonts.dart';

class ProxinetMapPage extends StatefulWidget {
  const ProxinetMapPage({super.key});

  @override
  State<ProxinetMapPage> createState() => _ProxinetMapPageState();
}

class _ProxinetMapPageState extends State<ProxinetMapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(25.276987, 55.296249); // Dubai default
  bool _nearbyEnabled = false;
  double _radiusKm = 1.0;
  List<Map<String, dynamic>> _nearbyUsers = [];
  List<Map<String, dynamic>> _availableUsers = []; // New: available users
  late ProxinetPresenceSyncService _presenceSync;
  
  // Tab controller
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    
    _presenceSync = GetIt.instance<ProxinetPresenceSyncService>();
    _getCurrentLocation();
    _loadNearbyStatus();
    
    // Load available users (always load these regardless of nearby status)
    _loadAvailableUsers();
    
    // Initialize availability status
    _presenceSync.initializeAvailabilityFromFirestore();
    
    // Listen to presence changes
    _presenceSync.addListener(_onPresenceChanged);
  }

  @override
  void dispose() {
    _presenceSync.removeListener(_onPresenceChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Request location permission with better error handling
      final permission = await Permission.location.request();
      if (permission.isGranted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation, 15.0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission required to get your current location'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        String errorMessage = 'Failed to get current location';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Location request timed out. Please try again.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Location permission denied. Please grant access.';
        } else if (e.toString().contains('location service')) {
          errorMessage = 'Location services are disabled. Please enable them.';
        } else {
          errorMessage = 'Error: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _getCurrentLocation,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadNearbyStatus() async {
    try {
      await _presenceSync.initializeFromFirestore();
      if (mounted) {
        setState(() {
          _nearbyEnabled = _presenceSync.isPresenceEnabled;
          _radiusKm = _presenceSync.radiusKm;
          if (_presenceSync.latitude != null && _presenceSync.longitude != null) {
            _currentLocation = LatLng(_presenceSync.latitude!, _presenceSync.longitude!);
          }
        });
      }
    } catch (e) {
      print('Error loading nearby status: $e');
    }
  }

  Future<void> _toggleNearbyDiscovery() async {
    if (_nearbyEnabled) {
      await _disableNearbyDiscovery();
    } else {
      await _enableNearbyDiscovery();
    }
  }

  Future<void> _enableNearbyDiscovery() async {
    try {
      // Check if user is authenticated
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please sign in to enable nearby discovery')),
        );
        return;
      }

      // Request location permission with better error handling
      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission required for nearby discovery'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Check if location services are enabled
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable location services in your device settings'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Calculate geohash and expiration
      final precision = Geohash.precisionForRadiusKm(_radiusKm);
      final hash = Geohash.encode(position.latitude, position.longitude,
          precision: precision);
      final expireAt = DateTime.now().toUtc().add(const Duration(minutes: 15));

      // Use the sync service instead of direct Firestore
      await _presenceSync.enablePresence(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: _radiusKm,
      );

      setState(() {
        _nearbyEnabled = true;
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_currentLocation, 15.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nearby discovery enabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Location error: $e');
      if (mounted) {
        String errorMessage = 'Error enabling nearby discovery';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Location request timed out. Please try again.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Location permission denied. Please grant access.';
        } else if (e.toString().contains('location service')) {
          errorMessage = 'Location services are disabled. Please enable them.';
        } else {
          errorMessage = 'Error: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _enableNearbyDiscovery,
            ),
          ),
        );
      }
    }
  }

  Future<void> _disableNearbyDiscovery() async {
    try {
      await _presenceSync.disablePresence();

      setState(() {
        _nearbyEnabled = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nearby discovery disabled')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error disabling nearby discovery: $e')),
      );
    }
  }

  void _loadNearbyUsers() {
    if (!_nearbyEnabled) return;

    final precision = Geohash.precisionForRadiusKm(_radiusKm);
    final prefix = Geohash.encode(
        _currentLocation.latitude, _currentLocation.longitude,
        precision: precision);

    FirebaseFirestore.instance
        .collection('presence_geo')
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThanOrEqualTo: Geohash.prefixRangeEnd(prefix))
        .snapshots()
        .listen((snapshot) {
      final users = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final expireAt = data['expireAt'] as Timestamp?;
            return expireAt != null &&
                expireAt.toDate().isAfter(DateTime.now());
          })
          .map((doc) => {
                'id': doc.id,
                'lat': doc.data()['lat'] as double,
                'lng': doc.data()['lng'] as double,
                'precisionM': doc.data()['precisionM'] as int? ?? 1000,
              })
          .toList();

      setState(() {
        _nearbyUsers = users;
      });
    });
  }

  void _onPresenceChanged() {
    if (mounted) {
      setState(() {
        _nearbyEnabled = _presenceSync.isPresenceEnabled;
        _radiusKm = _presenceSync.radiusKm;
        if (_presenceSync.latitude != null && _presenceSync.longitude != null) {
          _currentLocation = LatLng(_presenceSync.latitude!, _presenceSync.longitude!);
        }
      });
    }
  }

  void _showDeviceConnectionDialog(BuildContext context, Map<String, dynamic> user, Color color, int index) {
    final scheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Device ${index + 1}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This device is nearby and available for connection.',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, color: scheme.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Distance: ${_calculateDistance(user['lat'], user['lng']).toStringAsFixed(1)}m',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _connectToDevice(user);
            },
            icon: const Icon(Icons.connect_without_contact),
            label: const Text('Connect'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(double lat, double lng) {
    // Simple distance calculation (you can use a more accurate formula)
    final dx = lat - _currentLocation.latitude;
    final dy = lng - _currentLocation.longitude;
    return sqrt(dx * dx + dy * dy) * 111000; // Rough conversion to meters
  }

  void _connectToDevice(Map<String, dynamic> user) {
    // TODO: Implement actual connection logic
    // This could involve:
    // 1. Sending a connection request
    // 2. Opening a chat
    // 3. Sharing contact info
    // 4. etc.
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection request sent to Device ${user['id']}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(
          label: 'View Chat',
          onPressed: () {
            // Navigate to chat or messages
            context.push('/proxinet/messages');
          },
        ),
      ),
    );
  }

  void _showAvailableUserDialog(BuildContext context, Map<String, dynamic> user) {
    final scheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.person_add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'] ?? 'Available User',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Available to connect',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This person is available to connect!',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, color: scheme.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Distance: ${_calculateDistance(user['lat'], user['lng']).toStringAsFixed(1)}m',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Status: Available Now',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (user['audience'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility, color: scheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Audience: ${_formatAudience(user['audience'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          // View Profile Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _viewUserProfile(user);
            },
            icon: const Icon(Icons.person),
            label: const Text('Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              side: BorderSide(color: scheme.primary),
            ),
          ),
          // Add to Contacts Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _addToContacts(user);
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green),
            ),
          ),
          // Chat Button
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _startChat(user);
            },
            icon: const Icon(Icons.chat),
            label: const Text('Chat'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _connectToAvailableUser(Map<String, dynamic> user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection request sent to Available User'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View Chat',
          onPressed: () {
            context.push('/proxinet/messages');
          },
        ),
      ),
    );
  }

  void _loadAvailableUsers() {
    // Load users who have set their availability to ON
    FirebaseFirestore.instance
        .collection('availability')
        .where('isAvailable', isEqualTo: true)
        .where('until', isGreaterThan: Timestamp.now())
        .snapshots()
        .listen((snapshot) async {
      final availableUsers = <Map<String, dynamic>>[];
      
      print('Loading available users: ${snapshot.docs.length} documents found');
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final userId = doc.id;
          
          print('Processing user $userId: ${data.toString()}');
          
          // Check if location data is directly in availability document
          double? lat = data['latitude'] as double?;
          double? lng = data['longitude'] as double?;
          String? userName = data['userName'] as String?;
          
          // If no location in availability, try to get from user profile
          if (lat == null || lng == null) {
            try {
              final userProfile = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
              
              if (userProfile.exists) {
                final profileData = userProfile.data()!;
                lat = profileData['latitude'] as double?;
                lng = profileData['longitude'] as double?;
                userName = profileData['displayName'] ?? 'Available User';
                print('Got location from profile: lat=$lat, lng=$lng');
              } else {
                print('User profile does not exist for $userId');
              }
            } catch (e) {
              print('Error loading user profile: $e');
            }
          } else {
            print('Got location from availability: lat=$lat, lng=$lng');
          }
          
          // Only add user if we have valid location data
          if (lat != null && lng != null) {
            availableUsers.add({
              'id': userId,
              'lat': lat,
              'lng': lng,
              'name': userName ?? 'Available User',
              'type': 'available', // Distinguish from nearby users
              'audience': data['audience'] ?? 'firstDegree',
              'until': data['until'],
            });
            print('Added user $userId to available users list');
          } else {
            print('User $userId has no valid location data - skipping');
          }
        } catch (e) {
          print('Error loading available user: $e');
        }
      }
      
      print('Total available users loaded: ${availableUsers.length}');
      
      if (mounted) {
        setState(() {
          _availableUsers = availableUsers;
        });
      }
    });
  }

  Widget _buildAroundMeTab(ColorScheme scheme) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 15.0,
            onMapReady: () {
              if (_nearbyEnabled) {
                _loadNearbyUsers();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.yallakoll.proxinet',
            ),
            // Current location marker
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                // Nearby users markers
                ..._nearbyUsers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  final colors = [
                    scheme.secondary,
                    scheme.tertiary,
                    scheme.error,
                    scheme.primary,
                    scheme.outline,
                    Colors.purple,
                    Colors.teal,
                    Colors.orange,
                    Colors.indigo,
                    Colors.pink,
                  ];
                  final color = colors[index % colors.length];
                  
                  return Marker(
                    point: LatLng(user['lat'], user['lng']),
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () => _showEnhancedUserDialog(context, user, color, index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        ),
        // Radius control overlay
        if (_nearbyEnabled)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Radius: ${_radiusKm.toStringAsFixed(1)}km',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    width: 120,
                    child: Slider(
                      value: _radiusKm,
                      min: 0.1,
                      max: 10.0,
                      divisions: 99,
                      onChanged: (value) {
                        setState(() => _radiusKm = value);
                      },
                      onChangeEnd: (value) async {
                        if (_nearbyEnabled) {
                          await _enableNearbyDiscovery(); // Update with new radius
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        // User Legend overlay
        if (_nearbyUsers.isNotEmpty)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nearby Users',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Current location
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Location',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Nearby users with different colors
                  ..._nearbyUsers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final colors = [
                      scheme.secondary,
                      scheme.tertiary,
                      scheme.error,
                      scheme.primary,
                      scheme.outline,
                      Colors.purple,
                      Colors.teal,
                      Colors.orange,
                      Colors.indigo,
                      Colors.pink,
                    ];
                    final color = colors[index % colors.length];
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'User ${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${_nearbyUsers.length} users nearby',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Bottom overlay
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: ProxinetDesign.cardGradient(scheme),
              border:
                  Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _nearbyEnabled ? Icons.near_me : Icons.near_me_outlined,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nearbyEnabled
                            ? 'Nearby discovery is active'
                            : 'Discover friends and contacts who opt‑in nearby.',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        onPressed: _toggleNearbyDiscovery,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(10),
                        child: Text(_nearbyEnabled ? 'Disable' : 'Enable'),
                      ),
                    ),
                    if (_nearbyEnabled) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('My Location'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableTab(ColorScheme scheme) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 15.0,
            onMapReady: () {
              // No specific action needed here for available users,
              // as they are static and don't change based on proximity.
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.yallakoll.proxinet',
            ),
            // Current location marker
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                // Available users markers
                ..._availableUsers.map((user) => Marker(
                      point: LatLng(user['lat'], user['lng']),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showAvailableUserDialog(context, user),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(Icons.person_add, color: Colors.white, size: 16),
                        ),
                      ),
                    )),
              ],
            ),
          ],
        ),
        // Bottom overlay
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: ProxinetDesign.cardGradient(scheme),
              border:
                  Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_add,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available users to connect',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (_availableUsers.isNotEmpty)
                            Text(
                              '${_availableUsers.length} people available',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Availability Controls
                _buildAvailabilityControls(scheme),
                // Location refresh button for available users
                if (_presenceSync.isAvailableForConnections) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _presenceSync.refreshAvailabilityLocation();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location updated for other users'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Update My Location'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.primary,
                        side: BorderSide(color: scheme.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedTab(ColorScheme scheme) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 15.0,
            onMapReady: () {
              if (_nearbyEnabled) {
                _loadNearbyUsers();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.yallakoll.proxinet',
            ),
            // Current location marker
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                // Nearby users markers
                ..._nearbyUsers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  final colors = [
                    scheme.secondary,
                    scheme.tertiary,
                    scheme.error,
                    scheme.primary,
                    scheme.outline,
                    Colors.purple,
                    Colors.teal,
                    Colors.orange,
                    Colors.indigo,
                    Colors.pink,
                  ];
                  final color = colors[index % colors.length];
                  
                  return Marker(
                    point: LatLng(user['lat'], user['lng']),
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () => _showEnhancedUserDialog(context, user, color, index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                // Available users markers
                ..._availableUsers.map((user) => Marker(
                      point: LatLng(user['lat'], user['lng']),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showAvailableUserDialog(context, user),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(Icons.person_add, color: Colors.white, size: 16),
                        ),
                      ),
                    )),
              ],
            ),
          ],
        ),
        // Radius control overlay
        if (_nearbyEnabled)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Radius: ${_radiusKm.toStringAsFixed(1)}km',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    width: 120,
                    child: Slider(
                      value: _radiusKm,
                      min: 0.1,
                      max: 10.0,
                      divisions: 99,
                      onChanged: (value) {
                        setState(() => _radiusKm = value);
                      },
                      onChangeEnd: (value) async {
                        if (_nearbyEnabled) {
                          await _enableNearbyDiscovery(); // Update with new radius
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Comprehensive Legend overlay
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Map Legend',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // Current location
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Location',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Available users
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(Icons.person_add, color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Available to Connect',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nearby users
                if (_nearbyUsers.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nearby (BLE)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Show nearby user count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.secondary.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${_nearbyUsers.length} nearby users',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: scheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                // Show available user count
                if (_availableUsers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${_availableUsers.length} available users',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Bottom overlay
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: ProxinetDesign.cardGradient(scheme),
              border:
                  Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _nearbyEnabled ? Icons.near_me : Icons.near_me_outlined,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDiscoveryMessage(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        onPressed: _toggleNearbyDiscovery,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(10),
                        child: Text(_nearbyEnabled ? 'Disable' : 'Enable'),
                      ),
                    ),
                    if (_nearbyEnabled) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('My Location'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Get appropriate discovery message based on audience setting
  String _getDiscoveryMessage() {
    if (_nearbyEnabled) {
      return 'Nearby discovery is active';
    }
    
    // Check if user has "Everyone" audience set
    if (_presenceSync.isAvailableForConnections) {
      // This is a simplified check - in a real app you'd get the actual audience setting
      // For now, we'll show a more inclusive message
      return 'Discover anyone nearby who is available to connect';
    }
    
    // Default message for restricted audiences
    return 'Discover contacts and friends who opt-in nearby and available to connect';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_nearbyEnabled) {
      _loadNearbyUsers();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.network_check,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ProxiNet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/proxinet');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Go to current location',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.near_me, size: 20),
              text: 'Around Me',
            ),
            Tab(
              icon: Icon(Icons.person_add, size: 20),
              text: 'Available',
            ),
            Tab(
              icon: Icon(Icons.layers, size: 20),
              text: 'Combined',
            ),
          ],
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: scheme.primary,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withOpacity(0.6),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Around Me (Nearby BLE)
          _buildAroundMeTab(scheme),
          
          // Tab 2: Available to Connect
          _buildAvailableTab(scheme),
          
          // Tab 3: Combined View
          _buildCombinedTab(scheme),
        ],
      ),
    );
  }

  void _showEnhancedUserDialog(BuildContext context, Map<String, dynamic> user, Color color, int index) {
    final scheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.person_pin_circle,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user['name'] ?? 'Nearby User ${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_calculateDistance(user['lat'], user['lng']).toStringAsFixed(1)}m away',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: color, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Signal: ${_getSignalStrength(user)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _viewUserProfile(user);
            },
            icon: const Icon(Icons.person, size: 16),
            label: const Text('Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              side: BorderSide(color: scheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          // Only show Add button if it's not the current user
          if (user['id'] != FirebaseAuth.instance.currentUser?.uid) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _addToContacts(user);
              },
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Add'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _startChat(user);
            },
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('Chat'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
  }

  String _getSignalStrength(Map<String, dynamic> user) {
    // This could be enhanced with actual BLE signal strength data
    // For now, we'll simulate based on distance
    final distance = _calculateDistance(user['lat'], user['lng']);
    if (distance < 10) return 'Excellent';
    if (distance < 25) return 'Good';
    if (distance < 50) return 'Fair';
    return 'Weak';
  }

  String _formatAudience(String? audience) {
    switch (audience) {
      case 'firstDegree':
        return '1st Degree Connections';
      case 'secondDegree':
        return '2nd Degree Connections';
      case 'custom':
        return 'Custom Groups';
      case 'everyone':
        return 'Everyone in Area';
      default:
        return 'Unknown';
    }
  }

  void _viewUserProfile(Map<String, dynamic> user) {
    // TODO: Implement user profile view
    // This could navigate to a profile page or show a detailed modal
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing profile for User ${user['id']}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(
          label: 'View Full Profile',
          onPressed: () {
            // Navigate to profile page
            context.push('/proxinet/profile');
          },
        ),
      ),
    );
  }

  void _addToContacts(Map<String, dynamic> user) {
    // Use the new contact request system
    _showContactRequestDialog(context, user);
  }

  void _showContactRequestDialog(BuildContext context, Map<String, dynamic> user) {
    final scheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(
          children: [
            Icon(Icons.person_add, color: scheme.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Add to Contacts',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a contact request to ${user['name'] ?? 'this user'}?',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'They will receive a notification and can choose to accept or decline.',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _sendContactRequest(user);
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Request'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
  }

  Future<void> _sendContactRequest(Map<String, dynamic> user) async {
    try {
      final success = await _presenceSync.sendContactRequest(
        user['id'],
        message: 'Would like to connect with you',
        context: 'Found on ProxiNet map',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact request sent to ${user['name'] ?? 'user'}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View Requests',
                onPressed: () {
                  // Navigate to contacts page to see pending requests
                  context.push('/proxinet/contacts');
                },
              ),
            ),
          );
        } else {
          // Check why it failed
          final alreadySent = await _presenceSync.hasContactRequestSent(user['id']);
          final alreadyConnected = await _presenceSync.isAlreadyConnected(user['id']);
          
          String message;
          if (alreadyConnected) {
            message = 'You are already connected to this user';
          } else if (alreadySent) {
            message = 'Contact request already sent to this user';
          } else {
            message = 'Failed to send contact request. Please try again.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending contact request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startChat(Map<String, dynamic> user) {
    // Navigate to messages page with the selected user
    // You can pass user data as query parameters or use a route with parameters
    context.push('/proxinet/messages', extra: {
      'userId': user['id'],
      'userName': user['name'] ?? 'User',
      'userType': user['type'] ?? 'unknown',
    });
  }

  Widget _buildAvailabilityControls(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Status
        Row(
          children: [
            Icon(
              _presenceSync.isAvailableForConnections 
                ? Icons.check_circle 
                : Icons.cancel,
              color: _presenceSync.isAvailableForConnections 
                ? Colors.green 
                : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _presenceSync.isAvailableForConnections 
                ? 'You are available to connect'
                : 'You are not available to connect',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _presenceSync.isAvailableForConnections 
                  ? Colors.green 
                  : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Availability Toggle
        Row(
          children: [
            Expanded(
              child: GradientButton(
                onPressed: () async {
                  if (_presenceSync.isAvailableForConnections) {
                    // Disable availability
                    await _presenceSync.setAvailabilityForConnections(false);
                  } else {
                    // Enable availability with "Everyone" audience
                    await _presenceSync.setAvailabilityForConnections(
                      true,
                      audience: VisibilityAudience.everyone,
                      hours: 2,
                    );
                  }
                  if (mounted) setState(() {});
                },
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                child: Text(
                  _presenceSync.isAvailableForConnections 
                    ? 'Set Unavailable' 
                    : 'Set Available to Everyone',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/proxinet/availability'),
                icon: const Icon(Icons.settings),
                label: const Text('Advanced'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary),
                ),
              ),
            ),
          ],
        ),
        
        if (_presenceSync.isAvailableForConnections) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.visibility,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Visible to ${_formatAudience(_presenceSync.currentAudience?.name)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Debug section
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.errorContainer.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Debug Info',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.errorContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _debugAvailabilityStatus(),
                        icon: const Icon(Icons.bug_report, size: 14),
                        label: const Text('Check Status'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.errorContainer,
                          side: BorderSide(color: scheme.errorContainer),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _refreshAvailabilityLocation(),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Refresh Location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.errorContainer,
                          side: BorderSide(color: scheme.errorContainer),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // BLE Discovery Controls
        Text(
          'Nearby Discovery',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GradientButton(
                onPressed: () async {
                  if (_nearbyEnabled) {
                    await _disableNearbyDiscovery();
                  } else {
                    await _enableNearbyDiscovery();
                  }
                },
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                child: Text(_nearbyEnabled ? 'Disable Discovery' : 'Enable Discovery'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('My Location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary),
                ),
              ),
            ),
          ],
        ),
        
        if (_nearbyEnabled) ...[
          const SizedBox(height: 16),
          Text(
            'Discovery Radius: ${_radiusKm.toStringAsFixed(1)}km',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Slider(
              value: _radiusKm,
              min: 0.1,
              max: 10.0,
              divisions: 99,
              onChanged: (value) {
                setState(() => _radiusKm = value);
              },
              onChangeEnd: (value) async {
                if (_nearbyEnabled) {
                  await _enableNearbyDiscovery(); // Update with new radius
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  void _debugAvailabilityStatus() async {
    final status = await _presenceSync.getAvailabilityStatus();
    final audience = await _presenceSync.getVisibilityAudience();
    final currentAudience = await _presenceSync.getCurrentAudience();
    final isEnabled = await _presenceSync.isAvailableForConnections;

    final message = '''
Availability Status:
- Is Available: $isEnabled
- Current Audience: ${currentAudience?.name ?? 'N/A'}
- Visibility: ${status?['isAvailable'] ?? 'N/A'}
- Expires At: ${status?['until'] ?? 'N/A'}
- Latitude: ${status?['latitude'] ?? 'N/A'}
- Longitude: ${status?['longitude'] ?? 'N/A'}
- Radius: ${status?['radiusKm'] ?? 'N/A'}
''';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _refreshAvailabilityLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    await _presenceSync.setAvailabilityLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location updated for other users'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
