package com.musicapp.music_app

import android.annotation.TargetApi
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.ApplicationInfo
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID
import java.util.concurrent.Executors

internal fun registerAudioDownloads(context: Context, messenger: BinaryMessenger) {
    val channel = MethodChannel(messenger, "musicapp/audioDownloads")
    channel.setMethodCallHandler { call, result ->
        val available = Build.VERSION.SDK_INT >= 29
        when (call.method) {
            "available" -> result.success(available)
            "start" -> if (available) {
                val url = call.argument<String>("url").orEmpty()
                val id = Regex("""https://www\.youtube\.com/watch\?v=([A-Za-z0-9_-]{11})""")
                    .matchEntire(url)?.groupValues?.get(1)
                if (id == null) result.error("invalid", "Link inválido.", null)
                else AudioDownloads.start(context, url, id, channel, result)
            } else result.error("unavailable", "Requer Android 10 ou superior.", null)
            "startFixture" -> {
                val url = call.argument<String>("url").orEmpty()
                val debuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
                if (available && debuggable && Regex("""http://127\.0\.0\.1:\d{4,5}/fologne-test\.wav""").matches(url)) {
                    AudioDownloads.start(context, url, "fixture", channel, result)
                } else result.notImplemented()
            }
            "cancel" -> result.success(AudioDownloads.cancel())
            else -> result.notImplemented()
        }
    }
}

@TargetApi(29)
private object AudioDownloads {
    private val worker = Executors.newSingleThreadExecutor()
    private val cancellation = Executors.newSingleThreadExecutor()
    private val ui = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var active: Job? = null

    private class Job(val id: String = UUID.randomUUID().toString()) {
        @Volatile var canceled = false
        var committing = false
    }

    fun start(context: Context, url: String, id: String, channel: MethodChannel, result: MethodChannel.Result) {
        val job = synchronized(lock) {
            if (active != null) return result.error("busy", "Já há um download em andamento.", null)
            Job().also { active = it }
        }
        worker.execute {
            val directory = File(context.cacheDir, "audio-download-${job.id}")
            var savedTrack: Map<String, String>? = null
            var failure: DownloadFailure? = null
            try {
                val name = "Fologne-$id.mp3"
                checkNewFile(context, name)
                if (context.cacheDir.usableSpace < 160L * 1024 * 1024) {
                    throw DownloadFailure("storage", "Espaço insuficiente para converter a música.")
                }
                if (!directory.mkdir()) throw IOException()
                initialize(context)
                if (job.canceled) throw DownloadFailure("canceled", "Download cancelado.")
                val request = YoutubeDLRequest(url)
                    .addOption("--ignore-config")
                    .addOption("--no-playlist")
                    .addOption("--socket-timeout", 15)
                    .addOption("--retries", 2)
                    .addOption("--fragment-retries", 2)
                    .addOption("--max-filesize", "100M")
                    .addOption("--match-filters", "!is_live & duration <=? 1800")
                    .addOption("-f", "bestaudio/best")
                    .addOption("--extract-audio")
                    .addOption("--audio-format", "mp3")
                    .addOption("--audio-quality", "2")
                    .addOption("--embed-metadata")
                    .addOption("--newline")
                    .addOption("-o", File(directory, "audio.%(ext)s").absolutePath)
                if (id != "fixture") request.addOption("--embed-thumbnail")
                var lastProgress = -1
                YoutubeDL.execute(request, job.id) { progress, _, line ->
                    val percent = if (line.startsWith("[ExtractAudio]")) 100 else progress.toInt().coerceIn(0, 99)
                    if (percent > lastProgress) {
                        lastProgress = percent
                        ui.post { channel.invokeMethod("progress", percent) }
                    }
                }
                val mp3 = File(directory, "audio.mp3")
                if (!mp3.isFile || mp3.length() == 0L) {
                    throw DownloadFailure("no_audio", "O link não forneceu um áudio disponível.")
                }
                synchronized(lock) {
                    if (job.canceled) throw DownloadFailure("canceled", "Download cancelado.")
                    job.committing = true
                }
                savedTrack = publish(context, mp3, name)
            } catch (error: LinkageError) {
                android.util.Log.e("FologneDownloads", "Download engine failed to initialize", error)
                failure = DownloadFailure("engine", "Não foi possível iniciar o conversor de áudio.")
            } catch (error: Exception) {
                failure = when {
                    job.canceled -> DownloadFailure("canceled", "Download cancelado.")
                    error is DownloadFailure -> error
                    context.cacheDir.usableSpace < 16L * 1024 * 1024 ->
                        DownloadFailure("storage", "Espaço insuficiente para salvar a música.")
                    else -> DownloadFailure(
                        "download_failed", "Não foi possível baixar ou converter o áudio. Verifique a conexão e o link."
                    )
                }
            } finally {
                directory.deleteRecursively()
                synchronized(lock) { active = null }
                ui.post {
                    val error = failure
                    if (error == null) result.success(savedTrack)
                    else result.error(error.code, error.message, null)
                }
            }
        }
    }

