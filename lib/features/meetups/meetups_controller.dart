import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/auth_models.dart';
import '../../core/utils/mock_identity.dart';
import '../../core/widgets/map/lat_lng.dart';
import '../auth/auth_controller.dart';
import 'data/meetup_repository.dart';
import 'models/grouped_meetups.dart';
import 'models/meetup.dart';
import 'models/meetup_enums.dart';
import 'models/meetup_invite.dart';
import 'models/meetup_location.dart';
import 'models/meetup_member.dart';
import 'models/meetup_story.dart';

/// Owns meetup lists, the currently-open meetup, the create-meetup wizard
/// draft, and the live-simulation subscription. Same public-mutable-field +
/// `notifyListeners()` style as `AuthController`.
class MeetupsController extends ChangeNotifier {
  MeetupsController({
    required MeetupRepository repository,
    required AuthController authController,
  }) : _repository = repository,
       _authController = authController {
    _authController.addListener(_syncCurrentUserIdentity);
    _syncCurrentUserIdentity();
  }

  final MeetupRepository _repository;
  final AuthController _authController;

  bool loadingHome = false;
  List<Meetup> activeGroups = [];

  bool loadingGroups = false;
  GroupedMeetups groups = const GroupedMeetups();

  bool loadingInvites = false;
  List<MeetupInvite> invites = [];
  final Set<String> inviteActionInFlight = {};

  Meetup? selectedMeetup;
  StreamSubscription<Meetup>? _liveSubscription;

  /// Set when [markCurrentUserLeft], [confirmArrival], or [goHome] fails, so
  /// the calling screen can surface it - these calls used to fail silently,
  /// which read as positions/trips mysteriously never showing up.
  String? errorMessage;

  final Map<String, DateTime> _nudgeCooldownUntil = {};
  static const nudgeCooldown = Duration(seconds: 45);

  // --- Create Meetup wizard draft ---
  MeetupLocation? draftLocation;
  String draftTitle = '';
  DateTime? draftStartTime;
  final Set<String> draftInvitedFriendIds = {};

  void _syncCurrentUserIdentity() {
    final user = _authController.user;
    if (user == null) return;
    _repository.setCurrentUserIdentity(
      id: user.id,
      displayName: user.displayName,
      handle: mockHandleFor(user.displayName),
      initials: initialsFor(user.displayName),
    );
  }

  Future<void> loadHome() async {
    // Deliberately no `notifyListeners()` before the await: this is called
    // from `initState`, while the widget tree is still building - notifying
    // synchronously there throws ("markNeedsBuild called during build").
    // The `loadingHome = true` assignment is still visible on the very first
    // build since nothing has subscribed via `watch` yet at that point.
    loadingHome = true;
    activeGroups = await _repository.getActiveGroups();
    loadingHome = false;
    notifyListeners();
  }

  Future<void> loadGroups() async {
    loadingGroups = true;
    groups = await _repository.listGroups();
    loadingGroups = false;
    notifyListeners();
  }

  Future<void> loadInvites() async {
    loadingInvites = true;
    invites = await _repository.listInvites();
    loadingInvites = false;
    notifyListeners();
  }

  Future<void> acceptInvite(String meetupId) async {
    inviteActionInFlight.add(meetupId);
    notifyListeners();
    try {
      await _repository.acceptInvite(meetupId);
      invites = invites.where((i) => i.meetupId != meetupId).toList();
      await loadGroups();
    } finally {
      inviteActionInFlight.remove(meetupId);
      notifyListeners();
    }
  }

  Future<void> declineInvite(String meetupId) async {
    inviteActionInFlight.add(meetupId);
    notifyListeners();
    try {
      await _repository.declineInvite(meetupId);
      invites = invites.where((i) => i.meetupId != meetupId).toList();
    } finally {
      inviteActionInFlight.remove(meetupId);
      notifyListeners();
    }
  }

  Future<Meetup> loadMeetup(String id) async {
    selectedMeetup = await _repository.getMeetup(id);
    notifyListeners();
    return selectedMeetup!;
  }

  void resetDraft() {
    draftLocation = null;
    draftTitle = '';
    draftStartTime = null;
    draftInvitedFriendIds.clear();
  }

  void setDraftLocation(MeetupLocation location) {
    draftLocation = location;
    notifyListeners();
  }

  void setDraftDetails({required String title, required DateTime startTime}) {
    draftTitle = title;
    draftStartTime = startTime;
    notifyListeners();
  }

