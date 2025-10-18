plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

android {
    namespace = "com.example.pomodoro_mirza_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // [FIX]: Added coreLibraryDesugaringEnabled and set compatibility to Java 8.
        coreLibraryDesugaringEnabled true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.pomodoro_mirza_app"
        minSdk = 21 // Ensure minSdk is at least 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
        // [FIX]: Added multiDexEnabled.
        multiDexEnabled true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// [FIX]: Added dependencies block with the desugaring library.
dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
