import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:collection';
import '../services/ble_advertiser.dart';
import '../services/ble_scanner.dart';
import '../utilities/alert_data.dart';
import '../utilities/constants.dart';

enum MeshHealth { strong, weak, unstable, dead }

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

  MeshHealth get computedHealth {
    if (!bluetoothSupported || nearbyDeviceCount == 0 || lastActivityAt == null) return MeshHealth.dead;
    final diff = DateTime.now().difference(lastActivityAt!);
    if (diff.inSeconds < 10) return MeshHealth.strong;
    if (diff.inSeconds < 30) return MeshHealth.weak;
    return MeshHealth.unstable;
  }
}

typedef MeshAlertHandler = Future<bool> Function(AlertMessage alert);
typedef MeshStateListener = void Function(MeshNetworkState state);
typedef PendingAlertsPersistenceHandler =
    Future<void> Function(List<AlertMessage> pendingAlerts);

class MeshManager {
  MeshManager({
    BLEManager? scanner,
    SimpleBleAdvertiser? advertiser,
    this.maxHopCount = kMaxMeshHopCount,
    this.broadcastHoldDuration = const Duration(seconds: 6),
  }) : _scanner = scanner ?? BLEManager(),
       _advertiser = advertiser ?? SimpleBleAdvertiser();

  final BLEManager _scanner;
  final SimpleBleAdvertiser _advertiser;
  final int maxHopCount;
  final Duration broadcastHoldDuration;

  final Set<String> _processedMessages = {};
  final Queue<AlertMessage> _broadcastQueue = Queue<AlertMessage>();
  MeshNetworkState _state = const MeshNetworkState();
  StreamSubscription<BluetoothAdapterState>? _btStateSubscription;
  Timer? _watchdogTimer;
  MeshAlertHandler? _onAlertReceived;
  MeshStateListener? _onStateChanged;
  PendingAlertsPersistenceHandler? _persistPendingAlerts;
  String _localSenderId = '';
  bool _continuousDiscoveryActive = false;
  bool _isBroadcasting = false;
  int _continuousDiscoverySession = 0;

  MeshNetworkState get state => _state;

