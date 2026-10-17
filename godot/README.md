# Godot 3D game project

This project is the Godot 4.7 game/rendering side of Flux Racers. Flutter
provides the app shell, and Android launches the race in a native Godot
activity. The road and terrain use verified CC0 PBR textures, roadside scenery
uses verified CC0 glTF vegetation, and the vehicle uses an attributed
CC-BY-4.0 concept-car model with excluded logos removed from the rendered scene.

## Run the prototype

1. Install Godot 4.7 or a compatible later 4.x release.
2. Open this directory in Godot, or run `godot --path godot`.

The scene features a licensed detailed concept car, four animated wheel
assemblies, natural asphalt and terrain PBR materials, distant ridges, CC0
roadside shrubs, and original 3D coconut and date palms. The road, field texture,
palms, and shrubs advance by the same physical world distance calculated from
vehicle speed; roadside instances recycle beyond the camera for continuous
motion during long races. The eight recycled road sections render in two
MultiMesh batches: one for textured asphalt and one for lane dashes, edge lines,
and alternating red-white kerbs. Palm trunks, foliage, and fruit are combined
into one vertex-colored surface per species and GPU-instanced in roadside
batches, preserving green leaves and brown bark with a mobile-friendly standard
material. Road and palm batches scroll together; an individual instance
transform is updated only when that section or tree is recycled, rather than
rewriting every instance transform on every physics tick. The HUD refreshes at
the same 10 Hz interval as telemetry. Mobile rendering uses a reduced 3D scale,
and the broad field keeps diffuse and normal detail without a costly roughness
texture sample. The vehicle and CC0 shrubs load on background resource threads
so the environment and controls can initialize first. It supports
W/A/S/D or arrow keys, plus on-screen hold controls. Its root publishes
`telemetry_changed(speed_kmh, distance_m)` and
`race_exit_requested` signals. `set_control(action, pressed)` and
`set_race_paused(paused)` are the initial host-bridge contract.

For Android, the app exports this project to `godot.pck` during its Gradle
build and loads it using Godot's Android library. Set `GODOT_EXECUTABLE` to the
Godot executable if it is not on `PATH`. The Web race host has not been
implemented.

Run the headless driving model tests from the repository root:

```powershell
godot --headless --path godot --script res://tests/race_vehicle_model_test.gd
godot --headless --path godot --script res://tests/race_car_scene_test.gd --quit-after 100000
godot --headless --path godot --script res://tests/race_palm_tree_test.gd --quit-after 120
```

The third-party asset sources, licenses, and attribution are documented in
[assets/ASSET_LICENSES.md](assets/ASSET_LICENSES.md). The Android build targets
Godot's Compatibility renderer. The discontinued `flutter_godot` package is
not a project dependency. The driving model and road are still an arcade
prototype; the supplied car is a concept vehicle rather than a licensed
real-world marque, and the broader landscape remains a composed real-time
environment rather than a photorealistic scan.
