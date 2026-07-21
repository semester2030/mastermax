plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

android {
    namespace = "com.example.mastermax_2030_new"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mastermax_2030_new"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // PR-005 / RK-062 / EV-144: no Maps API key fallback in source.
        // Resolve order: -P / gradle.properties → env → android/local.properties
        val local = Properties()
        val lp = rootProject.file("local.properties")
        if (lp.exists()) {
            FileInputStream(lp).use { local.load(it) }
        }
        val mapsFromLocal = local.getProperty("GOOGLE_MAPS_API_KEY")?.trim().orEmpty()
        val mapsFromEnv = System.getenv("GOOGLE_MAPS_API_KEY")?.trim().orEmpty()
        val mapsKey =
            (project.findProperty("GOOGLE_MAPS_API_KEY") as String?)?.trim()?.takeIf { it.isNotEmpty() }
                ?: mapsFromEnv.takeIf { it.isNotEmpty() }
                ?: mapsFromLocal.takeIf { it.isNotEmpty() }
                ?: error(
                    "GOOGLE_MAPS_API_KEY is required (PR-005). " +
                        "Set android/local.properties, env GOOGLE_MAPS_API_KEY, or -PGOOGLE_MAPS_API_KEY=... " +
                        "See docs/android_maps_api_key.md. Do not commit the key."
                )
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
}

flutter {
    source = "../.."
}
