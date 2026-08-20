import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/network/auth_image.dart';

/// AuthImage memuat gambar lewat ApiClient (butuh bearer token), lalu MENYIMPAN
/// byte-nya di State. Karena State bertahan selama widget dipakai ulang di posisi
/// yang sama, memuat hanya di initState berarti gambar tidak pernah berganti saat
/// `path`-nya berubah — gejalanya: menekan pin/kartu lain, preview-nya masih
/// gambar yang tadi.
///
/// Respons sengaja dibuat 404 di sebagian test: yang diuji adalah KAPAN gambar
/// diminta ulang, dan 404 membuat widget tidak pernah men-decode byte palsu
/// menjadi gambar.
class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.hold = false});

  /// Path yang diminta, berurutan.
  final List<String> requested = [];

  /// Tahan tiap respons sampai test menyelesaikan gerbangnya. Tanpa ini respons
  /// palsu selesai dalam pump yang sama, sehingga keadaan "sedang memuat" lewat
  /// begitu saja dan tak bisa diperiksa.
  final bool hold;
  final List<Completer<void>> gates = [];

  @override
  Future<http.Response> get(String path, {Duration? timeout}) async {
    requested.add(path);
    if (hold) {
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
    }
    // Byte-nya ditandai path-nya supaya bisa dibedakan bila kelak dipakai.
    return http.Response.bytes(path.codeUnits, 404);
  }
}

Future<void> _pumpWithPath(
  WidgetTester tester,
  ApiClient client,
  String path,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AuthImage(apiClient: client, path: path, height: 40),
      ),
    ),
  );
}

void main() {
  testWidgets('path berganti → gambar diminta ulang, bukan memakai yang lama', (
    tester,
  ) async {
    final client = _FakeApiClient();

    await _pumpWithPath(tester, client, '/api/files/satu.jpg');
    await tester.pumpAndSettle();
    expect(client.requested, ['/api/files/satu.jpg']);

    // Widget yang SAMA di posisi yang sama, hanya path-nya berbeda — persis yang
    // terjadi saat popup peta menampilkan kunjungan lain.
    await _pumpWithPath(tester, client, '/api/files/dua.jpg');
    await tester.pumpAndSettle();

    expect(
      client.requested,
      ['/api/files/satu.jpg', '/api/files/dua.jpg'],
      reason: 'tanpa didUpdateWidget, permintaan kedua tidak pernah terjadi dan '
          'preview tetap memperlihatkan gambar sebelumnya',
    );
  });

  testWidgets('path sama dibangun ulang → tidak memuat ulang tanpa perlu', (
    tester,
  ) async {
    final client = _FakeApiClient();

    await _pumpWithPath(tester, client, '/api/files/satu.jpg');
    await tester.pumpAndSettle();
    await _pumpWithPath(tester, client, '/api/files/satu.jpg');
    await tester.pumpAndSettle();

    expect(
      client.requested.length,
      1,
      reason: 'memuat ulang tiap rebuild akan menembak berkas berkali-kali',
    );
  });

  testWidgets('selagi memuat gambar baru: penanda muat, bukan gambar lama', (
    tester,
  ) async {
    final client = _FakeApiClient(hold: true);

    await _pumpWithPath(tester, client, '/api/files/satu.jpg');
    await tester.pump();
    client.gates[0].complete();
    await tester.pumpAndSettle(); // gambar pertama selesai (404 → ikon rusak)
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await _pumpWithPath(tester, client, '/api/files/dua.jpg');
    await tester.pump(); // permintaan kedua berjalan, belum dijawab

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'menahan gambar lama selagi yang baru dimuat membuat pemakai '
          'mengira gambarnya memang milik baris yang barusan ditekan',
    );

    client.gates[1].complete();
    await tester.pumpAndSettle();
  });

  testWidgets('respons lama yang tiba belakangan tidak menimpa yang baru', (
    tester,
  ) async {
    final client = _FakeApiClient(hold: true);

    await _pumpWithPath(tester, client, '/api/files/lambat.jpg');
    await tester.pump();

    // Pemakai keburu menekan gambar lain sebelum yang pertama dijawab.
    await _pumpWithPath(tester, client, '/api/files/cepat.jpg');
    await tester.pump();
    client.gates[1].complete();
    await tester.pumpAndSettle();

    // Baru kemudian respons pertama tiba — harus diabaikan.
    client.gates[0].complete();
    await tester.pumpAndSettle();

    expect(client.requested, ['/api/files/lambat.jpg', '/api/files/cepat.jpg']);
    expect(tester.takeException(), isNull);
  });
}
