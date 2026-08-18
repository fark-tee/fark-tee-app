import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_format.dart';
import '../models/notification_item.dart';
import '../notifications_controller.dart';

/// Full notifications list, newest-first (the controller/repository already
/// sort it that way). Tapping a row marks it read and, for notifications
/// tied to a meetup, pushes straight into that meetup's detail screen.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsController>().load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    final notifications = controller.notifications;

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
              child: Text('Notifications', style: AppTextStyles.displayLg),
            ),
            Expanded(
              child: controller.loading && notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : notifications.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications yet',
                        style: AppTextStyles.captionMd,
                      ),
                    )
                  : ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.borderSubtle),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return _NotificationRow(
                          item: item,
                          onTap: () {
                            context.read<NotificationsController>().markRead(item.id);
                            if (item.relatedMeetupId != null) {
                              context.push('/meetup/${item.relatedMeetupId}');
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  static IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.meetupInvitation:
        return Icons.mail_outline;
      case NotificationType.meetupAccepted:
        return Icons.check_circle_outline;
      case NotificationType.meetupStartingSoon:
        return Icons.schedule;
      case NotificationType.locationSharingStarted:
        return Icons.location_on_outlined;
      case NotificationType.friendArrived:
        return Icons.person_pin_circle_outlined;
      case NotificationType.meetupCancelled:
        return Icons.cancel_outlined;
      case NotificationType.headingHome:
        return Icons.home_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(_iconFor(item.type), size: 18, color: AppColors.textBody),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (item.body != null) ...[
                    const SizedBox(height: 2),
                    Text(item.body!, style: AppTextStyles.captionMd),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(formatRelative(item.timestamp), style: AppTextStyles.captionMd),
                ],
              ),
            ),
            if (!item.read) ...[
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentDanger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
