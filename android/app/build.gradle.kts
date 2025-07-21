plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bharghavi"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.bharghavi"
        minSdk = 23                // 🔧 Raised from 21 to 23 to support Firebase Auth
        targetSdk = 34
        versionCode = 1
        versionName = flutter.versionName
        multiDexEnabled = true    // Needed for apps with many dependencies
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Replace with release config later
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1") // Required for multiDex
}