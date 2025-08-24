import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/connection.dart';
import '../models/user_profile.dart';

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Stream controllers for real-time updates
  final StreamController<List<Connection>> _connectionsController = 
      StreamController<List<Connection>>.broadcast();
  final StreamController<List<ConnectionRequest>> _requestsController = 
      StreamController<List<ConnectionRequest>>.broadcast();

  // Streams for real-time updates
  Stream<List<Connection>> get connectionsStream => _connectionsController.stream;
  Stream<List<ConnectionRequest>> get requestsStream => _requestsController.stream;

  // Send a connection request
  Future<String> sendConnectionRequest({
    required String receiverId,
    required String message,
    ConnectionType type = ConnectionType.professional,
    List<String> sharedInterests = const [],
    List<String> sharedSkills = const [],
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if connection already exists
      final existingConnection = await _getExistingConnection(
        currentUser.uid,
        receiverId,
      );

      if (existingConnection != null) {
        throw Exception('Connection already exists');
      }

      // Create connection request
      final requestId = _uuid.v4();
      final request = ConnectionRequest(
        id: requestId,
        requesterId: currentUser.uid,
        receiverId: receiverId,
        message: message,
        type: type,
        sharedInterests: sharedInterests,
        sharedSkills: sharedSkills,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore
          .collection('connection_requests')
          .doc(requestId)
          .set(request.toFirestore());

      // Create pending connection
      final connectionId = _uuid.v4();
      final connection = Connection(
        id: connectionId,
        requesterId: currentUser.uid,
        receiverId: receiverId,
        status: ConnectionStatus.pending,
        type: type,
        message: message,
        createdAt: DateTime.now(),
        sharedInterests: sharedInterests,
        sharedSkills: sharedSkills,
      );

      await _firestore
          .collection('connections')
          .doc(connectionId)
          .set(connection.toFirestore());

      // Update streams
      _refreshConnections();
      _refreshRequests();

      return connectionId;
    } catch (e) {
      print('Error sending connection request: $e');
      rethrow;
    }
  }

  // Accept a connection request
  Future<void> acceptConnection(String connectionId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update connection status
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .update({
        'status': ConnectionStatus.accepted.toString().split('.').last,
        'acceptedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Mark request as accepted
      await _firestore
          .collection('connection_requests')
          .where('requesterId', isEqualTo: currentUser.uid)
          .where('receiverId', isEqualTo: currentUser.uid)
          .get()
          .then((snapshot) {
        for (final doc in snapshot.docs) {
          doc.reference.update({
            'status': 'accepted',
            'acceptedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      });

      // Update streams
      _refreshConnections();
      _refreshRequests();
    } catch (e) {
      print('Error accepting connection: $e');
      rethrow;
    }
  }

  // Reject a connection request
  Future<void> rejectConnection(String connectionId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update connection status
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .update({
        'status': ConnectionStatus.rejected.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Mark request as rejected
      await _firestore
          .collection('connection_requests')
          .where('requesterId', isEqualTo: currentUser.uid)
          .where('receiverId', isEqualTo: currentUser.uid)
          .get()
          .then((snapshot) {
        for (final doc in snapshot.docs) {
          doc.reference.update({
            'status': 'rejected',
            'rejectedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      });

      // Update streams
      _refreshConnections();
      _refreshRequests();
    } catch (e) {
      print('Error rejecting connection: $e');
      rethrow;
    }
  }

  // Block a user
  Future<void> blockUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update existing connection to blocked
      final connectionQuery = await _firestore
          .collection('connections')
          .where('requesterId', whereIn: [currentUser.uid, userId])
          .where('receiverId', whereIn: [currentUser.uid, userId])
          .get();

      for (final doc in connectionQuery.docs) {
        await doc.reference.update({
          'status': ConnectionStatus.blocked.toString().split('.').last,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      // Update streams
      _refreshConnections();
    } catch (e) {
      print('Error blocking user: $e');
      rethrow;
    }
  }

  // Remove a connection
  Future<void> removeConnection(String connectionId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update connection status to removed
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .update({
        'status': ConnectionStatus.removed.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update streams
      _refreshConnections();
    } catch (e) {
      print('Error removing connection: $e');
      rethrow;
    }
  }

  // Get user's connections
  Future<List<Connection>> getUserConnections() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('connections')
          .where('requesterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: ConnectionStatus.accepted.toString().split('.').last)
          .get();

      final connections = snapshot.docs
          .map((doc) => Connection.fromFirestore(doc))
          .toList();

      // Also get connections where user is the receiver
      final receiverSnapshot = await _firestore
          .collection('connections')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: ConnectionStatus.accepted.toString().split('.').last)
          .get();

      final receiverConnections = receiverSnapshot.docs
          .map((doc) => Connection.fromFirestore(doc))
          .toList();

      // Combine and remove duplicates
      final allConnections = [...connections, ...receiverConnections];
      final uniqueConnections = <String, Connection>{};
      
      for (final connection in allConnections) {
        final key = '${connection.requesterId}_${connection.receiverId}';
        if (!uniqueConnections.containsKey(key)) {
          uniqueConnections[key] = connection;
        }
      }

      return uniqueConnections.values.toList();
    } catch (e) {
      print('Error getting user connections: $e');
      return [];
    }
  }

  // Get pending connection requests
  Future<List<ConnectionRequest>> getPendingRequests() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('connection_requests')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ConnectionRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting pending requests: $e');
      return [];
    }
  }

  // Get connection suggestions based on shared interests
  Future<List<UserProfile>> getConnectionSuggestions() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile
      final userProfileDoc = await _firestore
          .collection('profiles')
          .doc(currentUser.uid)
          .get();

      if (!userProfileDoc.exists) {
        return [];
      }

      final userProfile = UserProfile.fromFirestore(userProfileDoc);
      final userSkills = userProfile.skills;
      final userInterests = userProfile.interests;

      if (userSkills.isEmpty && userInterests.isEmpty) {
        return [];
      }

      // Find users with similar skills or interests
      final suggestionsQuery = await _firestore
          .collection('profiles')
          .where('skills', arrayContainsAny: userSkills)
          .limit(10)
          .get();

      final suggestions = suggestionsQuery.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((profile) => profile.id != currentUser.uid)
          .toList();

      // Filter out existing connections
      final existingConnections = await getUserConnections();
      final existingUserIds = existingConnections
          .map((c) => c.requesterId == currentUser.uid ? c.receiverId : c.requesterId)
          .toSet();

      return suggestions.where((profile) => !existingUserIds.contains(profile.id)).toList();
    } catch (e) {
      print('Error getting connection suggestions: $e');
      return [];
    }
  }

  // Check if two users are connected
  Future<bool> areUsersConnected(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('connections')
          .where('requesterId', whereIn: [userId1, userId2])
          .where('receiverId', whereIn: [userId1, userId2])
          .where('status', isEqualTo: ConnectionStatus.accepted.toString().split('.').last)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking connection status: $e');
      return false;
    }
  }

  // Get connection between two users
  Future<Connection?> getConnection(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('connections')
          .where('requesterId', whereIn: [userId1, userId2])
          .where('receiverId', whereIn: [userId1, userId2])
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return Connection.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error getting connection: $e');
      return null;
    }
  }

  // Update connection interaction
  Future<void> updateConnectionInteraction(String connectionId) async {
    try {
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .update({
        'interactionCount': FieldValue.increment(1),
        'lastInteractionAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      _refreshConnections();
    } catch (e) {
      print('Error updating connection interaction: $e');
    }
  }

  // Toggle connection favorite status
  Future<void> toggleConnectionFavorite(String connectionId) async {
    try {
      final connectionDoc = await _firestore
          .collection('connections')
          .doc(connectionId)
          .get();

      if (!connectionDoc.exists) return;

      final currentFavorite = connectionDoc.data()?['isFavorite'] ?? false;
      
      await _firestore
          .collection('connections')
          .doc(connectionId)
          .update({
        'isFavorite': !currentFavorite,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      _refreshConnections();
    } catch (e) {
      print('Error toggling connection favorite: $e');
    }
  }

  // Private methods
  Future<Connection?> _getExistingConnection(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('connections')
          .where('requesterId', whereIn: [userId1, userId2])
          .where('receiverId', whereIn: [userId1, userId2])
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return Connection.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  void _refreshConnections() {
    getUserConnections().then((connections) {
      _connectionsController.add(connections);
    });
  }

  void _refreshRequests() {
    getPendingRequests().then((requests) {
      _requestsController.add(requests);
    });
  }

  // Dispose resources
  void dispose() {
    _connectionsController.close();
    _requestsController.close();
  }
}
