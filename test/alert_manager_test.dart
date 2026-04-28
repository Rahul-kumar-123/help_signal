import 'package:flutter_test/flutter_test.dart';
import 'package:help_signal/core/alert_manager.dart';
import 'package:help_signal/services/storage_service.dart';
import 'package:help_signal/utilities/alert_data.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('initialize restores pending mesh alerts from storage', () async {
    final pendingAlert = AlertMessage.create(
      type: AlertType.sos,
      location: const LatLng(12.9716, 77.5946),
      senderId: 'device_a',
    );
    final storage = _FakeStorageService(
      initialSnapshot: StorageSnapshot(
        deviceId: 'device_a',
        pendingMeshAlerts: [pendingAlert],
      ),
    );
    final manager = AlertManager(storageService: storage);

    await manager.initialize();

    expect(manager.pendingMeshAlerts.map((alert) => alert.messageId), [
      pendingAlert.messageId,
    ]);
  });

  test('setPendingMeshAlerts persists the latest queue contents', () async {
    final storage = _FakeStorageService();
    final manager = AlertManager(storageService: storage);
    final alert = AlertMessage.create(
      type: AlertType.rescue,
      location: const LatLng(28.6139, 77.2090),
      senderId: 'device_b',
    );

    await manager.initialize();
    await manager.setPendingMeshAlerts([alert]);

    expect(storage.lastSavedSnapshot.pendingMeshAlerts.length, 1);
    expect(
      storage.lastSavedSnapshot.pendingMeshAlerts.single.messageId,
      alert.messageId,
    );
  });
}

class _FakeStorageService extends StorageService {
  _FakeStorageService({StorageSnapshot? initialSnapshot})
    : _snapshot = initialSnapshot ?? const StorageSnapshot();

  StorageSnapshot _snapshot;

  StorageSnapshot get lastSavedSnapshot => _snapshot;

  @override
  Future<StorageSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<void> saveSnapshot(StorageSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
