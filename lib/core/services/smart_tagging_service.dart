import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/serendipity_models.dart';

class SmartTaggingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Stream controllers for real-time updates
  final StreamController<List<SmartTag>> _tagsController = 
      StreamController<List<SmartTag>>.broadcast();
  final StreamController<List<SmartTag>> _suggestionsController = 
      StreamController<List<SmartTag>>.broadcast();

  // Streams for real-time updates
  Stream<List<SmartTag>> get tagsStream => _tagsController.stream;
  Stream<List<SmartTag>> get suggestionsStream => _suggestionsController.stream;

  // Predefined tag categories for auto-suggestions
  static const Map<TagType, List<String>> _predefinedTags = {
    TagType.industry: [
      'Technology', 'Healthcare', 'Finance', 'Education', 'Manufacturing',
      'Retail', 'Real Estate', 'Consulting', 'Media', 'Non-Profit',
      'Government', 'Energy', 'Transportation', 'Agriculture', 'Entertainment'
    ],
    TagType.skill: [
      'AI/ML', 'Data Science', 'Software Development', 'Marketing', 'Sales',
      'Project Management', 'Design', 'Analytics', 'Leadership', 'Communication',
      'Strategy', 'Operations', 'Finance', 'HR', 'Legal', 'Research',
      'Product Management', 'Customer Success', 'Business Development'
    ],
    TagType.location: [
      'San Francisco', 'New York', 'London', 'Berlin', 'Tokyo', 'Singapore',
      'Dubai', 'Mumbai', 'Sydney', 'Toronto', 'Paris', 'Amsterdam',
      'Stockholm', 'Vancouver', 'Austin', 'Seattle', 'Boston', 'Chicago'
    ],
    TagType.event: [
      'Conference', 'Meetup', 'Workshop', 'Hackathon', 'Networking Event',
      'Panel Discussion', 'Keynote', 'Roundtable', 'Summit', 'Expo',
      'Career Fair', 'Pitch Competition', 'Demo Day', 'Industry Forum'
    ],
    TagType.company: [
      'Startup', 'Scale-up', 'Enterprise', 'Consulting Firm', 'Agency',
      'Non-Profit', 'Government Agency', 'Educational Institution', 'Research Lab'
    ],
    TagType.role: [
      'Founder', 'CEO', 'CTO', 'CFO', 'VP', 'Director', 'Manager',
      'Senior', 'Mid-level', 'Junior', 'Intern', 'Consultant', 'Advisor',
      'Investor', 'Mentor', 'Student', 'Professor', 'Researcher'
    ],
    TagType.interest: [
      'Innovation', 'Sustainability', 'Diversity', 'Remote Work', 'Digital Transformation',
      'Blockchain', 'IoT', 'Cybersecurity', 'Cloud Computing', 'Mobile Apps',
      'E-commerce', 'Fintech', 'Healthtech', 'Edtech', 'Clean Energy'
    ],
    TagType.goal: [
      'Networking', 'Mentorship', 'Collaboration', 'Investment', 'Partnership',
      'Hiring', 'Learning', 'Career Growth', 'Business Development', 'Research',
      'Community Building', 'Knowledge Sharing', 'Problem Solving'
    ]
  };

  // Get all available tags
  Future<List<SmartTag>> getAllTags() async {
    try {
      final snapshot = await _firestore
          .collection('smart_tags')
          .orderBy('usageCount', descending: true)
          .limit(100)
          .get();

      final tags = snapshot.docs
          .map((doc) => SmartTag.fromMap(doc.data()))
          .toList();

      // Add predefined tags if none exist
      if (tags.isEmpty) {
        await _initializePredefinedTags();
        return await getAllTags();
      }

      return tags;
    } catch (e) {
      print('Error getting all tags: $e');
      return [];
    }
  }

  // Get tags by type
  Future<List<SmartTag>> getTagsByType(TagType type) async {
    try {
      final snapshot = await _firestore
          .collection('smart_tags')
          .where('type', isEqualTo: type.toString().split('.').last)
          .orderBy('usageCount', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SmartTag.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting tags by type: $e');
      return [];
    }
  }

  // Get popular tags
  Future<List<SmartTag>> getPopularTags({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('smart_tags')
          .orderBy('popularity', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SmartTag.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting popular tags: $e');
      return [];
    }
  }

  // Get tag suggestions based on input
  Future<List<SmartTag>> getTagSuggestions(String input, {int limit = 10}) async {
    try {
      if (input.isEmpty) {
        return await getPopularTags(limit: limit);
      }

      // Search for tags that match the input
      final snapshot = await _firestore
          .collection('smart_tags')
          .where('name', isGreaterThanOrEqualTo: input.toLowerCase())
          .where('name', isLessThan: '${input.toLowerCase()}\uf8ff')
          .orderBy('name')
          .limit(limit)
          .get();

      final exactMatches = snapshot.docs
          .map((doc) => SmartTag.fromMap(doc.data()))
          .where((tag) => tag.name.toLowerCase().startsWith(input.toLowerCase()))
          .toList();

      // If not enough exact matches, add popular tags
      if (exactMatches.length < limit) {
        final popularTags = await getPopularTags(limit: limit - exactMatches.length);
        final additionalTags = popularTags
            .where((tag) => !exactMatches.any((exact) => exact.id == tag.id))
            .toList();
        exactMatches.addAll(additionalTags);
      }

      return exactMatches;
    } catch (e) {
      print('Error getting tag suggestions: $e');
      return [];
    }
  }

  // Create a new tag
  Future<String> createTag({
    required String name,
    required TagType type,
    String? description,
    List<String> relatedTags = const [],
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if tag already exists
      final existingTag = await _getTagByName(name);
      if (existingTag != null) {
        return existingTag.id;
      }

      final tagId = _uuid.v4();
      final tag = SmartTag(
        id: tagId,
        name: name.trim(),
        type: type,
        description: description,
        usageCount: 0,
        popularity: 0.0,
        relatedTags: relatedTags,
        isAutoGenerated: false,
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      await _firestore
          .collection('smart_tags')
          .doc(tagId)
          .set(tag.toMap());

      _refreshTags();
      return tagId;
    } catch (e) {
      print('Error creating tag: $e');
      rethrow;
    }
  }

  // Update tag usage
  Future<void> updateTagUsage(String tagId) async {
    try {
      final tagRef = _firestore.collection('smart_tags').doc(tagId);
      
      await _firestore.runTransaction((transaction) async {
        final tagDoc = await transaction.get(tagRef);
        if (tagDoc.exists) {
          final currentData = tagDoc.data()!;
          final newUsageCount = (currentData['usageCount'] ?? 0) + 1;
          final newPopularity = _calculatePopularity(newUsageCount);
          
          transaction.update(tagRef, {
            'usageCount': newUsageCount,
            'popularity': newPopularity,
            'lastUsed': Timestamp.fromDate(DateTime.now()),
          });
        }
      });
    } catch (e) {
      print('Error updating tag usage: $e');
    }
  }

  // Get related tags
  Future<List<SmartTag>> getRelatedTags(String tagId, {int limit = 5}) async {
    try {
      final tagDoc = await _firestore
          .collection('smart_tags')
          .doc(tagId)
          .get();

      if (!tagDoc.exists) return [];

      final tag = SmartTag.fromMap(tagDoc.data()!);
      if (tag.relatedTags.isEmpty) return [];

      final relatedSnapshot = await _firestore
          .collection('smart_tags')
          .where(FieldPath.documentId, whereIn: tag.relatedTags.take(10).toList())
          .get();

      return relatedSnapshot.docs
          .map((doc) => SmartTag.fromMap(doc.data()))
          .take(limit)
          .toList();
    } catch (e) {
      print('Error getting related tags: $e');
      return [];
    }
  }

  // Auto-generate tags from text
  Future<List<String>> autoGenerateTags(String text) async {
    try {
      final words = text.toLowerCase().split(' ');
      final suggestedTags = <String>[];

      // Check for industry keywords
      for (final industry in _predefinedTags[TagType.industry]!) {
        if (words.any((word) => word.contains(industry.toLowerCase()))) {
          suggestedTags.add(industry);
        }
      }

      // Check for skill keywords
      for (final skill in _predefinedTags[TagType.skill]!) {
        if (words.any((word) => word.contains(skill.toLowerCase()))) {
          suggestedTags.add(skill);
        }
      }

      // Check for location keywords
      for (final location in _predefinedTags[TagType.location]!) {
        if (words.any((word) => word.contains(location.toLowerCase()))) {
          suggestedTags.add(location);
        }
      }

      // Check for event keywords
      for (final event in _predefinedTags[TagType.event]!) {
        if (words.any((word) => word.contains(event.toLowerCase()))) {
          suggestedTags.add(event);
        }
      }

      // Limit suggestions
      return suggestedTags.take(5).toList();
    } catch (e) {
      print('Error auto-generating tags: $e');
      return [];
    }
  }

  // Get trending tags
  Future<List<SmartTag>> getTrendingTags({int limit = 10}) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('smart_tags')
          .where('lastUsed', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('lastUsed', descending: true)
          .orderBy('usageCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SmartTag.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting trending tags: $e');
      return [];
    }
  }

  // Search tags
  Future<List<SmartTag>> searchTags(String query, {int limit = 20}) async {
    try {
      if (query.isEmpty) return [];

      // Simple text search (Firestore doesn't support full-text search)
      final allTags = await getAllTags();
      final results = allTags
          .where((tag) => 
              tag.name.toLowerCase().contains(query.toLowerCase()) ||
              (tag.description?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .take(limit)
          .toList();

      return results;
    } catch (e) {
      print('Error searching tags: $e');
      return [];
    }
  }

  // Private methods
  Future<SmartTag?> _getTagByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection('smart_tags')
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return SmartTag.fromMap(snapshot.docs.first.data());
    } catch (e) {
      return null;
    }
  }

  double _calculatePopularity(int usageCount) {
    // Simple popularity algorithm based on usage count
    if (usageCount == 0) return 0.0;
    if (usageCount <= 10) return usageCount * 0.1;
    if (usageCount <= 100) return 1.0 + (usageCount - 10) * 0.05;
    return 5.5 + (usageCount - 100) * 0.01;
  }

  Future<void> _initializePredefinedTags() async {
    try {
      final batch = _firestore.batch();
      int tagCount = 0;

      for (final entry in _predefinedTags.entries) {
        for (final tagName in entry.value) {
          final tagId = _uuid.v4();
          final tag = SmartTag(
            id: tagId,
            name: tagName,
            type: entry.key,
            description: 'Predefined ${entry.key.toString().split('.').last} tag',
            usageCount: 0,
            popularity: 0.0,
            relatedTags: const [],
            isAutoGenerated: true,
            createdAt: DateTime.now(),
            lastUsed: DateTime.now(),
          );

          final tagRef = _firestore.collection('smart_tags').doc(tagId);
          batch.set(tagRef, tag.toMap());
          tagCount++;
        }
      }

      await batch.commit();
      print('Initialized $tagCount predefined tags');
    } catch (e) {
      print('Error initializing predefined tags: $e');
    }
  }

  void _refreshTags() {
    getAllTags().then((tags) {
      _tagsController.add(tags);
    });
  }

  // Dispose resources
  void dispose() {
    _tagsController.close();
    _suggestionsController.close();
  }
}
