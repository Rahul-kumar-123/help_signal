import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

abstract class AppForegroundService {
  Future<void> start({
    required String title,
    required String message,
  });

  Future<void> update({
    required String title,
    required String message,
  });

  Future<void> stop();
}

class AndroidAppForegroundService implements AppForegroundService {
  static const MethodChannel _channel = MethodChannel(
    'help_signal/foreground_service',
  );

  bool _hasStarted = false;

  @override
  Future<void> start({
    required String title,
    required String message,
  }) async {
    if (!_isAndroid) {
      return;
    }

    await _requestNotificationPermissionIfNeeded();
    await _channel.invokeMethod<void>('startService', {
      'title': title,
      'message': message,
    });
    _hasStarted = true;
  }

  @override
  Future<void> update({
    required String title,
    required String message,
  }) async {
    if (!_isAndroid) {
      return;
    }

    if (!_hasStarted) {
      await start(title: title, message: message);
      return;
    }

    await _channel.invokeMethod<void>('updateService', {
      'title': title,
      'message': message,
    });
  }

  @override
  Future<void> stop() async {
    if (!_isAndroid || !_hasStarted) {
      return;
    }

    await _channel.invokeMethod<void>('stopService');
    _hasStarted = false;
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Foreground services can still start even if notification permission
      // handling is unavailable on the current platform/runtime.
    }
  }
}
