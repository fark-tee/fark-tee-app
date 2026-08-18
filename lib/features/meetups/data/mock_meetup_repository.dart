import 'dart:async';
import 'dart:io';

import '../../../core/auth/auth_models.dart';
import '../../../core/widgets/map/lat_lng.dart';
import '../models/grouped_meetups.dart';
import '../models/meetup.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_invite.dart';
import '../models/meetup_location.dart';
import '../models/meetup_member.dart';
import '../models/meetup_story.dart';
import 'meetup_repository.dart';

/// In-memory mock data. No backend yet - see [MeetupRepository]'s doc
/// comment for how this slots in once one exists.
class MockMeetupRepository implements MeetupRepository {
  MockMeetupRepository() {
    _seed();
  }

  final List<Meetup> _meetups = [];
  final List<MeetupInvite> _invites = [
    MeetupInvite(
      meetupId: 'meetup-invite-1',
      title: 'Beach Bonfire',
      destinationName: 'Rockaway Beach',
      startTime: DateTime.now().add(const Duration(days: 2, hours: 5)),
      invitedByName: 'Jamie Fox',
    ),
  ];
  final Map<String, StreamController<Meetup>> _liveControllers = {};
  final Map<String, Timer> _liveTimers = {};
  final Map<String, int> _tickCounts = {};
  int _idCounter = 100;

  /// Keyed by `"$meetupId:$userId"`.
  final Map<String, List<MeetupStory>> _storiesByMemberKey = {};

  static const _networkDelay = Duration(milliseconds: 350);

  void _seed() {
    final now = DateTime.now();

    final currentUser = MeetupMember(
      userId: 'me',
      displayName: 'You',
      handle: '@you',
      initials: 'ME',
      inviteStatus: MemberInviteStatus.accepted,
      isCurrentUser: true,
    );

    // Live now: starts soon enough that location sharing is already open,
    // so opening it demonstrates the Live Meetup screen immediately.
    final nobuVenue = const MeetupLocation(
      name: 'Nobu Downtown',
      address: '195 Broadway, New York, NY',
      position: LatLng(40.7128, -74.0060),
    );
    _meetups.add(
      Meetup(
        id: _nextId(),
        title: 'Dinner @ Nobu Downtown',
        location: nobuVenue,
        startTime: now.add(const Duration(minutes: 20)),
        status: MeetupStatus.live,
        members: [
          currentUser,
          MeetupMember(
            userId: 'alex-chen',
            displayName: 'Alex Chen',
            handle: '@alexc',
            initials: 'AC',
            inviteStatus: MemberInviteStatus.accepted,
            arrivalStatus: MemberArrivalStatus.arrived,
          ),
          _onTheWay(
            userId: 'maya-patel',
            displayName: 'Maya Patel',
            handle: '@mayap',
            initials: 'MP',
            venue: nobuVenue.position,
            etaMinutes: 8,
            latOffset: 0.006,
            lngOffset: -0.004,
          ),
          _onTheWay(
            userId: 'jordan-lee',
            displayName: 'Jordan Lee',
            handle: '@jlee',
            initials: 'JL',
            venue: nobuVenue.position,
            etaMinutes: 5,
            latOffset: -0.004,
            lngOffset: 0.005,
          ),
          MeetupMember(
            userId: 'sam-rivera',
            displayName: 'Sam Rivera',
            handle: '@samr',
            initials: 'SR',
            inviteStatus: MemberInviteStatus.pending,
          ),
        ],
      ),
    );

    // Upcoming, well outside the 1h window - demonstrates the Location
    // Sharing Rule / countdown screen.
    _meetups.add(
      Meetup(
        id: _nextId(),
        title: 'Rooftop · Soho House',
        location: const MeetupLocation(
          name: 'Soho House',
          address: '29-35 Ninth Ave, New York, NY',
          position: LatLng(40.7431, -74.0060),
        ),
        startTime: DateTime(now.year, now.month, now.day + 3, 21),
        status: MeetupStatus.upcoming,
        members: [
          MeetupMember(
            userId: 'me',
            displayName: 'You',
            handle: '@you',
            initials: 'ME',
            inviteStatus: MemberInviteStatus.accepted,
            isCurrentUser: true,
          ),
          MeetupMember(
            userId: 'chris-wong',
            displayName: 'Chris Wong',
            handle: '@chriswong',
            initials: 'CW',
            inviteStatus: MemberInviteStatus.accepted,
          ),
          MeetupMember(
            userId: 'priya-sharma',
            displayName: 'Priya Sharma',
            handle: '@priya_s',
            initials: 'PS',
            inviteStatus: MemberInviteStatus.pending,
          ),
        ],
      ),
    );

    for (final past in [
      ('Nobu Dinner', 20, 5),
      ('Rooftop at Soho House', 34, 7),
      ('Picnic in Central Park', 48, 4),
      ('Gallery Opening — 47 Canal', 66, 6),
    ]) {
      final (title, daysAgo, count) = past;
      _meetups.add(_pastMeetup(title, daysAgo, count));
    }
  }

