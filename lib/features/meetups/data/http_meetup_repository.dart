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
/// Position/PartyMember model onto this app's `Meetup`/`MeetupMember` view
/// models. Arrival state is the party member's server-side `tripStatus`
/// (`PENDING_DEPARTURE` -> `DEPARTED` -> `ARRIVED` -> `RETURNING` ->
/// `RETURNED`), so it's consistent for every member on every device.
class HttpMeetupRepository implements MeetupRepository {
  HttpMeetupRepository({
    required ApiClient apiClient,
    required LocationService locationService,
  }) : _apiClient = apiClient,
       _locationService = locationService;

  final ApiClient _apiClient;
  final LocationService _locationService;

  String? _currentUserId;

  /// Meetups where this device has started a depart trip but hasn't yet
  /// reached the venue - while a meetupId is present, [watchMeetup] reports
  /// a fresh GPS position on every poll tick, and once that position is
  /// within [_arrivalRadiusMeters] of the venue, [_pushUpdate] stops sending
  /// updates and advances the trip status to ARRIVED automatically.
  final Set<String> _activeDepartMeetupIds = {};

  /// Meetups where this device has started a return trip but hasn't yet
  /// reached home - same auto-stop/auto-advance behavior as
  /// [_activeDepartMeetupIds], except the target is the chosen destination
  /// (there's no venue to walk back to) and the terminal status is RETURNED.
  final Map<String, LatLng> _activeReturnTargets = {};

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
        await _updateTripStatus(meetupId, 'DEPARTED');
        _activeDepartMeetupIds.add(meetupId);
      case MemberArrivalStatus.arrived:
        await _apiClient.dio.post<void>(
          '/v1/parties/$meetupId/positions',
          data: {'lat': position.latitude, 'lng': position.longitude},
        );
        await _updateTripStatus(meetupId, 'ARRIVED');
        _activeDepartMeetupIds.remove(meetupId);
      case MemberArrivalStatus.notLeftYet:
      case MemberArrivalStatus.headingHome:
      case MemberArrivalStatus.returned:
        break;
    }
    await _pushUpdate(meetupId);
  }

  @override
  Future<void> goHome(
    String meetupId, {
    required String destinationLabel,
    required LatLng destinationPosition,
  }) async {
    final position = await _locationService.getCurrentPosition();
    await _apiClient.dio.post<void>(
      '/v1/parties/$meetupId/trips',
      data: {
        'direction': 'RETURN',
        'lat': position.latitude,
        'lng': position.longitude,
      },
    );
    await _updateTripStatus(meetupId, 'RETURNING');
    _activeDepartMeetupIds.remove(meetupId);
    _activeReturnTargets[meetupId] = destinationPosition;
  }

  Future<void> _updateTripStatus(String meetupId, String status) {
    return _apiClient.dio.patch<void>(
      '/v1/parties/$meetupId/trip-status',
      data: {'status': status},
    );
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

    final isDeparting = _activeDepartMeetupIds.contains(meetupId);
    final returnTarget = _activeReturnTargets[meetupId];

    LatLng? currentPosition;
    if (isDeparting || returnTarget != null) {
      try {
        currentPosition = await _locationService.getCurrentPosition();
        await _apiClient.dio.post<void>(
          '/v1/parties/$meetupId/positions',
          data: {'lat': currentPosition.latitude, 'lng': currentPosition.longitude},
        );
      } catch (_) {
        // A transient GPS/network hiccup shouldn't stop everyone else's
        // positions from still refreshing below.
      }
    }

    Meetup meetup;
    try {
      meetup = await getMeetup(meetupId);
    } catch (_) {
      // Swallow - the next tick will retry.
      return;
    }

    // Once within arrival range of the leg's target, stop sending this
    // device's location and advance the trip status - the next tick then
    // finds neither an active depart nor return target and goes quiet.
    if (currentPosition != null) {
      if (isDeparting &&
          _distanceMeters(currentPosition, meetup.location.position) <=
              _arrivalRadiusMeters) {
        _activeDepartMeetupIds.remove(meetupId);
        await _updateTripStatus(meetupId, 'ARRIVED');
        meetup.currentUser.arrivalStatus = MemberArrivalStatus.arrived;
      } else if (returnTarget != null &&
          _distanceMeters(currentPosition, returnTarget) <= _arrivalRadiusMeters) {
        _activeReturnTargets.remove(meetupId);
        await _updateTripStatus(meetupId, 'RETURNED');
        meetup.currentUser.arrivalStatus = MemberArrivalStatus.returned;
      }
    }

    if (!controller.isClosed) controller.add(meetup);
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

      return MeetupMember(
        userId: memberDto.userId,
        displayName: memberDto.userDisplayName,
        handle: mockHandleFor(memberDto.userDisplayName),
        initials: initialsFor(memberDto.userDisplayName),
        inviteStatus: memberDto.status == 'ACCEPTED'
            ? MemberInviteStatus.accepted
            : MemberInviteStatus.pending,
        arrivalStatus: _arrivalStatusFrom(memberDto.tripStatus),
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

MemberArrivalStatus _arrivalStatusFrom(String tripStatus) {
  switch (tripStatus) {
    case 'DEPARTED':
      return MemberArrivalStatus.onTheWay;
    case 'ARRIVED':
      return MemberArrivalStatus.arrived;
    case 'RETURNING':
      return MemberArrivalStatus.headingHome;
    case 'RETURNED':
      return MemberArrivalStatus.returned;
    case 'PENDING_DEPARTURE':
    default:
      return MemberArrivalStatus.notLeftYet;
  }
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
