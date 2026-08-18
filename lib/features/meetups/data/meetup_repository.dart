import '../../../core/auth/auth_models.dart';
import '../models/grouped_meetups.dart';
import '../models/meetup.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_invite.dart';
import '../models/meetup_location.dart';
import '../models/meetup_member.dart';

/// Meetup data access. `MockMeetupRepository` is the only implementation for
/// now (no backend yet) - once one exists, a `HttpMeetupRepository` can
/// implement this same interface and nothing above the repository layer
/// needs to change.
abstract class MeetupRepository {
  /// Patches the `isCurrentUser` member across all seeded meetups once the
  /// real signed-in identity is known (unavailable at repository
  /// construction time, since that happens before auth bootstrap resolves).
  void setCurrentUserIdentity({
    required String id,
    required String displayName,
    required String handle,
    required String initials,
  });

  /// Meetups happening soon enough to show on Home's "Active Groups" card.
  Future<List<Meetup>> getActiveGroups();

  /// Everything, bucketed for the Groups screen.
  Future<GroupedMeetups> listGroups();

  Future<Meetup> getMeetup(String id);

  Future<Meetup> createMeetup({
    required String title,
    required MeetupLocation location,
    required DateTime startTime,
    required List<MeetupMember> members,
  });

  Future<void> setCurrentUserArrivalStatus(
    String meetupId,
    MemberArrivalStatus status,
  );

  Future<void> goHome(String meetupId, {required String destinationLabel});

  /// Purely social - never mutates the target member's real status.
  Future<void> sendNudge(String meetupId, String memberId);

  /// Emits the meetup every time simulated member positions/arrivals change.
  /// Callers should cancel their subscription when they navigate away.
  Stream<Meetup> watchMeetup(String meetupId);

  /// Looks up candidate users to invite to a meetup, by display name/ID.
  Future<List<UserProfile>> searchUsers(String query);

  /// Pending invites for the current user.
  Future<List<MeetupInvite>> listInvites();

  /// Accepts a pending invite, joining the meetup.
  Future<void> acceptInvite(String meetupId);

  /// Declines a pending invite, removing yourself from the meetup.
  Future<void> declineInvite(String meetupId);
}
