import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../theme/app_colors.dart';
import 'lat_lng.dart';
import 'map_marker.dart';
import 'map_widget.dart';

/// Real Google Maps-backed `MapWidget` (display only - see `MockMapWidget`
/// for the placeholder this replaces). Requires a Maps SDK for Android key
/// in `android/local.properties` (`maps.apiKey`), read into the manifest via
/// `android/app/build.gradle.kts`.
///
/// Markers without a profile photo are plain colored pins (venue = orange,
/// current user = red, other members = azure) with the label/caption shown
/// via `InfoWindow` on tap. Markers with a `profileImageUrl` render the photo
/// itself, cropped to a circle - Google Maps markers can't host arbitrary
/// widgets, so the circular avatar is rendered offscreen into a PNG and
/// handed to the SDK as a custom `BitmapDescriptor`.
class GoogleMapWidget extends MapWidget {
  const GoogleMapWidget({
    super.key,
    required super.center,
    super.markers,
    super.onTap,
    this.onCenterChanged,
    this.centerController,
  });

  /// Fired once the camera settles (drag released, or a tap/[centerController]
  /// move finishes animating) - the location-picker screens use this to know
  /// where a fixed, screen-centered pin (drawn by the caller, not a
  /// [MapMarker]) currently points to.
  final ValueChanged<LatLng>? onCenterChanged;

  /// Imperative handle for moving the camera after this widget is already
  /// mounted (e.g. a "find me" button, or picking a search result) - [center]
  /// only feeds the platform view's *initial* camera position (see the class
  /// doc above), so anything that needs to move the already-live map goes
  /// through this instead.
  final MapCenterController? centerController;

  @override
  Widget build(BuildContext context) {
    return _GoogleMapView(
      center: center,
      markers: markers,
      onTap: onTap,
      onCenterChanged: onCenterChanged,
      centerController: centerController,
    );
  }
}

/// See [GoogleMapWidget.centerController].
class MapCenterController {
  gmaps.GoogleMapController? _controller;

  void _attach(gmaps.GoogleMapController controller) {
    _controller = controller;
  }

  Future<void> moveTo(LatLng point) async {
    await _controller?.animateCamera(
      gmaps.CameraUpdate.newLatLng(gmaps.LatLng(point.latitude, point.longitude)),
    );
  }
}

class _GoogleMapView extends StatefulWidget {
  const _GoogleMapView({
    required this.center,
    required this.markers,
    this.onTap,
    this.onCenterChanged,
    this.centerController,
  });

  final LatLng center;
  final List<MapMarker> markers;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<LatLng>? onCenterChanged;
  final MapCenterController? centerController;

  @override
  State<_GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<_GoogleMapView> {
  // Physical pixel size of the rendered avatar bitmap - large enough to stay
  // sharp on a high-DPI device without being wasteful.
  static const _avatarSize = 96.0;

  final Map<String, gmaps.BitmapDescriptor> _avatarIcons = {};
  final Set<String> _pendingUrls = {};

  // Tracked continuously while the camera is moving so the final position is
  // available once `onCameraIdle` fires (that callback carries no position
  // of its own).
  LatLng? _lastCameraTarget;

  @override
  void initState() {
    super.initState();
    _loadMissingAvatars();
  }

  @override
  void didUpdateWidget(covariant _GoogleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadMissingAvatars();
  }

  void _loadMissingAvatars() {
    for (final marker in widget.markers) {
      final url = marker.profileImageUrl;
      if (url == null || url.isEmpty) continue;
      if (_avatarIcons.containsKey(url) || _pendingUrls.contains(url)) continue;

      _pendingUrls.add(url);
      _loadAvatarIcon(url, isCurrentUser: marker.isCurrentUser);
    }
  }

  Future<void> _loadAvatarIcon(String url, {required bool isCurrentUser}) async {
    try {
      final image = await _resolveImage(url);
      final icon = await _circularBitmapDescriptor(image, isCurrentUser: isCurrentUser);
      if (mounted) setState(() => _avatarIcons[url] = icon);
    } catch (_) {
      // Leave uncached - the marker falls back to a colored default pin.
    } finally {
      _pendingUrls.remove(url);
    }
  }

  Future<ui.Image> _resolveImage(String url) {
    final completer = Completer<ui.Image>();
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  Future<gmaps.BitmapDescriptor> _circularBitmapDescriptor(
    ui.Image image, {
    required bool isCurrentUser,
  }) async {
    const size = _avatarSize;
    final borderWidth = isCurrentUser ? size * 0.06 : size * 0.04;
    final borderColor = isCurrentUser ? AppColors.accentDanger : Colors.white;
    const center = Offset(size / 2, size / 2);
    const radius = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    canvas.drawCircle(center, radius, Paint()..color = borderColor);

    final innerRadius = radius - borderWidth;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius)));
    canvas.drawImageRect(
      image,
      _coverSourceRect(image),
      Rect.fromCircle(center: center, radius: innerRadius),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    final rendered = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return gmaps.BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: 2);
  }

  /// The centered square crop of [image] matching `BoxFit.cover` behavior.
  Rect _coverSourceRect(ui.Image image) {
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final side = width < height ? width : height;
    return Rect.fromLTWH((width - side) / 2, (height - side) / 2, side, side);
  }

  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _toGoogleLatLng(widget.center),
        zoom: 15,
      ),
      markers: widget.markers.map(_toGoogleMarker).toSet(),
      onMapCreated: (controller) => widget.centerController?._attach(controller),
      onCameraMove: (position) => _lastCameraTarget = LatLng(
        position.target.latitude,
        position.target.longitude,
      ),
      onCameraIdle: () {
        final target = _lastCameraTarget;
        if (target != null) widget.onCenterChanged?.call(target);
      },
      onTap: widget.onTap == null && widget.onCenterChanged == null
          ? null
          : (point) {
              final latLng = LatLng(point.latitude, point.longitude);
              widget.onTap?.call(latLng);
              // A fixed-pin picker: taps recenter the camera under the pin
              // rather than reporting the raw tap point directly - the
              // resulting `onCameraIdle` above reports it once settled.
              if (widget.onCenterChanged != null) {
                widget.centerController?.moveTo(latLng);
              }
            },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  gmaps.LatLng _toGoogleLatLng(LatLng point) =>
      gmaps.LatLng(point.latitude, point.longitude);

  gmaps.Marker _toGoogleMarker(MapMarker marker) {
    final avatarIcon = marker.profileImageUrl == null
        ? null
        : _avatarIcons[marker.profileImageUrl];

    final icon = avatarIcon ??
        gmaps.BitmapDescriptor.defaultMarkerWithHue(switch (marker.type) {
          MapMarkerType.venue => gmaps.BitmapDescriptor.hueOrange,
          MapMarkerType.member when marker.isCurrentUser => gmaps.BitmapDescriptor.hueRed,
          MapMarkerType.member => gmaps.BitmapDescriptor.hueAzure,
        });

    return gmaps.Marker(
      markerId: gmaps.MarkerId(marker.id),
      position: _toGoogleLatLng(marker.position),
      icon: icon,
      anchor: avatarIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
      infoWindow: gmaps.InfoWindow(title: marker.label, snippet: marker.caption),
    );
  }
}
