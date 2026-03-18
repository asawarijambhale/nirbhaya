package com.example.nirbhaya

import android.app.PendingIntent
import android.content.Intent
import android.content.SharedPreferences
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SMS_CHANNEL     = "com.nirbhaya/sos_sms"
    private val WHISPER_CHANNEL = "com.nirbhaya/whisper"
    private val ENGINE_ID       = "main_engine"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache engine so WhisperForegroundService can reach it
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)

        // ── SMS channel (existing) ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSMS" -> {
                        val phone   = call.argument<String>("phone")
                        val message = call.argument<String>("message")
                        if (phone != null && message != null) {
                            try {
                                sendSMS(phone, message)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SEND_SMS_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Phone or message is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Whisper channel (new) ─────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WHISPER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Flutter → Native: start the foreground service
                    "startService" -> {
                        val codeword = call.argument<String>("codeword") ?: ""
                        saveCodeword(codeword)
                        WhisperForegroundService.start(this)
                        result.success(true)
                    }
                    // Flutter → Native: stop the foreground service
                    "stopService" -> {
                        WhisperForegroundService.stop(this)
                        result.success(true)
                    }
                    // Flutter → Native: update codeword without restarting
                    "updateCodeword" -> {
                        val codeword = call.argument<String>("codeword") ?: ""
                        saveCodeword(codeword)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Persist codeword in SharedPreferences so the service can read it. */
    private fun saveCodeword(codeword: String) {
        val prefs: SharedPreferences = getSharedPreferences(
            WhisperForegroundService.PREFS_NAME, MODE_PRIVATE
        )
        prefs.edit().putString(WhisperForegroundService.KEY_CODEWORD,
            codeword.trim().lowercase()).apply()
    }

    // ── SMS helper (unchanged) ────────────────────────────────────────────────

    private fun sendSMS(phone: String, message: String) {
        try {
            val smsManager: SmsManager =
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                    getSystemService(SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }

            val parts: ArrayList<String> = smsManager.divideMessage(message)
            val sentIntents: ArrayList<PendingIntent> = ArrayList()

            for (i in parts.indices) {
                val sentIntent = Intent("SMS_SENT_$i")
                val sentPendingIntent = PendingIntent.getBroadcast(
                    this, i, sentIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                sentIntents.add(sentPendingIntent)
            }

            for (i in parts.indices) {
                smsManager.sendTextMessage(
                    phone, null, parts[i], sentIntents.getOrNull(i), null
                )
            }

            android.util.Log.d("SOS_SMS", "SMS sent to $phone successfully")
        } catch (e: Exception) {
            android.util.Log.e("SOS_SMS", "Error sending SMS: ${e.message}")
            throw e
        }
    }
}
