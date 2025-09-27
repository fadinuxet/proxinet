import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SimpleGuidePage extends StatelessWidget {
  const SimpleGuidePage({super.key});

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
            // Title
            Text(
              'Putrace User Guide',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Simple guide to using Putrace for networking',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Getting Started
            _buildSection(
              title: 'Getting Started',
              children: [
                _buildFeature(
                  title: '1. Enable Location',
                  description: 'Allow Putrace to access your location',
                  expectation: 'You can see people nearby',
                  icon: Icons.location_on,
                  color: Colors.blue,
                ),
                _buildFeature(
                  title: '2. Go to Discover Tab',
                  description: 'Tap the first tab (Discover)',
                  expectation: 'See people in your area',
                  icon: Icons.explore,
                  color: Colors.green,
                ),
                _buildFeature(
                  title: '3. Start Networking',
                  description: 'Tap on profiles and send connection requests',
                  expectation: 'Build your professional network',
                  icon: Icons.people,
                  color: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Main Features
            _buildSection(
              title: 'Main Features',
              children: [
                _buildFeature(
                  title: 'Discover Tab',
                  description: 'Find people nearby',
                  expectation: 'See who is in your area for networking',
                  icon: Icons.explore,
                  color: Colors.blue,
                ),
                _buildFeature(
                  title: 'Messages Tab',
                  description: 'Chat with your connections',
                  expectation:
                      'Have conversations with people you\'ve connected with',
                  icon: Icons.chat,
                  color: Colors.green,
                ),
                _buildFeature(
                  title: 'Notifications',
                  description: 'Get alerts about nearby people',
                  expectation:
                      'Know when contacts are nearby or new people are discovered',
                  icon: Icons.notifications,
                  color: Colors.orange,
                ),
                _buildFeature(
                  title: 'Settings Tab',
                  description: 'Manage your app preferences',
                  expectation: 'Control privacy, profile, and app settings',
                  icon: Icons.settings,
                  color: Colors.purple,
                ),
                _buildFeature(
                  title: 'Profile Tab',
                  description: 'View and edit your profile',
                  expectation: 'Show your professional information to others',
                  icon: Icons.person,
                  color: Colors.teal,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // How Each Feature Works
            _buildSection(
              title: 'How Each Feature Works',
              children: [
                _buildFeature(
                  title: 'Finding People Nearby',
                  description: 'Go to Discover tab, enable location',
                  expectation:
                      'See a list of people within 30-100 meters of you',
                  icon: Icons.location_searching,
                  color: Colors.blue,
                ),
                _buildFeature(
                  title: 'Sending Connection Requests',
                  description: 'Tap on a profile, tap "Connect"',
                  expectation:
                      'The person gets a notification and can accept or decline',
                  icon: Icons.person_add,
                  color: Colors.green,
                ),
                _buildFeature(
                  title: 'Chatting with Connections',
                  description: 'Go to Messages tab, tap on a conversation',
                  expectation:
                      'Send and receive messages with your connections',
                  icon: Icons.message,
                  color: Colors.orange,
                ),
                _buildFeature(
                  title: 'Getting Notifications',
                  description: 'Check the bell icon in the top right',
                  expectation:
                      'See alerts about nearby contacts and new discoveries',
                  icon: Icons.notifications_active,
                  color: Colors.red,
                ),
                _buildFeature(
                  title: 'Managing Your Profile',
                  description: 'Go to Profile tab, tap edit button',
                  expectation: 'Update your name, company, title, and bio',
                  icon: Icons.edit,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // What to Expect
            _buildSection(
              title: 'What to Expect',
              children: [
                _buildFeature(
                  title: 'When You Open the App',
                  description:
                      'You\'ll see the Discover tab with nearby people',
                  expectation: 'A list of professionals in your area',
                  icon: Icons.home,
                  color: Colors.blue,
                ),
                _buildFeature(
                  title: 'When Someone is Nearby',
                  description: 'You\'ll get a notification',
                  expectation: 'Alert that a contact or new person is close by',
                  icon: Icons.location_on,
                  color: Colors.green,
                ),
                _buildFeature(
                  title: 'When You Send a Request',
                  description: 'The person gets notified',
                  expectation: 'They can accept, decline, or message you first',
                  icon: Icons.send,
                  color: Colors.orange,
                ),
                _buildFeature(
                  title: 'When You Get Connected',
                  description: 'You can start chatting',
                  expectation: 'Send messages and build relationships',
                  icon: Icons.handshake,
                  color: Colors.purple,
                ),
                _buildFeature(
                  title: 'When You Move Around',
                  description: 'The app updates nearby people',
                  expectation:
                      'See different networking opportunities in new areas',
                  icon: Icons.directions_walk,
                  color: Colors.teal,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Tips
            _buildSection(
              title: 'Simple Tips',
              children: [
                _buildFeature(
                  title: 'Keep Location On',
                  description: 'Location must be enabled to find people',
                  expectation: 'Better networking opportunities',
                  icon: Icons.location_on,
                  color: Colors.blue,
                ),
                _buildFeature(
                  title: 'Check Notifications',
                  description: 'Look at the bell icon regularly',
                  expectation: 'Don\'t miss networking opportunities',
                  icon: Icons.notifications,
                  color: Colors.orange,
                ),
                _buildFeature(
                  title: 'Complete Your Profile',
                  description: 'Add your name, company, and title',
                  expectation: 'People are more likely to connect with you',
                  icon: Icons.person,
                  color: Colors.green,
                ),
                _buildFeature(
                  title: 'Be Active',
                  description: 'Use the app regularly',
                  expectation: 'Build a strong professional network',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Need Help
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
                    'Need Help?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If something isn\'t working, check your location settings or restart the app.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildFeature({
    required String title,
    required String description,
    required String expectation,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Expectation: $expectation',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
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
}
