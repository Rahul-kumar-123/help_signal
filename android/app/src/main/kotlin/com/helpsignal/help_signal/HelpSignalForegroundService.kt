package com.helpsignal.help_signal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class HelpSignalForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START,
            ACTION_UPDATE,
            null -> {
                ensureNotificationChannel()
                val title =
                    intent?.getStringExtra(EXTRA_TITLE)?.takeIf { it.isNotBlank() }
                        ?: DEFAULT_TITLE
                val message =
                    intent?.getStringExtra(EXTRA_MESSAGE)?.takeIf { it.isNotBlank() }
                        ?: DEFAULT_MESSAGE
                val notification = buildNotification(title = title, message = message)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
        }

        return START_NOT_STICKY
    }

    private fun buildNotification(title: String, message: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(buildContentIntent())
            .build()

    private fun buildContentIntent(): PendingIntent {
        val intent =
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_NEW_TASK
            }

        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val existingChannel = manager?.getNotificationChannel(CHANNEL_ID)
        if (existingChannel != null) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "HelpSignal background service",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows that HelpSignal mesh discovery is active."
        }

        manager?.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "helpsignal_runtime"
        private const val NOTIFICATION_ID = 1042
        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_MESSAGE = "extra_message"
        private const val ACTION_START = "com.helpsignal.help_signal.action.START"
        private const val ACTION_UPDATE = "com.helpsignal.help_signal.action.UPDATE"
        private const val DEFAULT_TITLE = "HelpSignal active"
        private const val DEFAULT_MESSAGE =
            "Mesh discovery is running in the background."

        fun start(context: Context, title: String, message: String) {
            val intent =
                Intent(context, HelpSignalForegroundService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_MESSAGE, message)
                }
            ContextCompat.startForegroundService(context, intent)
        }

        fun update(context: Context, title: String, message: String) {
            val intent =
                Intent(context, HelpSignalForegroundService::class.java).apply {
                    action = ACTION_UPDATE
                    putExtra(EXTRA_TITLE, title)
                    putExtra(EXTRA_MESSAGE, message)
                }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, HelpSignalForegroundService::class.java))
        }
    }
}
