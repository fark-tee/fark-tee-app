import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Initials-in-circle avatar, or the user's real photo when [imageUrl] is
/// given. Falls back to initials on a missing/empty url or a failed load.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 32,
    this.borderColor,
  });

  final String initials;
  final String? imageUrl;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.bgAvatar,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
        image: (url == null || url.isEmpty)
            ? null
            : DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
                onError: (_, _) {},
              ),
      ),
      alignment: Alignment.center,
      child: (url == null || url.isEmpty)
          ? Text(
              initials,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

/// Overlapping avatar circles with a "+N" overflow badge, used on the Active
/// Groups / Groups cards.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.initialsList,
    this.imageUrls,
    this.max = 3,
    this.size = 24,
  });

  final List<String> initialsList;
  final List<String?>? imageUrls;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = initialsList.take(max).toList();
    final overflow = initialsList.length - shown.length;
    final overlap = size * 0.6;

    return SizedBox(
      height: size,
      width: overlap * (shown.length + (overflow > 0 ? 1 : 0)) + (size - overlap),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: overlap * i,
              child: AvatarCircle(
                initials: shown[i],
                imageUrl: imageUrls != null && i < imageUrls!.length ? imageUrls![i] : null,
                size: size,
                borderColor: AppColors.bgElevated,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: overlap * shown.length,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgElevated, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
