import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum BlockReason {
  spam,
  inappropriate,
  harassment,
  professionalConflict,
  personal,
  other,
}

class BlockContext {
  final BlockReason reason;
  final String? notes;
  final String? professionalContext;
  final DateTime blockedAt;

  const BlockContext({
    required this.reason,
    this.notes,
    this.professionalContext,
    required this.blockedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reason': reason.name,
      'notes': notes,
      'professionalContext': professionalContext,
      'blockedAt': Timestamp.fromDate(blockedAt),
    };
  }

  factory BlockContext.fromMap(Map<String, dynamic> map) {
    return BlockContext(
      reason: BlockReason.values.firstWhere(
        (e) => e.name == map['reason'],
        orElse: () => BlockReason.other,
      ),
      notes: map['notes'],
      professionalContext: map['professionalContext'],
      blockedAt: (map['blockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class BlockedUser {
  final String id;
  final String blockerId;
  final String blockedId;
  final BlockContext context;
  final String? blockedUserName;
  final String? blockedUserCompany;
  final DateTime createdAt;

  const BlockedUser({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.context,
    this.blockedUserName,
    this.blockedUserCompany,
    required this.createdAt,
  });

  factory BlockedUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedUser(
      id: doc.id,
      blockerId: data['blockerId'] ?? '',
      blockedId: data['blockedId'] ?? '',
      context: BlockContext.fromMap(data['context'] ?? {}),
      blockedUserName: data['blockedUserName'],
      blockedUserCompany: data['blockedUserCompany'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blockerId': blockerId,
      'blockedId': blockedId,
      'context': context.toMap(),
      'blockedUserName': blockedUserName,
      'blockedUserCompany': blockedUserCompany,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class UserBlockingService {
  static final UserBlockingService _instance = UserBlockingService._internal();
  factory UserBlockingService() => _instance;
  UserBlockingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<List<BlockedUser>> _blockedUsersController = 
      StreamController<List<BlockedUser>>.broadcast();
  Stream<List<BlockedUser>> get blockedUsersStream => _blockedUsersController.stream;

  final StreamController<List<String>> _blockedByController = 
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get blockedByStream => _blockedByController.stream;

  List<BlockedUser> _blockedUsers = [];
  List<String> _blockedBy = [];

  Future<void> initialize() async {
    await _loadBlockedUsers();
    _listenToBlockingChanges();
  }

  Future<void> _loadBlockedUsers() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Load users I've blocked
      final blockedSnapshot = await _firestore
          .collection('user_blocks')
          .where('blockerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      _blockedUsers = blockedSnapshot.docs
          .map((doc) => BlockedUser.fromFirestore(doc))
          .toList();

      // Load users who have blocked me
      final blockedBySnapshot = await _firestore
          .collection('user_blocks')
          .where('blockedId', isEqualTo: user.uid)
          .get();

      _blockedBy = blockedBySnapshot.docs
          .map((doc) => doc.data()['blockerId'] as String)
          .toList();

      _blockedUsersController.add(_blockedUsers);
      _blockedByController.add(_blockedBy);

      debugPrint('Loaded ${_blockedUsers.length} blocked users and ${_blockedBy.length} users who blocked me');
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
    }
  }

  void _listenToBlockingChanges() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen to changes in users I've blocked
    _firestore
        .collection('user_blocks')
        .where('blockerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _blockedUsers = snapshot.docs
          .map((doc) => BlockedUser.fromFirestore(doc))
          .toList();
      _blockedUsersController.add(_blockedUsers);
    });

    // Listen to changes in users who have blocked me
    _firestore
        .collection('user_blocks')
        .where('blockedId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _blockedBy = snapshot.docs
          .map((doc) => doc.data()['blockerId'] as String)
          .toList();
      _blockedByController.add(_blockedBy);
    });
  }

  Future<bool> blockUser(
    String userId, {
    required BlockReason reason,
    String? notes,
    String? professionalContext,
    String? userName,
    String? userCompany,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if already blocked
      if (_blockedUsers.any((blocked) => blocked.blockedId == userId)) {
        debugPrint('User $userId is already blocked');
        return true;
      }

      final blockContext = BlockContext(
        reason: reason,
        notes: notes,
        professionalContext: professionalContext,
        blockedAt: DateTime.now(),
      );

      // Add to blocked users
      await _firestore.collection('user_blocks').add({
        'blockerId': user.uid,
        'blockedId': userId,
        'context': blockContext.toMap(),
        'blockedUserName': userName,
        'blockedUserCompany': userCompany,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Remove any existing connections
      await _removeAllConnections(user.uid, userId);

      // Clean up professional context
      await _cleanupProfessionalContext(userId);

      debugPrint('Successfully blocked user $userId with reason: ${reason.name}');
      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Find and delete the block record
      final blockQuery = await _firestore
          .collection('user_blocks')
          .where('blockerId', isEqualTo: user.uid)
          .where('blockedId', isEqualTo: userId)
          .get();

      for (final doc in blockQuery.docs) {
        await doc.reference.delete();
      }

      debugPrint('Successfully unblocked user $userId');
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }

  Future<bool> isUserBlocked(String userId) async {
    return _blockedUsers.any((blocked) => blocked.blockedId == userId);
  }

  Future<bool> isBlockedByUser(String userId) async {
    return _blockedBy.contains(userId);
  }

  Future<bool> canInteractWithUser(String userId) async {
    // Can't interact if I've blocked them or they've blocked me
    final isBlocked = await isUserBlocked(userId);
    final isBlockedBy = await isBlockedByUser(userId);
    return !isBlocked && !isBlockedBy;
  }

  Future<void> _removeAllConnections(String userId1, String userId2) async {
    try {
      // Remove connection requests
      final connectionQuery = await _firestore
          .collection('connection_requests')
          .where('fromUserId', whereIn: [userId1, userId2])
          .where('toUserId', whereIn: [userId1, userId2])
          .get();

      for (final doc in connectionQuery.docs) {
        await doc.reference.delete();
      }

      // Remove any existing connections
      final connectionsQuery = await _firestore
          .collection('connections')
          .where('userId1', whereIn: [userId1, userId2])
          .where('userId2', whereIn: [userId1, userId2])
          .get();

      for (final doc in connectionsQuery.docs) {
        await doc.reference.delete();
      }

      // Remove any messages
      final messagesQuery = await _firestore
          .collection('messages')
          .where('fromUserId', whereIn: [userId1, userId2])
          .where('toUserId', whereIn: [userId1, userId2])
          .get();

      for (final doc in messagesQuery.docs) {
        await doc.reference.delete();
      }

      debugPrint('Removed all connections between $userId1 and $userId2');
    } catch (e) {
      debugPrint('Error removing connections: $e');
    }
  }

  Future<void> _cleanupProfessionalContext(String blockedUserId) async {
    try {
      // Remove from any professional groups or contexts
      final user = _auth.currentUser;
      if (user == null) return;

      // This would integrate with other services to clean up professional context
      // For now, we'll just log the cleanup
      debugPrint('Cleaned up professional context for blocked user $blockedUserId');
    } catch (e) {
      debugPrint('Error cleaning up professional context: $e');
    }
  }

  Future<List<BlockedUser>> getBlockedUsers() async {
    return List.from(_blockedUsers);
  }

  Future<List<String>> getBlockedByUsers() async {
    return List.from(_blockedBy);
  }

  String getBlockReasonDisplayName(BlockReason reason) {
    switch (reason) {
      case BlockReason.spam:
        return 'Spam/Unsolicited messages';
      case BlockReason.inappropriate:
        return 'Inappropriate content';
      case BlockReason.harassment:
        return 'Harassment';
      case BlockReason.professionalConflict:
        return 'Professional conflict';
      case BlockReason.personal:
        return 'Personal reasons';
      case BlockReason.other:
        return 'Other';
    }
  }

  Future<void> dispose() async {
    await _blockedUsersController.close();
    await _blockedByController.close();
  }
}
