import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../utilities/alert_data.dart';
import '../utilities/constants.dart';
import 'alert_manager.dart';
import 'location_manager.dart';
import 'mesh_manager.dart';

class AlertController extends ChangeNotifier {
  AlertController({
    AlertManager? alertManager,
    MeshManager? meshManager,
    LocationManager? locationManager,
  }) : _alertManager = alertManager ?? AlertManager(),
       _meshManager = meshManager ?? MeshManager(),
       _locationManager = locationManager ?? LocationManager();

  final AlertManager _alertManager;
  final MeshManager _meshManager;
  final LocationManager _locationManager;

  bool _isInitializing = true;
  bool _isSendingAlert = false;
  LatLng? _currentLocation;
  String? _lastError;
  MeshNetworkState _meshState = const MeshNetworkState();

  List<AlertMessage> get alerts => _alertManager.alerts;
  bool get isInitializing => _isInitializing;
  bool get isSendingAlert => _isSendingAlert;
  LatLng? get currentLocation =>
      _currentLocation ?? _alertManager.lastKnownLocation;
  String? get lastError => _lastError;
  MeshNetworkState get meshState => _meshState;
  String get deviceId => _alertManager.deviceId;

  Future<void> initialize() async {
    try {
      await _alertManager.initialize();
      _currentLocation =
          await _locationManager.getCurrentLocation() ??
          _alertManager.lastKnownLocation ??
          kFallbackMapCenter;
      await _alertManager.updateLastKnownLocation(_currentLocation);

      await _meshManager.initialize(
        localSenderId: deviceId,
        onAlertReceived: _handleIncomingAlert,
        onStateChanged: _handleMeshStateChanged,
      );
    } catch (error) {
      _lastError = error.toString();
      _currentLocation ??= kFallbackMapCenter;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<String> sendAlert(AlertType type, {int? descriptionCode}) async {
    if (_isSendingAlert) {
      return 'Another alert is already being prepared.';
    }

    _isSendingAlert = true;
    _lastError = null;
    notifyListeners();

    try {
      final location = await refreshLocation();
      if (location == null) {
        throw StateError('Location is required to create an alert.');
      }

      final alert = await _alertManager.createAlert(
        type: type,
        location: location,
        descriptionCode: descriptionCode,
      );
      await _meshManager.broadcastAlert(alert);
      notifyListeners();
      return _meshState.nearbyDeviceCount == 0
          ? '${type.label} alert saved and queued for relay.'
          : '${type.label} alert broadcast to nearby nodes.';
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
      return 'Unable to send alert right now.';
    } finally {
      _isSendingAlert = false;
      notifyListeners();
    }
  }

  Future<LatLng?> refreshLocation() async {
    final location =
        await _locationManager.getCurrentLocation() ??
        _alertManager.lastKnownLocation;
    if (location != null) {
      _currentLocation = location;
      await _alertManager.updateLastKnownLocation(location);
      notifyListeners();
    }
    return location;
  }

  Future<void> refreshMesh() async {
    await _meshManager.refreshNearbyDevices();
    notifyListeners();
  }

  List<AlertMessage> alertsFor(AlertType type) {
    if (type == AlertType.all) {
      return alerts;
    }

    return alerts.where((alert) => alert.type == type).toList();
  }

  String distanceLabelFor(AlertMessage alert) {
    final userLocation = currentLocation;
    if (userLocation == null) {
      return 'Location unavailable';
    }

    final distance = _locationManager.calculateDistance(
      userLocation,
      alert.location,
    );
    return _locationManager.formatDistance(distance);
  }

  String timeLabelFor(AlertMessage alert) =>
      formatRelativeTime(alert.createdAt);

  @override
  void dispose() {
    _meshManager.dispose();
    super.dispose();
  }

  Future<bool> _handleIncomingAlert(AlertMessage alert) async {
    final didStore = await _alertManager.processIncomingAlert(alert);
    if (didStore) {
      notifyListeners();
    }
    return didStore;
  }

  void _handleMeshStateChanged(MeshNetworkState state) {
    _meshState = state;
    notifyListeners();
  }
}

class HelpSignalScope extends InheritedNotifier<AlertController> {
  const HelpSignalScope({
    required AlertController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AlertController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HelpSignalScope>();
    assert(scope != null, 'HelpSignalScope not found in widget tree.');
    return scope!.notifier!;
  }
}
