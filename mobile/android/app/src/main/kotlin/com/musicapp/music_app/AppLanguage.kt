package com.musicapp.music_app

import android.app.NotificationManager
import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import android.os.Build
import java.util.Locale

internal object AppLanguage {
    private fun settings(context: Context) =
        context.getSharedPreferences("appearance", Context.MODE_PRIVATE)

    fun preference(context: Context): String? = settings(context).getString("language", null)

    fun deviceLanguage(): String = Resources.getSystem().configuration.locales[0].language

    fun resources(context: Context): Resources {
        val configuration = Configuration(context.resources.configuration)
        val language = preference(context) ?: deviceLanguage()
        configuration.setLocale(if (language == "pt") Locale("pt") else Locale.ENGLISH)
        return context.createConfigurationContext(configuration).resources
    }

    fun setPreference(context: Context, value: String?) {
        settings(context).edit().putString("language", value?.takeIf { it == "pt" || it == "en" }).apply()
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val strings = resources(context)
        val channels = mapOf(
            "com.musicapp.music_app.playback" to R.string.music_playback,
            "audio-download-progress" to R.string.downloads_in_progress,
            "audio-download-completed" to R.string.completed_downloads,
        )
        for ((id, label) in channels) {
            val channel = manager.getNotificationChannel(id) ?: continue
            channel.name = strings.getString(label)
            manager.createNotificationChannel(channel)
        }
    }
}
