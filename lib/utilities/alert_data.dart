import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum AlertType { all, medical, rescue, hazard, sos }

const Map<AlertType, IconData> alertIcons = {
  AlertType.medical: Icons.local_hospital,
  AlertType.rescue: Icons.shield,
  AlertType.hazard: Icons.warning,
  AlertType.sos: Icons.sos_sharp,
};

class AlertModel {
  final String id;
  final AlertType type;
  final String title;
  final String? description;
  final String distance;
  final String time;
  final LatLng? location;
  final Color color;

  const AlertModel({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.distance,
    required this.time,
    this.location,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'distance': distance,
      'time': time,
      'location': location == null
          ? null
          : {'latitude': location!.latitude, 'longitude': location!.longitude},
      'color': color.toARGB32(),
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    LatLng? location;
    if (map['location'] != null) {
      final locationMap = map['location'] as Map<String, dynamic>;
      location = LatLng(
        locationMap['latitude'] as double,
        locationMap['longitude'] as double,
      );
    }

    return AlertModel(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String),
      title: map['title'] as String,
      description: map['description'] as String?,
      distance: map['distance'] as String,
      time: map['time'] as String,
      location: location,
      color: Color(map['color'] as int),
    );
  }

  static AlertType _typeFromString(String raw) {
    return AlertType.values.firstWhere(
      (value) => value.toString().split('.').last == raw,
      orElse: () => AlertType.all,
    );
  }
}

final List<AlertModel> alerts = [
  AlertModel(
    id: 'sos-001',
    type: AlertType.sos,
    title: "Severe Vehicle Collision",
    description: null,
    distance: "0.4 KM",
    time: "2 min ago",
    location: LatLng(51.505, -0.08),
    color: Colors.red,
  ),
  AlertModel(
    id: 'medical-001',
    type: AlertType.medical,
    title: "Cardiac Emergency",
    description: "Immediate AED assistance needed at Central Park South Gate. Critical oxygen levels.",
    distance: "1.2 KM",
    time: "8 min ago",
    location: LatLng(51.51, -0.1),
    color: Colors.blue,
  ),
  AlertModel(
    id: 'hazard-001',
    type: AlertType.hazard,
    title: "Gas Leak Reported",
    description: "Structural hazard in zone 4B. Maintain 500m distance from site.",
    distance: "2.8 KM",
    time: "15 min ago",
    location: LatLng(51.52, -0.12),
    color: Colors.orange,
  ),
  AlertModel(
    id: 'rescue-001',
    type: AlertType.rescue,
    title: "Wilderness Search",
    description: "Missing hiker in Eastern Ridge area. Tracking gear volunteers requested.",
    distance: "5.1 KM",
    time: "22 min ago",
    location: LatLng(51.49, -0.085),
    color: Colors.orange,
  ),
];