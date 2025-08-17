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
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(Icons.person_add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'Available User',
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
              _connectToAvailableUser(user);
            },
            icon: const Icon(Icons.connect_without_contact),
            label: const Text('Connect'),
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
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final userId = doc.id;
          
          // Get user profile to get location and other details
          final userProfile = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userProfile.exists) {
            final profileData = userProfile.data()!;
            final lat = profileData['latitude'] as double?;
            final lng = profileData['longitude'] as double?;
            
            if (lat != null && lng != null) {
              availableUsers.add({
                'id': userId,
                'lat': lat,
                'lng': lng,
                'name': profileData['displayName'] ?? 'Available User',
                'type': 'available', // Distinguish from nearby users
                'audience': data['audience'] ?? 'firstDegree',
                'until': data['until'],
              });
            }
          }
        } catch (e) {
          print('Error loading available user: $e');
        }
      }
      
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
                ..._nearbyUsers.map((user) => Marker(
                      point: LatLng(user['lat'], user['lng']),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 16,
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.person_add, color: Colors.white, size: 16),
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
                      child: Text(
                        'Available users to connect',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // No slider or button for available users as they are static
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
                ..._nearbyUsers.map((user) => Marker(
                      point: LatLng(user['lat'], user['lng']),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    )),
                // Available users markers
                ..._availableUsers.map((user) => Marker(
                      point: LatLng(user['lat'], user['lng']),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.person_add, color: Colors.white, size: 16),
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
}
