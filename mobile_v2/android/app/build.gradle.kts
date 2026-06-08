plugins {
    id("com.android.application")
    id("kotlin-android")
    
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ru.valdolesov.medical_app_v2"
    compileSdk = flutter.compileSdkVersion
    // Минимум, который требуют плагины file_picker, flutter_secure_storage, open_filex и др.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        
        applicationId = "ru.valdolesov.medical_app_v2"

minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {

signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
