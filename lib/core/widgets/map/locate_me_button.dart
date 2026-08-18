import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Circular floating button overlaid on a map picker, matching the "find my
/// location" affordance; shows a spinner in place of the icon while a GPS
/// fix is in flight.
class LocateMeButton extends StatelessWidget {
  const LocateMeButton({super.key, required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textPrimary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: loading ? null : onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgBase),
                )
              : const Icon(Icons.my_location, color: AppColors.bgBase, size: 20),
        ),
      ),
    );
  }
}
