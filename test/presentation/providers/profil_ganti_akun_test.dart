import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/presentation/providers/profil_provider.dart';
import 'package:mbis/src/auth/auth_session.dart';
import 'package:mbis/src/network/api_client.dart';

/// TEMUAN UAT: setelah berpindah akun tanpa menutup aplikasi, layar Profil masih
/// menampilkan nama, NIP, dan email pemilik sesi SEBELUMNYA — sementara beranda
/// sudah benar. Penyebabnya `start()` berhenti lebih awal begitu future-nya ada,
/// padahal `profilProvider` hidup selama proses aplikasi dan tidak pernah
/// di-invalidate saat logout.
///
/// Di perangkat bersama, sisa itu bukan sekadar salah nama: identitas pengguna
/// lain ikut terbaca. Test ini mengunci bahwa pergantian sesi memuat ulang.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(this._profil);

  /// Profil yang dikembalikan /api/auth/me, diganti saat sesi berpindah —
  /// meniru server yang menjawab sesuai token pemanggil.
  Map<String, dynamic> _profil;
  int panggilan = 0;

  set profil(Map<String, dynamic> p) => _profil = p;

  @override
  Future<http.Response> get(String path, {Duration? timeout}) async {
    panggilan++;
    return http.Response(jsonEncode(_profil), 200,
        headers: {'content-type': 'application/json'});
  }
}

AuthSession _sesi(String id, String nip, String nama) => AuthSession.fromJson({
  'accessToken': 'token-$id',
  'user': {
    'id': id,
    'nip': nip,
    'name': nama,
    'email': '$nip@mbis.local',
    'roles': ['RM'],
  },
});

Map<String, dynamic> _me(String nip, String nama) => {
  'nip': nip,
  'name': nama,
  'email': '$nip@mbis.local',
  'officeId': 'KC-025',
  'roles': ['RM'],
};

void main() {
  late _FakeApiClient api;
  late ProviderContainer container;

  ProviderContainer buat(AuthSession sesi) {
    api = _FakeApiClient(_me('979', 'I Wayan Arya Antara'));
    return ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => SessionNotifier(sesi)),
        apiClientProvider.overrideWithValue(api),
      ],
    );
  }

  tearDown(() => container.dispose());

  test('profil dimuat ulang saat sesi berganti pengguna', () async {
    container = buat(_sesi('USR-979', '979', 'I Wayan Arya Antara'));
    final notifier = container.read(profilProvider.notifier);

    notifier.start();
    final pertama = await container.read(profilProvider).future!;
    expect(pertama.name, 'I Wayan Arya Antara');
    expect(pertama.nip, '979');
    expect(api.panggilan, 1);

    // Pengguna logout lalu login sebagai Branch Manager, aplikasi TIDAK ditutup.
    api.profil = _me('1224', 'Azhari Nur Kusumo');
    container.read(sessionProvider.notifier)
        .set(_sesi('USR-1224', '1224', 'Azhari Nur Kusumo'));

    notifier.start();
    final kedua = await container.read(profilProvider).future!;
    expect(api.panggilan, 2, reason: '/api/auth/me harus dipanggil ulang');
    expect(kedua.name, 'Azhari Nur Kusumo');
    expect(kedua.nip, '1224',
        reason: 'NIP pengguna sebelumnya tidak boleh tertinggal di layar Profil');
  });

  test('membuka Profil berulang pada sesi yang sama tidak memuat ulang', () async {
    container = buat(_sesi('USR-979', '979', 'I Wayan Arya Antara'));
    final notifier = container.read(profilProvider.notifier);

    notifier.start();
    await container.read(profilProvider).future!;
    notifier.start();
    notifier.start();

    expect(api.panggilan, 1,
        reason: 'perilaku hemat panggilan yang lama tetap dipertahankan');
  });
}