  void toggleDraftFriend(String friendId) {
    if (!draftInvitedFriendIds.remove(friendId)) {
      draftInvitedFriendIds.add(friendId);
    }
    notifyListeners();
  }

  Future<Meetup> submitDraft({
    required List<({String id, String displayName, String handle, String initials})>
    invitedFriends,
  }) async {
    final user = _authController.user;
    final members = [
      MeetupMember(
        userId: user?.id ?? 'me',
        displayName: user?.displayName ?? 'You',
        handle: mockHandleFor(user?.displayName ?? 'You'),
        initials: initialsFor(user?.displayName ?? 'You'),
        inviteStatus: MemberInviteStatus.accepted,
        isCurrentUser: true,
      ),
      for (final friend in invitedFriends)
        MeetupMember(
          userId: friend.id,
          displayName: friend.displayName,
          handle: friend.handle,
          initials: friend.initials,
          inviteStatus: MemberInviteStatus.pending,
        ),
    ];

    final meetup = await _repository.createMeetup(
      title: draftTitle,
      location: draftLocation!,
      startTime: draftStartTime!,
      members: members,
    );
    selectedMeetup = meetup;
    resetDraft();
    notifyListeners();
    return meetup;
  }

  void startWatchingLive(String meetupId) {
    _liveSubscription?.cancel();
    _liveSubscription = _repository.watchMeetup(meetupId).listen((meetup) {
      selectedMeetup = meetup;
      notifyListeners();
    });
  }

  void stopWatchingLive() {
    _liveSubscription?.cancel();
    _liveSubscription = null;
  }

  Future<bool> markCurrentUserLeft(String meetupId) async {
    errorMessage = null;
    try {
      await _repository.setCurrentUserArrivalStatus(
        meetupId,
        MemberArrivalStatus.onTheWay,
      );
      return true;
    } on DioException catch (e) {
      errorMessage = _tripErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmArrival(String meetupId) async {
    errorMessage = null;
    try {
      await _repository.setCurrentUserArrivalStatus(
        meetupId,
        MemberArrivalStatus.arrived,
      );
      return true;
    } on DioException catch (e) {
      errorMessage = _tripErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> goHome(
    String meetupId, {
    required String destinationLabel,
    required LatLng destinationPosition,
  }) async {
    errorMessage = null;
    try {
      await _repository.goHome(
        meetupId,
        destinationLabel: destinationLabel,
        destinationPosition: destinationPosition,
      );
      return true;
    } on DioException catch (e) {
      errorMessage = _tripErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Maps the backend's `{code, message}` trip-start error body to copy a
  /// user can act on - `NOT_PARTY_MEMBER` in particular covers the case
  /// where an invite is still pending, which otherwise surfaced as location
  /// sharing that silently never started.
  String _tripErrorMessage(
    DioException e, {
    String fallback = 'อัปเดตสถานะไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
  }) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] as String? : null;
    switch (code) {
      case 'NOT_PARTY_MEMBER':
        return 'คุณยังไม่ได้ตอบรับคำเชิญเข้าร่วมตี้นี้ จึงยังแชร์ตำแหน่งไม่ได้';
      case 'PARTY_NOT_FOUND':
        return 'ตี้นี้ไม่มีอยู่แล้ว';
      default:
        return fallback;
    }
  }

  bool isNudgeOnCooldown(String memberId) {
    final until = _nudgeCooldownUntil[memberId];
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> sendNudge(String meetupId, String memberId) async {
    _nudgeCooldownUntil[memberId] = DateTime.now().add(nudgeCooldown);
    notifyListeners();
    await _repository.sendNudge(meetupId, memberId);
  }

  Future<bool> postStory(String meetupId, File imageFile) async {
    errorMessage = null;
    try {
      await _repository.postStory(meetupId, imageFile);
      return true;
    } on DioException catch (e) {
      errorMessage = _tripErrorMessage(
        e,
        fallback: 'อัปโหลดสตอรี่ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
      );
      notifyListeners();
      return false;
    }
  }

  Future<List<MeetupStory>> fetchMemberStories(String meetupId, String userId) {
    return _repository.listMemberStories(meetupId, userId);
  }

  LatLng venuePosition(Meetup meetup) => meetup.location.position;

  Future<List<UserProfile>> searchUsers(String query) => _repository.searchUsers(query);

  @override
  void dispose() {
    _authController.removeListener(_syncCurrentUserIdentity);
    _liveSubscription?.cancel();
    super.dispose();
  }
}
