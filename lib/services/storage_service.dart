import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:help_signal/utilities/alert_data.dart';

/// Hive-based persistence for alerts and processed message IDs.
class StorageService {
  static const String _alertsBoxName = 'alerts';
  static const String _processedMessagesBoxName = 'processed_messages';

  late Box<String> _alertsBox;
  late Box<String> _processedMessagesBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _alertsBox = await Hive.openBox<String>(_alertsBoxName);
    _processedMessagesBox = await Hive.openBox<String>(_processedMessagesBoxName);
    _initialized = true;
  }

  List<AlertModel> getAlerts() {
    return _alertsBox.values
        .map((jsonString) {
          try {
            final map = jsonDecode(jsonString) as Map<String, dynamic>;
            return AlertModel.fromMap(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<AlertModel>()
        .toList();
  }

  bool containsAlert(String id) {
    return _alertsBox.containsKey(id);
  }

  bool saveAlert(AlertModel alert) {
    if (containsAlert(alert.id)) {
      return false;
    }
    _alertsBox.put(alert.id, jsonEncode(alert.toMap()));
    return true;
  }

  void clearAlerts() {
    _alertsBox.clear();
  }

  bool hasProcessedMessage(String messageId) {
    return _processedMessagesBox.containsKey(messageId);
  }

  void saveProcessedMessageId(String messageId) {
    _processedMessagesBox.put(messageId, messageId);
  }

  void clearProcessedMessages() {
    _processedMessagesBox.clear();
  }

  Future<void> close() async {
    await _alertsBox.close();
    await _processedMessagesBox.close();
  }
}


