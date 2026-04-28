package com.helpsignal.help_signal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "help_signal/foreground_service",
        ).setMethodCallHandler { call, result ->
            val title = call.argument<String>("title") ?: "HelpSignal active"
            val message =
                call.argument<String>("message")
                    ?: "Mesh discovery is running in the background."

            when (call.method) {
                "startService" -> {
                    HelpSignalForegroundService.start(this, title, message)
                    result.success(null)
                }

                "updateService" -> {
                    HelpSignalForegroundService.update(this, title, message)
                    result.success(null)
                }

                "stopService" -> {
                    HelpSignalForegroundService.stop(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