  Meetup _pastMeetup(String title, int daysAgo, int memberCount) {
    final startTime = DateTime.now().subtract(Duration(days: daysAgo));
    final members = [
      MeetupMember(
        userId: 'me',
        displayName: 'You',
        handle: '@you',
        initials: 'ME',
        inviteStatus: MemberInviteStatus.accepted,
        arrivalStatus: MemberArrivalStatus.headingHome,
        isCurrentUser: true,
      ),
      for (var i = 1; i < memberCount; i++)
        MeetupMember(
          userId: 'past-$title-$i',
          displayName: 'Friend $i',
          handle: '@friend$i',
          initials: 'F$i',
          inviteStatus: MemberInviteStatus.accepted,
          arrivalStatus: MemberArrivalStatus.headingHome,
        ),
    ];
    return Meetup(
      id: _nextId(),
      title: title,
      location: const MeetupLocation(
        name: 'Past venue',
        address: 'New York, NY',
        position: LatLng(40.73, -73.99),
      ),
      startTime: startTime,
      status: MeetupStatus.completed,
      members: members,
    );
  }

  MeetupMember _onTheWay({
    required String userId,
    required String displayName,
    required String handle,
    required String initials,
    required LatLng venue,
    required int etaMinutes,
    required double latOffset,
    required double lngOffset,
  }) {
    final remaining = (etaMinutes * 80).toDouble();
    return MeetupMember(
      userId: userId,
      displayName: displayName,
      handle: handle,
      initials: initials,
      inviteStatus: MemberInviteStatus.accepted,
      arrivalStatus: MemberArrivalStatus.onTheWay,
      startPosition: LatLng(venue.latitude + latOffset, venue.longitude + lngOffset),
      initialDistanceMeters: remaining,
      remainingDistanceMeters: remaining,
    );
  }

  String _nextId() => 'meetup-${_idCounter++}';

  @override
  void setCurrentUserIdentity({
    required String id,
    required String displayName,
    required String handle,
    required String initials,
  }) {
    for (final meetup in _meetups) {
      final index = meetup.members.indexWhere((m) => m.isCurrentUser);
      if (index == -1) continue;
      final existing = meetup.members[index];
      meetup.members[index] = MeetupMember(
        userId: id,
        displayName: displayName,
        handle: handle,
        initials: initials,
        inviteStatus: existing.inviteStatus,
        arrivalStatus: existing.arrivalStatus,
        isCurrentUser: true,
        startPosition: existing.startPosition,
        initialDistanceMeters: existing.initialDistanceMeters,
        remainingDistanceMeters: existing.remainingDistanceMeters,
      );
    }
  }

  @override
  Future<List<Meetup>> getActiveGroups() async {
    await Future.delayed(_networkDelay);
    final now = DateTime.now();
    return _meetups
        .where(
          (m) =>
              m.status != MeetupStatus.completed &&
              m.status != MeetupStatus.cancelled &&
              m.startTime.difference(now) < const Duration(hours: 20) &&
              !m.isPast,
        )
        .toList();
  }

  @override
  Future<GroupedMeetups> listGroups() async {
    await Future.delayed(_networkDelay);
    final now = DateTime.now();
    final tonight = <Meetup>[];
    final upcoming = <Meetup>[];
    final past = <Meetup>[];

    for (final meetup in _meetups) {
      if (meetup.isPast) {
        past.add(meetup);
        continue;
      }
      final isToday = meetup.startTime.year == now.year &&
          meetup.startTime.month == now.month &&
          meetup.startTime.day == now.day;
      if (isToday) {
        tonight.add(meetup);
      } else {
        upcoming.add(meetup);
      }
    }
    past.sort((a, b) => b.startTime.compareTo(a.startTime));
    return GroupedMeetups(tonight: tonight, upcoming: upcoming, past: past);
  }

  @override
  Future<Meetup> getMeetup(String id) async {
    await Future.delayed(_networkDelay);
    return _meetups.firstWhere((m) => m.id == id);
  }

  @override
  Future<Meetup> createMeetup({
    required String title,
    required MeetupLocation location,
    required DateTime startTime,
    required List<MeetupMember> members,
  }) async {
    await Future.delayed(_networkDelay);
    final meetup = Meetup(
      id: _nextId(),
      title: title,
      location: location,
      startTime: startTime,
      status: MeetupStatus.upcoming,
      members: members,
    );
    _meetups.insert(0, meetup);
    return meetup;
  }

