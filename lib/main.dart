import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:help_signal/screens/alert_screen.dart';
import 'screens/home_screen.dart';
import 'utilities/constants.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  LatLng? _mapInitialLocation;

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

  List<Widget> get _widgetOptions => <Widget>[
        HomeScreen(),
        MapScreen(initialLocation: _mapInitialLocation),
        AlertsScreen(onOpenMap: _openMap),
      ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HelpSignal',
      home: Theme(
        data: ThemeData(colorScheme: kcolorScheme),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'HelpSignal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Icon(Icons.notifications, size: 28.0),
              ],
            ),
          ),
          body: _widgetOptions.elementAt(_selectedIndex),
          bottomNavigationBar: NavigationBar(
            indicatorColor: Color.fromARGB(255, 255, 189, 194),
            surfaceTintColor: const Color.fromARGB(77, 143, 143, 143),
            selectedIndex: _selectedIndex,
            backgroundColor: const Color.fromARGB(255, 234, 234, 234),
            onDestinationSelected: _onItemTapped,
            destinations: [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home', selectedIcon: Icon(Icons.home)),
              NavigationDestination(icon: Icon(Icons.map), label: 'Map', selectedIcon: Icon(Icons.map)),
              NavigationDestination(icon: Icon(Icons.warning), label: 'Alerts', selectedIcon: Icon(Icons.warning)),
            ],
          ),
        ),
      ),
    );
  }
}
