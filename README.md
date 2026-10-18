# Flux Racers

**Own the road. Control the rush.**

Flux Racers is an Android 3D racing game built with Flutter and Godot 4. Choose
a race mode, tune your car in the garage, and take on traffic, a six-driver
sprint, or a timed solo challenge on a stylized 3D highway.

> **Development status:** playable, actively developed, and not yet a
> production-complete release. The game currently targets Android; Web and iOS
> gameplay exports are not configured.

## Screenshots

Captured from the Android game. Menus run in portrait; races switch to
landscape.

<p align="center">
  <img src="docs/screenshots/time-trial.png" alt="Time Trial gameplay showing the 3D road, car, controls, distance, and countdown timer" width="100%">
</p>

<table>
  <tr>
    <td align="center"><strong>Career</strong></td>
    <td align="center"><strong>Quick Race</strong></td>
    <td align="center"><strong>Grid Sprint</strong></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/career.png" alt="Career race on the Coastal Sprint event, with progress toward its 2 km finish" width="100%"></td>
    <td><img src="docs/screenshots/quick-race.png" alt="Open-ended Quick Race gameplay on the 3D highway" width="100%"></td>
    <td><img src="docs/screenshots/grid-sprint.png" alt="Six-driver Grid Sprint with live place and distance-to-leader telemetry" width="100%"></td>
  </tr>
</table>

<table>
  <tr>
    <td align="center"><strong>Main menu</strong></td>
    <td align="center"><strong>Garage</strong></td>
    <td align="center"><strong>Settings</strong></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/home.png" alt="Flux Racers main menu with Career, Quick Race, Grid Sprint, Time Trial, Garage, and Settings" width="100%"></td>
    <td><img src="docs/screenshots/garage.png" alt="Garage with car handling builds and paint options" width="100%"></td>
    <td><img src="docs/screenshots/settings.png" alt="Settings for steering, traffic density, graphics quality, and audio" width="100%"></td>
  </tr>
</table>

## Gameplay video

Watch the full **6:43 Android gameplay recording** (about 58 MB). Select the
screenshot to open the MP4, or use the direct video link below it.

<p align="center">
  <a href="docs/video/flux-racers-gameplay.mp4">
    <img src="docs/screenshots/time-trial.png" alt="Open the Flux Racers gameplay video, featuring the Android game menu and 3D races" width="720">
  </a>
</p>

<p align="center">
  <a href="docs/video/flux-racers-gameplay.mp4">▶ Watch the full gameplay recording (MP4)</a>
</p>

The recording is stored in this repository. GitHub may open or download the
MP4 instead of playing it inline in the README.

## Race modes and features

- **Quick Race** — open-ended solo driving with configurable traffic.
- **Career** — an offline three-event series with 2 km, 4 km, and 6 km races,
  unlocks, rewards, and personal-best records.
- **Grid Sprint** — a 3 km, six-driver point-to-point race with AI rivals,
  position telemetry, collision handling, and finish results.
- **Ghost Time Trial** — complete 3 km within 75 seconds. Beat the deadline to
  save a local personal-best run and race its translucent, non-colliding ghost;
  time out and the race ends.
- **Garage** — select a handling build and paint scheme for the concept car.
- **Race settings** — adjust steering sensitivity, traffic density, graphics
  quality, and audio levels.
- **3D presentation** — a textured road and terrain, roadside scenery,
  instanced trackside details, chase camera, and race audio.
- **Progression** — local profile points, experience, levels, credits, event
  unlocks, and race records.

## Technology and architecture

- **Flutter** provides the Android app shell, navigation, menu, garage, and
  settings screens.
- **Godot 4** runs the 3D race in a native Android landscape activity.
- The Godot race runs in its own Android process; the Flutter host communicates
  race mode and player options to it.
- Godot gameplay data and player options are stored locally on the device.
- The Android build packages Godot project assets with the app. Pre-optimized
  vehicle and traffic resources reduce runtime model processing.

