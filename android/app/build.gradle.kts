import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.devsoftware.pdfreader"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.devsoftware.pdfreader"
        minSdk = 21
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        
        // ❌ SPLITS VE ABI FILTERS KALDIRILDI
        // Flutter komutu zaten ARM64 yapıyor
    }

    signingConfigs {
        create("release") {
            val propertiesFile = rootProject.file("key.properties")
            if (propertiesFile.exists()) {
                val props = Properties().apply {
                    load(FileInputStream(propertiesFile))
                }
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
