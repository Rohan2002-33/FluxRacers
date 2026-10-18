package com.fluxracers.flux_racers

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingRaceResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RACE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "launchRace") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val mode = call.argument<String>("mode")
            if (mode !in RACE_MODES) {
                result.error("invalid_race_mode", "Choose Career or Quick Race.", null)
                return@setMethodCallHandler
            }
            if (pendingRaceResult != null) {
                result.error("race_in_progress", "A race is already open.", null)
                return@setMethodCallHandler
            }

            pendingRaceResult = result
            try {
                startActivityForResult(
                    Intent(this, GodotRaceActivity::class.java).putExtra(
                        RACE_MODE_EXTRA,
                        mode,
                    ),
                    RACE_REQUEST_CODE,
                )
            } catch (error: ActivityNotFoundException) {
                pendingRaceResult = null
                result.error(
                    "race_host_unavailable",
                    "The Godot race activity could not be opened.",
                    error.message,
                )
            }
        }
    }

    @Deprecated("Deprecated in Android, retained for Flutter activity result compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != RACE_REQUEST_CODE) return

        pendingRaceResult?.success(null)
        pendingRaceResult = null
    }

    companion object {
        const val RACE_CHANNEL = "com.fluxracers/godot"
        const val RACE_REQUEST_CODE = 4107
        const val RACE_MODE_EXTRA = "com.fluxracers.race_mode"
        val RACE_MODES = setOf("career", "quickRace")
    }
}
