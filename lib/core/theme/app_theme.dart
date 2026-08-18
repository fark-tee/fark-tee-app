import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

export 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.promptTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textBody,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgBase,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentDanger,
        brightness: Brightness.dark,
        surface: AppColors.bgBase,
        primary: AppColors.accentDanger,
        onPrimary: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgBase,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.displayLg,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.borderSubtle, width: 0.6),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 0.6,
        space: AppSpacing.lg,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: const BorderSide(color: AppColors.borderMuted),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.bgBase,
          textStyle: AppTextStyles.titleMd,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderMuted),
          textStyle: AppTextStyles.titleMd,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textMuted),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.bgElevated),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
