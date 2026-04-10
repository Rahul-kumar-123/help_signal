import 'dart:async';
import 'package:help_signal/mesh/mesh_packet.dart';
import 'package:help_signal/mesh/deduplication_cache.dart';
import 'package:help_signal/mesh/rate_limiter.dart';

typedef PacketHandler = void Function(MeshPacket packet);
typedef SendFunction = Future<void> Function(MeshPacket packet);

/// Core mesh network flooding controller
///
/// Implements the opportunistic controlled flooding algorithm:
/// 1. Receive packet
/// 2. Check deduplication cache
/// 3. Deliver to application layer
/// 4. Decrement TTL
/// 5. Apply rate limiting
/// 6. Rebroadcast with random delay
class FloodController {
  final DeduplicationCache _dedup;
  final RateLimiter _rateLimiter;
  final SendFunction _sendFunction;

  final List<PacketHandler> _handlers = [];
  final Map<int, Timer> _rebroadcastTimers = {};

  FloodController({
    required SendFunction sendFunction,
    DeduplicationCache? dedup,
    RateLimiter? rateLimiter,
  })  : _sendFunction = sendFunction,
        _dedup = dedup ?? DeduplicationCache(),
        _rateLimiter = rateLimiter ?? RateLimiter();

  /// Register handler to receive verified packets
  void onPacket(PacketHandler handler) {
    _handlers.add(handler);
  }

  /// Broadcast a new alert packet from this device
  /// Sets high initial TTL and marks as processed
  Future<void> broadcastAlert(
    MeshPacket packet, {
    int initialTtl = 8,
  }) async {
    final toSend = MeshPacket(
      messageId: packet.messageId,
      sourceId: packet.sourceId,
      timestamp: packet.timestamp,
      ttl: initialTtl,
      type: packet.type,
      priority: packet.priority,
      compressedLat: packet.compressedLat,
      compressedLng: packet.compressedLng,
      reserved: packet.reserved,
    );

    // Mark as processed to prevent self-relay
    _dedup.add(toSend.messageId);

    // Deliver locally
    _deliverToHandlers(toSend);

    // Broadcast immediately
    await _sendFunction(toSend);
  }

  /// Process incoming packet (core flooding algorithm)
  Future<void> handleIncomingPacket(MeshPacket packet) async {
    // Check deduplication cache
    if (_dedup.contains(packet.messageId)) {
      return; // Duplicate, drop
    }

    // Mark as processed
    _dedup.add(packet.messageId);

    // Deliver to application layer
    _deliverToHandlers(packet);

    // Check if TTL allows relaying
    if (packet.ttl <= 0) {
      return; // TTL expired, don't relay
    }

    // Apply rate limiting
    if (!_rateLimiter.canRebroadcast(isEmergency: packet.isEmergency)) {
      return; // Rate limit exceeded
    }

    // Create relay packet with decremented TTL
    final relayPacket = MeshPacket(
      messageId: packet.messageId,
      sourceId: packet.sourceId,
      timestamp: packet.timestamp,
      ttl: packet.ttl - 1,
      type: packet.type,
      priority: packet.priority,
      compressedLat: packet.compressedLat,
      compressedLng: packet.compressedLng,
      reserved: packet.reserved,
    );

    // Schedule rebroadcast with random delay
    _scheduleRebroadcast(relayPacket);
  }

  /// Schedule rebroadcast with random delay
  void _scheduleRebroadcast(MeshPacket packet) {
    // Cancel any existing timer for this packet
    _rebroadcastTimers[packet.messageId]?.cancel();

    final delay = _rateLimiter.getRandomDelay();

    _rebroadcastTimers[packet.messageId] = Timer(delay, () async {
      try {
        await _sendFunction(packet);
      } catch (e) {
        print('Error rebroadcasting packet: $e');
      } finally {
        _rebroadcastTimers.remove(packet.messageId);
      }
    });
  }

  /// Deliver packet to all registered handlers
  void _deliverToHandlers(MeshPacket packet) {
    for (final handler in _handlers) {
      try {
        handler(packet);
      } catch (e) {
        print('Error in packet handler: $e');
      }
    }
  }

  /// Get network statistics
  String getStats() {
    return 'Flood: ${_dedup.size} cached, '
        '${_rebroadcastTimers.length} pending, '
        '${_handlers.length} handlers\n'
        '${_dedup.getStats()}\n'
        '${_rateLimiter.getStats()}';
  }

  /// Clean up resources
  void dispose() {
    for (final timer in _rebroadcastTimers.values) {
      timer.cancel();
    }
    _rebroadcastTimers.clear();
    _handlers.clear();
    _dedup.clear();
  }
}
