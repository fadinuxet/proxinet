import 'package:flutter/material.dart';
import '../../../../core/services/user_tier_service.dart';

class FeatureGateWidget extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? lockedChild;
  
  const FeatureGateWidget({
    Key? key,
    required this.feature,
    required this.child,
    this.lockedChild,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final userTierService = UserTierService();
    
    if (userTierService.canAccessFeature(feature)) {
      return child;
    }
    
    return lockedChild ?? _buildLockedFeature(context, feature);
  }
  
  Widget _buildLockedFeature(BuildContext context, String feature) {
    final userTierService = UserTierService();
    final message = userTierService.getFeatureUpgradeMessage(feature);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, color: Colors.grey, size: 32),
          SizedBox(height: 8),
          Text(
            'Feature Locked',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _showUpgradeDialog(context, feature),
            child: Text('Upgrade'),
          ),
        ],
      ),
    );
  }
  
  void _showUpgradeDialog(BuildContext context, String feature) {
    final userTierService = UserTierService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade Required'),
        content: Text(userTierService.getFeatureUpgradeMessage(feature)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to upgrade flow
            },
            child: Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}
