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
