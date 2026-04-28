import 'package:latlong2/latlong.dart';

import '../services/storage_service.dart';
import '../utilities/alert_data.dart';

class AlertManager {
  AlertManager({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  final StorageService _storageService;
  final List<AlertMessage> _alerts = [];
  final List<AlertMessage> _pendingMeshAlerts = [];
  final Set<String> _seenMessageIds = {};
  String? _deviceId;
  LatLng? _lastKnownLocation;

  List<AlertMessage> get alerts => List.unmodifiable(_alerts);
  List<AlertMessage> get pendingMeshAlerts =>
      List.unmodifiable(_pendingMeshAlerts);
  Set<String> get seenMessageIds => Set.unmodifiable(_seenMessageIds);
  String get deviceId => _deviceId ?? 'device-uninitialized';
  LatLng? get lastKnownLocation => _lastKnownLocation;

  Future<void> initialize() async {
    final snapshot = await _storageService.loadSnapshot();

    _deviceId = snapshot.deviceId ?? _generateDeviceId();
    _lastKnownLocation = snapshot.lastKnownLocation;

    _alerts
      ..clear()
      ..addAll(snapshot.alerts);

    _pendingMeshAlerts
      ..clear()
      ..addAll(_dedupePendingMeshAlerts(snapshot.pendingMeshAlerts));

    _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _seenMessageIds
      ..clear()
      ..addAll(snapshot.seenMessageIds)
      ..addAll(_alerts.map((alert) => alert.messageId));

    await _persist();
  }

  bool isDuplicate(String messageId) => _seenMessageIds.contains(messageId);

  Future<AlertMessage> createAlert({
    required AlertType type,
    required LatLng location,
    int? descriptionCode,
  }) async {
    final alert = AlertMessage.create(
      type: type,
      location: location,
      senderId: deviceId,
      descriptionCode: descriptionCode,
    );
    await storeAlert(alert);
    return alert;
  }

  Future<bool> processIncomingAlert(AlertMessage alert) async {
    return storeAlert(alert);
  }

  Future<bool> storeAlert(AlertMessage alert) async {
    if (isDuplicate(alert.messageId)) {
      return false;
    }

    _seenMessageIds.add(alert.messageId);
    _alerts.add(alert);
    _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _persist();
    return true;
  }

  Future<void> updateLastKnownLocation(LatLng? location) async {
    if (location == null) {
      return;
    }

    _lastKnownLocation = location;
    await _persist();
  }

  Future<void> setPendingMeshAlerts(List<AlertMessage> alerts) async {
    _pendingMeshAlerts
      ..clear()
      ..addAll(_dedupePendingMeshAlerts(alerts));
    await _persist();
  }

  Future<void> _persist() {
    return _storageService.saveSnapshot(
      StorageSnapshot(
        deviceId: _deviceId,
        alerts: List<AlertMessage>.from(_alerts),
        pendingMeshAlerts: List<AlertMessage>.from(_pendingMeshAlerts),
        seenMessageIds: Set<String>.from(_seenMessageIds),
        lastKnownLocation: _lastKnownLocation,
      ),
    );
  }

  List<AlertMessage> _dedupePendingMeshAlerts(Iterable<AlertMessage> alerts) {
    final uniqueIds = <String>{};
    final deduped = <AlertMessage>[];

    for (final alert in alerts) {
      if (uniqueIds.add(alert.messageId)) {
        deduped.add(alert);
      }
    }

    return deduped;
  }

  String _generateDeviceId() {
    final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return 'device_$seed';
  }
}
