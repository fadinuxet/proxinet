import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/professional_auth_service.dart';
import '../../../../core/services/ble_conference_mode_service.dart';
import '../../../../core/models/user_profile.dart';

/// Clean, Minimal Main Screen - Focused on Core Putrace Actions
/// 
/// Design Philosophy:
/// - Maximum 4 core actions (not 8!)
/// - Clear visual hierarchy
/// - Privacy-first messaging
/// - Professional networking focus
class CleanMainScreen extends StatefulWidget {
  const CleanMainScreen({super.key});

  @override
  State<CleanMainScreen> createState() => _CleanMainScreenState();
}

class _CleanMainScreenState extends State<CleanMainScreen> {
  late final ProfessionalAuthService _professionalAuth;
  late final BLEConferenceModeService _conferenceMode;
  
  ProfessionalIdentity? _professionalIdentity;
  bool _isConferenceModeActive = false;
  final int _discoveredProfessionals = 0;

  @override
  void initState() {
    super.initState();
    _professionalAuth = GetIt.instance<ProfessionalAuthService>();
    _conferenceMode = GetIt.instance<BLEConferenceModeService>();
    _loadProfessionalIdentity();
    
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
      // Log error but don't throw - this is a background operation
      debugPrint('Error loading professional identity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Privacy Status
              _buildHeader(colorScheme),
              const SizedBox(height: 32),
              
              // Core Putrace Actions (Only 4!)
              _buildCoreActions(colorScheme),
              const SizedBox(height: 32),
              
              // Professional Identity Card
              if (_professionalIdentity != null) ...[
                _buildProfessionalIdentityCard(colorScheme),
                const SizedBox(height: 24),
              ],
              
              // Conference Mode Status
              _buildConferenceModeStatus(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.network_check,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Putrace',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Professional Proximity Networking',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Privacy Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Privacy-First',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
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

  Widget _buildCoreActions(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Core Actions',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        
        // 2x2 Grid of Core Actions
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildCoreActionCard(
                    icon: Icons.radar,
                    title: 'Find Nearby',
                    subtitle: 'Discover professionals around you',
                    color: colorScheme.primary,
                    onTap: () => context.push('/putrace/nearby'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCoreActionCard(
                    icon: Icons.location_on,
                    title: 'Go Available',
                    subtitle: 'Share your location & availability',
                    color: colorScheme.secondary,
                    onTap: () => context.push('/putrace/available'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCoreActionCard(
                    icon: Icons.message,
                    title: 'Messages',
                    subtitle: 'Secure professional chat',
                    color: colorScheme.tertiary,
                    onTap: () => context.push('/putrace/messages'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCoreActionCard(
                    icon: Icons.people,
                    title: 'Network',
                    subtitle: 'Manage your connections',
                    color: Colors.green,
                    onTap: () => context.push('/putrace/connections'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoreActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalIdentityCard(ColorScheme colorScheme) {
    if (_professionalIdentity == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_center, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Professional Identity',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _professionalIdentity!.displayName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          if (_professionalIdentity!.company != null) ...[
            const SizedBox(height: 4),
            Text(
              _professionalIdentity!.company!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                'End-to-end encrypted',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConferenceModeStatus(ColorScheme colorScheme) {
    if (!_isConferenceModeActive) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conference Mode Active',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  'Discovering professionals nearby without internet',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blue.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$_discoveredProfessionals',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
