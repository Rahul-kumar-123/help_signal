import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum AlertType { all, sos, medical, rescue, hazard }

extension AlertTypeWireFormat on AlertType {
  String get wireValue {
    switch (this) {
      case AlertType.all:
        return 'all';
      case AlertType.sos:
        return 'sos';
      case AlertType.medical:
        return 'medical';
      case AlertType.rescue:
        return 'rescue';
      case AlertType.hazard:
        return 'hazard';
    }
  }

  String get label {
    switch (this) {
      case AlertType.all:
        return 'All';
      case AlertType.sos:
        return 'SOS';
      case AlertType.medical:
        return 'Medical';
      case AlertType.rescue:
        return 'Rescue';
      case AlertType.hazard:
        return 'Hazard';
    }
  }

  String get fallbackTitle {
    switch (this) {
      case AlertType.all:
        return 'All Alerts';
      case AlertType.sos:
        return 'Emergency SOS';
      case AlertType.medical:
        return 'Medical Emergency';
      case AlertType.rescue:
        return 'Rescue Request';
      case AlertType.hazard:
        return 'Hazard Alert';
    }
  }

  String get actionLabel {
    switch (this) {
      case AlertType.all:
        return 'View';
      case AlertType.sos:
        return 'Navigate';
      case AlertType.medical:
        return 'View Details';
      case AlertType.rescue:
        return 'Navigate';
      case AlertType.hazard:
        return 'Safety Info';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertType.all:
        return Icons.filter_alt;
      case AlertType.sos:
        return Icons.sos;
      case AlertType.medical:
        return Icons.local_hospital;
      case AlertType.rescue:
        return Icons.shield;
      case AlertType.hazard:
        return Icons.warning_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AlertType.all:
        return const Color(0xFF475569);
      case AlertType.sos:
        return const Color(0xFFD92D20);
      case AlertType.medical:
        return const Color(0xFF2563EB);
      case AlertType.rescue:
        return const Color(0xFFF97316);
      case AlertType.hazard:
        return const Color(0xFFB45309);
    }
  }

  Color get lightColor {
    switch (this) {
      case AlertType.all:
        return const Color(0xFFE2E8F0);
      case AlertType.sos:
        return const Color(0xFFFDECEA);
      case AlertType.medical:
        return const Color(0xFFDBEAFE);
      case AlertType.rescue:
        return const Color(0xFFFFEDD5);
      case AlertType.hazard:
        return const Color(0xFFFEF3C7);
    }
  }

  static AlertType fromWireValue(String rawType) {
    return AlertType.values.firstWhere(
      (value) => value.wireValue == rawType,
      orElse: () => AlertType.sos,
    );
  }
}

const Map<AlertType, List<String>> predefinedDescriptions = {
  AlertType.sos: [
    'Severe accident',
    'Immediate danger',
    'Life-threatening situation',
  ],
  AlertType.medical: ['Heart attack', 'Unconscious person', 'Severe injury'],
  AlertType.rescue: ['Trapped person', 'Missing individual', 'Need evacuation'],
  AlertType.hazard: ['Fire', 'Gas leak', 'Flooded area'],
};

class AlertMessage {
  final String messageId;
  final AlertType type;
  final double latitude;
  final double longitude;
  final int timestamp;
  final int hopCount;
  final int? descriptionCode;
  final String senderId;

  const AlertMessage({
    required this.messageId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.hopCount,
    required this.senderId,
    this.descriptionCode,
  });

  factory AlertMessage.create({
    required AlertType type,
    required LatLng location,
    required String senderId,
    int? descriptionCode,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random();
    final id = '$now-${random.nextInt(1 << 20).toRadixString(16)}';

    return AlertMessage(
      messageId: id,
      type: type,
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: now,
      hopCount: 1,
      descriptionCode: descriptionCode,
      senderId: senderId,
    );
  }

  factory AlertMessage.fromJson(Map<String, dynamic> json) {
    return AlertMessage(
      messageId: json['messageId'] as String? ?? json['id'] as String,
      type: AlertTypeWireFormat.fromWireValue(
        json['type'] as String? ?? json['t'] as String,
      ),
      latitude: (json['latitude'] ?? json['lat'] as num).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] as num).toDouble(),
      timestamp: json['timestamp'] as int? ?? json['ts'] as int,
      hopCount: json['hopCount'] as int? ?? json['hop'] as int,
      descriptionCode: json['descriptionCode'] as int? ?? json['desc'] as int?,
      senderId: json['senderId'] as String? ?? json['sid'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'type': type.wireValue,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'hopCount': hopCount,
      'descriptionCode': descriptionCode,
      'senderId': senderId,
    };
  }

  Map<String, dynamic> toBlePacket() {
    return {
      'id': messageId,
      't': type.wireValue,
      'lat': latitude,
      'lng': longitude,
      'ts': timestamp,
      'hop': hopCount,
      'desc': descriptionCode,
      'sid': senderId,
    };
  }

  AlertMessage copyWith({
    String? messageId,
    AlertType? type,
    double? latitude,
    double? longitude,
    int? timestamp,
    int? hopCount,
    int? descriptionCode,
    bool clearDescriptionCode = false,
    String? senderId,
  }) {
    return AlertMessage(
      messageId: messageId ?? this.messageId,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      hopCount: hopCount ?? this.hopCount,
      descriptionCode: clearDescriptionCode
          ? null
          : descriptionCode ?? this.descriptionCode,
      senderId: senderId ?? this.senderId,
    );
  }

  AlertMessage relayed() => copyWith(hopCount: hopCount + 1);

  LatLng get location => LatLng(latitude, longitude);

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  String get title => description ?? type.fallbackTitle;

  String? get description {
    final code = descriptionCode;
    final options = predefinedDescriptions[type];
    if (code == null || options == null || code < 0 || code >= options.length) {
      return null;
    }
    return options[code];
  }
}

String formatRelativeTime(DateTime timestamp, {DateTime? now}) {
  final currentTime = now ?? DateTime.now();
  final difference = currentTime.difference(timestamp);

  if (difference.inSeconds < 60) {
    return '${difference.inSeconds.clamp(1, 59)} sec ago';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} hr ago';
  }
  return '${difference.inDays} day ago';
}
