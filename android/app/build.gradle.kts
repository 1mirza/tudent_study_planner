import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.pomodoro_mirza_app"
    compileSdk = (findProperty("flutter.compileSdkVersion") as String).toInt()
    ndkVersion = findProperty("flutter.ndkVersion") as String

    compileOptions {
        // [FIX]: Enabled core library desugaring using Kotlin DSL syntax.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.pomodoro_mirza_app"
        minSdk = 21
        targetSdk = (findProperty("flutter.targetSdkVersion") as String).toInt()
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        // [FIX]: Enabled multiDex using Kotlin DSL syntax.
        isMultiDexEnabled = true
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

// [FIX]: Added dependencies using Kotlin DSL syntax.
dependencies {
    implementation(kotlin("stdlib-jdk7"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
