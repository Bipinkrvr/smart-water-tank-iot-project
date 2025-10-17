// ✅ 1. THESE IMPORTS ARE CORRECT, EVEN IF THEY ARE WHITE
import org.gradle.api.JavaVersion
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ✅ 2. THIS CODE LOADS YOUR VERSION PROPERTIES
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

android {
    namespace = "com.example.smart_water_tank"
    compileSdk = 35

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // The JavaVersion class is now imported and will be recognized
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.smart_water_tank"
        minSdk = 21
        targetSdk = 35
        // The localProperties object is now defined and can be used
        versionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
        versionName = localProperties.getProperty("flutter.versionName")
        multiDexEnabled = true
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

dependencies {
    implementation(kotlin("stdlib-jdk7"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}