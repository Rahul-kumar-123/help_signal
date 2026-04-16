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
  const MyApp({super.key, this.controller});

  final AlertController? controller;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AlertController _controller;
  late final bool _ownsController;
  int _selectedIndex = 0;
  LatLng? _mapInitialLocation;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AlertController();
    _controller.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
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
        home: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final isInitializing = _controller.isInitializing;

            return Scaffold(
              appBar: AppBar(
                backgroundColor: kcolorScheme.primary,
                foregroundColor: kcolorScheme.onPrimary,
                title: const Text(
                  'HelpSignal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  _AlertsActionButton(
                    count: _controller.alerts.length,
                    onPressed: isInitializing ? null : () => _onItemTapped(2),
                  ),
                ],
              ),
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: isInitializing
                    ? _AppLoadingState(lastError: _controller.lastError)
                    : IndexedStack(
                        key: const ValueKey('app_content'),
                        index: _selectedIndex,
                        children: [
                          HomeScreen(onOpenAlerts: () => _onItemTapped(2)),
                          MapScreen(initialLocation: _mapInitialLocation),
                          AlertsScreen(onOpenMap: _openMap),
                        ],
                      ),
              ),
              bottomNavigationBar: NavigationBar(
                indicatorColor: const Color(0xFFFBD5D1),
                selectedIndex: _selectedIndex,
                backgroundColor: const Color(0xFFF4F1F0),
                onDestinationSelected: isInitializing ? null : _onItemTapped,
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
            );
          },
        ),
      ),
    );
  }
}

class _AlertsActionButton extends StatelessWidget {
  const _AlertsActionButton({required this.count, this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Open alerts',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_active_outlined, size: 28),
          if (count > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ),
    );
  }
}

class _AppLoadingState extends StatelessWidget {
  const _AppLoadingState({this.lastError});

  final String? lastError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      key: const ValueKey('app_loading'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Preparing local safety tools',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              lastError == null
                  ? 'Loading saved alerts, checking location access, and bringing the mesh online.'
                  : 'Startup hit a device limitation. HelpSignal will continue with reduced capabilities where possible.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
