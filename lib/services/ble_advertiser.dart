import 'package:flutter/foundation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart'
    as ble_peripheral;

import '../utilities/constants.dart';

class SimpleBleAdvertiser {
  ble_peripheral.PeripheralManager? _peripheralManager;

  bool isAdvertising = false;
  String deviceName = kMeshDeviceName;

  Future<void> initialize() async {
    try {
      _peripheralManager ??= ble_peripheral.PeripheralManager();
      await _peripheralManager!.authorize();
      debugPrint('Broadcaster initialized.');
    } catch (error) {
      debugPrint('Failed to initialize broadcaster: $error');
    }
  }

  Future<bool> startAdvertising(List<int> payload) async {
    if (isAdvertising) {
      return true;
    }
    if (_peripheralManager == null) {
      return false;
    }

    final manufacturerData = ble_peripheral.ManufacturerSpecificData(
      id: kBleManufacturerId,
      data: Uint8List.fromList(payload),
    );

    final advertisement = ble_peripheral.Advertisement(
      name: deviceName,
      manufacturerSpecificData: [manufacturerData],
    );

    try {
      await _peripheralManager!.startAdvertising(advertisement);
      isAdvertising = true;
      debugPrint('Started broadcasting payload (${payload.length} bytes).');
      return true;
    } catch (error) {
      isAdvertising = false;
      debugPrint('Failed to start broadcasting: $error');
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    if (!isAdvertising || _peripheralManager == null) {
      return;
    }

    try {
      await _peripheralManager!.stopAdvertising();
      isAdvertising = false;
      debugPrint('Stopped broadcasting.');
    } catch (error) {
      debugPrint('Failed to stop broadcasting: $error');
    }
  }

  Future<bool> updatePayload(List<int> newPayload) async {
    await stopAdvertising();
    return startAdvertising(newPayload);
  }

  void dispose() {
    stopAdvertising();
  }
}
