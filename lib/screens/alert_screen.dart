import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/alert_controller.dart';
import '../utilities/alert_data.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.onOpenMap});

  final void Function(LatLng?) onOpenMap;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertType activeFilter = AlertType.all;

  @override
  Widget build(BuildContext context) {
    final controller = HelpSignalScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final filteredAlerts = controller.alertsFor(activeFilter);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(controller),
              _filters(),
              const SizedBox(height: 16),
              if (filteredAlerts.isEmpty)
                _emptyState()
              else
                ...filteredAlerts.map(
                  (alert) => _alertCard(context, controller, alert),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(AlertController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alerts',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${controller.alerts.length} stored alert${controller.alerts.length == 1 ? '' : 's'} '
            'across the local device and mesh.',
            style: const TextStyle(color: Color(0xFF5B403D)),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final filters = AlertType.values;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final filter = filters[index];
          final isActive = activeFilter == filter;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => activeFilter = filter),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive ? filter.color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
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

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No alerts match this filter yet. Send a new alert from Home or scan for nearby peers.',
        style: TextStyle(height: 1.45, color: Color(0xFF5B403D)),
      ),
    );
  }

  Widget _alertCard(
    BuildContext context,
    AlertController controller,
    AlertMessage alert,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
          boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _tag(alert.type),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      controller.distanceLabelFor(alert),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      controller.timeLabelFor(alert),
                      style: const TextStyle(color: Color(0xFF5B403D)),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            alert.description ?? 'No additional details',
            style: TextStyle(
              color: alert.description == null
                  ? Colors.grey.shade500
                  : const Color(0xFF5B403D),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                'Hop count: ${alert.hopCount}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              Text(
                'Sender: ${alert.senderId}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _actionButton(context, controller, alert),
        ],
      ),
    );
  }

  Widget _tag(AlertType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: type.lightColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(type.icon, size: 14, color: type.color),
          const SizedBox(width: 4),
          Text(
            type.label.toUpperCase(),
            style: TextStyle(
              color: type.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    AlertController controller,
    AlertMessage alert,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleAlertAction(context, controller, alert),
        style: ElevatedButton.styleFrom(
          backgroundColor: alert.type.color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(alert.type.actionLabel),
      ),
    );
  }

  void _handleAlertAction(
    BuildContext context,
    AlertController controller,
    AlertMessage alert,
  ) {
    switch (alert.type) {
      case AlertType.sos:
      case AlertType.rescue:
        widget.onOpenMap(alert.location);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Routing to ${alert.title}')));
        return;
      case AlertType.medical:
        _showAlertDetailsSheet(context, controller, alert);
        return;
      case AlertType.hazard:
        _showHazardInstructionsSheet(context, controller, alert);
        return;
      case AlertType.all:
        return;
    }
  }

  void _showAlertDetailsSheet(
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
                  alert.description ?? 'No additional details provided.',
                  style: const TextStyle(color: Color(0xFF5B403D), height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      controller.distanceLabelFor(alert),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      controller.timeLabelFor(alert),
                      style: const TextStyle(color: Colors.grey),
                    ),
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
          ),
        );
      },
    );
  }

  void _showHazardInstructionsSheet(
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
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hazard Safety Instructions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  alert.description ?? 'No hazard details provided.',
                  style: const TextStyle(color: Color(0xFF5B403D), height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Move to a safe distance immediately. Avoid the affected area until help arrives. Follow any local authority instructions and keep others clear of the hazard zone.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reported ${controller.timeLabelFor(alert)} at ${controller.distanceLabelFor(alert)}.',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Understood'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
