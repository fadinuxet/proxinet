import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/serendipity_models.dart';
import '../models/user_profile.dart';

class InterestMatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance; // Removed unused field
  final Uuid _uuid = const Uuid();

  // Stream controllers for real-time updates
  final StreamController<List<InterestMatch>> _matchesController = 
      StreamController<List<InterestMatch>>.broadcast();
  final StreamController<List<SerendipityPost>> _recommendationsController = 
      StreamController<List<SerendipityPost>>.broadcast();

  // Streams for real-time updates
  Stream<List<InterestMatch>> get matchesStream => _matchesController.stream;
  Stream<List<SerendipityPost>> get recommendationsStream => _recommendationsController.stream;

  // Calculate compatibility score between two users
  double calculateUserCompatibility(UserProfile user1, UserProfile user2) {
    double score = 0.0;
    
    // Skills overlap (40% weight)
    if (user1.skills.isNotEmpty && user2.skills.isNotEmpty) {
      final skillOverlap = user1.skills.toSet().intersection(user2.skills.toSet()).length;
      final maxSkills = user1.skills.length > user2.skills.length ? user1.skills.length : user2.skills.length;
      score += (skillOverlap / maxSkills) * 0.4;
    }
    
    // Interests overlap (30% weight)
    if (user1.interests.isNotEmpty && user2.interests.isNotEmpty) {
      final interestOverlap = user1.interests.toSet().intersection(user2.interests.toSet()).length;
      final maxInterests = user1.interests.length > user2.interests.length ? user1.interests.length : user2.interests.length;
      score += (interestOverlap / maxInterests) * 0.3;
    }
    
    // Industry match (20% weight)
    if (user1.industry != null && user2.industry != null && user1.industry == user2.industry) {
      score += 0.2;
    }
    
    // Location proximity (10% weight)
    if (user1.location != null && user2.location != null && user1.location == user2.location) {
      score += 0.1;
    }
    
    return score;
  }

  // Calculate post relevance score for a user
  double calculatePostRelevance(SerendipityPost post, UserProfile user) {
    return post.getRelevanceScore(
      userSkills: user.skills,
      userInterests: user.interests,
      userIndustry: user.industry,
      userLocation: user.location,
    );
  }

  // Get personalized post recommendations for a user
  Future<List<SerendipityPost>> getPersonalizedRecommendations({
    required String userId,
    int limit = 20,
    double minScore = 0.1,
  }) async {
    try {
      // Get user profile
      final userProfileDoc = await _firestore
          .collection('profiles')
          .doc(userId)
          .get();

      if (!userProfileDoc.exists) {
        return [];
      }

      final userProfile = UserProfile.fromFirestore(userProfileDoc);
      
      // Get recent posts
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('archived', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final posts = postsSnapshot.docs
          .map((doc) => SerendipityPost.fromFirestore(doc))
          .where((post) => post.authorId != userId) // Exclude user's own posts
          .toList();

      // Calculate relevance scores
      final scoredPosts = posts.map((post) {
        final score = calculatePostRelevance(post, userProfile);
        return _ScoredPost(post: post, score: score);
      }).toList();

      // Sort by score and filter by minimum score
      scoredPosts.sort((a, b) => b.score.compareTo(a.score));
      
      final filteredPosts = scoredPosts
          .where((scored) => scored.score >= minScore)
          .take(limit)
          .map((scored) => scored.post)
          .toList();

      return filteredPosts;
    } catch (e) {
      
      return [];
    }
  }

  // Get users with similar interests in the same area
  Future<List<UserProfile>> getUsersWithSimilarInterests({
    required String userId,
    required double latitude,
    required double longitude,
    double radiusKm = 50.0,
    double minCompatibilityScore = 0.3,
    int limit = 20,
  }) async {
    try {
      // Get user profile
      final userProfileDoc = await _firestore
          .collection('profiles')
          .doc(userId)
          .get();

      if (!userProfileDoc.exists) {
        return [];
      }

      final userProfile = UserProfile.fromFirestore(userProfileDoc);

      // Get nearby users (simple radius search)
      final nearbyUsers = await _getNearbyUsers(latitude, longitude, radiusKm);
      
      // Calculate compatibility scores
      final scoredUsers = nearbyUsers.map((profile) {
        final score = calculateUserCompatibility(userProfile, profile);
        return _ScoredUser(profile: profile, score: score);
      }).toList();

      // Sort by score and filter by minimum score
      scoredUsers.sort((a, b) => b.score.compareTo(a.score));
      
      final filteredUsers = scoredUsers
          .where((scored) => scored.score >= minCompatibilityScore)
          .take(limit)
          .map((scored) => scored.profile)
          .toList();

      return filteredUsers;
    } catch (e) {
      
      return [];
    }
  }

  // Find event overlaps for users
  Future<List<SerendipityPost>> findEventOverlaps({
    required String userId,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    double? latitude,
    double? longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // Get user profile
      final userProfileDoc = await _firestore
          .collection('profiles')
          .doc(userId)
          .get();

      if (!userProfileDoc.exists) {
        return [];
      }

      final userProfile = UserProfile.fromFirestore(userProfileDoc);

      // Build query for event posts
      Query query = _firestore
          .collection('posts')
          .where('postType', isEqualTo: PostType.event.toString().split('.').last)
          .where('archived', isEqualTo: false);

      // Add time overlap filter
      query = query.where('startAt', isLessThanOrEqualTo: endTime);
      query = query.where('endAt', isGreaterThanOrEqualTo: startTime);

      final snapshot = await query.limit(50).get();
      
      final eventPosts = snapshot.docs
          .map((doc) => SerendipityPost.fromFirestore(doc))
          .where((post) => post.authorId != userId)
          .toList();

      // Filter by location if specified
      if (location != null || (latitude != null && longitude != null)) {
        eventPosts.removeWhere((post) => !_isLocationMatch(post, location, latitude, longitude, radiusKm));
      }

      // Calculate relevance scores and sort
      final scoredPosts = eventPosts.map((post) {
        final score = calculatePostRelevance(post, userProfile);
        return _ScoredPost(post: post, score: score);
      }).toList();

      scoredPosts.sort((a, b) => b.score.compareTo(a.score));
      
      return scoredPosts
          .take(20)
          .map((scored) => scored.post)
          .toList();
    } catch (e) {
      
      return [];
    }
  }

  // Get network intelligence insights
  Future<Map<String, dynamic>> getNetworkInsights(String userId) async {
    try {
      // Get user profile
      final userProfileDoc = await _firestore
          .collection('profiles')
          .doc(userId)
          .get();

      if (!userProfileDoc.exists) {
        return {};
      }

      final userProfile = UserProfile.fromFirestore(userProfileDoc);

      // Get user's connections
      final connectionsSnapshot = await _firestore
          .collection('connections')
          .where('requesterId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final receiverConnectionsSnapshot = await _firestore
          .collection('connections')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final allConnections = [...connectionsSnapshot.docs, ...receiverConnectionsSnapshot.docs];
      
      // Analyze network diversity
      final connectedUserIds = allConnections.map((doc) {
        final data = doc.data();
        return data['requesterId'] == userId ? data['receiverId'] : data['requesterId'];
      }).toSet();

      final networkProfiles = <UserProfile>[];
      for (final id in connectedUserIds.take(20)) { // Limit for performance
        final profileDoc = await _firestore.collection('profiles').doc(id).get();
        if (profileDoc.exists) {
          networkProfiles.add(UserProfile.fromFirestore(profileDoc));
        }
      }

      // Calculate insights
      final insights = <String, dynamic>{
        'totalConnections': allConnections.length,
        'networkDiversity': _calculateNetworkDiversity(networkProfiles),
        'skillGaps': _identifySkillGaps(userProfile, networkProfiles),
        'industryDistribution': _analyzeIndustryDistribution(networkProfiles),
        'geographicSpread': _analyzeGeographicSpread(networkProfiles),
        'recommendedConnections': _getRecommendedConnectionTypes(userProfile, networkProfiles),
      };

      return insights;
    } catch (e) {
      
      return {};
    }
  }

  // Create interest match record
  Future<String> createInterestMatch({
    required String userId,
    required String postId,
    required double score,
    required List<String> matchingFactors,
  }) async {
    try {
      final matchId = _uuid.v4();
      final match = InterestMatch(
        id: matchId,
        userId: userId,
        postId: postId,
        score: score,
        matchingFactors: matchingFactors,
        matchedAt: DateTime.now(),
      );

      await _firestore
          .collection('interest_matches')
          .doc(matchId)
          .set(match.toMap());

      _refreshMatches();
      return matchId;
    } catch (e) {
      
      rethrow;
    }
  }

  // Update match interaction
  Future<void> updateMatchInteraction(String matchId, {
    bool? isViewed,
    bool? isLiked,
    bool? isBookmarked,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (isViewed != null) updates['isViewed'] = isViewed;
      if (isLiked != null) updates['isLiked'] = isLiked;
      if (isBookmarked != null) updates['isBookmarked'] = isBookmarked;

      await _firestore
          .collection('interest_matches')
          .doc(matchId)
          .update(updates);

      _refreshMatches();
    } catch (e) {
      // Log error but don't throw - this is a background operation
      debugPrint('Error updating match: $e');
    }
  }

  // Private methods
  Future<List<UserProfile>> _getNearbyUsers(double latitude, double longitude, double radiusKm) async {
    try {
      // Simple radius search (Firestore doesn't support geospatial queries)
      // In production, use a geospatial service like Algolia or implement a grid-based system
      
      // For now, get all profiles and filter by approximate distance
      final snapshot = await _firestore
          .collection('profiles')
          .limit(100)
          .get();

      final nearbyProfiles = <UserProfile>[];
      
      for (final doc in snapshot.docs) {
        final profile = UserProfile.fromFirestore(doc);
        if (profile.latitude != null && profile.longitude != null) {
          final distance = _calculateDistance(
            latitude, longitude,
            profile.latitude!, profile.longitude!,
          );
          
          if (distance <= radiusKm) {
            nearbyProfiles.add(profile);
          }
        }
      }

      return nearbyProfiles;
    } catch (e) {
      
      return [];
    }
  }

  bool _isLocationMatch(SerendipityPost post, String? location, double? latitude, double? longitude, double radiusKm) {
    if (location != null && post.location == location) return true;
    
    if (latitude != null && longitude != null && post.latitude != null && post.longitude != null) {
      final distance = _calculateDistance(latitude, longitude, post.latitude!, post.longitude!);
      return distance <= radiusKm;
    }
    
    return false;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula for calculating distance between two points
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(lat1 * pi / 180) * sin(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan(sqrt(a) / sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  double _calculateNetworkDiversity(List<UserProfile> profiles) {
    if (profiles.isEmpty) return 0.0;
    
    final industries = profiles.map((p) => p.industry).where((i) => i != null).toSet();
    final skills = profiles.expand((p) => p.skills).toSet();
    
    return (industries.length + skills.length) / (profiles.length * 2);
  }

  List<String> _identifySkillGaps(UserProfile user, List<UserProfile> network) {
    final networkSkills = network.expand((p) => p.skills).toSet();
    final userSkills = user.skills.toSet();
    
    return networkSkills.difference(userSkills).take(5).toList();
  }

  Map<String, int> _analyzeIndustryDistribution(List<UserProfile> profiles) {
    final distribution = <String, int>{};
    
    for (final profile in profiles) {
      if (profile.industry != null) {
        distribution[profile.industry!] = (distribution[profile.industry!] ?? 0) + 1;
      }
    }
    
    return distribution;
  }

  Map<String, int> _analyzeGeographicSpread(List<UserProfile> profiles) {
    final spread = <String, int>{};
    
    for (final profile in profiles) {
      if (profile.location != null) {
        spread[profile.location!] = (spread[profile.location!] ?? 0) + 1;
      }
    }
    
    return spread;
  }

  List<String> _getRecommendedConnectionTypes(UserProfile user, List<UserProfile> network) {
    final recommendations = <String>[];
    
    // Analyze network gaps
    final networkIndustries = network.map((p) => p.industry).where((i) => i != null).toSet();
    final userIndustry = user.industry;
    
    if (userIndustry != null && !networkIndustries.contains(userIndustry)) {
      recommendations.add('Connect with more people in $userIndustry');
    }
    
    // Add more recommendations based on analysis
    if (network.length < 10) {
      recommendations.add('Expand your network');
    }
    
    return recommendations;
  }

  void _refreshMatches() {
    // Refresh matches stream
    // Implementation depends on specific requirements
  }

  // Dispose resources
  void dispose() {
    _matchesController.close();
    _recommendationsController.close();
  }
}

// Helper classes for scoring
class _ScoredPost {
  final SerendipityPost post;
  final double score;

  _ScoredPost({required this.post, required this.score});
}

class _ScoredUser {
  final UserProfile profile;
  final double score;

  _ScoredUser({required this.profile, required this.score});
}
