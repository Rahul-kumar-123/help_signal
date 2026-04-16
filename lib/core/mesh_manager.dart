import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_advertiser.dart';
import '../services/ble_scanner.dart';
import '../utilities/alert_data.dart';
import '../utilities/constants.dart';

class MeshNetworkState {
  final bool bluetoothSupported;
  final bool isScanning;
  final bool isAdvertising;
  final int nearbyDeviceCount;
  final int queuedAlertCount;
  final DateTime? lastActivityAt;
  final String statusMessage;

  const MeshNetworkState({
    this.bluetoothSupported = true,
    this.isScanning = false,
    this.isAdvertising = false,
    this.nearbyDeviceCount = 0,
    this.queuedAlertCount = 0,
    this.lastActivityAt,
    this.statusMessage = 'Mesh idle',
  });

  MeshNetworkState copyWith({
    bool? bluetoothSupported,
    bool? isScanning,
    bool? isAdvertising,
    int? nearbyDeviceCount,
    int? queuedAlertCount,
    DateTime? lastActivityAt,
    String? statusMessage,
  }) {
    return MeshNetworkState(
      bluetoothSupported: bluetoothSupported ?? this.bluetoothSupported,
      isScanning: isScanning ?? this.isScanning,
      isAdvertising: isAdvertising ?? this.isAdvertising,
      nearbyDeviceCount: nearbyDeviceCount ?? this.nearbyDeviceCount,
      queuedAlertCount: queuedAlertCount ?? this.queuedAlertCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

typedef MeshAlertHandler = Future<bool> Function(AlertMessage alert);
typedef MeshStateListener = void Function(MeshNetworkState state);

class MeshManager {
  MeshManager({
    BLEManager? scanner,
    SimpleBleAdvertiser? advertiser,
    this.maxHopCount = kMaxMeshHopCount,
  }) : _scanner = scanner ?? BLEManager(),
       _advertiser = advertiser ?? SimpleBleAdvertiser();

  final BLEManager _scanner;
  final SimpleBleAdvertiser _advertiser;
  final int maxHopCount;

  final Set<String> _processedMessages = {};
  final List<AlertMessage> _pendingAlerts = [];
  MeshNetworkState _state = const MeshNetworkState();
  MeshAlertHandler? _onAlertReceived;
  MeshStateListener? _onStateChanged;
  String _localSenderId = '';

  MeshNetworkState get state => _state;

  Future<void> initialize({
    required String localSenderId,
    required MeshAlertHandler onAlertReceived,
    required MeshStateListener onStateChanged,
  }) async {
    _localSenderId = localSenderId;
    _onAlertReceived = onAlertReceived;
    _onStateChanged = onStateChanged;

    final isSupported = await _safeBluetoothSupportedCheck();
    _updateState(
      _state.copyWith(
        bluetoothSupported: isSupported,
        statusMessage: isSupported
            ? 'Mesh ready for peer discovery'
            : 'Bluetooth unavailable on this device or platform',
      ),
    );

    if (!isSupported) {
      return;
    }

    try {
      await _scanner.initializeBluetooth();
      await _advertiser.initialize();
      await refreshNearbyDevices();
    } catch (_) {
      _updateState(
        _state.copyWith(
          bluetoothSupported: false,
          statusMessage: 'Mesh services are unavailable on this platform',
        ),
      );
    }
  }

  Future<void> refreshNearbyDevices() async {
    if (!_state.bluetoothSupported) {
      return;
    }

    _updateState(
      _state.copyWith(
        isScanning: true,
        statusMessage: 'Scanning for nearby HelpSignal nodes',
      ),
    );

    try {
      await _scanner.startTargetedScan(
        timeout: kMeshScanTimeout,
        onUpdate: _handleScanUpdate,
      );
    } catch (_) {
      _updateState(
        _state.copyWith(
          isScanning: false,
          statusMessage: 'Unable to complete Bluetooth scan on this device',
        ),
      );
      return;
    }

    _handleScanUpdate();
    _updateState(
      _state.copyWith(
        isScanning: false,
        statusMessage: _scanner.discoveredDevices.isEmpty
            ? 'No nearby nodes found'
            : 'Connected to nearby mesh nodes',
      ),
    );

    if (_scanner.discoveredDevices.isNotEmpty) {
      await _flushPendingAlerts();
    }
  }

  Future<void> broadcastAlert(AlertMessage alert) async {
    _processedMessages.add(alert.messageId);
    if (!_state.bluetoothSupported || _state.nearbyDeviceCount == 0) {
      _queueAlert(
        alert,
        _state.bluetoothSupported
            ? 'Alert stored until a peer is discovered'
            : 'Bluetooth unavailable, alert stored locally',
      );
      return;
    }

    await _publishAlert(
      alert,
      statusMessage: 'Broadcasting ${alert.type.label} alert',
    );
  }

  Future<void> receiveAlert(AlertMessage alert) async {
    if (alert.senderId == _localSenderId) {
      return;
    }

    if (alert.hopCount > maxHopCount ||
        _processedMessages.contains(alert.messageId)) {
      return;
    }

    _processedMessages.add(alert.messageId);
    final accepted = await _onAlertReceived?.call(alert) ?? false;
    if (!accepted) {
      return;
    }

    _updateState(
      _state.copyWith(
        lastActivityAt: DateTime.now(),
        statusMessage: 'Received ${alert.type.label} alert from the mesh',
      ),
    );

    if (alert.hopCount < maxHopCount) {
      await relayAlert(alert.relayed());
    }
  }

  Future<void> relayAlert(AlertMessage alert) async {
    if (_state.nearbyDeviceCount == 0) {
      _queueAlert(alert, 'Relay queued until another peer comes online');
      return;
    }

    await _publishAlert(
      alert,
      statusMessage:
          'Relaying ${alert.type.label} alert (hop ${alert.hopCount})',
    );
  }

  void dispose() {
    _scanner.dispose();
    _advertiser.dispose();
  }

  void _handleScanUpdate() {
    _updateState(
      _state.copyWith(
        nearbyDeviceCount: _scanner.discoveredDevices.length,
        lastActivityAt: _scanner.discoveredDevices.isEmpty
            ? _state.lastActivityAt
            : DateTime.now(),
      ),
    );

    for (final result in _scanner.discoveredDevices) {
      final rawPayload =
          result.advertisementData.manufacturerData[kBleManufacturerId];
      final alert = _decodePayload(rawPayload);
      if (alert == null) {
        continue;
      }

      unawaited(receiveAlert(alert));
    }
  }

  void _queueAlert(AlertMessage alert, String statusMessage) {
    final index = _pendingAlerts.indexWhere(
      (message) => message.messageId == alert.messageId,
    );
    if (index == -1) {
      _pendingAlerts.add(alert);
    } else {
      _pendingAlerts[index] = alert;
    }

    _updateState(
      _state.copyWith(
        queuedAlertCount: _pendingAlerts.length,
        statusMessage: statusMessage,
      ),
    );
  }

  Future<void> _flushPendingAlerts() async {
    if (_pendingAlerts.isEmpty) {
      return;
    }

    final alertsToSend = List<AlertMessage>.from(_pendingAlerts);
    _pendingAlerts.clear();

    _updateState(
      _state.copyWith(
        queuedAlertCount: 0,
        statusMessage: 'Forwarding queued alerts to nearby peers',
      ),
    );

    for (final alert in alertsToSend) {
      await _publishAlert(
        alert,
        statusMessage: 'Forwarded queued ${alert.type.label} alert',
      );
      // Wait for the alert to broadcast for a few seconds before the next one overwrites it
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<void> _publishAlert(
    AlertMessage alert, {
    required String statusMessage,
  }) async {
    final payload = utf8.encode(jsonEncode(alert.toBlePacket()));
    final didAdvertise = await _advertiser.updatePayload(payload);

    _updateState(
      _state.copyWith(
        isAdvertising: didAdvertise,
        lastActivityAt: DateTime.now(),
        queuedAlertCount: _pendingAlerts.length,
        statusMessage: didAdvertise
            ? statusMessage
            : 'Alert stored locally, but broadcasting is unavailable',
      ),
    );
  }

  AlertMessage? _decodePayload(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final alert = AlertMessage.fromJson(decoded);
      if (alert.senderId == _localSenderId) {
        return null;
      }
      return alert;
    } catch (_) {
      return null;
    }
  }

  void _updateState(MeshNetworkState state) {
    _state = state;
    _onStateChanged?.call(_state);
  }

  Future<bool> _safeBluetoothSupportedCheck() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }
}
