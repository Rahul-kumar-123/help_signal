import 'dart:async';

import 'package:help_signal/managers/alert_manager.dart';
import 'package:help_signal/services/ble_service.dart';
import 'package:help_signal/services/storage_service.dart';
import 'package:help_signal/utilities/alert_data.dart';

/// Handles relay logic for BLE messages, including TTL and duplicate suppression.
class MeshManager {
  final BLEService bleService;
  final AlertManager alertManager;
  final StorageService storage;
  final int maxTtl;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  MeshManager({
    required this.bleService,
    required this.alertManager,
    required this.storage,
    this.maxTtl = 3,
  });

  void start() {
    bleService.startAdvertising();
    bleService.startScanning();
    _subscription = bleService.onData.listen(_handleMessage);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void broadcastAlert(AlertModel alert) {
    final message = {
      'messageId': alert.id,
      'ttl': maxTtl,
      'alert': alert.toMap(),
    };
    storage.saveProcessedMessageId(alert.id);
    bleService.sendData(message);
  }

  void _handleMessage(Map<String, dynamic> message) {
    final messageId = message['messageId'] as String?;
    if (messageId == null || storage.hasProcessedMessage(messageId)) {
      return;
    }

    storage.saveProcessedMessageId(messageId);

    final ttl = (message['ttl'] as int?) ?? maxTtl;
    if (ttl <= 0) {
      return;
    }

    final alertContent = message['alert'] as Map<String, dynamic>?;
    if (alertContent != null) {
      final alert = AlertModel.fromMap(alertContent);
      alertManager.processIncomingAlert(alert);
    }

    if (ttl > 1) {
      final relayMessage = Map<String, dynamic>.from(message);
      relayMessage['ttl'] = ttl - 1;
      bleService.sendData(relayMessage);
    }
  }
}
