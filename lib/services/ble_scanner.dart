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
  final Map<String, DateTime> _deviceLastSeen = {};
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

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationGranted = statuses[Permission.location]?.isGranted ?? false;
      final locationRequired = _requiresLocationForAndroidBleScan;

      if (!scanGranted || !connectGranted || (locationRequired && !locationGranted)) {
        throw StateError(
          locationRequired
              ? 'Bluetooth scan permissions or required location access were denied.'
              : 'Bluetooth scan permissions were denied.',
        );
      }

      if (!(statuses[Permission.bluetoothAdvertise]?.isGranted ?? false)) {
        debugPrint(
          'BLEManager: advertise permission not granted; scanning can continue, '
          'but this device may not be able to relay alerts.',
        );
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
    _deviceLastSeen.clear();
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
        } else {
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
      await FlutterBluePlus.startScan(
        timeout: timeout,
        continuousUpdates: true,
        androidUsesFineLocation: _requiresLocationForAndroidBleScan,
        androidCheckLocationServices: _requiresLocationForAndroidBleScan,
      );
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
        
        _deviceLastSeen[device.device.remoteId.str] = DateTime.now();
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
        await FlutterBluePlus.startScan(
          timeout: scanDuration,
          continuousUpdates: true,
          androidUsesFineLocation: _requiresLocationForAndroidBleScan,
          androidCheckLocationServices: _requiresLocationForAndroidBleScan,
        );

        // Wait for this scan window to complete
        await FlutterBluePlus.isScanning.where((val) => val == false).first;

        // Purge devices not seen recently (older than scan + pause duration + buffer)
        final now = DateTime.now();
        final staleThreshold = scanDuration + pauseDuration + const Duration(seconds: 5);
        final initialCount = discoveredDevices.length;
        
        discoveredDevices.removeWhere((d) {
          final lastSeen = _deviceLastSeen[d.device.remoteId.str];
          return lastSeen == null || now.difference(lastSeen) > staleThreshold;
        });
        
        if (discoveredDevices.length != initialCount) {
          debugPrint('Purged ${initialCount - discoveredDevices.length} stale device(s).');
        }

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

      // Pause between scan cycles (interruptible)
      final pauseSteps = pauseDuration.inMilliseconds ~/ 100;
      for (int i = 0; i < pauseSteps; i++) {
        if (_stopRequested) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Cleanup
    await _continuousScanSubscription?.cancel();
    _continuousScanSubscription = null;
    _isContinuousScanning = false;
    debugPrint('Continuous scan loop stopped.');
  }

  Future<void> stopContinuousScan() async {
    if (!_isContinuousScanning) return;

    debugPrint('Stopping continuous scan...');
    _stopRequested = true;

    if (FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }

    // Wait for the loop to gracefully exit before returning
    while (_isContinuousScanning) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void dispose() {
    _stopRequested = true;
    _continuousScanSubscription?.cancel();
    _continuousScanSubscription = null;
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }

  bool get _requiresLocationForAndroidBleScan {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    final sdkMatch = RegExp(r'SDK\s+(\d+)').firstMatch(
      Platform.operatingSystemVersion,
    );
    final sdkVersion = sdkMatch == null ? null : int.tryParse(sdkMatch.group(1)!);
    return sdkVersion != null && sdkVersion <= 30;
  }
}
