import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale per the UI spec. Font is Prompt throughout; weight/size/
/// leading below match the spec's table exactly. `labelSm` additionally
/// needs manual `.toUpperCase()` at the call site - it's a text transform,
/// not something a TextStyle can express.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle displayLg = GoogleFonts.prompt(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 28 / 18,
    color: AppColors.textPrimary,
  );

  static TextStyle titleMd = GoogleFonts.prompt(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMd = GoogleFonts.prompt(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    color: AppColors.textBody,
  );

  static TextStyle captionMd = GoogleFonts.prompt(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    color: AppColors.textMuted,
  );

  static TextStyle labelSm = GoogleFonts.prompt(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 15 / 10,
    letterSpacing: 0.25,
    color: AppColors.textMuted,
  );

  static TextStyle microSm = GoogleFonts.prompt(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 15 / 10,
    color: AppColors.textMuted,
  );

  static TextStyle tinySm = GoogleFonts.prompt(
    fontSize: 8,
    fontWeight: FontWeight.w500,
    height: 12 / 8,
    color: AppColors.textPrimary,
  );

  static TextStyle statusBar = GoogleFonts.prompt(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    color: AppColors.textSecondary,
  );
}
