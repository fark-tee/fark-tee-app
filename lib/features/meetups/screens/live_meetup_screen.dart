import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/map/map_marker.dart';
import '../../../core/widgets/map/google_map_widget.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../meetups_controller.dart';
import '../models/meetup.dart';
import '../models/meetup_enums.dart';
import '../models/meetup_member.dart';

/// Full-screen live map + draggable bottom sheet showing every member's
/// simulated live position and the current user's own arrival state machine.
class LiveMeetupScreen extends StatefulWidget {
  const LiveMeetupScreen({super.key, required this.meetupId});

  final String meetupId;

  @override
  State<LiveMeetupScreen> createState() => _LiveMeetupScreenState();
}

class _LiveMeetupScreenState extends State<LiveMeetupScreen> {
  Timer? _cooldownRefreshTimer;

  @override
  void initState() {
    super.initState();
    context.read<MeetupsController>()
      ..loadMeetup(widget.meetupId)
      ..startWatchingLive(widget.meetupId);

    // The live stream (which would otherwise refresh nudge-cooldown UI as a
    // side effect) goes quiet once nobody is en route anymore, but a nudge
    // cooldown can still be ticking down after that point. Poll locally so
    // "ฝากที" buttons re-enable promptly even with a quiet stream.
    _cooldownRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownRefreshTimer?.cancel();
    context.read<MeetupsController>().stopWatchingLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meetup = context.watch<MeetupsController>().selectedMeetup;

    if (meetup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final onTheWayCount = meetup.otherMembers
        .where((m) => m.arrivalStatus == MemberArrivalStatus.onTheWay)
        .length;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMapWidget(
              center: meetup.location.position,
              markers: [
                MapMarker(
                  id: 'venue',
                  position: meetup.location.position,
                  type: MapMarkerType.venue,
                  label: meetup.location.name,
                ),
                for (final member in meetup.members)
                  MapMarker(
                    id: member.userId,
                    position: member.currentPosition(meetup.location.position),
                    type: MapMarkerType.member,
                    label: member.initials,
                    isCurrentUser: member.isCurrentUser,
                    caption: _captionFor(member),
                    profileImageUrl: member.profileImageUrl,
                  ),
              ],
            ),
          ),
          SafeArea(
            child: _TopBar(meetup: meetup, onTheWayCount: onTheWayCount),
          ),
          _MemberSheet(meetup: meetup),
        ],
      ),
    );
  }

  String? _captionFor(MeetupMember member) {
    if (member.isCurrentUser) return null;
    if (member.arrivalStatus == MemberArrivalStatus.onTheWay) {
      return '${member.displayName.split(' ').first}\n${member.etaMinutes} min';
    }
    return member.displayName.split(' ').first;
  }
}

/// Runs a [MeetupsController] trip action (start/arrive) and, if it fails,
/// surfaces `controller.errorMessage` via a snackbar - these calls used to be
/// fire-and-forget, so a rejected request (e.g. a still-pending invite) left
/// positions silently empty with no feedback to the user.
Future<void> _runTripAction(
  BuildContext context,
  Future<bool> Function(MeetupsController controller) action,
) async {
  final controller = context.read<MeetupsController>();
  final messenger = ScaffoldMessenger.of(context);

  final succeeded = await action(controller);
  if (!succeeded && controller.errorMessage != null) {
    messenger.showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
  }
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
                            'Live · ${meetup.arrivedCount} arrived · $onTheWayCount on the way',
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
  const _MemberSheet({required this.meetup});

  final Meetup meetup;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.85,
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
                title: 'Members',
                trailing: Text(
                  '${meetup.arrivedCount} of ${meetup.members.length} arrived',
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
              for (final member in meetup.otherMembers)
                _MemberRow(meetupId: meetup.id, member: member),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

class _CurrentUserStatusCard extends StatelessWidget {
  const _CurrentUserStatusCard({required this.meetup});

  final Meetup meetup;

  @override
  Widget build(BuildContext context) {
    final everyoneArrived = meetup.members.every(
      (m) => m.arrivalStatus == MemberArrivalStatus.arrived,
    );

    if (everyoneArrived) {
      return _StatusCard(
        headline: 'ทุกคนถึงครบแล้ว',
        imagePath: 'assets/images/mascots/all_arrived.png',
        action: _StatusActionPill(
          label: 'แยกย้ายกลับ',
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
          headline: 'คุณควรออกเดินทางภายได้แล้ว',
          imagePath: 'assets/images/mascots/prep.png',
          action: _StatusActionPill(
            label: 'ออกแล้วจ้า',
            onPressed: () => _runTripAction(
              context,
              (controller) => controller.markCurrentUserLeft(meetup.id),
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

/// Compact outlined pill for the status card's inline action - unlike
/// [PillButton] it sizes to its content instead of stretching full-width,
/// matching the mockups' small "ออกแล้วจ้า" / "แยกย้ายกลับ" buttons.
class _StatusActionPill extends StatelessWidget {
  const _StatusActionPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.check_box, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.accentDanger),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.meetupId, required this.member});

  final String meetupId;
  final MeetupMember member;

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
          AvatarCircle(
            initials: member.initials,
            imageUrl: member.profileImageUrl,
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
                    if (member.arrivalStatus ==
                        MemberArrivalStatus.onTheWay) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${member.etaMinutes} min',
                        style: AppTextStyles.captionMd,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (member.arrivalStatus != MemberArrivalStatus.arrived &&
              member.arrivalStatus != MemberArrivalStatus.returned) ...[
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 84,
              child: PillButton(
                label: isOnCooldown ? 'Nudged' : 'ฝากที',
                onPressed: isOnCooldown
                    ? null
                    : () => context.read<MeetupsController>().sendNudge(
                        meetupId,
                        member.userId,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
