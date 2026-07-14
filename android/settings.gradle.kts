pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Required to process android/app/google-services.json at build time
    // (reads the file and injects the Firebase config as generated
    // resources/manifest entries). Without this plugin applied in
    // app/build.gradle.kts below, the JSON file is inert — Firebase.
    // initializeApp() still runs off firebase_options.dart at the Dart
    // level, but this plugin is still the standard/expected wiring and
    // some Firebase features (e.g. Crashlytics, Performance, google-
    // services-derived resource values) rely on it being present.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