    fun cancel(): Boolean {
        val job = synchronized(lock) {
            val running = active ?: return false
            if (running.committing || running.canceled) return false
            running.canceled = true
            running
        }
        cancellation.execute {
            while (synchronized(lock) { active === job }) {
                if (YoutubeDL.destroyProcessById(job.id)) break
                Thread.sleep(100)
            }
        }
        return true
    }

    private fun initialize(context: Context) {
        val directory = File(context.noBackupFilesDir, "${YoutubeDL.baseName}/${YoutubeDL.ytdlpDirName}")
        directory.mkdirs()
        val extractor = File(directory, YoutubeDL.ytdlpBin)
        val marker = File(directory, "fologne-version")
        if (!extractor.isFile || !marker.isFile || marker.readText() != "2026.10.26") {
            val temporary = File(directory, "fologne-extractor.tmp")
            context.assets.open("fologne-yt-dlp").use { input ->
                temporary.outputStream().use { input.copyTo(it) }
            }
            Files.move(temporary.toPath(), extractor.toPath(), StandardCopyOption.REPLACE_EXISTING)
            marker.writeText("2026.10.26")
        }
        YoutubeDL.init(context)
        FFmpeg.init(context)
    }

    private val collection get() = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    private const val folder = "Music/FologneMusic/"

    private fun checkNewFile(context: Context, name: String) {
        val exists = context.contentResolver.query(
            collection, arrayOf(MediaStore.Audio.Media._ID),
            "${MediaStore.Audio.Media.DISPLAY_NAME} = ? AND ${MediaStore.Audio.Media.RELATIVE_PATH} = ?",
            arrayOf(name, folder), null
        )?.use { it.moveToFirst() } == true
        if (exists) throw DownloadFailure("duplicate", "Esta música já está na pasta do FologneMusic.")
    }

    private fun publish(context: Context, mp3: File, name: String): Map<String, String> {
        val metadata = MediaMetadataRetriever()
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.RELATIVE_PATH, folder)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val title = try {
            metadata.setDataSource(mp3.absolutePath)
            val title = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                ?.takeIf { it.isNotBlank() } ?: name.removeSuffix(".mp3")
            values.put(MediaStore.Audio.Media.TITLE, title)
            values.put(MediaStore.Audio.Media.ARTIST, metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST))
            values.put(MediaStore.Audio.Media.ALBUM, metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM))
            title
        } finally {
            metadata.release()
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(collection, values) ?: throw IOException()
        try {
            (resolver.openOutputStream(uri) ?: throw IOException()).use { output ->
                mp3.inputStream().use { it.copyTo(output) }
            }
            val ready = ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }
            if (resolver.update(uri, ready, null, null) != 1) throw IOException()
        } catch (error: Exception) {
            runCatching { resolver.delete(uri, null, null) }
            throw error
        }
        val trackId = ContentUris.withAppendedId(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, ContentUris.parseId(uri)
        )
        return mapOf("title" to title, "trackId" to trackId.toString())
    }

    private class DownloadFailure(val code: String, message: String) : Exception(message)
}
