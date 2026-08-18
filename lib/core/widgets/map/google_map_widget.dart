import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import 'lat_lng.dart';
import 'map_marker.dart';
import 'map_widget.dart';

/// Real Google Maps-backed `MapWidget` (display only - see `MockMapWidget`
/// for the placeholder this replaces). Requires a Maps SDK for Android key
/// in `android/local.properties` (`maps.apiKey`), read into the manifest via
/// `android/app/build.gradle.kts`.
///
/// Markers are plain colored pins (venue = orange, current user = red, other
/// members = azure) with the label/caption shown via `InfoWindow` on tap -
/// Google Maps markers can't host arbitrary widgets the way the mock's
/// initials-in-circle avatars do without generating custom bitmap icons,
/// which is out of scope for "just for showing".
class GoogleMapWidget extends MapWidget {
  const GoogleMapWidget({
    super.key,
    required super.center,
    super.markers,
    super.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _toGoogleLatLng(center),
        zoom: 15,
      ),
      markers: markers.map(_toGoogleMarker).toSet(),
      onTap: onTap == null
          ? null
          : (point) => onTap!(LatLng(point.latitude, point.longitude)),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  gmaps.LatLng _toGoogleLatLng(LatLng point) =>
      gmaps.LatLng(point.latitude, point.longitude);

  gmaps.Marker _toGoogleMarker(MapMarker marker) {
    final hue = switch (marker.type) {
      MapMarkerType.venue => gmaps.BitmapDescriptor.hueOrange,
      MapMarkerType.member when marker.isCurrentUser => gmaps.BitmapDescriptor.hueRed,
      MapMarkerType.member => gmaps.BitmapDescriptor.hueAzure,
    };
    return gmaps.Marker(
      markerId: gmaps.MarkerId(marker.id),
      position: _toGoogleLatLng(marker.position),
      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: gmaps.InfoWindow(title: marker.label, snippet: marker.caption),
    );
  }
}
