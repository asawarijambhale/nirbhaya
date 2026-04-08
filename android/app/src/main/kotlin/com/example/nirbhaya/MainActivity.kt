package com.example.nirbhaya

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SmsManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SMS_CHANNEL        = "com.nirbhaya/sos_sms"
    private val WHISPER_CHANNEL    = "com.nirbhaya/whisper"
    private val VOLUME_SOS_CHANNEL = "com.nirbhaya/volume_sos"
    private val ENGINE_ID          = "main_engine"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)

        // ── SMS channel ───────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSMS" -> {
                        val phone   = call.argument<String>("phone")
                        val message = call.argument<String>("message")
                        if (phone != null && message != null) {
                            try { sendSMS(phone, message); result.success(true) }
                            catch (e: Exception) { result.error("SEND_SMS_ERROR", e.message, null) }
                        } else {
                            result.error("INVALID_ARGS", "Phone or message is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Whisper channel — codeword detection only ─────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WHISPER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val codeword = call.argument<String>("codeword") ?: ""
                        val contacts = call.argument<String>("contacts") ?: ""
                        saveToPrefs(WhisperForegroundService.KEY_CODEWORD,
                            codeword.trim().lowercase())
                        saveToPrefs(WhisperForegroundService.KEY_CONTACTS, contacts)
                        WhisperForegroundService.start(this)
                        result.success(true)
                    }
                    "stopService" -> {
                        WhisperForegroundService.stop(this)
                        result.success(true)
                    }
                    "updateCodeword" -> {
                        saveToPrefs(WhisperForegroundService.KEY_CODEWORD,
                            (call.argument<String>("codeword") ?: "").trim().lowercase())
                        result.success(true)
                    }
                    "updateContacts" -> {
                        saveToPrefs(WhisperForegroundService.KEY_CONTACTS,
                            call.argument<String>("contacts") ?: "")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Volume SOS channel — volume button detection only ─────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_SOS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolumeSosEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        saveBoolToPrefs(VolumeSosForegroundService.KEY_ENABLED, enabled)
                        if (enabled) {
                            // Also sync contacts so the service can send SMS natively
                            VolumeSosForegroundService.start(this)
                        } else {
                            VolumeSosForegroundService.stop(this)
                        }
                        android.util.Log.d("MainActivity", "Volume SOS enabled=$enabled")
                        result.success(true)
                    }
                    "requestBatteryOptimizationExemption" -> {
                        requestBatteryOptimizationExemption()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Battery optimisation ──────────────────────────────────────────────

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
            )
        } catch (e: Exception) {
            try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
            catch (_: Exception) {}
        }
    }

    // ── Volume key interception (foreground) ──────────────────────────────
    // MediaSession in VolumeSosForegroundService handles background/locked.
    // onKeyDown handles foreground — both feed the same VolumeSosDetector.

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (!isVolumeSosEnabled()) return super.onKeyDown(keyCode, event)
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                android.util.Log.d("MainActivity", "Vol UP (foreground)")
                VolumeSosForegroundService.sendVolumeUp(this)
                true // consume — suppress system volume UI
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                android.util.Log.d("MainActivity", "Vol DOWN (foreground)")
                VolumeSosForegroundService.sendVolumeDown(this)
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }

    // ── SharedPreferences helpers ─────────────────────────────────────────

    private fun saveToPrefs(key: String, value: String) {
        getSharedPreferences(WhisperForegroundService.PREFS_NAME, MODE_PRIVATE)
            .edit().putString(key, value).apply()
    }

    private fun saveBoolToPrefs(key: String, value: Boolean) {
        getSharedPreferences(WhisperForegroundService.PREFS_NAME, MODE_PRIVATE)
            .edit().putBoolean(key, value).apply()
    }

    private fun isVolumeSosEnabled(): Boolean =
        getSharedPreferences(WhisperForegroundService.PREFS_NAME, MODE_PRIVATE)
            .getBoolean(VolumeSosForegroundService.KEY_ENABLED, false)

    // ── SMS helper ────────────────────────────────────────────────────────

    private fun sendSMS(phone: String, message: String) {
        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            getSystemService(SmsManager::class.java)
        else @Suppress("DEPRECATION") SmsManager.getDefault()

        val parts = smsManager.divideMessage(message)
        val sentIntents = ArrayList<PendingIntent>()
        for (i in parts.indices) {
            sentIntents.add(
                PendingIntent.getBroadcast(
                    this, i, Intent("SMS_SENT_$i"),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        for (i in parts.indices) {
            smsManager.sendTextMessage(phone, null, parts[i], sentIntents.getOrNull(i), null)
        }
        android.util.Log.d("SOS_SMS", "SMS sent to $phone")
    }
}
