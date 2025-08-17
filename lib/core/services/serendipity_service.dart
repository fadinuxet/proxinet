import 'dart:async';
import 'package:uuid/uuid.dart';
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

  void dispose() {
    _postsStream.close();
  }
}
