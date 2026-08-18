import 'meetup.dart';

/// The Groups screen's three sections.
class GroupedMeetups {
  const GroupedMeetups({
    this.tonight = const [],
    this.upcoming = const [],
    this.past = const [],
  });

  final List<Meetup> tonight;
  final List<Meetup> upcoming;
  final List<Meetup> past;
}
