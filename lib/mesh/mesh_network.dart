import 'dart:async';
import 'package:help_signal/mesh/mesh_packet.dart';
import 'package:help_signal/mesh/packet_encoder.dart';
import 'package:help_signal/mesh/flood_controller.dart';
import 'package:help_signal/managers/alert_manager.dart';
import 'package:help_signal/utilities/alert_data.dart';
import 'package:latlong2/latlong.dart';

/// Orchestrator for mesh network operations
///
/// Bridges between:
/// - BLE transport layer (advertising/scanning)
/// - Flood control layer (deduplication/relay)
/// - Application layer (AlertManager, UI)
class MeshNetwork {
  final AlertManager alertManager;
  final int deviceId;

  late final FloodController _floodController;
  final StreamController<MeshPacket> _packetStream =
      StreamController<MeshPacket>.broadcast();

  bool _initialized = false;
  bool _active = false;

  MeshNetwork({
    required this.alertManager,
    required this.deviceId,
  });

  /// Initialize the mesh network
  Future<void> init() async {
    if (_initialized) return;

    // Create flood controller with this network's send function
    _floodController = FloodController(
      sendFunction: _sendPacket,
    );

    // Register handler to process verified packets
    _floodController.onPacket(_handleVerifiedPacket);

    _initialized = true;
  }

  /// Start mesh operations
  void start() {
    if (!_initialized) {
      throw StateError('MeshNetwork not initialized. Call init() first.');
    }
    _active = true;
  }

  /// Stop mesh operations
  void stop() {
    _active = false;
  }

  /// Create and broadcast a new alert as mesh packet
  Future<void> broadcastAlert({
    required int alertType, // 0=sos, 1=medical, 2=rescue, 3=hazard
    required double latitude,
    required double longitude,
    required int priority, // 0=normal, 1=urgent, 2=emergency
  }) async {
    if (!_active) {
      throw StateError('MeshNetwork not active. Call start() first.');
    }

    final messageId = DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Compress GPS coordinates
    final compressedLat = ((latitude + 90) * 10000).toInt();
    final compressedLng = ((longitude + 180) * 10000).toInt();

    final packet = MeshPacket(
      messageId: messageId,
      sourceId: deviceId,
      timestamp: timestamp,
      ttl: 8, // Initial TTL (will hop up to 8 times)
      type: alertType,
      priority: priority,
      compressedLat: compressedLat,
      compressedLng: compressedLng,
      reserved: 0,
    );

    await _floodController.broadcastAlert(packet);
  }

  /// Process incoming raw advertisement data
  Future<void> processAdvertisement(List<int> rawData) async {
    if (!_active) return;

    final packet = PacketEncoder.decode(rawData);
    if (packet == null) return;

    // Process through flooding algorithm
    await _floodController.handleIncomingPacket(packet);
  }

  /// Handle verified packet (called by flood controller)
  void _handleVerifiedPacket(MeshPacket packet) {
    _packetStream.add(packet);

    // Reconstruct UI alert from mesh packet
    _reconstructAndDeliverAlert(packet);
  }

  /// Reconstruct full UI alert from mesh packet and store it
  void _reconstructAndDeliverAlert(MeshPacket packet) {
    // Get alert type metadata
    final alertTypeMap = {
      0: (AlertType.sos, 'SOS Alert', Colors.red),
      1: (AlertType.medical, 'Medical Emergency', Colors.blue),
      2: (AlertType.rescue, 'Rescue Request', Colors.orange),
      3: (AlertType.hazard, 'Hazard Warning', Colors.orange),
    };

    final metadata = alertTypeMap[packet.type];
    if (metadata == null) return;

    final (alertType, title, color) = metadata;

    final location = LatLng(packet.latitude, packet.longitude);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(packet.timestamp * 1000);
    final timeAgo = _formatTimeAgo(timestamp);

    // Calculate distance from a default location (in real app, use device location)
    const userLocation = LatLng(28.4953546, 77.0073292);
    final distance = _calculateDistance(location, userLocation);
    final distanceStr = _formatDistance(distance);

    final alert = AlertModel(
      id: packet.messageId.toString(),
      type: alertType,
      title: title,
      description: 'Received via mesh relay (TTL: ${packet.ttl})',
      distance: distanceStr,
      time: timeAgo,
      location: location,
      color: color,
    );

    // Store alert in manager
    alertManager.processIncomingAlert(alert);
  }

  /// Format time ago for display
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Calculate distance between two locations
  double _calculateDistance(LatLng loc1, LatLng loc2) {
    const earthRadiusKm = 6371.0;

    final dLat = _toRad(loc2.latitude - loc1.latitude);
    final dLng = _toRad(loc2.longitude - loc1.longitude);

    final a = (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
        (Math.cos(_toRad(loc1.latitude)) *
            Math.cos(_toRad(loc2.latitude)) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2));

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  double _toRad(double degrees) {
    return degrees * 3.14159265359 / 180;
  }

  /// Format distance for display
  String _formatDistance(double km) {
    if (km >= 1.0) {
      return '${km.toStringAsFixed(1)} KM';
    } else {
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
  }

  /// Send encoded packet via BLE
  Future<void> _sendPacket(MeshPacket packet) async {
    final encoded = PacketEncoder.encode(packet);
    // This would be connected to BLE service in real implementation
    // For now, just simulate
    print('Sending packet: $packet');
  }

  /// Get mesh network statistics
  String getStats() {
    return 'MeshNetwork: active=$_active, ${_floodController.getStats()}';
  }

  /// Stream of verified packets
  Stream<MeshPacket> get packetStream => _packetStream.stream;

  /// Clean up resources
  void dispose() {
    _floodController.dispose();
    _packetStream.close();
  }
}

// Math utilities
class Math {
  static double sin(double x) => double.parse(
      _nativeSin(x).toStringAsFixed(15)); // Use Dart's sin if available
  static double cos(double x) => double.parse(
      _nativeCos(x).toStringAsFixed(15)); // Use Dart's cos if available
  static double atan2(double y, double x) =>
      double.parse(_nativeAtan2(y, x).toStringAsFixed(15));
  static double sqrt(double x) => double.parse(
      _nativeSqrt(x).toStringAsFixed(15)); // Use Dart's sqrt if available

  static double _nativeSin(double x) {
    // Use Dart's built-in sin
    return (x * 3.14159265359 / 180).sin;
  }

  static double _nativeCos(double x) {
    // Use Dart's built-in cos
    return (x * 3.14159265359 / 180).cos;
  }

  static double _nativeAtan2(double y, double x) {
    return Atan2(y, x);
  }

  static double _nativeSqrt(double x) {
    return x.sqrt;
  }

  // Separate atan2 implementation if needed
  static double Atan2(double y, double x) {
    if (x > 0) return (y / x).atan;
    if (x < 0 && y >= 0) return (y / x).atan + 3.14159265359;
    if (x < 0 && y < 0) return (y / x).atan - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0; // x=0 and y=0
  }
}
