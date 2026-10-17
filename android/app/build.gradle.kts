plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val godotProjectDirectory = rootProject.projectDir.resolve("../godot")
val godotPackDirectory = layout.buildDirectory.dir("generated/godotAssets").get().asFile
val godotPackFile = godotPackDirectory.resolve("godot.pck")
val godotExecutable = providers.gradleProperty("godotExecutable")
    .orElse(providers.environmentVariable("GODOT_EXECUTABLE"))
    .orElse("godot")

val exportGodotGamePack by tasks.registering(Exec::class) {
    inputs.files(
        fileTree(godotProjectDirectory) {
            exclude(".godot/**", "build/**")
        },
    )
    outputs.file(godotPackFile)
    workingDir(godotProjectDirectory)
    doFirst {
        godotPackDirectory.mkdirs()
        commandLine(
            godotExecutable.get(),
            "--headless",
            "--export-pack",
            "Android Game Pack",
            godotPackFile.absolutePath,
        )
    }
}

android {
    namespace = "com.fluxracers.flux_racers"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fluxracers.flux_racers"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets.getByName("main").assets.srcDir(godotPackDirectory)

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    implementation("androidx.fragment:fragment-ktx:1.8.6")
    implementation("org.godotengine:godot:4.7.2.stable")
}

tasks.named("preBuild").configure {
    dependsOn(exportGodotGamePack)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
