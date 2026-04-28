import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:help_signal/core/alert_controller.dart';
import 'package:help_signal/core/alert_manager.dart';
import 'package:help_signal/core/location_manager.dart';
import 'package:help_signal/core/mesh_manager.dart';
import 'package:help_signal/utilities/alert_data.dart';

void main() {
  test('sendAlert waits for initialization to complete', () async {
    final alertManager = _FakeAlertManager();
    final meshManager = _FakeMeshManager();
    final controller = AlertController(
      alertManager: alertManager,
      meshManager: meshManager,
      locationManager: _FakeLocationManager(),
    );

    final result = await controller.sendAlert(AlertType.sos);

    expect(result, 'HelpSignal is still preparing device services.');
    expect(alertManager.createAlertCalls, 0);
    expect(meshManager.broadcastAlertCalls, 0);
  });

  test('initialize completes even if runtime services hang', () async {
    final controller = AlertController(
      alertManager: _HangingAlertManager(),
      meshManager: _HangingMeshManager(),
      locationManager: _HangingLocationManager(),
      startupStorageTimeout: const Duration(milliseconds: 10),
      startupLocationTimeout: const Duration(milliseconds: 10),
      meshInitializationTimeout: const Duration(milliseconds: 10),
    );

    await controller.initialize();

    expect(controller.isInitializing, isFalse);
    controller.dispose();
  });

  test(
    'refreshLocation falls back to the last stored location after timeout',
    () async {
      final controller = AlertController(
        alertManager: _FakeAlertManager(
          lastKnownLocation: const LatLng(28.6139, 77.2090),
        ),
        meshManager: _FakeMeshManager(),
        locationManager: _HangingLocationManager(),
        refreshLocationTimeout: const Duration(milliseconds: 10),
      );

      final location = await controller.refreshLocation();

      expect(location, const LatLng(28.6139, 77.2090));
      controller.dispose();
    },
  );
}

class _FakeAlertManager extends AlertManager {
  _FakeAlertManager({LatLng? lastKnownLocation})
    : _lastKnownLocationOverride = lastKnownLocation;

  int createAlertCalls = 0;
  final LatLng? _lastKnownLocationOverride;

  @override
  LatLng? get lastKnownLocation => _lastKnownLocationOverride;

  @override
  Future<void> initialize() async {}

  @override
  Future<AlertMessage> createAlert({
    required AlertType type,
    required LatLng location,
    int? descriptionCode,
  }) async {
    createAlertCalls += 1;
    return AlertMessage.create(
      type: type,
      location: location,
      senderId: 'fake-device',
      descriptionCode: descriptionCode,
    );
  }
}

class _HangingAlertManager extends _FakeAlertManager {
  @override
  Future<void> initialize() => Completer<void>().future;
}

class _FakeMeshManager extends MeshManager {
  int broadcastAlertCalls = 0;

  @override
  Future<bool> broadcastAlert(AlertMessage alert) async {
    broadcastAlertCalls += 1;
    return true;
  }
}

class _FakeLocationManager extends LocationManager {
  @override
  Future<LatLng?> getCurrentLocation() async => const LatLng(12.9716, 77.5946);
}

class _HangingLocationManager extends LocationManager {
  @override
  Future<LatLng?> getCurrentLocation() => Completer<LatLng?>().future;
}

class _HangingMeshManager extends MeshManager {
  @override
  Future<void> initialize({
    required String localSenderId,
    required MeshAlertHandler onAlertReceived,
    required MeshStateListener onStateChanged,
    Iterable<String> restoredProcessedMessageIds = const <String>[],
    List<AlertMessage> restoredPendingAlerts = const <AlertMessage>[],
    PendingAlertsPersistenceHandler? onPendingAlertsChanged,
  }) {
    return Completer<void>().future;
  }
}
