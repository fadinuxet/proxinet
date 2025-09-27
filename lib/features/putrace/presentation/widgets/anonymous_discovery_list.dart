import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/anonymous_ble_service.dart';

class AnonymousDiscoveryList extends StatelessWidget {
  final VoidCallback? onUserTap;
  
  const AnonymousDiscoveryList({
    Key? key,
    this.onUserTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final anonymousBLEService = AnonymousBLEService();
    
    return StreamBuilder<List<AnonymousBLEDevice>>(
      stream: anonymousBLEService.nearbyDevicesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context, colorScheme);
        }
        
        return _buildDiscoveryList(context, colorScheme, snapshot.data!);
      },
    );
  }
  
  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return const SizedBox.shrink(); // Remove the empty state completely
  }
  
  Widget _buildDiscoveryList(BuildContext context, ColorScheme colorScheme, List<AnonymousBLEDevice> devices) {
    // Don't show devices on main screen anymore - they should only appear in "See All Nearby"
    return const SizedBox.shrink();
  }
  
  Widget _buildOldDiscoveryList(BuildContext context, ColorScheme colorScheme, List<AnonymousBLEDevice> devices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.radar,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Nearby Professionals (${devices.length})',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'BLE Discovery',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Device list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return _buildDeviceCard(context, colorScheme, device);
          },
        ),
      ],
    );
  }
  
  Widget _buildDeviceCard(BuildContext context, ColorScheme colorScheme, AnonymousBLEDevice device) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => onUserTap?.call(),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.shortDisplayName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Distance and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getProximityColor(device.proximity).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        device.proximity,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getProximityColor(device.proximity),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth,
                          color: Colors.blue,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${device.rssi} dBm',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getProximityColor(String proximity) {
    switch (proximity) {
      case 'Very Close':
        return Colors.red;
      case 'Close':
        return Colors.orange;
      case 'Nearby':
        return Colors.blue;
      case 'In Range':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
