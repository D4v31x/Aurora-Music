package com.aurorasoftware.music

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val SAF_CHANNEL = "aurora/saf_write"
        private const val MEDIA_ACTIONS_CHANNEL = "aurora/media_actions"
        private const val VISUALIZER_CHANNEL = "aurora/visualizer"
        private const val REQUEST_WRITE_PERMISSION = 42
        private const val REQUEST_DELETE_PERMISSION = 43
    }

    // Holds state for a pending write that is waiting for the user to approve
    // the MediaStore.createWriteRequest system dialog.
    private data class PendingWrite(
        val tempPath: String,
        val mediaUri: Uri,
        val result: MethodChannel.Result,
    )
    private var pendingWrite: PendingWrite? = null

    // Holds state for a pending delete awaiting MediaStore.createDeleteRequest approval.
    private var pendingDeleteResult: MethodChannel.Result? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_ACTIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAsRingtone" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "path is required", null)
                            return@setMethodCallHandler
                        }
                        handleSetRingtone(path, result)
                    }
                    "deleteSong" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "path is required", null)
                            return@setMethodCallHandler
                        }
                        handleDeleteSong(path, result)
                    }
                    else -> result.notImplemented()
                }
            }

        setupVisualizerChannel(flutterEngine)
    }

    /**
     * Streams FFT magnitude data from the Android [Visualizer] API to Dart.
     *
     * The Dart side passes the audio session ID as the [EventChannel] stream
     * argument. When the stream is cancelled the Visualizer is released.
     */
    private fun setupVisualizerChannel(flutterEngine: FlutterEngine) {
        val mainHandler = Handler(Looper.getMainLooper())
        var activeVisualizer: Visualizer? = null

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    activeVisualizer?.release()
                    activeVisualizer = null

                    val sessionId = when (arguments) {
                        is Int  -> arguments
                        is Long -> arguments.toInt()
                        else    -> 0
                    }

                    try {
                        val capSize = try {
                            Visualizer.getCaptureSizeRange()[1]
                        } catch (_: Exception) {
                            1024
                        }
                        activeVisualizer = Visualizer(sessionId).apply {
                            captureSize = capSize
                            setDataCaptureListener(
                                object : Visualizer.OnDataCaptureListener {
                                    override fun onWaveFormDataCapture(
                                        v: Visualizer, waveform: ByteArray, samplingRate: Int
                                    ) { /* waveform mode removed */ }
                                    override fun onFftDataCapture(
                                        v: Visualizer, fft: ByteArray, samplingRate: Int
                                    ) {
                                        // Prefix 0x01 = FFT complex-pair data
                                        val copy = ByteArray(fft.size + 1)
                                        copy[0] = 1
                                        fft.copyInto(copy, destinationOffset = 1)
                                        mainHandler.post { events?.success(copy) }
                                    }
                                },
                                Visualizer.getMaxCaptureRate(),
                                false, /* waveform — not used */
                                true   /* fft */
                            )
                            enabled = true
                        }
                    } catch (e: Exception) {
                        events?.error("VISUALIZER_ERROR", e.message ?: "Visualizer init failed", null)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    activeVisualizer?.release()
                    activeVisualizer = null
                }
            })
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
        when (requestCode) {
            REQUEST_WRITE_PERMISSION -> {
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
            REQUEST_DELETE_PERMISSION -> {
                val res = pendingDeleteResult
                pendingDeleteResult = null
                if (resultCode == Activity.RESULT_OK) {
                    res?.success(null)
                } else {
                    res?.error("PERMISSION_DENIED", "User denied delete permission", null)
                }
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

    // -------------------------------------------------------------------------
    // Ringtone: set a song as the default phone ringtone
    // -------------------------------------------------------------------------

    private fun handleSetRingtone(path: String, result: MethodChannel.Result) {
        // On Android 6+ we need WRITE_SETTINGS (a special permission that is
        // not granted as a runtime permission — the user must enable it in Settings).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.System.canWrite(this)
        ) {
            // Open the "Modify system settings" page for the app so the user
            // can grant the permission, then return PERMISSION_NEEDED so the
            // Dart side can show a guiding snackbar.
            val intent = Intent(
                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
            result.error("PERMISSION_NEEDED", "WRITE_SETTINGS permission required", null)
            return
        }

        try {
            val mediaUri = getMediaUriForPath(path)
                ?: run {
                    result.error("NOT_FOUND", "Could not locate song in MediaStore: $path", null)
                    return
                }

            // Mark the file as a ringtone in MediaStore so the system accepts it.
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.IS_RINGTONE, true)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                put(MediaStore.Audio.Media.IS_ALARM, false)
                put(MediaStore.Audio.Media.IS_MUSIC, false)
            }
            contentResolver.update(mediaUri, values, null, null)

            RingtoneManager.setActualDefaultRingtoneUri(
                this,
                RingtoneManager.TYPE_RINGTONE,
                mediaUri
            )
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_RINGTONE_FAILED", e.message, null)
        }
    }

    // -------------------------------------------------------------------------
    // Delete: remove a song from the device via MediaStore
    // -------------------------------------------------------------------------

    private fun handleDeleteSong(path: String, result: MethodChannel.Result) {
        try {
            val mediaUri = getMediaUriForPath(path)
                ?: run {
                    result.error("NOT_FOUND", "Could not locate song in MediaStore: $path", null)
                    return
                }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+: createDeleteRequest shows the system confirmation dialog.
                pendingDeleteResult = result
                val intentSender =
                    MediaStore.createDeleteRequest(contentResolver, listOf(mediaUri))
                startIntentSenderForResult(
                    intentSender.intentSender, REQUEST_DELETE_PERMISSION, null, 0, 0, 0
                )
            } else {
                // Android 10 and below: direct delete via ContentResolver.
                val deleted = contentResolver.delete(mediaUri, null, null)
                if (deleted > 0) {
                    result.success(null)
                } else {
                    result.error("DELETE_FAILED", "ContentResolver.delete returned 0 rows", null)
                }
            }
        } catch (e: Exception) {
            result.error("DELETE_FAILED", e.message, null)
        }
    }
}
