import 'package:cloud_firestore/cloud_firestore.dart';

enum VisibilityAudience {
  everyone,
  firstDegree,
  secondDegree,
  customGroups
}

enum PostType {
  availability,
  event,
  skillShare,
  collaboration,
  learning,
  general
}

enum PostCategory {
  networking,
  mentorship,
  collaboration,
  learning,
  event,
  availability,
  skillShare,
  investment,
  career,
  industry,
  general
}

class SerendipityPost {
  final String id;
  final String authorId;
  final String text;
  final List<String> tags;
  final String? photoPath;
  final VisibilityAudience audience;
  final Set<String> customGroupIds;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime createdAt;
  final bool archived;
  
  // Enhanced fields for the 4 core features
  final PostType postType;
  final PostCategory category;
  final String? location;
  final double? latitude;
  final double? longitude;
  final List<String> skills;
  final List<String> interests;
  final String? company;
  final String? title;
  final String? industry;
  final Map<String, dynamic> metadata;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final List<String> likedBy;
  final List<String> bookmarkedBy;
  final bool isPromoted;
  final DateTime? promotedUntil;

  const SerendipityPost({
    required this.id,
    required this.authorId,
    required this.text,
    required this.tags,
    this.photoPath,
    required this.audience,
    this.customGroupIds = const {},
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    this.archived = false,
    this.postType = PostType.general,
    this.category = PostCategory.general,
    this.location,
    this.latitude,
    this.longitude,
    this.skills = const [],
    this.interests = const [],
    this.company,
    this.title,
    this.industry,
    this.metadata = const {},
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.likedBy = const [],
    this.bookmarkedBy = const [],
    this.isPromoted = false,
    this.promotedUntil,
  });

