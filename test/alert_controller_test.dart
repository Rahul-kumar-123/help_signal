import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:help_signal/core/alert_controller.dart';
import 'package:help_signal/core/alert_manager.dart';
import 'package:help_signal/core/location_manager.dart';
import 'package:help_signal/core/mesh_manager.dart';
import 'package:help_signal/services/app_foreground_service.dart';
import 'package:help_signal/services/offline_map_cache_service.dart';
import 'package:help_signal/utilities/alert_data.dart';

void main() {
  test('sendAlert waits for initialization to complete', () async {
    final alertManager = _FakeAlertManager();
    final meshManager = _FakeMeshManager();
    final controller = AlertController(
      alertManager: alertManager,
      meshManager: meshManager,
      locationManager: _FakeLocationManager(),
      offlineMapCacheService: _FakeOfflineMapCacheService(),
      foregroundService: _FakeAppForegroundService(),
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
      offlineMapCacheService: _FakeOfflineMapCacheService(),
      foregroundService: _FakeAppForegroundService(),
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
        offlineMapCacheService: _FakeOfflineMapCacheService(),
        foregroundService: _FakeAppForegroundService(),
        refreshLocationTimeout: const Duration(milliseconds: 10),
      );

      final location = await controller.refreshLocation();

      expect(location, const LatLng(28.6139, 77.2090));
      controller.dispose();
    },
  );

  test('refreshLocation starts offline map caching in the background', () async {
    final offlineMapCacheService = _FakeOfflineMapCacheService();
    final controller = AlertController(
      alertManager: _FakeAlertManager(),
      meshManager: _FakeMeshManager(),
      locationManager: _FakeLocationManager(),
      offlineMapCacheService: offlineMapCacheService,
      foregroundService: _FakeAppForegroundService(),
    );

    final location = await controller.refreshLocation();

    expect(location, const LatLng(12.9716, 77.5946));
    expect(
      offlineMapCacheService.cachedLocations,
      contains(const LatLng(12.9716, 77.5946)),
    );
    controller.dispose();
  });

  test('initialize starts the Android foreground service bridge', () async {
    final foregroundService = _FakeAppForegroundService();
    final controller = AlertController(
      alertManager: _FakeAlertManager(),
      meshManager: _FakeMeshManager(),
      locationManager: _FakeLocationManager(),
      offlineMapCacheService: _FakeOfflineMapCacheService(),
      foregroundService: foregroundService,
    );

    await controller.initialize();

    expect(foregroundService.startCalls, 1);
    expect(foregroundService.lastTitle, isNotEmpty);
    expect(foregroundService.lastMessage, isNotEmpty);
    controller.dispose();
  });
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

class _FakeOfflineMapCacheService extends OfflineMapCacheService {
  final List<LatLng> cachedLocations = <LatLng>[];

  @override
  Future<void> cacheAreaAround(LatLng center) async {
    cachedLocations.add(center);
  }

  @override
  void dispose() {}
}

class _FakeAppForegroundService implements AppForegroundService {
  int startCalls = 0;
  int updateCalls = 0;
  int stopCalls = 0;
  String? lastTitle;
  String? lastMessage;

  @override
  Future<void> start({
    required String title,
    required String message,
  }) async {
    startCalls += 1;
    lastTitle = title;
    lastMessage = message;
  }

  @override
  Future<void> update({
    required String title,
    required String message,
  }) async {
    updateCalls += 1;
    lastTitle = title;
    lastMessage = message;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}
