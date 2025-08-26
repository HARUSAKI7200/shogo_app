plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): java.util.Properties {
    val localPropertiesFile = rootProject.file("local.properties")
    val properties = java.util.Properties()
    if (localPropertiesFile.exists()) {
        properties.load(java.io.FileInputStream(localPropertiesFile))
    }
    return properties
}

val flutterVersionCode: String by project
val flutterVersionName: String by project

android {
    namespace = "com.example.shogo_app"
    compileSdk = 34

    // ★★★【変更点】★★★
    // エラーメッセージの指示通り、この1行を追加します
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.shogo_app"
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        getByName("release") {
            // isSigningReady = true // この行は新しいGradleバージョンでは不要なためコメントアウトまたは削除します
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {}