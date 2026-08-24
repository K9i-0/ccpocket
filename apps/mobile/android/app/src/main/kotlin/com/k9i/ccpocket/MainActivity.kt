package com.k9i.ccpocket

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val APP_ICON_CHANNEL = "ccpocket/app_icon"
private const val APP_SETTINGS_CHANNEL = "ccpocket/app_settings"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_ICON_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "supportsAlternateIcons" -> result.success(true)
                "getCurrentIcon" -> result.success(getCurrentIcon())
                "setIcon" -> {
                    val icon = call.argument<String>("icon")
                    try {
                        setLauncherIcon(icon)
                        result.success(null)
                    } catch (error: IllegalArgumentException) {
                        result.error("invalid_icon", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    try {
                        openNotificationSettings()
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("settings_unavailable", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getCurrentIcon(): String? {
        val aliases = mapOf(
            "$packageName.MainActivitySupporterLightOutline" to "light_outline",
            "$packageName.MainActivitySupporterProCopperEmerald" to "pro_copper_emerald",
        )

        for ((alias, iconId) in aliases) {
            val state = packageManager.getComponentEnabledSetting(
                ComponentName(packageName, alias),
            )
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return iconId
            }
        }
        return null
    }

    private fun setLauncherIcon(icon: String?) {
        val targetAlias = when (icon) {
            null, "default" -> "$packageName.MainActivityDefault"
            "light_outline" -> "$packageName.MainActivitySupporterLightOutline"
            "pro_copper_emerald" -> "$packageName.MainActivitySupporterProCopperEmerald"
            else -> throw IllegalArgumentException("Unknown app icon: $icon")
        }
        val aliases = listOf(
            "$packageName.MainActivityDefault",
            "$packageName.MainActivitySupporterLightOutline",
            "$packageName.MainActivitySupporterProCopperEmerald",
        )

        for (alias in aliases) {
            packageManager.setComponentEnabledSetting(
                ComponentName(packageName, alias),
                if (alias == targetAlias) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                },
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
        }
        startActivity(intent)
    }
}
