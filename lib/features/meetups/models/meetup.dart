import 'meetup_enums.dart';
import 'meetup_location.dart';
import 'meetup_member.dart';

class Meetup {
  Meetup({
    required this.id,
    required this.title,
    required this.location,
    required this.startTime,
    required this.members,
    this.status = MeetupStatus.upcoming,
  });

  final String id;
  final String title;
  final MeetupLocation location;
  DateTime startTime;
  MeetupStatus status;
  List<MeetupMember> members;

  DateTime get locationSharingOpensAt =>
      startTime.subtract(const Duration(hours: 1));

  bool get isLocationSharingOpen =>
      DateTime.now().isAfter(locationSharingOpensAt);

  bool get isPast => DateTime.now().isAfter(startTime.add(const Duration(hours: 4)));

  int get arrivedCount =>
      members.where((m) => m.arrivalStatus == MemberArrivalStatus.arrived).length;

  MeetupMember get currentUser => members.firstWhere((m) => m.isCurrentUser);

  List<MeetupMember> get otherMembers =>
      members.where((m) => !m.isCurrentUser).toList();
}
