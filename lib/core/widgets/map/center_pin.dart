import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Fixed pin drawn dead-center over a map, for location pickers where the
/// user drags the map underneath a stationary pin (instead of tapping to
/// drop one) to choose a point. The pin's tip - not its bounding-box center -
/// must land exactly on the map's center coordinate, hence the upward
/// translation by half the icon's height.
class CenterPin extends StatelessWidget {
  const CenterPin({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: Offset(0, -size / 2),
          child: Icon(
            Icons.location_on,
            size: size,
            color: AppColors.accentDanger,
            shadows: const [
              Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }
}
