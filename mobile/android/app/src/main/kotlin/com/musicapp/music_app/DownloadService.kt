package com.musicapp.music_app

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder

class DownloadService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        instance = this
        startForeground(42, DownloadNotifications.running(this))
        if (!requested) stopSelf(startId)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        requested = false
        stopSelf()
    }

    companion object {
        private var requested = false
        private var instance: DownloadService? = null

        fun start(context: Context) {
            if (requested) return
            context.startForegroundService(Intent(context, DownloadService::class.java))
            requested = true
        }

        fun idle() {
            requested = false
            instance?.stopSelf()
        }
    }
}

internal object DownloadNotifications {
    fun request(activity: Activity) {
        if (Build.VERSION.SDK_INT < 33 ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) return
        val preferences = activity.getSharedPreferences("download-notifications", Context.MODE_PRIVATE)
        if (preferences.getBoolean("asked", false)) return
        preferences.edit().putBoolean("asked", true).apply()
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 404)
    }

    fun running(context: Context): Notification {
        val strings = AppLanguage.resources(context)
        return builder(context, "audio-download-progress", strings.getString(R.string.downloads_in_progress), NotificationManager.IMPORTANCE_LOW)
            .setContentTitle(strings.getString(R.string.downloading_audio))
            .setContentText(strings.getString(R.string.preparing_mp3))
            .setOngoing(true)
            .build()
    }

    fun completed(context: Context, trackId: String, title: String) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val strings = AppLanguage.resources(context)
        val notification = builder(context, "audio-download-completed", strings.getString(R.string.completed_downloads), NotificationManager.IMPORTANCE_DEFAULT)
            .setContentTitle(strings.getString(R.string.download_completed))
            .setContentText(title)
            .setAutoCancel(true)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(trackId, 43, notification)
    }

    private fun builder(context: Context, id: String, name: String, importance: Int): Notification.Builder {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(id, name, importance))
        val open = PendingIntent.getActivity(context, 43, DownloadShare.openIntent(context), PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(context, id)
            .setSmallIcon(R.drawable.ic_music_note)
            .setContentIntent(open)
    }
}
