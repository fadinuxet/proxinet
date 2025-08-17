import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'serendipity_models.dart';

class SerendipityService {
  final _uuid = const Uuid();

  final List<SerendipityPost> _posts = [];
  AvailabilityStatus _availability = const AvailabilityStatus(
      isAvailable: false, audience: VisibilityAudience.firstDegree);
  ReferralReward _referral = const ReferralReward(credits: 0, invitedCount: 0);

  final StreamController<List<SerendipityPost>> _postsStream =
      StreamController.broadcast();

  Stream<List<SerendipityPost>> get postsStream => _postsStream.stream;
  List<SerendipityPost> get posts => List.unmodifiable(_posts);
  AvailabilityStatus get availability => _availability;
  ReferralReward get referral => _referral;

  SerendipityPost createPost({
    required String authorId,
    required String text,
    required List<String> tags,
    String? photoPath,
    required VisibilityAudience audience,
    Set<String> customGroupIds = const {},
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final post = SerendipityPost(
      id: _uuid.v4(),
      authorId: authorId,
      text: text,
      tags: tags,
      photoPath: photoPath,
      audience: audience,
      customGroupIds: customGroupIds,
      startAt: startAt,
      endAt: endAt,
      createdAt: DateTime.now().toUtc(),
      archived: false,
    );
    _posts.insert(0, post);
    _postsStream.add(posts);
    return post;
  }

  void archiveExpired() {
    final now = DateTime.now().toUtc();
    for (var i = 0; i < _posts.length; i++) {
      final p = _posts[i];
      if (!p.archived && p.endAt.isBefore(now)) {
        _posts[i] = SerendipityPost(
          id: p.id,
          authorId: p.authorId,
          text: p.text,
          tags: p.tags,
          photoPath: p.photoPath,
          audience: p.audience,
          customGroupIds: p.customGroupIds,
          startAt: p.startAt,
          endAt: p.endAt,
          createdAt: p.createdAt,
          archived: true,
        );
      }
    }
    _postsStream.add(posts);
  }

  void setAvailability(AvailabilityStatus status) {
    _availability = status;
  }

  void addReferralCredit({int invited = 1, int credits = 1}) {
    _referral = ReferralReward(
        credits: _referral.credits + credits,
        invitedCount: _referral.invitedCount + invited);
  }

  // Simple overlap matcher by tag or time window
  List<SerendipityPost> overlapsWith(SerendipityPost target) {
    return _posts.where((p) {
      if (p.id == target.id || p.archived) return false;
      final timeOverlap = !(p.endAt.isBefore(target.startAt) ||
          p.startAt.isAfter(target.endAt));
      final tagOverlap =
          p.tags.toSet().intersection(target.tags.toSet()).isNotEmpty;
      return timeOverlap || tagOverlap;
    }).toList();
  }

  // Get users with similar interests in the same area
  Future<List<Map<String, dynamic>>> getUsersWithSimilarInterests({
    required String userId,
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 10,
  }) async {
    try {
      // Get current user's interests
      final userProfile = await _getUserProfile(userId);
      if (userProfile == null) return [];

      final userInterests = UserInterests.fromMap(userProfile);
      if (!userInterests.hasInterests) return [];

      // Get users in the same area
      final nearbyUsers = await _getNearbyUsers(latitude, longitude, radiusKm);
      
      // Score users based on interest overlap
      final scoredUsers = <Map<String, dynamic>>[];
      
      for (final user in nearbyUsers) {
        if (user['userId'] == userId) continue; // Skip self
        
        final userProfileData = await _getUserProfile(user['userId']);
        if (userProfileData == null) continue;
        
        final otherUserInterests = UserInterests.fromMap(userProfileData);
        final score = _calculateInterestScore(userInterests, otherUserInterests);
        
        if (score > 0) {
          scoredUsers.add({
            ...user,
            'interestScore': score,
            'commonInterests': _getCommonInterests(userInterests, otherUserInterests),
          });
        }
      }
      
      // Sort by interest score and return top matches
      scoredUsers.sort((a, b) => (b['interestScore'] as double).compareTo(a['interestScore'] as double));
      return scoredUsers.take(limit).toList();
      
    } catch (e) {
      print('Error getting users with similar interests: $e');
      return [];
    }
  }

  // Get serendipity suggestions for a user
  Future<List<Map<String, dynamic>>> getSerendipitySuggestions({
    required String userId,
    int limit = 5,
  }) async {
    try {
      final suggestions = <Map<String, dynamic>>[];
      
      // Get user's recent posts
      final userPosts = await _getUserRecentPosts(userId);
      
      // Get users with similar interests
      final userProfile = await _getUserProfile(userId);
      if (userProfile != null) {
        final userInterests = UserInterests.fromMap(userProfile);
        if (userInterests.hasInterests) {
          final similarUsers = await getUsersWithSimilarInterests(
            userId: userId,
            latitude: userProfile['latitude'] ?? 0.0,
            longitude: userProfile['longitude'] ?? 0.0,
            radiusKm: 50.0, // 50km radius for suggestions
            limit: limit,
          );
          
          for (final user in similarUsers) {
            suggestions.add({
              'type': 'similar_interests',
              'title': 'Connect with ${user['name'] ?? 'someone'}',
              'description': 'You share interests in ${user['commonInterests'].join(', ')}',
              'userId': user['userId'],
              'score': user['interestScore'],
              'action': 'connect',
            });
          }
        }
      }
      
      // Get event overlap suggestions
      final eventOverlaps = await _getEventOverlaps(userId);
      suggestions.addAll(eventOverlaps);
      
      // Sort by relevance and return top suggestions
      suggestions.sort((a, b) => (b['score'] ?? 0.0).compareTo(a['score'] ?? 0.0));
      return suggestions.take(limit).toList();
      
    } catch (e) {
      print('Error getting serendipity suggestions: $e');
      return [];
    }
  }

  // Helper methods
  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getNearbyUsers(
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      // This is a simplified version - in production you'd use geohash queries
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('latitude', isGreaterThan: latitude - radiusKm / 111.0)
          .where('latitude', isLessThan: latitude + radiusKm / 111.0)
          .get();
      
      return users.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting nearby users: $e');
      return [];
    }
  }

