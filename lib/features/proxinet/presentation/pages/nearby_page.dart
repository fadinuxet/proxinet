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
import '../../../../core/services/proxinet_settings_service.dart';
import '../../../../core/utils/geohash.dart';
import '../../../../core/services/proxinet_ble_service.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  // State variables
  bool _sharing = false;
  double _radiusKm = 1.0;
  final List<String> _discovered = [];
  double? _lat;
  double? _lng;
  late ColorScheme _colorScheme;

  // Services
  final _settings = GetIt.instance<ProxinetSettingsService>();
  final _ble = GetIt.instance<ProxinetBleService>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;

  @override
  void initState() {
    super.initState();
    _colorScheme = Theme.of(context).colorScheme;
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSettings();
    _setupBleListener();
  }

  Future<void> _loadSettings() async {
    final km = await _settings.getPrecisionKm();
    final sharingEnabled = await _settings.isPresenceEnabled();
    if (!mounted) return;
    setState(() {
      _radiusKm = km.clamp(0.5, 10.0);
      _sharing = sharingEnabled;
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

  Future<void> _resolveToken(String token) async {
    try {
      final result = await _functions
          .httpsCallable('resolveBleToken')
          .call({'token': token});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['allowed'] == true) {
        final display = data['display'] as String? ?? 'Proxinet contact';
        if (mounted) setState(() => _discovered.insert(0, display));
      }
    } catch (e) {
      debugPrint('Token resolution error: $e');
    }
  }

  Future<void> _toggleSharing(bool enable) async {
    if (enable) {
      await _enableSharing();
    } else {
      await _disableSharing();
    }
  }

  Future<void> _enableSharing() async {
    try {
      if (!await _checkPermissions()) return;
      if (!await _checkBluetooth()) return;

      final position = await _getCurrentPosition();
      if (position == null) return;

      _lat = position.latitude;
      _lng = position.longitude;

      await _ble.startEventMode();
      await _updateFirestorePresence(true);
      await _settings.setPresenceEnabled(true);

      if (mounted) {
        setState(() => _sharing = true);
        _showSnackBar(
          'Nearby discovery enabled successfully!',
          Colors.green,
        );
      }
    } catch (e) {
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

    if (!await FlutterBluePlus.isOn) {
      if (mounted) {
        _showSnackBar(
          'Please turn on Bluetooth',
          Colors.orange,
        );
      }
      return false;
    }
    return true;
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
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
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

  Future<void> _updateFirestorePresence(bool enable) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (enable) {
      final lat = _lat ?? 25.276987;
      final lng = _lng ?? 55.296249;
      final precision = Geohash.precisionForRadiusKm(_radiusKm);
      final hash = Geohash.encode(lat, lng, precision: precision);

      await _firestore.collection('presence_geo').doc(user.uid).set({
        'geohash': hash,
        'lat': lat,
        'lng': lng,
        'precisionM': (_radiusKm * 1000).toInt(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(
          DateTime.now().toUtc().add(const Duration(minutes: 15)),
        ),
        'userId': user.uid,
      }, SetOptions(merge: true));
    } else {
      await _firestore.collection('presence_geo').doc(user.uid).delete();
    }
  }

  Future<void> _disableSharing() async {
    try {
      await _ble.stopEventMode();
      await _updateFirestorePresence(false);
      await _settings.setPresenceEnabled(false);

      if (mounted) {
        setState(() => _sharing = false);
        _showSnackBar(
          'Nearby discovery disabled',
          Colors.blue,
        );
      }
    } catch (e) {
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
            'ProxiNet',
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
        onPressed: () => Navigator.maybePop(context) ?? context.go('/proxinet'),
      ),
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
      title: const Text('Share Nearby'),
      subtitle: const Text('Enable mutual discovery within a radius'),
      value: _sharing,
      onChanged: _toggleSharing,
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
          onChangeEnd: (v) => _settings.setPrecisionKm(v),
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
          color: _colorScheme.outlineVariant.withOpacity(0.3),
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
          color: _colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Text(message),
    );
  }
}
