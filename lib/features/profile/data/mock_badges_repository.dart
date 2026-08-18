import '../models/profile_badge.dart';

/// No badge-earning backend logic exists yet - this just supplies the two
/// badges shown in the reference Profile screen.
class MockBadgesRepository {
  Future<List<ProfileBadge>> getBadges() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      ProfileBadge(
        title: 'Always On Time',
        description: 'Arrived early or on time 5x in a row',
      ),
      ProfileBadge(
        title: 'Reliable',
        description: 'On time for 80% or more of meetups',
      ),
    ];
  }
}
