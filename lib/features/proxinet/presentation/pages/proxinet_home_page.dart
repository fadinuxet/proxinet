import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/proxinet_presence_service.dart';
import '../../../../core/services/proxinet_local_store.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/serendipity_service.dart';
import '../../../messaging/presentation/pages/messages_page.dart';

class ProxinetHomePage extends StatefulWidget {
  const ProxinetHomePage({super.key});

  @override
  State<ProxinetHomePage> createState() => _ProxinetHomePageState();
}

class _ProxinetHomePageState extends State<ProxinetHomePage> {
  int _currentTabIndex = 0;
  late final NotificationService _notificationService;
  late final ColorScheme _colorScheme;

  @override
  void initState() {
    super.initState();
    _colorScheme = Theme.of(context).colorScheme;
    _notificationService = NotificationService();
    _initializeNotifications();
  }

  void _initializeNotifications() {
    _notificationService.createSampleNotifications();
    _notificationService.addListener(_onNotificationsChanged);
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildCurrentTab(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      extendBody: false,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.network_check, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'ProxiNet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _colorScheme.onSurface,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      actions: [
        _buildNotificationBadge(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotificationsPanel(context),
          tooltip: 'Notifications',
        ),
        if (_notificationService.unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _notificationService.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentTab() {
    final tabs = [
      _buildDiscoverTab(),
      const MessagesPage(),
      const _ProfileTab(),
    ];
    return SafeArea(
      bottom: false, // Don't add bottom safe area since we handle it in bottom navigation
      child: tabs[_currentTabIndex],
    );
  }

  Widget _buildDiscoverTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroSection(),
        const SizedBox(height: 24),
        _buildSectionHeader('Quick Actions'),
        const SizedBox(height: 16),
        _buildQuickActionGrid(),
        const SizedBox(height: 24),
        _buildSectionHeader('Recent Activity'),
        const SizedBox(height: 16),
        _buildRecentActivityCard(),
        const SizedBox(height: 24),
        _buildSectionHeader('Serendipity Suggestions'),
        const SizedBox(height: 16),
        _buildSerendipitySuggestions(),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            _colorScheme.primary.withOpacity(0.9),
            _colorScheme.secondary.withOpacity(0.8),
            _colorScheme.tertiary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _colorScheme.primary.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 24),
          _buildHeroButtons(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to ProxiNet',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Discover and connect with professionals around you',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/proxinet/nearby'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.location_on, size: 24),
            label: Text(
              'Find Nearby',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/proxinet/map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.map, size: 24),
            label: Text(
              'View Map',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _colorScheme.onSurface,
      ),
    );
  }

  Widget _buildQuickActionGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildQuickActionCard(
              icon: Icons.person_add,
              title: 'Connect',
              subtitle: 'Find new connections',
              color: _colorScheme.primary,
              onTap: () => context.push('/proxinet/connect'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _buildQuickActionCard(
              icon: Icons.camera_alt,
              title: 'Event Mode',
              subtitle: 'Start networking',
              color: _colorScheme.secondary,
              onTap: () => context.push('/proxinet/camera'),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildQuickActionCard(
              icon: Icons.edit_note,
              title: 'New Post',
              subtitle: 'Share your thoughts',
              color: _colorScheme.tertiary,
              onTap: () => context.push('/proxinet/post'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _buildQuickActionCard(
              icon: Icons.article,
              title: 'My Posts',
              subtitle: 'View your content',
              color: Colors.orange,
              onTap: () => context.push('/proxinet/posts'),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: _colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              icon: Icons.person_add,
              title: 'Connected with Sarah Chen',
              subtitle: 'Software Engineer at TechCorp',
              time: '2 hours ago',
              color: _colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              icon: Icons.location_on,
              title: 'Discovered 3 new contacts',
              subtitle: 'Nearby networking event',
              time: '5 hours ago',
              color: _colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              icon: Icons.edit_note,
              title: 'Posted new update',
              subtitle: 'Excited about the new project!',
              time: '1 day ago',
              color: _colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSerendipitySuggestions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: _colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Serendipity Suggestions',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSerendipityItem(
              title: 'Networking Event',
              subtitle: 'Join a local meetup for tech professionals.',
              icon: Icons.event,
              color: _colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildSerendipityItem(
              title: 'New User',
              subtitle: 'Sarah Chen just joined ProxiNet.',
              icon: Icons.person_add,
              color: _colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            _buildSerendipityItem(
              title: 'Proximity Alert',
              subtitle: 'You are near a new connection opportunity.',
              icon: Icons.location_on,
              color: _colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSerendipityItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: _colorScheme.primary,
          unselectedItemColor: _colorScheme.onSurface.withOpacity(0.6),
          backgroundColor: Colors.transparent,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications, color: _colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Notifications'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_notificationService.notifications.isEmpty)
                  _buildEmptyNotifications()
                else
                  ..._notificationService.notifications
                      .take(10)
                      .map(_buildNotificationItem),
                const SizedBox(height: 16),
                if (_notificationService.notifications.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          _notificationService.markAllAsRead();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Mark All Read'),
                      ),
                      TextButton(
                        onPressed: () {
                          _notificationService.clearAll();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (_notificationService.notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/notifications');
              },
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Column(
      children: [
        Icon(
          Icons.notifications_none,
          size: 64,
          color: _colorScheme.onSurface.withOpacity(0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'No notifications yet',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll notify you when something important happens',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getNotificationColor(notification.type),
        child: Icon(
          _getNotificationIcon(notification.type),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        notification.title,
        style: GoogleFonts.inter(
          fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        notification.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatTime(notification.timestamp),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: () => _handleNotificationTap(notification),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.connection:
        return Colors.orange;
      case NotificationType.discovery:
        return Colors.blue;
      case NotificationType.proximity:
        return Colors.green;
      case NotificationType.location:
        return Colors.purple;
      case NotificationType.general:
        return Colors.grey;
    }
  }

 IconData _getNotificationIcon(NotificationType type) {
  switch (type) {
    case NotificationType.connection:
      return Icons.handshake;
    case NotificationType.discovery:
      return Icons.person_add;
    case NotificationType.proximity:
      return Icons.location_on;
    case NotificationType.location:
      return Icons.map;
    case NotificationType.general:
      return Icons.notifications;
  }
}

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  void _handleNotificationTap(NotificationItem notification) {
    _notificationService.markAsRead(notification.id);

    switch (notification.type) {
      case NotificationType.connection:
        context.push('/proxinet');
        break;
      case NotificationType.discovery:
        context.push('/proxinet');
        break;
      case NotificationType.proximity:
        context.push('/proxinet');
        break;
      case NotificationType.location:
        context.push('/proxinet/map');
        break;
      case NotificationType.general:
        // Stay on current page for general notifications
        break;
    }
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          title: 'Profile',
          subtitle: 'Manage your personal information',
          icon: Icons.person,
          color: scheme.primary,
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'View Profile',
          subtitle: 'See and edit your profile',
          icon: Icons.person,
          color: scheme.primary,
          onTap: () => context.go('/proxinet/profile'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'My Posts',
          subtitle: 'View and manage your posts',
          icon: Icons.article,
          color: scheme.secondary,
          onTap: () => context.go('/proxinet/posts'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'Availability',
          subtitle: 'Set your connection status',
          icon: Icons.person_add,
          color: scheme.tertiary,
          onTap: () => context.go('/proxinet/availability'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'Custom Groups',
          subtitle: 'Manage your audience groups',
          icon: Icons.group,
          color: scheme.secondary,
          onTap: () => context.go('/proxinet/groups'),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          title: 'My Contacts',
          subtitle: 'View your network connections',
          icon: Icons.people,
          color: scheme.primary,
          onTap: () => context.go('/proxinet/contacts'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withOpacity(0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
