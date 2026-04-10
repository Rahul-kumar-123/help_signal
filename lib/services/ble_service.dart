import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

/// Real BLE service using scanning and advertising.
class BLEService {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const int _manufacturerId = 0x1234;

  bool _advertising = false;
  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Map<String, dynamic>? _pendingAdvertisement;

  Stream<Map<String, dynamic>> get onData => _incomingController.stream;

  Future<void> startAdvertising() async {
    _advertising = true;
    await _restartAdvertising();
  }

  Future<void> _restartAdvertising() async {
    if (!_advertising) {
      return;
    }

    final payload = _pendingAdvertisement == null
        ? Uint8List.fromList([])
        : _encodeMessage(_pendingAdvertisement!);

    final advertiseData = AdvertiseData(
      includeDeviceName: false,
      manufacturerId: _manufacturerId,
      manufacturerData: payload,
    );

    await _blePeripheral.start(advertiseData: advertiseData);
  }

  Future<void> startScanning() async {
    if (_scanning) {
      return;
    }

    _scanning = true;
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 0));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        _processScanResult(result);
      }
    });
  }

  void _processScanResult(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;
    if (!manufacturerData.containsKey(_manufacturerId)) {
      return;
    }

    final rawBytes = manufacturerData[_manufacturerId];
    if (rawBytes == null || rawBytes.isEmpty) {
      return;
    }

    final decoded = _decodeMessage(Uint8List.fromList(rawBytes));
    if (decoded != null) {
      _incomingController.add(decoded);
    }
  }

  Uint8List _encodeMessage(Map<String, dynamic> message) {
    final jsonString = jsonEncode(message);
    final bytes = utf8.encode(jsonString);
    if (bytes.length <= 24) {
      return Uint8List.fromList(bytes);
    }

    final shortMessage = {
      'messageId': message['messageId'],
      'ttl': message['ttl'],
      'alert': {
        'type': message['alert']?['type'],
        'title': message['alert']?['title'],
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(shortMessage)));
  }

  Map<String, dynamic>? _decodeMessage(List<int> bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final dynamic parsed = jsonDecode(jsonString);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (_) {
      // ignore malformed advertisement payloads
    }
    return null;
  }

  Future<void> sendData(Map<String, dynamic> data) async {
    if (!_advertising) {
      return;
    }

    _pendingAdvertisement = data;
    await _restartAdvertising();
  }

  void receiveData(void Function(Map<String, dynamic>) callback) {
    _incomingController.stream.listen(callback);
  }

  Future<void> stopAdvertising() async {
    _advertising = false;
    await _blePeripheral.stop();
  }

  Future<void> stopScanning() async {
    _scanning = false;
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> dispose() async {
    await stopScanning();
    await stopAdvertising();
    await _incomingController.close();
  }
}
