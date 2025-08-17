import 'package:flutter/material.dart';

enum NotificationType {
  proximity,
  discovery,
  connection,
  location,
  general,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  IconData get icon {
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

  Color get color {
    switch (type) {
      case NotificationType.proximity:
        return Colors.green;
      case NotificationType.discovery:
        return Colors.blue;
      case NotificationType.connection:
        return Colors.orange;
      case NotificationType.location:
        return Colors.purple;
      case NotificationType.general:
        return Colors.grey;
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationItem> _notifications = [];
  final List<Function> _listeners = [];

  // Get all notifications
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  // Get unread notifications count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Get recent notifications (last 24 hours)
  List<NotificationItem> get recentNotifications {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _notifications
        .where((n) => n.timestamp.isAfter(yesterday))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Add a new notification
  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
    _notifyListeners();
  }

  // Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notifyListeners();
    }
  }

  // Mark all notifications as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _notifyListeners();
  }

  // Remove notification
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notifyListeners();
  }

  // Clear all notifications
  void clearAll() {
    _notifications.clear();
    _notifyListeners();
  }

  // Add listener for notification changes
  void addListener(Function callback) {
    _listeners.add(callback);
  }

  // Remove listener
  void removeListener(Function callback) {
    _listeners.remove(callback);
  }

  // Notify all listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // Create sample notifications for testing
  void createSampleNotifications() {
    if (_notifications.isNotEmpty) return; // Don't create duplicates

    final now = DateTime.now();
    
    // Proximity alerts
    addNotification(NotificationItem(
      id: 'prox_1',
      type: NotificationType.proximity,
      title: 'Contact Nearby',
      subtitle: 'John from LinkedIn is 30m away',
      timestamp: now.subtract(const Duration(minutes: 2)),
    ));

    addNotification(NotificationItem(
      id: 'prox_2',
      type: NotificationType.proximity,
      title: 'Contact Nearby',
      subtitle: 'Maria from TechCorp is 45m away',
      timestamp: now.subtract(const Duration(minutes: 8)),
    ));

    // Discovery notifications
    addNotification(NotificationItem(
      id: 'disc_1',
      type: NotificationType.discovery,
      title: 'New People Discovered',
      subtitle: '3 new people in your area',
      timestamp: now.subtract(const Duration(minutes: 5)),
    ));

    addNotification(NotificationItem(
      id: 'disc_2',
      type: NotificationType.discovery,
      title: 'New People Discovered',
      subtitle: '2 professionals at the coffee shop',
      timestamp: now.subtract(const Duration(minutes: 25)),
    ));

    // Connection requests
    addNotification(NotificationItem(
      id: 'conn_1',
      type: NotificationType.connection,
      title: 'Connection Request',
      subtitle: 'Sarah wants to connect with you',
      timestamp: now.subtract(const Duration(minutes: 10)),
    ));

    addNotification(NotificationItem(
      id: 'conn_2',
      type: NotificationType.connection,
      title: 'Connection Request',
      subtitle: 'Alex from StartupHub wants to connect',
      timestamp: now.subtract(const Duration(minutes: 35)),
    ));

    // Location updates
    addNotification(NotificationItem(
      id: 'loc_1',
      type: NotificationType.location,
      title: 'Location Update',
      subtitle: 'You\'ve entered a networking zone',
      timestamp: now.subtract(const Duration(minutes: 15)),
    ));

    addNotification(NotificationItem(
      id: 'loc_2',
      type: NotificationType.location,
      title: 'Location Update',
      subtitle: 'Entered downtown business district',
      timestamp: now.subtract(const Duration(minutes: 45)),
    ));

    // General notifications
    addNotification(NotificationItem(
      id: 'gen_1',
      type: NotificationType.general,
      title: 'Weekly Summary',
      subtitle: 'You made 5 new connections this week',
      timestamp: now.subtract(const Duration(hours: 2)),
    ));

    addNotification(NotificationItem(
      id: 'gen_2',
      type: NotificationType.general,
      title: 'Profile Update',
      subtitle: 'Your profile was viewed 12 times today',
      timestamp: now.subtract(const Duration(hours: 4)),
    ));
  }

  // Compatibility methods for existing code
  Future<void> init() async {
    // Initialize the notification service
    // This method is kept for compatibility with existing code
    print('NotificationService initialized');
  }

  Future<void> showNow({required String title, required String body}) async {
    // Show a notification immediately
    // This method is kept for compatibility with existing code
    addNotification(NotificationItem(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.general,
      title: title,
      subtitle: body,
      timestamp: DateTime.now(),
    ));
    print('Notification shown: $title - $body');
  }
}

// Extension to add copyWith method to NotificationItem
extension NotificationItemExtension on NotificationItem {
  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? subtitle,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}
