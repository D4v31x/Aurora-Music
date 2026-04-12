package com.aurorasoftware.music

import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.ContentValues
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.view.WindowCompat
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val SAF_CHANNEL = "aurora/saf_write"
        private const val MEDIA_ACTIONS_CHANNEL = "aurora/media_actions"
        private const val AUDIO_OUTPUT_CHANNEL = "com.aurorasoftware.music/audio_output"
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_OUTPUT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getActiveOutput" -> {
                        result.success(getActiveAudioOutput())
                    }
                    "switchOutput" -> {
                        val type = call.argument<String>("type")
                        if (type == null) {
                            result.error("INVALID_ARGS", "type is required", null)
                            return@setMethodCallHandler
                        }
                        val success = switchAudioOutput(type)
                        result.success(success)
                    }
                    "getBluetoothBattery" -> {
                        result.success(getBluetoothBatteryLevel())
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

    // -------------------------------------------------------------------------
    // Audio output: query active output and switch between devices
    // -------------------------------------------------------------------------

    private fun getActiveAudioOutput(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in devices) {
                if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                ) {
                    return device.productName?.toString() ?: "bluetooth"
                }
            }
            for (device in devices) {
                if (device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    device.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
                ) {
                    return "wired"
                }
            }
        }
        return "phone_speaker"
    }

    /**
     * Returns the battery level (0–100) of the connected Bluetooth audio
     * device, or -1 if unavailable.
     *
     * Tries multiple approaches since OEM support varies:
     * 1. BluetoothDevice.getBatteryLevel() via reflection (hidden API)
     * 2. BluetoothDevice.getMetadata(METADATA_UNTOKENIZED_BATTERY_LEVEL) (API 28+)
     */
    @Suppress("MissingPermission")
    private fun getBluetoothBatteryLevel(): Int {
        try {
            val btManager = getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager
                ?: return -1
            val adapter = btManager.adapter ?: return -1
            val bondedDevices = adapter.bondedDevices ?: return -1

            // Also check which BT audio device is actually connected right now.
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            val outputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val hasBtAudio = outputDevices.any {
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                    (it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                     it.type == AudioDeviceInfo.TYPE_BLE_SPEAKER))
            }
            if (!hasBtAudio) return -1

            for (device in bondedDevices) {
                try {
                    val isConnected = device.javaClass
                        .getMethod("isConnected")
                        .invoke(device) as? Boolean ?: false
                    if (!isConnected) continue

                    // Approach 1: hidden getBatteryLevel() API
                    try {
                        val battery = device.javaClass
                            .getMethod("getBatteryLevel")
                            .invoke(device) as? Int ?: -1
                        if (battery in 0..100) return battery
                    } catch (_: Exception) {}

                    // Approach 2: getMetadata with METADATA_UNTOKENIZED_BATTERY_LEVEL (API 28+)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        try {
                            // METADATA_UNTOKENIZED_BATTERY_LEVEL = 6
                            val metaBytes = device.javaClass
                                .getMethod("getMetadata", Int::class.java)
                                .invoke(device, 6) as? ByteArray
                            if (metaBytes != null) {
                                val level = String(metaBytes).trim().toIntOrNull()
                                if (level != null && level in 0..100) return level
                            }
                        } catch (_: Exception) {}
                    }
                } catch (_: Exception) {
                    // Reflection may fail on some OEMs — skip this device.
                }
            }
        } catch (_: Exception) {}
        return -1
    }

    /// Find the ExoPlayer instance from the just_audio plugin via reflection,
    /// then call setPreferredAudioDevice(). This is the only reliable way to
    /// route *media* audio to a specific device — AudioManager APIs like
    /// setCommunicationDevice only affect the communication audio stream.
    private fun switchAudioOutput(type: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false

        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val outputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

        // Explicitly resolve the target AudioDeviceInfo for every device type.
        // Passing null to setPreferredAudioDevice kills the current AudioTrack
        // without giving ExoPlayer a concrete device to recreate it on, so we
        // always pass an explicit device when one is connected.
        val targetDevice: AudioDeviceInfo? = when (type) {
            "phone" -> {
                outputDevices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            }
            "bluetooth" -> {
                outputDevices.firstOrNull {
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                }
            }
            "wiredHeadset" -> {
                outputDevices.firstOrNull {
                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
                }
            }
            "usb" -> {
                outputDevices.firstOrNull {
                    it.type == AudioDeviceInfo.TYPE_USB_DEVICE ||
                    it.type == AudioDeviceInfo.TYPE_USB_HEADSET
                }
            }
            else -> null
        }

        return try {
            val player = findExoPlayer()

            if (player != null) {
                // ExoPlayer must be accessed on the main looper thread (where
                // just_audio creates it).
                val mainHandler = Handler(Looper.getMainLooper())
                mainHandler.post {
                    try {
                        val wasPlaying = player.isPlaying
                        val pos = player.currentPosition

                        // Just set the preferred device — ExoPlayer will
                        // internally recreate its AudioTrack on the new route.
                        // Avoiding stop()+clearMediaItems() prevents the
                        // "dead IAudioTrack" cascade that kills playback when
                        // switching back to a previously active device.
                        player.setPreferredAudioDevice(targetDevice)

                        // If the device switch causes a transient AudioTrack
                        // error (ERROR_DEAD_OBJECT / write -6), ExoPlayer marks
                        // it as a "recoverable renderer error" and recreates
                        // the renderer. Give it a moment to settle, then ensure
                        // playback resumes at the correct position.
                        mainHandler.postDelayed({
                            try {
                                if (wasPlaying && !player.isPlaying) {
                                    player.seekTo(player.currentMediaItemIndex, pos)
                                    player.prepare()
                                    player.play()
                                }
                            } catch (_: Exception) {}
                        }, 300)
                    } catch (_: Exception) {
                        // Best-effort; if the player is released this is harmless.
                    }
                }
                true
            } else {
                // Fallback: use setCommunicationDevice (less reliable for media)
                fallbackRoutingViaCommunicationDevice(type, targetDevice, audioManager)
            }
        } catch (e: Exception) {
            // Last-resort fallback
            try {
                fallbackRoutingViaCommunicationDevice(type, targetDevice, audioManager)
            } catch (_: Exception) {
                false
            }
        }
    }

    /// Locate the just_audio ExoPlayer instance via the plugin's private fields.
    private fun findExoPlayer(): ExoPlayer? {
        val engine = flutterEngine ?: return null
        try {
            // just_audio registers as "com.ryanheise.just_audio" in the Flutter plugin registry.
            val plugin = engine.plugins.get(com.ryanheise.just_audio.JustAudioPlugin::class.java)
                ?: return null

            // JustAudioPlugin -> MainMethodCallHandler methodCallHandler
            val handlerField = plugin.javaClass.getDeclaredField("methodCallHandler")
            handlerField.isAccessible = true
            val handler = handlerField.get(plugin) ?: return null

            // MainMethodCallHandler -> Map<String, AudioPlayer> players
            val playersField = handler.javaClass.getDeclaredField("players")
            playersField.isAccessible = true
            @Suppress("UNCHECKED_CAST")
            val players = playersField.get(handler) as? Map<String, *> ?: return null

            // Get the first (usually only) AudioPlayer
            val audioPlayer = players.values.firstOrNull() ?: return null

            // AudioPlayer -> ExoPlayer player
            val playerField = audioPlayer.javaClass.getDeclaredField("player")
            playerField.isAccessible = true
            return playerField.get(audioPlayer) as? ExoPlayer
        } catch (e: Exception) {
            return null
        }
    }

    /// Fallback for pre-M devices or when reflection fails.
    @Suppress("DEPRECATION")
    private fun fallbackRoutingViaCommunicationDevice(
        type: String,
        targetDevice: AudioDeviceInfo?,
        audioManager: AudioManager,
    ): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && targetDevice != null) {
            audioManager.setCommunicationDevice(targetDevice)
            return true
        }
        // Pre-S deprecated approach
        when (type) {
            "phone" -> {
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                audioManager.isSpeakerphoneOn = true
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
            }
            "bluetooth" -> {
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                audioManager.isSpeakerphoneOn = false
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
            }
            else -> {
                audioManager.mode = AudioManager.MODE_NORMAL
                audioManager.isSpeakerphoneOn = false
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
            }
        }
        return true
    }
}
