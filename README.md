# Flux Racers

Flux Racers is a Flutter application with a Godot 4 3D racing-game prototype.
The Android app launches the Godot race in a native landscape activity. The
gameplay visuals and vehicle are still procedural prototypes, not production
assets or a photorealistic release.

## Architecture and status

- Flutter owns the app shell and menus; Godot runs 3D gameplay on Android.
- The verified 2.5D prototype is preserved in commit `8bd3ae7`.
- `godot/` contains the first procedural 3D driving prototype and isolated
  vehicle-physics tests. It is not a finished game or production car asset.
- Android launches the Godot runtime as a native landscape activity; its PCK
  is generated from the Godot project during the Android build.
- Godot Web export and Flutter Web hosting are not integrated yet. The race
  route reports that explicitly rather than silently showing the old 2.5D
  implementation. The discontinued `flutter_godot` package is not used.
- Vehicle designs will be original and fictional; real manufacturer brands,
  logos, and unlicensed vehicle models are out of scope.

## Prerequisites

- Flutter SDK, Android SDK/NDK, and a configured Flutter Android target.
- Godot 4.7 or a compatible later 4.x release for the 3D prototype.
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

Run the Godot vehicle-model tests:

```powershell
godot --headless --path godot --script res://tests/race_vehicle_model_test.gd
```

The Android host uses Godot's Compatibility renderer. Browser support and
realistic production vehicle/environment assets are still separate work; the
procedural scene is a functional 3D prototype, not a photorealistic release.
