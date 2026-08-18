import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/section_header.dart';
import '../../meetups/meetups_controller.dart';
import '../../meetups/models/meetup.dart';
import '../../meetups/models/meetup_enums.dart';
import '../../meetups/models/meetup_invite.dart';

/// The Groups tab: "TONIGHT" / "UPCOMING" / "PAST" sections of meetups, per
/// the spec's "16. GROUPS SCREEN". Empty sections are skipped entirely.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MeetupsController>().loadGroups();
    context.read<MeetupsController>().loadInvites();
  }

  Future<void> _accept(BuildContext context, String meetupId) async {
    try {
      await context.read<MeetupsController>().acceptInvite(meetupId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ตอบรับคำเชิญไม่สำเร็จ')),
      );
    }
  }

  Future<void> _decline(BuildContext context, String meetupId) async {
    try {
      await context.read<MeetupsController>().declineInvite(meetupId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ปฏิเสธคำเชิญไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MeetupsController>();
    final groups = controller.groups;
    final invites = controller.invites;
    final isEmpty =
        groups.tonight.isEmpty &&
        groups.upcoming.isEmpty &&
        groups.past.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text('ตี้ของคุณ', style: AppTextStyles.displayLg),
            ),
            Expanded(
              child: controller.loadingGroups && isEmpty && invites.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : isEmpty && invites.isEmpty
                  ? Center(
                      child: Text(
                        'ยังไม่มีตี้',
                        style: AppTextStyles.captionMd,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      children: [
                        if (invites.isNotEmpty)
                          _InviteSection(
                            invites: invites,
                            actionInFlight: controller.inviteActionInFlight,
                            onAccept: (id) => _accept(context, id),
                            onDecline: (id) => _decline(context, id),
                          ),
                        if (groups.tonight.isNotEmpty)
                          _MeetupSection(
                            title: 'วันนี้',
                            meetups: groups.tonight,
                            isTonight: true,
                          ),
                        if (groups.upcoming.isNotEmpty)
                          _MeetupSection(
                            title: 'กำลังจะถึง',
                            meetups: groups.upcoming,
                          ),
                        if (groups.past.isNotEmpty)
                          _MeetupSection(title: 'ที่ผ่านมา', meetups: groups.past),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteSection extends StatelessWidget {
  const _InviteSection({
    required this.invites,
    required this.actionInFlight,
    required this.onAccept,
    required this.onDecline,
  });

  final List<MeetupInvite> invites;
  final Set<String> actionInFlight;
  final void Function(String meetupId) onAccept;
  final void Function(String meetupId) onDecline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'คำเชิญ'),
          const SizedBox(height: AppSpacing.sm),
          for (final invite in invites) ...[
            _InviteCard(
              invite: invite,
              loading: actionInFlight.contains(invite.meetupId),
              onAccept: () => onAccept(invite.meetupId),
              onDecline: () => onDecline(invite.meetupId),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.loading,
    required this.onAccept,
    required this.onDecline,
  });

  final MeetupInvite invite;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(invite.title, style: AppTextStyles.titleMd),
          const SizedBox(height: 2),
          Text(
            '${invite.invitedByName} เชิญคุณ · ${invite.destinationName}',
            style: AppTextStyles.captionMd,
          ),
          const SizedBox(height: 2),
          Text(
            '${formatDayLabel(invite.startTime)} · ${formatTime12h(invite.startTime)}',
            style: AppTextStyles.captionMd,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : onDecline,
                  child: const Text('ปฏิเสธ'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: loading ? null : onAccept,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ตอบรับ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeetupSection extends StatelessWidget {
  const _MeetupSection({
    required this.title,
    required this.meetups,
    this.isTonight = false,
  });

  final String title;
  final List<Meetup> meetups;
  final bool isTonight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: AppSpacing.sm),
          for (final meetup in meetups) ...[
            _MeetupCard(meetup: meetup, isTonight: isTonight),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _MeetupCard extends StatelessWidget {
  const _MeetupCard({required this.meetup, this.isTonight = false});

  final Meetup meetup;
  final bool isTonight;

  @override
  Widget build(BuildContext context) {
    final total = meetup.members.length;
    final arrived = meetup.arrivedCount;
    // "TONIGHT" cards (and any meetup that's already live) additionally show
    // who has arrived so far, per the spec's Groups screen example.
    final showArrivalStatus = isTonight || meetup.status == MeetupStatus.live;
    final subtitle =
        '${formatDayLabel(meetup.startTime)} · ${formatTime12h(meetup.startTime)} · $total people';

    return AppCard(
      onTap: () => context.push('/meetup/${meetup.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meetup.title,
                        style: AppTextStyles.titleMd,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showArrivalStatus) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AvatarStack(
                        initialsList: meetup.members
                            .map((m) => m.initials)
                            .toList(),
                        imageUrls: meetup.members
                            .map((m) => m.profileImageUrl)
                            .toList(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.captionMd),
                if (showArrivalStatus) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : arrived / total,
                      minHeight: 4,
                      backgroundColor: AppColors.bgSurface,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.accentDanger,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'ถึงแล้ว $arrived จาก $total คน',
                    style: AppTextStyles.captionMd,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
