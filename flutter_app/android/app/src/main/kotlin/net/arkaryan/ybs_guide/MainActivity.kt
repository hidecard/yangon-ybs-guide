package net.arkaryan.ybs_guide

import android.content.Context
import android.os.Build
import android.os.PowerManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "net.arkaryan.ybs_guide/wakelock"
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    acquireWakeLock()
                    result.success(null)
                }
                "release" -> {
                    releaseWakeLock()
                    result.success(null)
                }
                "wakeScreen" -> {
                    wakeScreen()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun powerManager(): PowerManager? {
        return getSystemService(Context.POWER_SERVICE) as? PowerManager
    }

    private fun acquireWakeLock() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = powerManager() ?: return
            if (wakeLock?.isHeld != true) {
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "YBSGuide::ArrivalAlert"
                ).apply {
                    setReferenceCounted(false)
                    acquire(6 * 60 * 60 * 1000L) // up to 6h, released on stop
                }
            }
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            try {
                wakeLock?.release()
            } catch (_: Exception) {
            }
        }
        wakeLock = null
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun wakeScreen() {
        val pm = powerManager() ?: return
        // Turn the screen on + dismiss the keyguard so the alert is visible.
        val flags =
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE
        val screenLock = pm.newWakeLock(flags, "YBSGuide::WakeScreen")
        screenLock.setReferenceCounted(false)
        screenLock.acquire(5000)
        screenLock.release()
    }
}
