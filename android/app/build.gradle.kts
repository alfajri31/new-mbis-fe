import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging. Requires android/app/google-services.json (replace the
    // committed placeholder with the file from your Firebase project to enable delivery).
    id("com.google.gms.google-services")
    // Firebase Crashlytics. Wajib ada berdampingan dengan minify R8: tanpa unggahan
    // peta simbol di bawah, stack trace di Play Console tetap teracak.
    id("com.google.firebase.crashlytics")
}

// Release signing is driven by android/key.properties (gitignored). When it's
// absent — e.g. a local dev build or a fresh checkout — we fall back to the debug
// key so `flutter run --release` still works. Create key.properties + a keystore
// before distributing a real release build (see docs/RILIS-ANDROID.md).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

// Gerbang keamanan rilis. Tanpa ini, `flutter build appbundle --release` di mesin
// tanpa key.properties menghasilkan AAB yang ditandatangani DEBUG KEY secara diam-
// diam — Play Console menolaknya, dan kegagalannya baru ketahuan setelah upload.
// AAB = jalur distribusi, jadi wajib gagal cepat. APK release masih boleh memakai
// debug key (dipakai untuk uji lokal / sideload internal), tapi diberi peringatan.
val requestedTasks = gradle.startParameter.taskNames.joinToString(" ")
val isBundleRequested = Regex("(^|:)bundle\\w*Release").containsMatchIn(requestedTasks)
val isAssembleReleaseRequested = Regex("(^|:)assemble\\w*Release").containsMatchIn(requestedTasks)

// Gerbang kedua: key.properties ADA, tapi isinya menunjuk berkas yang tidak ada.
//
// Ranjau yang paling sering kena di Windows: berkas .properties memperlakukan `\`
// sebagai karakter escape, jadi `storeFile=C:\Users\x\mbis.jks` diam-diam terbaca
// menjadi `C:Usersxmbis.jks`. Tanpa pemeriksaan ini, Gradle gagal jauh di belakang
// dengan pesan yang tidak menyebut penyebabnya sama sekali — atau lebih buruk,
// task assembleRelease jatuh ke debug key padahal pengembang yakin kuncinya sudah
// terpasang. Path WAJIB memakai garis miring depan.
if (hasReleaseKeystore && (isBundleRequested || isAssembleReleaseRequested)) {
    val storeFileValue = (keystoreProperties["storeFile"] as String?)?.trim().orEmpty()
    val storeFileResolved = if (storeFileValue.isEmpty()) null else file(storeFileValue)

    if (storeFileValue.isEmpty() || storeFileResolved?.exists() != true) {
        val petunjukBackslash = if (storeFileValue.contains(":") && !storeFileValue.contains("/")) {
            "\n  |  DUGAAN KUAT: path memakai backslash. Di berkas .properties, `\\`\n" +
                "  |  adalah karakter escape sehingga `C:\\Users\\...` terbaca rusak.\n" +
                "  |  Tulis dengan garis miring depan: C:/Users/.../mbis-upload.jks"
        } else {
            ""
        }
        throw GradleException(
            """
            |
            |╭─ RILIS DIBATALKAN ────────────────────────────────────────────────────╮
            |  storeFile di android/key.properties tidak menunjuk berkas yang ada.
            |
            |  Dibaca sebagai : ${storeFileValue.ifEmpty { "(kosong)" }}
            |  Dicari di      : ${storeFileResolved?.absolutePath ?: "-"}$petunjukBackslash
            |
            |  Lihat android/key.properties.example dan docs/RILIS-ANDROID.md §1.
            |╰───────────────────────────────────────────────────────────────────────╯
            """.trimMargin()
        )
    }
}

if (!hasReleaseKeystore) {
    if (isBundleRequested) {
        throw GradleException(
            """
            |
            |╭─ RILIS DIBATALKAN ────────────────────────────────────────────────────╮
            |  android/key.properties tidak ditemukan.
            |
            |  Tanpa berkas itu, AAB akan ditandatangani dengan DEBUG KEY dan pasti
            |  ditolak Google Play Console.
            |
            |  Buat keystore rilis lebih dulu — lihat docs/RILIS-ANDROID.md §1.
            |  Di CI (Codemagic), key.properties dirakit dari secret group
            |  `mbis-android-keystore`; pastikan variabelnya terisi.
            |╰───────────────────────────────────────────────────────────────────────╯
            """.trimMargin()
        )
    }
    if (isAssembleReleaseRequested) {
        logger.warn(
            "[mbis] PERINGATAN: key.properties tidak ada — APK release ini memakai " +
                "DEBUG KEY. Boleh untuk uji lokal, JANGAN dibagikan sebagai rilis."
        )
    }
}

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
            // (Jalur AAB sudah dihentikan lebih dulu oleh gerbang di atas.)
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8: perkecil + obfuscate kode JVM (kode Dart sudah AOT, tidak terpengaruh)
            // dan buang resource Android yang tidak terpakai. Efek sampingnya yang
            // penting untuk rilis: mapping.txt dihasilkan, sehingga stack trace crash
            // di Play Console bisa dibaca kembali. Aturan keep ada di proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Unggah peta simbol R8 ke Crashlytics saat build rilis. Tanpa ini, crash
            // yang masuk ke konsol tetap teracak dan pelaporan crash jadi setengah
            // berguna — persis masalah yang dibuat oleh minify di atas.
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = true
            }
        }

        debug {
            // Build debug tidak mengirim laporan (lihat CrashReporter.install), jadi
            // unggahan simbolnya hanya memperlambat build tanpa guna.
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = false
            }
        }
    }

    packaging {
        // Wajib untuk kompatibilitas 16 KB page size: .so diekstrak/di-align oleh
        // installer modern alih-alih dibungkus dengan alignment 4 KB warisan.
        jniLibs { useLegacyPackaging = false }
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
