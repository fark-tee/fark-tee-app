import 'dart:async';
import 'dart:math';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/mock_identity.dart';
import '../../../core/widgets/map/lat_lng.dart';
import '../models/grouped_meetups.dart';
import '../models/meetup.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_invite.dart';
import '../models/meetup_location.dart';
import '../models/meetup_member.dart';
import 'meetup_repository.dart';
import 'party_dto.dart';

/// Real backend-backed [MeetupRepository]. Maps the backend's Party/Trip/
/// Position model onto this app's `Meetup`/`MeetupMember` view models.
///
/// Known limitations, given what the backend currently exposes:
/// - There's no server-side "arrived" concept - it's derived here from the
///   distance between a member's last reported position and the party's
///   destination (see [_arrivalRadiusMeters]).
/// - The backend doesn't record trip *direction* on the positions list, so a
///   member walking home looks identical to one walking to the venue. Only
///   the current device's own "heading home" state (set via [goHome]) is
///   tracked, and only locally - other members will never show as
///   `headingHome` on this device.
class HttpMeetupRepository implements MeetupRepository {
  HttpMeetupRepository({
    required ApiClient apiClient,
    required LocationService locationService,
  }) : _apiClient = apiClient,
       _locationService = locationService;

  final ApiClient _apiClient;
  final LocationService _locationService;

  String? _currentUserId;

  /// Meetups where this device has started a depart trip but not yet
  /// confirmed arrival - while true, [watchMeetup] reports a fresh GPS
  /// position on every poll tick.
  final Set<String> _activeTripMeetupIds = {};

  /// Meetups where this device has tapped "Go Home" - purely a local display
  /// hint, see the class doc comment.
  final Set<String> _headingHomeMeetupIds = {};

  final Map<String, StreamController<Meetup>> _liveControllers = {};
  final Map<String, Timer> _liveTimers = {};

  static const _arrivalRadiusMeters = 100.0;
  static const _pollInterval = Duration(seconds: 8);
  static const _locationSharingWindow = Duration(hours: 1);
  static const _pastAfter = Duration(hours: 4);

  @override
  void setCurrentUserIdentity({
    required String id,
    required String displayName,
    required String handle,
    required String initials,
  }) {
    _currentUserId = id;
  }

  @override
  Future<List<Meetup>> getActiveGroups() async {
    final now = DateTime.now();
    final parties = await _fetchMyParties();
    final active = parties.where(
      (p) =>
          !_isPast(p.targetTime) && p.targetTime.difference(now) < const Duration(hours: 20),
    );
    return Future.wait(active.map(_buildMeetup));
  }

  @override
  Future<GroupedMeetups> listGroups() async {
    final now = DateTime.now();
    final parties = await _fetchMyParties();
    final meetups = await Future.wait(parties.map(_buildMeetup));

    final tonight = <Meetup>[];
    final upcoming = <Meetup>[];
    final past = <Meetup>[];
    for (final meetup in meetups) {
      if (meetup.isPast) {
        past.add(meetup);
        continue;
      }
      final isToday =
          meetup.startTime.year == now.year &&
          meetup.startTime.month == now.month &&
          meetup.startTime.day == now.day;
      (isToday ? tonight : upcoming).add(meetup);
    }
    past.sort((a, b) => b.startTime.compareTo(a.startTime));
    return GroupedMeetups(tonight: tonight, upcoming: upcoming, past: past);
  }

