import 'package:help_signal/services/storage_service.dart';
import 'package:help_signal/utilities/alert_data.dart';

typedef AlertListener = void Function();

/// Handles alert creation, storage, and duplicate detection with custom state management.
class AlertManager {
  final StorageService storage;
  final List<AlertListener> _listeners = [];

  AlertManager(this.storage);

  List<AlertModel> get alerts => storage.getAlerts();

  bool containsAlert(String id) => storage.containsAlert(id);

  bool createAlert(AlertModel alert) {
    final success = storage.saveAlert(alert);
    if (success) {
      _notifyListeners();
    }
    return success;
  }

  bool processIncomingAlert(AlertModel alert) {
    final success = storage.saveAlert(alert);
    if (success) {
      _notifyListeners();
    }
    return success;
  }

  List<AlertModel> alertsByType(AlertType type) {
    if (type == AlertType.all) {
      return alerts;
    }
    return alerts.where((alert) => alert.type == type).toList();
  }

  void addListener(AlertListener listener) {
    _listeners.add(listener);
  }

  void removeListener(AlertListener listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

