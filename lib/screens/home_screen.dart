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

    return AnimatedBuilder(
      animation: controller,
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
              Center(
                child: SOSArea(
                  isSending: controller.isSendingAlert,
                  onTrigger: () {
                    _sendAlert(context, controller, AlertType.sos);
                  },
                ),
              ),
              const SizedBox(height: 24),
              _locationBanner(controller),
              if (controller.lastError != null) ...[
                const SizedBox(height: 16),
                _issueBanner(controller.lastError!),
              ],
              const SizedBox(height: 28),
              Text(
                'Specific Alerts',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _specificAlertActions(context, controller),
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

  Widget _specificAlertActions(
    BuildContext context,
    AlertController controller,
  ) {
    final actions = [
      (
        title: 'Medical',
        type: AlertType.medical,
        onTap: () => _chooseDescription(context, controller, AlertType.medical),
      ),
      (
        title: 'Rescue',
        type: AlertType.rescue,
        onTap: () => _chooseDescription(context, controller, AlertType.rescue),
      ),
      (
        title: 'Hazard',
        type: AlertType.hazard,
        onTap: () => _chooseDescription(context, controller, AlertType.hazard),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 260
            ? 3
            : constraints.maxWidth >= 240
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  child: ActionCard(
                    title: action.title,
                    type: action.type,
                    onTap: action.onTap,
                  ),
                ),
              )
              .toList(),
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

  Widget _issueBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: Color(0xFFD92D20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
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

    final parentContext = context;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send ${type.label} Alert',
                    style: Theme.of(parentContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                        Navigator.pop(sheetContext);
                        await _sendAlert(
                          parentContext,
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
                      Navigator.pop(sheetContext);
                      await _sendAlert(parentContext, controller, type);
                    },
                  ),
                ],
              ),
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
    final result = await controller.sendAlert(
      type,
      descriptionCode: descriptionCode,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: type.lightColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                shape: BoxShape.circle,
              ),
              child: Icon(type.icon, color: type.color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: type.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
