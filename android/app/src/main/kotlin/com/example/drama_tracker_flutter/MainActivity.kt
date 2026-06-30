package com.example.drama_tracker_flutter

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "epilog/app_icon"
    private val iconAliases = listOf(
        "MainActivityDefault",
        "MainActivityNewLight",
        "MainActivityNewDark",
        "MainActivityTicketWarm",
        "MainActivityTicketPurple",
        "MainActivityDark",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supportsAlternateIcons" -> result.success(true)
                    "setAlternateIcon" -> {
                        val alias = call.argument<String>("alias")
                        if (alias == null || !iconAliases.contains(alias)) {
                            result.error("invalid_alias", "Unknown app icon alias: $alias", null)
                            return@setMethodCallHandler
                        }

                        try {
                            setLauncherAlias(alias)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("set_icon_failed", error.localizedMessage, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setLauncherAlias(enabledAlias: String) {
        val packageManager = packageManager
        iconAliases.forEach { alias ->
            val componentName = ComponentName(packageName, "$packageName.$alias")
            val state = if (alias == enabledAlias) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }

            packageManager.setComponentEnabledSetting(
                componentName,
                state,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
