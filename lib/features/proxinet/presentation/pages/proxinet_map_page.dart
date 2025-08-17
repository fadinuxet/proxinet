import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/ui/proxinet_design.dart';
import '../../../../core/utils/geohash.dart';
import 'package:google_fonts/google_fonts.dart';

class ProxinetMapPage extends StatefulWidget {
  const ProxinetMapPage({super.key});

  @override
  State<ProxinetMapPage> createState() => _ProxinetMapPageState();
}

class _ProxinetMapPageState extends State<ProxinetMapPage> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(25.276987, 55.296249); // Dubai default
  bool _nearbyEnabled = false;
  double _radiusKm = 1.0;
  List<Map<String, dynamic>> _nearbyUsers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadNearbyStatus();
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('presence_geo')
            .doc(uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final expireAt = data['expireAt'] as Timestamp?;
          if (expireAt != null && expireAt.toDate().isAfter(DateTime.now())) {
            setState(() {
              _nearbyEnabled = true;
              _radiusKm = (data['precisionM'] ?? 1000) / 1000.0;
            });
          }
        }
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

      // Write to Firestore with better error handling
      try {
        await FirebaseFirestore.instance
            .collection('presence_geo')
            .doc(uid)
            .set({
          'geohash': hash,
          'lat': position.latitude,
          'lng': position.longitude,
          'precisionM': (_radiusKm * 1000).toInt(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expireAt': Timestamp.fromDate(expireAt),
          'userId': uid, // Add user ID for security rules
        });

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
      } catch (firestoreError) {
        print('Firestore error: $firestoreError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Database error: $firestoreError'),
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('presence_geo')
            .doc(uid)
            .delete();

        setState(() {
          _nearbyEnabled = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nearby discovery disabled')),
        );
      }
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
      ),
      body: Stack(
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
      ),
    );
  }
}
