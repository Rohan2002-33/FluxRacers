package com.fluxracers.flux_racers

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotFragment
import org.godotengine.godot.GodotHost
import org.godotengine.godot.plugin.GodotPlugin

class GodotRaceActivity : FragmentActivity(), GodotHost {
    private var godotFragment: GodotFragment? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY

        val fragmentContainer = FrameLayout(this).apply {
            id = R.id.godot_fragment_container
        }
        setContentView(fragmentContainer)

        val existingFragment =
            supportFragmentManager.findFragmentById(fragmentContainer.id)
        godotFragment = existingFragment as? GodotFragment ?: GodotFragment().also { fragment ->
            supportFragmentManager.beginTransaction()
                .replace(fragmentContainer.id, fragment)
                .commitNow()
        }
    }

    override fun getActivity(): Activity = this

    override fun getGodot(): Godot? = godotFragment?.godot

    override fun getCommandLine(): List<String> {
        val mode = intent.getStringExtra(MainActivity.RACE_MODE_EXTRA) ?: "quickRace"
        return listOf(
            "--main-pack",
            "res://godot.pck",
            "--",
            "--race-mode=$mode",
            "--vehicle-build=${intent.getStringExtra(MainActivity.VEHICLE_BUILD_EXTRA) ?: "street"}",
            "--paint=${intent.getStringExtra(MainActivity.VEHICLE_PAINT_EXTRA) ?: "carmine"}",
            "--steering-sensitivity=${intent.getDoubleExtra(MainActivity.STEERING_SENSITIVITY_EXTRA, 1.0)}",
            "--traffic-density=${intent.getIntExtra(MainActivity.TRAFFIC_DENSITY_EXTRA, 1)}",
            "--graphics-quality=${intent.getStringExtra(MainActivity.GRAPHICS_QUALITY_EXTRA) ?: "balanced"}",
            "--music-volume=${intent.getDoubleExtra(MainActivity.MUSIC_VOLUME_EXTRA, 0.35)}",
            "--effects-volume=${intent.getDoubleExtra(MainActivity.EFFECTS_VOLUME_EXTRA, 0.8)}",
        )
    }

    override fun getHostPlugins(godot: Godot): Set<GodotPlugin> = emptySet()

    override fun onGodotForceQuit(instance: Godot) {
        runOnUiThread { finish() }
    }
}
