package com.example.nirbhaya

import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Strict volume-button SOS detector.
 *
 * Valid pattern  : UP → DOWN → UP  (exactly 3 presses, no more)
 * Invalid cases  : any extra press, wrong order, timeout > 2 s
 *
 * Logic:
 *  1. Each press is appended to [sequence].
 *  2. If sequence length > 3 → reset immediately (extra press).
 *  3. If sequence length == 3 AND matches ["UP","DOWN","UP"]:
 *       → start 200 ms confirmation delay.
 *       → if another press arrives during delay → cancel.
 *       → if delay elapses with no extra press → fire [onSosTriggered].
 *  4. A 2-second inactivity timer resets the sequence after each press.
 */
class VolumeSosDetector(private val onSosTriggered: () -> Unit) {

    companion object {
        private const val TAG              = "VolumeSosDetector"
        private const val WINDOW_MS        = 2_000L   // max time for full sequence
        private const val CONFIRM_DELAY_MS = 200L     // wait for extra press before firing
        private val VALID_PATTERN          = listOf("UP", "DOWN", "UP")
    }

    private val handler   = Handler(Looper.getMainLooper())
    private val sequence  = mutableListOf<String>()

    // Pending confirmation runnable — cancelled if extra press arrives
    private var confirmRunnable: Runnable? = null

    // Timeout runnable — resets sequence after WINDOW_MS of inactivity
    private val timeoutRunnable = Runnable {
        Log.d(TAG, "Timeout — resetting sequence: $sequence")
        reset()
    }

    // Safety lock: prevents duplicate SOS within one confirmation window
    @Volatile private var isSosArmed = false

    // ── Public API ────────────────────────────────────────────────────────

    /** Call this from MainActivity.onKeyDown or the foreground service. */
    fun onVolumeUp()   = recordPress("UP")
    fun onVolumeDown() = recordPress("DOWN")

    // ── Core logic ────────────────────────────────────────────────────────

    private fun recordPress(direction: String) {
        // If a confirmation is pending, an extra press cancels it
        if (confirmRunnable != null) {
            Log.d(TAG, "Extra press '$direction' during confirmation window → CANCEL SOS")
            cancelConfirmation()
            reset()
            return
        }

        sequence.add(direction)
        Log.d(TAG, "Button pressed: $direction | sequence: $sequence")

        // Restart inactivity timeout
        handler.removeCallbacks(timeoutRunnable)

        when {
            sequence.size > 3 -> {
                Log.d(TAG, "Sequence > 3 → RESET immediately")
                reset()
            }

            sequence.size == 3 -> {
                handler.removeCallbacks(timeoutRunnable) // no timeout during confirm
                if (sequence == VALID_PATTERN) {
                    Log.d(TAG, "Pattern matched! Starting ${CONFIRM_DELAY_MS}ms confirmation delay…")
                    armConfirmation()
                } else {
                    Log.d(TAG, "Wrong pattern ${sequence} → RESET")
                    reset()
                }
            }

            else -> {
                // Sequence still building — restart window timer
                handler.postDelayed(timeoutRunnable, WINDOW_MS)
            }
        }
    }

    /** Start the 200 ms delay; fire SOS only if no extra press arrives. */
    private fun armConfirmation() {
        isSosArmed = true
        val runnable = Runnable {
            confirmRunnable = null
            if (isSosArmed) {
                Log.d(TAG, "✅ Pattern confirmed — triggering SOS!")
                reset()
                onSosTriggered()
            }
        }
        confirmRunnable = runnable
        handler.postDelayed(runnable, CONFIRM_DELAY_MS)
    }

    private fun cancelConfirmation() {
        confirmRunnable?.let { handler.removeCallbacks(it) }
        confirmRunnable = null
        isSosArmed = false
        Log.d(TAG, "Confirmation cancelled")
    }

    private fun reset() {
        handler.removeCallbacks(timeoutRunnable)
        cancelConfirmation()
        sequence.clear()
        Log.d(TAG, "Sequence reset")
    }
}
