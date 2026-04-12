import 'package:flutter/material.dart';

import '../components/sos_area.dart';
import '../components/status_area.dart';
import '../core/alert_controller.dart';
import '../utilities/alert_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onOpenAlerts, super.key});

  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    final controller = HelpSignalScope.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusArea(
                totalCount: controller.meshState.nearbyDeviceCount,
                queueCount: controller.meshState.queuedAlertCount,
                statusMessage: controller.meshState.statusMessage,
                isScanning: controller.meshState.isScanning,
                onRefresh: () {
                  controller.refreshMesh();
                },
              ),
              SOSArea(
                isSending: controller.isSendingAlert,
                onTrigger: () {
                  _sendAlert(context, controller, AlertType.sos);
                },
              ),
              const SizedBox(height: 24),
              _locationBanner(controller),
              const SizedBox(height: 28),
              Text(
                'Specific Alerts',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ActionCard(
                    title: 'Medical',
                    type: AlertType.medical,
                    onTap: () {
                      _chooseDescription(
                        context,
                        controller,
                        AlertType.medical,
                      );
                    },
                  ),
                  ActionCard(
                    title: 'Rescue',
                    type: AlertType.rescue,
                    onTap: () {
                      _chooseDescription(context, controller, AlertType.rescue);
                    },
                  ),
                  ActionCard(
                    title: 'Hazard',
                    type: AlertType.hazard,
                    onTap: () {
                      _chooseDescription(context, controller, AlertType.hazard);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Mesh Activity',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      controller.alerts.isEmpty
                          ? 'No alerts have been stored yet. Send an alert or scan for peers to populate the feed.'
                          : '${controller.alerts.length} alert${controller.alerts.length == 1 ? '' : 's'} stored on this device. '
                                'Open the Alerts tab to review details and act on incoming requests.',
                      style: const TextStyle(
                        height: 1.45,
                        color: Color(0xFF5B403D),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonal(
                      onPressed: onOpenAlerts,
                      child: const Text('Open Alert Feed'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _locationBanner(AlertController controller) {
    final currentLocation = controller.currentLocation;
    final locationLabel = currentLocation == null
        ? 'Location unavailable'
        : '${currentLocation.latitude.toStringAsFixed(4)}, '
              '${currentLocation.longitude.toStringAsFixed(4)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Position',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  locationLabel,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDescription(
    BuildContext context,
    AlertController controller,
    AlertType type,
  ) async {
    final options = predefinedDescriptions[type] ?? const <String>[];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send ${type.label} Alert',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a quick description to include with the alert.',
                ),
                const SizedBox(height: 16),
                ...options.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(type.icon, color: type.color),
                    title: Text(entry.value),
                    onTap: () async {
                      Navigator.pop(context);
                      await _sendAlert(
                        context,
                        controller,
                        type,
                        descriptionCode: entry.key,
                      );
                    },
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.send_outlined),
                  title: const Text('Send without additional details'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _sendAlert(context, controller, type);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendAlert(
    BuildContext context,
    AlertController controller,
    AlertType type, {
    int? descriptionCode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await controller.sendAlert(
      type,
      descriptionCode: descriptionCode,
    );

    messenger.showSnackBar(SnackBar(content: Text(result)));
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.title,
    required this.type,
    required this.onTap,
    super.key,
  });

  final String title;
  final AlertType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: type.lightColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(type.icon, color: type.color, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: type.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
