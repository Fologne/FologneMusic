package com.musicapp.music_app

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal fun registerAudioDownloads(context: Context, messenger: BinaryMessenger) {
    MethodChannel(messenger, "musicapp/audioDownloads").setMethodCallHandler { call, result ->
        if (call.method == "available") result.success(false)
        else result.notImplemented()
    }
}
