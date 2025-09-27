import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/user_tier_service.dart';
import '../../../../core/services/anonymous_ble_service.dart';
import '../../../../core/services/connection_request_service.dart';
import '../../../../core/services/user_blocking_service.dart';
import '../../../../core/services/professional_serendipity_engine.dart';
import '../../../../core/models/user_tier.dart';
import '../widgets/enhanced_user_card.dart';
import '../widgets/enhanced_hi_dialog.dart';

class NearbyUsersListPage extends StatefulWidget {
  const NearbyUsersListPage({super.key});

  @override
  State<NearbyUsersListPage> createState() => _NearbyUsersListPageState();
}

class _NearbyUsersListPageState extends State<NearbyUsersListPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Services
  final UserTierService _userTierService = GetIt.instance<UserTierService>();
  final AnonymousBLEService _anonymousBLEService = GetIt.instance<AnonymousBLEService>();
  final ConnectionRequestService _connectionRequestService = GetIt.instance<ConnectionRequestService>();
  final UserBlockingService _blockingService = GetIt.instance<UserBlockingService>();
  final ProfessionalSerendipityEngine _serendipityEngine = GetIt.instance<ProfessionalSerendipityEngine>();
  
  // Real data
  List<AnonymousBLEDevice> _anonymousBLEDevices = [];
  List<Map<String, dynamic>> _combinedUsers = [];
  
  // State
  bool _isScanning = false;
  bool _isLoading = true;
  UserTier _currentTier = UserTier.anonymous;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
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
    
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeServices() async {
    try {
      // Get current user tier
      _currentTier = _userTierService.currentTier;
      
      // Listen to tier changes
      _userTierService.tierStream.listen((tier) {
        if (mounted) {
          setState(() {
            _currentTier = tier;
          });
        }
      });
      
      // Listen to anonymous BLE devices
      _anonymousBLEService.nearbyDevicesStream.listen((devices) {
        if (mounted) {
          debugPrint('NearbyUsersListPage: Received ${devices.length} devices from BLE service');
          setState(() {
            _anonymousBLEDevices = devices;
            _updateCombinedUsers();
          });
          
          // Start pulse animation when no devices found, stop when devices found
          if (_combinedUsers.isEmpty) {
            _pulseController.repeat();
          } else {
            _pulseController.stop();
          }
        }
      });
      
      // Note: BLE and user discovery services are not available in this implementation
      // Only anonymous BLE devices are supported for now
      
      // Set loading to false immediately - we don't show scanning indicators
      setState(() {
        _isLoading = false;
      });
      
      // Initialize connection request service
      await _connectionRequestService.initialize();
      
      // Start scanning if not already active
      if (_currentTier.isAnonymous) {
        await _anonymousBLEService.startScanning();
      }
      // Note: Authenticated user scanning not implemented yet
      
    } catch (e) {
      debugPrint('Error initializing services: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateCombinedUsers() {
    final combined = <Map<String, dynamic>>[];
    final addedIds = <String>{};
    
    // Add anonymous BLE devices (prevent duplicates by device ID)
    for (final device in _anonymousBLEDevices) {
      if (!addedIds.contains(device.id)) {
        addedIds.add(device.id);
        combined.add({
          'id': device.id,
          'name': device.userData.displayName,
          'title': device.userData.role,
          'company': device.userData.company ?? 'Unknown',
          'distance': device.distance.round(),
          'status': 'Available via BLE',
          'avatar': device.userData.role.isNotEmpty ? device.userData.role[0].toUpperCase() : 'A',
          'color': _getColorForUser(device.userData.role),
          'skills': [device.userData.role],
          'availability': 'Now',
          'type': 'anonymous_ble',
          'device': device,
        });
        debugPrint('Added device: ${device.userData.displayName} (${device.userData.company})');
      } else {
        debugPrint('Skipped duplicate device: ${device.id}');
      }
    }
    
    setState(() {
      _combinedUsers = combined;
    });
  }

  Color _getColorForUser(String name) {
    final colors = [
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.blue,
      Colors.teal,
      Colors.red,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.deepOrange,
    ];
    
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  @override
  void dispose() {
    // Don't stop scanning when leaving the page - keep discovery active
    // This ensures devices remain available when user returns
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nearby Professionals',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Show animated refresh when no devices found, static refresh when devices exist
          _combinedUsers.isEmpty
              ? AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _pulseAnimation.value * 2 * 3.14159, // Full rotation
                      child: IconButton(
                        onPressed: _refreshNearbyUsers,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Scanning...',
                      ),
                    );
                  },
                )
              : IconButton(
                  onPressed: _refreshNearbyUsers,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
        ],
      ),
      body: Column(
        children: [
          // Pulse visualization header
          _buildPulseHeader(),
          
          // Users list
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseHeader() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Pulse rings
                _buildPulseRing(80, 0.3),
                _buildPulseRing(60, 0.5),
                
                // Center user (you)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                
                // Count badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_combinedUsers.length} nearby',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPulseRing(double size, double opacity) {
    return Container(
      width: size * _pulseAnimation.value,
      height: size * _pulseAnimation.value,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.blue.withValues(alpha: opacity * (1 - _pulseAnimation.value)),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_combinedUsers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _combinedUsers.length,
      itemBuilder: (context, index) {
        final user = _combinedUsers[index];
        return _buildUserCard(user, index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No nearby professionals found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isScanning 
                ? 'Keep scanning...' 
                : 'Tap refresh to scan again',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          // Scan Again button removed - automatic scanning is active
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    // Use the enhanced user card with professional serendipity features
    return EnhancedUserCard(
      user: user['device'] as AnonymousBLEDevice, // Pass the actual AnonymousBLEDevice object
      onTap: () => _viewUserProfile(user),
      onSendHi: () => _sendHiToUser(user),
      onBlock: () => _blockUser(user),
      onUnblock: () => _unblockUser(user),
      showBlockOption: true,
      context: 'nearby',
    );
  }

  void _sendHiToUser(Map<String, dynamic> user) async {
    // Calculate opportunity score for enhanced hi dialog
    final opportunityScore = await _serendipityEngine.calculateOpportunityScore(
      _getCurrentUser(),
      user['device'] ?? user,
      context: 'nearby',
    );

    // Show enhanced hi dialog with professional context
    showDialog(
      context: context,
      builder: (context) => EnhancedHiDialog(
        targetUser: user['device'] ?? user,
        opportunityScore: opportunityScore,
        onSend: () => _handleSendHi(user, _customMessage),
        onBlock: () => _blockUser(user),
        onCancel: () {},
      ),
    );
  }

  String _customMessage = '';

  dynamic _getCurrentUser() {
    // This would get the current user profile
    // For now, return a placeholder
    return null;
  }

  void _showAnonymousMessagingDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Hi to ${user['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You can send a quick "Hi" message to this nearby professional.'),
            const SizedBox(height: 16),
            Text(
              'Note: As an anonymous user, you can only send basic messages. Sign up for full messaging capabilities.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAnonymousHi(user);
            },
            child: const Text('Send Hi'),
          ),
        ],
      ),
    );
  }

  void _handleAnonymousHi(Map<String, dynamic> user) async {
    // For anonymous users, send a simple BLE message
    try {
      final deviceId = user['id'] as String;
      await _anonymousBLEService.sendMessage(deviceId, 'Hi! 👋');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Hi sent to ${user['name']}! 👋'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send Hi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _blockUser(Map<String, dynamic> user) async {
    try {
      final userId = user['id'] as String;
      final userName = user['name'] as String;
      final userCompany = user['company'] as String;
      
      final success = await _blockingService.blockUser(
        userId,
        reason: BlockReason.professionalConflict,
        notes: 'Blocked from nearby users list',
        userName: userName,
        userCompany: userCompany,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked ${userName}'),
            backgroundColor: Colors.orange,
          ),
        );
        // Refresh the list to remove blocked user
        _updateCombinedUsers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to block user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _unblockUser(Map<String, dynamic> user) async {
    try {
      final userId = user['id'] as String;
      final userName = user['name'] as String;
      
      final success = await _blockingService.unblockUser(userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unblocked ${userName}'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list to show unblocked user
        _updateCombinedUsers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unblock user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleSendHi(Map<String, dynamic> user, String message) {
    try {
      // Implement actual Hi message sending based on user type
      final userType = user['type'] as String;
      
      if (userType == 'anonymous_ble') {
        // Send BLE message to anonymous user
        _sendBLEMessage(user, message);
      } else if (userType == 'authenticated') {
        // Send Firebase message to authenticated user
        _sendFirebaseMessage(user, message);
      } else {
        // Default handling
        _sendDefaultMessage(user, message);
      }
      
      Navigator.pop(context);
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Hi sent to ${user['name']}! 👋'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      
      // Optional: Show follow-up options
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _showFollowUpOptions(user);
        }
      });
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send Hi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendBLEMessage(Map<String, dynamic> user, String message) async {
    try {
      final deviceId = user['id'] as String;
      await _anonymousBLEService.sendMessage(deviceId, message);
      debugPrint('BLE message sent to ${user['name']}: $message');
    } catch (e) {
      debugPrint('Failed to send BLE message: $e');
      rethrow;
    }
  }

  void _sendFirebaseMessage(Map<String, dynamic> user, String message) {
    // TODO: Implement Firebase messaging
    // This would use Firebase Cloud Messaging or Firestore
    debugPrint('Sending Firebase message to ${user['name']}: $message');
  }

  void _sendDefaultMessage(Map<String, dynamic> user, String message) {
    // Default message handling
    debugPrint('Sending default message to ${user['name']}: $message');
  }

  void _showFollowUpOptions(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Great! You said hi to ${user['name']}'),
        content: const Text(
          'What would you like to do next? You can connect for a longer conversation or view their full profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToUser(user);
            },
            child: const Text('Connect'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _viewUserProfile(user);
            },
            child: const Text('View Profile'),
          ),
        ],
      ),
    );
  }

  void _connectToUser(Map<String, dynamic> user) {
    // Check if user can connect (not anonymous)
    if (_currentTier.isAnonymous) {
      _showUpgradeDialog('Connect with professionals');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ConnectionRequestDialog(
        user: user,
        onSend: (message) => _handleConnectionRequest(user, message),
      ),
    );
  }

  void _showUpgradeDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade Required'),
        content: Text('Sign up to $feature and unlock more networking features.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to signup flow
            },
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }

  void _handleConnectionRequest(Map<String, dynamic> user, String message) async {
    try {
      final userType = user['type'] as String;
      
      // For now, only anonymous BLE users are supported
      // Connection requests to authenticated users require full implementation
      _showUpgradeDialog('Connect with authenticated users');
      return;
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${user['name']}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send connection request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewUserProfile(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _UserProfileDialog(
        user: user,
        currentTier: _currentTier,
        onConnect: () {
          Navigator.pop(context);
          _connectToUser(user);
        },
      ),
    );
  }


  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _refreshNearbyUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger new BLE scan
      if (_currentTier.isAnonymous) {
        await _anonymousBLEService.startScanning();
      }
      // Note: Authenticated user scanning not implemented yet

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning for nearby professionals...'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _SendHiDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String) onSend;

  const _SendHiDialog({
    required this.user,
    required this.onSend,
  });

  @override
  State<_SendHiDialog> createState() => _SendHiDialogState();
}

