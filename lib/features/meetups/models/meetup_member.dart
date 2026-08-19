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
    this.checkInStatus = CheckInStatus.none,
    this.checkInRequestedByUserId,
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

  /// This member's current "are you okay?" safety check status, and who
  /// asked (only meaningful while [checkInStatus] is
  /// [CheckInStatus.pending]).
  CheckInStatus checkInStatus;
  String? checkInRequestedByUserId;

  /// Interpolates a live map position between [startPosition] and [venue]
  /// based on how much of the walk remains, or falls back to a
  /// status-appropriate resting point once there's nothing to interpolate.
  /// Returns null when this member's real position genuinely isn't known
  /// yet - e.g. [notLeftYet] or an [onTheWay] member whose first GPS fix
  /// hasn't landed - rather than fabricating a pin at the venue, which used
  /// to make members look like they'd already reached the destination
  /// before they'd actually left home.
  LatLng? currentPosition(LatLng venue) {
    final reported = reportedPosition;
    if (reported != null) return reported;

    final start = startPosition;
    final initial = initialDistanceMeters;
    final remaining = remainingDistanceMeters;
    if (start != null && initial != null && remaining != null && initial > 0) {
      final t = (1 - remaining / initial).clamp(0.0, 1.0);
      return LatLng(
        start.latitude + (venue.latitude - start.latitude) * t,
        start.longitude + (venue.longitude - start.longitude) * t,
      );
    }

    switch (arrivalStatus) {
      case MemberArrivalStatus.arrived:
        return venue;
      case MemberArrivalStatus.headingHome:
        // The return leg genuinely starts at the venue - everyone left from
        // there - so this is a real position, not a placeholder.
        return venue;
      case MemberArrivalStatus.returned:
        return destinationPosition ?? venue;
      case MemberArrivalStatus.notLeftYet:
      case MemberArrivalStatus.onTheWay:
        return null;
    }
  }
}
