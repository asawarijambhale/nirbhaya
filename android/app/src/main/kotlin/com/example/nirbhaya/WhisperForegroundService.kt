package com.example.nirbhaya

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Foreground service for Panic Whisper (codeword) detection only.
 * Volume Button SOS is handled by VolumeSosForegroundService — completely separate.
 */
class WhisperForegroundService : Service() {

    companion object {
        const val TAG             = "WhisperService"
        const val CHANNEL_ID      = "panic_whisper_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START    = "ACTION_START_WHISPER"
        const val ACTION_STOP     = "ACTION_STOP_WHISPER"
        const val PREFS_NAME      = "whisper_prefs"
        const val KEY_CODEWORD    = "panic_codeword"
        const val KEY_CONTACTS    = "emergency_contacts"
        const val FLUTTER_CHANNEL = "com.nirbhaya/whisper"
        const val COOLDOWN_MS     = 15_000L

        fun start(context: Context) {
            val intent = Intent(context, WhisperForegroundService::class.java)
                .setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, WhisperForegroundService::class.java)
                    .setAction(ACTION_STOP)
            )
        }
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private val handler = Handler(Looper.getMainLooper())
    private var lastTriggerTime = 0L

    private val fusedLocationClient by lazy {
        LocationServices.getFusedLocationProviderClient(this)
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.d(TAG, "WhisperForegroundService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startRecognition()
            ACTION_STOP  -> { stopRecognition(); stopSelf() }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopRecognition()
        super.onDestroy()
        Log.d(TAG, "WhisperForegroundService destroyed")
    }

    // ── Speech Recognition ────────────────────────────────────────────────

    private fun startRecognition() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.w(TAG, "Speech recognition not available on this device")
            return
        }
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(recognitionListener)
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 0L)
        }
        speechRecognizer?.startListening(intent)
        isListening = true
        Log.d(TAG, "Recognition started")
    }

    private fun stopRecognition() {
        handler.removeCallbacksAndMessages(null)
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
        isListening = false
    }

    private fun scheduleRestart() {
        handler.postDelayed({ if (!isListening) startRecognition() }, 1500L)
    }

    // ── Keyword Detection + Cooldown ──────────────────────────────────────

    private fun getCodeword(): String =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_CODEWORD, "") ?: ""

    private fun checkAndTrigger(spoken: String) {
        val codeword = getCodeword()
        if (codeword.isBlank()) return
        if (!KeywordDetector.matches(spoken, codeword)) return

        val now = System.currentTimeMillis()
        if (now - lastTriggerTime < COOLDOWN_MS) {
            Log.d(TAG, "Ignored due to cooldown. Spoken: $spoken")
            return
        }
        Log.d(TAG, "Keyword Detected: $spoken")
        lastTriggerTime = now
        triggerSOSNatively()
    }

    // ── Native SOS ────────────────────────────────────────────────────────

    private fun triggerSOSNatively() {
        Log.d(TAG, "SOS Triggered")

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val contactsRaw = prefs.getString(KEY_CONTACTS, "") ?: ""
        if (contactsRaw.isBlank()) {
            Log.w(TAG, "No contacts saved — cannot send SOS")
            notifyFlutter()
            return
        }

        val phones = contactsRaw.split(",")
            .map { it.trim() }.filter { it.isNotEmpty() }.distinct()

        fetchFreshLocation(
            onSuccess = { location ->
                val mapsLink = "https://maps.google.com/?q=${location.latitude},${location.longitude}"
                Log.d(TAG, "Location fetched: ${location.latitude}, ${location.longitude}")
                sendSMSToContacts(phones, mapsLink)
            },
            onFallback = {
                Log.d(TAG, "Fallback location used")
                val fallback = getLastKnownLocation()
                val mapsLink = if (fallback != null)
                    "https://maps.google.com/?q=${fallback.latitude},${fallback.longitude}"
                else "Location unavailable"
                sendSMSToContacts(phones, mapsLink)
            }
        )

        notifyFlutter()
    }

    private fun fetchFreshLocation(onSuccess: (Location) -> Unit, onFallback: () -> Unit) {
        try {
            val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
                .setMaxUpdates(1).setWaitForAccurateLocation(false).build()

            val callback = object : LocationCallback() {
                override fun onLocationResult(result: LocationResult) {
                    fusedLocationClient.removeLocationUpdates(this)
                    handler.removeCallbacksAndMessages("loc_timeout")
                    result.lastLocation?.let { onSuccess(it) } ?: onFallback()
                }
            }
            fusedLocationClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
            handler.postAtTime({
                fusedLocationClient.removeLocationUpdates(callback)
                onFallback()
            }, "loc_timeout", android.os.SystemClock.uptimeMillis() + 5_000L)
        } catch (e: SecurityException) {
            Log.w(TAG, "Location permission denied: ${e.message}"); onFallback()
        } catch (e: Exception) {
            Log.w(TAG, "fetchFreshLocation error: ${e.message}"); onFallback()
        }
    }

    private fun getLastKnownLocation(): Location? {
        return try {
            var result: Location? = null
            fusedLocationClient.lastLocation.addOnSuccessListener { loc -> result = loc }
            Thread.sleep(500)
            result
        } catch (e: Exception) {
            Log.w(TAG, "getLastKnownLocation error: ${e.message}")
            null
        }
    }

    private fun sendSMSToContacts(phones: List<String>, mapsLink: String) {
        val message = "SOS! I need help. My location: $mapsLink"
        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            getSystemService(SmsManager::class.java)
        else @Suppress("DEPRECATION") SmsManager.getDefault()

        for (phone in phones) {
            try {
                smsManager.sendTextMessage(phone, null, message, null, null)
                Log.d(TAG, "SMS sent to $phone")
            } catch (e: Exception) {
                Log.e(TAG, "SMS failed to $phone: ${e.message}")
            }
        }
    }

    private fun notifyFlutter() {
        val engine = FlutterEngineCache.getInstance().get("main_engine") ?: return
        handler.post {
            MethodChannel(engine.dartExecutor.binaryMessenger, FLUTTER_CHANNEL)
                .invokeMethod("onKeywordDetected", null)
        }
    }

    // ── RecognitionListener ───────────────────────────────────────────────

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: android.os.Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: android.os.Bundle?) {}

        override fun onPartialResults(partialResults: android.os.Bundle?) {
            partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()?.let { checkAndTrigger(it) }
        }

        override fun onResults(results: android.os.Bundle?) {
            results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()?.let { checkAndTrigger(it) }
            isListening = false
            scheduleRestart()
        }

        override fun onError(error: Int) {
            Log.w(TAG, "Recognition error: $error")
            isListening = false
            speechRecognizer?.destroy()
            speechRecognizer = null
            scheduleRestart()
        }
    }

    // ── Notification ──────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Safety Monitor", NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Nirbhaya safety monitoring"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nirbhaya Protection Active")
            .setContentText("Safety monitoring is running")
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(openIntent)
            .build()
    }
}
