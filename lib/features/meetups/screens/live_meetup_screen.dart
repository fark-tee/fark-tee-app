import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/map/lat_lng.dart';
import '../../../core/widgets/map/locate_me_button.dart';
import '../../../core/widgets/map/map_marker.dart';
import '../../../core/widgets/map/map_route.dart';
import '../../../core/widgets/map/google_map_widget.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../meetups_controller.dart';
import '../models/meetup.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_member.dart';
import 'story_viewer_screen.dart';

/// Full-screen live map + draggable bottom sheet showing every member's
/// simulated live position and the current user's own arrival state machine.
class LiveMeetupScreen extends StatefulWidget {
  const LiveMeetupScreen({super.key, required this.meetupId});

  final String meetupId;

  @override
  State<LiveMeetupScreen> createState() => _LiveMeetupScreenState();
}

const _sheetInitialSize = 0.35;
const _sheetMinSize = 0.15;
const _sheetMaxSize = 0.85;

/// Statuses where reviewing a member makes sense: they've reached the venue
/// and aren't still in transit home (see [MemberArrivalStatus.headingHome],
/// which gets the check-in prompt instead - see [_ReviewButton]).
const _reviewEligibleStatuses = {
  MemberArrivalStatus.arrived,
  MemberArrivalStatus.returned,
};

class _LiveMeetupScreenState extends State<LiveMeetupScreen> {
  Timer? _cooldownRefreshTimer;
  final _sheetController = DraggableScrollableController();
  final _mapController = MapCenterController();

  /// User IDs with at least one story, fetched once when the meetup first
  /// loads (not on every live poll tick - that would mean N extra requests
  /// every 2 seconds). Updated locally the moment the current user posts one,
  /// so their own ring appears instantly without waiting on a re-fetch.
  Set<String> _membersWithStories = {};

  @override
  void initState() {
    super.initState();
    final controller = context.read<MeetupsController>();
    controller.loadMeetup(widget.meetupId).then(_loadStoryPresence);
    controller.startWatchingLive(widget.meetupId);

    // The live stream (which would otherwise refresh nudge-cooldown UI as a
    // side effect) goes quiet once nobody is en route anymore, but a nudge
    // cooldown can still be ticking down after that point. Poll locally so
    // "ฝากที" buttons re-enable promptly even with a quiet stream.
    _cooldownRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadStoryPresence(Meetup meetup) async {
    final controller = context.read<MeetupsController>();
    final results = await Future.wait(
      meetup.members.map(
        (m) => controller
            .fetchMemberStories(meetup.id, m.userId)
            .then((stories) => (m.userId, stories.isNotEmpty)),
      ),
    );
    if (!mounted) return;
    setState(() {
      _membersWithStories = {
        for (final entry in results)
          if (entry.$2) entry.$1,
      };
    });
  }

  @override
  void dispose() {
    _cooldownRefreshTimer?.cancel();
    _sheetController.dispose();
    context.read<MeetupsController>().stopWatchingLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MeetupsController>();
    final meetup = controller.selectedMeetup;

    if (meetup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final onTheWayCount = meetup.otherMembers
        .where((m) => m.arrivalStatus == MemberArrivalStatus.onTheWay)
        .length;

    final returningMembers = meetup.members.where(
      (m) =>
          m.arrivalStatus == MemberArrivalStatus.headingHome &&
          m.destinationPosition != null,
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMapWidget(
              center: meetup.location.position,
              centerController: _mapController,
              markers: [
                MapMarker(
                  id: 'venue',
                  position: meetup.location.position,
                  type: MapMarkerType.venue,
                  label: meetup.location.name,
                ),
                for (final member in meetup.members)
                  if (member.currentPosition(meetup.location.position)
                      case final position?)
                    MapMarker(
                      id: member.userId,
                      position: position,
                      type: MapMarkerType.member,
                      label: member.initials,
                      isCurrentUser: member.isCurrentUser,
                      caption: _captionFor(member),
                      profileImageUrl: member.profileImageUrl,
                    ),
                for (final member in returningMembers)
                  MapMarker(
                    id: '${member.userId}-destination',
                    position: member.destinationPosition!,
                    type: MapMarkerType.destination,
                    label: member.destinationLabel ?? 'บ้าน',
                  ),
              ],
              routes: [
                for (final member in returningMembers)
                  MapRoute(
                    id: '${member.userId}-route-home',
                    points: [
                      // headingHome members always resolve to a real position
                      // (reported, interpolated, or the venue they just left).
                      member.currentPosition(meetup.location.position)!,
                      member.destinationPosition!,
                    ],
                  ),
              ],
            ),
          ),
          SafeArea(
            child: _TopBar(meetup: meetup, onTheWayCount: onTheWayCount),
          ),
          _MemberSheet(
            meetup: meetup,
            sheetController: _sheetController,
            membersWithStories: _membersWithStories,
          ),
          _LocateMeOverlay(
            sheetController: _sheetController,
            mapController: _mapController,
            myPosition: meetup.currentUser.currentPosition(meetup.location.position),
          ),
          _StoryCameraOverlay(
            sheetController: _sheetController,
            meetupId: meetup.id,
            onPosted: () => setState(() {
              _membersWithStories = {
                ..._membersWithStories,
                meetup.currentUser.userId,
              };
            }),
          ),
          if (controller.updatingArrivalStatus) const _TravelCalculatingOverlay(),
        ],
      ),
    );
  }

  String? _captionFor(MeetupMember member) {
    if (member.isCurrentUser) return null;
    return member.displayName.split(' ').first;
  }
}

