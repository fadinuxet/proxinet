import 'package:flutter/material.dart';

import '../../../../core/models/user_profile.dart';

/// Privacy-First UI Components - Professional networking with enterprise-grade security
/// Features:
/// - End-to-end encryption indicators
/// - Professional identity displays
/// - Conference mode indicators
/// - Privacy status badges
/// - Secure messaging UI

/// Privacy Status Badge - shows encryption level
class PrivacyStatusBadge extends StatelessWidget {
  final bool isEncrypted;
  final String encryptionLevel;
  final VoidCallback? onTap;

  const PrivacyStatusBadge({
    super.key,
    required this.isEncrypted,
    this.encryptionLevel = 'standard',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isEncrypted ? Colors.green : Colors.orange;
    final icon = isEncrypted ? Icons.lock : Icons.lock_open;
    final text = isEncrypted ? 'Encrypted' : 'Standard';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Professional Identity Card - Enterprise-grade professional display
class ProfessionalIdentityCard extends StatelessWidget {
  final ProfessionalIdentity identity;
  final bool showEncryptionStatus;
  final VoidCallback? onTap;

  const ProfessionalIdentityCard({
    super.key,
    required this.identity,
    this.showEncryptionStatus = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with privacy indicator
              Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 20,
                    color: identity.isVerified ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      identity.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (showEncryptionStatus)
                    PrivacyStatusBadge(
                      isEncrypted: identity.encryptionPublicKey != null,
                      encryptionLevel: 'end_to_end',
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Professional details
              if (identity.company != null || identity.title != null)
                Row(
                  children: [
                    Icon(Icons.business, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [identity.title, identity.company]
                            .where((e) => e != null)
                            .join(' at '),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              
              if (identity.skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: identity.skills.take(3).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Privacy level indicator
              Row(
                children: [
                  Icon(
                    _getPrivacyIcon(identity.privacyLevel),
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getPrivacyText(identity.privacyLevel),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPrivacyIcon(PrivacyLevel level) {
    switch (level) {
      case PrivacyLevel.public:
        return Icons.public;
      case PrivacyLevel.connections:
        return Icons.people;
      case PrivacyLevel.professional:
        return Icons.business_center;
      case PrivacyLevel.private:
        return Icons.lock;
      case PrivacyLevel.anonymous:
        return Icons.visibility_off;
    }
  }

  String _getPrivacyText(PrivacyLevel level) {
    switch (level) {
      case PrivacyLevel.public:
        return 'Public Profile';
      case PrivacyLevel.connections:
        return 'Connections Only';
      case PrivacyLevel.professional:
        return 'Professional Network';
      case PrivacyLevel.private:
        return 'Private';
      case PrivacyLevel.anonymous:
        return 'Anonymous';
    }
  }
}

/// Conference Mode Badge - shows offline networking status
class ConferenceModeBadge extends StatelessWidget {
  final bool isActive;
  final String? eventName;
  final String? venueName;
  final int discoveredProfessionals;
  final VoidCallback? onTap;

  const ConferenceModeBadge({
    super.key,
    required this.isActive,
    this.eventName,
    this.venueName,
    this.discoveredProfessionals = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[600]!, Colors.blue[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Conference Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OFFLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (venueName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      venueName!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$discoveredProfessionals professionals nearby',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Encrypted Message Bubble - Privacy-first message display with enterprise security
class EncryptedMessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final bool isEncrypted;
  final DateTime timestamp;
  final MessageType messageType;

  const EncryptedMessageBubble({
    super.key,
    required this.content,
    required this.isMe,
    required this.isEncrypted,
    required this.timestamp,
    this.messageType = MessageType.text,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final color = isMe 
        ? (isEncrypted ? Colors.green[600] : Colors.blue[600])
        : (isEncrypted ? Colors.green[100] : Colors.grey[300]);
    final textColor = isMe ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message type indicator
            if (messageType != MessageType.text)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getMessageTypeIcon(messageType),
                      size: 14,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getMessageTypeText(messageType),
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white70 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Message content
            Text(
              content,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Timestamp and encryption indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isEncrypted) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: isMe ? Colors.white70 : Colors.green[600],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMessageTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.text:
        return Icons.message;
      case MessageType.contactInfo:
        return Icons.contact_page;
      case MessageType.meetingRequest:
        return Icons.event;
      case MessageType.meetingDetails:
        return Icons.schedule;
      case MessageType.businessCard:
        return Icons.badge;
    }
  }

  String _getMessageTypeText(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'Message';
      case MessageType.contactInfo:
        return 'Contact Info';
      case MessageType.meetingRequest:
        return 'Meeting Request';
      case MessageType.meetingDetails:
        return 'Meeting Details';
      case MessageType.businessCard:
        return 'Business Card';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
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
}

/// Professional Contact Sharing Widget
class ProfessionalContactSharing extends StatelessWidget {
  final ProfessionalIdentity identity;
  final VoidCallback onShareContact;
  final VoidCallback onRequestMeeting;

  const ProfessionalContactSharing({
    super.key,
    required this.identity,
    required this.onShareContact,
    required this.onRequestMeeting,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Secure Professional Exchange',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'Share your professional information securely with end-to-end encryption.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onShareContact,
                    icon: const Icon(Icons.contact_page, size: 18),
                    label: const Text('Share Contact'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRequestMeeting,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Meeting'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                      side: BorderSide(color: Colors.blue[600]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'End-to-end encrypted',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Privacy Settings Quick Toggle
class PrivacyQuickToggle extends StatelessWidget {
  final String title;
  final String description;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const PrivacyQuickToggle({
    super.key,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isEnabled ? Colors.green : Colors.grey,
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
      ),
    );
  }
}
