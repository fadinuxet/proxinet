import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EnhancedQuickActions extends StatelessWidget {
  const EnhancedQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildQuickActionsGrid(context),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      // Core Putrace Features
      _QuickAction(
        icon: Icons.bluetooth_searching,
        title: 'Go Available',
        description: 'Start BLE proximity mode',
        color: Colors.purple,
        onTap: () => _handleGoAvailable(context),
      ),
      _QuickAction(
        icon: Icons.location_on,
        title: 'Set Location',
        description: 'Available at specific venue',
        color: Colors.blue,
        onTap: () => _handleSetLocation(context),
      ),
      _QuickAction(
        icon: Icons.language,
        title: 'Global Mode',
        description: 'Virtual networking worldwide',
        color: Colors.green,
        onTap: () => _handleGlobalMode(context),
      ),
      
      // Networking & Discovery
      _QuickAction(
        icon: Icons.people,
        title: 'Nearby People',
        description: 'Discover people around you',
        color: Colors.orange,
        onTap: () => _handleNearbyPeople(context),
      ),
      _QuickAction(
        icon: Icons.event,
        title: 'Event Mode',
        description: 'Network at events',
        color: Colors.red,
        onTap: () => _handleEventMode(context),
      ),
      _QuickAction(
        icon: Icons.search,
        title: 'Find Matches',
        description: 'Search by interests',
        color: Colors.teal,
        onTap: () => _handleFindMatches(context),
      ),
      
      // Content & Communication
      _QuickAction(
        icon: Icons.add_circle,
        title: 'New Post',
        description: 'Share your thoughts',
        color: Colors.indigo,
        onTap: () => _handleNewPost(context),
      ),
      _QuickAction(
        icon: Icons.chat_bubble,
        title: 'Quick Chat',
        description: 'Start conversations',
        color: Colors.pink,
        onTap: () => _handleQuickChat(context),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) => _buildActionCard(context, actions[index]),
    );
  }

  Widget _buildActionCard(BuildContext context, _QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              action.description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Action Handlers
  void _handleGoAvailable(BuildContext context) {
    // Navigate to BLE proximity availability setup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting BLE proximity mode...')),
    );
  }

  void _handleSetLocation(BuildContext context) {
    // Navigate to location-based availability setup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setting location availability...')),
    );
  }

  void _handleGlobalMode(BuildContext context) {
    // Navigate to global virtual availability setup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting global virtual mode...')),
    );
  }

  void _handleNearbyPeople(BuildContext context) {
    // Navigate to nearby people discovery
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Discovering nearby people...')),
    );
  }

  void _handleEventMode(BuildContext context) {
    // Navigate to event networking mode
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting event networking...')),
    );
  }

  void _handleFindMatches(BuildContext context) {
    // Navigate to interest-based matching
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finding matches by interests...')),
    );
  }

  void _handleNewPost(BuildContext context) {
    // Navigate to post creation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating new post...')),
    );
  }

  void _handleQuickChat(BuildContext context) {
    // Navigate to quick chat/messaging
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting quick chat...')),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });
}
