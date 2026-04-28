import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help_signal/core/mesh_manager.dart';
import 'package:help_signal/services/ble_advertiser.dart';
import 'package:help_signal/services/ble_scanner.dart';
import 'package:help_signal/utilities/alert_data.dart';
import 'package:help_signal/utilities/constants.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('queued alert is broadcast when refresh discovers a nearby peer', () async {
    final scanner = _FakeBleManager(
      targetedDevices: [_peerResult()],
    );
    final advertiser = _FakeAdvertiser();
    final meshManager = MeshManager(
      scanner: scanner,
      advertiser: advertiser,
      broadcastHoldDuration: Duration.zero,
    );

    await meshManager.broadcastAlert(_sampleAlert());

    expect(meshManager.state.queuedAlertCount, 1);

    await meshManager.refreshNearbyDevices();
    await _settleAsyncMeshWork();

    expect(meshManager.state.queuedAlertCount, 0);
    expect(advertiser.payloads.where((payload) => payload.length == 19), hasLength(1));
  });

  test('failed broadcast stays queued for the next discovery attempt', () async {
    final scanner = _FakeBleManager(
      targetedDevices: [_peerResult()],
    );
    final advertiser = _FakeAdvertiser(
      outcomes: <Object>[StateError('advertiser unavailable'), true],
    );
    final meshManager = MeshManager(
      scanner: scanner,
      advertiser: advertiser,
      broadcastHoldDuration: Duration.zero,
    );

    await meshManager.broadcastAlert(_sampleAlert());
    await meshManager.refreshNearbyDevices();
    await _settleAsyncMeshWork();

    expect(meshManager.state.queuedAlertCount, 1);

    await meshManager.refreshNearbyDevices();
    await _settleAsyncMeshWork();

    expect(meshManager.state.queuedAlertCount, 0);
    expect(advertiser.payloads.where((payload) => payload.length == 19), hasLength(2));
  });
}

class _FakeBleManager extends BLEManager {
  _FakeBleManager({List<ScanResult>? targetedDevices})
    : _targetedDevices = targetedDevices ?? const [];

  final List<ScanResult> _targetedDevices;

  @override
  Future<void> initializeBluetooth() async {}

  @override
  Future<void> startTargetedScan({
    Duration timeout = const Duration(seconds: 15),
    VoidCallback? onUpdate,
  }) async {
    discoveredDevices = List<ScanResult>.from(_targetedDevices);
  }
}

class _FakeAdvertiser extends SimpleBleAdvertiser {
  _FakeAdvertiser({List<Object>? outcomes}) : _outcomes = outcomes ?? const [];

  final List<Object> _outcomes;
  final List<List<int>> payloads = [];
  int _nextOutcomeIndex = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> updatePayload(List<int> newPayload) async {
    payloads.add(List<int>.from(newPayload));

    if (_nextOutcomeIndex >= _outcomes.length) {
      return true;
    }

    final outcome = _outcomes[_nextOutcomeIndex++];
    if (outcome is bool) {
      return outcome;
    }

    throw outcome;
  }
}

AlertMessage _sampleAlert() {
  return AlertMessage.create(
    type: AlertType.sos,
    location: const LatLng(12.9716, 77.5946),
    senderId: 'device_a',
  );
}

ScanResult _peerResult() {
  return ScanResult(
    device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
    advertisementData: AdvertisementData(
      advName: kMeshDeviceName,
      txPowerLevel: null,
      appearance: null,
      connectable: false,
      manufacturerData: {
        kBleManufacturerId: [0],
      },
      serviceData: const {},
      serviceUuids: const [],
    ),
    rssi: -42,
    timeStamp: DateTime.now(),
  );
}

Future<void> _settleAsyncMeshWork() {
  return Future<void>.delayed(const Duration(milliseconds: 20));
}
