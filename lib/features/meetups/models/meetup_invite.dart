/// A pending invite to join a meetup, from `GET /v1/me/invites`.
class MeetupInvite {
  const MeetupInvite({
    required this.meetupId,
    required this.title,
    required this.destinationName,
    required this.startTime,
    required this.invitedByName,
  });

  final String meetupId;
  final String title;
  final String destinationName;
  final DateTime startTime;
  final String invitedByName;
}
