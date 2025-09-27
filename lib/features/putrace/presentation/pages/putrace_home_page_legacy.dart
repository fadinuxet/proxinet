import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/professional_auth_service.dart';
import '../../../../core/services/secure_messaging_service.dart';
import '../../../../core/services/ble_conference_mode_service.dart';
import '../../../../core/models/user_profile.dart';
import '../../../messaging/presentation/pages/messages_page.dart';
import '../../../admin/presentation/pages/simple_monitoring_dashboard.dart';
import '../widgets/privacy_first_widgets.dart';
import '../../data/services/osm_venue_service.dart';
import 'privacy_demo_page.dart';
import 'virtual_world_page.dart';
import 'simple_osm_page.dart';
import 'connection_settings_page.dart';
import 'nearby_users_list_page.dart';
import '../../data/services/ble_discovery_service.dart';
import '../../data/services/user_discovery_service.dart';

// Three-mode availability system
enum AvailabilityMode {
  nearby,    // BLE proximity mode (immediate, here now)
  location,  // GPS/map-based (planned, future locations)
  virtual,   // Online availability (global, no location)
}

// Enhanced Multi-Mode Availability System
class HybridAvailability {
  final Set<AvailabilityMode> activeModes;
  final AvailabilityMode primaryMode;
  final Map<AvailabilityMode, ModeSettings> settings;
  final bool isAvailable;
  
  const HybridAvailability({
    required this.activeModes,
    required this.primaryMode,
    required this.settings,
    this.isAvailable = true,
  });
  
  // Helper methods
  bool isActiveIn(AvailabilityMode mode) => activeModes.contains(mode);
  String getStatusText() => isAvailable ? 'DISCOVERABLE' : 'BUSY';
  String getContextText() => '${activeModes.length} modes active';

  // Added copyWith for immutability
  HybridAvailability copyWith({
    Set<AvailabilityMode>? activeModes,
    AvailabilityMode? primaryMode,
    Map<AvailabilityMode, ModeSettings>? settings,
    bool? isAvailable,
  }) {
    return HybridAvailability(
      activeModes: activeModes ?? this.activeModes,
      primaryMode: primaryMode ?? this.primaryMode,
      settings: settings ?? this.settings,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

// Mode-specific settings
class ModeSettings {
  final PrivacyLevel privacy;
  final int radius;
  final bool notifications;
  
  const ModeSettings({
    required this.privacy,
    required this.radius,
    this.notifications = true,
  });
}

enum PrivacyLevel {
  public,           // Anyone can see
  connections,      // Only your network
  colleagues,       // Work connections only
  eventAttendees,   // Event-specific
  private,          // Hidden
}

class PutraceHomePage extends StatefulWidget {
  const PutraceHomePage({super.key});

  @override
  State<PutraceHomePage> createState() => _PutraceHomePageState();
}

class _PutraceHomePageState extends State<PutraceHomePage> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  late final NotificationService _notificationService;
  late final ColorScheme _colorScheme;
  
  // Privacy-First Services
  late final ProfessionalAuthService _professionalAuth;
  late final SecureMessagingService _secureMessaging;
  late final BLEConferenceModeService _conferenceMode;
  
  // Privacy state
  ProfessionalIdentity? _professionalIdentity;
  bool _isConferenceModeActive = false;
  int _discoveredProfessionals = 0;
  
  // Location mode state
  OSMVenue? _selectedLocationVenue; // Currently selected venue for location mode
  String _venueCustomMessage = ''; // Custom message for the selected venue
  Map<String, String> _venueMessages = {}; // Store custom messages by venue ID
  Map<String, DateTime?> _venueScheduledTimes = {}; // Store scheduled times by venue ID
  
  // HYBRID AVAILABILITY STATE
  late HybridAvailability _hybridAvailability;
  
  // Animation controllers for pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Legacy state for backward compatibility
  AvailabilityMode _currentMode = AvailabilityMode.nearby;
  bool _isAvailable = false; // Start as offline until modes are activated
  int _nearbyCount = 3;
  
  // Real networking services
  final BLEDiscoveryService _bleService = BLEDiscoveryService();
  final UserDiscoveryService _userDiscoveryService = UserDiscoveryService();
  List<NearbyUser> _nearbyUsers = [];
  List<BLEDevice> _bleDevices = [];

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _initializeNotifications();
    _initializePrivacyServices();
    _initializeHybridAvailability();
    _initializeAnimations();
    _initializeRealNetworkingServices();
  }
  
  void _initializePrivacyServices() {
    // Initialize privacy-first services
    _professionalAuth = GetIt.instance<ProfessionalAuthService>();
    _secureMessaging = GetIt.instance<SecureMessagingService>();
    _conferenceMode = GetIt.instance<BLEConferenceModeService>();
    
    // Load professional identity
    _loadProfessionalIdentity();
    
    // Listen to conference mode changes
    _conferenceMode.discoveryStream.listen((message) {
      if (mounted) {
        setState(() {
          _isConferenceModeActive = _conferenceMode.isConferenceModeActive;
        });
      }
    });
  }
  
  Future<void> _loadProfessionalIdentity() async {
    try {
      final identity = await _professionalAuth.getProfessionalIdentity();
      if (mounted) {
        setState(() {
          _professionalIdentity = identity;
        });
      }
    } catch (e) {
      
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = Theme.of(context).colorScheme;
  }

  void _initializeNotifications() {
    _notificationService.createSampleNotifications();
    _notificationService.addListener(_onNotificationsChanged);
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  void _navigateToMonitoringDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleMonitoringDashboard(),
      ),
    );
  }
  
