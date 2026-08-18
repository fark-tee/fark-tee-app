import '../../../core/widgets/map/lat_lng.dart';

class MeetupLocation {
  const MeetupLocation({
    required this.name,
    required this.address,
    required this.position,
  });

  final String name;
  final String address;
  final LatLng position;
}
