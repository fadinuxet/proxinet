// Models for Serendipity core features

enum VisibilityAudience { firstDegree, secondDegree, custom, everyone }

// User interests and networking preferences
class UserInterests {
  final String? industry;
  final String? skills;
  final String? networkingGoals;
  final List<String> tags;
  final String? location;
  final DateTime? lastUpdated;

  UserInterests({
    this.industry,
    this.skills,
    this.networkingGoals,
    this.tags = const [],
    this.location,
    this.lastUpdated,
  });

  factory UserInterests.fromMap(Map<String, dynamic> map) {
    return UserInterests(
      industry: map['industry']?.toString(),
      skills: map['skills']?.toString(),
      networkingGoals: map['networkingGoals']?.toString(),
      tags: List<String>.from(map['tags'] ?? []),
      location: map['location']?.toString(),
      lastUpdated: map['lastUpdated']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (industry != null) 'industry': industry,
      if (skills != null) 'skills': skills,
      if (networkingGoals != null) 'networkingGoals': networkingGoals,
      'tags': tags,
      if (location != null) 'location': location,
      'lastUpdated': lastUpdated,
    };
  }

  UserInterests copyWith({
    String? industry,
    String? skills,
    String? networkingGoals,
    List<String>? tags,
    String? location,
    DateTime? lastUpdated,
  }) {
    return UserInterests(
      industry: industry ?? this.industry,
      skills: skills ?? this.skills,
      networkingGoals: networkingGoals ?? this.networkingGoals,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get hasInterests => 
      (industry?.isNotEmpty ?? false) || 
      (skills?.isNotEmpty ?? false) || 
      (networkingGoals?.isNotEmpty ?? false) ||
      tags.isNotEmpty;

  List<String> get allInterests {
    final interests = <String>[];
    if (industry?.isNotEmpty ?? false) interests.add(industry!);
    if (skills?.isNotEmpty ?? false) interests.add(skills!);
    if (networkingGoals?.isNotEmpty ?? false) interests.add(networkingGoals!);
    interests.addAll(tags);
    return interests;
  }
}

class SerendipityPost {
  final String id;
  final String authorId;
  final String text;
  final List<String> tags; // e.g. [#conference, #Berlin]
  final String? photoPath; // local path for now
  final VisibilityAudience audience;
  final Set<String> customGroupIds;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime createdAt;
  final bool archived;

  const SerendipityPost({
    required this.id,
    required this.authorId,
    required this.text,
    required this.tags,
    required this.photoPath,
    required this.audience,
    this.customGroupIds = const {},
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    this.archived = false,
  });
}

class AvailabilityStatus {
  final bool isAvailable;
  final DateTime? until;
  final VisibilityAudience audience;
  final Set<String> customGroupIds;
  const AvailabilityStatus({
    required this.isAvailable,
    this.until,
    required this.audience,
    this.customGroupIds = const {},
  });
}

class ReferralReward {
  final int credits;
  final int invitedCount;
  const ReferralReward({required this.credits, required this.invitedCount});
}