  @override
  Future<Meetup> getMeetup(String id) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/v1/parties/$id');
    return _buildMeetup(PartyDto.fromJson(response.data!));
  }

  @override
  Future<Meetup> createMeetup({
    required String title,
    required MeetupLocation location,
    required DateTime startTime,
    required List<MeetupMember> members,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/v1/parties',
      data: {
        'name': title,
        'destinationName': location.name,
        'destinationLat': location.position.latitude,
        'destinationLng': location.position.longitude,
        'targetTime': startTime.toUtc().toIso8601String(),
      },
    );
    final party = PartyDto.fromJson(response.data!);

    for (final member in members) {
      if (member.isCurrentUser) continue;
      try {
        await _apiClient.dio.post<void>(
          '/v1/parties/${party.id}/members',
          data: {'userId': member.userId},
        );
      } catch (_) {
        // Best-effort: an invitee that doesn't exist as a real backend user
        // (or is already a member) shouldn't stop the party from being
        // created - the roster below reflects who was actually invited.
      }
    }

    return _buildMeetup(party);
  }

  @override
  Future<void> setCurrentUserArrivalStatus(
    String meetupId,
    MemberArrivalStatus status,
  ) async {
    final position = await _locationService.getCurrentPosition();
    switch (status) {
      case MemberArrivalStatus.onTheWay:
        await _apiClient.dio.post<void>(
          '/v1/parties/$meetupId/trips',
          data: {
            'direction': 'DEPART',
            'lat': position.latitude,
            'lng': position.longitude,
          },
        );
        _activeTripMeetupIds.add(meetupId);
      case MemberArrivalStatus.arrived:
        await _apiClient.dio.post<void>(
          '/v1/parties/$meetupId/positions',
          data: {'lat': position.latitude, 'lng': position.longitude},
        );
        _activeTripMeetupIds.remove(meetupId);
      case MemberArrivalStatus.notLeftYet:
      case MemberArrivalStatus.headingHome:
        break;
    }
    await _pushUpdate(meetupId);
  }

  @override
  Future<void> goHome(String meetupId, {required String destinationLabel}) async {
    final position = await _locationService.getCurrentPosition();
    await _apiClient.dio.post<void>(
      '/v1/parties/$meetupId/trips',
      data: {
        'direction': 'RETURN',
        'lat': position.latitude,
        'lng': position.longitude,
      },
    );
    _activeTripMeetupIds.remove(meetupId);
    _headingHomeMeetupIds.add(meetupId);
  }

  @override
  Future<void> sendNudge(String meetupId, String memberId) async {
    // No backend endpoint exists for this - purely cosmetic, same as mock.
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Stream<Meetup> watchMeetup(String meetupId) {
    final existing = _liveControllers[meetupId];
    if (existing != null) return existing.stream;

    late final StreamController<Meetup> controller;
    controller = StreamController<Meetup>.broadcast(
      onListen: () {
        _liveTimers[meetupId] ??= Timer.periodic(
          _pollInterval,
          (_) => _pushUpdate(meetupId),
        );
        _pushUpdate(meetupId);
      },
      onCancel: () {
        if (!controller.hasListener) {
          _liveTimers.remove(meetupId)?.cancel();
          _liveControllers.remove(meetupId);
        }
      },
    );
    _liveControllers[meetupId] = controller;
    return controller.stream;
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/v1/users/search',
      queryParameters: {'q': query},
    );
    final users = (response.data!['users'] as List<dynamic>?) ?? [];
    return users
        .cast<Map<String, dynamic>>()
        .map(UserProfile.fromJson)
        .where((u) => u.id != _currentUserId)
        .toList();
  }

  @override
  Future<List<MeetupInvite>> listInvites() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/v1/me/invites');
    final invites = (response.data!['invites'] as List<dynamic>?) ?? [];
    return invites.cast<Map<String, dynamic>>().map(PartyInviteDto.fromJson).map(
      (invite) => MeetupInvite(
        meetupId: invite.party.id,
        title: invite.party.name,
        destinationName: invite.party.destinationName,
        startTime: invite.party.targetTime,
        invitedByName: invite.party.createdByName,
      ),
    ).toList();
  }

  @override
  Future<void> acceptInvite(String meetupId) async {
    await _apiClient.dio.post<void>('/v1/parties/$meetupId/members/accept');
  }

  @override
  Future<void> declineInvite(String meetupId) async {
    await _apiClient.dio.post<void>('/v1/parties/$meetupId/members/decline');
  }

  Future<void> _pushUpdate(String meetupId) async {
    final controller = _liveControllers[meetupId];
    if (controller == null || controller.isClosed) return;

    if (_activeTripMeetupIds.contains(meetupId)) {
      try {
        final position = await _locationService.getCurrentPosition();
        await _apiClient.dio.post<void>(
          '/v1/parties/$meetupId/positions',
          data: {'lat': position.latitude, 'lng': position.longitude},
        );
      } catch (_) {
        // A transient GPS/network hiccup shouldn't stop everyone else's
        // positions from still refreshing below.
      }
    }

    try {
      final meetup = await getMeetup(meetupId);
      if (!controller.isClosed) controller.add(meetup);
    } catch (_) {
      // Swallow - the next tick will retry.
    }
  }

  Future<List<PartyDto>> _fetchMyParties() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/v1/me/parties');
    final parties = (response.data!['parties'] as List<dynamic>?) ?? [];
    return parties.cast<Map<String, dynamic>>().map(PartyDto.fromJson).toList();
  }

  Future<Meetup> _buildMeetup(PartyDto party) async {
    final destination = LatLng(party.destinationLat, party.destinationLng);

    final results = await Future.wait([
      _apiClient.dio
          .get<Map<String, dynamic>>('/v1/parties/${party.id}/members')
          .then((r) => (r.data!['members'] as List<dynamic>?) ?? []),
      _apiClient.dio
          .get<Map<String, dynamic>>('/v1/parties/${party.id}/positions')
          .then((r) => (r.data!['positions'] as List<dynamic>?) ?? []),
    ]);

    final memberDtos = results[0]
        .cast<Map<String, dynamic>>()
        .map(PartyMemberDto.fromJson)
        .toList();
    final positionDtos = results[1].cast<Map<String, dynamic>>().map(PositionDto.fromJson);
    final positionsByUserId = {for (final p in positionDtos) p.userId: p};

    final members = memberDtos.map((memberDto) {
      final isCurrentUser = memberDto.userId == _currentUserId;
      final position = positionsByUserId[memberDto.userId];
      final reportedPosition = position == null
          ? null
          : LatLng(position.lat, position.lng);
      final distance = reportedPosition == null
          ? null
          : _distanceMeters(reportedPosition, destination);

      MemberArrivalStatus arrivalStatus;
      if (distance == null) {
        arrivalStatus = MemberArrivalStatus.notLeftYet;
      } else if (distance <= _arrivalRadiusMeters) {
        arrivalStatus = MemberArrivalStatus.arrived;
      } else if (isCurrentUser && _headingHomeMeetupIds.contains(party.id)) {
        arrivalStatus = MemberArrivalStatus.headingHome;
      } else {
        arrivalStatus = MemberArrivalStatus.onTheWay;
      }

      return MeetupMember(
        userId: memberDto.userId,
        displayName: memberDto.userDisplayName,
        handle: mockHandleFor(memberDto.userDisplayName),
        initials: initialsFor(memberDto.userDisplayName),
        inviteStatus: memberDto.status == 'ACCEPTED'
            ? MemberInviteStatus.accepted
            : MemberInviteStatus.pending,
        arrivalStatus: arrivalStatus,
        isCurrentUser: isCurrentUser,
        reportedPosition: reportedPosition,
        remainingDistanceMeters: distance,
        profileImageUrl: memberDto.userProfileImage.isEmpty
            ? null
            : memberDto.userProfileImage,
      );
    }).toList();

    return Meetup(
      id: party.id,
      title: party.name,
      location: MeetupLocation(
        name: party.destinationName,
        address: party.destinationName,
        position: destination,
      ),
      startTime: party.targetTime,
      status: _deriveStatus(party.targetTime),
      members: members,
    );
  }

  MeetupStatus _deriveStatus(DateTime targetTime) {
    if (_isPast(targetTime)) return MeetupStatus.completed;
    if (DateTime.now().isAfter(targetTime.subtract(_locationSharingWindow))) {
      return MeetupStatus.live;
    }
    return MeetupStatus.upcoming;
  }

  bool _isPast(DateTime targetTime) => DateTime.now().isAfter(targetTime.add(_pastAfter));
}

double _distanceMeters(LatLng a, LatLng b) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);
  final sinDLat = sin(dLat / 2);
  final sinDLng = sin(dLng / 2);
  final h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLng * sinDLng;
  final c = 2 * atan2(sqrt(h), sqrt(1 - h));
  return earthRadiusMeters * c;
}

double _degToRad(double deg) => deg * (pi / 180);
