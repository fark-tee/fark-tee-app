import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-width white pill button used for every primary CTA ("Confirm
/// Location", "Send N Invitations", "I've Arrived", ...). `loading` swaps the
/// label for a small spinner without changing the button's size.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.destructive = false,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool destructive;

  /// Optional accent border drawn around the button, e.g. to call out a
  /// time-sensitive action without switching to the `destructive` fill.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    ButtonStyle? style;
    if (destructive) {
      style = FilledButton.styleFrom(
        backgroundColor: AppColors.accentDanger,
        foregroundColor: AppColors.textPrimary,
        shape: const StadiumBorder(),
      );
    } else if (borderColor != null) {
      style = FilledButton.styleFrom(side: BorderSide(color: borderColor!));
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: child,
      ),
    );
  }
}

/// Outlined pill variant for secondary actions.
class PillOutlineButton extends StatelessWidget {
  const PillOutlineButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
