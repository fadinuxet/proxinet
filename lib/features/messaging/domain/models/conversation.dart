import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Conversation {
  final String id;
  final List<String> participantIds;
  final String lastMessageId;
  final String lastMessageContent;
  final DateTime lastMessageTime;
  final bool hasUnreadMessages;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.participantIds,
    required this.lastMessageId,
    required this.lastMessageContent,
    required this.lastMessageTime,
    this.hasUnreadMessages = false,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    try {
      return Conversation(
        id: json['id'] as String? ?? '',
        participantIds: List<String>.from(json['participantIds'] ?? []),
        lastMessageId: json['lastMessageId'] as String? ?? '',
        lastMessageContent: json['lastMessageContent'] as String? ?? '',
        lastMessageTime: json['lastMessageTime'] != null 
            ? (json['lastMessageTime'] as Timestamp).toDate()
            : DateTime.now(),
        hasUnreadMessages: json['hasUnreadMessages'] as bool? ?? false,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: json['createdAt'] != null 
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null 
            ? (json['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      
      
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantIds': participantIds,
      'lastMessageId': lastMessageId,
      'lastMessageContent': lastMessageContent,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'hasUnreadMessages': hasUnreadMessages,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Conversation copyWith({
    String? id,
    List<String>? participantIds,
    String? lastMessageId,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    bool? hasUnreadMessages,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get otherParticipantId {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participantIds.first,
    );
  }
}
