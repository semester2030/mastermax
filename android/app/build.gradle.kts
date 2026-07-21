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

// PR-006 / RK-062 / EV-144: load release signing material from non-committed android/key.properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("keyAlias missing in android/key.properties (PR-006)")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: error("keyPassword missing in android/key.properties (PR-006)")
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("storePassword missing in android/key.properties (PR-006)")
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                    ?: error("storeFile missing in android/key.properties (PR-006)")
                storeFile = rootProject.file(storeFilePath)
                require(storeFile!!.isFile) {
                    "Release keystore file not found: $storeFilePath — see docs/android_release_signing.md"
                }
            }
        }
    }

    buildTypes {
        release {
            // Debug buildType keeps AGP default debug signing. Release must not use debug keys.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Fail release packaging if key.properties is missing (debug builds still configure/run).
afterEvaluate {
    val releaseGate = {
        if (!keystorePropertiesFile.exists()) {
            error(
                "PR-006: android/key.properties is required for release builds. " +
                    "Copy android/key.properties.example → android/key.properties and point storeFile at your keystore. " +
                    "See docs/android_release_signing.md. Do not commit key.properties or *.jks / *.keystore."
            )
        }
    }
    listOf(
        "assembleRelease",
        "bundleRelease",
        "assembleReleaseUnitTest",
    ).forEach { name ->
        tasks.findByName(name)?.doFirst { releaseGate() }
    }
    tasks.matching { it.name.startsWith("sign") && it.name.contains("Release", ignoreCase = true) }
        .configureEach { doFirst { releaseGate() } }
}

dependencies {
}

flutter {
    source = "../.."
}
