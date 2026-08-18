import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'lat_lng.dart';
import 'map_marker.dart';
import 'map_widget.dart';

/// Placeholder `MapWidget` implementation: a custom-painted light street grid
/// (matching the reference screenshots, where the map area stays light even
/// though the rest of the UI is dark) with markers positioned by projecting
/// lat/lng onto the widget's bounds. No API key, no network tiles - this is
/// what every screen renders until a real SDK-backed `MapWidget` is swapped
/// in.
class MockMapWidget extends MapWidget {
  const MockMapWidget({
    super.key,
    required super.center,
    super.markers,
    super.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final projector = _MapProjector(
          center: center,
          markers: markers,
          size: size,
        );

        return GestureDetector(
          onTapUp: onTap == null
              ? null
              : (details) => onTap!(projector.unproject(details.localPosition)),
          child: Container(
            color: const Color(0xFFE5E7EB),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _StreetGridPainter(), size: size),
                for (final marker in markers)
                  _MarkerPin(marker: marker, offset: projector.project(marker.position)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Projects fake lat/lng deltas onto pixel offsets. There are no real map
/// tiles to align with, so the "zoom level" (`_span`) is just picked wide
/// enough to spread whatever markers are passed in in the widget's bounds.
class _MapProjector {
  _MapProjector({
    required this.center,
    required List<MapMarker> markers,
    required this.size,
  }) : _span = _computeSpan(center, markers);

  final LatLng center;
  final Size size;
  final double _span;

  static double _computeSpan(LatLng center, List<MapMarker> markers) {
    var maxDelta = 0.0015;
    for (final marker in markers) {
      maxDelta = math.max(
        maxDelta,
        math.max(
          (marker.position.latitude - center.latitude).abs(),
          (marker.position.longitude - center.longitude).abs(),
        ),
      );
    }
    return maxDelta * 2.6;
  }

  Offset project(LatLng point) {
    final dx = (point.longitude - center.longitude) / _span;
    final dy = (center.latitude - point.latitude) / _span;
    return Offset(
      size.width / 2 + dx * size.width,
      size.height / 2 + dy * size.height,
    );
  }

  LatLng unproject(Offset offset) {
    final dx = (offset.dx - size.width / 2) / size.width;
    final dy = (offset.dy - size.height / 2) / size.height;
    return LatLng(center.latitude - dy * _span, center.longitude + dx * _span);
  }
}

class _StreetGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final block = Paint()..color = const Color(0xFFEDEEF0);
    canvas.drawRect(Offset.zero & size, block);

    final minorRoad = Paint()
      ..color = const Color(0xFFD7D9DC)
      ..strokeWidth = 1.5;
    const step = 44.0;
    for (double x = size.width % step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorRoad);
    }
    for (double y = size.height % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorRoad);
    }

    final majorRoad = Paint()
      ..color = const Color(0xFFC6C9CE)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width * 0.32, 0),
      Offset(size.width * 0.32, size.height),
      majorRoad,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.58),
      Offset(size.width, size.height * 0.58),
      majorRoad,
    );
  }

  @override
  bool shouldRepaint(covariant _StreetGridPainter oldDelegate) => false;
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({required this.marker, required this.offset});

  final MapMarker marker;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final pin = marker.type == MapMarkerType.venue
        ? _VenuePin(label: marker.label)
        : _MemberPin(marker: marker);

    if (marker.caption == null) {
      return Positioned(
        left: offset.dx - 20,
        top: offset.dy - 40,
        child: pin,
      );
    }

    return Positioned(
      left: offset.dx - 32,
      top: offset.dy - 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pin,
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bgBase.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              marker.caption!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _VenuePin extends StatelessWidget {
  const _VenuePin({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accentDanger.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accentDanger,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberPin extends StatelessWidget {
  const _MemberPin({required this.marker});

  final MapMarker marker;

  @override
  Widget build(BuildContext context) {
    final imageUrl = marker.profileImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.bgAvatar,
        shape: BoxShape.circle,
        border: Border.all(
          color: marker.isCurrentUser ? AppColors.accentDanger : Colors.white,
          width: marker.isCurrentUser ? 3 : 2,
        ),
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                onError: (_, _) {},
              )
            : null,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              marker.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
