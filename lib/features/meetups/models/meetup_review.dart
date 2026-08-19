/// One party member's rating of another, left once the target has arrived
/// at the venue.
class MeetupReview {
  MeetupReview({
    required this.id,
    required this.partyId,
    required this.reviewerId,
    required this.targetUserId,
    required this.score,
    required this.createdAt,
  });

  final String id;
  final String partyId;
  final String reviewerId;
  final String targetUserId;
  final int score;
  final DateTime createdAt;
}
