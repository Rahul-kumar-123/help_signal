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

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _header(controller),
              ),
            ),
            SliverToBoxAdapter(child: _filters()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (filteredAlerts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _emptyState(),
                ),
              )
            else
              SliverList.separated(
                itemCount: filteredAlerts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _alertCard(context, controller, filteredAlerts[i]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  Widget _header(AlertController controller) {
    return Column(
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
    );
  }

  Widget _filters() {
    final filters = AlertType.values;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final filter = filters[index];
          final isActive = activeFilter == filter;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() => activeFilter = filter),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? filter.color : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive) ...[
                      Icon(filter.icon, size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      filter.label,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No alerts here yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Send a new alert from Home or scan for nearby peers.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: Color(0xFF5B403D)),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(
    BuildContext context,
    AlertController controller,
    AlertMessage alert,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tag(alert.type),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    controller.distanceLabelFor(alert),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    controller.timeLabelFor(alert),
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
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
          const SizedBox(height: 5),
          Text(
            alert.description ?? 'No additional details provided.',
            style: TextStyle(
              color: alert.description == null ? Colors.grey.shade400 : const Color(0xFF5B403D),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip(Icons.alt_route, 'Hop ${alert.hopCount}'),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  Icons.fingerprint,
                  alert.senderId.length > 16
                      ? '${alert.senderId.substring(0, 16)}…'
                      : alert.senderId,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _actionButton(context, controller, alert),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
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
        mainAxisSize: MainAxisSize.min,
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
      child: ElevatedButton.icon(
        onPressed: () => _handleAlertAction(context, controller, alert),
        icon: Icon(alert.type.icon, size: 18),
        label: Text(alert.type.actionLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: alert.type.color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 4,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _tag(alert.type),
                  const Spacer(),
                  Text(
                    controller.timeLabelFor(alert),
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                alert.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                alert.description ?? 'No additional details provided.',
                style: const TextStyle(color: Color(0xFF5B403D), height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 16),
              _detailRow(Icons.near_me, 'Distance', controller.distanceLabelFor(alert)),
              const SizedBox(height: 8),
              _detailRow(Icons.alt_route, 'Hop Count', '${alert.hopCount} of 3 hops'),
              const SizedBox(height: 8),
              _detailRow(Icons.fingerprint, 'Sender ID', alert.senderId),
              const SizedBox(height: 8),
              _detailRow(Icons.location_on, 'Coordinates',
                  '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenMap(alert.location);
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Show on Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alert.type.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  void _showHazardInstructionsSheet(
    BuildContext context,
    AlertController controller,
    AlertMessage alert,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 4,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tag(alert.type),
              const SizedBox(height: 16),
              const Text(
                'Hazard Safety Instructions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                alert.description ?? 'No hazard details provided.',
                style: const TextStyle(color: Color(0xFF5B403D), height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text('Safety Protocol', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ]),
                    SizedBox(height: 8),
                    Text(
                      '• Move to a safe distance immediately\n'
                      '• Avoid the affected area until help arrives\n'
                      '• Follow local authority instructions\n'
                      '• Keep others clear of the hazard zone',
                      style: TextStyle(height: 1.7, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _detailRow(Icons.near_me, 'Distance', controller.distanceLabelFor(alert)),
              const SizedBox(height: 8),
              _detailRow(Icons.schedule, 'Reported', controller.timeLabelFor(alert)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Understood'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenMap(alert.location);
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Show on Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: alert.type.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF5B403D), fontSize: 13),
          ),
        ),
      ],
    );
  }
}
