import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// configure Gradle to use the upload key
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.minh.mobile_image_gallery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    defaultConfig {
        // TODO: Specify your own unique Application ID
        // (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.minh.mobile_image_gallery"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // add the signing configuration
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")

            // R8 is on for release; without keep rules it strips the
            // ai.onnxruntime classes the native code resolves by name,
            // crashing model inference (GetMethodID java_class == null).
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter { source = "../.." }

// Tell Gradle to exclude the Android library (without Admin)
// that is added by the objectbox_flutter_libs package for debug builds.
configurations {
    named("debugImplementation") { exclude(group = "io.objectbox", module = "objectbox-android") }
}

dependencies {
    // Add the Android library with ObjectBox Admin only for debug builds.
    // Note: when the objectbox package updates, check if the Android
    // library below needs to be updated as well.
    // TODO Replace <version> with the one noted in the release notes
    // (https://github.com/objectbox/objectbox-dart/releases)
    debugImplementation("io.objectbox:objectbox-android-objectbrowser:5.1.0")
}
