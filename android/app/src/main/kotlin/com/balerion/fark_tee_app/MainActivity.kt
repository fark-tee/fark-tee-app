package com.balerion.fark_tee_app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val NUDGE_PAYLOAD = "nudge_alert"
private const val LOCK_SCREEN_CHANNEL = "com.balerion.fark_tee_app/nudge_lock_screen"

/**
 * Nudge alerts arrive as a call-style, full-screen-intent Android
 * notification (see NudgeNotificationService) so they can wake a locked
 * device the way an incoming call does. Android satisfies that full-screen
 * intent by launching this activity, carrying the same "payload" extra a
 * normal notification tap would - only that specific launch is allowed to
 * draw over the lock screen and turn the screen on; a plain app open (icon
 * tap, any other notification) still goes through the normal lock screen.
 * NudgeAlertScreen clears the flags via [LOCK_SCREEN_CHANNEL] on dismiss so
 * whatever screen is underneath isn't left exposed over a still-locked
 * device.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyShowOverLockScreenIfNudge(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        applyShowOverLockScreenIfNudge(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCK_SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "clearShowWhenLocked") {
                    clearShowOverLockScreen()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun applyShowOverLockScreenIfNudge(intent: Intent?) {
        if (intent?.getStringExtra("payload") != NUDGE_PAYLOAD) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun clearShowOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        } else {
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }
}
