plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.offlinestreamapp"
    compileSdk = 36 // Use API 34 for Android 14 compatibility

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.offlinestreamapp"
        minSdk = flutter.minSdkVersion // Minimum supported by Flutter and audio_service
        minSdk = flutter.minSdkVersion
        targetSdk = 34 // Align with compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Debug signing for now
            // Use correct Kotlin DSL properties
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            // Use correct Kotlin DSL property
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Optional: Include only if using Google Play Services
    implementation("com.google.android.gms:play-services-base:18.5.0")
}
