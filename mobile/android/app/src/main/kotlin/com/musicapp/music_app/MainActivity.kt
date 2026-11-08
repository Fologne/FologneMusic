package com.musicapp.music_app

import android.Manifest
import android.app.RecoverableSecurityException
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
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.nio.file.attribute.BasicFileAttributes
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val worker = Executors.newFixedThreadPool(2)
    private val pendingShares = ArrayDeque<String>()
    private var shareChannel: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null
    private var pendingDelete: Pair<Uri, MethodChannel.Result>? = null
    private val audioPermission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE

    override fun onCreate(savedInstanceState: Bundle?) {
        val sharedIntent = intent
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) receiveShare(sharedIntent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receiveShare(intent)
    }

    private fun receiveShare(intent: Intent) {
        if (intent.action != Intent.ACTION_SEND || intent.type != "text/plain") return
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?: intent.clipData?.getItemAt(0)?.text
        if (pendingShares.size == 8) pendingShares.removeFirst()
        pendingShares.addLast(text?.take(8192)?.toString().orEmpty())
        shareChannel?.invokeMethod("shareAvailable", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerAudioDownloads(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "musicapp/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") result.success(pendingShares.removeFirstOrNull())
                else result.notImplemented()
            }
        }
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
                "deleteTrack" -> deleteTrack(call.argument<String>("uri"), result)
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
        if (requestCode == 403) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) deletePendingTrack()
            else finishDelete(false)
        }
    }

    @Suppress("DEPRECATION")
    private fun deleteTrack(value: String?, result: MethodChannel.Result) {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val id = value?.substringAfterLast('/')?.toLongOrNull()
        val uri = id?.let { ContentUris.withAppendedId(collection, it) }
        if (uri == null || id <= 0 || uri.toString() != value || pendingDelete != null) {
            result.error("delete_failed", "Arquivo inválido ou exclusão em andamento.", null)
            return
        }
        pendingDelete = uri to result
        try {
            when {
                Build.VERSION.SDK_INT >= 30 -> {
                    val request = MediaStore.createDeleteRequest(contentResolver, listOf(uri))
                    startIntentSenderForResult(request.intentSender, 402, null, 0, 0, 0)
                }
                Build.VERSION.SDK_INT <= 28 &&
                    checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED ->
                    requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 403)
                else -> deletePendingTrack()
            }
        } catch (_: Exception) {
            failDelete()
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            402 -> finishDelete(resultCode == RESULT_OK)
            404 -> if (resultCode == RESULT_OK) deletePendingTrack(allowConsent = false)
                   else finishDelete(false)
        }
    }

    @Suppress("DEPRECATION")
    private fun deletePendingTrack(allowConsent: Boolean = true) {
        val uri = pendingDelete?.first ?: return
        worker.execute {
            try {
                val deleted = contentResolver.delete(uri, null, null) > 0
                runOnUiThread { finishDelete(deleted) }
            } catch (error: Exception) {
                runOnUiThread {
                    if (allowConsent && Build.VERSION.SDK_INT == 29 && error is RecoverableSecurityException) {
                        try {
                            startIntentSenderForResult(
                                error.userAction.actionIntent.intentSender, 404, null, 0, 0, 0
                            )
                        } catch (_: Exception) {
                            failDelete()
                        }
                    } else failDelete()
                }
            }
        }
    }

    private fun finishDelete(deleted: Boolean) {
        val result = pendingDelete?.second
        pendingDelete = null
        result?.success(deleted)
    }

    private fun failDelete() {
        val result = pendingDelete?.second
        pendingDelete = null
        result?.error("delete_failed", "Não foi possível apagar o arquivo.", null)
    }

    private fun scanAudio(): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val folderColumn = if (Build.VERSION.SDK_INT >= 29) MediaStore.Audio.Media.RELATIVE_PATH else MediaStore.Audio.Media.DATA
        val columns = listOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.DISPLAY_NAME, MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM, MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED, MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.DATA, folderColumn).distinct().toTypedArray()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        contentResolver.query(collection, columns, "${MediaStore.Audio.Media.SIZE} > 0", null, "${MediaStore.Audio.Media.TITLE} ASC")?.use { cursor ->
            fun text(column: String): String = cursor.getString(cursor.getColumnIndexOrThrow(column))?.trim().orEmpty()
            fun known(value: String, fallback: String) = if (value.isBlank() || value == "<unknown>") fallback else value
            while (cursor.moveToNext()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                val duration = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)).coerceAtLeast(0)
                val rawFolder = text(folderColumn)
                val folder = if (Build.VERSION.SDK_INT >= 29) rawFolder.trimEnd('/') else rawFolder.substringBeforeLast('/', "Music")
                val createdAt = creationTime(text(MediaStore.Audio.Media.DATA))
                    ?: cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)) * 1000
                rows.add(mapOf(
                    "id" to ContentUris.withAppendedId(collection, id).toString(),
                    "title" to known(text(MediaStore.Audio.Media.TITLE), known(text(MediaStore.Audio.Media.DISPLAY_NAME), "Sem título")),
                    "artist" to known(text(MediaStore.Audio.Media.ARTIST), "Artista desconhecido"),
                    "album" to known(text(MediaStore.Audio.Media.ALBUM), "Álbum desconhecido"),
                    "durationMs" to duration,
                    "folder" to known(folder, "Music"),
                    "addedAt" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)) * 1000,
                    "createdAt" to createdAt,
                    "available" to true
                ))
            }
        }
        return rows
    }

    private fun creationTime(path: String): Long? {
        if (Build.VERSION.SDK_INT < 26 || path.isBlank()) return null
        return runCatching {
            Files.readAttributes(File(path).toPath(), BasicFileAttributes::class.java)
                .creationTime().toMillis().takeIf { it > 0 }
        }.getOrNull()
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
