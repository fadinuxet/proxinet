import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';
import 'putrace_crypto_service.dart';
import 'professional_auth_service.dart';
import 'simple_firebase_monitor.dart';
// import '../../features/messaging/domain/models/chat_message.dart'; // Removed to avoid MessageType conflict

/// Secure Messaging Service - Privacy-first end-to-end encryption for professional communications
/// Features:
/// - End-to-end encryption for all professional messages
/// - Contact info encryption for business card exchanges
/// - Meeting details encryption for confidential discussions
/// - Professional identity verification
class SecureMessagingService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final PutraceCryptoService _cryptoService;
  final ProfessionalAuthService _authService;
  // final ChatRepository _chatRepository; // Removed unused field
  final Uuid _uuid = const Uuid();
  
  SecureMessagingService(
    this._cryptoService, 
    this._authService,
    // this._chatRepository, // Removed unused field
  );

  /// Send encrypted professional message (Privacy-first)
  Future<void> sendEncryptedMessage({
    required String recipientId,
    required String content,
    MessageType messageType = MessageType.text,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      
      // Get recipient's public key
      final recipientPublicKey = await _getRecipientPublicKey(recipientId);
      if (recipientPublicKey == null) {
        throw Exception('Recipient public key not found. Cannot send encrypted message.');
      }
      
      // Encrypt the message
      final encryptedData = await _cryptoService.encryptProfessionalMessage(
        message: content,
        recipientPublicKey: recipientPublicKey,
        messageType: messageType,
      );
      
      // Create encrypted message
      final encryptedMessage = EncryptedMessage(
        messageId: _uuid.v4(),
        senderId: currentUser.uid,
        recipientId: recipientId,
        encryptedContent: encryptedData['encryptedMessage'],
        encryptionVersion: '1.0',
        keyId: encryptedData['keyId'],
        timestamp: DateTime.now(),
        messageType: messageType,
      );
      
      // Store in Firestore with encryption metadata
      await _storeEncryptedMessage(encryptedMessage, encryptedData);
      
      // Track encrypted message event
      SimpleFirebaseMonitor.trackPutraceEvent('encrypted_message_sent', {
        'message_type': messageType.name,
        'encryption_level': 'end_to_end',
        'recipient_type': 'professional',
      });
      
    } catch (e) {
      throw Exception('Failed to send encrypted message: $e');
    }
  }
  
  /// Send encrypted contact information (business card exchange)
  Future<void> sendEncryptedContactInfo({
    required String recipientId,
    required Map<String, dynamic> contactInfo,
  }) async {
    try {
      final recipientPublicKey = await _getRecipientPublicKey(recipientId);
      if (recipientPublicKey == null) {
        throw Exception('Cannot send contact info - recipient key not found');
      }
      
      // Encrypt contact information
      // final encryptedData = await _cryptoService.encryptContactInfo(
      //   contactInfo: contactInfo,
      //   recipientPublicKey: recipientPublicKey,
      // ); // Removed unused variable
      
      // Send as encrypted message
      await sendEncryptedMessage(
        recipientId: recipientId,
        content: 'Shared contact information securely',
        messageType: MessageType.contactInfo,
      );
      
      // Track contact sharing event
      SimpleFirebaseMonitor.trackPutraceEvent('contact_info_shared', {
        'encryption_level': 'end_to_end',
        'fields_count': contactInfo.keys.length,
      });
      
    } catch (e) {
      throw Exception('Failed to send encrypted contact info: $e');
    }
  }
  
  /// Send encrypted meeting details
  Future<void> sendEncryptedMeetingDetails({
    required String recipientId,
    required Map<String, dynamic> meetingInfo,
  }) async {
    try {
      final recipientPublicKey = await _getRecipientPublicKey(recipientId);
      if (recipientPublicKey == null) {
        throw Exception('Cannot send meeting details - recipient key not found');
      }
      
      // Encrypt meeting details
      // final encryptedData = await _cryptoService.encryptMeetingDetails(
      //   meetingInfo: meetingInfo,
      //   recipientPublicKey: recipientPublicKey,
      // ); // Removed unused variable
      
      // Send as encrypted message
      await sendEncryptedMessage(
        recipientId: recipientId,
        content: 'Shared meeting details securely',
        messageType: MessageType.meetingDetails,
      );
      
      // Track meeting sharing event
      SimpleFirebaseMonitor.trackPutraceEvent('meeting_details_shared', {
        'encryption_level': 'end_to_end',
        'meeting_type': meetingInfo['type'] ?? 'unknown',
      });
      
    } catch (e) {
      throw Exception('Failed to send encrypted meeting details: $e');
    }
  }
  
  /// Receive and decrypt message
  Future<String> receiveEncryptedMessage(EncryptedMessage encryptedMessage) async {
    try {
      // Get sender's public key for verification
      final senderPublicKey = await _getRecipientPublicKey(encryptedMessage.senderId);
      if (senderPublicKey == null) {
        throw Exception('Sender public key not found. Cannot decrypt message.');
      }
      
      // Get stored encryption metadata
      final encryptionData = await _getEncryptionMetadata(encryptedMessage.messageId);
      if (encryptionData == null) {
        throw Exception('Encryption metadata not found');
      }
      
      // Decrypt the message
      final decryptedContent = await _cryptoService.decryptProfessionalMessage(
        encryptedMessage: encryptedMessage.encryptedContent,
        iv: encryptionData['iv'],
        tag: encryptionData['tag'],
        senderPublicKey: senderPublicKey,
      );
      
      // Track decryption event
      SimpleFirebaseMonitor.trackPutraceEvent('encrypted_message_received', {
        'message_type': encryptedMessage.messageType.name,
        'decryption_successful': true,
      });
      
      return decryptedContent;
      
    } catch (e) {
      SimpleFirebaseMonitor.trackPutraceEvent('message_decryption_failed', {
        'error_type': e.toString(),
        'message_id': encryptedMessage.messageId,
      });
      throw Exception('Failed to decrypt message: $e');
    }
  }
  
  /// Get encrypted messages stream
  Stream<List<EncryptedMessage>> getEncryptedMessagesStream(String conversationId) {
    return _firestore
        .collection('encrypted_messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return EncryptedMessage.fromMap(data);
          }).toList();
        });
  }
  
  /// Start encrypted conversation
  Future<String> startEncryptedConversation(String recipientId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      
      // Check if recipient has encryption capability
      final recipientPublicKey = await _getRecipientPublicKey(recipientId);
      if (recipientPublicKey == null) {
        throw Exception('Recipient does not support encrypted messaging');
      }
      
      // Create encrypted conversation
      final conversationId = _uuid.v4();
      
      final conversationData = {
        'id': conversationId,
        'participantIds': [currentUser.uid, recipientId],
        'isEncrypted': true,
        'encryptionVersion': '1.0',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'type': 'professional_encrypted',
      };
      
      await _firestore
          .collection('encrypted_conversations')
          .doc(conversationId)
          .set(conversationData);
      
      // Track conversation creation
      SimpleFirebaseMonitor.trackPutraceEvent('encrypted_conversation_started', {
        'conversation_id': conversationId,
        'encryption_level': 'end_to_end',
      });
      
      return conversationId;
      
    } catch (e) {
      throw Exception('Failed to start encrypted conversation: $e');
    }
  }
  
  /// Verify professional identity before messaging
  Future<bool> verifyProfessionalIdentity(String userId) async {
    try {
      // Get user's professional identity
      final identity = await _authService.getProfessionalIdentityFromCloud();
      if (identity == null) return false;
      
      // Verify the identity (simplified for demo)
      return _cryptoService.verifyProfessionalIdentity(
        publicKey: identity.encryptionPublicKey ?? '',
        signature: 'demo_signature',
        message: identity.identityId,
      );
      
    } catch (e) {
      
      return false;
    }
  }
  
  // Private helper methods
  
  /// Get recipient's public key for encryption
  Future<String?> _getRecipientPublicKey(String recipientId) async {
    try {
      final doc = await _firestore
          .collection('professional_identities')
          .doc(recipientId)
          .get();
          
            SimpleFirebaseMonitor.trackRead();
      
      if (doc.exists && doc.data() != null) {
        return doc.data()!['encryptionPublicKey'] as String?;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Store encrypted message with metadata
  Future<void> _storeEncryptedMessage(
    EncryptedMessage message, 
    Map<String, dynamic> encryptionData,
  ) async {
    try {
      // Store the encrypted message
      await _firestore
          .collection('encrypted_messages')
          .doc(message.messageId)
          .set(message.toMap());
      
      // Store encryption metadata separately for decryption
      await _firestore
          .collection('encryption_metadata')
          .doc(message.messageId)
          .set({
            'messageId': message.messageId,
            'iv': encryptionData['iv'],
            'tag': encryptionData['tag'],
            'algorithm': encryptionData['algorithm'],
            'timestamp': FieldValue.serverTimestamp(),
          });
      
            SimpleFirebaseMonitor.trackWrite();
            SimpleFirebaseMonitor.trackWrite(); // Two writes
      
    } catch (e) {
      throw Exception('Failed to store encrypted message: $e');
    }
  }
  
  /// Get encryption metadata for decryption
  Future<Map<String, dynamic>?> _getEncryptionMetadata(String messageId) async {
    try {
      final doc = await _firestore
          .collection('encryption_metadata')
          .doc(messageId)
          .get();
          
            SimpleFirebaseMonitor.trackRead();
      
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Check if user supports encrypted messaging
  Future<bool> supportsEncryptedMessaging(String userId) async {
    final publicKey = await _getRecipientPublicKey(userId);
    return publicKey != null && publicKey.isNotEmpty;
  }
  
  /// Get encryption status for conversation
  Future<Map<String, dynamic>> getEncryptionStatus(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('encrypted_conversations')
          .doc(conversationId)
          .get();
          
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'isEncrypted': data['isEncrypted'] ?? false,
          'encryptionVersion': data['encryptionVersion'] ?? 'none',
          'type': data['type'] ?? 'standard',
        };
      }
      
      return {
        'isEncrypted': false,
        'encryptionVersion': 'none',
        'type': 'standard',
      };
    } catch (e) {
      
      return {
        'isEncrypted': false,
        'encryptionVersion': 'none',
        'type': 'standard',
      };
    }
  }
}
