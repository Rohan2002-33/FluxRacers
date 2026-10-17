# Flux Racers

Flux Racers is a Flutter application with a Godot 4 3D racing-game prototype.
The game is being migrated from the preserved Flutter/Flame 2.5D prototype;
the complete Android and Web host integration is not implemented yet.

## Architecture and status

- Flutter owns the app shell and menus; Godot is the planned 3D gameplay
  runtime.
- The verified 2.5D prototype is preserved in commit `8bd3ae7`.
- `godot/` contains the first procedural 3D driving prototype and isolated
  vehicle-physics tests. It is not a finished game or production car asset.
- Custom Flutter-to-Godot Android hosting and Godot Web integration remain
  future work. The discontinued `flutter_godot` package is not used.
- Vehicle designs will be original and fictional; real manufacturer brands,
  logos, and unlicensed vehicle models are out of scope.

## Prerequisites

- Flutter SDK and a configured Flutter target for the app shell.
- Godot 4.7 or a compatible later 4.x release for the 3D prototype.
- Android and Web export toolchains are needed only when their host adapters
  are implemented.

## Run locally

From the repository root:

```powershell
flutter pub get
flutter run
godot --path godot
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

The Godot scene currently targets the Compatibility renderer as an initial
Android/Web feasibility baseline. Native and browser exports still require
integration and device/browser validation before they are supported.