  // Factory constructor from Firestore document
  factory SerendipityPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SerendipityPost(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      text: data['text'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      photoPath: data['photoPath'],
      audience: VisibilityAudience.values.firstWhere(
        (e) => e.toString() == 'VisibilityAudience.${data['audience']}',
        orElse: () => VisibilityAudience.everyone,
      ),
      customGroupIds: Set<String>.from(data['customGroupIds'] ?? []),
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      archived: data['archived'] ?? false,
      postType: PostType.values.firstWhere(
        (e) => e.toString() == 'PostType.${data['postType']}',
        orElse: () => PostType.general,
      ),
      category: PostCategory.values.firstWhere(
        (e) => e.toString() == 'PostCategory.${data['category']}',
        orElse: () => PostCategory.general,
      ),
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      skills: List<String>.from(data['skills'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      company: data['company'],
      title: data['title'],
      industry: data['industry'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      viewCount: data['viewCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      bookmarkedBy: List<String>.from(data['bookmarkedBy'] ?? []),
      isPromoted: data['isPromoted'] ?? false,
      promotedUntil: data['promotedUntil'] != null ? (data['promotedUntil'] as Timestamp).toDate() : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'text': text,
      'tags': tags,
      'photoPath': photoPath,
      'audience': audience.toString().split('.').last,
      'customGroupIds': customGroupIds.toList(),
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'archived': archived,
      'postType': postType.toString().split('.').last,
      'category': category.toString().split('.').last,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'skills': skills,
      'interests': interests,
      'company': company,
      'title': title,
      'industry': industry,
      'metadata': metadata,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'likedBy': likedBy,
      'bookmarkedBy': bookmarkedBy,
      'isPromoted': isPromoted,
      'promotedUntil': promotedUntil != null ? Timestamp.fromDate(promotedUntil!) : null,
    };
  }

  // Create a copy with updated fields
  SerendipityPost copyWith({
    String? id,
    String? authorId,
    String? text,
    List<String>? tags,
    String? photoPath,
    VisibilityAudience? audience,
    Set<String>? customGroupIds,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? createdAt,
    bool? archived,
    PostType? postType,
    PostCategory? category,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? skills,
    List<String>? interests,
    String? company,
    String? title,
    String? industry,
    Map<String, dynamic>? metadata,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    List<String>? likedBy,
    List<String>? bookmarkedBy,
    bool? isPromoted,
    DateTime? promotedUntil,
  }) {
    return SerendipityPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      tags: tags ?? this.tags,
      photoPath: photoPath ?? this.photoPath,
      audience: audience ?? this.audience,
      customGroupIds: customGroupIds ?? this.customGroupIds,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
      postType: postType ?? this.postType,
      category: category ?? this.category,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      company: company ?? this.company,
      title: title ?? this.title,
      industry: industry ?? this.industry,
      metadata: metadata ?? this.metadata,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      likedBy: likedBy ?? this.likedBy,
      bookmarkedBy: bookmarkedBy ?? this.bookmarkedBy,
      isPromoted: isPromoted ?? this.isPromoted,
      promotedUntil: promotedUntil ?? this.promotedUntil,
    );
  }

  // Get post type display text
  String get postTypeDisplayText {
    switch (postType) {
      case PostType.availability:
        return 'Available to Connect';
      case PostType.event:
        return 'Event';
      case PostType.skillShare:
        return 'Skill Share';
      case PostType.collaboration:
        return 'Collaboration';
      case PostType.learning:
        return 'Learning';
      case PostType.general:
        return 'General';
    }
  }

  // Get category display text
  String get categoryDisplayText {
    switch (category) {
      case PostCategory.networking:
        return 'Networking';
      case PostCategory.mentorship:
        return 'Mentorship';
      case PostCategory.collaboration:
        return 'Collaboration';
      case PostCategory.learning:
        return 'Learning';
      case PostCategory.event:
        return 'Event';
      case PostCategory.availability:
        return 'Availability';
      case PostCategory.skillShare:
        return 'Skill Share';
      case PostCategory.investment:
        return 'Investment';
      case PostCategory.career:
        return 'Career';
      case PostCategory.industry:
        return 'Industry';
      case PostCategory.general:
        return 'General';
    }
  }

  // Check if post is location-based
  bool get isLocationBased => latitude != null && longitude != null;

  // Check if post is time-sensitive
  bool get isTimeSensitive => startAt.isBefore(DateTime.now()) && endAt.isAfter(DateTime.now());

  // Check if post is expired
  bool get isExpired => endAt.isBefore(DateTime.now());

  // Get engagement score (simple algorithm)
  double get engagementScore {
    return (viewCount * 0.1) + (likeCount * 1.0) + (commentCount * 2.0) + (shareCount * 3.0);
  }

  // Get post relevance score for a user
  double getRelevanceScore({
    required List<String> userSkills,
    required List<String> userInterests,
    required String? userIndustry,
    required String? userLocation,
  }) {
    double score = 0.0;
    
    // Skills match (40% weight)
    final skillOverlap = skills.toSet().intersection(userSkills.toSet()).length;
    score += (skillOverlap / skills.length) * 0.4;
    
    // Interests match (30% weight)
    final interestOverlap = interests.toSet().intersection(userInterests.toSet()).length;
    score += (interestOverlap / interests.length) * 0.3;
    
    // Industry match (20% weight)
    if (userIndustry != null && industry == userIndustry) {
      score += 0.2;
    }
    
    // Location match (10% weight)
    if (userLocation != null && location == userLocation) {
      score += 0.1;
    }
    
    return score;
  }
}

class AvailabilityStatus {
  final bool isAvailable;
  final VisibilityAudience audience;
  final String? message;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final List<String> seekingConnections;
  final List<String> preferredMeetingTypes;
  final List<String> preferredMeetingLocations;

  const AvailabilityStatus({
    required this.isAvailable,
    required this.audience,
    this.message,
    this.location,
    this.latitude,
    this.longitude,
    this.availableFrom,
    this.availableUntil,
    this.seekingConnections = const [],
    this.preferredMeetingTypes = const [],
    this.preferredMeetingLocations = const [],
  });

  factory AvailabilityStatus.fromMap(Map<String, dynamic> map) {
    return AvailabilityStatus(
      isAvailable: map['isAvailable'] ?? false,
      audience: VisibilityAudience.values.firstWhere(
        (e) => e.toString() == 'VisibilityAudience.${map['audience']}',
        orElse: () => VisibilityAudience.everyone,
      ),
      message: map['message'],
      location: map['location'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      availableFrom: map['availableFrom'] != null ? (map['availableFrom'] as Timestamp).toDate() : null,
      availableUntil: map['availableUntil'] != null ? (map['availableUntil'] as Timestamp).toDate() : null,
      seekingConnections: List<String>.from(map['seekingConnections'] ?? []),
      preferredMeetingTypes: List<String>.from(map['preferredMeetingTypes'] ?? []),
      preferredMeetingLocations: List<String>.from(map['preferredMeetingLocations'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isAvailable': isAvailable,
      'audience': audience.toString().split('.').last,
      'message': message,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'availableFrom': availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableUntil': availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'seekingConnections': seekingConnections,
      'preferredMeetingTypes': preferredMeetingTypes,
      'preferredMeetingLocations': preferredMeetingLocations,
    };
  }
}

class ReferralReward {
  final int credits;
  final int invitedCount;

  const ReferralReward({
    required this.credits,
    required this.invitedCount,
  });

  factory ReferralReward.fromMap(Map<String, dynamic> map) {
    return ReferralReward(
      credits: map['credits'] ?? 0,
      invitedCount: map['invitedCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'credits': credits,
      'invitedCount': invitedCount,
    };
  }
}

// Smart Tagging System
class SmartTag {
  final String id;
  final String name;
  final TagType type;
  final String? description;
  final int usageCount;
  final double popularity;
  final List<String> relatedTags;
  final bool isAutoGenerated;
  final DateTime createdAt;
  final DateTime lastUsed;

  const SmartTag({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.usageCount = 0,
    this.popularity = 0.0,
    this.relatedTags = const [],
    this.isAutoGenerated = false,
    required this.createdAt,
    required this.lastUsed,
  });

  factory SmartTag.fromMap(Map<String, dynamic> map) {
    return SmartTag(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: TagType.values.firstWhere(
        (e) => e.toString() == 'TagType.${map['type']}',
        orElse: () => TagType.general,
      ),
      description: map['description'],
      usageCount: map['usageCount'] ?? 0,
      popularity: map['popularity']?.toDouble() ?? 0.0,
      relatedTags: List<String>.from(map['relatedTags'] ?? []),
      isAutoGenerated: map['isAutoGenerated'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUsed: (map['lastUsed'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'description': description,
      'usageCount': usageCount,
      'popularity': popularity,
      'relatedTags': relatedTags,
      'isAutoGenerated': isAutoGenerated,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUsed': Timestamp.fromDate(lastUsed),
    };
  }
}

enum TagType {
  industry,
  skill,
  location,
  event,
  company,
  role,
  interest,
  goal,
  general
}

// Interest Matching System
class InterestMatch {
  final String id;
  final String userId;
  final String postId;
  final double score;
  final List<String> matchingFactors;
  final DateTime matchedAt;
  final bool isViewed;
  final bool isLiked;
  final bool isBookmarked;

  const InterestMatch({
    required this.id,
    required this.userId,
    required this.postId,
    required this.score,
    required this.matchingFactors,
    required this.matchedAt,
    this.isViewed = false,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  factory InterestMatch.fromMap(Map<String, dynamic> map) {
    return InterestMatch(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      postId: map['postId'] ?? '',
      score: map['score']?.toDouble() ?? 0.0,
      matchingFactors: List<String>.from(map['matchingFactors'] ?? []),
      matchedAt: (map['matchedAt'] as Timestamp).toDate(),
      isViewed: map['isViewed'] ?? false,
      isLiked: map['isLiked'] ?? false,
      isBookmarked: map['isBookmarked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'postId': postId,
      'score': score,
      'matchingFactors': matchingFactors,
      'matchedAt': Timestamp.fromDate(matchedAt),
      'isViewed': isViewed,
      'isLiked': isLiked,
      'isBookmarked': isBookmarked,
    };
  }
}
