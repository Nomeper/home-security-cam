import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

gradle.taskGraph.whenReady {
    val buildingReleaseArtifact = allTasks.any { task ->
        val name = task.name
        name.contains("Release", ignoreCase = true) &&
            (name.startsWith("assemble") ||
                name.startsWith("bundle") ||
                name.startsWith("package"))
    }
    if (buildingReleaseArtifact && !hasReleaseKeystore) {
        throw GradleException(
            "Release signing is not configured. Copy android/key.properties.example " +
                "to android/key.properties, create a release keystore outside the repo, " +
                "and fill in the values. Debug builds do not require this file."
        )
    }
}

android {
    // Namespace univoco per l'applicazione
    namespace = "com.bebobbx.home_security_cam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.bebobbx.home_security_cam"

        // Agora richiede almeno API 21, ma Flutter usa minSdk 23 o superiore di default
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Abilitiamo MultiDex per evitare errori con librerie pesanti come Agora
        multiDexEnabled = true

        // Telefoni ARM 64-bit + emulatore x86_64. Niente ARM 32-bit.
        ndk {
            abiFilters.clear()
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    packaging {
        jniLibs {
            // Estensioni Agora non usate (bellezza, avatar, AV1, condivisione schermo…).
            // Restano rtc-sdk, ffmpeg, encoder/decoder H.264, iris e Flutter.
            excludes += setOf(
                "**/libagora_ai_noise_suppression_extension.so",
                "**/libagora_ai_noise_suppression_ll_extension.so",
                "**/libagora_ai_echo_cancellation_extension.so",
                "**/libagora_ai_echo_cancellation_ll_extension.so",
                "**/libagora_audio_beauty_extension.so",
                "**/libagora_clear_vision_extension.so",
                "**/libagora_content_inspect_extension.so",
                "**/libagora_screen_capture_extension.so",
                "**/libagora_segmentation_extension.so",
                "**/libagora_spatial_audio_extension.so",
                "**/libagora_face_detection_extension.so",
                "**/libagora_face_capture_extension.so",
                "**/libagora_lip_sync_extension.so",
                "**/libagora_video_quality_analyzer_extension.so",
                "**/libagora_video_av1_encoder_extension.so",
                "**/libagora_video_av1_decoder_extension.so",
                "**/libagora_pvc_extension.so",
                "**/libagora_super_resolution_extension.so",
                "**/libagora_drm_loader_extension.so",
                "**/libagora_udrm3_extension.so",
            )
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("key.properties: missing keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: error("key.properties: missing keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("key.properties: missing storePassword")
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                    ?: error("key.properties: missing storeFile")
                storeFile = rootProject.file(storeFilePath)
                require(storeFile!!.isFile) {
                    "key.properties: storeFile not found at ${storeFile!!.absolutePath}"
                }
            }
        }
    }

    buildTypes {
        release {
            // Firma solo con keystore di rilascio (mai con la debug key)
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }

            // Riduce superficie di analisi e dimensione dell'artefatto release.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Supporto MultiDex per garantire compatibilità con dispositivi Android più vecchi
    implementation("androidx.multidex:multidex:2.0.1")
}

configurations.configureEach {
    exclude(group = "io.agora.rtc", module = "full-screen-sharing-special")
}
