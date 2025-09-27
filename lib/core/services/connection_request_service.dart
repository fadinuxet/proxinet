import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ConnectionRequestService {
  static final ConnectionRequestService _instance = ConnectionRequestService._internal();
  factory ConnectionRequestService() => _instance;
  ConnectionRequestService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<List<ConnectionRequest>> _requestsController = 
      StreamController<List<ConnectionRequest>>.broadcast();
  Stream<List<ConnectionRequest>> get requestsStream => _requestsController.stream;

  final StreamController<List<ConnectionRequest>> _sentRequestsController = 
      StreamController<List<ConnectionRequest>>.broadcast();
  Stream<List<ConnectionRequest>> get sentRequestsStream => _sentRequestsController.stream;

  Future<void> initialize() async {
    // Listen to incoming connection requests
    _listenToIncomingRequests();
    _listenToSentRequests();
  }

  void _listenToIncomingRequests() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('connection_requests')
        .where('toUserId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      final requests = snapshot.docs
          .map((doc) => ConnectionRequest.fromFirestore(doc))
          .toList();
      _requestsController.add(requests);
    });
  }

  void _listenToSentRequests() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('connection_requests')
        .where('fromUserId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      final requests = snapshot.docs
          .map((doc) => ConnectionRequest.fromFirestore(doc))
          .toList();
      _sentRequestsController.add(requests);
    });
  }

  Future<String> sendConnectionRequest({
    required String toUserId,
    required String toUserName,
    String? message,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('connection_requests')
          .where('fromUserId', isEqualTo: user.uid)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Connection request already sent');
      }

      // Create connection request
      final request = ConnectionRequest(
        id: '',
        fromUserId: user.uid,
        fromUserName: user.displayName ?? 'Anonymous',
        toUserId: toUserId,
        toUserName: toUserName,
        message: message ?? 'Hi! I\'d love to connect with you.',
        status: ConnectionRequestStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('connection_requests').add(request.toMap());
      
      // Update the request with its ID
      await docRef.update({'id': docRef.id});

      debugPrint('Connection request sent to $toUserName');
      return docRef.id;
    } catch (e) {
      debugPrint('Error sending connection request: $e');
      rethrow;
    }
  }

  Future<void> acceptConnectionRequest(String requestId) async {
    try {
      await _firestore
          .collection('connection_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Connection request accepted: $requestId');
    } catch (e) {
      debugPrint('Error accepting connection request: $e');
      rethrow;
    }
  }

  Future<void> rejectConnectionRequest(String requestId) async {
    try {
      await _firestore
          .collection('connection_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Connection request rejected: $requestId');
    } catch (e) {
      debugPrint('Error rejecting connection request: $e');
      rethrow;
    }
  }

  Future<void> cancelConnectionRequest(String requestId) async {
    try {
      await _firestore
          .collection('connection_requests')
          .doc(requestId)
          .delete();

      debugPrint('Connection request cancelled: $requestId');
    } catch (e) {
      debugPrint('Error cancelling connection request: $e');
      rethrow;
    }
  }

  Future<List<ConnectionRequest>> getPendingRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('connection_requests')
          .where('toUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ConnectionRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending requests: $e');
      return [];
    }
  }

  Future<List<ConnectionRequest>> getSentRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('connection_requests')
          .where('fromUserId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ConnectionRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting sent requests: $e');
      return [];
    }
  }

  Future<void> dispose() async {
    await _requestsController.close();
    await _sentRequestsController.close();
  }
}

enum ConnectionRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled,
}

class ConnectionRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final String message;
  final ConnectionRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConnectionRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConnectionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConnectionRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? '',
      message: data['message'] ?? '',
      status: ConnectionRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ConnectionRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'message': message,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ConnectionRequest copyWith({
    String? id,
    String? fromUserId,
    String? fromUserName,
    String? toUserId,
    String? toUserName,
    String? message,
    ConnectionRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConnectionRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      toUserId: toUserId ?? this.toUserId,
      toUserName: toUserName ?? this.toUserName,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ConnectionRequest(id: $id, from: $fromUserName, to: $toUserName, status: $status)';
  }
}
