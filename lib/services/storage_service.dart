import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../utilities/alert_data.dart';

class StorageSnapshot {
  final String? deviceId;
  final List<AlertMessage> alerts;
  final List<AlertMessage> pendingMeshAlerts;
  final Set<String> seenMessageIds;
  final LatLng? lastKnownLocation;

  const StorageSnapshot({
    this.deviceId,
    this.alerts = const [],
    this.pendingMeshAlerts = const [],
    this.seenMessageIds = const <String>{},
    this.lastKnownLocation,
  });

  StorageSnapshot copyWith({
    String? deviceId,
    List<AlertMessage>? alerts,
    List<AlertMessage>? pendingMeshAlerts,
    Set<String>? seenMessageIds,
    LatLng? lastKnownLocation,
    bool clearLastKnownLocation = false,
  }) {
    return StorageSnapshot(
      deviceId: deviceId ?? this.deviceId,
      alerts: alerts ?? this.alerts,
      pendingMeshAlerts: pendingMeshAlerts ?? this.pendingMeshAlerts,
      seenMessageIds: seenMessageIds ?? this.seenMessageIds,
      lastKnownLocation: clearLastKnownLocation
          ? null
          : lastKnownLocation ?? this.lastKnownLocation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'alerts': alerts.map((alert) => alert.toJson()).toList(),
      'pendingMeshAlerts': pendingMeshAlerts
          .map((alert) => alert.toJson())
          .toList(),
      'seenMessageIds': seenMessageIds.toList(),
      'lastKnownLocation': lastKnownLocation == null
          ? null
          : {
              'lat': lastKnownLocation!.latitude,
              'lng': lastKnownLocation!.longitude,
            },
    };
  }

  factory StorageSnapshot.fromJson(Map<String, dynamic> json) {
    final alertJson = (json['alerts'] as List<dynamic>? ?? const []).map(
      (item) => Map<String, dynamic>.from(item as Map),
    );
    final pendingMeshAlertJson =
        (json['pendingMeshAlerts'] as List<dynamic>? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        );
    final rawLocationJson = json['lastKnownLocation'];
    final locationJson = rawLocationJson == null
        ? null
        : Map<String, dynamic>.from(rawLocationJson as Map);

    return StorageSnapshot(
      deviceId: json['deviceId'] as String?,
      alerts: alertJson.map(AlertMessage.fromJson).toList(),
      pendingMeshAlerts: pendingMeshAlertJson
          .map(AlertMessage.fromJson)
          .toList(),
      seenMessageIds: (json['seenMessageIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toSet(),
      lastKnownLocation: locationJson == null
          ? null
          : LatLng(
              (locationJson['lat'] as num).toDouble(),
              (locationJson['lng'] as num).toDouble(),
            ),
    );
  }
}

class StorageService {
  StorageSnapshot _memorySnapshot = const StorageSnapshot();

  Future<StorageSnapshot> loadSnapshot() async {
    if (kIsWeb) {
      return _memorySnapshot;
    }

    try {
      final file = await _storageFile();
      if (!await file.exists()) {
        return _memorySnapshot;
      }

      final rawContent = await file.readAsString();
      if (rawContent.trim().isEmpty) {
        return _memorySnapshot;
      }

      final decoded = jsonDecode(rawContent) as Map<String, dynamic>;
      _memorySnapshot = StorageSnapshot.fromJson(decoded);
    } catch (_) {
      return _memorySnapshot;
    }

    return _memorySnapshot;
  }

  Future<void> saveSnapshot(StorageSnapshot snapshot) async {
    _memorySnapshot = snapshot;
    if (kIsWeb) {
      return;
    }

    try {
      final file = await _storageFile();
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Keep the in-memory state even if persistence is not available.
    }
  }

  Future<File> _storageFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/helpsignal_storage.json');
  }
}
