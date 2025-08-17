// Models for Serendipity core features

enum VisibilityAudience { firstDegree, secondDegree, custom }

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
