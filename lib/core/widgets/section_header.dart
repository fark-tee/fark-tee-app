import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// ALL-CAPS section label per the spec's `labelSm` token, e.g. "TONIGHT",
/// "MEMBERS". Optional trailing widget for things like "1 active".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.toUpperCase(), style: AppTextStyles.labelSm),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}
