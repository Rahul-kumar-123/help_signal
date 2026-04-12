import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'core/alert_controller.dart';
import 'screens/alert_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'utilities/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AlertController _controller;
  int _selectedIndex = 0;
  LatLng? _mapInitialLocation;

  @override
  void initState() {
    super.initState();
    _controller = AlertController()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openMap(LatLng? initialLocation) {
    setState(() {
      _mapInitialLocation = initialLocation;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HelpSignalScope(
      controller: _controller,
      child: MaterialApp(
        title: 'HelpSignal',
        theme: ThemeData(colorScheme: kcolorScheme, useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(
            backgroundColor: Color.fromARGB(255, 32, 94, 217),
            foregroundColor: kcolorScheme.onPrimary,
            title: const Text(
              'HelpSignal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  final count = _controller.alerts.length;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          size: 28,
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 10,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: kcolorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              HomeScreen(onOpenAlerts: () => _onItemTapped(2)),
              MapScreen(initialLocation: _mapInitialLocation),
              AlertsScreen(onOpenMap: _openMap),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            indicatorColor: const Color(0xFFFBD5D1),
            selectedIndex: _selectedIndex,
            backgroundColor: const Color(0xFFF4F1F0),
            onDestinationSelected: _onItemTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.warning_amber_outlined),
                selectedIcon: Icon(Icons.warning),
                label: 'Alerts',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
