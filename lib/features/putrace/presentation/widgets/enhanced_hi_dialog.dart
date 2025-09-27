import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/professional_serendipity_engine.dart';
import '../../../../core/services/user_blocking_service.dart';
import '../../../../core/models/professional_intent.dart';
import '../../../../core/services/user_tier_service.dart';
import '../../../../core/models/user_tier.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/anonymous_user_service.dart';

class EnhancedHiDialog extends StatefulWidget {
  final dynamic targetUser; // Can be UserProfile or AnonymousUserProfile
  final OpportunityScore? opportunityScore;
  final VoidCallback? onSend;
  final VoidCallback? onBlock;
  final VoidCallback? onCancel;

  const EnhancedHiDialog({
    Key? key,
    required this.targetUser,
    this.opportunityScore,
    this.onSend,
    this.onBlock,
    this.onCancel,
  }) : super(key: key);

  @override
  State<EnhancedHiDialog> createState() => _EnhancedHiDialogState();
}

class _EnhancedHiDialogState extends State<EnhancedHiDialog> {
  final ProfessionalSerendipityEngine _serendipityEngine = ProfessionalSerendipityEngine();
  final UserTierService _userTierService = UserTierService();
  
  ProfessionalIntent? _selectedIntent;
  String _customMessage = '';
  List<String> _aiIcebreakers = [];
  bool _isLoadingIcebreakers = true;
  UserTier _currentTier = UserTier.anonymous;

  @override
  void initState() {
    super.initState();
    _initializeDialog();
  }

  Future<void> _initializeDialog() async {
    try {
      _currentTier = _userTierService.currentTier;
      
      // Generate AI icebreakers
      if (widget.opportunityScore != null) {
        _aiIcebreakers = await _serendipityEngine.generateAIIcebreakers(
          _getCurrentUser(),
          widget.targetUser,
          widget.opportunityScore!,
        );
      }
      
      setState(() {
        _isLoadingIcebreakers = false;
      });
    } catch (e) {
      debugPrint('Error initializing enhanced hi dialog: $e');
      setState(() {
        _isLoadingIcebreakers = false;
      });
    }
  }

  dynamic _getCurrentUser() {
    // This would get the current user profile
    // For now, return a placeholder
    return null;
  }

  String _getTargetUserName() {
    if (widget.targetUser is UserProfile) {
      return (widget.targetUser as UserProfile).name;
    } else if (widget.targetUser is AnonymousUserProfile) {
      return (widget.targetUser as AnonymousUserProfile).displayName;
    }
    return 'Professional';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            Icons.waving_hand,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Connect with ${_getTargetUserName()}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opportunity context
            if (widget.opportunityScore != null) _buildOpportunityContext(),
            
            const SizedBox(height: 16),
            
            // Professional intent selection
            _buildIntentSelector(),
            
            const SizedBox(height: 16),
            
            // AI-generated icebreakers
            _buildAIIcebreakers(),
            
            const SizedBox(height: 16),
            
            // Custom message
            _buildCustomMessageField(),
          ],
        ),
      ),
      actions: [
        // Block button
        TextButton.icon(
          onPressed: () => _showBlockDialog(),
          icon: const Icon(Icons.block, size: 16),
          label: const Text('Block'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
        
        const Spacer(),
        
        // Cancel button
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onCancel?.call();
          },
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: colorScheme.onSurface),
          ),
        ),
        
        // Send button
        ElevatedButton(
          onPressed: _canSend() ? _sendHi : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Send Hi',
            style: GoogleFonts.inter(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunityContext() {
    final colorScheme = Theme.of(context).colorScheme;
    final score = widget.opportunityScore!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: score.scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: score.scoreColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                score.isHighValue ? Icons.star : Icons.trending_up,
                color: score.scoreColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                score.displayScore,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: score.scoreColor,
                ),
              ),
            ],
          ),
          
          if (score.primaryOpportunity != null) ...[
            const SizedBox(height: 8),
            Text(
              score.primaryOpportunity!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ],
          
          if (score.urgencyLevel == 'high') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Time-sensitive opportunity',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntentSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final availableIntents = ProfessionalIntent.getIntentsForUserTier(_currentTier.isPremium);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Intent',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: availableIntents.length,
            itemBuilder: (context, index) {
              final intent = availableIntents[index];
              final isSelected = _selectedIntent?.type == intent.type;
              
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 8),
                child: Card(
                  color: isSelected 
                      ? colorScheme.primary.withOpacity(0.1)
                      : colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected 
                          ? colorScheme.primary 
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedIntent = intent),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            intent.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                  ? colorScheme.primary 
                                  : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            intent.description,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 12,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                intent.durationDisplay,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAIIcebreakers() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI-Generated Icebreakers',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        
        if (_isLoadingIcebreakers)
          const Center(child: CircularProgressIndicator())
        else if (_aiIcebreakers.isEmpty)
          Text(
            'No icebreakers available',
            style: GoogleFonts.inter(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ..._aiIcebreakers.map((icebreaker) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: colorScheme.primary,
                size: 20,
              ),
              title: Text(
                icebreaker,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              onTap: () => setState(() => _customMessage = icebreaker),
              trailing: _customMessage == icebreaker
                  ? Icon(
                      Icons.check_circle,
                      color: colorScheme.primary,
                      size: 20,
                    )
                  : null,
            ),
          )),
      ],
    );
  }

  Widget _buildCustomMessageField() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Message',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) => setState(() => _customMessage = value),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Type your message here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
          ),
          style: GoogleFonts.inter(color: colorScheme.onSurface),
        ),
      ],
    );
  }

  bool _canSend() {
    return _selectedIntent != null && _customMessage.isNotEmpty;
  }

  void _sendHi() {
    if (!_canSend()) return;
    
    // Create the hi message with intent
    final hiMessage = {
      'intent': _selectedIntent!.toMap(),
      'message': _customMessage,
      'timestamp': DateTime.now().toIso8601String(),
      'opportunityScore': widget.opportunityScore?.overall,
    };
    
    Navigator.of(context).pop();
    widget.onSend?.call();
    
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hi sent to ${_getTargetUserName()}!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${_getTargetUserName()}?'),
        content: const Text('This will prevent all future interactions with this user.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close block dialog
              Navigator.pop(context); // Close hi dialog
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
