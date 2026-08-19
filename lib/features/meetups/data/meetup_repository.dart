import 'dart:io';

import '../../../core/auth/auth_models.dart';
import '../../../core/widgets/map/lat_lng.dart';
import '../models/grouped_meetups.dart';
import '../models/meetup.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_invite.dart';
import '../models/meetup_location.dart';
import '../models/meetup_member.dart';
import '../models/meetup_review.dart';
import '../models/meetup_story.dart';

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

  /// [destination] is required when [status] is [MemberArrivalStatus.onTheWay]
  /// - it's where the current user is heading (the meetup's venue), used to
  /// start a DEPART trip and compute its estimated travel time.
  Future<void> setCurrentUserArrivalStatus(
    String meetupId,
    MemberArrivalStatus status, {
    MeetupLocation? destination,
  });

  Future<void> goHome(
    String meetupId, {
    required String destinationLabel,
    required LatLng destinationPosition,
  });

  /// Purely social - never mutates the target member's real status.
  Future<void> sendNudge(String meetupId, String memberId);

  /// Asks [memberId] - who must currently be [MemberArrivalStatus.headingHome]
  /// - to confirm they're okay, via a push notification. Sets their
  /// [CheckInStatus.pending] until they respond.
  Future<void> requestCheckIn(String meetupId, String memberId);

  /// Records the current user's answer to their own pending check-in
  /// request.
  Future<void> respondCheckIn(String meetupId, CheckInStatus status);

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

  /// Uploads [imageFile] as a new story photo in this meetup, visible to
  /// every party member.
  Future<void> postStory(String meetupId, File imageFile);

  /// A single member's story photos in this meetup, most recent first.
  Future<List<MeetupStory>> listMemberStories(String meetupId, String userId);

  /// Leaves a review for [targetUserId] within [meetupId], once they've
  /// arrived at the venue. Throws if the current user has already reviewed
  /// them for this meetup.
  Future<MeetupReview> submitReview(
    String meetupId,
    String targetUserId, {
    required int score,
  });

  /// Every review the current user has left within [meetupId].
  Future<List<MeetupReview>> listMyReviews(String meetupId);
}
