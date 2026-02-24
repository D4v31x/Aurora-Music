package com.aurorasoftware.music

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val SAF_CHANNEL = "aurora/saf_write"
        private const val REQUEST_WRITE_PERMISSION = 42
    }

    // Holds state for a pending write that is waiting for the user to approve
    // the MediaStore.createWriteRequest system dialog.
    private data class PendingWrite(
        val tempPath: String,
        val mediaUri: Uri,
        val result: MethodChannel.Result,
    )
    private var pendingWrite: PendingWrite? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable edge-to-edge display for Android 15+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeFileViaMediaStore" -> {
                        val tempPath = call.argument<String>("tempPath")
                        val originalPath = call.argument<String>("originalPath")
                        if (tempPath == null || originalPath == null) {
                            result.error("INVALID_ARGS", "tempPath and originalPath are required", null)
                            return@setMethodCallHandler
                        }
                        handleWriteRequest(tempPath, originalPath, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Entry point for a write request.
     *
     * On API 30+ (Android 11+): resolve the MediaStore URI, then launch
     * [MediaStore.createWriteRequest] so the system shows the "Allow edit?"
     * dialog. The actual write happens in [onActivityResult] after approval.
     *
     * On API 29 (Android 10): attempt a direct write; if it throws a
     * SecurityException, fall back to createWriteRequest.
     */
    private fun handleWriteRequest(
        tempPath: String,
        originalPath: String,
        result: MethodChannel.Result,
    ) {
        try {
            val tempFile = File(tempPath)
            if (!tempFile.exists()) {
                result.error("INVALID_ARGS", "Temp file not found: $tempPath", null)
                return
            }

            val mediaUri = getMediaUriForPath(originalPath)
            if (mediaUri == null) {
                result.error(
                    "WRITE_FAILED",
                    "Could not resolve MediaStore URI for: $originalPath",
                    null
                )
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // API 30+ – always use createWriteRequest
                launchWriteRequest(tempPath, mediaUri, result)
            } else {
                // API 29 – try direct write; fall back on SecurityException
                try {
                    doWrite(tempPath, mediaUri)
                    result.success(null)
                } catch (se: SecurityException) {
                    launchWriteRequest(tempPath, mediaUri, result)
                }
            }
        } catch (e: Exception) {
            result.error("WRITE_FAILED", e.message, null)
        }
    }

    /**
     * Shows the system "Allow Aurora Music to modify this file?" dialog via
     * [MediaStore.createWriteRequest].
     */
    @Suppress("DEPRECATION")
    private fun launchWriteRequest(
        tempPath: String,
        mediaUri: Uri,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error("WRITE_FAILED", "createWriteRequest requires API 30+", null)
            return
        }
        pendingWrite = PendingWrite(tempPath, mediaUri, result)
        val intentSender = MediaStore.createWriteRequest(contentResolver, listOf(mediaUri))
        startIntentSenderForResult(intentSender.intentSender, REQUEST_WRITE_PERMISSION, null, 0, 0, 0)
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_WRITE_PERMISSION) {
            val pw = pendingWrite
            pendingWrite = null
            if (pw == null) return

            if (resultCode == Activity.RESULT_OK) {
                try {
                    doWrite(pw.tempPath, pw.mediaUri)
                    pw.result.success(null)
                } catch (e: Exception) {
                    pw.result.error("WRITE_FAILED", e.message, null)
                }
            } else {
                pw.result.error(
                    "PERMISSION_DENIED",
                    "User denied write access to the media file",
                    null
                )
            }
        }
    }

    /**
     * Performs the actual binary copy from [tempPath] into [mediaUri].
     * Caller must ensure write access has already been granted.
     */
    private fun doWrite(tempPath: String, mediaUri: Uri) {
        // "rwt" = read+write, truncate – binary safe
        contentResolver.openOutputStream(mediaUri, "rwt")?.use { out ->
            FileInputStream(File(tempPath)).use { input -> input.copyTo(out) }
        } ?: throw IllegalStateException("Could not open output stream for URI: $mediaUri")
    }

    /**
     * Resolves a MediaStore content URI from a filesystem path.
     */
    private fun getMediaUriForPath(path: String): Uri? {
        val projection = arrayOf(MediaStore.Audio.Media._ID)
        val selection = "${MediaStore.Audio.Media.DATA} = ?"
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection, selection, arrayOf(path), null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                return Uri.withAppendedPath(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id.toString()
                )
            }
        }
        return null
    }
}
