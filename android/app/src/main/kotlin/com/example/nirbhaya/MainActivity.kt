package com.example.nirbhaya

import android.app.PendingIntent
import android.content.Intent
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nirbhaya/sos_sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSMS" -> {
                        val phone = call.argument<String>("phone")
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
    }

    private fun sendSMS(phone: String, message: String) {
        try {
            val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // For long messages, split into multiple parts
            val parts: ArrayList<String> = smsManager.divideMessage(message)
            val sentIntents: ArrayList<PendingIntent> = ArrayList()

            for (i in parts.indices) {
                val sentIntent = Intent("SMS_SENT_$i")
                val sentPendingIntent = PendingIntent.getBroadcast(
                    this,
                    i,
                    sentIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                sentIntents.add(sentPendingIntent)
            }

            // Use sendTextMessage for each part (more compatible approach)
            for (i in parts.indices) {
                smsManager.sendTextMessage(phone, null, parts[i], sentIntents.getOrNull(i), null)
            }

            android.util.Log.d("SOS_SMS", "SMS sent to $phone successfully")
        } catch (e: Exception) {
            android.util.Log.e("SOS_SMS", "Error sending SMS: ${e.message}")
            throw e
        }
    }
}
