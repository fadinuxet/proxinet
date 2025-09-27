import 'package:flutter/material.dart';
import '../../../../core/models/user_tier.dart';
import '../../../../core/services/user_tier_service.dart';

class TierStatusIndicator extends StatelessWidget {
  final UserTierService _userTierService = UserTierService();
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserTier>(
      stream: _userTierService.tierStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }
        
        return _buildIndicatorForTier(snapshot.data!);
      },
    );
  }
  
  Widget _buildIndicatorForTier(UserTier tier) {
    switch (tier) {
      case UserTier.anonymous:
        return _buildAnonymousIndicator();
      case UserTier.standard:
        return _buildStandardIndicator();
      case UserTier.premium:
        return _buildPremiumIndicator();
    }
  }
  
  Widget _buildAnonymousIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off, color: Colors.grey, size: 16),
          SizedBox(width: 8),
          Text(
            'FREE',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStandardIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person, color: Colors.blue, size: 16),
          SizedBox(width: 8),
          Text(
            'Standard',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPremiumIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Colors.amber, size: 16),
          SizedBox(width: 8),
          Text(
            'Premium',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