  double _calculateInterestScore(UserInterests user1, UserInterests user2) {
    double score = 0.0;
    
    // Industry match
    if (user1.industry != null && user2.industry != null) {
      if (user1.industry!.toLowerCase() == user2.industry!.toLowerCase()) {
        score += 3.0;
      } else if (_hasPartialMatch(user1.industry!, user2.industry!)) {
        score += 1.5;
      }
    }
    
    // Skills overlap
    final skills1 = user1.skills?.toLowerCase().split(',').map((s) => s.trim()) ?? [];
    final skills2 = user2.skills?.toLowerCase().split(',').map((s) => s.trim()) ?? [];
    final commonSkills = skills1.where((skill) => skills2.contains(skill)).length;
    score += commonSkills * 2.0;
    
    // Networking goals match
    if (user1.networkingGoals != null && user2.networkingGoals != null) {
      if (_hasPartialMatch(user1.networkingGoals!, user2.networkingGoals!)) {
        score += 2.0;
      }
    }
    
    // Location match
    if (user1.location != null && user2.location != null) {
      if (user1.location!.toLowerCase() == user2.location!.toLowerCase()) {
        score += 1.0;
      }
    }
    
    return score;
  }

  List<String> _getCommonInterests(UserInterests user1, UserInterests user2) {
    final common = <String>[];
    
    if (user1.industry != null && user2.industry != null) {
      if (user1.industry!.toLowerCase() == user2.industry!.toLowerCase()) {
        common.add(user1.industry!);
      }
    }
    
    final skills1 = user1.skills?.toLowerCase().split(',').map((s) => s.trim()) ?? [];
    final skills2 = user2.skills?.toLowerCase().split(',').map((s) => s.trim()) ?? [];
    final commonSkills = skills1.where((skill) => skills2.contains(skill));
    common.addAll(commonSkills);
    
    return common.take(3).toList(); // Limit to top 3 common interests
  }

  bool _hasPartialMatch(String text1, String text2) {
    final words1 = text1.toLowerCase().split(' ');
    final words2 = text2.toLowerCase().split(' ');
    return words1.any((word) => words2.contains(word));
  }

  Future<List<Map<String, dynamic>>> _getUserRecentPosts(String userId) async {
    try {
      final posts = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      return posts.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting user recent posts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getEventOverlaps(String userId) async {
    try {
      final suggestions = <Map<String, dynamic>>[];
      
      // Get user's upcoming events
      final userPosts = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .where('startAt', isGreaterThan: Timestamp.now())
          .get();
      
      for (final post in userPosts.docs) {
        final postData = post.data();
        final startDate = postData['startAt'] as Timestamp;
        final endDate = postData['endAt'] as Timestamp;
        
        // Find other users attending similar events
        final similarPosts = await FirebaseFirestore.instance
            .collection('posts')
            .where('startAt', isGreaterThan: startDate.toDate().subtract(const Duration(days: 1)))
            .where('startAt', isLessThan: endDate.toDate().add(const Duration(days: 1)))
            .where('authorId', isNotEqualTo: userId)
            .get();
        
        for (final otherPost in similarPosts.docs) {
          final otherPostData = otherPost.data();
          final otherUserId = otherPostData['authorId'] as String;
          
          // Check if there's overlap in time and location
          if (_hasEventOverlap(postData, otherPostData)) {
            suggestions.add({
              'type': 'event_overlap',
              'title': 'Event Overlap with ${otherPostData['authorName'] ?? 'someone'}',
              'description': 'You\'re both attending events around the same time',
              'userId': otherUserId,
              'score': 2.0,
              'action': 'connect',
            });
          }
        }
      }
      
      return suggestions;
    } catch (e) {
      print('Error getting event overlaps: $e');
      return [];
    }
  }

  bool _hasEventOverlap(Map<String, dynamic> post1, Map<String, dynamic> post2) {
    final start1 = post1['startAt'] as Timestamp;
    final end1 = post1['endAt'] as Timestamp;
    final start2 = post2['startAt'] as Timestamp;
    final end2 = post2['endAt'] as Timestamp;
    
    return start1.toDate().isBefore(end2.toDate()) && 
           start2.toDate().isBefore(end1.toDate());
  }

  void dispose() {
    _postsStream.close();
  }
}