  @override
  Future<void> setCurrentUserArrivalStatus(
    String meetupId,
    MemberArrivalStatus status,
  ) async {
    await Future.delayed(_networkDelay);
    final meetup = await getMeetup(meetupId);
    meetup.currentUser.arrivalStatus = status;
    _liveControllers[meetupId]?.add(meetup);
  }

  @override
  Future<void> goHome(
    String meetupId, {
    required String destinationLabel,
    required LatLng destinationPosition,
  }) async {
    await Future.delayed(_networkDelay);
    final meetup = await getMeetup(meetupId);
    meetup.currentUser.arrivalStatus = MemberArrivalStatus.headingHome;
    _liveControllers[meetupId]?.add(meetup);
  }

  @override
  Future<void> sendNudge(String meetupId, String memberId) async {
    await Future.delayed(_networkDelay);
    // Purely cosmetic - intentionally a no-op against real member state.
  }

  @override
  Stream<Meetup> watchMeetup(String meetupId) {
    final existing = _liveControllers[meetupId];
    if (existing != null) return existing.stream;

    late final StreamController<Meetup> controller;
    controller = StreamController<Meetup>.broadcast(
      onListen: () {
        _liveTimers[meetupId] ??= Timer.periodic(
          const Duration(seconds: 3),
          (_) => _tick(meetupId, controller),
        );
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
    await Future.delayed(_networkDelay);
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final seededNames = <String>{
      for (final meetup in _meetups)
        for (final member in meetup.members) member.displayName,
    };

    return seededNames
        .where((name) => name.toLowerCase().contains(normalized))
        .map(
          (name) => UserProfile(
            id: 'mock-${name.toLowerCase().replaceAll(' ', '-')}',
            displayName: name,
            username: name.toLowerCase().replaceAll(' ', '_'),
            profileImageUrl: '',
            googleUserId: 'mock-google-id',
            rating: 5,
            ratingCount: 0,
            onTimeCount: 0,
            lateCount: 0,
          ),
        )
        .toList();
  }

  @override
  Future<List<MeetupInvite>> listInvites() async {
    await Future.delayed(_networkDelay);
    return List.unmodifiable(_invites);
  }

  @override
  Future<void> acceptInvite(String meetupId) async {
    await Future.delayed(_networkDelay);
    _invites.removeWhere((i) => i.meetupId == meetupId);
  }

  @override
  Future<void> declineInvite(String meetupId) async {
    await Future.delayed(_networkDelay);
    _invites.removeWhere((i) => i.meetupId == meetupId);
  }

  @override
  Future<void> postStory(String meetupId, File imageFile) async {
    await Future.delayed(_networkDelay);
    final meetup = await getMeetup(meetupId);
    final key = '$meetupId:${meetup.currentUser.userId}';
    _storiesByMemberKey.putIfAbsent(key, () => []).insert(
      0,
      MeetupStory(
        id: 'story-${_idCounter++}',
        userId: meetup.currentUser.userId,
        imageUrl: imageFile.path,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<MeetupStory>> listMemberStories(
    String meetupId,
    String userId,
  ) async {
    await Future.delayed(_networkDelay);
    return List.unmodifiable(_storiesByMemberKey['$meetupId:$userId'] ?? []);
  }

  void _tick(String meetupId, StreamController<Meetup> controller) {
    final meetup = _meetups.firstWhere((m) => m.id == meetupId);
    final tickCount = (_tickCounts[meetupId] ?? 0) + 1;
    _tickCounts[meetupId] = tickCount;
    var changed = false;

    // Members who haven't left yet don't have a real device deciding when
    // they depart in this mock world - without this, a member seeded as
    // `notLeftYet` (e.g. Sam Rivera) would sit there forever and "everyone
    // has arrived" could never be reached. Simulate them heading out a few
    // ticks in, same as a real person eventually leaving home.
    if (tickCount == 2) {
      for (final member in meetup.otherMembers) {
        if (member.arrivalStatus != MemberArrivalStatus.notLeftYet) continue;
        member.arrivalStatus = MemberArrivalStatus.onTheWay;
        member.startPosition = LatLng(
          meetup.location.position.latitude - 0.005,
          meetup.location.position.longitude + 0.006,
        );
        member.initialDistanceMeters = 560;
        member.remainingDistanceMeters = 560;
        changed = true;
      }
    }

    for (final member in meetup.otherMembers) {
      if (member.arrivalStatus != MemberArrivalStatus.onTheWay) continue;
      final remaining = member.remainingDistanceMeters ?? 0;
      final next = remaining - 60;
      changed = true;
      if (next <= 100) {
        member.remainingDistanceMeters = 0;
        member.arrivalStatus = MemberArrivalStatus.arrived;
      } else {
        member.remainingDistanceMeters = next;
      }
    }
    if (changed) controller.add(meetup);
  }
}
