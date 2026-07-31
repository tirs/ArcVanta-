import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key details, kept out of the repository. See android/key.properties.example.
//
// Absent on a fresh clone and on CI, which is deliberate: the build still has
// to work for anyone running the app locally. What it must not do is quietly
// sign a release with the debug key, so a missing file fails the release build
// rather than downgrading it.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "ai.arcvanta.arcvanta"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ai.arcvanta.arcvanta"
        // CameraX plus NNAPI. NNAPI arrived in 27 but only became worth using
        // in 29, and below that ONNX Runtime falls back to XNNPACK anyway.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // A debug-signed release cannot be updated by a Play-signed one
            // later, so shipping one by accident is unrecoverable for every
            // user who installed it. Better to stop the build.
            signingConfig = signingConfigs.findByName("release")
                ?: throw GradleException(
                    "No release signing key. Copy android/key.properties.example " +
                        "to android/key.properties and point it at your keystore, " +
                        "or build a debug variant instead."
                )

            // The key checked in for build verification must never sign a
            // store upload: whoever publishes with it can never rotate away
            // from a keystore whose password is in the repository.
            if (keystoreProperties.getProperty("throwaway") == "true") {
                // println rather than logger.warn: the Flutter CLI filters
                // Gradle's warn level out of its own output, and a warning
                // nobody sees is not a warning.
                println(
                    "\n" +
                        "**********************************************************\n" +
                        "* Signing with the THROWAWAY verification key.            *\n" +
                        "* Do not upload this build. Generate your own keystore    *\n" +
                        "* and replace android/key.properties before publishing.   *\n" +
                        "**********************************************************\n"
                )
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        // The ONNX Runtime AAR ships its own copies of these.
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

dependencies {
    val cameraX = "1.4.1"
    implementation("androidx.camera:camera-core:$cameraX")
    implementation("androidx.camera:camera-camera2:$cameraX")
    implementation("androidx.camera:camera-lifecycle:$cameraX")

    // Pinned to the runtime version recorded in vision/contract/model_contract.json.
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
