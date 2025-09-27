import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../../core/services/putrace_settings_service.dart';
import '../../../../core/utils/geohash.dart';
import '../../../../core/services/putrace_ble_service.dart';
import '../../../../core/services/putrace_presence_sync_service.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  // State variables
  bool _sharing = false;
  bool _connecting = false; // New state for connection process
  double _radiusKm = 1.0;
  final List<String> _discovered = [];
  double? _lat;
  double? _lng;
  late ColorScheme _colorScheme;

  // Services
  final _settings = GetIt.instance<PutraceSettingsService>();
  final _ble = GetIt.instance<PutraceBleService>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;
  final _presenceSync = GetIt.instance<PutracePresenceSyncService>();

  @override
  void initState() {
    super.initState();
    _initialize();
    
    // Listen to presence changes from other pages
    _presenceSync.addListener(_onPresenceChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = Theme.of(context).colorScheme;
  }

  Future<void> _initialize() async {
    await _loadSettings();
    _setupBleListener();
  }

  Future<void> _loadSettings() async {
    // final km = await _settings.getPrecisionKm(); // Removed unused variable
    await _presenceSync.initializeFromFirestore();
    if (!mounted) return;
    setState(() {
      _radiusKm = _presenceSync.radiusKm;
      _sharing = _presenceSync.isPresenceEnabled;
    });
  }

  void _setupBleListener() {
    _ble.discoveryStream.listen((e) {
      if (!mounted) return;
      if (e.startsWith('TOKEN:')) {
        _resolveToken(e.substring(6));
      } else {
        setState(() => _discovered.insert(0, e));
      }
    });
  }

  void _onPresenceChanged() {
    if (mounted) {
      setState(() {
        _sharing = _presenceSync.isPresenceEnabled;
        _radiusKm = _presenceSync.radiusKm;
      });
    }
  }

  Future<void> _resolveToken(String token) async {
    try {
      final result = await _functions
          .httpsCallable('resolveBleToken')
          .call({'token': token});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['allowed'] == true) {
        final display = data['display'] as String? ?? 'Putrace contact';
        if (mounted) setState(() => _discovered.insert(0, display));
      }
    } catch (e) {
      debugPrint('Token resolution error: $e');
    }
  }

  Future<void> _toggleSharing(bool enable) async {
    // Prevent multiple clicks while connecting
    if (_connecting) return;
    
    if (enable) {
      await _enableSharing();
    } else {
      await _disableSharing();
    }
  }

  Future<void> _enableSharing() async {
    try {
      // Set connecting state to prevent multiple clicks
      if (mounted) {
        setState(() => _connecting = true);
      }

      if (!await _checkPermissions()) return;
      if (!await _checkBluetooth()) return;

      final position = await _getCurrentPosition();
      if (position == null) return;

      _lat = position.latitude;
      _lng = position.longitude;

      await _ble.startEventMode();
      await _presenceSync.enablePresence();
      await _settings.setPresenceEnabled(true);

      if (mounted) {
        setState(() {
          _sharing = true;
          _connecting = false; // Clear connecting state
        });
        _showSnackBar(
          'Nearby discovery enabled successfully!',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false); // Clear connecting state on error
      }
      _handleSharingError(e);
    }
  }

  Future<bool> _checkPermissions() async {
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (!permissions.values.every((status) => status.isGranted)) {
      if (mounted) {
        _showSnackBar(
          'All permissions are required for nearby discovery',
          Colors.orange,
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<bool> _checkBluetooth() async {
    if (!await FlutterBluePlus.isSupported) {
      if (mounted) {
        _showSnackBar(
          'Bluetooth not supported on this device',
          Colors.red,
        );
      }
      return false;
    }

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (mounted) {
        // Show dialog to enable Bluetooth
        final shouldEnable = await _showBluetoothEnableDialog();
        if (shouldEnable) {
          try {
            // Try to enable Bluetooth (this may not work on all devices)
            await FlutterBluePlus.turnOn();
            // Wait a moment for Bluetooth to initialize
            await Future.delayed(const Duration(seconds: 2));
            // Check if it's now on
            if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
              return true;
            }
          } catch (e) {
            debugPrint('Could not enable Bluetooth programmatically: $e');
          }
          
          // If we can't enable it programmatically, show instructions
          if (mounted) {
            _showSnackBar(
              'Please enable Bluetooth in your device settings',
              Colors.orange,
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            );
          }
        }
      }
      return false;
    }
    return true;
  }

  Future<bool> _showBluetoothEnableDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bluetooth, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Enable Bluetooth'),
          ],
        ),
        content: const Text(
          'Bluetooth is required for nearby discovery. Would you like to enable it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.bluetooth),
            label: const Text('Enable'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnackBar(
            'Location permission required for nearby discovery',
            Colors.orange,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Standardized for optimal battery/accuracy balance
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        _showSnackBar(
          'Failed to get location: ${e.toString()}',
          Colors.red,
        );
      }
      return null;
    }
  }

  // Future<void> _updateFirestorePresence(bool enable) async {
  //   final user = _auth.currentUser;
  //   if (user == null) return;

  //   if (enable) {
  //     final lat = _lat ?? 25.276987;
  //     final lng = _lng ?? 55.296249;
  //     final precision = Geohash.precisionForRadiusKm(_radiusKm);
  //     final hash = Geohash.encode(lat, lng, precision: precision);

  //     await _firestore.collection('presence_geo').doc(user.uid).set({
  //       'geohash': hash,
  //       'lat': lat,
  //       'lng': lng,
  //       'precisionM': (_radiusKm * 1000).toInt(),
  //       'updatedAt': FieldValue.serverTimestamp(),
  //       'expireAt': Timestamp.fromDate(
  //         DateTime.now().toUtc().add(const Duration(minutes: 15)),
  //       ),
  //       'userId': user.uid,
  //     }, SetOptions(merge: true));
  //   } else {
  //     await _firestore.collection('presence_geo').doc(user.uid).delete();
  //   }
  // }

  Future<void> _disableSharing() async {
    try {
      // Set connecting state to prevent multiple clicks
      if (mounted) {
        setState(() => _connecting = true);
      }

      await _ble.stopEventMode();
      await _presenceSync.disablePresence();
      await _settings.setPresenceEnabled(false);

      if (mounted) {
        setState(() {
          _sharing = false;
          _connecting = false; // Clear connecting state
        });
        _showSnackBar(
          'Nearby discovery disabled',
          Colors.blue,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false); // Clear connecting state on error
      }
      debugPrint('Disable sharing error: $e');
      if (mounted) {
        _showSnackBar(
          'Error disabling nearby discovery: ${e.toString()}',
          Colors.red,
        );
      }
    }
  }

  void _handleSharingError(dynamic e) {
    debugPrint('Sharing error: $e');
    if (!mounted) return;

    String errorMessage = 'Failed to enable nearby discovery';
    if (e.toString().contains('timeout')) {
      errorMessage = 'Location request timed out. Please try again.';
    } else if (e.toString().contains('bluetooth')) {
      errorMessage = 'Bluetooth error. Please check Bluetooth settings.';
    } else if (e.toString().contains('location')) {
      errorMessage = 'Location error. Please check location settings.';
    }

    _showSnackBar(
      errorMessage,
      Colors.red,
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => _toggleSharing(true),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor,
      {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
        action: action,
      ),
    );
  }

  @override
  void dispose() {
    _presenceSync.removeListener(_onPresenceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _buildFirestoreQuery();

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(query),
    );
  }

  Query _buildFirestoreQuery() {
    final lat = _lat ?? 25.276987;
    final lng = _lng ?? 55.296249;
    final precision = Geohash.precisionForRadiusKm(_radiusKm);
    final prefix = Geohash.encode(lat, lng, precision: precision);

    return _firestore
        .collection('presence_geo')
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThanOrEqualTo: Geohash.prefixRangeEnd(prefix))
        .where('expireAt', isGreaterThan: Timestamp.now());
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.network_check, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'Putrace',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _colorScheme.onSurface,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            context.go('/putrace');
          }
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.bluetooth_searching),
          onPressed: () => context.push('/putrace/ble-diagnostic'),
          tooltip: 'BLE Diagnostic',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(Query query) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSharingToggle(),
        _buildRadiusSlider(),
        const SizedBox(height: 16),
        _buildNearbyList(query),
      ],
    );
  }

  Widget _buildSharingToggle() {
    return SwitchListTile(
      title: Row(
        children: [
          const Text('Share Nearby'),
          if (_connecting) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_colorScheme.primary),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        _connecting 
          ? 'Connecting...' 
          : 'Enable mutual discovery within a radius'
      ),
      value: _sharing,
      onChanged: _connecting ? null : _toggleSharing, // Disable while connecting
    );
  }

  Widget _buildRadiusSlider() {
    return ListTile(
      title: const Text('Radius'),
      subtitle: Text('${_radiusKm.toStringAsFixed(1)} km'),
              trailing: SizedBox(
          width: 220,
          child: Slider(
            value: _radiusKm,
            min: 0.1,
            max: 10,
            divisions: 99,
            onChanged: (v) => setState(() => _radiusKm = v),
            onChangeEnd: (v) async {
              await _settings.setPrecisionKm(v);
              if (_sharing) {
                await _presenceSync.updateRadius(v);
              }
            },
          ),
        ),
    );
  }

  Widget _buildNearbyList(Query query) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildEmptyState('Loading nearby devices...');
        }

        final items = [
          ...snapshot.data!.docs.map((d) => 'Presence: ${d.id}'),
          ..._discovered,
        ];

        return items.isEmpty
            ? _buildEmptyState('No nearby signals yet. Try enabling sharing.')
            : Column(
                children: items.map(_buildDiscoveryItem).toList(),
              );
      },
    );
  }

  Widget _buildDiscoveryItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(message),
    );
  }
}
