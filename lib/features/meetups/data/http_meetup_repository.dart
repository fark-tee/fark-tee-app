import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/mock_identity.dart';
import '../../../core/widgets/map/lat_lng.dart';
import '../../../core/widgets/map/polyline_codec.dart';
import '../models/grouped_meetups.dart';
import '../models/meetup.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_invite.dart';
import '../models/meetup_location.dart';
import '../models/meetup_member.dart';
import '../models/meetup_review.dart';
import '../models/meetup_story.dart';
import 'meetup_repository.dart';
import 'party_dto.dart';
import 'review_dto.dart';
import 'story_dto.dart';

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
  /// [_reconcileActiveDepart] re-derives this from the server's own
  /// `tripStatus` on every fetch, so it survives this flag being lost (e.g.
  /// an app restart) instead of leaving the member's marker frozen forever.
  final Set<String> _activeDepartMeetupIds = {};

  /// Meetups where this device has started a return trip but hasn't yet
  /// reached home - same auto-stop/auto-advance behavior as
  /// [_activeDepartMeetupIds], except the target is the chosen destination
  /// (there's no venue to walk back to) and the terminal status is RETURNED.
  /// Unlike depart, this one can't self-heal the way
  /// [_reconcileActiveDepart] does for [_activeDepartMeetupIds]: the chosen
  /// destination isn't part of the party/member schema the server returns,
  /// so if this flag is lost, a "heading home" trip stops posting positions
  /// until the user re-triggers "Go Home".
  final Map<String, ({String label, LatLng position})> _activeReturnTargets = {};

  /// This device's last-fetched arrival status per meetup, from the previous
  /// [_pushUpdate] tick. Used to keep reporting this device's real GPS
  /// position while [MemberArrivalStatus.notLeftYet] - before the user has
  /// tapped "leave" - so other members see where this member actually is
  /// (e.g. still at home) instead of no pin at all; an unknown/missing entry
  /// (the very first tick after opening the live screen) is treated the same
  /// way, since PENDING_DEPARTURE is the common starting state.
  final Map<String, MemberArrivalStatus> _lastKnownArrivalStatus = {};

  final Map<String, StreamController<Meetup>> _liveControllers = {};
  final Map<String, Timer> _liveTimers = {};

  /// Route polylines already fetched for a given `partyId:userId:direction`,
  /// keyed since a trip's route is computed once by OSRM when it starts and
  /// never changes afterwards - so once fetched, it never needs re-fetching
  /// on later poll ticks.
  final Map<String, List<LatLng>> _routeCache = {};

  static const _arrivalRadiusMeters = 100.0;
  static const _pollInterval = Duration(seconds: 2);
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
    String? note,
    required List<MeetupMember> members,
  }) async {
    final trimmedNote = note?.trim();
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/v1/parties',
      data: {
        'name': title,
        'destinationName': location.name,
        'destinationLat': location.position.latitude,
        'destinationLng': location.position.longitude,
        'targetTime': startTime.toUtc().toIso8601String(),
        if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
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
    MemberArrivalStatus status, {
    MeetupLocation? destination,
  }) async {
    final position = await _locationService.getCurrentPosition();
    switch (status) {
      case MemberArrivalStatus.onTheWay:
        if (destination == null) {
          throw ArgumentError.notNull('destination');
        }
        await _apiClient.dio.post<void>(
          '/v1/parties/$meetupId/trips',
          data: {
            'direction': 'DEPART',
            'lat': position.latitude,
            'lng': position.longitude,
            'destinationName': destination.name,
            'destinationLat': destination.position.latitude,
            'destinationLng': destination.position.longitude,
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
        'destinationName': destinationLabel,
        'destinationLat': destinationPosition.latitude,
        'destinationLng': destinationPosition.longitude,
      },
    );
    await _updateTripStatus(meetupId, 'RETURNING');
    _activeDepartMeetupIds.remove(meetupId);
    _activeReturnTargets[meetupId] = (
      label: destinationLabel,
      position: destinationPosition,
    );
  }

  Future<void> _updateTripStatus(String meetupId, String status) {
    return _apiClient.dio.patch<void>(
      '/v1/parties/$meetupId/trip-status',
      data: {'status': status},
    );
  }

  @override
  Future<void> sendNudge(String meetupId, String memberId) async {
    await _apiClient.dio.post<void>('/v1/parties/$meetupId/members/$memberId/nudge');
  }

  @override
  Future<void> requestCheckIn(String meetupId, String memberId) async {
    await _apiClient.dio.post<void>('/v1/parties/$meetupId/members/$memberId/check-in');
  }

  @override
  Future<void> respondCheckIn(String meetupId, CheckInStatus status) async {
    await _apiClient.dio.patch<void>(
      '/v1/parties/$meetupId/check-in',
      data: {'status': _checkInStatusWireValue(status)},
    );
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

  @override
  Future<void> postStory(String meetupId, File imageFile) async {
    final filename = Uri.file(imageFile.path).pathSegments.last;
    final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
    await _apiClient.dio.post<void>(
      '/v1/parties/$meetupId/stories',
      data: FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      }),
    );
  }

  @override
  Future<List<MeetupStory>> listMemberStories(
    String meetupId,
    String userId,
  ) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/v1/parties/$meetupId/members/$userId/stories',
    );
    final stories = (response.data!['stories'] as List<dynamic>?) ?? [];
    return stories
        .cast<Map<String, dynamic>>()
        .map(StoryDto.fromJson)
        .map(
          (dto) => MeetupStory(
            id: dto.id,
            userId: dto.userId,
            imageUrl: dto.image,
            createdAt: dto.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<MeetupReview> submitReview(
    String meetupId,
    String targetUserId, {
    required int score,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/v1/parties/$meetupId/members/$targetUserId/review',
      data: {'score': score},
    );
    return _toMeetupReview(ReviewDto.fromJson(response.data!));
  }

  @override
  Future<List<MeetupReview>> listMyReviews(String meetupId) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/v1/parties/$meetupId/reviews',
    );
    final reviews = (response.data!['reviews'] as List<dynamic>?) ?? [];
    return reviews
        .cast<Map<String, dynamic>>()
        .map(ReviewDto.fromJson)
        .map(_toMeetupReview)
        .toList();
  }

  MeetupReview _toMeetupReview(ReviewDto dto) {
    return MeetupReview(
      id: dto.id,
      partyId: dto.partyId,
      reviewerId: dto.reviewerId,
      targetUserId: dto.targetUserId,
      score: dto.score,
      createdAt: dto.createdAt,
    );
  }

  Future<void> _pushUpdate(String meetupId) async {
    final controller = _liveControllers[meetupId];
    if (controller == null || controller.isClosed) return;

    final isDeparting = _activeDepartMeetupIds.contains(meetupId);
    final returnTarget = _activeReturnTargets[meetupId];
    final lastStatus = _lastKnownArrivalStatus[meetupId];
    final isPendingDeparture =
        lastStatus == null || lastStatus == MemberArrivalStatus.notLeftYet;
    debugPrint(
      '[live:$meetupId] tick - isDeparting=$isDeparting '
      'isPendingDeparture=$isPendingDeparture returnTarget=$returnTarget',
    );

    LatLng? currentPosition;
    if (isDeparting || returnTarget != null || isPendingDeparture) {
      try {
        currentPosition = await _locationService.getCurrentPosition();
        debugPrint('[live:$meetupId] got GPS fix: $currentPosition');
        await _apiClient.dio.post<void>(
          '/v1/parties/$meetupId/positions',
          data: {'lat': currentPosition.latitude, 'lng': currentPosition.longitude},
        );
        debugPrint('[live:$meetupId] posted position OK');
      } catch (e) {
        // A transient GPS/network hiccup shouldn't stop everyone else's
        // positions from still refreshing below - but log it, since a
        // *persistent* failure here (bad permission state, wrong endpoint,
        // etc.) would otherwise look identical to "the pin never moves"
        // with zero trace of why.
        debugPrint('[live:$meetupId] position post FAILED: $e');
      }
    }

    Meetup meetup;
    try {
      meetup = await getMeetup(meetupId);
    } catch (e) {
      // Swallow - the next tick will retry.
      debugPrint('[live:$meetupId] getMeetup FAILED: $e');
      return;
    }
    debugPrint(
      '[live:$meetupId] fetched meetup - currentUser.arrivalStatus='
      '${meetup.currentUser.arrivalStatus} '
      'currentUser.reportedPosition=${meetup.currentUser.reportedPosition}',
    );

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
          _distanceMeters(currentPosition, returnTarget.position) <=
              _arrivalRadiusMeters) {
        _activeReturnTargets.remove(meetupId);
        await _updateTripStatus(meetupId, 'RETURNED');
        meetup.currentUser.arrivalStatus = MemberArrivalStatus.returned;
      }
    }

    _lastKnownArrivalStatus[meetupId] = meetup.currentUser.arrivalStatus;
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
        estimatedArrivalAt: position?.estimatedArrivalAt,
        profileImageUrl: memberDto.userProfileImage.isEmpty
            ? null
            : memberDto.userProfileImage,
        checkInStatus: _checkInStatusFrom(memberDto.checkInStatus),
        checkInRequestedByUserId: memberDto.checkInRequestedByUserId,
      );
    }).toList();

    final meetup = Meetup(
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
      note: party.note,
    );
    _reconcileActiveDepart(party.id, meetup);
    _attachReturnDestination(party.id, meetup);
    await _attachRoutePolylines(party.id, meetup);
    return meetup;
  }

  /// Fetches and attaches each currently-traveling member's OSRM route
  /// polyline (depart leg: [MemberArrivalStatus.onTheWay]; return leg:
  /// [MemberArrivalStatus.headingHome]) - see [_fetchMemberRoute].
  Future<void> _attachRoutePolylines(String partyId, Meetup meetup) async {
    await Future.wait(
      meetup.members.map((member) async {
        final direction = switch (member.arrivalStatus) {
          MemberArrivalStatus.onTheWay => 'DEPART',
          MemberArrivalStatus.headingHome => 'RETURN',
          _ => null,
        };
        if (direction == null) return;
        member.routePolyline = await _fetchMemberRoute(partyId, member.userId, direction);
      }),
    );
  }

  /// Returns the road route for [userId]'s current [direction] leg within
  /// [partyId], from the cache if already fetched (see [_routeCache]) or by
  /// calling the backend otherwise. Returns null on a network failure, or if
  /// the member's latest trip turns out to be for a different direction than
  /// expected (e.g. a stale request racing a leg change).
  Future<List<LatLng>?> _fetchMemberRoute(String partyId, String userId, String direction) async {
    final cacheKey = '$partyId:$userId:$direction';
    final cached = _routeCache[cacheKey];
    if (cached != null) return cached;

    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/v1/parties/$partyId/members/$userId/trip',
      );
      final trip = TripDto.fromJson(response.data!);
      if (trip.direction != direction || trip.polyline.isEmpty) return null;

      final points = decodePolyline(trip.polyline);
      _routeCache[cacheKey] = points;
      return points;
    } catch (_) {
      return null;
    }
  }

  /// Attaches this device's chosen "go home" destination (tracked only in
  /// [_activeReturnTargets], since it isn't part of the party/member schema
  /// the server returns - see that field's doc comment) onto the current
  /// user's member model, so the live map can plot their target and a route
  /// to it while they're heading home.
  void _attachReturnDestination(String meetupId, Meetup meetup) {
    if (_currentUserId == null) return;
    final target = _activeReturnTargets[meetupId];
    if (target == null) return;
    if (meetup.currentUser.arrivalStatus != MemberArrivalStatus.headingHome) return;
    meetup.currentUser.destinationLabel = target.label;
    meetup.currentUser.destinationPosition = target.position;
  }

  /// Keeps [_activeDepartMeetupIds] in sync with the server's own view of
  /// this device's trip status. Without this, a depart that the *server*
  /// already knows about but that this in-memory flag never recorded (e.g.
  /// after an app restart, since the flag isn't persisted) would leave
  /// [_pushUpdate] silently skipping the GPS-post step forever - the arrival
  /// status shown would correctly say "on the way", but the member's marker
  /// would stay frozen at wherever it was last reported, since nothing would
  /// ever post a newer position for it again.
  void _reconcileActiveDepart(String meetupId, Meetup meetup) {
    if (_currentUserId == null) return;
    if (meetup.currentUser.arrivalStatus == MemberArrivalStatus.onTheWay) {
      _activeDepartMeetupIds.add(meetupId);
    } else {
      _activeDepartMeetupIds.remove(meetupId);
    }
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

CheckInStatus _checkInStatusFrom(String checkInStatus) {
  switch (checkInStatus) {
    case 'PENDING':
      return CheckInStatus.pending;
    case 'OK':
      return CheckInStatus.ok;
    case 'NOT_OK':
      return CheckInStatus.notOk;
    case 'NONE':
    default:
      return CheckInStatus.none;
  }
}

String _checkInStatusWireValue(CheckInStatus status) {
  switch (status) {
    case CheckInStatus.pending:
      return 'PENDING';
    case CheckInStatus.ok:
      return 'OK';
    case CheckInStatus.notOk:
      return 'NOT_OK';
    case CheckInStatus.none:
      return 'NONE';
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
