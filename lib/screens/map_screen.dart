import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/alert_controller.dart';
import '../utilities/alert_data.dart';
import '../utilities/constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  AlertType activeFilter = AlertType.all;
  LatLng? selectedAlertLocation;

  @override
  void initState() {
    super.initState();
    selectedAlertLocation = widget.initialLocation;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _moveToInitialLocation(),
    );
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLocation != widget.initialLocation) {
      selectedAlertLocation = widget.initialLocation;
      if (widget.initialLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _moveToInitialLocation(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = HelpSignalScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final userLocation = controller.currentLocation ?? kFallbackMapCenter;
        final alerts = controller.alertsFor(activeFilter);

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: widget.initialLocation ?? userLocation,
                initialZoom: 13,
              ),
              mapController: _mapController,
              children: [
                openStreetMapLayer,
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                    ...alerts.map(
                      (alert) => Marker(
                        point: alert.location,
                        width: 80,
                        height: 80,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedAlertLocation = alert.location;
                            });
                            _showAlertCard(context, controller, alert);
                          },
                          child: Icon(
                            alert.type.icon,
                            color: alert.type.color,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
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
              top: 18,
              left: 16,
              right: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AlertType.values
                      .map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _filterChip(type),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            Positioned(
              top: 72,
              left: 16,
              right: 16,
                child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  controller.meshState.statusMessage,
                  style: const TextStyle(color: Color(0xFF5B403D)),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'refresh_map',
                    onPressed: () async {
                      final location = await controller.refreshLocation();
                      if (!mounted) {
                        return;
                      }
                      _mapController.move(location ?? userLocation, 13);
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.gps_fixed,
                      color: Color(0xFFD92D20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'center_map',
                    backgroundColor: Colors.red,
                    onPressed: () {
                      setState(() {
                        selectedAlertLocation = null;
                      });
                      _mapController.move(userLocation, 13);
                    },
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(AlertType alertType) {
    final isActive = activeFilter == alertType;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            activeFilter = alertType;
            selectedAlertLocation = null;
          });
        },
            child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? alertType.color
                : Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              if (alertType != AlertType.all)
                Icon(
                  alertType.icon,
                  color: isActive ? Colors.white : Colors.black,
                  size: 16,
                ),
              if (alertType != AlertType.all) const SizedBox(width: 6),
              Text(
                alertType.label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveToInitialLocation() {
    if (!mounted || widget.initialLocation == null) {
      return;
    }
    _mapController.move(widget.initialLocation!, 14);
  }

  void _showAlertCard(
    BuildContext context,
    AlertController controller,
    AlertMessage alert,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SingleChildScrollView(
          child: Container(
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
                  alert.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('${controller.distanceLabelFor(alert)} away'),
                    Text(controller.timeLabelFor(alert)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  alert.description ?? 'No additional details provided.',
                  style: const TextStyle(color: Color(0xFF5B403D)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            selectedAlertLocation = alert.location;
                          });
                          _mapController.move(alert.location, 14);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alert.type.color,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Navigate'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
