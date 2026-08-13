package com.sproutapp.sprout

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        createChannel(context)
        val message = intent.getStringExtra(EXTRA_MESSAGE)
            ?.trim()
            ?.take(MAX_MESSAGE_LENGTH)
            ?.ifEmpty { DEFAULT_MESSAGE }
            ?: DEFAULT_MESSAGE
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Sprout reminder")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Sprout reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Reminders you explicitly schedule in Sprout"
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "sprout_reminders"
        const val EXTRA_MESSAGE = "message"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        private const val DEFAULT_MESSAGE = "Time for your Sprout reminder."
        private const val MAX_MESSAGE_LENGTH = 500
    }
}
