import 'package:flutter/foundation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart'
    as ble_peripheral;

class SimpleBleAdvertiser {
  ble_peripheral.PeripheralManager? _peripheralManager;

  bool isAdvertising = false;
  String deviceName = 'HelpNode';

  Future<void> initialize() async {
    try {
      _peripheralManager ??= ble_peripheral.PeripheralManager();
      await _peripheralManager!.authorize();
      debugPrint('Broadcaster initialized.');
    } catch (error) {
      debugPrint('Failed to initialize broadcaster: $error');
    }
  }

  Future<void> startAdvertising(List<int> payload) async {
    if (isAdvertising) return;
    if (_peripheralManager == null) return;

    final manufacturerData = ble_peripheral.ManufacturerSpecificData(
      id: 0xFFFF,
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
    } catch (error) {
      debugPrint('Failed to start broadcasting: $error');
    }
  }

  Future<void> stopAdvertising() async {
    if (!isAdvertising) return;
    if (_peripheralManager == null) return;

    try {
      await _peripheralManager!.stopAdvertising();
      isAdvertising = false;
      debugPrint('Stopped broadcasting.');
    } catch (error) {
      debugPrint('Failed to stop broadcasting: $error');
    }
  }

  Future<void> updatePayload(List<int> newPayload) async {
    await stopAdvertising();
    await startAdvertising(newPayload);
  }

  void dispose() {
    stopAdvertising();
  }
}