class _SendHiDialogState extends State<_SendHiDialog> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _quickMessages = [
    'Hi! 👋',
    'Nice to meet you!',
    'Hello from nearby!',
    'Hi there!',
    'Hey! 👋',
    'Good to see you here!',
  ];

  @override
  void initState() {
    super.initState();
    _messageController.text = _quickMessages.first;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: widget.user['color'],
            child: Text(
              widget.user['avatar'],
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Say Hi to ${widget.user['name']}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${widget.user['title']} at ${widget.user['company']}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
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
            'Choose a quick message or write your own:',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          
          // Quick message chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickMessages.map((message) {
              final isSelected = _messageController.text == message;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _messageController.text = message;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isSelected 
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Custom message field
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Custom message',
              hintText: 'Type your own message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            maxLines: 2,
            maxLength: 100,
            style: GoogleFonts.inter(
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final message = _messageController.text.trim();
            if (message.isNotEmpty) {
              widget.onSend(message);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.send, size: 16),
              const SizedBox(width: 8),
              Text(
                'Send Hi',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionRequestDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String) onSend;

  const _ConnectionRequestDialog({
    required this.user,
    required this.onSend,
  });

  @override
  State<_ConnectionRequestDialog> createState() => _ConnectionRequestDialogState();
}

class _ConnectionRequestDialogState extends State<_ConnectionRequestDialog> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Connect with ${widget.user['name']}',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Send a connection request to ${widget.user['name']}?',
            style: GoogleFonts.inter(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Add a message (optional)',
              hintText: 'Hi! I\'d love to connect...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            maxLines: 3,
            style: GoogleFonts.inter(
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final message = _messageController.text.trim();
            widget.onSend(message);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Send Request',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserProfileDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  final UserTier currentTier;
  final VoidCallback onConnect;

  const _UserProfileDialog({
    required this.user,
    required this.currentTier,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        '${user['name']}\'s Profile',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: user['color'],
                child: Text(
                  user['avatar'],
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${user['title']} at ${user['company']}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${user['distance']}m away • ${user['availability']}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Skills:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (user['skills'] as List<String>).map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: user['color'].withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    skill,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: user['color'],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${user['status']}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.inter(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        if (currentTier.isStandard || currentTier.isPremium)
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Connect',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
