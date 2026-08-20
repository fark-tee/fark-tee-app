import 'lat_lng.dart';

/// Decodes a Google polyline-encoded string (precision 5) into its points, as
/// returned by OSRM's `/route/v1` endpoint with `geometries=polyline`.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final (latDelta, afterLat) = _decodeSignedValue(encoded, index);
    lat += latDelta;
    final (lngDelta, afterLng) = _decodeSignedValue(encoded, afterLat);
    lng += lngDelta;
    index = afterLng;
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

/// Decodes one varint-encoded, zigzag-signed delta starting at [start],
/// returning its value and the index just past it.
(int, int) _decodeSignedValue(String encoded, int start) {
  var result = 0;
  var shift = 0;
  var index = start;

  int byte;
  do {
    byte = encoded.codeUnitAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);

  final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return (value, index);
}
