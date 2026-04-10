import 'package:latlong2/latlong.dart';

/// Simple location utilities and distance calculations.
class LocationManager {
  final Distance _distance = Distance();

  Future<LatLng> getCurrentLocation() async {
    return const LatLng(28.4953546, 77.0073292);
  }

  double distanceBetween(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Meter, from, to);
  }

  String formatDistance(LatLng from, LatLng to) {
    final meters = distanceBetween(from, to);
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}
