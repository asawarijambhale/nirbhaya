package com.example.nirbhaya

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class WhisperForegroundService : Service() {

    companion object {
        const val TAG             = "WhisperService"
        const val CHANNEL_ID      = "panic_whisper_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START    = "ACTION_START_WHISPER"
        const val ACTION_STOP     = "ACTION_STOP_WHISPER"
        const val PREFS_NAME      = "whisper_prefs"
        const val KEY_CODEWORD    = "panic_codeword"
        const val FLUTTER_CHANNEL = "com.nirbhaya/whisper"

        fun start(context: Context) {
            val intent = Intent(context, WhisperForegroundService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, WhisperForegroundService::class.java).setAction(ACTION_STOP)
            )
        }
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.d(TAG, "Service created")
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
    }

    private fun startRecognition() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(recognitionListener)
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 0L)
        }
        speechRecognizer?.startListening(intent)
        isListening = true
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

    private fun getCodeword(): String {
        val prefs: SharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_CODEWORD, "") ?: ""
    }

    private fun checkAndTrigger(spoken: String) {
        val codeword = getCodeword()
        if (codeword.isBlank()) return
        if (KeywordDetector.matches(spoken, codeword)) {
            Log.d(TAG, "CODEWORD DETECTED: $spoken")
            notifyFlutter()
        }
    }

    private fun notifyFlutter() {
        val engine = FlutterEngineCache.getInstance().get("main_engine") ?: return
        handler.post {
            MethodChannel(engine.dartExecutor.binaryMessenger, FLUTTER_CHANNEL)
                .invokeMethod("onKeywordDetected", null)
        }
    }

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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Safety Monitor", NotificationManager.IMPORTANCE_MIN).apply {
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
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
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