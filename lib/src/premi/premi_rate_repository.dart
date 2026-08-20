import 'dart:convert';

import '../network/api_client.dart';

/// Rate default satu slot kalkulator (MTR-2), sebagaimana disimpan admin.
///
/// [ratePercent] (angka awal yang tampil) dan [minRatePercent] (batas bawah yang
/// boleh ditawarkan) sama-sama dalam PERSEN (3.5 = 3,5%) — sama dengan angka yang
/// diketik di kalkulator, tanpa konversi di jalan.
///
/// [minRatePercent] null berarti slot ini TANPA batas bawah, bukan batas bawah nol
/// persen; keduanya berbeda saat kalkulator memutuskan boleh-tidaknya sebuah rate.
class PremiRateDefault {
  final String slotKey;
  final double ratePercent;
  final double? minRatePercent;
  final DateTime? updatedAt;
  final String? updatedByName;

  const PremiRateDefault({
    required this.slotKey,
    required this.ratePercent,
    this.minRatePercent,
    this.updatedAt,
    this.updatedByName,
  });

  /// True bila [rate] di bawah batas bawah slot ini. Slot tanpa batas bawah selalu
  /// false — tidak ada yang bisa dilanggar.
  bool melanggarBatasBawah(double? rate) {
    final min = minRatePercent;
    if (min == null || rate == null) return false;
    return rate < min;
  }

  factory PremiRateDefault.fromJson(Map<String, dynamic> j) => PremiRateDefault(
        slotKey: j['slotKey']?.toString() ?? '',
        ratePercent: (j['ratePercent'] as num?)?.toDouble() ?? 0,
        minRatePercent: (j['minRatePercent'] as num?)?.toDouble(),
        updatedAt: _parseUtc(j['updatedAt']?.toString()),
        updatedByName: j['updatedByName']?.toString(),
      );

  /// Backend menyimpan waktu dalam UTC tapi mengirimnya TANPA penanda zona
  /// (`2026-08-20T09:02:30.535744`, bukan `...Z`), sedangkan [DateTime.parse]
  /// membaca teks tanpa penanda sebagai waktu LOKAL. Dibiarkan apa adanya, "terakhir
  /// diperbarui" tampil mundur 7 jam di WIB — cukup untuk menggeser TANGGAL bila
  /// admin menyimpannya di pagi hari. Karena itu penandanya ditambahkan di sini
  /// sebelum dikonversi ke zona perangkat.
  static DateTime? _parseUtc(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final berzona =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    return DateTime.tryParse(berzona ? raw : '${raw}Z')?.toLocal();
  }
}

/// Akses API rate default Kalkulator Premi.
///
/// Baca terbuka untuk semua peran pemakai kalkulator; tulis & hapus hanya ADMIN
/// (`/api/admin/premi-rates`, dijawab 403 untuk peran lain). Gerbang admin di UI
/// hanya menghindarkan pintu yang pasti tertutup — yang menentukan tetap server.
class PremiRateRepository {
  final ApiClient apiClient;
  PremiRateRepository({required this.apiClient});

  /// Seluruh rate default, dipetakan slotKey → rate. Daftarnya kecil (satu baris
  /// per slot terisi, puluhan) sehingga diambil sekaligus, bukan per pilihan
  /// produk — kalkulator jadi tidak perlu menunggu jaringan tiap ganti pilihan.
  Future<Map<String, PremiRateDefault>> fetchAll() async {
    final res = await apiClient.get('/api/premi-rates');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      final map = <String, PremiRateDefault>{};
      for (final j in list) {
        final item = PremiRateDefault.fromJson(j as Map<String, dynamic>);
        if (item.slotKey.isNotEmpty) map[item.slotKey] = item;
      }
      return map;
    }
    throw Exception(_message(res.body, 'Gagal memuat rate default'));
  }

  /// Simpan/perbarui rate default satu slot (ADMIN). [ratePercent] & [minRatePercent]
  /// dalam persen; [minRatePercent] null = slot tanpa batas bawah. Server menolak
  /// default yang lebih rendah dari batas bawahnya sendiri.
  ///
  /// Bagian uraian slot ikut dikirim hanya agar baris di DB terbaca manusia saat
  /// audit; yang mengikat tetap [slotKey].
  Future<PremiRateDefault> save({
    required String slotKey,
    required double ratePercent,
    double? minRatePercent,
    String? productName,
    String? riskTier,
    String? jaminan,
    String? tenor,
  }) async {
    final res = await apiClient.put('/api/admin/premi-rates', body: {
      'slotKey': slotKey,
      'ratePercent': ratePercent,
      'minRatePercent': minRatePercent,
      'productName': productName,
      'riskTier': riskTier,
      'jaminan': jaminan,
      'tenor': tenor,
    });
    if (res.statusCode == 200) {
      return PremiRateDefault.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal menyimpan rate default'));
  }

  /// Hapus rate default satu slot (ADMIN) — kalkulator kembali ke isian kosong.
  ///
  /// POST `/clear` berbadan JSON, bukan DELETE ber-URL: kunci slot memuat `|`, spasi,
  /// dan `>`, dan menaruhnya di URL sudah dua kali meleset diam-diam saat fitur ini
  /// dibuat (encoding bentuk form, lalu `%` yang ter-encode ulang). Body membawa kunci
  /// verbatim. Slot yang tidak ada dijawab 404 oleh server — sengaja, supaya kunci yang
  /// salah tidak terbaca sebagai penghapusan yang berhasil.
  Future<void> clear(String slotKey) async {
    final res = await apiClient.post(
      '/api/admin/premi-rates/clear',
      body: {'slotKey': slotKey},
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus rate default'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {}
    return fallback;
  }
}
