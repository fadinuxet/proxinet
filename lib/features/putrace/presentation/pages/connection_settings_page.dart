import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/user_tier_service.dart';
import '../../../../core/models/user_tier.dart';
import '../../../../core/services/ble_state_service.dart';
import '../widgets/ble_disable_warning_dialog.dart';

class ConnectionSettingsPage extends StatefulWidget {
  const ConnectionSettingsPage({super.key});

  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  // User Tier Service
  final UserTierService _userTierService = UserTierService();
  UserTier _currentTier = UserTier.anonymous;
  
  // BLE State Service
  final BLEStateService _bleStateService = BLEStateService();
  bool _bleEnabled = true;
  
  // Nearby Mode Settings
  bool _nearbyEnabled = true;
  int _nearbyRange = 50; // meters
  int _nearbyTimeout = 30; // minutes
  bool _nearbyAutoDisconnect = true;
  
  // Location Mode Settings
  bool _locationEnabled = false;
  int _locationRange = 1000; // meters
  int _locationTimeout = 60; // minutes
  bool _locationAutoDisconnect = true;
  String _locationPrecision = 'venue'; // exact, block, venue, city
  
  // Virtual Mode Settings
  bool _virtualEnabled = false;
  int _virtualTimeout = 120; // minutes
  bool _virtualAutoDisconnect = true;
  String _virtualAvailability = 'now'; // now, scheduled, always

  @override
  void initState() {
    super.initState();
    _initializeUserTier();
    _initializeBLEState();
  }

  Future<void> _initializeUserTier() async {
    await _userTierService.initialize();
    _userTierService.tierStream.listen((tier) {
      if (mounted) {
        setState(() {
          _currentTier = tier;
        });
      }
    });
  }

