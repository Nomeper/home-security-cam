package com.bebobbx.home_security_cam

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Keep the foreground-service disclosure visible while Lock Task
                // prevents Home/Overview from leaving the camera application.
                policyManager.setLockTaskFeatures(
                    admin,
                    DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO or
                        DevicePolicyManager.LOCK_TASK_FEATURE_NOTIFICATIONS,
                )
            }
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
}
