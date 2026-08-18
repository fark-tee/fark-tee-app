/// Provider-agnostic coordinate so `MapWidget` implementations never leak a
/// specific map SDK's types into screen code.
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
