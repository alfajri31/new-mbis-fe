import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/auth/auth_repository.dart';
import 'package:mbis/src/auth/auth_session.dart';
import 'package:mbis/src/auth/secure_context.dart';
import 'package:mbis/src/auth/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tes penyimpanan sesi login.
///
/// Latar: `flutter_secure_storage` v10 di web memakai `crypto.subtle`, yang browser
/// hanya sediakan di *secure context*. Server dev kantor diakses lewat
/// `http://<ip>:<port>` tanpa TLS, sehingga login berhasil (HTTP 200) lalu gagal saat
/// menyimpan sesi dengan `Unsupported operation: FlutterSecureStorageWeb only works in
/// secure contexts`. [PreferencesSessionStore] adalah jalan keluarnya, dan
/// [createSessionStore] yang memutuskan kapan ia dipakai.
///
/// Tes berjalan di Dart VM, jadi `kIsWeb` selalu false dan
/// [isBrowserSecureContext] memakai stub-nya. Karena itu keputusan factory diuji
/// sejauh yang bisa diamati di VM, sedangkan perilaku store-nya diuji langsung.
/// Pengganti [FlutterSecureStorage] berbasis Map.
///
/// `implements` + `noSuchMethod` dipakai supaya hanya tiga metode yang benar-benar
/// dipanggil [SecureSessionStore] yang perlu ditulis; sisanya (readAll, containsKey,
/// deleteAll, listener, ...) tidak relevan dan akan melempar kalau tersentuh — itu
/// justru yang diinginkan, karena berarti tes ini akan gagal kalau store diam-diam
/// mulai memakai API lain.
class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} tidak dipakai di tes ini');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('PreferencesSessionStore', () {
    test('tulis, baca, hapus berputar penuh', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PreferencesSessionStore(prefs);

      expect(await store.read(), isNull, reason: 'awalnya kosong');

      await store.write('{"a":1}');
      expect(await store.read(), '{"a":1}');
      expect(prefs.getString(sessionStorageKey), '{"a":1}',
          reason: 'harus mendarat di kunci yang sama dengan store satunya');

      await store.delete();
      expect(await store.read(), isNull);
    });

    test('string kosong diperlakukan sebagai tidak ada sesi', () async {
      // Kalau ini mengembalikan '' alih-alih null, AuthRepository.loadSession akan
      // menyerahkannya ke jsonDecode dan pengguna melihat error, bukan layar login.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionStorageKey, '');

      expect(await PreferencesSessionStore(prefs).read(), isNull);
    });
  });

  group('SecureSessionStore — jalur yang dipakai prod', () {
    test('tulis, baca, hapus berputar penuh', () async {
      final prefs = await SharedPreferences.getInstance();
      final secure = _FakeSecureStorage();
      final store = SecureSessionStore(secureStorage: secure, preferences: prefs);

      expect(await store.read(), isNull);
      await store.write('{"a":1}');
      expect(secure.data[sessionStorageKey], '{"a":1}');
      expect(await store.read(), '{"a":1}');

      await store.delete();
      expect(await store.read(), isNull);
      expect(secure.data, isEmpty);
    });

    test('memigrasi sesi plaintext dari build lama, lalu menghapus jejaknya', () async {
      // Build lama menyimpan sesi (termasuk refresh token) sebagai teks biasa di
      // SharedPreferences. Logika ini pindah dari AuthRepository.loadSession ke sini;
      // kalau ia rusak, seluruh pengguna lama dipaksa login ulang tanpa sebab jelas.
      SharedPreferences.setMockInitialValues(
        <String, Object>{sessionStorageKey: '{"legacy":true}'},
      );
      final prefs = await SharedPreferences.getInstance();
      final secure = _FakeSecureStorage();
      final store = SecureSessionStore(secureStorage: secure, preferences: prefs);

      expect(await store.read(), '{"legacy":true}');
      expect(secure.data[sessionStorageKey], '{"legacy":true}',
          reason: 'harus dipindahkan ke secure storage');
      expect(prefs.getString(sessionStorageKey), isNull,
          reason: 'salinan teks biasa harus dihapus, bukan ditinggal');
    });

    test('secure storage menang atas sisa plaintext', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{sessionStorageKey: '{"legacy":true}'},
      );
      final prefs = await SharedPreferences.getInstance();
      final secure = _FakeSecureStorage()..data[sessionStorageKey] = '{"baru":true}';
      final store = SecureSessionStore(secureStorage: secure, preferences: prefs);

      expect(await store.read(), '{"baru":true}');
    });

    test('delete juga membersihkan sisa plaintext', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{sessionStorageKey: '{"legacy":true}'},
      );
      final prefs = await SharedPreferences.getInstance();
      final store = SecureSessionStore(
        secureStorage: _FakeSecureStorage(),
        preferences: prefs,
      );

      await store.delete();
      expect(prefs.getString(sessionStorageKey), isNull);
    });
  });

  group('sessionFallbackAllowedForEnv — gerbang paling penting', () {
    test('hanya dev & staging yang boleh', () {
      expect(sessionFallbackAllowedForEnv('dev'), isTrue);
      expect(sessionFallbackAllowedForEnv('staging'), isTrue);
      expect(sessionFallbackAllowedForEnv('prod'), isFalse);
    });

    test('nilai tak dikenal GAGAL-TERTUTUP', () {
      // Inti alasan ini allowlist, bukan `!= prod`. Semua di bawah ini pernah bisa
      // terjadi: salah ketik di Jenkins, konvensi penamaan lain, atau --dart-define
      // yang lupa dipasang. Dengan denylist, semuanya membuka gerbang diam-diam.
      for (final env in ['production', 'PRODUCTION', 'prd', 'live', '', 'test', 'uat']) {
        expect(sessionFallbackAllowedForEnv(env), isFalse,
            reason: "'$env' tidak dikenal — harus menolak fallback");
      }
    });

    test('toleran pada beda huruf besar-kecil & spasi', () {
      // Dimaafkan hanya untuk nilai yang MEMANG ada di allowlist; ini soal ergonomi
      // pengisian variabel CI, bukan pelonggaran gerbang.
      expect(sessionFallbackAllowedForEnv('  Staging '), isTrue);
      expect(sessionFallbackAllowedForEnv('DEV'), isTrue);
    });
  });

  group('shouldUsePlaintextFallback — tabel kebenaran lengkap', () {
    // Delapan kombinasi dari tiga masukan boolean/enum. Ditulis utuh, bukan sampel,
    // karena inilah satu-satunya tempat keputusan itu diambil.
    test('HANYA web + origin tidak tepercaya + env non-prod yang mengizinkan', () {
      for (final isWeb in [true, false]) {
        for (final isSecure in [true, false]) {
          for (final env in ['dev', 'staging', 'prod']) {
            final expected = isWeb && !isSecure && env != 'prod';
            expect(
              shouldUsePlaintextFallback(
                isWeb: isWeb,
                isSecureContext: isSecure,
                env: env,
              ),
              expected,
              reason: 'isWeb=$isWeb isSecureContext=$isSecure env=$env',
            );
          }
        }
      }
    });

    test('web + origin tidak tepercaya + PROD tetap MENOLAK', () {
      // Kombinasi paling penting, dan satu-satunya yang tak bisa dihadirkan runner tes
      // mana pun: runner VM tak punya web, runner Chrome selalu di localhost yang
      // secure context. Kalau baris ini merah, refresh token 7 hari bisa mendarat
      // sebagai teks biasa di produksi.
      expect(
        shouldUsePlaintextFallback(
          isWeb: true,
          isSecureContext: false,
          env: 'prod',
        ),
        isFalse,
      );
    });

    test('native tidak pernah memakai fallback, apa pun env & context-nya', () {
      for (final env in ['dev', 'staging', 'prod', 'apa-saja']) {
        expect(
          shouldUsePlaintextFallback(
            isWeb: false,
            isSecureContext: false,
            env: env,
          ),
          isFalse,
          reason: 'env=$env',
        );
      }
    });

    test('HTTPS/localhost tidak pernah memakai fallback walau env dev', () {
      expect(
        shouldUsePlaintextFallback(
          isWeb: true,
          isSecureContext: true,
          env: 'dev',
        ),
        isFalse,
      );
    });
  });

  group('createSessionStore di platform runner ini', () {
    test('memakai secure storage', () async {
      // Berlaku di kedua runner, dengan alasan berbeda — dan keduanya benar:
      //   `flutter test`                → kIsWeb false, native selalu punya Keychain.
      //   `flutter test --platform chrome` → kIsWeb true, tapi origin-nya localhost
      //                                      sehingga isSecureContext true.
      final prefs = await SharedPreferences.getInstance();
      final store = createSessionStore(
        preferences: prefs,
        secureStorage: const FlutterSecureStorage(),
      );

      expect(store, isA<SecureSessionStore>());
    });

    test('isBrowserSecureContext benar untuk runner yang sedang berjalan', () {
      // Di VM ini menguji stub-nya; di Chrome ini menguji implementasi
      // `package:web`-nya sungguhan, yang berarti `window.isSecureContext` memang
      // terbaca dan berkas web-nya ikut terkompilasi. Keduanya harus true:
      // native tak punya konsep ini, dan runner Chrome memakai localhost.
      expect(isBrowserSecureContext(), isTrue);
    });
  });

  group('AuthRepository memakai SessionStore yang disuntikkan', () {
    // Inti perbaikannya: dengan store fallback, alur simpan/muat sesi harus utuh
    // tanpa menyentuh FlutterSecureStorage sama sekali.
    final session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAt: DateTime.utc(2030, 1, 1),
      refreshTokenExpiresAt: DateTime.utc(2030, 1, 8),
      user: const AuthUser(
        id: 'id-1',
        nip: 'ADMIN',
        name: 'System Administrator',
        email: 'admin@mbis.local',
        roles: ['ADMIN'],
        authMethod: 'LOCAL',
        active: true,
      ),
    );

    test('saveSession lalu loadSession mengembalikan sesi yang sama', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = AuthRepository(
        sharedPreferences: prefs,
        sessionStore: PreferencesSessionStore(prefs),
      );

      await repo.saveSession(session);

      final stored = prefs.getString(sessionStorageKey);
      expect(stored, isNotNull);
      expect(jsonDecode(stored!)['accessToken'], 'access-token');

      final loaded = await repo.loadSession();
      expect(loaded, isNotNull);
      expect(loaded!.accessToken, 'access-token');
      expect(loaded.refreshToken, 'refresh-token');
      expect(loaded.user.nip, 'ADMIN');
    });

    test('clearSession mengosongkan penyimpanan', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = AuthRepository(
        sharedPreferences: prefs,
        sessionStore: PreferencesSessionStore(prefs),
      );

      await repo.saveSession(session);
      await repo.clearSession();

      expect(await repo.loadSession(), isNull);
      expect(prefs.getString(sessionStorageKey), isNull);
    });

    test('isi rusak menghasilkan null, bukan lemparan', () async {
      // localStorage bisa disunting tangan atau tersisa dari format lama; pengguna
      // harus mendarat di layar login, bukan di layar merah.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionStorageKey, 'bukan-json');

      final repo = AuthRepository(
        sharedPreferences: prefs,
        sessionStore: PreferencesSessionStore(prefs),
      );

      expect(await repo.loadSession(), isNull);
    });
  });
}
