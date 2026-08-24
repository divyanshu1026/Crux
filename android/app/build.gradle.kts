import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// git-ignored (see android/key.properties.example).
//
// Missing keystore behaviour is deliberately split:
//   * building an App Bundle (.aab) — only ever used for Play upload — FAILS
//     immediately, because a debug-signed bundle is rejected by Play and the
//     failure otherwise surfaces minutes later in the Console.
//   * anything else (`flutter run --release`, a local release APK) falls back
//     to debug signing with a warning, so local testing still works.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// `flutter build appbundle` runs a :bundleRelease task; `flutter run` never does.
val isBuildingReleaseBundle = gradle.startParameter.taskNames.any {
    it.contains("bundle", ignoreCase = true) && it.contains("release", ignoreCase = true)
}

if (isBuildingReleaseBundle && !hasReleaseKeystore) {
    throw GradleException(
        """
        |
        |═══════════════════════════════════════════════════════════════════
        | Cannot build a release App Bundle: android/key.properties is missing.
        |
        | Without it this bundle would be DEBUG-SIGNED, and Google Play
        | rejects debug-signed uploads ("You need to sign your APK or Android
        | App Bundle in release mode").
        |
        | Fix — one time only:
        |   1. Create an upload keystore (keep the file safe and backed up):
        |
        |      keytool -genkey -v -keystore %USERPROFILE%\crux-upload.jks ^
        |        -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 ^
        |        -alias crux
        |
        |   2. cp android/key.properties.example android/key.properties
        |      and fill in the 4 values (alias: crux).
        |
        | Details: RELEASE.md section 0.1
        |═══════════════════════════════════════════════════════════════════
        """.trimMargin()
    )
}

android {
    namespace = "com.cruxapp.crux"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (java.time backport).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cruxapp.crux"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Keep the Play "resizable app" check happy and the UI predictable.
        resourceConfigurations += listOf("en")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Bundles already hard-failed above if the keystore is missing, so
            // reaching the debug branch here means a local release APK — fine
            // for on-device testing, never for distribution.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n⚠️  android/key.properties not found — this release APK is " +
                    "DEBUG-SIGNED. Fine for local testing; Play will reject it.\n"
                )
                signingConfigs.getByName("debug")
            }

            // R8: shrink + obfuscate. Cuts ~30-40% off the download size and
            // makes the shipped Dart/Java surface harder to poke at.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Lets a debug build sit alongside a Play install on the same device.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    // Play requires the bundle to keep language splits; keep density/abi too.
    bundle {
        language { enableSplit = true }
        density { enableSplit = true }
        abi { enableSplit = true }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
