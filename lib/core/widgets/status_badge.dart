import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Small pill-shaped status chip (Accepted/Pending/On the way/Arrived/...).
/// Generic by design - each feature maps its own status enum to a label +
/// color via an extension, rather than this widget knowing about every
/// feature's enums.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.microSm.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Common badge colors shared across features (kept here so unrelated
/// features don't invent slightly different shades for the same meaning).
class BadgeColors {
  BadgeColors._();

  static const positive = Color(0xFF4ADE80);
  static const neutral = AppColors.textMuted;
  static const negative = AppColors.accentDanger;
  static const info = Color(0xFF60A5FA);
}
