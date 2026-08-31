import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'secure_context.dart';

/// Kunci penyimpanan sesi. Sama untuk kedua implementasi di bawah, supaya sesi tidak
/// hilang kalau origin yang sama suatu saat naik ke HTTPS (mis. dev diberi TLS):
/// store-nya berganti, kuncinya tidak.
const String sessionStorageKey = 'mbis.auth.session';

/// Satu pintu penyimpanan sesi login (`AuthSession` ter-serialisasi).
///
/// Dulu [AuthRepository] memanggil `FlutterSecureStorage` langsung. Dipisah ke sini
/// karena web punya satu kondisi di mana secure storage TIDAK BISA dipakai sama
/// sekali, dan keputusannya perlu satu tempat yang bisa dibaca dan diuji — lihat
/// [createSessionStore].
abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Environment yang BOLEH memakai penyimpanan teks biasa saat origin tidak tepercaya.
///
/// Sengaja *allowlist*, bukan `!= 'prod'`. Dengan denylist, satu salah ketik di CI
/// (`APP_ENV=production`) atau define yang lupa dipasang — `AppConfig.env` default-nya
/// `'dev'` — akan MEMBUKA gerbang tanpa suara. Dengan allowlist, nilai yang tak dikenal
/// gagal-tertutup: aplikasi tetap memakai secure storage dan, kalau origin-nya memang
/// tidak tepercaya, melempar `only works in secure contexts` yang langsung kelihatan.
///
/// Salah arah itu penting: kesalahan konfigurasi harus berakhir sebagai error yang
/// berisik, bukan sebagai refresh token berumur 7 hari yang diam-diam tersimpan sebagai
/// teks biasa di produksi.
const Set<String> _fallbackAllowedEnvs = {'dev', 'staging'};

/// Apakah [env] boleh turun ke penyimpanan teks biasa. Dipisah dari
/// [createSessionStore] supaya bisa diuji tanpa browser — lihat `session_store_test`.
bool sessionFallbackAllowedForEnv(String env) =>
    _fallbackAllowedEnvs.contains(env.trim().toLowerCase());

/// Pilih implementasi berdasarkan kemampuan platform.
///
/// Fallback ke SharedPreferences hanya aktif bila KETIGA syarat terpenuhi:
///
///   1. `kIsWeb` — native selalu punya secure storage yang berfungsi.
///   2. bukan secure context — HTTPS dan `localhost` tidak butuh fallback.
///   3. [sessionFallbackAllowedForEnv] — pagar terakhir, dan yang paling penting.
///
/// Prod dilayani di `https://mbis.askrindo.co.id`, jadi syarat 2 saja sudah tak pernah
/// terpenuhi di sana. Syarat 3 ada supaya perlindungannya tidak bertumpu pada satu
/// lapis: kalau suatu hari prod salah dipasang di HTTP polos, aplikasi GAGAL KERAS.
///
/// `AppConfig.env` berasal dari `String.fromEnvironment` yang konstan, jadi di bundle
/// prod cabang ini konstan-salah dan tak pernah terjangkau.
/// Keputusan gerbangnya sebagai fungsi murni, terpisah dari cara ketiga masukannya
/// diperoleh.
///
/// Dipisah karena tanpa ini gerbangnya praktis tak bisa dibuktikan: `kIsWeb` dan
/// `window.isSecureContext` ditentukan oleh runner tesnya, jadi tes di VM tak pernah
/// menyentuh cabang web, sedangkan tes di Chrome selalu berjalan di `localhost` yang
/// justru secure context. Kombinasi yang paling ingin dijamin — **web + origin tidak
/// tepercaya + prod** — tidak bisa dihadirkan oleh runner mana pun. Sebagai fungsi
/// murni, seluruh tabel kebenarannya bisa diuji di platform apa saja.
@visibleForTesting
bool shouldUsePlaintextFallback({
  required bool isWeb,
  required bool isSecureContext,
  required String env,
}) =>
    isWeb && !isSecureContext && sessionFallbackAllowedForEnv(env);

SessionStore createSessionStore({
  required SharedPreferences preferences,
  required FlutterSecureStorage secureStorage,
}) {
  if (shouldUsePlaintextFallback(
    isWeb: kIsWeb,
    isSecureContext: isBrowserSecureContext(),
    env: AppConfig.env,
  )) {
    debugPrint(
      'AuthRepository: origin bukan secure context (HTTP polos) dan '
      'APP_ENV=${AppConfig.env} — sesi disimpan di localStorage, '
      'bukan secure storage.',
    );
    return PreferencesSessionStore(preferences);
  }
  return SecureSessionStore(
    secureStorage: secureStorage,
    preferences: preferences,
  );
}

/// Jalur normal: Keychain/EncryptedSharedPreferences di native, `crypto.subtle` di web.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({required this.secureStorage, required this.preferences});

  final FlutterSecureStorage secureStorage;
  final SharedPreferences preferences;

  @override
  Future<String?> read() async {
    final raw = await secureStorage.read(key: sessionStorageKey);
    if (raw != null && raw.isNotEmpty) return raw;

    // Migrasi sekali jalan: build lama menyimpan sesi (termasuk refresh token) sebagai
    // teks biasa di SharedPreferences. Pindahkan ke secure storage lalu hapus salinan
    // plaintext-nya, tanpa memaksa pengguna login ulang.
    final legacy = preferences.getString(sessionStorageKey);
    if (legacy == null || legacy.isEmpty) return null;
    await secureStorage.write(key: sessionStorageKey, value: legacy);
    await preferences.remove(sessionStorageKey);
    return legacy;
  }

  @override
  Future<void> write(String value) =>
      secureStorage.write(key: sessionStorageKey, value: value);

  @override
  Future<void> delete() async {
    await secureStorage.delete(key: sessionStorageKey);
    // Defensif: bersihkan juga sisa salinan plaintext dari build lama.
    await preferences.remove(sessionStorageKey);
  }
}

/// Fallback untuk web di origin yang tidak tepercaya. Di web `shared_preferences`
/// bermuara ke `localStorage`, jadi sesi tersimpan sebagai teks biasa.
///
/// Memang lebih lemah, dan karena itu dibatasi ke non-prod. Yang perlu diingat: pada
/// origin HTTP polos token sudah melintas tanpa enkripsi di jaringan, sehingga
/// menguatkan sisi penyimpanan tidak menutup lubang itu. Obat sebenarnya tetap TLS —
/// dan begitu dev memakai HTTPS, jalur ini mati sendiri tanpa perlu ubah kode.
class PreferencesSessionStore implements SessionStore {
  PreferencesSessionStore(this.preferences);

  final SharedPreferences preferences;

  @override
  Future<String?> read() async {
    final raw = preferences.getString(sessionStorageKey);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  @override
  Future<void> write(String value) =>
      preferences.setString(sessionStorageKey, value);

  @override
  Future<void> delete() => preferences.remove(sessionStorageKey);
}