  Future<void> _initializeBLEState() async {
    // Initialize with current BLE state
    _bleEnabled = _bleStateService.isBLEEnabled;
    _nearbyEnabled = _bleStateService.isBLEEnabled;
    
    // Listen to BLE state changes
    _bleStateService.bleEnabledStream.listen((enabled) {
      if (mounted) {
        setState(() {
          _bleEnabled = enabled;
          _nearbyEnabled = enabled;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Connection Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNearbySettings(),
          const SizedBox(height: 24),
          _buildLocationSettings(),
          const SizedBox(height: 24),
          _buildVirtualSettings(),
          const SizedBox(height: 24),
          _buildGlobalSettings(),
        ],
      ),
    );
  }

  Widget _buildNearbySettings() {
    return _buildSettingsCard(
      title: 'Nearby Mode (BLE)',
      icon: Icons.radar,
      color: Colors.blue,
      children: [
        _buildSwitchTile(
          title: 'Enable BLE for Nearby',
          subtitle: 'Use Bluetooth to find professionals nearby',
          value: _bleEnabled,
          onChanged: _handleBLEEnablement,
        ),
        if (_bleEnabled) ...[
          const Divider(),
          _buildSliderTile(
            title: 'Discovery Range',
            subtitle: '$_nearbyRange m radius',
            value: _nearbyRange.toDouble(),
            min: 10,
            max: 200,
            divisions: 19,
            onChanged: (value) => setState(() => _nearbyRange = value.round()),
          ),
          _buildSliderTile(
            title: 'Auto-Disconnect Timer',
            subtitle: '$_nearbyTimeout minutes',
            value: _nearbyTimeout.toDouble(),
            min: 5,
            max: 180,
            divisions: 35,
            onChanged: (value) => setState(() => _nearbyTimeout = value.round()),
          ),
          _buildSwitchTile(
            title: 'Auto-Disconnect',
            subtitle: 'Automatically disconnect after timer expires',
            value: _nearbyAutoDisconnect,
            onChanged: (value) => setState(() => _nearbyAutoDisconnect = value),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationSettings() {
    final isLocationModeLocked = _currentTier.isAnonymous;
    
    return _buildSettingsCard(
      title: 'Location Mode (GPS)',
      icon: Icons.location_on,
      color: Colors.orange,
      children: [
        _buildSwitchTile(
          title: 'Enable Location Sharing',
          subtitle: isLocationModeLocked 
              ? 'Sign up to discover professionals in your area'
              : 'Share your location for venue-based networking',
          value: _locationEnabled,
          onChanged: isLocationModeLocked 
              ? null 
              : (value) => setState(() => _locationEnabled = value),
        ),
        if (_locationEnabled) ...[
          const Divider(),
          _buildSliderTile(
            title: 'Location Range',
            subtitle: '$_locationRange m radius',
            value: _locationRange.toDouble(),
            min: 100,
            max: 5000,
            divisions: 49,
            onChanged: (value) => setState(() => _locationRange = value.round()),
          ),
          _buildSliderTile(
            title: 'Auto-Disconnect Timer',
            subtitle: '$_locationTimeout minutes',
            value: _locationTimeout.toDouble(),
            min: 10,
            max: 480,
            divisions: 47,
            onChanged: (value) => setState(() => _locationTimeout = value.round()),
          ),
          _buildDropdownTile(
            title: 'Location Precision',
            subtitle: _getLocationPrecisionDescription(_locationPrecision),
            value: _locationPrecision,
            items: const [
              {'value': 'exact', 'label': 'Exact Location'},
              {'value': 'block', 'label': 'City Block'},
              {'value': 'venue', 'label': 'Venue Level'},
              {'value': 'city', 'label': 'City Level'},
            ],
            onChanged: (value) => setState(() => _locationPrecision = value!),
          ),
          _buildSwitchTile(
            title: 'Auto-Disconnect',
            subtitle: 'Automatically disconnect after timer expires',
            value: _locationAutoDisconnect,
            onChanged: (value) => setState(() => _locationAutoDisconnect = value),
          ),
        ],
      ],
    );
  }

  Widget _buildVirtualSettings() {
    final isVirtualModeLocked = _currentTier.isAnonymous || _currentTier.isStandard;
    
    return _buildSettingsCard(
      title: 'Virtual Mode (Online)',
      icon: Icons.cloud,
      color: Colors.purple,
      children: [
        _buildSwitchTile(
          title: 'Enable Virtual Networking',
          subtitle: isVirtualModeLocked 
              ? 'Upgrade to Premium to be discoverable 24/7'
              : 'Connect with professionals worldwide online',
          value: _virtualEnabled,
          onChanged: isVirtualModeLocked 
              ? null 
              : (value) => setState(() => _virtualEnabled = value),
        ),
        if (_virtualEnabled) ...[
          const Divider(),
          _buildSliderTile(
            title: 'Auto-Disconnect Timer',
            subtitle: '$_virtualTimeout minutes',
            value: _virtualTimeout.toDouble(),
            min: 15,
            max: 720,
            divisions: 47,
            onChanged: (value) => setState(() => _virtualTimeout = value.round()),
          ),
          _buildDropdownTile(
            title: 'Availability Type',
            subtitle: _getVirtualAvailabilityDescription(_virtualAvailability),
            value: _virtualAvailability,
            items: const [
              {'value': 'now', 'label': 'Available Now'},
              {'value': 'scheduled', 'label': 'Scheduled Times'},
              {'value': 'always', 'label': 'Always Available'},
            ],
            onChanged: (value) => setState(() => _virtualAvailability = value!),
          ),
          _buildSwitchTile(
            title: 'Auto-Disconnect',
            subtitle: 'Automatically disconnect after timer expires',
            value: _virtualAutoDisconnect,
            onChanged: (value) => setState(() => _virtualAutoDisconnect = value),
          ),
        ],
      ],
    );
  }

  Widget _buildGlobalSettings() {
    return _buildSettingsCard(
      title: 'Global Settings',
      icon: Icons.settings,
      color: Colors.grey,
      children: [
        _buildInfoTile(
          title: 'Connection Status',
          subtitle: 'Monitor your active connections',
          icon: Icons.network_check,
          onTap: () => _showConnectionStatus(),
        ),
        _buildInfoTile(
          title: 'Privacy Settings',
          subtitle: 'Control what information you share',
          icon: Icons.privacy_tip,
          onTap: () => _showPrivacySettings(),
        ),
        _buildInfoTile(
          title: 'Battery Optimization',
          subtitle: 'Optimize battery usage for networking',
          icon: Icons.battery_charging_full,
          onTap: () => _showBatterySettings(),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final isDisabled = onChanged == null;
    
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: isDisabled ? Colors.grey : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          color: isDisabled ? Colors.grey[500] : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      secondary: isDisabled 
          ? Icon(Icons.lock, color: Colors.grey, size: 20)
          : null,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: subtitle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item['value'],
              child: Text(item['label']!),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getLocationPrecisionDescription(String precision) {
    switch (precision) {
      case 'exact':
        return 'Share exact coordinates (most precise)';
      case 'block':
        return 'Share city block level (moderate privacy)';
      case 'venue':
        return 'Share venue level (recommended)';
      case 'city':
        return 'Share city level (most private)';
      default:
        return 'Share venue level (recommended)';
    }
  }

  String _getVirtualAvailabilityDescription(String availability) {
    switch (availability) {
      case 'now':
        return 'Available for immediate connections';
      case 'scheduled':
        return 'Available during scheduled times';
      case 'always':
        return 'Always available for connections';
      default:
        return 'Available for immediate connections';
    }
  }

  void _showConnectionStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connection Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusRow('Nearby Mode', _nearbyEnabled ? 'Active' : 'Inactive', Colors.blue),
            _buildStatusRow('Location Mode', _locationEnabled ? 'Active' : 'Inactive', Colors.orange),
            _buildStatusRow('Virtual Mode', _virtualEnabled ? 'Active' : 'Inactive', Colors.purple),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String mode, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(mode, style: GoogleFonts.inter()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Active' ? color : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy settings coming soon!')),
    );
  }

  void _showBatterySettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Battery optimization coming soon!')),
    );
  }

  void _handleBLEEnablement(bool value) {
    if (value) {
      // Enable BLE
      _bleStateService.enableBLE();
    } else {
      // Show warning dialog before disabling BLE
      showDialog(
        context: context,
        builder: (context) => BLEDisableWarningDialog(
          onConfirm: () {
            _bleStateService.disableBLE();
          },
          onCancel: () {
            // Keep BLE enabled
          },
        ),
      );
    }
  }
}
