import 'package:flutter/material.dart';
import 'package:help_signal/components/status_area.dart';
import 'package:help_signal/components/sos_area.dart';
import 'package:help_signal/managers/alert_manager.dart';
import 'package:help_signal/managers/mesh_manager.dart';

class HomeScreen extends StatefulWidget {
  final AlertManager alertManager;
  final MeshManager meshManager;
  final bool meshActive;
  final VoidCallback onToggleMesh;

  const HomeScreen({
    super.key,
    required this.alertManager,
    required this.meshManager,
    required this.meshActive,
    required this.onToggleMesh,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            StatusArea(totalCount: widget.alertManager.alerts.length),
            const SizedBox(height: 16),
            SOSArea(),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              alignment: Alignment.centerLeft,
              child: const Text('Mesh Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onToggleMesh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.meshActive ? Colors.red : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(widget.meshActive ? 'Stop Mesh' : 'Start Mesh'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              alignment: Alignment.centerLeft,
              child: const Text('Specific Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Row(
              children: [
                ActionCard(
                  title: 'Medical',
                  icon: Icons.local_hospital,
                  iconColor: const Color.fromARGB(255, 0, 49, 184),
                  iconBackgroundColor: const Color.fromARGB(255, 193, 220, 255),
                  textColor: const Color(0xFF1E3A8A),
                  cardBackgroundColor: const Color.fromARGB(255, 234, 242, 255),
                ),
                ActionCard(
                  title: 'Rescue',
                  icon: Icons.shield,
                  iconColor: const Color(0xFFB45309),
                  iconBackgroundColor: const Color.fromARGB(255, 255, 238, 171),
                  textColor: const Color(0Xff78350F),
                  cardBackgroundColor: const Color.fromARGB(255, 255, 247, 234),
                ),
                ActionCard(
                  title: 'Hazard',
                  icon: Icons.warning,
                  iconColor: Colors.red,
                  iconBackgroundColor: const Color.fromARGB(255, 253, 207, 207),
                  textColor: const Color.fromARGB(255, 180, 9, 9),
                  cardBackgroundColor: const Color.fromARGB(255, 255, 237, 237),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.textColor,
    this.cardBackgroundColor = Colors.white,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color textColor;
  final Color cardBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: cardBackgroundColor,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
