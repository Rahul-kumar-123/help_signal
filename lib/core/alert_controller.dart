import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../utilities/alert_data.dart';
import 'alert_manager.dart';
import 'location_manager.dart';
import 'mesh_manager.dart';

class AlertController extends ChangeNotifier {
  AlertController({
    AlertManager? alertManager,
    MeshManager? meshManager,
    LocationManager? locationManager,
    Duration startupStorageTimeout = const Duration(seconds: 4),
    Duration startupLocationTimeout = const Duration(seconds: 6),
    Duration refreshLocationTimeout = const Duration(seconds: 8),
    Duration meshInitializationTimeout = const Duration(seconds: 30),
  }) : _alertManager = alertManager ?? AlertManager(),
       _meshManager = meshManager ?? MeshManager(),
       _locationManager = locationManager ?? LocationManager(),
       _startupStorageTimeout = startupStorageTimeout,
       _startupLocationTimeout = startupLocationTimeout,
       _refreshLocationTimeout = refreshLocationTimeout,
       _meshInitializationTimeout = meshInitializationTimeout;

  final AlertManager _alertManager;
  final MeshManager _meshManager;
  final LocationManager _locationManager;
  final Duration _startupStorageTimeout;
  final Duration _startupLocationTimeout;
  final Duration _refreshLocationTimeout;
  final Duration _meshInitializationTimeout;

  bool _isInitializing = true;
  bool _isSendingAlert = false;
  bool _isDisposed = false;
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
      await _alertManager.initialize().timeout(_startupStorageTimeout);
      _currentLocation = _alertManager.lastKnownLocation;
    } on TimeoutException {
      _lastError =
          'Loading saved alerts is taking too long. HelpSignal will continue with fresh local state.';
    } catch (error) {
      _recordError(error, fallbackMessage: 'Unable to load saved alerts.');
      _currentLocation ??= _alertManager.lastKnownLocation;
    } finally {
      _isInitializing = false;
      _notifySafely();
    }

    if (_isDisposed) {
      return;
    }

    unawaited(_warmUpLocation());
    unawaited(_initializeMeshInBackground());
  }

  Future<String> sendAlert(AlertType type, {int? descriptionCode}) async {
    if (_isInitializing) {
      return 'HelpSignal is still preparing device services.';
    }

    if (_isSendingAlert) {
      return 'Another alert is already being prepared.';
    }

    _isSendingAlert = true;
    _lastError = null;
    _notifySafely();

    try {
      final location = await refreshLocation();
      if (location == null) {
        _isSendingAlert = false;
        _notifySafely();
        return 'Location unavailable — cannot pin alert to map. Please enable GPS.';
      }

      final alert = await _alertManager.createAlert(
        type: type,
        location: location,
        descriptionCode: descriptionCode,
      );
      final broadcastSuccess = await _meshManager.broadcastAlert(alert);
      _notifySafely();
      return broadcastSuccess
          ? '${type.label} alert saved and broadcast successfully.'
          : '${type.label} alert saved locally, but Bluetooth broadcast failed.';
    } catch (error) {
      _recordError(error, fallbackMessage: 'Unable to send alert right now.');
      _notifySafely();
      return 'Unable to send alert right now.';
    } finally {
      _isSendingAlert = false;
      _notifySafely();
    }
  }

  Future<LatLng?> refreshLocation() async {
    final location =
        await _readCurrentLocation(
          timeout: _refreshLocationTimeout,
          timeoutMessage:
              'Location lookup timed out. Last known coordinates will be used when available.',
        ) ??
        _alertManager.lastKnownLocation;
    if (location != null) {
      _currentLocation = location;
      await _alertManager.updateLastKnownLocation(location);
      _notifySafely();
    }
    return location;
  }

  Future<void> refreshMesh() async {
    if (_isInitializing) {
      return;
    }

    // Stop continuous scanning, do a fresh one-shot scan, then restart continuous
    await _meshManager.stopContinuousDiscovery();
    await _meshManager.refreshNearbyDevices();
    _meshManager.startContinuousDiscovery();
    _notifySafely();
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
    _isDisposed = true;
    _meshManager.stopContinuousDiscovery();
    _meshManager.dispose();
    super.dispose();
  }

  Future<bool> _handleIncomingAlert(AlertMessage alert) async {
    final didStore = await _alertManager.processIncomingAlert(alert);
    if (didStore) {
      _notifySafely();
    }
    return didStore;
  }

  void _handleMeshStateChanged(MeshNetworkState state) {
    _meshState = state;
    _notifySafely();
  }

  Future<void> _warmUpLocation() async {
    final location = await _readCurrentLocation(
      timeout: _startupLocationTimeout,
      timeoutMessage:
          'Live location is taking too long to load. The app will keep working and update when coordinates are available.',
    );

    if (location == null) {
      _notifySafely();
      return;
    }

    _currentLocation = location;
    await _alertManager.updateLastKnownLocation(location);
    _notifySafely();
  }

  Future<void> _initializeMeshInBackground() async {
    try {
      await _meshManager
          .initialize(
            localSenderId: deviceId,
            onAlertReceived: _handleIncomingAlert,
            onStateChanged: _handleMeshStateChanged,
          )
          .timeout(_meshInitializationTimeout);
    } on TimeoutException {
      _meshState = _meshState.copyWith(
        isScanning: false,
        isAdvertising: false,
        statusMessage:
            'Mesh startup is taking longer than expected. Local alerts are still available.',
      );
      _notifySafely();
    } catch (error) {
      _recordError(
        error,
        fallbackMessage: 'Mesh services are unavailable right now.',
        overwrite: false,
      );
      _meshState = _meshState.copyWith(
        isScanning: false,
        isAdvertising: false,
        statusMessage: 'Mesh services are unavailable right now.',
      );
      _notifySafely();
    }
  }

  Future<LatLng?> _readCurrentLocation({
    required Duration timeout,
    required String timeoutMessage,
  }) async {
    try {
      return await _locationManager.getCurrentLocation().timeout(timeout);
    } on TimeoutException {
      if (_currentLocation == null && _alertManager.lastKnownLocation == null) {
        _lastError = timeoutMessage;
      }
      return null;
    } catch (error) {
      _recordError(
        error,
        fallbackMessage: 'Unable to determine the current location.',
        overwrite: false,
      );
      return null;
    }
  }

  void _recordError(
    Object error, {
    String? fallbackMessage,
    bool overwrite = true,
  }) {
    final message = error.toString().trim();
    if (!overwrite && _lastError != null) {
      return;
    }

    _lastError = message.isEmpty ? fallbackMessage : message;
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
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
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'HelpSignalScope not found in the widget tree. '
        'Wrap the app with HelpSignalScope before reading the controller.',
      );
    }
    return notifier;
  }
}
