/// Wire DTO mirroring the backend's `ReviewResponse` schema
/// (docs/openapi.yaml). Kept separate from [MeetupReview], the app's own
/// view model, which [HttpMeetupRepository] builds from this.
class ReviewDto {
  ReviewDto({
    required this.id,
    required this.partyId,
    required this.reviewerId,
    required this.targetUserId,
    required this.score,
    required this.createdAt,
  });

  factory ReviewDto.fromJson(Map<String, dynamic> json) {
    return ReviewDto(
      id: json['id'] as String,
      partyId: json['partyId'] as String,
      reviewerId: json['reviewerId'] as String,
      targetUserId: json['targetUserId'] as String,
      score: json['score'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String partyId;
  final String reviewerId;
  final String targetUserId;
  final int score;
  final DateTime createdAt;
}
