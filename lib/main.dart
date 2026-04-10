import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:help_signal/screens/alert_screen.dart';
import 'package:help_signal/services/ble_service.dart';
import 'package:help_signal/services/storage_service.dart';
import 'package:help_signal/managers/alert_manager.dart';
import 'package:help_signal/managers/mesh_manager.dart';
import 'package:help_signal/utilities/alert_data.dart';
import 'screens/home_screen.dart';
import 'utilities/constants.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = StorageService();
  await storageService.init();
  runApp(MyApp(storageService: storageService));
}

class MyApp extends StatefulWidget {
  final StorageService storageService;

  const MyApp({super.key, required this.storageService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AlertManager _alertManager;
  late final BLEService _bleService;
  late final MeshManager _meshManager;

  int _selectedIndex = 0;
  LatLng? _mapInitialLocation;
  bool _meshActive = false;

  @override
  void initState() {
    super.initState();
    _alertManager = AlertManager(widget.storageService);
    _bleService = BLEService();
    _meshManager = MeshManager(
      bleService: _bleService,
      alertManager: _alertManager,
      storage: widget.storageService,
    );

    // Add listener for alerts
    _alertManager.addListener(_onAlertsChanged);

    for (final alert in alerts) {
      _alertManager.createAlert(alert);
    }

    _startMesh();
  }

  void _onAlertsChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _alertManager.removeListener(_onAlertsChanged);
    _meshManager.stop();
    _bleService.dispose();
    widget.storageService.close();
    super.dispose();
  }

  void _startMesh() {
    _meshManager.start();
    setState(() {
      _meshActive = true;
    });
  }

  void _stopMesh() {
    _meshManager.stop();
    setState(() {
      _meshActive = false;
    });
  }

  void _toggleMesh() {
    if (_meshActive) {
      _stopMesh();
    } else {
      _startMesh();
    }
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

  List<Widget> get _widgetOptions => <Widget>[
        HomeScreen(
          alertManager: _alertManager,
          meshManager: _meshManager,
          meshActive: _meshActive,
          onToggleMesh: _toggleMesh,
        ),
        MapScreen(
          initialLocation: _mapInitialLocation,
          alertManager: _alertManager,
        ),
        AlertsScreen(
          alertManager: _alertManager,
          onOpenMap: _openMap,
        ),
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
