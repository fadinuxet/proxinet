import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/professional_serendipity_engine.dart';
import '../../../../core/services/user_blocking_service.dart';
import '../../../../core/models/professional_intent.dart';
import '../../../../core/services/user_tier_service.dart';
import '../../../../core/models/user_tier.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/anonymous_user_service.dart';
import '../../../../core/services/anonymous_ble_service.dart';

class EnhancedUserCard extends StatefulWidget {
  final dynamic user; // Can be UserProfile or AnonymousUserProfile
  final VoidCallback? onTap;
  final VoidCallback? onSendHi;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;
  final bool showBlockOption;
  final String? context; // e.g., "nearby", "event", "virtual"

  const EnhancedUserCard({
    Key? key,
    required this.user,
    this.onTap,
    this.onSendHi,
    this.onBlock,
    this.onUnblock,
    this.showBlockOption = true,
    this.context,
  }) : super(key: key);

  @override
  State<EnhancedUserCard> createState() => _EnhancedUserCardState();
}

class _EnhancedUserCardState extends State<EnhancedUserCard> {
  final ProfessionalSerendipityEngine _serendipityEngine = ProfessionalSerendipityEngine();
  final UserBlockingService _blockingService = UserBlockingService();
  final UserTierService _userTierService = UserTierService();

  OpportunityScore? _opportunityScore;
  bool _isLoading = true;
  bool _isBlocked = false;
  UserTier _currentTier = UserTier.anonymous;

  @override
  void initState() {
    super.initState();
    _initializeCard();
  }

  Future<void> _initializeCard() async {
    try {
      // Get current user tier
      _currentTier = _userTierService.currentTier;

      // Calculate opportunity score
      _opportunityScore = await _serendipityEngine.calculateOpportunityScore(
        _getCurrentUser(),
        widget.user,
        context: widget.context,
      );

      // Check if user is blocked
      _isBlocked = await _blockingService.isUserBlocked(_getUserId());

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing enhanced user card: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  dynamic _getCurrentUser() {
    // This would get the current user profile
    // For now, return a placeholder
    return null;
  }

  String _getUserId() {
    if (widget.user is UserProfile) {
      return (widget.user as UserProfile).id;
    } else if (widget.user is AnonymousUserProfile) {
      return (widget.user as AnonymousUserProfile).sessionId;
    }
    return '';
  }

  String _getUserName() {
    if (widget.user is UserProfile) {
      return (widget.user as UserProfile).name;
    } else if (widget.user is AnonymousUserProfile) {
      return (widget.user as AnonymousUserProfile).displayName;
    } else if (widget.user is AnonymousBLEDevice) {
      return (widget.user as AnonymousBLEDevice).userData.displayName;
    }
    return 'Unknown User';
  }

  String _getUserTitle() {
    if (widget.user is UserProfile) {
      return (widget.user as UserProfile).title ?? 'Professional';
    } else if (widget.user is AnonymousUserProfile) {
      return (widget.user as AnonymousUserProfile).role;
    } else if (widget.user is AnonymousBLEDevice) {
      return (widget.user as AnonymousBLEDevice).userData.role;
    }
    return 'Professional';
  }

  String _getUserCompany() {
    if (widget.user is UserProfile) {
      return (widget.user as UserProfile).company ?? 'Unknown Company';
    } else if (widget.user is AnonymousUserProfile) {
      return (widget.user as AnonymousUserProfile).company ?? 'Unknown Company';
    } else if (widget.user is AnonymousBLEDevice) {
      return (widget.user as AnonymousBLEDevice).userData.company ?? 'Unknown Company';
    }
    return 'Unknown Company';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_isBlocked) {
      return _buildBlockedCard();
    }

    return _buildEnhancedCard();
  }

  Widget _buildLoadingCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(
              'Analyzing professional opportunity...',
              style: GoogleFonts.inter(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.block,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This user has been blocked',
                style: GoogleFonts.inter(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (widget.onUnblock != null)
              TextButton(
                onPressed: widget.onUnblock,
                child: Text('Unblock'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final score = _opportunityScore;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: score?.isHighValue == true ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: score?.isHighValue == true 
              ? colorScheme.primary.withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with opportunity score
              _buildHeader(score),
              
              const SizedBox(height: 12),
              
              // Professional insights
              if (score?.isHighValue == true) _buildHighValueInsights(score!),
              
              const SizedBox(height: 12),
              
              // User info
              _buildUserInfo(),
              
              const SizedBox(height: 12),
              
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(OpportunityScore? score) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        // User avatar
        CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.2),
          child: Text(
            _getUserName().isNotEmpty ? _getUserName()[0].toUpperCase() : '?',
            style: GoogleFonts.inter(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // User name and title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getUserName(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                _getUserTitle(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        
        // Opportunity score badge
        if (score != null) _buildOpportunityScoreBadge(score),
      ],
    );
  }

  Widget _buildOpportunityScoreBadge(OpportunityScore score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: score.scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: score.scoreColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            score.isHighValue ? Icons.star : Icons.trending_up,
            color: score.scoreColor,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            score.displayScore,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: score.scoreColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighValueInsights(OpportunityScore score) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'High-Value Opportunity',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          if (score.primaryOpportunity != null)
            Text(
              score.primaryOpportunity!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          
          if (score.insights.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...score.insights.take(2).map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Icon(
          Icons.business,
          color: colorScheme.onSurface.withOpacity(0.5),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getUserCompany(),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        
        // Context indicator
        if (widget.context != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.context!.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    final score = _opportunityScore;
    
    return Row(
      children: [
        // Send Hi button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.onSendHi,
            icon: const Icon(Icons.waving_hand, size: 16),
            label: Text(
              score?.isHighValue == true ? 'Strategic Hi' : 'Send Hi',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: score?.isHighValue == true 
                  ? colorScheme.primary 
                  : colorScheme.primary.withOpacity(0.8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Quick action for high-value opportunities
        if (score?.isHighValue == true)
          ElevatedButton.icon(
            onPressed: () => _showQuickActions(),
            icon: const Icon(Icons.flash_on, size: 16),
            label: const Text('Quick'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        
        const SizedBox(width: 8),
        
        // Block option
        if (widget.showBlockOption)
          IconButton(
            onPressed: () => _showBlockDialog(),
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
          ),
      ],
    );
  }

  void _showQuickActions() {
    final score = _opportunityScore;
    if (score == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...score.suggestedActions.take(3).map((action) => ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(action),
              onTap: () {
                Navigator.pop(context);
                // Handle quick action
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${_getUserName()}?'),
        content: const Text('This will prevent all future interactions with this user.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onBlock?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}
