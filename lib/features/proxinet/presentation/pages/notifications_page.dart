import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();
  NotificationType? _selectedFilter;
  bool _showOnlyUnread = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<NotificationItem> get _filteredNotifications {
    List<NotificationItem> notifications = _notificationService.notifications;

    // Apply type filter
    if (_selectedFilter != null) {
      notifications = notifications.where((n) => n.type == _selectedFilter).toList();
    }

    // Apply unread filter
    if (_showOnlyUnread) {
      notifications = notifications.where((n) => !n.isRead).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      notifications = notifications.where((n) =>
          n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          n.subtitle.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return notifications;
  }

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
              'ProxiNet',
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
              context.go('/proxinet');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showNotificationSettings,
            tooltip: 'Notification Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: scheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notifications...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 16),
                
                // Filter chips
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // All notifications filter
                            FilterChip(
                              label: const Text('All'),
                              selected: _selectedFilter == null,
                              onSelected: (selected) {
                                setState(() => _selectedFilter = null);
                              },
                            ),
                            const SizedBox(width: 8),
                            // Type filters
                            ...NotificationType.values.map((type) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_getTypeLabel(type)),
                                selected: _selectedFilter == type,
                                onSelected: (selected) {
                                  setState(() => _selectedFilter = selected ? type : null);
                                },
                                avatar: Icon(
                                  _getTypeIcon(type),
                                  size: 16,
                                  color: _selectedFilter == type ? Colors.white : null,
                                ),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                    // Unread toggle
                    Row(
                      children: [
                        const Text('Unread only'),
                        Switch(
                          value: _showOnlyUnread,
                          onChanged: (value) => setState(() => _showOnlyUnread = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notifications list
          Expanded(
            child: _filteredNotifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationsList(),
          ),
        ],
      ),
      bottomNavigationBar: _filteredNotifications.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _markAllAsRead,
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark All Read'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _clearAllNotifications,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear All'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getEmptyStateIcon(),
            size: 80,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            _getEmptyStateTitle(),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _getEmptyStateSubtitle(),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isNotEmpty || _selectedFilter != null || _showOnlyUnread)
            FilledButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  IconData _getEmptyStateIcon() {
    if (_searchQuery.isNotEmpty) return Icons.search_off;
    if (_selectedFilter != null) return Icons.filter_list_off;
    if (_showOnlyUnread) return Icons.mark_email_read;
    return Icons.notifications_none;
  }

  String _getEmptyStateTitle() {
    if (_searchQuery.isNotEmpty) return 'No search results';
    if (_selectedFilter != null) return 'No ${_getTypeLabel(_selectedFilter!)} notifications';
    if (_showOnlyUnread) return 'No unread notifications';
    return 'No notifications yet';
  }

  String _getEmptyStateSubtitle() {
    if (_searchQuery.isNotEmpty) return 'Try adjusting your search terms';
    if (_selectedFilter != null) return 'You\'ll see them here when they arrive';
    if (_showOnlyUnread) return 'All notifications have been read';
    return 'You\'ll see proximity alerts and discoveries here';
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      itemCount: _filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = _filteredNotifications[index];
        return _buildNotificationTile(notification);
      },
    );
  }

  Widget _buildNotificationTile(NotificationItem notification) {
    final scheme = Theme.of(context).colorScheme;
    
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _notificationService.removeNotification(notification.id);
      },
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: notification.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            notification.icon,
            color: notification.color,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              notification.timeAgo,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleNotificationAction(value, notification),
              itemBuilder: (context) => [
                if (!notification.isRead)
                  const PopupMenuItem(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(Icons.done, size: 16),
                        SizedBox(width: 8),
                        Text('Mark as read'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Mark as read if unread
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }
    
    // Navigate back to home and show the notification dialog
    context.pop();
    // TODO: Show the enhanced notification dialog from home page
  }

  void _handleNotificationAction(String action, NotificationItem notification) {
    switch (action) {
      case 'mark_read':
        _notificationService.markAsRead(notification.id);
        break;
      case 'delete':
        _notificationService.removeNotification(notification.id);
        break;
    }
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead();
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _notificationService.clearAll();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = null;
      _showOnlyUnread = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _showNotificationSettings() {
    // TODO: Implement notification settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification settings coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.proximity:
        return 'Proximity';
      case NotificationType.discovery:
        return 'Discovery';
      case NotificationType.connection:
        return 'Connection';
      case NotificationType.location:
        return 'Location';
      case NotificationType.general:
        return 'General';
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.proximity:
        return Icons.location_on;
      case NotificationType.discovery:
        return Icons.person_add;
      case NotificationType.connection:
        return Icons.handshake;
      case NotificationType.location:
        return Icons.map;
      case NotificationType.general:
        return Icons.notifications;
    }
  }
}
