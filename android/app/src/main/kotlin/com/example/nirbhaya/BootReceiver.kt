package com.example.nirbhaya

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts safety services after device reboot.
 * Each service is only restarted if it was enabled before the reboot.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON" &&
            intent.action != "com.htc.intent.action.QUICKBOOT_POWERON") return

        Log.d("BootReceiver", "Boot completed — checking which services to restart")

        val prefs = context.getSharedPreferences(
            WhisperForegroundService.PREFS_NAME, Context.MODE_PRIVATE
        )

        // Restart Whisper (codeword) service if it was enabled
        val whisperEnabled = prefs.getBoolean("panic_whisper_enabled", false)
        if (whisperEnabled) {
            Log.d("BootReceiver", "Restarting WhisperForegroundService")
            WhisperForegroundService.start(context)
        }

        // Restart Volume SOS service if it was enabled
        val volumeSosEnabled = prefs.getBoolean(VolumeSosForegroundService.KEY_ENABLED, false)
        if (volumeSosEnabled) {
            Log.d("BootReceiver", "Restarting VolumeSosForegroundService")
            VolumeSosForegroundService.start(context)
        }
    }
}
