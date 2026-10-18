package com.fluxracers.flux_racers

import android.content.ActivityNotFoundException
import android.content.Intent
import java.io.File
import java.io.IOException
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
            when (call.method) {
                "loadPlayerOptions" -> result.success(loadPlayerOptions())
                "savePlayerOptions" -> savePlayerOptions(call.arguments, result)
                "loadPlayerProfile" -> {
                    try {
                        result.success(loadPlayerProfile())
                    } catch (error: IOException) {
                        result.error("profile_unavailable", "Could not read player progress.", error.message)
                    }
                }
                "launchRace" -> launchRace(call.arguments, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun launchRace(arguments: Any?, result: MethodChannel.Result) {
        val request = arguments as? Map<*, *>
        if (request == null) {
            result.error("invalid_race_mode", "Choose Career or Quick Race.", null)
            return
        }
        val mode = request["mode"] as? String
        if (mode !in RACE_MODES) {
            result.error("invalid_race_mode", "Choose Career or Quick Race.", null)
            return
        }
        if (pendingRaceResult != null) {
            result.error("race_in_progress", "A race is already open.", null)
            return
        }

        val options = request["options"] as? Map<*, *>
        val parsed = parsePlayerOptions(options)
        if (parsed == null) {
            result.error("invalid_player_options", "The saved race options are invalid.", null)
            return
        }

        pendingRaceResult = result
        try {
            startActivityForResult(
                Intent(this, GodotRaceActivity::class.java)
                    .putExtra(RACE_MODE_EXTRA, mode)
                    .putExtra(VEHICLE_BUILD_EXTRA, parsed.vehicleBuild)
                    .putExtra(VEHICLE_PAINT_EXTRA, parsed.paint)
                    .putExtra(STEERING_SENSITIVITY_EXTRA, parsed.steeringSensitivity)
                    .putExtra(TRAFFIC_DENSITY_EXTRA, parsed.trafficDensity)
                    .putExtra(GRAPHICS_QUALITY_EXTRA, parsed.graphicsQuality)
                    .putExtra(MUSIC_VOLUME_EXTRA, parsed.musicVolume)
                    .putExtra(EFFECTS_VOLUME_EXTRA, parsed.effectsVolume),
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

    private fun savePlayerOptions(arguments: Any?, result: MethodChannel.Result) {
        val options = parsePlayerOptions(arguments as? Map<*, *>)
        if (options == null) {
            result.error("invalid_player_options", "The supplied game options are invalid.", null)
            return
        }
        preferences.edit()
            .putString(VEHICLE_BUILD_KEY, options.vehicleBuild)
            .putString(VEHICLE_PAINT_KEY, options.paint)
            .putFloat(STEERING_SENSITIVITY_KEY, options.steeringSensitivity.toFloat())
            .putInt(TRAFFIC_DENSITY_KEY, options.trafficDensity)
            .putString(GRAPHICS_QUALITY_KEY, options.graphicsQuality)
            .putFloat(MUSIC_VOLUME_KEY, options.musicVolume.toFloat())
            .putFloat(EFFECTS_VOLUME_KEY, options.effectsVolume.toFloat())
            .apply()
        result.success(null)
    }

    private fun loadPlayerOptions(): Map<String, Any> = mapOf(
        "vehicleBuild" to preferences.getString(VEHICLE_BUILD_KEY, "street").orEmpty(),
        "paint" to preferences.getString(VEHICLE_PAINT_KEY, "carmine").orEmpty(),
        "steeringSensitivity" to preferences.getFloat(STEERING_SENSITIVITY_KEY, 1.0f).toDouble(),
        "trafficDensity" to preferences.getInt(TRAFFIC_DENSITY_KEY, 1),
        "graphicsQuality" to preferences.getString(GRAPHICS_QUALITY_KEY, "balanced").orEmpty(),
        "musicVolume" to preferences.getFloat(MUSIC_VOLUME_KEY, 0.35f).toDouble(),
        "effectsVolume" to preferences.getFloat(EFFECTS_VOLUME_KEY, 0.8f).toDouble(),
    )

    private fun loadPlayerProfile(): Map<String, Int> {
        val profile = readGodotProfile() ?: mapOf(
            "level" to preferences.getInt(PLAYER_LEVEL_KEY, 1),
            "totalPoints" to preferences.getInt(TOTAL_POINTS_KEY, 0),
            "credits" to preferences.getInt(CREDITS_KEY, 0),
        )
        preferences.edit()
            .putInt(PLAYER_LEVEL_KEY, profile.getValue("level"))
            .putInt(TOTAL_POINTS_KEY, profile.getValue("totalPoints"))
            .putInt(CREDITS_KEY, profile.getValue("credits"))
            .apply()
        return profile
    }

    @Throws(IOException::class)
    private fun readGodotProfile(): Map<String, Int>? {
        val profileFile = filesDir.walkTopDown()
            .maxDepth(6)
            .firstOrNull { it.name == CAREER_PROGRESS_FILE } ?: return null
        var inCareerSection = false
        var savedValues = emptyMap<String, Int>()
        for (line in profileFile.readLines()) {
            val value = line.trim()
            if (value.startsWith("[") && value.endsWith("]")) {
                inCareerSection = value == "[career]"
                continue
            }
            if (!inCareerSection) continue
            val entry = PROFILE_ENTRY.matchEntire(value) ?: continue
            savedValues = savedValues + (entry.groupValues[1] to entry.groupValues[2].toInt())
        }
        if (savedValues.isEmpty()) return null
        val points = savedValues["total_points"] ?: 0
        val experience = savedValues["experience"] ?: points
        return mapOf(
            "level" to (savedValues["player_level"] ?: (1 + experience / 1000)),
            "totalPoints" to points,
            "credits" to (savedValues["credits"] ?: 0),
        )
    }

    private fun parsePlayerOptions(arguments: Map<*, *>?): PlayerOptions? {
        if (arguments == null) return null
        val vehicleBuild = arguments["vehicleBuild"] as? String ?: return null
        val paint = arguments["paint"] as? String ?: return null
        val sensitivity = (arguments["steeringSensitivity"] as? Number)?.toDouble() ?: return null
        val density = arguments["trafficDensity"] as? Number ?: return null
        val graphicsQuality = arguments["graphicsQuality"] as? String ?: return null
        val musicVolume = parseOptionalAudioVolume(
            arguments,
            "musicVolume",
            MUSIC_VOLUME_KEY,
            0.35,
        ) ?: return null
        val effectsVolume = parseOptionalAudioVolume(
            arguments,
            "effectsVolume",
            EFFECTS_VOLUME_KEY,
            0.8,
        ) ?: return null
        if (vehicleBuild !in VEHICLE_BUILDS || paint !in VEHICLE_PAINTS) return null
        if (preferences.getInt(PLAYER_LEVEL_KEY, 1) < VEHICLE_BUILD_LEVELS.getValue(vehicleBuild)) return null
        if (!sensitivity.isFinite() || sensitivity !in 0.5..1.5) return null
        if (density.toInt() !in 1..3 || density.toDouble() != density.toInt().toDouble()) return null
        if (graphicsQuality !in GRAPHICS_QUALITIES) return null
        if (!musicVolume.isFinite() || musicVolume !in 0.0..1.0) return null
        if (!effectsVolume.isFinite() || effectsVolume !in 0.0..1.0) return null
        return PlayerOptions(
            vehicleBuild,
            paint,
            sensitivity,
            density.toInt(),
            graphicsQuality,
            musicVolume,
            effectsVolume,
        )
    }

    private fun parseOptionalAudioVolume(
        arguments: Map<*, *>,
        argumentName: String,
        preferenceKey: String,
        defaultValue: Double,
    ): Double? {
        if (!arguments.containsKey(argumentName)) {
            return preferences.getFloat(preferenceKey, defaultValue.toFloat()).toDouble()
        }
        return (arguments[argumentName] as? Number)?.toDouble()
    }

    private data class PlayerOptions(
        val vehicleBuild: String,
        val paint: String,
        val steeringSensitivity: Double,
        val trafficDensity: Int,
        val graphicsQuality: String,
        val musicVolume: Double,
        val effectsVolume: Double,
    )

    private val preferences
        get() = getSharedPreferences(PLAYER_PREFERENCES, MODE_PRIVATE)

    @Deprecated("Deprecated in Android, retained for Flutter activity result compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != RACE_REQUEST_CODE) return

        try {
            pendingRaceResult?.success(loadPlayerProfile())
        } catch (error: IOException) {
            pendingRaceResult?.error("profile_unavailable", "Could not read race progress.", error.message)
        }
        pendingRaceResult = null
    }

    companion object {
        const val RACE_CHANNEL = "com.fluxracers/godot"
        const val RACE_REQUEST_CODE = 4107
        const val RACE_MODE_EXTRA = "com.fluxracers.race_mode"
        const val VEHICLE_BUILD_EXTRA = "com.fluxracers.vehicle_build"
        const val VEHICLE_PAINT_EXTRA = "com.fluxracers.vehicle_paint"
        const val STEERING_SENSITIVITY_EXTRA = "com.fluxracers.steering_sensitivity"
        const val TRAFFIC_DENSITY_EXTRA = "com.fluxracers.traffic_density"
        const val GRAPHICS_QUALITY_EXTRA = "com.fluxracers.graphics_quality"
        const val MUSIC_VOLUME_EXTRA = "com.fluxracers.music_volume"
        const val EFFECTS_VOLUME_EXTRA = "com.fluxracers.effects_volume"
        val RACE_MODES = setOf("career", "quickRace")
        private const val PLAYER_PREFERENCES = "flux_racers_player"
        private const val VEHICLE_BUILD_KEY = "vehicle_build"
        private const val VEHICLE_PAINT_KEY = "vehicle_paint"
        private const val STEERING_SENSITIVITY_KEY = "steering_sensitivity"
        private const val TRAFFIC_DENSITY_KEY = "traffic_density"
        private const val GRAPHICS_QUALITY_KEY = "graphics_quality"
        private const val MUSIC_VOLUME_KEY = "music_volume"
        private const val EFFECTS_VOLUME_KEY = "effects_volume"
        private const val PLAYER_LEVEL_KEY = "player_level"
        private const val TOTAL_POINTS_KEY = "total_points"
        private const val CREDITS_KEY = "credits"
        private const val CAREER_PROGRESS_FILE = "career_progress.cfg"
        private val VEHICLE_BUILDS = setOf("street", "sprint", "grip")
        private val VEHICLE_BUILD_LEVELS = mapOf("street" to 1, "sprint" to 3, "grip" to 5)
        private val VEHICLE_PAINTS = setOf("carmine", "cyan", "pearl", "graphite")
        private val GRAPHICS_QUALITIES = setOf("balanced", "performance")
        private val PROFILE_ENTRY = Regex("""([a-z_]+)\s*=\s*(\d+)""")
    }
}
