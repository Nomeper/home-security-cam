package com.bebobbx.home_security_cam

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Android Enterprise DPC component.
 *
 * Device Owner status is granted only by Android during provisioning; this
 * receiver does not attempt to activate device administration itself.
 */
class HomeSecurityDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) = Unit

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "La disattivazione della gestione del dispositivo richiede un reset autorizzato."
}
