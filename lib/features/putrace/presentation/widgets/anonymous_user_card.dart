import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/anonymous_user_service.dart';
import '../../../../core/models/user_tier.dart';

class AnonymousUserCard extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  
  const AnonymousUserCard({
    Key? key,
    this.onTap,
    this.onEdit,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final anonymousUserService = AnonymousUserService();
    
    return StreamBuilder<AnonymousUserProfile>(
      stream: anonymousUserService.profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? anonymousUserService.currentProfile;
        
        if (profile == null) {
          return _buildEmptyCard(context, colorScheme);
        }
        
        return _buildProfileCard(context, colorScheme, profile);
      },
    );
  }
  
  Widget _buildEmptyCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_outline,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Anonymous User',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to set up your profile',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileCard(BuildContext context, ColorScheme colorScheme, AnonymousUserProfile profile) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.visibility_off,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FREE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        profile.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 18,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Profile info
            if (profile.company != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile.company!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            // Status
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Discoverable via BLE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Features
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildFeatureChip('BLE Discovery', true, colorScheme),
                _buildFeatureChip('Anonymous Profiles', true, colorScheme),
                _buildFeatureChip('Location Mode', false, colorScheme),
                _buildFeatureChip('Virtual Mode', false, colorScheme),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureChip(String label, bool enabled, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled 
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled 
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.lock,
            color: enabled ? Colors.green : Colors.grey,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: enabled ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