/// "Arriving in N min" copy for a member currently en route, from the
/// OSRM-computed [MeetupMember.estimatedArrivalAt]. Null once they've
/// arrived/returned or haven't started a trip yet.
String? _etaLabelFor(MeetupMember member) {
  if (member.arrivalStatus != MemberArrivalStatus.onTheWay &&
      member.arrivalStatus != MemberArrivalStatus.headingHome) {
    return null;
  }
  final arrivalAt = member.estimatedArrivalAt;
  if (arrivalAt == null) return null;

  final minutes = arrivalAt.difference(DateTime.now()).inMinutes;
  if (minutes <= 0) return 'มาถึงอีกไม่นาน';
  return 'ถึงในอีก $minutes นาที';
}

/// Runs a [MeetupsController] trip action (start/arrive) and, if it fails,
/// surfaces `controller.errorMessage` via a snackbar - these calls used to be
/// fire-and-forget, so a rejected request (e.g. a still-pending invite) left
/// positions silently empty with no feedback to the user.
Future<bool> _runTripAction(
  BuildContext context,
  Future<bool> Function(MeetupsController controller) action,
) async {
  final controller = context.read<MeetupsController>();
  final messenger = ScaffoldMessenger.of(context);

  final succeeded = await action(controller);
  if (!succeeded && controller.errorMessage != null) {
    messenger.showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
  }
  return succeeded;
}

/// Opens the camera, then uploads whatever was captured as a new story photo
/// for [meetupId]. Calls [onPosted] on success so the caller can flip on the
/// current user's story ring immediately, without waiting on a re-fetch.
Future<void> _captureAndPostStory(
  BuildContext context,
  String meetupId, {
  VoidCallback? onPosted,
}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return;

  final succeeded = await _runTripAction(
    context,
    (controller) => controller.postStory(meetupId, File(picked.path)),
  );
  if (succeeded) onPosted?.call();
}