  Future<void> initialize({
    required String localSenderId,
    required MeshAlertHandler onAlertReceived,
    required MeshStateListener onStateChanged,
    Iterable<String> restoredProcessedMessageIds = const <String>[],
    List<AlertMessage> restoredPendingAlerts = const <AlertMessage>[],
    PendingAlertsPersistenceHandler? onPendingAlertsChanged,
  }) async {
    _localSenderId = localSenderId;
    _onAlertReceived = onAlertReceived;
    _onStateChanged = onStateChanged;
    _persistPendingAlerts = onPendingAlertsChanged;

    _processedMessages
      ..clear()
      ..addAll(restoredProcessedMessageIds);
    _restorePendingQueue(restoredPendingAlerts);

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

    _btStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off || state == BluetoothAdapterState.unauthorized) {
        unawaited(stopContinuousDiscovery());
        _updateState(_state.copyWith(
          bluetoothSupported: false,
          nearbyDeviceCount: 0,
          statusMessage: 'Bluetooth turned off or unauthorized',
        ));
      } else if (state == BluetoothAdapterState.on) {
        if (!_state.bluetoothSupported) {
          _updateState(_state.copyWith(bluetoothSupported: true));
          
          // Bluetooth was just enabled, restart our scanners
          unawaited(() async {
            try {
              await refreshNearbyDevices();
              startContinuousDiscovery();
              if (_broadcastQueue.isNotEmpty) {
                unawaited(_processBroadcastQueue());
              }
            } catch (_) {}
          }());
        }
      }
    });

    try {
      await _scanner.initializeBluetooth();
      
      // Try to initialize the advertiser, but don't fail the whole mesh if it's unsupported
      try {
        await _advertiser.initialize();
        // Broadcast a 1-byte payload so we are discoverable (Heartbeat). Android often drops 0-byte manufacturer payloads.
        await _advertiser.updatePayload([0]);
      } catch (e) {
        debugPrint('MeshManager: Advertising not supported or failed to start: $e');
        // We can still scan even if we can't advertise
      }

      // Do an initial one-shot scan to populate immediately
      await refreshNearbyDevices();
      // Then start continuous scanning
      startContinuousDiscovery();
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
      await stopContinuousDiscovery();
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
      unawaited(_processBroadcastQueue());
    }
  }

  /// Starts continuous background scanning that repeatedly discovers nearby
  /// nodes and processes their alert payloads. This keeps the mesh alive
  /// so new nodes are detected automatically and alerts are relayed without
  /// manual refresh.
  void startContinuousDiscovery() {
    if (_continuousDiscoveryActive || !_state.bluetoothSupported) {
      return;
    }

    final sessionId = ++_continuousDiscoverySession;
    _continuousDiscoveryActive = true;
    debugPrint('MeshManager: starting continuous discovery');

    _updateState(
      _state.copyWith(
        isScanning: false, // Keep UI spinner hidden during silent background loop
        statusMessage: 'Continuously scanning for nearby nodes',
      ),
    );

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_continuousDiscoveryActive || !_state.bluetoothSupported) return;
      
      final diff = _state.lastActivityAt == null 
           ? const Duration(seconds: 60) 
           : DateTime.now().difference(_state.lastActivityAt!);
      
      if (diff > const Duration(seconds: 30)) {
        debugPrint('MeshManager: Watchdog triggered, restarting scan loop');
        _scanner.discoveredDevices.clear();
        unawaited(() async {
          await refreshNearbyDevices();
          // Ensure we restart continuous discovery after the watchdog's targeted scan
          if (_state.bluetoothSupported) {
            startContinuousDiscovery();
          }
        }());
      }
    });

    // Fire-and-forget the continuous scan loop — it runs until stopped
    unawaited(_scanner.startContinuousScan(
      onUpdate: () {
        _handleScanUpdate();

        // Update state with current device count
        _updateState(
          _state.copyWith(
            isScanning: false,
            nearbyDeviceCount: _scanner.discoveredDevices.length,
            statusMessage: _scanner.discoveredDevices.isEmpty
                ? 'Scanning for nearby HelpSignal nodes'
                : '${_scanner.discoveredDevices.length} node(s) discovered — mesh active',
            lastActivityAt: _scanner.discoveredDevices.isNotEmpty
                ? DateTime.now()
                : _state.lastActivityAt,
          ),
        );

        // Flush pending alerts whenever we find peers
        if (_scanner.discoveredDevices.isNotEmpty) {
          unawaited(_processBroadcastQueue());
        }
      },
    ).then((_) {
      if (sessionId != _continuousDiscoverySession) {
        return;
      }

      // Loop exited (stopContinuousScan was called)
      _continuousDiscoveryActive = false;
      _updateState(
        _state.copyWith(
          isScanning: false,
          statusMessage: 'Continuous scanning stopped',
        ),
      );
    }));
  }

  /// Stops the continuous discovery loop.
  Future<void> stopContinuousDiscovery() async {
    if (!_continuousDiscoveryActive) return;
    debugPrint('MeshManager: stopping continuous discovery');
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    await _scanner.stopContinuousScan();
    _continuousDiscoveryActive = false;
  }

  Future<bool> broadcastAlert(AlertMessage alert) async {
    _processedMessages.add(alert.messageId);
    if (!_state.bluetoothSupported) {
      _enqueueBroadcast(alert, 'Bluetooth unavailable, alert queued locally');
      return false;
    }

    _enqueueBroadcast(alert, 'Alert queued for broadcast');
    return true;
  }

  Future<void> receiveAlert(AlertMessage alert) async {
    // Reject messages we originated ourselves
    if (alert.senderId == _localSenderId) return;

    // Reject if max hops exceeded
    if (alert.hopCount > maxHopCount) return;

    // Deduplicate: if we've already processed this exact messageId, skip.
    // We strictly use ONLY the messageId to prevent broadcast storms where
    // nodes bounce the same message back and forth with incrementing hop counts.
    final dedupKey = alert.messageId;
    if (_processedMessages.contains(dedupKey)) return;
    _processedMessages.add(dedupKey);

    final didStore =
        await (_onAlertReceived?.call(alert) ?? Future<bool>.value(true));
    if (!didStore) {
      return;
    }

    debugPrint('MeshManager: received alert ${alert.type.label} '
        'msgId=${alert.messageId} hop=${alert.hopCount}');

    _updateState(
      _state.copyWith(
        lastActivityAt: DateTime.now(),
        statusMessage: 'Received ${alert.type.label} alert from the mesh',
      ),
    );

    // Relay to the next hop if budget allows
    if (alert.hopCount < maxHopCount) {
      debugPrint('MeshManager: relaying alert hop ${alert.hopCount + 1}');
      _enqueueBroadcast(alert.relayed(), 'Relaying ${alert.type.label} (hop ${alert.hopCount + 1})');
    }
  }

  Future<void> relayAlert(AlertMessage alert) async {
    _enqueueBroadcast(alert, 'Relay queued for broadcast');
  }

  void dispose() {
    _btStateSubscription?.cancel();
    _watchdogTimer?.cancel();
    _scanner.dispose();
    _advertiser.dispose();
    _continuousDiscoveryActive = false;
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

    // If there are queued alerts waiting for peers, process them now
    if (_broadcastQueue.isNotEmpty) {
      unawaited(_processBroadcastQueue());
    }
  }

  void _enqueueBroadcast(AlertMessage alert, String statusMessage) {
    if (!_broadcastQueue.any((a) => a.messageId == alert.messageId)) {
      _broadcastQueue.add(alert);
      if (_broadcastQueue.length > 20) {
        _broadcastQueue.removeFirst();
      }
    }
    _updateState(_state.copyWith(
       queuedAlertCount: _broadcastQueue.length,
       statusMessage: statusMessage,
    ));
    _persistPendingQueue();
    unawaited(_processBroadcastQueue());
  }

  Future<void> _processBroadcastQueue() async {
    if (_isBroadcasting || _broadcastQueue.isEmpty || !_state.bluetoothSupported) return;

    if (_scanner.discoveredDevices.isEmpty) {
      _updateState(_state.copyWith(
        statusMessage: 'Alert queued, waiting for nearby peers to broadcast',
      ));
      return;
    }

    _isBroadcasting = true;
    final alert = _broadcastQueue.first;
    bool didPublish = false;

    try {
      didPublish = await _publishAlert(
        alert,
        statusMessage: 'Broadcasting ${alert.type.label} alert',
      );
      if (didPublish) {
        _broadcastQueue.removeFirst();
        _updateState(_state.copyWith(queuedAlertCount: _broadcastQueue.length));
        _persistPendingQueue();
        debugPrint('MeshManager: published alert ${alert.type.label} hop=${alert.hopCount}');
        if (broadcastHoldDuration > Duration.zero) {
          await Future.delayed(broadcastHoldDuration);
        }
      } else {
        _updateState(_state.copyWith(
          isAdvertising: false,
          queuedAlertCount: _broadcastQueue.length,
          statusMessage:
              'Nearby peers found, but this device could not advertise the queued alert',
        ));
      }
    } catch (e) {
      debugPrint('MeshManager: broadcast error: $e');
      _updateState(_state.copyWith(
        isAdvertising: false,
        queuedAlertCount: _broadcastQueue.length,
        statusMessage: 'Broadcast failed, alert remains queued for the mesh',
      ));
    } finally {
      _isBroadcasting = false;
    }

    // Restore heartbeat payload so this device stays discoverable after broadcasting
    try {
      await _advertiser.updatePayload([0]);
    } catch (_) {}

    if (didPublish) {
      unawaited(_processBroadcastQueue());
    }
  }

  Future<bool> _publishAlert(
    AlertMessage alert, {
    required String statusMessage,
  }) async {
    final payload = _encodeAlertBinary(alert);
    final didAdvertise = await _advertiser.updatePayload(payload);

    _updateState(
      _state.copyWith(
        isAdvertising: didAdvertise,
        lastActivityAt: DateTime.now(),
        queuedAlertCount: _broadcastQueue.length,
        statusMessage: didAdvertise
            ? statusMessage
            : 'Alert stored locally, but broadcasting is unavailable',
      ),
    );
    return didAdvertise;
  }

  List<int> _encodeAlertBinary(AlertMessage alert) {
    final bd = ByteData(19);
    // Use the raw msgId integer if it was decoded from BLE (hash_msg_NNNN...),
    // otherwise hash the original UUID. This keeps the ID stable across hops.
    final int msgIdHash;
    final existingMatch = RegExp(r'^hash_msg_(\d+)').firstMatch(alert.messageId);
    if (existingMatch != null) {
      msgIdHash = int.parse(existingMatch.group(1)!) & 0xFFFF;
    } else {
      msgIdHash = alert.messageId.hashCode & 0xFFFF;
    }

    final int senderIdHash;
    final existingSenderMatch = RegExp(r'^hash_snd_(\d+)$').firstMatch(alert.senderId);
    if (existingSenderMatch != null) {
      senderIdHash = int.parse(existingSenderMatch.group(1)!) & 0xFFFF;
    } else {
      senderIdHash = alert.senderId.hashCode & 0xFFFF;
    }

    bd.setUint16(0, msgIdHash, Endian.little);
    bd.setUint16(2, senderIdHash, Endian.little);
    bd.setUint8(4, alert.type.index);
    bd.setUint8(5, alert.hopCount);
    bd.setUint8(6, alert.descriptionCode ?? 255);
    bd.setFloat32(7, alert.latitude, Endian.little);
    bd.setFloat32(11, alert.longitude, Endian.little);
    bd.setUint32(15, (alert.timestamp ~/ 1000) & 0xFFFFFFFF, Endian.little);
    return bd.buffer.asUint8List();
  }

  AlertMessage? _decodePayload(List<int>? bytes) {
    if (bytes == null || bytes.length < 19) {
      return null;
    }

    try {
      final bd = ByteData.sublistView(Uint8List.fromList(bytes));
      final msgIdHash = bd.getUint16(0, Endian.little);
      final sIdHash = bd.getUint16(2, Endian.little);
      final typeIndex = bd.getUint8(4);
      final hopCount = bd.getUint8(5);
      final descCodeRaw = bd.getUint8(6);
      final lat = bd.getFloat32(7, Endian.little);
      final lng = bd.getFloat32(11, Endian.little);
      final ts = bd.getUint32(15, Endian.little) * 1000;

      if (sIdHash == (_localSenderId.hashCode & 0xFFFF)) {
        return null;
      }

      return AlertMessage(
        messageId: 'hash_msg_${msgIdHash}_ts_${ts}_snd_${sIdHash}',
        type: AlertType.values[typeIndex % AlertType.values.length],
        latitude: lat,
        longitude: lng,
        timestamp: ts,
        hopCount: hopCount,
        descriptionCode: descCodeRaw == 255 ? null : descCodeRaw,
        senderId: 'hash_snd_$sIdHash',
      );
    } catch (_) {
      return null;
    }
  }

  void _updateState(MeshNetworkState state) {
    _state = state;
    _onStateChanged?.call(_state);
  }

  void _restorePendingQueue(List<AlertMessage> restoredPendingAlerts) {
    final mergedQueue = <AlertMessage>[
      ...restoredPendingAlerts,
      ..._broadcastQueue,
    ];

    _broadcastQueue.clear();
    for (final alert in mergedQueue) {
      if (_broadcastQueue.any((queued) => queued.messageId == alert.messageId)) {
        continue;
      }
      _broadcastQueue.add(alert);
      if (_broadcastQueue.length > 20) {
        _broadcastQueue.removeFirst();
      }
    }

    _updateState(_state.copyWith(queuedAlertCount: _broadcastQueue.length));
    _persistPendingQueue();
  }

  void _persistPendingQueue() {
    final persistPendingAlerts = _persistPendingAlerts;
    if (persistPendingAlerts == null) {
      return;
    }

    unawaited(
      persistPendingAlerts(List<AlertMessage>.from(_broadcastQueue)),
    );
  }

  Future<bool> _safeBluetoothSupportedCheck() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }
}
