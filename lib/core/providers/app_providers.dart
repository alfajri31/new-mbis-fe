import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/src/auth/auth_repository.dart';
import 'package:mbis/src/auth/auth_session.dart';
import 'package:mbis/src/network/api_client.dart';

/// Fondasi lapisan Riverpod (Fase 0 migrasi state management).
///
/// Tiga provider inti yang dikonsumsi modul-modul saat dimigrasi dari `setState`:
///  - [sessionProvider]     : sesi auth aktif (di-mirror dari [MbisAppState]).
///  - [apiClientProvider]   : `ApiClient` yang selalu membawa sesi terbaru.
///  - [authRepositoryProvider]: instance `AuthRepository` tunggal (override di main).
///
/// Selama migrasi, `MbisAppState` tetap SUMBER KEBENARAN sesi (router legacy
/// membacanya lewat `currentSession: () => _session`). Ia menyinkronkan setiap
/// perubahan (login/refresh/logout) ke [sessionProvider] agar provider di sini
/// ikut ter-update. Setelah semua modul termigrasi, sumber kebenaran bisa
/// dipindah sepenuhnya ke [sessionProvider].

/// Menyimpan sesi auth untuk lapisan Riverpod. Nilai awal diseed lewat override
/// ProviderScope di `main.dart` (`SessionNotifier(session)`); perubahan berikutnya
/// didorong `MbisAppState` via [set].
class SessionNotifier extends Notifier<AuthSession?> {
  SessionNotifier([this._initial]);

  final AuthSession? _initial;

  @override
  AuthSession? build() => _initial;

  /// Dipanggil MbisAppState tiap sesi berubah (login/refresh/logout).
  void set(AuthSession? session) => state = session;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, AuthSession?>(SessionNotifier.new);

/// Instance `AuthRepository` tunggal aplikasi. Dibuat di `main.dart` (butuh
/// `SharedPreferences`) dan disuntikkan lewat `overrideWithValue` di ProviderScope.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider wajib di-override di ProviderScope (main.dart).',
  ),
);

/// `ApiClient` yang membawa sesi aktif; rebuild otomatis saat [sessionProvider]
/// berubah. Kesegaran token tetap ditangani hook global `ApiClient.tokenProvider`
/// (di-wire di `MbisAppState`), jadi snapshot sesi di sini sudah cukup.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(session: ref.watch(sessionProvider)),
);
