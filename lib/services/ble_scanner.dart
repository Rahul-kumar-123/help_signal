import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utilities/constants.dart';

class BLEManager {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _continuousScanSubscription;
  List<ScanResult> discoveredDevices = [];
  bool _isContinuousScanning = false;
  bool _stopRequested = false;

  bool get isContinuousScanning => _isContinuousScanning;

  Future<void> initializeBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) return;

    if (!kIsWeb && Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      final allGranted = statuses.values.every((status) => status.isGranted);
      if (!allGranted) {
        throw StateError('Essential permissions were denied.');
      }
    }

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
      try {
        await FlutterBluePlus.adapterState
            .where((state) => state == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        throw StateError('Bluetooth adapter is not turned on.');
      }
    }

    final scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      var listUpdated = false;

      for (final device in results) {
        // Filter for project-specific devices matching the "HelpNode" profile
        final advData = device.advertisementData;
        final rawPayload = advData.manufacturerData[kBleManufacturerId];
        final isValidPayload = rawPayload != null && (rawPayload.length <= 1 || rawPayload.length == 19);
        final isHelpNode = advData.manufacturerData.containsKey(kBleManufacturerId) && isValidPayload;

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

  /// Starts a continuous scan loop that cycles:
  ///   scan for [scanDuration] → pause for [pauseDuration] → repeat.
  ///
  /// The [onUpdate] callback is called whenever the discovered device list
  /// changes. The loop runs until [stopContinuousScan] is called.
  Future<void> startContinuousScan({
    Duration scanDuration = kContinuousScanDuration,
    Duration pauseDuration = kContinuousScanPause,
    VoidCallback? onUpdate,
  }) async {
    if (_isContinuousScanning) {
      debugPrint('Continuous scan already running.');
      return;
    }

    _isContinuousScanning = true;
    _stopRequested = false;

    debugPrint('Starting continuous scan loop '
        '(scan ${scanDuration.inSeconds}s, pause ${pauseDuration.inSeconds}s)');

    // Ensure Bluetooth is ready
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.adapterState
            .where((state) => state == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        debugPrint('Bluetooth not available for continuous scan.');
        _isContinuousScanning = false;
        return;
      }
    }

    // Set up the persistent scan results listener
    await _continuousScanSubscription?.cancel();
    _continuousScanSubscription =
        FlutterBluePlus.onScanResults.listen((results) {
      var listUpdated = false;

      for (final device in results) {
        final advData = device.advertisementData;
        final rawPayload = advData.manufacturerData[kBleManufacturerId];
        final isValidPayload = rawPayload != null && (rawPayload.length <= 1 || rawPayload.length == 19);
        final isHelpNode = advData.manufacturerData.containsKey(kBleManufacturerId) && isValidPayload;

        if (!isHelpNode) {
          continue;
        }

        final existingIndex = discoveredDevices.indexWhere(
          (d) => d.device.remoteId == device.device.remoteId,
        );

        if (existingIndex == -1) {
          discoveredDevices.add(device);
          listUpdated = true;
        } else {
          // Always update to get fresh advertisement data (may contain new alert payload)
          discoveredDevices[existingIndex] = device;
          listUpdated = true;
        }
      }

      if (listUpdated) {
        discoveredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
        onUpdate?.call();
      }
    }, onError: (error) => debugPrint('Continuous scan error: $error'));

    // Run the scan-pause loop
    while (!_stopRequested) {
      try {
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }

        debugPrint(
            'Continuous scan cycle: scanning for ${scanDuration.inSeconds}s...');
        await FlutterBluePlus.startScan(timeout: scanDuration);

        // Wait for this scan window to complete
        await FlutterBluePlus.isScanning.where((val) => val == false).first;

        // Always fire onUpdate after each cycle so the UI reflects current reality
        onUpdate?.call();

        debugPrint('Continuous scan cycle complete. '
            'Found ${discoveredDevices.length} device(s). '
            'Pausing ${pauseDuration.inSeconds}s...');
      } catch (error) {
        debugPrint('Continuous scan cycle error: $error');
        onUpdate?.call(); // Still update UI on error
      }

      if (_stopRequested) break;

      // Pause between scan cycles
      await Future.delayed(pauseDuration);
    }

    // Cleanup
    await _continuousScanSubscription?.cancel();
    _continuousScanSubscription = null;
    _isContinuousScanning = false;
    debugPrint('Continuous scan loop stopped.');
  }

  /// Stops the continuous scan loop. The current scan cycle will finish
  /// and the loop will exit gracefully.
  Future<void> stopContinuousScan() async {
    if (!_isContinuousScanning) return;

    debugPrint('Stopping continuous scan...');
    _stopRequested = true;

    if (FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  void dispose() {
    _stopRequested = true;
    _continuousScanSubscription?.cancel();
    _continuousScanSubscription = null;
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
