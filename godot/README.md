# Godot 3D game project

This project is the Godot 4.7 game/rendering side of Flux Racers. Flutter remains
the application shell. The initial scene is an original, procedural 3D
prototype; it is not a licensed or production vehicle model.

## Run the prototype

1. Install Godot 4.7 or a compatible later 4.x release.
2. Open this directory in Godot, or run `godot --path godot`.

The scene supports W/A/S/D or arrow keys, plus on-screen hold controls. Its root
publishes `telemetry_changed(speed_kmh, distance_m)` and
`race_exit_requested` signals. `set_control(action, pressed)` and
`set_race_paused(paused)` are the initial host-bridge contract.

Run the headless driving model tests from the repository root:

```powershell
godot --headless --path godot --script res://tests/race_vehicle_model_test.gd
```

The first validation milestone targets Godot's Compatibility renderer so the
same scene can be evaluated on Android and in a WebGL 2.0 export. Flutter host
adapters are developed and validated separately; the discontinued
`flutter_godot` package is not a project dependency.
