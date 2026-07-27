import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging. Requires android/app/google-services.json (replace the
    // committed placeholder with the file from your Firebase project to enable delivery).
    id("com.google.gms.google-services")
}

// Release signing is driven by android/key.properties (gitignored). When it's
// absent — e.g. a local dev build or a fresh checkout — we fall back to the debug
// key so `flutter run --release` still works. Create key.properties + a keystore
// before distributing a real release build (see docs/DEPLOY-COOLIFY.md §9).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.askrindo.mbis.mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (v18): backports java.time APIs used by
        // the plugin to older Android via desugaring. Pairs with the
        // coreLibraryDesugaring dependency below.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Askrindo M-BIS mobile.
        applicationId = "com.askrindo.mbis.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Flavor per environment. `prod` = applicationId dasar; `staging` menambah
    // suffix `.staging` agar prod & staging bisa terpasang berdampingan di device.
    // Environment runtime (dev/staging/prod) tetap lewat --dart-define=APP_ENV;
    // flavor hanya memisahkan identitas paket & signing di store.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real release key when key.properties is present; otherwise fall
            // back to the debug key so local `flutter run --release` still works.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backports java.time (and other Java 8+ APIs) for flutter_local_notifications.
    // 2.1.x is required by core library desugaring on recent AGP.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
