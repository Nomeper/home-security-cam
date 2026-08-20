package com.bebobbx.home_security_cam

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceOwnerChannel = "com.bebobbx.home_security_cam/device_owner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceOwnerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(
                        mapOf(
                            "isDeviceOwner" to isDeviceOwner(),
                            "isLockTaskActive" to isLockTaskActive(),
                        ),
                    )
                    "startLockTask" -> startKiosk(result)
                    "stopLockTask" -> stopKiosk(result)
                    "setEcoChrome" -> setEcoChrome(
                        call.argument<Boolean>("enabled") ?: false,
                        result,
                    )
                    "setCameraPowerSave" -> setCameraPowerSave(
                        call.argument<Boolean>("enabled") ?: false,
                        call.argument<Number>("timeoutMs")?.toLong() ?: 15_000L,
                        result,
                    )
                    "blankDisplay" -> blankDisplay(
                        call.argument<Boolean>("enabled") ?: false,
                        result,
                    )
                    "setScreenFlashlight" -> setScreenFlashlight(
                        call.argument<Boolean>("enabled") ?: false,
                        call.argument<Boolean>("restoreSystemBars") ?: true,
                        result,
                    )
                    "openUrl" -> openUrl(call.argument<String>("url"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun isDeviceOwner(): Boolean {
        val policyManager =
            getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return policyManager.isDeviceOwnerApp(packageName)
    }

    private fun isLockTaskActive(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
    }

    private fun startKiosk(result: MethodChannel.Result) {
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            result.error(
                "debug_build",
                "Lock Task cannot be activated from a debug build.",
                null,
            )
            return
        }
        if (!isDeviceOwner()) {
            result.error(
                "not_device_owner",
                "Lock Task is available only after Device Owner provisioning.",
                null,
            )
            return
        }

        try {
            val policyManager =
                getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, HomeSecurityDeviceAdminReceiver::class.java)
            policyManager.setLockTaskPackages(admin, arrayOf(packageName))
            applyLockTaskFeatures(ecoMode = false)
            startLockTask()
            result.success(null)
        } catch (error: SecurityException) {
            result.error("lock_task_failed", error.message, null)
        }
    }

    private fun stopKiosk(result: MethodChannel.Result) {
        if (!isDeviceOwner()) {
            result.error(
                "not_device_owner",
                "Only a provisioned Device Owner can exit Lock Task.",
                null,
            )
            return
        }

        try {
            stopLockTask()
            result.success(null)
        } catch (error: IllegalStateException) {
            result.error("lock_task_failed", error.message, null)
        }
    }

    private fun setCameraPowerSave(
        enabled: Boolean,
        timeoutMs: Long,
        result: MethodChannel.Result,
    ) {
        try {
            if (enabled) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            // Do not override brightness here. Dim only in blankDisplay
            // (ECO and standby after the countdown), otherwise the UI is unreadable.
            if (isDeviceOwner()) {
                val policyManager =
                    getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val admin = ComponentName(this, HomeSecurityDeviceAdminReceiver::class.java)
                policyManager.setMaximumTimeToLock(
                    admin,
                    if (enabled) timeoutMs.coerceAtLeast(5_000L) else 0L,
                )
            }
            result.success(null)
        } catch (error: SecurityException) {
            result.error("camera_power_save_failed", error.message, null)
        }
    }

    private fun blankDisplay(enabled: Boolean, result: MethodChannel.Result) {
        try {
            if (enabled) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                hideOrShowSystemBars(hide = true)
            }
            val attrs = window.attributes
            attrs.screenBrightness = if (enabled) {
                0f
            } else {
                WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            }
            window.attributes = attrs
            if (enabled && isDeviceOwner()) {
                val policyManager =
                    getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val admin = ComponentName(this, HomeSecurityDeviceAdminReceiver::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    policyManager.setStatusBarDisabled(admin, true)
                    try {
                        policyManager.setKeyguardDisabled(admin, true)
                    } catch (_: SecurityException) {
                        // Lock-task may be required before keyguard can be disabled.
                    }
                }
                policyManager.lockNow()
            }
            result.success(null)
        } catch (error: SecurityException) {
            result.error("blank_display_failed", error.message, null)
        }
    }

    private fun setScreenFlashlight(
        enabled: Boolean,
        restoreSystemBars: Boolean,
        result: MethodChannel.Result,
    ) {
        try {
            val attrs = window.attributes
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(true)
                    setTurnScreenOn(true)
                } else {
                    @Suppress("DEPRECATION")
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
                    )
                }
                hideOrShowSystemBars(hide = true)
                attrs.screenBrightness = 1f
                wakeScreenIfNeeded()
            } else {
                attrs.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                if (restoreSystemBars) {
                    hideOrShowSystemBars(hide = false)
                }
            }
            window.attributes = attrs
            result.success(null)
        } catch (error: SecurityException) {
            result.error("screen_flashlight_failed", error.message, null)
        }
    }

    private fun wakeScreenIfNeeded() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (powerManager.isInteractive) return
        @Suppress("DEPRECATION")
        val wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "HomeSecurityCam:screenFlash",
        )
        wakeLock.acquire(1_500L)
        if (wakeLock.isHeld) wakeLock.release()
    }

    private fun openUrl(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("invalid_url", "Missing url", null)
            return
        }
        val uri = try {
            Uri.parse(url)
        } catch (_: Exception) {
            result.error("invalid_url", "Invalid url", null)
            return
        }
        if (uri.scheme != "https") {
            result.error("invalid_url", "Only https URLs are allowed", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("no_browser", error.message, null)
        }
    }

    private fun setEcoChrome(enabled: Boolean, result: MethodChannel.Result) {
        try {
            hideOrShowSystemBars(hide = enabled)
            if (isDeviceOwner()) {
                val policyManager =
                    getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val admin = ComponentName(this, HomeSecurityDeviceAdminReceiver::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    policyManager.setStatusBarDisabled(admin, enabled)
                }
                applyLockTaskFeatures(ecoMode = enabled)
            }
            result.success(null)
        } catch (error: SecurityException) {
            result.error("eco_chrome_failed", error.message, null)
        }
    }

    private fun applyLockTaskFeatures(ecoMode: Boolean) {
        if (!isDeviceOwner() || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        val policyManager =
            getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(this, HomeSecurityDeviceAdminReceiver::class.java)
        val features = if (ecoMode) {
            DevicePolicyManager.LOCK_TASK_FEATURE_NONE
        } else {
            // Keep the foreground-service disclosure visible while Lock Task
            // prevents Home/Overview from leaving the camera application.
            DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO or
                DevicePolicyManager.LOCK_TASK_FEATURE_NOTIFICATIONS
        }
        policyManager.setLockTaskFeatures(admin, features)
    }

    private fun hideOrShowSystemBars(hide: Boolean) {
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        if (hide) {
            window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            val types = WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
            if (hide) {
                controller.hide(types)
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            } else {
                controller.show(types)
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = if (hide) {
                (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION)
            } else {
                View.SYSTEM_UI_FLAG_VISIBLE
            }
        }
    }
}
