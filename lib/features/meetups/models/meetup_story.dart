/// A single story photo posted by a meetup member.
class MeetupStory {
  const MeetupStory({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String imageUrl;
  final DateTime createdAt;
}
