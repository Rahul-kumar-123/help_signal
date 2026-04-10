import 'package:flutter/material.dart';
import 'package:help_signal/utilities/alert_data.dart';
import 'package:latlong2/latlong.dart';

class AlertsScreen extends StatefulWidget {
  final void Function(LatLng?) onOpenMap;

  const AlertsScreen({super.key, required this.onOpenMap});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String activeFilter = "All";

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            _filters(),
            SizedBox(height: 16),
            ...alerts.map((alert) => _alertCard(alert)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Alerts",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            "Real-time emergency signals nearby.",
            style: TextStyle(color: Color(0xFF5B403D)),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final filters = ["All", "SOS", "Medical", "Rescue", "Hazard"];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final label = filters[i];
          final isActive = activeFilter == label;

          return GestureDetector(
            onTap: () => setState(() => activeFilter = label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: filters.length,
      ),
    );
  }

  Widget _alertCard(AlertModel alert) {
    final config = _alertConfig(alert.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _tag(config),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    alert.distance,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    alert.time,
                    style: const TextStyle(color: Color(0xFF5B403D)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            alert.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          if (alert.description != null && alert.description!.isNotEmpty) ...[
            Text(
              alert.description!,
              style: const TextStyle(color: Color(0xFF5B403D)),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Text(
              "No additional details",
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
          ],
          _actionButton(alert),
        ],
      ),
    );
  }

  Widget _tag(Map config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config["bg"],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(config["icon"], size: 14, color: config["color"]),
          const SizedBox(width: 4),
          Text(
            config["label"],
            style: TextStyle(
              color: config["color"],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(AlertModel alert) {
    final config = _alertConfig(alert.type);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleAlertAction(context, alert),
        style: ElevatedButton.styleFrom(
          backgroundColor: config["button"],
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          config["action"],
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _handleAlertAction(BuildContext context, AlertModel alert) {
    switch (alert.type) {
      case AlertType.sos:
      case AlertType.rescue:
        if (alert.location != null) {
          widget.onOpenMap(alert.location);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Routing to ${alert.title}'),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _showAlertDetailsSheet(context, alert);
        break;
      case AlertType.medical:
        _showAlertDetailsSheet(context, alert);
        break;
      case AlertType.hazard:
        _showHazardInstructionsSheet(context, alert);
        break;
      case AlertType.all:
        throw UnsupportedError(
          'AlertType.all should not be used for alert actions.',
        );
    }
  }

  void _showAlertDetailsSheet(BuildContext context, AlertModel alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                alert.description?.isNotEmpty == true
                    ? alert.description!
                    : 'No additional details provided.',
                style: const TextStyle(color: Color(0xFF5B403D), height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    alert.distance,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(alert.time, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHazardInstructionsSheet(BuildContext context, AlertModel alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hazard Safety Instructions',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                alert.description?.isNotEmpty == true
                    ? alert.description!
                    : 'No hazard details provided.',
                style: const TextStyle(color: Color(0xFF5B403D), height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                "• Move to a safe distance immediately. • Avoid the affected area until emergency services arrive.• Follow local authority instructions and keep clear of hazards.",
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _alertConfig(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return {
          "label": "SOS",
          "icon": Icons.close,
          "color": Colors.red,
          "bg": const Color(0xFFFFE5E5),
          "button": Colors.red,
          "action": "Respond",
        };
      case AlertType.medical:
        return {
          "label": "MEDICAL",
          "icon": Icons.local_hospital,
          "color": Colors.blue,
          "bg": const Color(0xFFE3F2FD),
          "button": Colors.blue,
          "action": "Monitor Case",
        };
      case AlertType.hazard:
        return {
          "label": "HAZARD",
          "icon": Icons.warning,
          "color": Colors.red,
          "bg": const Color(0xFFFFE5E5),
          "button": Colors.grey.shade300,
          "action": "Safety Instructions",
        };
      case AlertType.rescue:
        return {
          "label": "RESCUE",
          "icon": Icons.search,
          "color": Colors.orange,
          "bg": const Color(0xFFFFF3E0),
          "button": Colors.orange,
          "action": "Respond to Request",
        };
      case AlertType.all:
        throw UnsupportedError(
          'AlertType.all should not be used in _alertConfig()',
        );
    }
  }
}