## Run on Android

### Requirements

- Flutter SDK and Dart SDK matching the versions in `pubspec.yaml`.
- Android SDK/NDK configured for Flutter.
- Godot 4.7 (or a compatible Godot 4 release) available on `PATH`, or the
  `GODOT_EXECUTABLE` environment variable set to the Godot executable.
- An Android device or emulator. Find connected device IDs with
  `flutter devices`.

From the repository root in PowerShell:

```powershell
flutter pub get
$env:GODOT_EXECUTABLE = 'C:\path\to\Godot_v4.7.2-stable_win64.exe'
$deviceId = 'YOUR_ANDROID_DEVICE_ID'
flutter run -d $deviceId
```

If Godot is already on `PATH`, omit the `$env:GODOT_EXECUTABLE` line.

### Build and share a release APK

Release APKs must be signed with a private release key. Create a key once;
keep it safe and backed up, because every future update must use the same key.
Never commit the key or `android/key.properties` to Git.

From the repository root in PowerShell, generate the signing key:

```powershell
$passwordBytes = [byte[]]::new(32)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $rng.GetBytes($passwordBytes)
} finally {
  $rng.Dispose()
}
$env:KEYSTORE_PASSWORD = [Convert]::ToBase64String($passwordBytes)
keytool -genkeypair -v `
  -keystore android\app\flux-racers-release.p12 `
  -storetype PKCS12 `
  -keyalg RSA -keysize 4096 -validity 10000 `
  -alias flux-racers-release `
  -storepass $env:KEYSTORE_PASSWORD `
  -keypass $env:KEYSTORE_PASSWORD `
  -dname 'CN=Flux Racers, O=Flux Racers, C=BD'
@"
storeFile=app/flux-racers-release.p12
storePassword=$env:KEYSTORE_PASSWORD
keyAlias=flux-racers-release
keyPassword=$env:KEYSTORE_PASSWORD
"@ | Set-Content -Encoding ascii android\key.properties
Remove-Item Env:\KEYSTORE_PASSWORD
```

Build one APK that supports the widest range of Android devices:

```powershell
flutter build apk --release
```

The shareable APK is `build\app\outputs\flutter-apk\app-release.apk`. The
universal APK supports `arm64-v8a`, `armeabi-v7a`, and `x86_64`, and installs on
Android 7.0 or later (API 24+). It is larger than an architecture-specific APK.
To build smaller APKs for separate devices instead, use
`flutter build apk --release --split-per-abi`; give each person only the APK
matching their phone's CPU architecture. Do not distribute debug APKs.

For a USB-connected phone with USB debugging enabled, install the universal
release APK with:

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

For public sharing, upload the release APK as an asset to a GitHub Release or
share it through a trusted file-hosting service; do not add the generated APK
or signing files to Git. Android may show an unknown-app warning when
sideloading. People should install APKs only from a source they trust. The
project repository contains the source code, not the generated APK.

## Validate changes

Run Flutter analysis and tests:

```powershell
flutter analyze
flutter test
```

Run every Godot regression test:

```powershell
Get-ChildItem godot\tests -Filter '*_test.gd' | ForEach-Object {
  godot --headless --path godot --script "res://tests/$($_.Name)"
  if ($LASTEXITCODE -ne 0) {
    throw "Godot test failed: $($_.Name)"
  }
}
```

## Assets and licensing

The vehicle is an attributed Khronos CC-BY-4.0 concept model, not a real-world
marque. Road, terrain, and shrub assets include verified CC0 Poly Haven
materials; traffic includes Kenney CC0 Car Kit models. Some scenery and audio
are project-authored. Review
[the asset credits and license details](godot/assets/ASSET_LICENSES.md) before
redistributing the game or its assets.

## Project scope

Flux Racers is an evolving mobile racing project with a stylized 3D presentation.
It is not a photorealistic simulator, and performance varies by device. Android
is the currently integrated gameplay target; Godot Web export and Flutter Web
hosting are not implemented.
