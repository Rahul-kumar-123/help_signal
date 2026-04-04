import 'package:flutter/material.dart';

const ColorScheme kcolorScheme = ColorScheme(
  brightness: Brightness.light,

  primary: Color(0xFFD92D20),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFFDECEA),
  onPrimaryContainer: Color(0xFF410E0B),

  secondary: Color(0xFFF97316),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFFEDD5),
  onSecondaryContainer: Color(0xFF7C2D12),

  tertiary: Color(0xFF2563EB),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFDBEAFE),
  onTertiaryContainer: Color(0xFF1E3A8A),

  error: Color(0xFFB3261E),
  onError: Colors.white,
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),

  surface: Color(0xFFF4F6F8),
  onSurface: Color(0xFF0F172A),
);

const List<NavigationDestination> kNavigationDestinationList = [
  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
  NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
  NavigationDestination(icon: Icon(Icons.warning), label: 'Alerts'),
];
