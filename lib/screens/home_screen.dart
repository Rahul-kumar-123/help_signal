import 'package:flutter/material.dart';
import 'package:help_signal/components/status_area.dart';
import 'package:help_signal/components/sos_area.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            StatusArea(totalCount: 5),
            SOSArea(),
            Container(
              margin: EdgeInsets.only(top: 52.0, bottom: 8.0),
              alignment: Alignment.centerLeft,
              child: Text('Specific Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),  
            Row(
              children: [
                ActionCard(
                  title: 'Medical',
                  icon: Icons.local_hospital,
                  iconColor: Color.fromARGB(255, 0, 49, 184),
                  iconBackgroundColor: Color.fromARGB(255, 193, 220, 255),
                  textColor: Color(0xFF1E3A8A),
                  cardBackgroundColor: Color.fromARGB(255, 234, 242, 255),
                ),
                ActionCard(
                  title: 'Rescue',
                  icon: Icons.shield,
                  iconColor: Color(0xFFB45309),
                  iconBackgroundColor: Color.fromARGB(255, 255, 238, 171),
                  textColor: Color(0Xff78350F),
                  cardBackgroundColor: Color.fromARGB(255, 255, 247, 234),
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