/// Fetches [member]'s stories for [meetupId] and, if any exist, opens the
/// full-screen viewer; otherwise surfaces a snackbar instead of a silent
/// no-op tap.
Future<void> _openMemberStories(
  BuildContext context,
  String meetupId,
  MeetupMember member,
) async {
  final controller = context.read<MeetupsController>();
  final stories = await controller.fetchMemberStories(meetupId, member.userId);
  if (!context.mounted) return;

  if (stories.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${member.displayName.split(' ').first} ยังไม่มีสตอรี่'),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => StoryViewerScreen(member: member, stories: stories),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.meetup, required this.onTheWayCount});

  final Meetup meetup;
  final int onTheWayCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgBase.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_left,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meetup.location.name, style: AppTextStyles.titleMd),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text(
                          '●',
                          style: TextStyle(
                            color: AppColors.accentDanger,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'ถึงแล้ว ${meetup.arrivedCount} คน · กำลังเดินทาง $onTheWayCount คน',
                            style: AppTextStyles.captionMd,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatTime12h(meetup.startTime),
                style: AppTextStyles.bodyMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSheet extends StatelessWidget {
  const _MemberSheet({
    required this.meetup,
    required this.sheetController,
    required this.membersWithStories,
  });

  final Meetup meetup;
  final DraggableScrollableController sheetController;
  final Set<String> membersWithStories;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: _sheetInitialSize,
      minChildSize: _sheetMinSize,
      maxChildSize: _sheetMaxSize,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderMuted,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CurrentUserStatusCard(meetup: meetup),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: 'สมาชิก',
                titleStyle: AppTextStyles.captionMd,
                trailing: Text(
                  'ถึงแล้ว ${meetup.arrivedCount} จาก ${meetup.members.length} คน',
                  style: AppTextStyles.captionMd,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: meetup.members.isEmpty
                      ? 0
                      : meetup.arrivedCount / meetup.members.length,
                  minHeight: 4,
                  backgroundColor: AppColors.bgSurface,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.accentDanger,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final member in meetup.members)
                _MemberRow(
                  meetupId: meetup.id,
                  member: member,
                  hasStory: membersWithStories.contains(member.userId),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

/// "Find me" FAB matching Google Maps' own current-location button, stacked
/// directly above [_StoryCameraOverlay] and tracking [sheetController] the
/// same way (see that class's doc comment for why it can't live inside the
/// sheet's own builder).
class _LocateMeOverlay extends StatefulWidget {
  const _LocateMeOverlay({
    required this.sheetController,
    required this.mapController,
    required this.myPosition,
  });

  final DraggableScrollableController sheetController;
  final MapCenterController mapController;

  /// The current user's own marker position on the map (see
  /// `MeetupMember.currentPosition`), i.e. the exact spot their pin is
  /// already drawn at. Preferred over a fresh GPS fix so this button always
  /// centers on the pin the user is actually looking at, rather than a
  /// slightly different reading from a brand-new location request.
  final LatLng? myPosition;

  @override
  State<_LocateMeOverlay> createState() => _LocateMeOverlayState();
}

class _LocateMeOverlayState extends State<_LocateMeOverlay> {
  bool _locating = false;

  Future<void> _goToMyLocation() async {
    final knownPosition = widget.myPosition;
    if (knownPosition != null) {
      await widget.mapController.moveTo(knownPosition);
      return;
    }

    // No pin yet (e.g. the very first GPS fix hasn't landed) - fall back to
    // requesting one directly so the button still works.
    setState(() => _locating = true);
    try {
      final position = await context.read<LocationService>().getCurrentPosition();
      if (!mounted) return;
      await widget.mapController.moveTo(position);
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.sheetController,
      builder: (context, _) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final extent = widget.sheetController.isAttached
            ? widget.sheetController.size
            : _sheetInitialSize;
        final sheetTop = screenHeight * (1 - extent);
        return Positioned(
          top: sheetTop - 77,
          right: AppSpacing.lg,
          child: LocateMeButton(loading: _locating, onPressed: _goToMyLocation),
        );
      },
    );
  }
}

/// Floating shutter button pinned to the top-right of [_MemberSheet]'s
/// current top edge. Lives in [LiveMeetupScreen]'s own top-level `Stack`
/// (a sibling of the sheet, not nested inside it) and tracks [sheetController]
/// to follow the sheet as it's dragged.
///
/// It can't live inside the sheet's own builder: `DraggableScrollableSheet`'s
/// render box is only as tall as its current drag extent, and Flutter's
/// default hit-testing rejects any tap outside a box's own size before it
/// even looks at children - so a button positioned above that box's top edge
/// (even with `Clip.none`, which only affects painting) would render there
/// but never receive taps; they'd fall through to whatever is behind it.
class _StoryCameraOverlay extends StatelessWidget {
  const _StoryCameraOverlay({
    required this.sheetController,
    required this.meetupId,
    required this.onPosted,
  });

  final DraggableScrollableController sheetController;
  final String meetupId;
  final VoidCallback onPosted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sheetController,
      builder: (context, _) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final extent = sheetController.isAttached
            ? sheetController.size
            : _sheetInitialSize;
        final sheetTop = screenHeight * (1 - extent);
        return Positioned(
          top: sheetTop - 25,
          right: AppSpacing.lg,
          child: Material(
            color: AppColors.textPrimary,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              onTap: () => _captureAndPostStory(context, meetupId, onPosted: onPosted),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Icon(Icons.camera_alt, color: AppColors.bgBase, size: 22),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen scrim shown while [MeetupsController.markCurrentUserLeft] is
/// awaiting the backend's OSRM route calculation for the just-started trip.
class _TravelCalculatingOverlay extends StatelessWidget {
  const _TravelCalculatingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.bgBase.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.accentDanger),
              const SizedBox(height: AppSpacing.md),
              Text(
                'รอสักครู่กำลังคำนวณการเดินทาง',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentUserStatusCard extends StatelessWidget {
  const _CurrentUserStatusCard({required this.meetup});

  final Meetup meetup;

  @override
  Widget build(BuildContext context) {
    final everyoneArrived = meetup.members.every(
      (m) => m.arrivalStatus == MemberArrivalStatus.arrived || m.arrivalStatus == MemberArrivalStatus.returned || m.arrivalStatus == MemberArrivalStatus.headingHome,
    );

    if (everyoneArrived && meetup.currentUser.arrivalStatus == MemberArrivalStatus.arrived) {
      return _StatusCard(
        headline: 'ทุกคนถึงครบแล้ว',
        imagePath: 'assets/images/mascots/all_arrived.png',
        action: _StatusActionPill(
          label: 'แยกย้ายกลับ',
          icon: Icons.home,
          onPressed: () => context.push('/meetup/${meetup.id}/going-home'),
        ),
      );
    }

    final currentUser = meetup.currentUser;

    switch (currentUser.arrivalStatus) {
      case MemberArrivalStatus.arrived:
        return const _StatusCard(
          headline: 'ฝากทีไปตามเพื่อนดีกว่า',
          imagePath: 'assets/images/mascots/waiting.png',
        );
      case MemberArrivalStatus.onTheWay:
        final aFriendArrived = meetup.otherMembers.any(
          (m) => m.arrivalStatus == MemberArrivalStatus.arrived,
        );
        return _StatusCard(
          headline: aFriendArrived
              ? 'สายแล้ว!!\nเพื่อนกำลังรอคุณอยู่'
              : 'กำลังเดินทางไปจุดนัด',
          imagePath: aFriendArrived
              ? 'assets/images/mascots/late.png'
              : 'assets/images/mascots/walking.png',
        );
      case MemberArrivalStatus.notLeftYet:
        return _StatusCard(
          headline: 'ออกสักทีเถอะ!',
          imagePath: 'assets/images/mascots/prep.png',
          action: _StatusActionPill(
            label: 'ออกแล้วจ้า',
            icon: Icons.directions_car,
            onPressed: () => _runTripAction(
              context,
              (controller) =>
                  controller.markCurrentUserLeft(meetup.id, meetup.location),
            ),
          ),
        );
      case MemberArrivalStatus.headingHome:
        return const _StatusCard(
          headline: 'กำลังเดินทางกลับบ้าน',
          imagePath: 'assets/images/mascots/walking.png',
        );
      case MemberArrivalStatus.returned:
        return const _StatusCard(
          headline: 'กลับถึงบ้านแล้ว',
          imagePath: 'assets/images/mascots/all_arrived.png',
        );
    }
  }
}

/// Dark status card matching the "your status now" mockups: a caption,
/// a bold headline, an optional compact action pill, and a mascot
/// illustration anchored to the trailing edge.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.headline,
    required this.imagePath,
    this.action,
  });

  final String headline;
  final String imagePath;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สถานะของคุณตอนนี้', style: AppTextStyles.captionMd),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  headline,
                  style: AppTextStyles.displayLg.copyWith(fontSize: 20),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Image.asset(imagePath, width: 72, height: 72, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

/// Light filled pill with a red outline for the status card's inline action,
/// matching the mockups' "ออกแล้วจ้า" / "แยกย้ายกลับ" buttons - a light
/// surface (not the card's dark background) with a colored border, dark
/// text/icon, stretched full-width like [PillButton].
class _StatusActionPill extends StatelessWidget {
  const _StatusActionPill({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textBody,
          foregroundColor: AppColors.bgBase,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.meetupId,
    required this.member,
    required this.hasStory,
  });

  final String meetupId;
  final MeetupMember member;
  final bool hasStory;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (member.arrivalStatus) {
      MemberArrivalStatus.notLeftYet => ('กำลังเตรียมตัว', BadgeColors.neutral),
      MemberArrivalStatus.onTheWay => ('กำลังเดินทาง', BadgeColors.info),
      MemberArrivalStatus.arrived => ('ไปถึงแล้ว', BadgeColors.positive),
      MemberArrivalStatus.headingHome => ('กำลังกลับบ้าน', BadgeColors.neutral),
      MemberArrivalStatus.returned => ('กลับถึงแล้ว', BadgeColors.neutral),
    };

    final isOnCooldown = context.watch<MeetupsController>().isNudgeOnCooldown(
      member.userId,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openMemberStories(context, meetupId, member),
            child: AvatarCircle(
              initials: member.initials,
              imageUrl: member.profileImageUrl,
              hasStory: hasStory,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: AppTextStyles.bodyMd),
                const SizedBox(height: 2),
                Row(
                  children: [
                    StatusBadge(label: label, color: color),
                    if (_etaLabelFor(member) != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _etaLabelFor(member)!,
                        style: AppTextStyles.captionMd,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!member.isCurrentUser &&
              member.arrivalStatus == MemberArrivalStatus.headingHome) ...[
            const SizedBox(width: AppSpacing.sm),
            _CheckInButton(
              status: member.checkInStatus,
              onPressed: member.checkInStatus == CheckInStatus.pending
                  ? null
                  : () => context.read<MeetupsController>().requestCheckIn(
                      meetupId,
                      member.userId,
                    ),
            ),
          ] else if (!member.isCurrentUser &&
              _reviewEligibleStatuses.contains(member.arrivalStatus)) ...[
            const SizedBox(width: AppSpacing.sm),
            _ReviewButton(
              onPressed: () => context.push('/meetup/$meetupId/review'),
            ),
          ] else if (!member.isCurrentUser) ...[
            const SizedBox(width: AppSpacing.sm),
            _NudgeButton(
              isOnCooldown: isOnCooldown,
              onPressed: isOnCooldown
                  ? null
                  : () => context.read<MeetupsController>().sendNudge(
                      meetupId,
                      member.userId,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dark filled pill with the nudge mascot icon, matching the "ฝากที" mockup -
/// unlike [PillButton] (a generic full-width CTA), this is a fixed-size chip
/// with a custom illustration leading the label, so it's built standalone
/// rather than extending the shared primitive for a one-off look.
class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.isOnCooldown, required this.onPressed});

  final bool isOnCooldown;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bgSurface,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.bgSurface.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.textMuted,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: isOnCooldown ? 0.5 : 1,
              child: Image.asset(
                'assets/images/mascots/nudge.png',
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(width: 6),
            Text(isOnCooldown ? 'โดนละ' : 'ฝากที'),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of [_NudgeButton]/[_ReviewButton] while a member is
/// [MemberArrivalStatus.headingHome] - asks them to confirm they're okay.
/// Tinted by [status] so the asker can see the last answer at a glance;
/// tapping always sends a fresh request (server resets it to pending).
class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.status, required this.onPressed});

  final CheckInStatus status;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CheckInStatus.pending => ('รอคำตอบ...', AppColors.textMuted),
      CheckInStatus.ok => ('โอเคแล้ว', BadgeColors.positive),
      CheckInStatus.notOk => ('ไม่โอเค!', BadgeColors.negative),
      CheckInStatus.none => ('โอเคนะคะ?', AppColors.textPrimary),
    };

    return SizedBox(
      width: 100,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bgSurface,
          foregroundColor: color,
          disabledBackgroundColor: AppColors.bgSurface.withValues(alpha: 0.5),
          disabledForegroundColor: color,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Shown in place of [_NudgeButton] once a member has reached
/// [_reviewEligibleStatuses] - opens the review screen to rate them.
class _ReviewButton extends StatelessWidget {
  const _ReviewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bgSurface,
          foregroundColor: AppColors.textPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 18),
            SizedBox(width: 6),
            Text('ให้คะแนน'),
          ],
        ),
      ),
    );
  }
}
