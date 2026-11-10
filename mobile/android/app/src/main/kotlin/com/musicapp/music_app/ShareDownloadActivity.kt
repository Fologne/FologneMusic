package com.musicapp.music_app

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ShareDownloadActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent.action != Intent.ACTION_SEND || intent.type != "text/plain") {
            finish()
            return
        }
        val strings = AppLanguage.resources(this)
        val dialog = AlertDialog.Builder(this)
            .setTitle("FologneMusic")
            .setMessage(strings.getString(R.string.preparing_download))
            .setPositiveButton(strings.getString(R.string.view_download)) { _, _ ->
                startActivity(DownloadShare.openIntent(this))
            }
            .setNegativeButton(android.R.string.ok, null)
            .create()
        dialog.setOnDismissListener { finish() }
        dialog.show()
        val openButton = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
        openButton.isEnabled = false
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?: intent.clipData?.getItemAt(0)?.text
        val context = applicationContext
        DownloadShare.attach(context, AudioServicePlugin.getFlutterEngine(context))
        DownloadShare.enqueue(text?.take(8192)?.toString().orEmpty()) { status ->
            if (!dialog.isShowing || isFinishing || isDestroyed) return@enqueue
            dialog.setMessage(when (status) {
                "started" -> strings.getString(R.string.download_started)
                "queued" -> strings.getString(R.string.download_queued)
                "duplicate" -> strings.getString(R.string.download_duplicate)
                "invalid" -> strings.getString(R.string.share_invalid)
                "unavailable" -> strings.getString(R.string.share_unavailable)
                else -> strings.getString(R.string.share_failed)
            })
            openButton.isEnabled = status in setOf("started", "queued", "duplicate")
            if (status == "started" || status == "queued") DownloadNotifications.request(this)
        }
    }
}

internal object DownloadShare {
    const val openAction = "com.musicapp.music_app.OPEN_AUDIO_DOWNLOADS"
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private var openPending = false
    private val pending = ArrayDeque<Pair<String, (String) -> Unit>>()

    fun attach(context: Context, flutterEngine: FlutterEngine) {
        if (engine === flutterEngine) return
        engine = flutterEngine
        ready = false
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        registerAudioDownloads(context, messenger)
        channel = MethodChannel(messenger, "musicapp/share").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLanguage" -> result.success(AppLanguage.preference(context))
                    "getDeviceLanguage" -> result.success(AppLanguage.deviceLanguage())
                    "setLanguage" -> {
                        AppLanguage.setPreference(context, call.arguments as? String)
                        result.success(null)
                    }
                    "ready" -> {
                        ready = true
                        result.success(null)
                        while (pending.isNotEmpty()) {
                            val (text, callback) = pending.removeFirst()
                            enqueue(text, callback)
                        }
                        if (openPending) openDownloads()
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun enqueue(text: String, callback: (String) -> Unit) {
        if (!ready) {
            if (pending.size == 8) pending.removeFirst().second("failed")
            pending.addLast(text to callback)
            return
        }
        channel?.invokeMethod("enqueueShared", text, object : MethodChannel.Result {
            override fun success(result: Any?) = callback(result as? String ?: "failed")
            override fun error(code: String, message: String?, details: Any?) = callback("failed")
            override fun notImplemented() = callback("unavailable")
        })
    }

    fun openIntent(context: Context) = Intent(context, MainActivity::class.java)
        .setAction(openAction)
        .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    fun openDownloads() {
        openPending = !ready
        if (ready) channel?.invokeMethod("openDownloads", null)
    }
}
