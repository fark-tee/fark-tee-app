import '../../../core/widgets/map/lat_lng.dart';
import 'meetup_enums.dart';

/// A meetup participant. Fields are plain mutable state (matching the
/// codebase's existing convention, e.g. `AuthController`) since the live
/// simulation in `MockMeetupRepository` mutates members in place every tick.
class MeetupMember {
  MeetupMember({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.initials,
    this.inviteStatus = MemberInviteStatus.pending,
    this.arrivalStatus = MemberArrivalStatus.notLeftYet,
    this.isCurrentUser = false,
    this.startPosition,
    this.initialDistanceMeters,
    this.remainingDistanceMeters,
    this.reportedPosition,
    this.profileImageUrl,
    this.estimatedArrivalAt,
    this.destinationLabel,
    this.destinationPosition,
  });

  final String userId;
  final String displayName;
  final String handle;
  final String initials;
  final bool isCurrentUser;

  /// The member's profile photo URL, when they have one set.
  final String? profileImageUrl;

  MemberInviteStatus inviteStatus;
  MemberArrivalStatus arrivalStatus;

  /// Where this member's simulated walk starts from (only set once the
  /// meetup is live and the member is en route).
  LatLng? startPosition;
  double? initialDistanceMeters;
  double? remainingDistanceMeters;

  /// The member's actual last-reported GPS position, from a real backend.
  /// When set, [currentPosition] uses this directly instead of interpolating
  /// between [startPosition] and the venue.
  LatLng? reportedPosition;

  /// OSRM-computed estimated arrival time at this member's trip destination,
  /// as of their last reported position. Null until they've started a trip.
  DateTime? estimatedArrivalAt;

  /// The saved location this member picked when heading home (see
  /// `MeetupsController.goHome`), so the live map can plot their target and
  /// a route to it. Only ever set for [MemberArrivalStatus.headingHome] -
  /// there's no equivalent for the depart leg, whose target is always the
  /// meetup venue.
  String? destinationLabel;
  LatLng? destinationPosition;

  /// Interpolates a live map position between [startPosition] and [venue]
  /// based on how much of the walk remains. Falls back to [venue] once
  /// arrived/not tracked, so an arrived member's pin sits on the venue.
  LatLng currentPosition(LatLng venue) {
    final reported = reportedPosition;
    if (reported != null) return reported;

    final start = startPosition;
    final initial = initialDistanceMeters;
    final remaining = remainingDistanceMeters;
    if (start == null || initial == null || remaining == null || initial <= 0) {
      return venue;
    }
    final t = (1 - remaining / initial).clamp(0.0, 1.0);
    return LatLng(
      start.latitude + (venue.latitude - start.latitude) * t,
      start.longitude + (venue.longitude - start.longitude) * t,
    );
  }
}
