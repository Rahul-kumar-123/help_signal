import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum AlertType { all, medical, rescue, hazard, sos }

const alertIcons = {
  AlertType.medical: Icons.local_hospital,
  AlertType.rescue: Icons.shield,
  AlertType.hazard: Icons.warning,
  AlertType.sos: Icons.sos_sharp,
};

final List<Map<String, dynamic>> alerts = [
  {
    "type": AlertType.sos,
    "location": LatLng(51.505, -0.08),
    "description": "Emergency SOS",
    "color": Colors.red,
    "title": "Emergency SOS",
    "distance": "200m",
  },
  {
    "type": AlertType.medical,
    "location": LatLng(51.51, -0.1),
    "description": "Accident",
    "color": Colors.blue,
    "title": "Medical Help",
    "distance": "350m",
  },
  {
    "type": AlertType.rescue,
    "location": LatLng(51.49, -0.085),
    "description": "Rescue Needed",
    "color": Colors.orange,
    "title": "Rescue Needed",
    "distance": "500m",
  },
  {
    "type": AlertType.hazard,
    "location": LatLng(51.52, -0.12),
    "description": "Fire Hazard",
    "color": Colors.red,
    "title": "Hazard Alert",
    "distance": "1km",
  },
];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  AlertType activeFilter = AlertType.all;
  LatLng userLocation = LatLng(28.4953546, 77.0073292);
  double mapRotation = 0.0;
  LatLng? selectedAlertLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: userLocation,
              initialZoom: 13,
              initialRotation: mapRotation,
            ),
            mapController: _mapController,
            children: [
              openStreetMapLayer,
              MarkerLayer(
                markers: [
                  Marker(
                    point: userLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),

                  ...alerts
                      .where(
                        (alert) =>
                            alert["type"] == activeFilter ||
                            activeFilter == AlertType.all,
                      )
                      .map((alert) {
                        return Marker(
                          point: alert["location"],
                          width: 150,
                          height: 150,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedAlertLocation = alert["location"];
                              });
                              _showAlertCard(context, alert);
                            },
                            child: Icon(
                              alertIcons[alert["type"]],
                              color: alert["color"],
                              size: 36,
                            ),
                          ),
                        );
                      }),
                ],
              ),
              PolylineLayer(
                polylines: [
                  if (selectedAlertLocation != null)
                    Polyline(
                      points: [userLocation, selectedAlertLocation!],
                      color: Colors.red,
                      strokeWidth: 3,
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _filterChip("All", AlertType.all),
                  SizedBox(width: 10),
                  _filterChip("Medical", AlertType.medical),
                  SizedBox(width: 10),
                  _filterChip("Rescue", AlertType.rescue),
                  SizedBox(width: 10),
                  _filterChip("Hazard", AlertType.hazard),
                  SizedBox(width: 10),
                  _filterChip("SOS", AlertType.sos),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      mapRotation = 0.0;
                    });
                    _mapController.move(userLocation, 13);
                  },
                  backgroundColor: Colors.red,
                  child: Icon(
                    Icons.arrow_circle_up_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () {
                    setState(() {
                      userLocation = LatLng(
                        userLocation.latitude + 0.001,
                        userLocation.longitude + 0.001,
                      );
                    });
                    _mapController.move(userLocation, 13);
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, AlertType alertType) {
    return GestureDetector(
      onTap: () {
        setState(() {
          activeFilter = alertType;
          selectedAlertLocation = null;
        });
      },

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activeFilter == alertType
              ? Colors.red
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            if (alertType != AlertType.all)
              Icon(
                alertIcons[alertType],
                color: activeFilter == alertType ? Colors.white : Colors.black,
                size: 16,
              ),
            if (alertType != AlertType.all) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: activeFilter == alertType ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertCard(BuildContext context, Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert["title"],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text("${alert["distance"]} away • 2 min ago"),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alert["color"],
                      ),
                      child: const Text("Respond"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text("Details"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

TileLayer get openStreetMapLayer => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.helpsignal',
);
