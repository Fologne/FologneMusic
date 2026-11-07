package com.musicapp.music_app

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val worker = Executors.newFixedThreadPool(2)
    private var permissionResult: MethodChannel.Result? = null
    private val audioPermission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "musicapp/media").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(checkSelfPermission(audioPermission) == PackageManager.PERMISSION_GRANTED)
                "requestPermission" -> {
                    if (checkSelfPermission(audioPermission) == PackageManager.PERMISSION_GRANTED) result.success(true)
                    else if (permissionResult != null) result.error("busy", "Uma solicitação já está aberta.", null)
                    else {
                        permissionResult = result
                        requestPermissions(arrayOf(audioPermission), 401)
                    }
                }
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "scan" -> worker.execute {
                    try {
                        if (checkSelfPermission(audioPermission) != PackageManager.PERMISSION_GRANTED) throw SecurityException("Permissão de áudio negada")
                        val rows = scanAudio()
                        runOnUiThread { result.success(rows) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("scan_failed", "Não foi possível ler a biblioteca. Verifique a permissão de áudio.", null) }
                    }
                }
                "artwork" -> worker.execute {
                    val bytes = artwork(call.argument<String>("uri") ?: "")
                    runOnUiThread { result.success(bytes) }
                }
                "notificationArtwork" -> worker.execute {
                    val file = runCatching { notificationArtwork(call.argument<String>("uri").orEmpty()) }.getOrNull()
                    runOnUiThread { result.success(file) }
                }
                "openSource" -> {
                    val uri = Uri.parse(call.argument<String>("url").orEmpty())
                    val opened = uri.scheme == "https" && !uri.host.isNullOrBlank() && runCatching {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                    }.isSuccess
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 401) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    private fun scanAudio(): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val folderColumn = if (Build.VERSION.SDK_INT >= 29) MediaStore.Audio.Media.RELATIVE_PATH else MediaStore.Audio.Media.DATA
        val columns = arrayOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.DISPLAY_NAME, MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM, MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED, folderColumn)
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        contentResolver.query(collection, columns, "${MediaStore.Audio.Media.SIZE} > 0", null, "${MediaStore.Audio.Media.TITLE} ASC")?.use { cursor ->
            fun text(column: String): String = cursor.getString(cursor.getColumnIndexOrThrow(column))?.trim().orEmpty()
            fun known(value: String, fallback: String) = if (value.isBlank() || value == "<unknown>") fallback else value
            while (cursor.moveToNext()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                val duration = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)).coerceAtLeast(0)
                val rawFolder = text(folderColumn)
                val folder = if (Build.VERSION.SDK_INT >= 29) rawFolder.trimEnd('/') else rawFolder.substringBeforeLast('/', "Music")
                rows.add(mapOf(
                    "id" to ContentUris.withAppendedId(collection, id).toString(),
                    "title" to known(text(MediaStore.Audio.Media.TITLE), known(text(MediaStore.Audio.Media.DISPLAY_NAME), "Sem título")),
                    "artist" to known(text(MediaStore.Audio.Media.ARTIST), "Artista desconhecido"),
                    "album" to known(text(MediaStore.Audio.Media.ALBUM), "Álbum desconhecido"),
                    "durationMs" to duration,
                    "folder" to known(folder, "Music"),
                    "addedAt" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)) * 1000,
                    "available" to true
                ))
            }
        }
        return rows
    }

    private fun artwork(value: String): ByteArray? {
        if (!value.startsWith("content://media/")) return null
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(this, Uri.parse(value))
            val bytes = retriever.embeddedPicture ?: return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            while (bounds.outWidth / sample > 512 || bounds.outHeight / sample > 512) sample *= 2
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
            bitmap.recycle()
            output.toByteArray()
        } catch (_: Exception) { null } finally { runCatching { retriever.release() } }
    }

    @Synchronized
    private fun notificationArtwork(uri: String): String {
        val directory = File(cacheDir, "media-art-original").apply { mkdirs() }
        val key = MessageDigest.getInstance("SHA-256").digest(uri.toByteArray())
            .joinToString("") { "%02x".format(it) }
        val file = File(directory, "$key.jpg")
        if (file.isFile && System.currentTimeMillis() - file.lastModified() < 3_600_000) return file.path
        val bytes = artwork(uri)
        if (bytes == null) {
            val fallback = File(directory, "navy.jpg")
            if (!fallback.isFile) {
                val bitmap = Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                canvas.drawColor(Color.rgb(10, 23, 48))
                getDrawable(R.drawable.ic_music_note)?.mutate()?.apply {
                    setTint(Color.rgb(143, 190, 255))
                    setBounds(88, 88, 168, 168)
                    draw(canvas)
                }
                fallback.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }
                bitmap.recycle()
            }
            return fallback.path
        }
        file.writeBytes(bytes)
        directory.listFiles()?.filter { it.name != "navy.jpg" }
            ?.sortedByDescending { it.lastModified() }?.drop(48)?.forEach { it.delete() }
        return file.path
    }
}
