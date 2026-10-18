# Flux Racers

Flux Racers is a Flutter application with a Godot 4 3D racing game.
The Android app launches the Godot race in a native landscape activity. The
race uses an attributed concept-car model, CC0 roadside shrubs, project-authored
3D coconut and date palms, and physically scaled environment textures. It
has an unlimited Quick Race mode and an offline three-event Career series with
countdowns, timed distance goals, persistent unlocks, credits, and personal
best records. Completed Careers can be replayed without losing rewards or
records. It now has a persistent Garage with paint and level-unlocked handling
builds, race settings for steering, traffic density and performance rendering,
project-authored and CC0 textured 3D traffic models in varied colors, three
traffic-density settings with 3/6/9 distinct vehicles, shape-aware collision
failure for cars and trucks,
an original looping race score with a phone-speaker-friendly engine, road
ambience and an in-race horn, and persistent music/effects levels and
points/experience/levels. Race setup shows progress and reports asset-loading
failures rather than leaving a silent black screen. The game is under active
development and is not yet a production-complete release.

## Architecture and status

- Flutter owns the app shell and menus; Godot runs 3D gameplay on Android.
- The verified 2.5D prototype is preserved in commit `8bd3ae7`.
- `godot/` contains the 3D game, career progression, regression tests, and
  integrated licensed assets. It is not a finished game.
- The car is Khronos' attributed CC-BY-4.0 concept model, not a specific
  real-world marque. The road, terrain and shrubs use verified CC0 Poly Haven
  assets; the traffic includes Kenney's stylized, low-poly CC0 Car Kit models;
  palms and audio use original project-authored work. Source, author and
  license details are in
  [godot/assets/ASSET_LICENSES.md](godot/assets/ASSET_LICENSES.md).
- Android launches the Godot runtime as a native landscape activity; its PCK
  is generated from the Godot project during the Android build. The race
  activity runs in its own process, which is closed when a race exits so
  starting another mode always creates a fresh Godot runtime.
- The player car and Kenney traffic meshes are pre-optimized into Godot
  resources, so mobile race startup does not merge imported GLB geometry at
  runtime. The Android pack omits the offline baker, tests, and original
  player/traffic GLBs; only their baked runtime assets are shipped. Regenerate
  them after changing source models with
  `godot --headless --path godot --script res://tools/bake_race_assets.gd`.
- Godot Web export and Flutter Web hosting are not integrated yet. The race
  route reports that explicitly rather than silently showing the old 2.5D
  implementation. The discontinued `flutter_godot` package is not used.
- The current car asset is unbranded; manufacturer names, logos, and unlicensed
  marque-specific models are out of scope.

## Prerequisites

- Flutter SDK, Android SDK/NDK, and a configured Flutter Android target.
- Godot 4.7 or a compatible later 4.x release for the 3D game.
- Add the Godot executable to `PATH`, or set the `GODOT_EXECUTABLE`
  environment variable before building Android.
- A Web export toolchain is needed when the Web host is implemented.

## Run locally

From the repository root:

```powershell
flutter pub get
flutter run
godot --path godot
```

To create architecture-specific Android debug APKs, run:

```powershell
flutter build apk --debug --split-per-abi
```

For Windows PowerShell, when Godot is not on `PATH`, set the executable before
running Flutter:

```powershell
$env:GODOT_EXECUTABLE = 'C:\path\to\Godot_v4.7.2-stable_win64.exe'
flutter run
```

## Validate

Run the Flutter checks:

```powershell
flutter analyze
flutter test
```

Run the Godot regression tests (including race audio, traffic collisions,
imported vehicle rendering, career progression and licensed assets):

```powershell
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tools/bake_race_assets.gd
godot --headless --path godot --script res://tests/race_audio_test.gd
godot --headless --path godot --script res://tests/race_traffic_test.gd
godot --headless --path godot --script res://tests/race_vehicle_render_test.gd
```

The Android host uses Godot's Compatibility renderer. Browser support remains
separate work; the concept vehicle and composed landscape are not claimed to be
photorealistic or representative of a real manufacturer.
