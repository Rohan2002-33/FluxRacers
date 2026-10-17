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

    override fun getCommandLine(): List<String> =
        listOf("--main-pack", "res://godot.pck")

    override fun getHostPlugins(godot: Godot): Set<GodotPlugin> = emptySet()

    override fun onGodotForceQuit(instance: Godot) {
        runOnUiThread { finish() }
    }
}
