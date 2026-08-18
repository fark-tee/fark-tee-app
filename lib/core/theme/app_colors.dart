import 'package:flutter/material.dart';

/// Design-system color tokens. Hex values are exact per the UI spec - do not
/// substitute Material's derived shades for these.
class AppColors {
  AppColors._();

  // Background
  static const bgBase = Color(0xFF141414);
  static const bgElevated = Color(0xFF1F1F1F);
  static const bgSurface = Color(0xFF242424);
  static const bgAvatar = Color(0xFF1E2939);

  // Border
  static const borderSubtle = Color(0xFF2A2A2A);
  static const borderMuted = Color(0xFF333333);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textBody = Color(0xFFE5E7EB);
  static const textSecondary = Color(0xFFD1D5DC);
  static const textMuted = Color(0xFF99A1AF);

  // Accent
  static const accentDanger = Color(0xFF7C1D1D);
}
