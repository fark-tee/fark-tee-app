import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/mock_identity.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/auth_controller.dart';
import '../data/mock_badges_repository.dart';
import '../models/profile_badge.dart';

/// Profile tab: avatar/name/handle, star rating, on-time/late stats, mock
/// badges, and a Settings entry point that surfaces sign-out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<ProfileBadge>? _badges;

  @override
  void initState() {
    super.initState();
    context.read<AuthController>().refreshUser();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final badges = await context.read<MockBadgesRepository>().getBadges();
    if (!mounted) return;
    setState(() => _badges = badges);
  }

  void _showSignOutSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PillButton(
                  label: 'Sign Out',
                  destructive: true,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.read<AuthController>().signOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filledStars = user.rating.round().clamp(0, 5);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: Column(
                children: [
                  AvatarCircle(
                    initials: initialsFor(user.displayName),
                    imageUrl: user.profileImageUrl,
                    size: 88,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(user.displayName, style: AppTextStyles.displayLg),
                  const SizedBox(height: 2),
                  Text(
                    user.username.isEmpty ? mockHandleFor(user.displayName) : '@${user.username}',
                    style: AppTextStyles.captionMd,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          i < filledStars ? Icons.star : Icons.star_border,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${user.rating.toStringAsFixed(1)} (${_abbreviate(user.ratingCount)})',
                        style: AppTextStyles.captionMd,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: _StatColumn(value: user.onTimeCount, label: 'On time'),
                  ),
                  Container(width: 0.6, height: 32, color: AppColors.borderSubtle),
                  Expanded(
                    child: _StatColumn(value: user.lateCount, label: 'Late'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(title: 'Badges'),
            const SizedBox(height: AppSpacing.md),
            if (_badges == null)
              const Center(child: CircularProgressIndicator())
            else
              for (final badge in _badges!) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge.title, style: AppTextStyles.titleMd),
                      const SizedBox(height: 2),
                      Text(badge.description, style: AppTextStyles.captionMd),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.md),
            AppCard(
              onTap: () => context.push('/saved-locations'),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.textBody),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('สถานที่บันทึกไว้', style: AppTextStyles.titleMd),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: _showSignOutSheet,
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, color: AppColors.textBody),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('Settings', style: AppTextStyles.titleMd)),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: AppTextStyles.displayLg.copyWith(fontSize: 22, height: 1),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.captionMd),
      ],
    );
  }
}

/// Turns e.g. 21500 into "21.5K"; leaves smaller counts as-is.
String _abbreviate(int count) {
  if (count < 1000) return '$count';
  final thousands = count / 1000;
  final rounded = (thousands * 10).round() / 10;
  final label = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
  return '${label}K';
}
