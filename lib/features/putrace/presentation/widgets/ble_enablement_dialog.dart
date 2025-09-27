import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../../core/services/ble_state_service.dart';

class BLEEnablementDialog extends StatefulWidget {
  final VoidCallback onBLEEnabled;
  final VoidCallback onCancel;

  const BLEEnablementDialog({
    super.key,
    required this.onBLEEnabled,
    required this.onCancel,
  });

  @override
  State<BLEEnablementDialog> createState() => _BLEEnablementDialogState();
}

class _BLEEnablementDialogState extends State<BLEEnablementDialog> {
  bool _bleEnabled = false;
  bool _permissionsGranted = false;
  bool _isChecking = true;
  bool _userConsent = false;
  String _statusMessage = 'Checking BLE status...';
  
  // Settings
  bool _autoDisconnect = true;
  int _discoveryRange = 50; // meters
  int _autoDisconnectTimer = 30; // minutes

  @override
  void initState() {
    super.initState();
    _checkBLEStatus();
    
    // Listen to Bluetooth adapter state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        final isEnabled = state == BluetoothAdapterState.on;
        if (_bleEnabled != isEnabled) {
          setState(() {
            _bleEnabled = isEnabled;
            if (isEnabled && _permissionsGranted && _userConsent) {
              _statusMessage = 'BLE is ready for Nearby discovery';
              _proceedWithBLE();
            } else if (!isEnabled) {
              _statusMessage = 'Bluetooth disabled';
            }
          });
        }
      }
    });
  }

  Future<void> _checkBLEStatus() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking BLE status...';
    });

    try {
      // Check if BLE is supported
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        setState(() {
          _statusMessage = 'Bluetooth is not supported on this device';
          _isChecking = false;
        });
        return;
      }

      // Check if BLE is enabled - use stream to get real-time state
      final adapterState = await FlutterBluePlus.adapterState.first;
      final isEnabled = adapterState == BluetoothAdapterState.on;
      
      debugPrint('BLE Status Check:');
      debugPrint('  Supported: $isSupported');
      debugPrint('  Adapter State: $adapterState');
      debugPrint('  Enabled: $isEnabled');
      
      // Check permissions
      final bluetoothScan = await Permission.bluetoothScan.status;
      final bluetoothAdvertise = await Permission.bluetoothAdvertise.status;
      final bluetoothConnect = await Permission.bluetoothConnect.status;
      final locationWhenInUse = await Permission.locationWhenInUse.status;
      
      final permissionsOk = bluetoothScan.isGranted &&
          bluetoothAdvertise.isGranted &&
          bluetoothConnect.isGranted &&
          locationWhenInUse.isGranted;
      
      debugPrint('BLE Permissions:');
      debugPrint('  Bluetooth Scan: ${bluetoothScan.isGranted}');
      debugPrint('  Bluetooth Advertise: ${bluetoothAdvertise.isGranted}');
      debugPrint('  Bluetooth Connect: ${bluetoothConnect.isGranted}');
      debugPrint('  Location When In Use: ${locationWhenInUse.isGranted}');
      debugPrint('  All Permissions OK: $permissionsOk');

      setState(() {
        _bleEnabled = isEnabled;
        _permissionsGranted = permissionsOk;
        _isChecking = false;
        
        if (isEnabled && permissionsOk) {
          _statusMessage = 'BLE is ready for Nearby discovery';
          // Auto-proceed if everything is ready and user has consented
          if (_userConsent) {
            _proceedWithBLE();
          }
        } else if (!isEnabled) {
          _statusMessage = 'Bluetooth is disabled';
        } else if (!permissionsOk) {
          _statusMessage = 'BLE permissions are required for Nearby discovery';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking BLE status: $e';
        _isChecking = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Requesting BLE permissions...';
    });

    try {
      debugPrint('=== Requesting BLE permissions ===');
      
      // Request permissions one by one to show platform-specific dialogs
      debugPrint('Requesting bluetoothScan permission...');
      final bluetoothScan = await Permission.bluetoothScan.request();
      debugPrint('bluetoothScan result: ${bluetoothScan.isGranted}');
      
      debugPrint('Requesting bluetoothAdvertise permission...');
      final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
      debugPrint('bluetoothAdvertise result: ${bluetoothAdvertise.isGranted}');
      
      debugPrint('Requesting bluetoothConnect permission...');
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      debugPrint('bluetoothConnect result: ${bluetoothConnect.isGranted}');
      
      debugPrint('Requesting locationWhenInUse permission...');
      final locationWhenInUse = await Permission.locationWhenInUse.request();
      debugPrint('locationWhenInUse result: ${locationWhenInUse.isGranted}');

      final allGranted = bluetoothScan.isGranted &&
          bluetoothAdvertise.isGranted &&
          bluetoothConnect.isGranted &&
          locationWhenInUse.isGranted;
      
      debugPrint('All permissions granted: $allGranted');
      
      setState(() {
        _permissionsGranted = allGranted;
        _isChecking = false;
        _statusMessage = allGranted 
            ? 'BLE permissions granted'
            : 'Some BLE permissions were denied';
      });
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      setState(() {
        _statusMessage = 'Error requesting permissions: $e';
        _isChecking = false;
      });
    }
  }

  Future<void> _enableBluetooth() async {
    try {
      debugPrint('Attempting to enable Bluetooth...');
      
      // Try to enable Bluetooth (this may not work on all devices)
      debugPrint('Calling FlutterBluePlus.turnOn()...');
      await FlutterBluePlus.turnOn();
      debugPrint('FlutterBluePlus.turnOn() completed');
      
      // Wait a moment for Bluetooth to initialize
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if Bluetooth is actually enabled
      final adapterState = await FlutterBluePlus.adapterState.first;
      final isEnabled = adapterState == BluetoothAdapterState.on;
      
      debugPrint('Bluetooth adapter state after turnOn: $adapterState');
      debugPrint('Bluetooth is enabled: $isEnabled');
      
      // Update the toggle state
      setState(() {
        _bleEnabled = isEnabled;
        _isChecking = false;
        if (isEnabled) {
          _statusMessage = 'Bluetooth enabled successfully';
          // Auto-proceed if everything is ready and user has consented
          if (_userConsent) {
            _proceedWithBLE();
          }
        } else {
          _statusMessage = 'Bluetooth could not be enabled programmatically';
        }
      });
    } catch (e) {
      debugPrint('Error enabling Bluetooth: $e');
      setState(() {
        _statusMessage = 'Please enable Bluetooth manually in device settings';
        _bleEnabled = false;
        _isChecking = false;
      });
    }
  }

  void _proceedWithBLE() {
    if (_bleEnabled && _permissionsGranted && _userConsent) {
      HapticFeedback.lightImpact();
      
      debugPrint('Proceeding with BLE - all conditions met');
      
      // Enable BLE in the global state service
      final bleStateService = BLEStateService();
      bleStateService.enableBLE();
      
      Navigator.of(context).pop();
      widget.onBLEEnabled();
    } else {
      debugPrint('Cannot proceed with BLE:');
      debugPrint('  BLE Enabled: $_bleEnabled');
      debugPrint('  Permissions Granted: $_permissionsGranted');
      debugPrint('  User Consent: $_userConsent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.bluetooth, color: colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enable BLE for Nearby',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _bleEnabled && _permissionsGranted 
                      ? Colors.green 
                      : Colors.orange,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _bleEnabled && _permissionsGranted 
                            ? Icons.check_circle 
                            : Icons.warning,
                        color: _bleEnabled && _permissionsGranted 
                            ? Colors.green 
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BLE Status',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isChecking)
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusMessage,
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _statusMessage,
                      style: GoogleFonts.inter(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // User Consent Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Privacy & Consent',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'By enabling BLE for Nearby discovery, you agree to:',
                    style: GoogleFonts.inter(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildConsentPoint('Share your anonymous profile (role, company) with nearby professionals'),
                  _buildConsentPoint('Allow other devices to discover you via Bluetooth'),
                  _buildConsentPoint('Use location services for BLE scanning (required by Android)'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _userConsent,
                        onChanged: (value) {
                          setState(() {
                            _userConsent = value ?? false;
                          });
                        },
                        activeColor: colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          'I understand and agree to enable BLE for Nearby discovery',
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // BLE Enable Toggle
            SwitchListTile(
              title: Text(
                'Enable Bluetooth',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Required for Nearby discovery via BLE',
                style: GoogleFonts.inter(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              value: _bleEnabled,
              onChanged: _userConsent ? (value) async {
                if (value && !_bleEnabled) {
                  // User wants to enable Bluetooth - request permissions first
                  debugPrint('=== User toggled Bluetooth ON - requesting permissions ===');
                  
                  // Request permissions first
                  await _requestPermissions();
                  
                  // Check if permissions were granted
                  if (!_permissionsGranted) {
                    setState(() {
                      _statusMessage = 'BLE permissions are required. Please grant all permissions.';
                      _bleEnabled = false;
                    });
                    return;
                  }
                  
                  // Now try to enable Bluetooth
                  await _enableBluetooth();
                } else if (!value && _bleEnabled) {
                  // User wants to disable Bluetooth
                  debugPrint('=== User toggled Bluetooth OFF ===');
                  try {
                    await FlutterBluePlus.turnOff();
                    setState(() {
                      _bleEnabled = false;
                      _statusMessage = 'Bluetooth disabled';
                    });
                  } catch (e) {
                    debugPrint('Error disabling Bluetooth: $e');
                  }
                }
              } : null,
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            
            
            // Permissions Button - Always show to ensure permissions are requested
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    debugPrint('=== Manual permission request button pressed ===');
                    await _requestPermissions();
                    // After requesting permissions, try to enable Bluetooth
                    if (_permissionsGranted) {
                      await _enableBluetooth();
                    }
                  },
                  icon: const Icon(Icons.security),
                  label: Text(
                    _permissionsGranted ? 'Re-request BLE Permissions' : 'Grant BLE Permissions',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Settings Section (only show if BLE is ready)
            if (_bleEnabled && _permissionsGranted) ...[
              Text(
                'Nearby Settings',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              
              // Discovery Range
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discovery Range',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$_discoveryRange m',
                          style: GoogleFonts.inter(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _discoveryRange.toDouble(),
                      min: 10,
                      max: 200,
                      divisions: 19,
                      onChanged: (value) {
                        setState(() {
                          _discoveryRange = value.round();
                        });
                      },
                      activeColor: colorScheme.primary,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Auto Disconnect Settings
              SwitchListTile(
                title: Text(
                  'Auto-Disconnect',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Automatically stop discovery after timer expires',
                  style: GoogleFonts.inter(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                value: _autoDisconnect,
                onChanged: (value) {
                  setState(() {
                    _autoDisconnect = value;
                  });
                },
                activeColor: colorScheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              
              if (_autoDisconnect) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Auto-Disconnect Timer',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '$_autoDisconnectTimer min',
                            style: GoogleFonts.inter(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _autoDisconnectTimer.toDouble(),
                        min: 5,
                        max: 180,
                        divisions: 35,
                        onChanged: (value) {
                          setState(() {
                            _autoDisconnectTimer = value.round();
                          });
                        },
                        activeColor: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onCancel();
          },
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: colorScheme.onSurface),
          ),
        ),
        ElevatedButton(
          onPressed: (_bleEnabled && _permissionsGranted && _userConsent) ? _proceedWithBLE : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Enable Nearby',
            style: GoogleFonts.inter(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentPoint(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
