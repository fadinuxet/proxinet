import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/conversation.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get messages for a specific conversation
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data()))
            .toList());
  }

  // Send a new message
  Future<void> sendMessage(ChatMessage message) async {
    try {
      final conversationId = _getConversationId(message.senderId, message.receiverId);
      
      // First, ensure conversation exists
      await _ensureConversationExists(conversationId, message.senderId, message.receiverId);
      
      // Add message to conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(message.id) // Use message ID as document ID
          .set(message.toJson());

      // Update conversation metadata
      await _updateConversationMetadata(conversationId, message);
      
      print('Message sent successfully: ${message.id}');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Mark message as read
  Future<void> markAsRead(String conversationId, String messageId) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'isRead': true});
  }

  // Get conversations for current user
  Stream<List<Conversation>> getConversations() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    try {
      return _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUserId)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) {
                    try {
                      // Add the document ID to the data
                      final data = doc.data();
                      data['id'] = doc.id;
                      return Conversation.fromJson(data);
                    } catch (e) {
                      print('Error parsing conversation ${doc.id}: $e');
                      return null;
                    }
                  })
                  .where((conv) => conv != null)
                  .cast<Conversation>()
                  .toList();
            } catch (e) {
              print('Error processing conversations snapshot: $e');
              return <Conversation>[];
            }
          })
          .handleError((error) {
            print('Error in conversations stream: $error');
            return <Conversation>[];
          });
    } catch (e) {
      print('Error setting up conversations stream: $e');
      return Stream.value(<Conversation>[]);
    }
  }

  // Create or get conversation between two users
  Future<String> getOrCreateConversation(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not authenticated');

    final conversationId = _getConversationId(currentUserId, otherUserId);
    
    // Check if conversation exists
    final conversationDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (!conversationDoc.exists) {
      // Create new conversation
      final conversation = Conversation(
        id: conversationId,
        participantIds: [currentUserId, otherUserId],
        lastMessageId: '',
        lastMessageContent: '',
        lastMessageTime: DateTime.now(),
        hasUnreadMessages: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversation.toJson());
    }

    return conversationId;
  }

  // Helper method to generate conversation ID
  String _getConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Update conversation metadata when new message is sent
  Future<void> _updateConversationMetadata(String conversationId, ChatMessage message) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'lastMessageId': message.id,
        'lastMessageContent': message.content,
        'lastMessageTime': Timestamp.fromDate(message.timestamp),
        'updatedAt': FieldValue.serverTimestamp(),
        'hasUnreadMessages': true, // Mark as having unread messages
      });
      
      print('Updated conversation metadata: $conversationId');
    } catch (e) {
      print('Error updating conversation metadata: $e');
      // If update fails, try to create the conversation
      await _ensureConversationExists(conversationId, message.senderId, message.receiverId);
      // Try update again
      try {
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .update({
          'lastMessageId': message.id,
          'lastMessageContent': message.content,
          'lastMessageTime': Timestamp.fromDate(message.timestamp),
          'updatedAt': FieldValue.serverTimestamp(),
          'hasUnreadMessages': true,
        });
      } catch (e2) {
        print('Failed to update conversation metadata after retry: $e2');
      }
    }
  }

  // Ensure conversation exists before sending message
  Future<void> _ensureConversationExists(String conversationId, String senderId, String receiverId) async {
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        // Create new conversation
        final conversation = Conversation(
          id: conversationId,
          participantIds: [senderId, receiverId],
          lastMessageId: '',
          lastMessageContent: '',
          lastMessageTime: DateTime.now(),
          hasUnreadMessages: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .set(conversation.toJson());
        
        print('Created new conversation: $conversationId');
      }
    } catch (e) {
      print('Error ensuring conversation exists: $e');
      rethrow;
    }
  }
}
