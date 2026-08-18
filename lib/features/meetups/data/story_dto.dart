/// Wire DTO mirroring the backend's `StoryResponse` schema
/// (docs/openapi.yaml). Kept separate from [MeetupStory], the app's own view
/// model, which [HttpMeetupRepository] builds from this.
class StoryDto {
  StoryDto({
    required this.id,
    required this.partyId,
    required this.userId,
    required this.image,
    required this.createdAt,
  });

  factory StoryDto.fromJson(Map<String, dynamic> json) {
    return StoryDto(
      id: json['id'] as String,
      partyId: json['partyId'] as String,
      userId: json['userId'] as String,
      image: json['image'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String partyId;
  final String userId;
  final String image;
  final DateTime createdAt;
}
