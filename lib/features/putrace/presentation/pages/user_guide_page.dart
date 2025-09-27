import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class UserGuidePage extends StatelessWidget {
  const UserGuidePage({super.key});

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
              'Putrace',
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
              context.go('/putrace');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.1),
                    scheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 48,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Putrace!',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your guide to networking with people nearby',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Start Guide
            _buildSection(
              title: '🚀 Quick Start',
              icon: Icons.rocket_launch,
              color: Colors.blue,
              children: [
                _buildStep(
                  number: '1',
                  title: 'Enable Location',
                  description:
                      'Allow Putrace to access your location to discover people nearby',
                  icon: Icons.location_on,
                ),
                _buildStep(
                  number: '2',
                  title: 'Go to Discover',
                  description:
                      'Tap the Discover tab to see people in your area',
                  icon: Icons.explore,
                ),
                _buildStep(
                  number: '3',
                  title: 'Connect & Chat',
                  description:
                      'Send connection requests and start conversations',
                  icon: Icons.chat,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Main Features
            _buildSection(
              title: '⭐ Main Features',
              icon: Icons.star,
              color: Colors.amber,
              children: [
                _buildFeature(
                  icon: Icons.explore,
                  title: 'Discover Tab',
                  description: 'Find people nearby and see who\'s in your area',
                  color: Colors.blue,
                ),
                _buildFeature(
                  icon: Icons.chat,
                  title: 'Messages Tab',
                  description:
                      'Chat with your connections and manage conversations',
                  color: Colors.green,
                ),
                _buildFeature(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  description:
                      'Get alerts when contacts are nearby or new people are discovered',
                  color: Colors.orange,
                ),
                _buildFeature(
                  icon: Icons.settings,
                  title: 'Settings Tab',
                  description:
                      'Manage your privacy, profile, and app preferences',
                  color: Colors.purple,
                ),
                _buildFeature(
                  icon: Icons.person,
                  title: 'Profile Tab',
                  description: 'View and edit your profile information',
                  color: Colors.teal,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // How to Use
            _buildSection(
              title: '📖 How to Use',
              icon: Icons.book,
              color: Colors.green,
              children: [
                _buildHowTo(
                  title: 'Finding People Nearby',
                  steps: [
                    'Go to the Discover tab',
                    'Make sure location is enabled',
                    'See people within your discovery radius',
                    'Tap on profiles to view details',
                    'Send connection requests',
                  ],
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildHowTo(
                  title: 'Managing Connections',
                  steps: [
                    'Check the Messages tab for conversations',
                    'View connection requests in notifications',
                    'Accept or decline requests',
                    'Start chatting with your connections',
                    'Manage your network from the Profile tab',
                  ],
                  icon: Icons.handshake,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildHowTo(
                  title: 'Staying Updated',
                  steps: [
                    'Check the notification bell for alerts',
                    'Get proximity alerts when contacts are nearby',
                    'Discover new networking opportunities',
                    'Stay informed about your area',
                  ],
                  icon: Icons.notifications_active,
                  color: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tips & Tricks
            _buildSection(
              title: '💡 Tips & Tricks',
              icon: Icons.lightbulb,
              color: Colors.amber,
              children: [
                _buildTip(
                  icon: Icons.location_on,
                  title: 'Location Matters',
                  description:
                      'Enable location services for the best networking experience',
                  color: Colors.blue,
                ),
                _buildTip(
                  icon: Icons.privacy_tip,
                  title: 'Privacy First',
                  description: 'Control who can see you in the Settings tab',
                  color: Colors.green,
                ),
                _buildTip(
                  icon: Icons.update,
                  title: 'Keep Updated',
                  description:
                      'Check notifications regularly for networking opportunities',
                  color: Colors.orange,
                ),
                _buildTip(
                  icon: Icons.person,
                  title: 'Complete Profile',
                  description:
                      'Fill out your profile to make better connections',
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Need Help Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 32,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Need More Help?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you have questions or need assistance, check the Settings tab for support options.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/simple-guide'),
                          icon: const Icon(Icons.description),
                          label: const Text('Simple Guide'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.go('/putrace'),
                          icon: const Icon(Icons.check),
                          label: const Text('Got It'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
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
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowTo({
    required String title,
    required List<String> steps,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTip({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
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
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
