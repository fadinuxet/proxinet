import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('profiles')
          .doc(conversation.otherParticipantId)
          .get(),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = profileData?['name'] ?? 'Unknown User';
        final avatarUrl = profileData?['avatarUrl'];
        final company = profileData?['company'] ?? '';
        final title = profileData?['title'] ?? '';

        return ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primary.withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  )
                : null,
          ),
          title: Text(
            userName,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (company.isNotEmpty || title.isNotEmpty)
                Text(
                  [company, title].where((s) => s.isNotEmpty).join(' • '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Text(
                conversation.lastMessageContent.isNotEmpty
                    ? conversation.lastMessageContent
                    : 'Start a conversation',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: conversation.lastMessageContent.isNotEmpty
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(conversation.lastMessageTime),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (conversation.hasUnreadMessages) ...[
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
