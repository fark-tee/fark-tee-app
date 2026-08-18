import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_card.dart';
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

/// Meetup Detail screen. Always shows a header + info block + map; below
/// that, exactly one of three variants depending on the meetup's timing and
/// status - see the private `_show*` helpers for the exact rule (reconciles
/// an ambiguity between spec sections 7 and 9: the "before open" countdown
/// panel wins whenever sharing isn't open yet *and* the meetup hasn't
/// finished, otherwise a live members list with a "View Live Location" CTA
/// shows while sharing is open and the meetup isn't over, otherwise a plain
/// invite-status members list for past/cancelled meetups).
class MeetupDetailScreen extends StatefulWidget {
  const MeetupDetailScreen({super.key, required this.meetupId});

  final String meetupId;

  @override
  State<MeetupDetailScreen> createState() => _MeetupDetailScreenState();
}

class _MeetupDetailScreenState extends State<MeetupDetailScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    context.read<MeetupsController>().loadMeetup(widget.meetupId);
    // Ticks the "Location sharing starts in X" countdown. Harmless no-op
    // rebuild when the countdown panel isn't showing.
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool _showLocationSharingRule(Meetup meetup) {
    final relevantStatus =
        meetup.status == MeetupStatus.upcoming || meetup.status == MeetupStatus.live;
    return !meetup.isLocationSharingOpen && relevantStatus;
  }

  bool _showLiveMembers(Meetup meetup) {
    final isOver =
        meetup.status == MeetupStatus.completed || meetup.status == MeetupStatus.cancelled;
    return meetup.isLocationSharingOpen && !isOver;
  }

  @override
  Widget build(BuildContext context) {
    final meetup = context.watch<MeetupsController>().selectedMeetup;

    if (meetup == null || meetup.id != widget.meetupId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(meetup.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing is not available yet')),
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _InfoBlock(meetup: meetup),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: 200,
                child: GoogleMapWidget(
                  center: meetup.location.position,
                  markers: [
                    MapMarker(
                      id: 'venue',
                      position: meetup.location.position,
                      type: MapMarkerType.venue,
                      label: meetup.location.name,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (_showLocationSharingRule(meetup))
              _LocationSharingRulePanel(meetup: meetup)
            else if (_showLiveMembers(meetup))
              _LiveMembersSection(meetup: meetup)
            else
              _MembersSection(
                members: meetup.otherMembers,
                badgeFor: _inviteStatusBadge,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.meetup});

  final Meetup meetup;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Location', value: meetup.location.name),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  label: 'Date',
                  value: formatLongDate(meetup.startTime),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _InfoRow(
                  label: 'Time',
                  value: formatTime24h(meetup.startTime),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.captionMd),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.titleMd),
      ],
    );
  }
}

/// Variant 1: sharing hasn't opened yet - a centered message plus a live
/// countdown to `meetup.locationSharingOpensAt`, ticked by the parent's
/// `Timer.periodic`.
class _LocationSharingRulePanel extends StatelessWidget {
  const _LocationSharingRulePanel({required this.meetup});

  final Meetup meetup;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_clock_outlined, color: AppColors.textMuted, size: 28),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Member locations will be shown 1 hour before the meetup starts',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Location sharing starts in ${_countdownLabel(meetup.locationSharingOpensAt)}',
            textAlign: TextAlign.center,
            style: AppTextStyles.captionMd,
          ),
        ],
      ),
    );
  }

  static String _countdownLabel(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative || diff.inMinutes < 1) return 'less than a minute';

    final days = diff.inDays;
    if (days >= 1) return '$days day${days == 1 ? '' : 's'}';

    final hours = diff.inHours;
    if (hours >= 1) {
      final minutes = diff.inMinutes % 60;
      if (minutes == 0) return '$hours hour${hours == 1 ? '' : 's'}';
      return '$hours hour${hours == 1 ? '' : 's'} $minutes minute${minutes == 1 ? '' : 's'}';
    }

    final minutes = diff.inMinutes;
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }
}

/// Variant 2: sharing is open and the meetup isn't over yet - a live CTA
/// card plus the members list keyed off arrival status.
class _LiveMembersSection extends StatelessWidget {
  const _LiveMembersSection({required this.meetup});

  final Meetup meetup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Live · ${meetup.arrivedCount} arrived',
                style: AppTextStyles.titleMd.copyWith(color: BadgeColors.positive),
              ),
              const SizedBox(height: AppSpacing.md),
              PillButton(
                label: 'View Live Location',
                onPressed: () => context.push('/meetup/${meetup.id}/live'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _MembersSection(members: meetup.otherMembers, badgeFor: _arrivalStatusBadge),
      ],
    );
  }
}

/// Shared "Members" list used by variants 2 and 3; only the status-badge
/// mapping differs between them.
class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.members, required this.badgeFor});

  final List<MeetupMember> members;
  final ({String label, Color color}) Function(MeetupMember member) badgeFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Members'),
        const SizedBox(height: AppSpacing.md),
        if (members.isEmpty)
          Text('No other members yet.', style: AppTextStyles.captionMd)
        else
          for (final member in members) ...[
            _MemberRow(member: member, badge: badgeFor(member)),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.badge});

  final MeetupMember member;
  final ({String label, Color color}) badge;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          AvatarCircle(initials: member.initials, imageUrl: member.profileImageUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: AppTextStyles.titleMd),
                Text(member.handle, style: AppTextStyles.captionMd),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StatusBadge(label: badge.label, color: badge.color),
        ],
      ),
    );
  }
}

({String label, Color color}) _arrivalStatusBadge(MeetupMember member) {
  switch (member.arrivalStatus) {
    case MemberArrivalStatus.notLeftYet:
      return (label: 'Pending', color: BadgeColors.neutral);
    case MemberArrivalStatus.onTheWay:
      return (label: 'On the way', color: BadgeColors.info);
    case MemberArrivalStatus.arrived:
      return (label: 'Arrived', color: BadgeColors.positive);
    case MemberArrivalStatus.headingHome:
      return (label: 'Heading home', color: BadgeColors.neutral);
  }
}

({String label, Color color}) _inviteStatusBadge(MeetupMember member) {
  switch (member.inviteStatus) {
    case MemberInviteStatus.accepted:
      return (label: 'Accepted', color: BadgeColors.positive);
    case MemberInviteStatus.pending:
      return (label: 'Pending', color: BadgeColors.neutral);
    case MemberInviteStatus.declined:
      return (label: 'Declined', color: BadgeColors.negative);
  }
}
