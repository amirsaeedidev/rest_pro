plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_project"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_project"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Keep the existing debug signing configuration for CI builds.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Flutter's embedding references Play Core split-install APIs for deferred
    // components. Provide the maintained modular Play Feature Delivery library
    // so R8 can resolve those classes in release builds.
    implementation("com.google.android.play:feature-delivery:2.1.0")
}

flutter {
    source = "../.."
}
