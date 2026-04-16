import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../utilities/constants.dart';

class BLEManager {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  List<ScanResult> discoveredDevices = [];

  Future<void> initializeBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) return;

    await _adapterStateSubscription?.cancel();

    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      debugPrint('Bluetooth state changed: $state');
    });

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}
    }
  }

  Future<void> startTargetedScan({
    Duration timeout = const Duration(seconds: 15),
    VoidCallback? onUpdate,
  }) async {
    discoveredDevices.clear();
    onUpdate?.call();

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 4));
    }

    final scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      var listUpdated = false;

      for (final device in results) {
        // Filter for project-specific devices matching the "HelpNode" profile
        final advData = device.advertisementData;
        final isHelpNode =
            advData.advName == kMeshDeviceName ||
            advData.manufacturerData.containsKey(kBleManufacturerId);

        if (!isHelpNode) {
          continue;
        }

        final existingIndex = discoveredDevices.indexWhere(
          (d) => d.device.remoteId == device.device.remoteId,
        );

        if (existingIndex == -1) {
          discoveredDevices.add(device);
          listUpdated = true;
        } else if (discoveredDevices[existingIndex].rssi != device.rssi) {
          discoveredDevices[existingIndex] = device;
          listUpdated = true;
        }
      }

      if (listUpdated) {
        discoveredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
        onUpdate?.call();
      }
    }, onError: (error) => debugPrint('Scan error: $error'));

    try {
      debugPrint('Starting scan...');
      await FlutterBluePlus.startScan(timeout: timeout);
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
    } catch (error) {
      debugPrint('Failed to start scan: $error');
      rethrow;
    } finally {
      await scanSubscription.cancel();
    }

    debugPrint('Scan finished. Found ${discoveredDevices.length} devices.');
  }

  void dispose() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
