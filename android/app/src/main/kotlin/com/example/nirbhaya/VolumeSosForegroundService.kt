package com.example.nirbhaya

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.support.v4.media.session.PlaybackStateCompat
import androidx.media.session.MediaButtonReceiver
import android.support.v4.media.session.MediaSessionCompat
import android.telephony.SmsManager
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Dedicated foreground service for Volume Button SOS detection.
 *
 * Completely separate from WhisperForegroundService (codeword detection).
 * Uses its own notification channel, MediaSession, WakeLock, and Flutter channel.
 *
 * Detection mechanism:
 *   MediaSessionCompat with FLAG_HANDLES_MEDIA_BUTTONS — the only reliable
 *   way to intercept hardware volume keys in background, locked screen, and
 *   screen-off states. Android's AudioManager routes key events to the active
 *   MediaSession before the system processes them for volume control.
 *
 * Pattern: UP → DOWN → UP (exactly 3 presses within 2 seconds, no extras)
 */
class VolumeSosForegroundService : Service() {

    companion object {
        const val TAG             = "VolumeSosService"
        const val CHANNEL_ID      = "volume_sos_channel"
        const val NOTIFICATION_ID = 1002
        const val ACTION_START    = "ACTION_START_VOLUME_SOS"
        const val ACTION_STOP     = "ACTION_STOP_VOLUME_SOS"
        // Foreground volume events forwarded from MainActivity.onKeyDown
        const val ACTION_VOL_UP   = "ACTION_VOL_UP_FG"
        const val ACTION_VOL_DOWN = "ACTION_VOL_DOWN_FG"
        const val PREFS_NAME      = "whisper_prefs"   // shared prefs file
        const val KEY_CONTACTS    = "emergency_contacts"
        const val KEY_ENABLED     = "volume_sos_enabled"
        const val FLUTTER_CHANNEL = "com.nirbhaya/volume_sos"
        const val COOLDOWN_MS     = 15_000L

        fun start(context: Context) {
            val intent = Intent(context, VolumeSosForegroundService::class.java)
                .setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, VolumeSosForegroundService::class.java)
                    .setAction(ACTION_STOP)
            )
        }

        fun sendVolumeUp(context: Context) {
            context.startService(
                Intent(context, VolumeSosForegroundService::class.java)
                    .setAction(ACTION_VOL_UP)
            )
        }

        fun sendVolumeDown(context: Context) {
            context.startService(
                Intent(context, VolumeSosForegroundService::class.java)
                    .setAction(ACTION_VOL_DOWN)
            )
        }
    }

    // ── Fields ────────────────────────────────────────────────────────────

    private val handler = Handler(Looper.getMainLooper())
    private var lastTriggerTime = 0L
    private var mediaSession: MediaSessionCompat? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioFocusRequest: AudioFocusRequest? = null  // API 26+
    private val audioManager by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }

    private val fusedLocationClient by lazy {
        LocationServices.getFusedLocationProviderClient(this)
    }

    // Pattern detector — fires callback only when UP→DOWN→UP confirmed
    private val detector = VolumeSosDetector {
        Log.d(TAG, "✅ Pattern confirmed — checking cooldown")
        val now = System.currentTimeMillis()
        if (now - lastTriggerTime < COOLDOWN_MS) {
            Log.d(TAG, "Cooldown active — SOS suppressed")
            return@VolumeSosDetector
        }
        lastTriggerTime = now
        triggerSOS()
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        // MediaSession MUST be initialized before startForeground so the
        // notification carries the session token. Without the token in the
        // notification Android cannot route lock-screen key events here.
        acquireWakeLock()
        initMediaSession()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.d(TAG, "VolumeSosForegroundService created — MediaSession active")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: ${intent?.action}")

        // MediaButtonReceiver forwards lock-screen/background hardware key events
        // here as ACTION_MEDIA_BUTTON intents. Pass them into the MediaSession
        // so onMediaButtonEvent fires — this is the lock-screen detection path.
        if (intent?.action == Intent.ACTION_MEDIA_BUTTON) {
            mediaSession?.let { MediaButtonReceiver.handleIntent(it, intent) }
            return START_STICKY
        }

        when (intent?.action) {
            ACTION_START    -> Log.d(TAG, "Service started/resumed")
            ACTION_STOP     -> { releaseAll(); stopSelf(); return START_NOT_STICKY }
            ACTION_VOL_UP   -> {
                if (isEnabled()) {
                    Log.d(TAG, "Foreground Vol UP → detector")
                    detector.onVolumeUp()
                }
            }
            ACTION_VOL_DOWN -> {
                if (isEnabled()) {
                    Log.d(TAG, "Foreground Vol DOWN → detector")
                    detector.onVolumeDown()
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed — scheduling restart")
        val pending = PendingIntent.getService(
            applicationContext, 2,
            Intent(applicationContext, VolumeSosForegroundService::class.java)
                .setAction(ACTION_START),
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        (getSystemService(ALARM_SERVICE) as AlarmManager).set(
            AlarmManager.ELAPSED_REALTIME,
            android.os.SystemClock.elapsedRealtime() + 1_000L,
            pending
        )
    }

    override fun onDestroy() {
        releaseAll()
        super.onDestroy()
        Log.d(TAG, "VolumeSosForegroundService destroyed")
    }

    private fun releaseAll() {
        releaseMediaSession()
        releaseWakeLock()
        abandonAudioFocus()
    }

    // ── Enabled check ─────────────────────────────────────────────────────

    private fun isEnabled(): Boolean =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)

    // ── WakeLock ──────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "nirbhaya:VolumeSosWakeLock"
            ).also {
                it.setReferenceCounted(false)
                it.acquire(10 * 60 * 60 * 1000L) // 10 h max; refreshed on restart
            }
            Log.d(TAG, "WakeLock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock failed: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
            wakeLock = null
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock release error: ${e.message}")
        }
    }

    // ── Audio Focus ───────────────────────────────────────────────────────
    //
    // CRITICAL for background detection.
    // Android only routes volume key events to the MediaSession that currently
    // holds audio focus. Without requesting focus, any other app that played
    // audio last (YouTube, Spotify, etc.) keeps the focus and our session
    // never receives the key events when the app is in the background.
    //
    // We request AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK so we don't interrupt
    // actual media playback — we just need the routing, not the audio stream.

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            audioFocusRequest = AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener { /* no-op — we don't play audio */ }
                .build()
            audioManager.requestAudioFocus(audioFocusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                { /* no-op */ },
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
        }
        Log.d(TAG, "Audio focus requested")
    }

    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(null)
            }
            Log.d(TAG, "Audio focus abandoned")
        } catch (e: Exception) {
            Log.w(TAG, "abandonAudioFocus error: ${e.message}")
        }
    }

    // ── MediaSession ──────────────────────────────────────────────────────
    //
    // Three things are required for background volume key routing:
    //
    //  1. FLAG_HANDLES_MEDIA_BUTTONS — registers session as a media button target
    //  2. setPlaybackState(PLAYING) — Android only routes events to sessions
    //     with an active playback state. A session with no state or STATE_NONE
    //     is silently skipped even if isActive = true.
    //  3. Audio focus — Android routes volume keys to the focus holder.
    //     Without this, background apps lose routing to any other audio app.

    private fun initMediaSession() {
        requestAudioFocus()

        mediaSession = MediaSessionCompat(this, "NirbhayaVolumeSOS").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )

            // Set a fake PLAYING state — required for Android to route
            // media button events to this session in background/locked states.
            setPlaybackState(
                PlaybackStateCompat.Builder()
                    .setState(
                        PlaybackStateCompat.STATE_PLAYING,
                        PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN,
                        0f  // playback speed 0 — we're not actually playing anything
                    )
                    .setActions(
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE
                    )
                    .build()
            )

            setCallback(object : MediaSessionCompat.Callback() {
                override fun onMediaButtonEvent(mediaButtonEvent: Intent): Boolean {
                    val keyEvent: KeyEvent? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            mediaButtonEvent.getParcelableExtra(
                                Intent.EXTRA_KEY_EVENT, KeyEvent::class.java
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            mediaButtonEvent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                        }

                    if (keyEvent == null || keyEvent.action != KeyEvent.ACTION_DOWN) return false
                    if (!isEnabled()) return false

                    return when (keyEvent.keyCode) {
                        KeyEvent.KEYCODE_VOLUME_UP -> {
                            Log.d(TAG, "MediaSession: Vol UP → detector")
                            detector.onVolumeUp()
                            true // consume — suppress system volume UI
                        }
                        KeyEvent.KEYCODE_VOLUME_DOWN -> {
                            Log.d(TAG, "MediaSession: Vol DOWN → detector")
                            detector.onVolumeDown()
                            true
                        }
                        else -> false
                    }
                }
            })

            isActive = true
        }
        Log.d(TAG, "MediaSession initialized — active with PLAYING state")
    }

    private fun releaseMediaSession() {
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
    }

    // ── SOS Trigger ───────────────────────────────────────────────────────

    private fun triggerSOS() {
        Log.d(TAG, "🚨 SOS triggered by volume pattern")

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val contactsRaw = prefs.getString(KEY_CONTACTS, "") ?: ""
        if (contactsRaw.isBlank()) {
            Log.w(TAG, "No contacts — notifying Flutter only")
            notifyFlutter()
            return
        }

        val phones = contactsRaw.split(",")
            .map { it.trim() }.filter { it.isNotEmpty() }.distinct()

        fetchFreshLocation(
            onSuccess = { loc ->
                val link = "https://maps.google.com/?q=${loc.latitude},${loc.longitude}"
                Log.d(TAG, "Location: ${loc.latitude}, ${loc.longitude}")
                sendSMS(phones, link)
            },
            onFallback = {
                val fallback = getLastKnownLocation()
                val link = if (fallback != null)
                    "https://maps.google.com/?q=${fallback.latitude},${fallback.longitude}"
                else "Location unavailable"
                Log.d(TAG, "Fallback location: $link")
                sendSMS(phones, link)
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
            fusedLocationClient.lastLocation.addOnSuccessListener { result = it }
            Thread.sleep(500)
            result
        } catch (e: Exception) { null }
    }

    private fun sendSMS(phones: List<String>, mapsLink: String) {
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
                .invokeMethod("onVolumeSosDetected", null)
        }
    }

    // ── Notification ──────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Volume SOS", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Volume button SOS detection"
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
            .setContentTitle("Nirbhaya Volume SOS Active 🔊")
            .setContentText("Press Vol UP → DOWN → UP to trigger SOS")
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(openIntent)
            .also { builder ->
                mediaSession?.sessionToken?.let { token ->
                    androidx.media.app.NotificationCompat.MediaStyle()
                        .setMediaSession(token)
                        .let { builder.setStyle(it) }
                }
            }
            .build()
    }
}
