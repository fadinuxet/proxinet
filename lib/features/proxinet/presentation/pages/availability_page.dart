import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/serendipity_models.dart';
import '../../../../core/services/proxinet_presence_sync_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  bool _available = false;
  double _hours = 2;
  VisibilityAudience _audience = VisibilityAudience.firstDegree;
  bool _isSaving = false;
  bool _showGuidelines = false; // Track if we should show guidelines
  
  late final ProxinetPresenceSyncService _presenceSync;

  @override
  void initState() {
    super.initState();
    _presenceSync = GetIt.instance<ProxinetPresenceSyncService>();
    _loadCurrentAvailability();
  }

  // Load current availability status
  Future<void> _loadCurrentAvailability() async {
    try {
      // Initialize availability from Firestore
      await _presenceSync.initializeAvailabilityFromFirestore();
      
      // Update UI based on current status
      if (mounted) {
        setState(() {
          _available = _presenceSync.isAvailableForConnections;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading availability: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Refresh user's current location
  Future<void> _refreshLocation() async {
    try {
      setState(() => _isSaving = true);
      
      // Refresh availability location using the service
      await _presenceSync.refreshAvailabilityLocation();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('I am open to connect'),
            subtitle: const Text('Signal availability to your network'),
            value: _available,
            onChanged: (v) => setState(() => _available = v),
          ),
          ListTile(
            title: const Text('Auto-expire in'),
            subtitle: Text('${_hours.toStringAsFixed(0)} hours'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _hours,
                min: 1,
                max: 8,
                divisions: 7,
                onChanged: (v) => setState(() => _hours = v),
              ),
            ),
          ),
          _buildVisibilitySelector(),
          const SizedBox(height: 16),
          
          // Location Status Indicator
          if (_available) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location Services',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your current location will be automatically updated when you set availability. This helps others discover you nearby.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Refresh Location Button
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _refreshLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh My Location'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          _buildSaveButton(),
          if (!_showGuidelines && _available) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                '💡 Save to see connection guidelines',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ],
          if (_showGuidelines) ...[
            const SizedBox(height: 24),
            _buildConnectionGuidelines(),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showGuidelines = false),
                icon: const Icon(Icons.keyboard_arrow_up),
                label: const Text('Hide Guidelines'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisibilitySelector() {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who can see this?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _VisibilityIconButton(
                icon: Icons.person,
                label: '1st Degree',
                subtitle: 'Direct connections',
                isSelected: _audience == VisibilityAudience.firstDegree,
                color: scheme.primary,
                onTap: () =>
                    setState(() => _audience = VisibilityAudience.firstDegree),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VisibilityIconButton(
                icon: Icons.people,
                label: '2nd Degree',
                subtitle: 'Friends of friends',
                isSelected: _audience == VisibilityAudience.secondDegree,
                color: scheme.secondary,
                onTap: () =>
                    setState(() => _audience = VisibilityAudience.secondDegree),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VisibilityIconButton(
                icon: Icons.group,
                label: 'Custom Groups',
                subtitle: 'Selected audiences',
                isSelected: _audience == VisibilityAudience.custom,
                color: scheme.tertiary,
                onTap: () =>
                    setState(() => _audience = VisibilityAudience.custom),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _VisibilityIconButton(
                icon: Icons.public,
                label: 'Everyone',
                subtitle: 'All users in map area',
                isSelected: _audience == VisibilityAudience.everyone,
                color: Colors.green,
                onTap: () =>
                    setState(() => _audience = VisibilityAudience.everyone),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveAvailability,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                ),
              )
            : const Icon(Icons.save, size: 24),
        label: Text(
          _isSaving ? 'Saving...' : 'Save Availability',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionGuidelines() {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'How to Connect & Work Together',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuidelineItem(
            icon: Icons.near_me,
            title: 'Enable Nearby Discovery',
            description: 'Turn on nearby discovery to find people physically near you',
            action: 'Go to Nearby Page',
            onAction: () => context.push('/proxinet/nearby'),
            scheme: scheme,
          ),
          const SizedBox(height: 12),
          _buildGuidelineItem(
            icon: Icons.map,
            title: 'Use the Map View',
            description: 'See nearby people on a map and connect with them',
            action: 'Open Map',
            onAction: () => context.push('/proxinet/map'),
            scheme: scheme,
          ),
          const SizedBox(height: 12),
          _buildGuidelineItem(
            icon: Icons.message,
            title: 'Start Conversations',
            description: 'Send connection requests and start meaningful conversations',
            action: 'View Messages',
            onAction: () => context.push('/proxinet/messages'),
            scheme: scheme,
          ),
          const SizedBox(height: 12),
          _buildGuidelineItem(
            icon: Icons.group,
            title: 'Join Groups',
            description: 'Connect with like-minded people in your industry or interests',
            action: 'Browse Groups',
            onAction: () => context.push('/proxinet/groups'),
            scheme: scheme,
          ),
          const SizedBox(height: 12),
          _buildGuidelineItem(
            icon: Icons.people,
            title: 'See Available People',
            description: 'Browse all people who are currently available to connect',
            action: 'View Available',
            onAction: () => context.push('/proxinet/available-people'),
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pro tip: Combine availability with nearby discovery for maximum networking opportunities!',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem({
    required IconData icon,
    required String title,
    required String description,
    required String action,
    required VoidCallback onAction,
    required ColorScheme scheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: scheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              action,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAvailability() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Ensure auth is fresh
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Use the presence sync service for proper integration
      await _presenceSync.setAvailabilityForConnections(
        _available,
        audience: _audience,
        hours: _hours.toInt(),
      );

      // Show success popup
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Text('Success!'),
              ],
            ),
            content: Text(
              _available
                  ? 'Your availability status has been updated! People can now see that you\'re open to connect and your location has been updated.'
                  : 'Your availability status has been updated to closed.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Show guidelines after successful save
                  if (_available) {
                    setState(() => _showGuidelines = true);
                  }
                },
                child: const Text('Great!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text('Failed to save availability: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _VisibilityIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _VisibilityIconButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? color : null),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : null,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isSelected ? null : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
