# Aturan R8 untuk build release M-BIS.
#
# Kode Dart sudah dikompilasi AOT ke libapp.so dan TIDAK disentuh R8 — yang
# diproses di sini hanya lapisan JVM: engine Flutter, plugin, dan Firebase.
# Penyebab crash paling umum setelah minify adalah kelas yang hanya dipanggil
# lewat refleksi/JNI, jadi semua itu di-keep eksplisit di bawah.

# ── Flutter engine & plugin registrant ───────────────────────────────────────
# Dipanggil dari JNI (native → JVM), tidak terlihat sebagai referensi oleh R8.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter merujuk Play Core (deferred components / split install) meski kita
# tidak memakainya. Tanpa ini R8 gagal dengan "missing class".
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# ── flutter_local_notifications ──────────────────────────────────────────────
# Menyimpan jadwal notifikasi sebagai JSON lewat Gson → butuh refleksi penuh
# atas model & generic signature-nya. Kalau ini hilang, notifikasi terjadwal
# gagal di-restore setelah reboot (dan diam-diam saja, tanpa crash).
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn com.dexterous.**

# Gson: TypeToken bergantung pada generic signature yang di-strip R8.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ── Firebase (core + messaging) ──────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
# FirebaseMessagingService diinstansiasi oleh sistem lewat nama kelas di manifest.
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# ── Core library desugaring (java.time backport) ─────────────────────────────
-dontwarn java.lang.invoke.**
-dontwarn build.IgnoreJava8API
-dontwarn com.google.devtools.build.android.desugar.**

# ── Plugin lain yang memakai refleksi/JNI ────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }         # geolocator
-keep class com.baseflow.permissionhandler.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }  # image_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }# file_picker
-keep class com.it_nomads.fluttersecurestorage.** { *; } # flutter_secure_storage
-dontwarn com.it_nomads.fluttersecurestorage.**

# ── Buang log di build release ───────────────────────────────────────────────
# Lapisan JVM saja (Dart debugPrint tidak lewat sini). Menghindari kebocoran
# nilai yang ikut ter-log oleh plugin pihak ketiga.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Simpan nomor baris supaya stack trace tetap bisa dipetakan lewat mapping.txt.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Firebase Crashlytics ─────────────────────────────────────────────────────
# Nama berkas & nomor baris wajib dipertahankan agar stack trace yang dikirim
# bisa dipetakan kembali lewat mapping.txt (sudah di-keep di bagian atas berkas
# ini, diulang di sini supaya alasannya jelas kalau bagian atas diubah).
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-dontwarn com.google.firebase.crashlytics.**
