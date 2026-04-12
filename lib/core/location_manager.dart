import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationManager {
  Future<LatLng?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _getLastKnownLocation();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _getLastKnownLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _getLastKnownLocation();
      }

      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _getLastKnownLocation();
    }
  }

  Future<LatLng?> _getLastKnownLocation() async {
    try {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition == null) {
        return null;
      }

      return LatLng(lastPosition.latitude, lastPosition.longitude);
    } catch (_) {
      return null;
    }
  }

  double calculateDistance(LatLng userLocation, LatLng alertLocation) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, userLocation, alertLocation);
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
