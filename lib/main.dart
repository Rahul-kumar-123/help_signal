import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utilities/constants.dart';

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

  static final List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    const Text('Map Page'),
    const Text('Alerts Page'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HelpSignal',
      home: Theme(
        data: ThemeData(colorScheme: kcolorScheme),
        child: Scaffold(
          appBar: AppBar(title: const Text('HelpSignal')),
          body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: kNavigationDestinationList,
          ),
        ),
      ),
    );
  }
}