  void _navigateToPrivacyDemo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyDemoPage(),
      ),
    );
  }

  void _togglePrivacyMode() {
    // Toggle privacy mode logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy mode toggled')),
    );
  }

  void _toggleAvailability() {
    setState(() {
      _isAvailable = !_isAvailable;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isAvailable ? 'Now Available' : 'Now Busy'),
        backgroundColor: _isAvailable ? Colors.green : Colors.grey,
      ),
    );
  }
  
  void _switchToMode(AvailabilityMode mode) {
    setState(() {
      _currentMode = mode;
    });
    
    // Navigate to appropriate screen based on mode
    switch (mode) {
      case AvailabilityMode.nearby:
        context.push('/putrace/nearby');
        break;
      case AvailabilityMode.location:
        context.push('/putrace/map');
        break;
      case AvailabilityMode.virtual:
        // For now, show a message - could navigate to virtual networking page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Virtual mode - coming soon!')),
        );
        break;
    }
  }
  
  IconData _getModeIcon(AvailabilityMode mode) {
    switch (mode) {
      case AvailabilityMode.nearby:
        return Icons.radar;
      case AvailabilityMode.location:
        return Icons.location_on;
      case AvailabilityMode.virtual:
        return Icons.cloud;
    }
  }
  
  Color _getModeColor(AvailabilityMode mode) {
    switch (mode) {
      case AvailabilityMode.nearby:
        return _colorScheme.primary;
      case AvailabilityMode.location:
        return _colorScheme.secondary;
      case AvailabilityMode.virtual:
        return _colorScheme.tertiary;
    }
  }
  
  String _getModeDisplayName(AvailabilityMode mode) {
    switch (mode) {
      case AvailabilityMode.nearby:
        return 'Nearby Mode';
      case AvailabilityMode.location:
        return 'Location Mode';
      case AvailabilityMode.virtual:
        return 'Virtual Mode';
    }
  }
  
  String _getNearbyCountText() {
    switch (_currentMode) {
      case AvailabilityMode.nearby:
        return '$_nearbyCount nearby';
      case AvailabilityMode.location:
        return '2 venues';
      case AvailabilityMode.virtual:
        return '12 online';
    }
  }
  
  String _getConnectionCountText() {
    // If no modes are active (disconnected), show 0 modes
    if (_hybridAvailability.activeModes.isEmpty) {
      return '0 modes active';
    }
    
    // Show count based on primary mode
    switch (_hybridAvailability.primaryMode) {
      case AvailabilityMode.nearby:
        return '$_nearbyCount nearby';
      case AvailabilityMode.location:
        return '2 venues';
      case AvailabilityMode.virtual:
        return '12 online';
    }
  }
  
  String _getModeDescription(AvailabilityMode mode) {
    switch (mode) {
      case AvailabilityMode.nearby:
        return '';
      case AvailabilityMode.location:
        return 'Map-based networking - Set availability at specific venues and locations';
      case AvailabilityMode.virtual:
        return 'Global virtual networking - Connect with professionals worldwide online';
    }
  }
  
  String _getNetworkFeedTitle() {
    switch (_currentMode) {
      case AvailabilityMode.nearby:
        return 'Nearby Professionals';
      case AvailabilityMode.location:
        return 'Venue Opportunities';
      case AvailabilityMode.virtual:
        return 'Virtual Network';
    }
  }
  
  List<Widget> _getNetworkFeedCards() {
    switch (_currentMode) {
      case AvailabilityMode.nearby:
        return [
          _buildNetworkCard(
            title: 'Sarah Chen',
            subtitle: 'AI Researcher • Tech Corp',
            status: 'Open to chat about ML',
            timeAgo: '25m',
            isOnline: true,
            canConnect: true,
          ),
          const SizedBox(height: 12),
          _buildNetworkCard(
            title: 'Marcus Williams',
            subtitle: 'UX Designer • Design Studio',
            status: 'At Tech Conference',
            timeAgo: '15m',
            isOnline: true,
            canConnect: true,
          ),
        ];
      case AvailabilityMode.location:
        return [
          _buildNetworkCard(
            title: 'Starbucks Downtown',
            subtitle: 'Coffee Shop • 2-4 PM tomorrow',
            status: '3 professionals planning to be there',
            timeAgo: '5m',
            isOnline: true,
            canConnect: false,
          ),
          const SizedBox(height: 12),
          _buildNetworkCard(
            title: 'Tech Conference Center',
            subtitle: 'Event Venue • Tomorrow 9 AM - 5 PM',
            status: '12 professionals registered',
            timeAgo: '1h',
            isOnline: true,
            canConnect: false,
          ),
        ];
      case AvailabilityMode.virtual:
        return [
          _buildNetworkCard(
            title: 'AI & ML Discussion',
            subtitle: 'Virtual Room • Online now',
            status: '8 professionals discussing AI trends',
            timeAgo: '10m',
            isOnline: true,
            canConnect: true,
          ),
          const SizedBox(height: 12),
          _buildNetworkCard(
            title: 'Startup Founders',
            subtitle: 'Virtual Meetup • Starts in 2 hours',
            status: '15 professionals registered',
            timeAgo: '30m',
            isOnline: true,
            canConnect: true,
          ),
        ];
    }
  }
  
  Widget _buildNetworkCard({
    required String title,
    required String subtitle,
    required String status,
    required String timeAgo,
    required bool isOnline,
    required bool canConnect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getModeColor(_currentMode).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              _getModeIcon(_currentMode),
              color: _getModeColor(_currentMode),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isOnline)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _getModeColor(_currentMode),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          // Time and Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeAgo,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              if (canConnect)
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Connecting with $title...')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getModeColor(_currentMode),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Connect',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Viewing $title details...')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'View',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showPrivacyDemo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyDemoPage(),
      ),
    );
  }
  
  /// Build privacy-first components (Enterprise-grade security)
  Widget _buildPrivacyFirstComponents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Conference Mode Badge
        ConferenceModeBadge(
          isActive: _isConferenceModeActive,
          venueName: 'Tech Conference 2024',
          discoveredProfessionals: _discoveredProfessionals,
          onTap: () => _toggleConferenceMode(),
        ),
        
        const SizedBox(height: 16),
        
        // Professional Identity Card
        if (_professionalIdentity != null)
          ProfessionalIdentityCard(
            identity: _professionalIdentity!,
            showEncryptionStatus: true,
            onTap: () => _showProfessionalIdentityDetails(),
          ),
        
        const SizedBox(height: 16),
        
        // Privacy Status Row
        Row(
          children: [
            const Icon(Icons.security, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Privacy-First Networking',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const Spacer(),
            PrivacyStatusBadge(
              isEncrypted: _professionalIdentity?.encryptionPublicKey != null,
              encryptionLevel: 'end_to_end',
              onTap: () => _showPrivacySettings(),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Your professional communications are end-to-end encrypted. No phone number required.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  void _toggleConferenceMode() async {
    try {
      if (_isConferenceModeActive) {
        await _conferenceMode.disableConferenceMode();
      } else {
        await _conferenceMode.enableOfflineConferenceMode(
          eventId: 'tech_conference_2024',
          venueName: 'Convention Center Hall A',
          eventName: 'Tech Summit 2024',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conference mode error: $e')),
      );
    }
  }
  
  void _showProfessionalIdentityDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Professional Identity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_professionalIdentity != null) ...[
              Text('Name: ${_professionalIdentity!.displayName}'),
              Text('Email: ${_professionalIdentity!.professionalEmail}'),
              if (_professionalIdentity!.company != null)
                Text('Company: ${_professionalIdentity!.company}'),
              if (_professionalIdentity!.title != null)
                Text('Title: ${_professionalIdentity!.title}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.lock, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text('End-to-end encrypted'),
                ],
              ),
            ] else
              const Text('No professional identity found'),
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
  
  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrivacyQuickToggle(
              title: 'End-to-End Encryption',
              description: 'All messages are encrypted',
              isEnabled: _professionalIdentity?.encryptionPublicKey != null,
              onChanged: (value) => _toggleEncryption(value),
              icon: Icons.lock,
            ),
            PrivacyQuickToggle(
              title: 'Professional Identity',
              description: 'Use work email only',
              isEnabled: _professionalIdentity != null,
              onChanged: (value) => _toggleProfessionalIdentity(value),
              icon: Icons.business_center,
            ),
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
  
  void _toggleEncryption(bool enabled) {
    // Implementation for toggling encryption
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Encryption ${enabled ? 'enabled' : 'disabled'}')),
    );
  }
  
  void _toggleProfessionalIdentity(bool enabled) {
    // Implementation for toggling professional identity
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Professional identity ${enabled ? 'enabled' : 'disabled'}')),
    );
  }

  void _initializeHybridAvailability() {
    // Initialize hybrid availability
    _hybridAvailability = HybridAvailability(
      activeModes: <AvailabilityMode>{}, // Start with no active modes
      primaryMode: AvailabilityMode.nearby,
      settings: {
        AvailabilityMode.nearby: ModeSettings(
          privacy: PrivacyLevel.eventAttendees,
          radius: 50,
        ),
        AvailabilityMode.location: ModeSettings(
          privacy: PrivacyLevel.public,
          radius: 1000,
        ),
        AvailabilityMode.virtual: ModeSettings(
          privacy: PrivacyLevel.connections,
          radius: 0, // Global
        ),
      },
      isAvailable: false, // Start as offline
    );
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start pulse animation for nearby mode
    if (_hybridAvailability.isActiveIn(AvailabilityMode.nearby)) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _initializeRealNetworkingServices() async {
    try {
      // Initialize BLE discovery service
      bool bleInitialized = await _bleService.initialize();
      if (bleInitialized) {
        // Listen to BLE devices
        _bleService.nearbyDevicesStream.listen((devices) {
          setState(() {
            _bleDevices = devices;
            _updateNearbyCount();
          });
        });
      }

      // Initialize user discovery service
      bool userDiscoveryInitialized = await _userDiscoveryService.initialize();
      if (userDiscoveryInitialized) {
        // Listen to nearby users
        _userDiscoveryService.nearbyUsersStream.listen((users) {
          setState(() {
            _nearbyUsers = users;
            _updateNearbyCount();
          });
        });
      }
    } catch (e) {
      
    }
  }

  void _updateNearbyCount() {
    // Combine BLE devices and Firestore users
    int totalNearby = _bleDevices.length + _nearbyUsers.length;
    setState(() {
      _nearbyCount = totalNearby;
    });
  }
  
  // HYBRID MODE MANAGEMENT
  void _toggleMode(AvailabilityMode mode) {
    // Instant haptic feedback for immediate response
    HapticFeedback.lightImpact();
    
    setState(() {
      final newActiveModes = Set<AvailabilityMode>.from(_hybridAvailability.activeModes);
      
      if (newActiveModes.contains(mode)) {
        newActiveModes.remove(mode);
        // If removing primary mode, switch to another active mode
        if (_hybridAvailability.primaryMode == mode && newActiveModes.isNotEmpty) {
          _hybridAvailability = _hybridAvailability.copyWith(
            activeModes: newActiveModes,
            primaryMode: newActiveModes.first,
          );
        } else if (_hybridAvailability.primaryMode == mode && newActiveModes.isEmpty) {
          // If no other modes, set primary to null or default
          _hybridAvailability = _hybridAvailability.copyWith(
            activeModes: newActiveModes,
            primaryMode: AvailabilityMode.nearby, // Default to nearby if no other active modes
          );
        } else {
          _hybridAvailability = _hybridAvailability.copyWith(
            activeModes: newActiveModes,
          );
        }
      } else {
        newActiveModes.add(mode);
        _hybridAvailability = _hybridAvailability.copyWith(
          activeModes: newActiveModes,
          primaryMode: mode, // New mode becomes primary
        );
      }
      
      // AUTO-DISCOVERABLE: When at least one mode is active, automatically set discoverable
      if (newActiveModes.isNotEmpty) {
        _isAvailable = true; // Automatically become discoverable
      } else {
        _isAvailable = false; // Automatically go offline when no modes
      }
    });
    
    _handleModeChange(mode);
  }
  
  void _handleModeChange(AvailabilityMode mode) {
    // Handle mode-specific logic with instant visual feedback
    switch (mode) {
      case AvailabilityMode.nearby:
        // Start/stop BLE scanning
        if (_hybridAvailability.isActiveIn(mode)) {
          _pulseController.repeat(reverse: true);
          _startRealNetworking();
        } else {
          _pulseController.stop();
          _stopRealNetworking();
        }
        break;
      case AvailabilityMode.location:
        // Update location sharing
        if (_hybridAvailability.isActiveIn(mode)) {
          _startLocationSharing();
        } else {
          _stopLocationSharing();
        }
        break;
      case AvailabilityMode.virtual:
        // Connect to virtual network
        if (_hybridAvailability.isActiveIn(mode)) {
          _connectVirtualNetwork();
        } else {
          _disconnectVirtualNetwork();
        }
        break;
    }
  }

  // Placeholder methods for actual networking implementation
  void _startRealNetworking() {
    
    
    // Start BLE scanning
    _bleService.startScanning();
    
    // Update user availability in Firestore
    _userDiscoveryService.setUserAvailability(
      true, 
      _hybridAvailability.activeModes.map((mode) => mode.name).toList()
    );
  }

  void _startBLEScanning() {
    // Legacy method - now calls real networking
    _startRealNetworking();
  }

  void _stopRealNetworking() {
    
    
    // Stop BLE scanning
    _bleService.stopScanning();
    
    // Update user availability in Firestore
    _userDiscoveryService.setUserAvailability(
      false, 
      _hybridAvailability.activeModes.map((mode) => mode.name).toList()
    );
  }

  void _stopBLEScanning() {
    // Legacy method - now calls real networking
    _stopRealNetworking();
  }

  // BLE Permission Check
  void _checkBLEPermissions() {
    // TODO: Implement actual BLE permission check
    
  }

  // BLE Advertising (Make yourself discoverable)
  void _startBLEAdvertising() {
    // TODO: Implement actual BLE advertising
    
  }

  void _stopBLEAdvertising() {
    // TODO: Implement actual BLE advertising stop
    
  }

  // BLE Discovery (Find nearby professionals)
  void _startBLEDiscovery() {
    // TODO: Implement actual BLE discovery
    
  }

  void _stopBLEDiscovery() {
    // TODO: Implement actual BLE discovery stop
    
  }


  // Clear nearby users
  void _clearNearbyUsers() {
    // TODO: Clear actual nearby users list
    
  }

  // Show user feedback
  void _showNearbyModeFeedback() {
    // TODO: Show subtle feedback that BLE is active
    
  }

  void _startLocationSharing() {
    // TODO: Implement actual location sharing
    
  }

  void _stopLocationSharing() {
    // TODO: Implement actual location stop
    
  }

  void _connectVirtualNetwork() {
    // TODO: Implement actual virtual network connection
    
  }

  void _disconnectVirtualNetwork() {
    // TODO: Implement actual virtual network disconnection
    
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _notificationService.removeListener(_onNotificationsChanged);
    _bleService.dispose();
    _userDiscoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildCurrentTab(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      extendBody: false,
    );
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.security),
          onPressed: () => _navigateToPrivacyDemo(),
          tooltip: 'Privacy Demo',
        ),
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          onPressed: () => _navigateToMonitoringDashboard(),
          tooltip: 'Monitoring Dashboard',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _navigateToConnectionSettings(),
          tooltip: 'Connection Settings',
        ),
        _buildNotificationBadge(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotificationsPanel(context),
          tooltip: 'Notifications',
        ),
        if (_notificationService.unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _notificationService.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentTab() {
    final tabs = [
      _buildDiscoverTab(),
      const MessagesPage(),
      const _ProfileTab(),
    ];
    return SafeArea(
      bottom: false, // Don't add bottom safe area since we handle it in bottom navigation
      child: tabs[_currentTabIndex],
    );
  }

  Widget _buildDiscoverTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPresenceStatusCard(),
        const SizedBox(height: 16),
        _buildModeSelector(),
        const SizedBox(height: 16),
        _buildLiveNetworkFeed(),
      ],
    );
  }

  // NEW INNOVATIVE DESIGN: Professional Presence Hub
  
  Widget _buildPresenceStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getModeColor(_currentMode).withValues(alpha: 0.1),
            _getModeColor(_currentMode).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isAvailable ? _getModeColor(_currentMode) : Colors.grey,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Status Indicator
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _hybridAvailability.activeModes.isEmpty ? Colors.red : (_isAvailable ? Colors.green : Colors.orange),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_hybridAvailability.activeModes.isEmpty ? Colors.red : (_isAvailable ? Colors.green : Colors.orange)).withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _hybridAvailability.activeModes.isEmpty ? 'OFFLINE' : (_isAvailable ? 'DISCOVERABLE' : 'BUSY'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _hybridAvailability.activeModes.isEmpty ? Colors.red : (_isAvailable ? Colors.green : Colors.orange),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 12),
              // Status Toggle Button (only show when modes are active)
              if (_hybridAvailability.activeModes.isNotEmpty)
                GestureDetector(
                  onTap: _toggleAvailability,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAvailable ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAvailable ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isAvailable ? 'ON' : 'OFF',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
        const SizedBox(height: 8),
        ],
      ),
    );
  }
  
   Widget _buildModeSelector() {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           children: [
             Text(
               'Professional Availability',
               style: GoogleFonts.inter(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
                 color: _colorScheme.onSurface,
               ),
             ),
             const Spacer(),
             _buildHybridStatusBadge(),
           ],
         ),
        const SizedBox(height: 16),
         Row(
           children: [
             Expanded(
               child: _buildHybridModeCard(
                 mode: AvailabilityMode.nearby,
                 title: 'Nearby',
                 subtitle: 'BLE Discovery',
                 description: '50m radius',
                 icon: Icons.radar,
                 color: Colors.blue,
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: _buildHybridModeCard(
                 mode: AvailabilityMode.location,
                 title: 'Location',
                 subtitle: 'Set Location',
                 description: '1km radius',
                 icon: Icons.location_on,
                 color: Colors.orange,
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: _buildHybridModeCard(
                 mode: AvailabilityMode.virtual,
                 title: 'Virtual',
                 subtitle: 'Online Only',
                 description: 'Global',
                 icon: Icons.cloud,
                 color: Colors.purple,
               ),
             ),
           ],
         ),
       ],
     );
   }
  
   Widget _buildHybridStatusBadge() {
     final activeCount = _hybridAvailability.activeModes.length;
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
       decoration: BoxDecoration(
         color: _hybridAvailability.isAvailable ? Colors.green : Colors.orange,
         borderRadius: BorderRadius.circular(20),
       ),
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Icon(
             _hybridAvailability.isAvailable ? Icons.visibility : Icons.visibility_off,
             color: Colors.white,
             size: 16,
           ),
           const SizedBox(width: 4),
           Text(
             '$activeCount mode${activeCount == 1 ? '' : 's'} active',
             style: GoogleFonts.inter(
               fontSize: 12,
               fontWeight: FontWeight.bold,
               color: Colors.white,
             ),
           ),
         ],
       ),
     );
   }

   Widget _buildHybridModeCard({
     required AvailabilityMode mode,
     required String title,
     required String subtitle,
     required String description,
     required IconData icon,
     required Color color,
   }) {
     final isActive = _hybridAvailability.isActiveIn(mode);
     final isPrimary = _hybridAvailability.primaryMode == mode;
     
    return GestureDetector(
      onTap: () => _toggleMode(mode),
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: isActive ? color.withValues(alpha: 0.1) : _colorScheme.surface,
           borderRadius: BorderRadius.circular(16),
           border: Border.all(
             color: isActive ? color : _colorScheme.outline.withValues(alpha: 0.2),
             width: isPrimary ? 3 : (isActive ? 2 : 1),
           ),
         ),
         child: Column(
           children: [
             Stack(
               children: [
                 Icon(
                   icon,
                   color: isActive ? color : Colors.grey,
                   size: 24,
                 ),
                 if (isPrimary)
                   Positioned(
                     right: -2,
                     top: -2,
                     child: Container(
                       padding: const EdgeInsets.all(2),
                       decoration: BoxDecoration(
                         color: Colors.amber,
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(
                         Icons.star,
                         color: Colors.white,
                         size: 8,
                       ),
                     ),
                   ),
               ],
             ),
             const SizedBox(height: 8),
             Text(
               title,
               style: GoogleFonts.inter(
                 fontSize: 14,
                 fontWeight: FontWeight.bold,
                 color: isActive ? color : _colorScheme.onSurface,
               ),
             ),
             const SizedBox(height: 4),
             Text(
               subtitle,
               style: GoogleFonts.inter(
                 fontSize: 10,
                 color: _colorScheme.onSurface.withValues(alpha: 0.6),
               ),
             ),
             const SizedBox(height: 8),
             Text(
               description,
               style: GoogleFonts.inter(
                 fontSize: 10,
                 color: _colorScheme.onSurface.withValues(alpha: 0.7),
                 height: 1.2,
               ),
             textAlign: TextAlign.center,
             ),
             if (isActive)
               Container(
                 margin: const EdgeInsets.only(top: 4),
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: isPrimary ? Colors.amber : color,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   isPrimary ? 'PRIMARY' : 'ACTIVE',
                   style: GoogleFonts.inter(
                     fontSize: 8,
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                 ),
               ),
           ],
         ),
       ),
     ),
    );
   }
  
  
  
  Widget _buildLiveNetworkFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Network title with See All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Blinking "Live Network" title
            Expanded(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  // Clamp opacity to valid range (0.0 to 1.0)
                  final opacity = (0.5 + (0.5 * _pulseAnimation.value)).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: opacity, // Blinks between 0.5 and 1.0
                    child: Text(
                      'Live Network',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
            // See All button next to title
            _buildSeeAllButton(),
          ],
        ),
        const SizedBox(height: 12),
        
        // Show content from all active modes
        ..._getHybridNetworkContent(),
      ],
    );
  }

   List<Widget> _getHybridNetworkContent() {
     final content = <Widget>[];
     
     for (final mode in _hybridAvailability.activeModes) {
       content.add(_buildModeSection(mode));
       content.add(const SizedBox(height: 16));
     }
     
     return content;
   }

   Widget _buildModeSection(AvailabilityMode mode) {
     final isPrimary = _hybridAvailability.primaryMode == mode;
     
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: _getModeColor(mode).withValues(alpha: 0.05),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: _getModeColor(mode).withValues(alpha: isPrimary ? 0.5 : 0.2),
           width: isPrimary ? 2 : 1,
         ),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               Icon(_getModeIcon(mode), color: _getModeColor(mode), size: 20),
               const SizedBox(width: 8),
               Text(
                 _getModeDisplayName(mode),
                 style: GoogleFonts.inter(
                   fontSize: 16,
                   fontWeight: FontWeight.bold,
                   color: _getModeColor(mode),
                 ),
               ),
               if (isPrimary) ...[
                 const SizedBox(width: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(
                     color: Colors.amber,
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Text(
                     'PRIMARY',
                     style: GoogleFonts.inter(
                       fontSize: 8,
                       fontWeight: FontWeight.bold,
                       color: Colors.white,
                     ),
                   ),
                 ),
               ],
             ],
           ),
           const SizedBox(height: 12),
           ..._getModeSpecificContent(mode),
         ],
       ),
     );
   }

   List<Widget> _getModeSpecificContent(AvailabilityMode mode) {
     switch (mode) {
       case AvailabilityMode.nearby:
         return _buildNearbyContent();
       case AvailabilityMode.location:
         return _buildLocationContent();
       case AvailabilityMode.virtual:
         return _buildVirtualContent();
     }
   }

  List<Widget> _buildNearbyContent() {
    return [
      // Atomic pulse visualization
      _buildPulseVisualization(),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildPulseVisualization() {
    return Container(
      height: 200, // Restored original height
      width: double.infinity, // Full width
      decoration: BoxDecoration(
        color: Colors.white, // Restored white background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2), // Light blue border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 200, // Constrain the atomic animation area
          height: 200, // Constrain the atomic animation area
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Atomic nucleus (you) - glowing center
                  _buildAtomicNucleus(),
                  
                  // Electron orbits (concentric circles)
                  _buildElectronOrbits(),
                  
                  // Orbiting electrons (nearby users)
                  ..._buildOrbitingElectrons(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAtomicNucleus() {
    return Container(
      width: 50, // Minimized central user circle
      height: 50, // Minimized central user circle
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            const Color(0xFFF59E0B), // Bright amber
            const Color(0xFFD97706), // Darker amber
            const Color(0xFFB45309), // Darkest amber
          ],
        ),
        shape: BoxShape.circle,
        // Removed boxShadow to eliminate opacity outside circle
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 28, // Minimized icon size
      ),
    );
  }

  Widget _buildElectronOrbits() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Inner orbit
        Container(
          width: 100, // Fits within 200px constraint
          height: 100, // Fits within 200px constraint
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.6), // Increased opacity
              width: 3, // Increased width
            ),
          ),
        ),
        // Outer orbit
        Container(
          width: 160, // Fits within 200px constraint
          height: 160, // Fits within 200px constraint
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.5), // Increased opacity
              width: 3, // Increased width
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOrbitingElectrons() {
    // Use real user data if available, otherwise fall back to mock data
    List<Map<String, dynamic>> innerElectrons = [];
    List<Map<String, dynamic>> outerElectrons = [];

    if (_nearbyUsers.isNotEmpty || _bleDevices.isNotEmpty) {
      // Use real data
      List<Map<String, dynamic>> allUsers = [];
      
      // Add Firestore users
      for (int i = 0; i < _nearbyUsers.length && i < 6; i++) {
        NearbyUser user = _nearbyUsers[i];
        allUsers.add({
          'name': user.name,
          'distance': user.distance.toInt(),
          'angle': (i * 60) % 360,
          'orbit': i < 3 ? 'inner' : 'outer',
          'proximity': user.proximity,
        });
      }
      
      // Add BLE devices
      for (int i = 0; i < _bleDevices.length && allUsers.length < 6; i++) {
        BLEDevice device = _bleDevices[i];
        allUsers.add({
          'name': device.name,
          'distance': device.distance.toInt(),
          'angle': (allUsers.length * 60) % 360,
          'orbit': allUsers.length < 3 ? 'inner' : 'outer',
          'proximity': device.proximity,
        });
      }
      
      // Split into inner and outer orbits
      innerElectrons = allUsers.where((user) => user['orbit'] == 'inner').toList();
      outerElectrons = allUsers.where((user) => user['orbit'] == 'outer').toList();
    } else {
      // Fallback to mock data
      innerElectrons = [
        {'name': 'Sarah', 'distance': 15, 'angle': 0, 'orbit': 'inner', 'proximity': 'Very Close'},
        {'name': 'Mike', 'distance': 25, 'angle': 120, 'orbit': 'inner', 'proximity': 'Very Close'},
        {'name': 'Lisa', 'distance': 35, 'angle': 240, 'orbit': 'inner', 'proximity': 'Very Close'},
      ];
      
      outerElectrons = [
        {'name': 'John', 'distance': 45, 'angle': 60, 'orbit': 'outer', 'proximity': 'Nearby'},
        {'name': 'Emma', 'distance': 50, 'angle': 180, 'orbit': 'outer', 'proximity': 'Nearby'},
        {'name': 'Alex', 'distance': 30, 'angle': 300, 'orbit': 'outer', 'proximity': 'Nearby'},
      ];
    }

    final allElectrons = [...innerElectrons, ...outerElectrons];

    return allElectrons.map((electron) {
      final distance = electron['distance'] as int;
      final name = electron['name'] as String;
      final angle = electron['angle'] as int;
      final orbit = electron['orbit'] as String;
      final proximity = electron['proximity'] as String;
      
      // Calculate orbit radius and position
      final orbitRadius = orbit == 'inner' ? 50.0 : 80.0; // Adjusted for constrained area
      final radians = (angle * pi) / 180;
      // final x = cos(radians) * orbitRadius; // Removed unused variable
      // final y = sin(radians) * orbitRadius; // Removed unused variable
      
      // Add orbital motion animation
      final orbitalOffset = orbit == 'inner' ? 0.0 : _pulseAnimation.value * 0.5;
      final animatedAngle = angle + (orbitalOffset * 30); // 30 degree orbital motion
      final animatedRadians = (animatedAngle * pi) / 180;
      final animatedX = cos(animatedRadians) * orbitRadius;
      final animatedY = sin(animatedRadians) * orbitRadius;
      
      return Positioned(
        left: 120 + animatedX - 15, // Center at 120, offset by half electron size (30/2 = 15)
        top: 120 + animatedY - 15,
        child: GestureDetector(
          onTap: () => _showUserProfile(name, distance),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Electron circle
              Container(
                width: 30, // Minimized to half size (60/2 = 30)
                height: 30, // Minimized to half size (60/2 = 30)
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: orbit == 'inner' 
                      ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)] // Blue for inner orbit
                      : [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)], // Purple for outer orbit
                  ),
                  shape: BoxShape.circle,
                  // Removed boxShadow to eliminate opacity outside circle
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14, // Reduced to match smaller size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Proximity label
              const SizedBox(height: 2),
              Text(
                proximity,
                style: GoogleFonts.inter(
                  color: orbit == 'inner' 
                    ? const Color(0xFF3B82F6) // Blue for inner orbit
                    : const Color(0xFF8B5CF6), // Purple for outer orbit
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showUserProfile(String name, int distance) {
    // Determine proximity based on distance
    String proximity;
    if (distance <= 25) {
      proximity = 'Very Close';
    } else if (distance <= 50) {
      proximity = 'Nearby';
    } else {
      proximity = 'In Range';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$name - $proximity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tap to connect or view profile'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _connectToUser(name);
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Connect'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _viewUserProfile(name);
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Profile'),
                ),
              ],
            ),
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

  void _connectToUser(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to $name...')),
    );
  }

  void _viewUserProfile(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $name\'s profile...')),
    );
  }

  Widget _buildSeeAllButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _navigateToNearbyUsersList(),
        icon: const Icon(Icons.people, size: 18),
        label: const Text('See All Nearby'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }

  void _navigateToNearbyUsersList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NearbyUsersListPage(),
      ),
    );
  }


   List<Widget> _buildLocationContent() {
     return [
       Text(
         'Set one location for networking opportunities',
         style: GoogleFonts.inter(
           color: Colors.grey[600],
           fontSize: 14,
         ),
       ),
       const SizedBox(height: 8),
       if (_selectedLocationVenue != null) ...[
         GestureDetector(
           onTap: () => _showVenueInfoPopup(_selectedLocationVenue!),
           child: Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.orange.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
             ),
             child: Row(
               children: [
                 Icon(
                   Icons.location_on,
                   color: Colors.orange,
                   size: 20,
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Selected Venue:',
                         style: GoogleFonts.inter(
                           fontSize: 12,
                           color: Colors.orange[700],
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                       Text(
                         _selectedLocationVenue!.name,
                         style: GoogleFonts.inter(
                           fontSize: 14,
                           color: Colors.orange[800],
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                     ],
                   ),
                 ),
                 Icon(
                   Icons.info_outline,
                   color: Colors.orange[700],
                   size: 18,
                 ),
                 const SizedBox(width: 8),
                 IconButton(
                   onPressed: () {
                     setState(() {
                       _selectedLocationVenue = null;
                     });
                   },
                   icon: const Icon(Icons.close, size: 18),
                   color: Colors.orange[700],
                 ),
               ],
             ),
           ),
         ),
         const SizedBox(height: 8),
       ],
       ElevatedButton.icon(
         onPressed: () => _navigateToLocationMode(),
         icon: const Icon(Icons.map),
         label: Text(_selectedLocationVenue != null ? 'Change Location' : 'Set Location'),
         style: ElevatedButton.styleFrom(
           backgroundColor: Colors.orange,
           foregroundColor: Colors.white,
         ),
       ),
     ];
   }

   List<Widget> _buildVirtualContent() {
     return [
       Text(
         'Virtual networking opportunities',
         style: GoogleFonts.inter(
           color: Colors.grey[600],
           fontSize: 14,
         ),
       ),
       const SizedBox(height: 8),
       ElevatedButton.icon(
         onPressed: () => _navigateToVirtualWorld(),
         icon: const Icon(Icons.public),
         label: const Text('Enter Virtual World'),
         style: ElevatedButton.styleFrom(
           backgroundColor: Colors.purple,
           foregroundColor: Colors.white,
         ),
       ),
     ];
   }

   // Navigation methods
   void _navigateToLocationMode() async {
     // Navigate to clean Location Mode map
     final result = await Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => const SimpleOSMPage(), // Simple OSM map - no permissions needed!
       ),
     );
     
     // Handle the returned venue selection
     if (result != null && result is Map<String, dynamic>) {
       final venue = result['venue'] as OSMVenue;
       final message = result['message'] as String? ?? '';
       final scheduledTime = result['scheduledTime'] as DateTime?;
       setState(() {
         _selectedLocationVenue = venue;
         _venueCustomMessage = message;
         _setVenueCustomMessage(venue.id, message);
         if (scheduledTime != null) {
           _setVenueScheduledTime(venue.id, scheduledTime);
         }
       });
     }
   }

  void _navigateToVirtualWorld() {
    // Navigate to Virtual World Map
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VirtualWorldPage(),
      ),
    );
  }

  String _getVenueCustomMessage(String venueId) {
    return _venueMessages[venueId] ?? '';
  }

  void _setVenueCustomMessage(String venueId, String message) {
    setState(() {
      _venueMessages[venueId] = message;
    });
  }

  DateTime? _getVenueScheduledTime(String venueId) {
    return _venueScheduledTimes[venueId];
  }

  void _setVenueScheduledTime(String venueId, DateTime? scheduledTime) {
    setState(() {
      _venueScheduledTimes[venueId] = scheduledTime;
    });
  }


  void _showVenueInfoPopup(OSMVenue venue) {
    // Get the custom message and scheduled time for this specific venue
    final venueMessage = _getVenueCustomMessage(venue.id);
    final scheduledTime = _getVenueScheduledTime(venue.id);
    final messageController = TextEditingController(text: venueMessage);
    bool isEditing = false;
    bool isEditingTime = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            venue.name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Venue Type
                Text(
                  venue.type,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Address
                if (venue.address != null) ...[
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
                  const SizedBox(height: 8),
                ],
                
                // Phone
                if (venue.phone != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        venue.phone!,
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Rating and Type
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
                const SizedBox(height: 16),
                
                // Custom Message Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Your Message:',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                isEditing = !isEditing;
                                if (!isEditing) {
                                  // Save the message when done editing
                                  _setVenueCustomMessage(venue.id, messageController.text.trim());
                                }
                              });
                            },
                            icon: Icon(
                              isEditing ? Icons.check : Icons.edit,
                              size: 18,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isEditing) ...[
                        TextField(
                          controller: messageController,
                          decoration: InputDecoration(
                            hintText: 'e.g., "Meet me for coffee", "Come pitch your idea"',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(8),
                          ),
                          maxLines: 2,
                          maxLength: 100,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            venueMessage.isEmpty 
                                ? 'No message set. Tap edit to add one.'
                                : venueMessage,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: venueMessage.isEmpty ? Colors.grey[500] : Colors.grey[800],
                              fontStyle: venueMessage.isEmpty ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Scheduled Time Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Scheduled Time:',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[800],
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                isEditingTime = !isEditingTime;
                                if (!isEditingTime) {
                                  // Save the time when done editing
                                  // This will be handled in the date/time picker
                                }
                              });
                            },
                            icon: Icon(
                              isEditingTime ? Icons.check : Icons.edit,
                              size: 18,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isEditingTime) ...[
                        GestureDetector(
                          onTap: () async {
                            try {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: scheduledTime ?? DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: scheduledTime != null 
                                      ? TimeOfDay.fromDateTime(scheduledTime!)
                                      : TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1),
                                );
                                if (time != null) {
                                  final newScheduledTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                  setState(() {
                                    _setVenueScheduledTime(venue.id, newScheduledTime);
                                    isEditingTime = false; // Exit editing mode after selection
                                  });
                                }
                              }
                            } catch (e) {
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error selecting date/time: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.blue[700], size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Tap to select date and time',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                color: scheduledTime != null ? Colors.blue[700] : Colors.grey[400],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  scheduledTime != null
                                      ? '${scheduledTime!.day}/${scheduledTime!.month}/${scheduledTime!.year} at ${scheduledTime!.hour.toString().padLeft(2, '0')}:${scheduledTime!.minute.toString().padLeft(2, '0')}'
                                      : 'No time scheduled. Tap edit to add one.',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: scheduledTime != null ? Colors.grey[800] : Colors.grey[500],
                                    fontStyle: scheduledTime == null ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ),
                              if (scheduledTime != null) ...[
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _setVenueScheduledTime(venue.id, null);
                                    });
                                  },
                                  icon: const Icon(Icons.close, size: 16),
                                  color: Colors.grey[500],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                messageController.dispose();
                Navigator.pop(context);
              },
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToConnectionSettings() {
    // Navigate to Connection Settings
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConnectionSettingsPage(),
      ),
    );
  }
  
  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.power_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Disconnect & Go Private',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'This will stop all networking activities:\n\n'
          '• Stop BLE scanning and advertising\n'
          '• Hide your location from others\n'
          '• Pause all discovery modes\n\n'
          'You can reconnect anytime by switching modes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _disconnectAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
  
  void _disconnectAll() {
    // Strong haptic feedback for disconnect action
    HapticFeedback.heavyImpact();
    
    setState(() {
      // Set user offline
      _isAvailable = false;
      
      // Unselect all 3 modes using hybrid availability system
      _hybridAvailability = _hybridAvailability.copyWith(
        activeModes: <AvailabilityMode>{}, // Empty set - no modes active
        primaryMode: AvailabilityMode.nearby, // Reset to default
        isAvailable: false, // Set offline
      );
      
      // Stop pulse animation
      _pulseController.stop();
    });
    
    // Stop all networking activities
    _stopAllNetworkingActivities();
    
    // Show brief confirmation (no snackbar to avoid delay)
    // Visual feedback is immediate through UI state changes
  }
  
  void _stopAllNetworkingActivities() {
    // Stop BLE scanning and advertising
    // _stopBLEScanning(); // Placeholder for actual BLE stop
    
    // Stop location sharing
    // _stopLocationSharing(); // Placeholder for actual location stop
    
    // Disconnect from virtual network
    // _disconnectVirtualNetwork(); // Placeholder for actual virtual disconnect
    
    // Clear all active connections
    // _clearAllConnections(); // Placeholder for actual connection clearing
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            _colorScheme.primary.withValues(alpha: 0.9),
            _colorScheme.secondary.withValues(alpha: 0.8),
            _colorScheme.tertiary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 24),
          _buildHeroButtons(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Putrace',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Discover and connect with professionals around you',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.4,
          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Bigger Privacy Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 32, // Bigger icon
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Privacy-First',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/putrace/nearby'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.location_on, size: 24),
            label: Text(
              'Find Nearby',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/putrace/map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.map, size: 24),
            label: Text(
              'View Map',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _colorScheme.onSurface,
      ),
    );
  }


  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoreActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (isActive)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveProfessionalPulse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _getPulseSectionTitle(),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getModeColor(_currentMode).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _getModeColor(_currentMode),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getModeColor(_currentMode),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Context-aware professional cards
        ..._getContextAwareProfessionalCards(),
      ],
    );
  }
  
  String _getPulseSectionTitle() {
    switch (_currentMode) {
      case AvailabilityMode.nearby:
        return 'Live Professional Pulse';
      case AvailabilityMode.location:
        return 'Venue-Based Networking';
      case AvailabilityMode.virtual:
        return 'Virtual Professional Network';
    }
  }
  
  List<Widget> _getContextAwareProfessionalCards() {
    switch (_currentMode) {
      case AvailabilityMode.nearby:
        return [
          _buildProfessionalCard(
            name: 'Sarah Chen',
            title: 'AI Researcher',
            company: 'Tech Corp',
            timeAgo: '25m',
            status: 'Open to chat about ML',
            isOnline: true,
            mode: _currentMode,
          ),
          const SizedBox(height: 12),
          _buildProfessionalCard(
            name: 'Marcus Williams',
            title: 'UX Designer',
            company: 'Design Studio',
            timeAgo: '15m',
            status: 'At Tech Conference',
            isOnline: true,
            mode: _currentMode,
          ),
          const SizedBox(height: 12),
          _buildProfessionalCard(
            name: 'Dr. Elena Rodriguez',
            title: 'Data Scientist',
            company: 'Research Lab',
            timeAgo: '1h',
            status: 'Available for collaboration',
            isOnline: false,
            mode: _currentMode,
          ),
        ];
      case AvailabilityMode.location:
        return [
          _buildProfessionalCard(
            name: 'Starbucks Downtown',
            title: 'Coffee Shop',
            company: '2-4 PM tomorrow',
            timeAgo: '5m',
            status: '3 professionals planning to be there',
            isOnline: true,
            mode: _currentMode,
          ),
          const SizedBox(height: 12),
          _buildProfessionalCard(
            name: 'Tech Conference Center',
            title: 'Event Venue',
            company: 'Tomorrow 9 AM - 5 PM',
            timeAgo: '1h',
            status: '12 professionals registered',
            isOnline: true,
            mode: _currentMode,
          ),
          const SizedBox(height: 12),
          _buildProfessionalCard(
            name: 'Co-working Space',
            title: 'Office Space',
            company: 'Available now',
            timeAgo: '2h',
            status: '5 professionals working there',
            isOnline: false,
            mode: _currentMode,
          ),
        ];
      case AvailabilityMode.virtual:
        return [
          _buildProfessionalCard(
            name: 'AI & ML Discussion',
            title: 'Virtual Room',
            company: 'Online now',
            timeAgo: '10m',
            status: '8 professionals discussing AI trends',
            isOnline: true,
            mode: _currentMode,
          ),
          const SizedBox(height: 12),
          _buildProfessionalCard(
            name: 'Startup Founders',
            title: 'Virtual Meetup',
            company: 'Starts in 2 hours',
            timeAgo: '30m',
            status: '15 professionals registered',
            isOnline: true,
            mode: _currentMode,
          ),
          const SizedBox(height: 12),
          _buildProfessionalCard(
            name: 'Remote Work Tips',
            title: 'Virtual Workshop',
            company: 'Tomorrow 2 PM',
            timeAgo: '1h',
            status: '25 professionals interested',
            isOnline: false,
            mode: _currentMode,
          ),
        ];
    }
  }

  Widget _buildProfessionalCard({
    required String name,
    required String title,
    required String company,
    required String timeAgo,
    required String status,
    required bool isOnline,
    AvailabilityMode? mode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.person,
              color: _colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isOnline)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$title • $company',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          // Time and Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeAgo,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  // Connect action
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connecting with $name...')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Connect',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: _colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              icon: Icons.person_add,
              title: 'Connected with Sarah Chen',
              subtitle: 'Software Engineer at TechCorp',
              time: '2 hours ago',
              color: _colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              icon: Icons.location_on,
              title: 'Discovered 3 new contacts',
              subtitle: 'Nearby networking event',
              time: '5 hours ago',
              color: _colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              icon: Icons.edit_note,
              title: 'Posted new update',
              subtitle: 'Excited about the new project!',
              time: '1 day ago',
              color: _colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSerendipitySuggestions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: _colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Serendipity Suggestions',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSerendipityItem(
              title: 'Networking Event',
              subtitle: 'Join a local meetup for tech professionals.',
              icon: Icons.event,
              color: _colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildSerendipityItem(
              title: 'New User',
              subtitle: 'Sarah Chen just joined Putrace.',
              icon: Icons.person_add,
              color: _colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            _buildSerendipityItem(
              title: 'Proximity Alert',
              subtitle: 'You are near a new connection opportunity.',
              icon: Icons.location_on,
              color: _colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSerendipityItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            if (index == 3) {
              // Disconnect button
              _showDisconnectDialog();
            } else {
              setState(() => _currentTabIndex = index);
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: _colorScheme.primary,
          unselectedItemColor: _colorScheme.onSurface.withValues(alpha: 0.6),
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Discover',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              label: 'Disconnect',
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications, color: _colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Notifications'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_notificationService.notifications.isEmpty)
                  _buildEmptyNotifications()
                else
                  ..._notificationService.notifications
                      .take(10)
                      .map(_buildNotificationItem),
                const SizedBox(height: 16),
                if (_notificationService.notifications.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          _notificationService.markAllAsRead();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Mark All Read'),
                      ),
                      TextButton(
                        onPressed: () {
                          _notificationService.clearAll();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (_notificationService.notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/notifications');
              },
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Column(
      children: [
        Icon(
          Icons.notifications_none,
          size: 64,
          color: _colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'No notifications yet',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll notify you when something important happens',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getNotificationColor(notification.type),
        child: Icon(
          _getNotificationIcon(notification.type),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        notification.title,
        style: GoogleFonts.inter(
          fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        notification.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatTime(notification.timestamp),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: () => _handleNotificationTap(notification),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.connection:
        return Colors.orange;
      case NotificationType.discovery:
        return Colors.blue;
      case NotificationType.proximity:
        return Colors.green;
      case NotificationType.location:
        return Colors.purple;
      case NotificationType.general:
        return Colors.grey;
    }
  }

 IconData _getNotificationIcon(NotificationType type) {
  switch (type) {
    case NotificationType.connection:
      return Icons.handshake;
    case NotificationType.discovery:
      return Icons.person_add;
    case NotificationType.proximity:
      return Icons.location_on;
    case NotificationType.location:
      return Icons.map;
    case NotificationType.general:
      return Icons.notifications;
  }
}

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  void _handleNotificationTap(NotificationItem notification) {
    _notificationService.markAsRead(notification.id);

    switch (notification.type) {
      case NotificationType.connection:
        context.push('/putrace');
        break;
      case NotificationType.discovery:
        context.push('/putrace');
        break;
      case NotificationType.proximity:
        context.push('/putrace');
        break;
      case NotificationType.location:
        context.push('/putrace/map');
        break;
      case NotificationType.general:
        // Stay on current page for general notifications
        break;
    }
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          title: 'Profile',
          subtitle: 'Manage your personal information',
          icon: Icons.person,
          color: scheme.primary,
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'View Profile',
          subtitle: 'See and edit your profile',
          icon: Icons.person,
          color: scheme.primary,
          onTap: () => context.go('/putrace/profile'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'My Posts',
          subtitle: 'View and manage your posts',
          icon: Icons.article,
          color: scheme.secondary,
          onTap: () => context.go('/putrace/posts'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'Availability',
          subtitle: 'Set your connection status',
          icon: Icons.person_add,
          color: scheme.tertiary,
          onTap: () => context.go('/putrace/availability'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'Custom Groups',
          subtitle: 'Manage your audience groups',
          icon: Icons.group,
          color: scheme.secondary,
          onTap: () => context.go('/putrace/groups'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'My Contacts',
          subtitle: 'View your network connections',
          icon: Icons.people,
          color: scheme.primary,
          onTap: () => context.go('/putrace/contacts'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

