import 'dart:typed_data';
import 'package:help_signal/mesh/mesh_packet.dart';

/// Binary encoder/decoder for MeshPacket
///
/// Packs a 26-byte message into BLE advertisement payload (fits in 31-byte limit)
/// Format (all multi-byte integers are big-endian):
/// Bytes 0-3:   messageId (uint32)
/// Bytes 4-7:   sourceId (uint32)
/// Bytes 8-11:  timestamp (uint32)
/// Byte 12:     ttl (uint8)
/// Byte 13:     type (uint8)
/// Byte 14:     priority (uint8)
/// Bytes 15-17: compressedLat (uint24)
/// Bytes 18-20: compressedLng (uint24)
/// Bytes 21-22: reserved (uint16)
class PacketEncoder {
  static const int PACKET_SIZE = 23; // 4+4+4+1+1+1+3+3+2

  /// Encode MeshPacket to raw bytes
  static Uint8List encode(MeshPacket packet) {
    final buffer = ByteData(PACKET_SIZE);

    // messageId: 4 bytes
    buffer.setUint32(0, packet.messageId, Endian.big);

    // sourceId: 4 bytes
    buffer.setUint32(4, packet.sourceId, Endian.big);

    // timestamp: 4 bytes
    buffer.setUint32(8, packet.timestamp, Endian.big);

    // ttl: 1 byte
    buffer.setUint8(12, packet.ttl & 0xFF);

    // type: 1 byte
    buffer.setUint8(13, packet.type & 0xFF);

    // priority: 1 byte
    buffer.setUint8(14, packet.priority & 0xFF);

    // compressedLat: 3 bytes (uint24)
    _setUint24(buffer, 15, packet.compressedLat);

    // compressedLng: 3 bytes (uint24)
    _setUint24(buffer, 18, packet.compressedLng);

    // reserved: 2 bytes
    buffer.setUint16(21, packet.reserved & 0xFFFF, Endian.big);

    return buffer.buffer.asUint8List();
  }

  /// Decode raw bytes to MeshPacket
  static MeshPacket? decode(List<int> data) {
    if (data.length < PACKET_SIZE) {
      return null;
    }

    try {
      final buffer = ByteData.view(Uint8List.fromList(data).buffer);

      final messageId = buffer.getUint32(0, Endian.big);
      final sourceId = buffer.getUint32(4, Endian.big);
      final timestamp = buffer.getUint32(8, Endian.big);
      final ttl = buffer.getUint8(12);
      final type = buffer.getUint8(13);
      final priority = buffer.getUint8(14);
      final compressedLat = _getUint24(buffer, 15);
      final compressedLng = _getUint24(buffer, 18);
      final reserved = buffer.getUint16(21, Endian.big);

      return MeshPacket(
        messageId: messageId,
        sourceId: sourceId,
        timestamp: timestamp,
        ttl: ttl,
        type: type,
        priority: priority,
        compressedLat: compressedLat,
        compressedLng: compressedLng,
        reserved: reserved,
      );
    } catch (_) {
      return null;
    }
  }

  /// Write 24-bit unsigned integer (big-endian)
  static void _setUint24(ByteData buffer, int offset, int value) {
    final v = value & 0xFFFFFF;
    buffer.setUint8(offset, (v >> 16) & 0xFF);
    buffer.setUint8(offset + 1, (v >> 8) & 0xFF);
    buffer.setUint8(offset + 2, v & 0xFF);
  }

  /// Read 24-bit unsigned integer (big-endian)
  static int _getUint24(ByteData buffer, int offset) {
    final b0 = buffer.getUint8(offset);
    final b1 = buffer.getUint8(offset + 1);
    final b2 = buffer.getUint8(offset + 2);
    return (b0 << 16) | (b1 << 8) | b2;
  }
}
