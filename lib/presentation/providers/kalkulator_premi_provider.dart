import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/src/premi/premi_rate_repository.dart';
import 'package:mbis/src/reference/exchange_rate_service.dart';

/// State ASYNC (data/loading) untuk layar Kalkulator Premi.
///
/// Perhitungan premi di layar ini sepenuhnya client-only dan real-time. Bagian
/// ASYNC-nya ada dua: kurs indikatif (FX → IDR, referensi ECB via
/// [ExchangeRateService]) dan **rate default per produk** yang diisi admin (MTR-2,
/// lihat [PremiRateRepository]).
///
/// SEMUA input form interaktif TETAP di widget `KalkulatorPremiScreen`:
/// controller TSI/rate/diskon/kurs, kategori & produk/jaminan/tenor terpilih,
/// mata uang terpilih, dan checkbox kriteria risiko. Hasil kurs (rate) juga tetap
/// ditulis ke `_kursController` milik widget — provider hanya menyimpan flag muat.
/// Rate default pun begitu: provider menyimpan PETA rate milik admin, sedangkan
/// angka yang sedang diketik tetap milik controller widget. Pemisahan ini yang
/// membuat timpaan user bersifat sementara — ia tidak pernah masuk ke sini.
class KalkulatorPremiState {
  /// True selagi kurs indikatif untuk mata uang non-IDR sedang diambil.
  final bool kursLoading;

  /// Rate default milik admin, slotKey → rate. Kosong = belum dimuat, gagal
  /// dimuat, atau memang belum ada yang diisi admin — ketiganya diperlakukan
  /// sama oleh kalkulator: isian rate dikosongkan, user mengetik sendiri.
  final Map<String, PremiRateDefault> rateDefaults;

  /// True selagi daftar rate default diambil (sekali saat layar dibuka).
  final bool rateDefaultsLoading;

  /// Kapan daftar rate terakhir berhasil diambil; null = belum pernah. Dipakai
  /// menahan pengambilan ulang yang tidak perlu (lihat [KalkulatorPremiNotifier
  /// .loadRateDefaults]).
  final DateTime? rateDefaultsLoadedAt;

  const KalkulatorPremiState({
    this.kursLoading = false,
    this.rateDefaults = const {},
    this.rateDefaultsLoading = false,
    this.rateDefaultsLoadedAt,
  });

  KalkulatorPremiState copyWith({
    bool? kursLoading,
    Map<String, PremiRateDefault>? rateDefaults,
    bool? rateDefaultsLoading,
    DateTime? rateDefaultsLoadedAt,
  }) {
    return KalkulatorPremiState(
      kursLoading: kursLoading ?? this.kursLoading,
      rateDefaults: rateDefaults ?? this.rateDefaults,
      rateDefaultsLoading: rateDefaultsLoading ?? this.rateDefaultsLoading,
      rateDefaultsLoadedAt: rateDefaultsLoadedAt ?? this.rateDefaultsLoadedAt,
    );
  }

  /// Rate default untuk satu slot; null bila slot itu belum diisi admin.
  PremiRateDefault? defaultFor(String slotKey) => rateDefaults[slotKey];
}

final kalkulatorPremiProvider =
    NotifierProvider<KalkulatorPremiNotifier, KalkulatorPremiState>(
      KalkulatorPremiNotifier.new,
    );

/// Memindahkan logika `setState` ASYNC dari `_KalkulatorPremiScreenState`:
/// flag loading kurs + panggilan FX, plus peta rate default milik admin.
class KalkulatorPremiNotifier extends Notifier<KalkulatorPremiState> {
  @override
  KalkulatorPremiState build() => const KalkulatorPremiState();

  /// Set flag loading kurs (dipakai saat mulai/selesai/ganti ke IDR).
  void setKursLoading(bool loading) =>
      state = state.copyWith(kursLoading: loading);

  /// Ambil kurs indikatif (1 [cur] ke IDR) — pola sama seperti add_pipeline
  /// (referensi ECB, bisa di-override manual). Set loading true saat mulai;
  /// mengembalikan rate (null bila gagal/tak tersedia). Reset loading & penulisan
  /// hasil ke `_kursController` dilakukan pemanggil (widget) setelah guard
  /// mounted/currency, agar kurs tetap ditulis ke controller milik widget.
  Future<double?> loadKursToIdr(String cur) async {
    state = state.copyWith(kursLoading: true);
    return ExchangeRateService.rateToIdr(cur);
  }

  /// Berapa lama daftar rate dianggap masih segar. Rate berubah hanya saat admin
  /// menyimpannya, jadi menahan pengambilan ulang selama beberapa menit tidak
  /// membuat siapa pun melihat angka yang keliru — sementara tanpa penahan ini,
  /// membuka-tutup layar kalkulator N kali berarti N request.
  static const Duration rateDefaultsTtl = Duration(minutes: 5);

  /// Sumber waktu, bisa diganti test untuk menguji kedaluwarsa TTL tanpa menunggu.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  /// Pengambilan yang sedang berjalan, kalau ada. Penjaga single-flight: dua
  /// pemicu yang berdekatan (mis. layar dibuka dua kali cepat, atau frame pertama
  /// terpanggil ulang) hanya menghasilkan SATU request.
  Future<void>? _rateDefaultsInFlight;

  /// Muat seluruh rate default + batas bawah milik admin.
  ///
  /// Dipanggil tiap kali layar kalkulator dibuka, tapi TIDAK selalu menembak server:
  /// permintaan dilewati bila datanya masih segar ([rateDefaultsTtl]), dan permintaan
  /// yang sedang berjalan dipakai bersama alih-alih dimulai lagi. [force] melewati
  /// penahan itu untuk pemuatan ulang yang memang disengaja.
  ///
  /// Kegagalan sengaja DITELAN, bukan dilempar: kalkulator tetap berfungsi penuh
  /// tanpa rate default (user mengetik sendiri, persis perilaku sebelum MTR-2),
  /// jadi memblokir layar karena satu request gagal justru menghilangkan fitur
  /// yang masih bisa dipakai. Kegagalan juga tidak menyegel TTL — [rateDefaultsLoadedAt]
  /// hanya diperbarui saat berhasil, sehingga pembukaan layar berikutnya mencoba lagi.
  Future<void> loadRateDefaults(PremiRateRepository repo, {bool force = false}) {
    final terakhir = state.rateDefaultsLoadedAt;
    if (!force &&
        terakhir != null &&
        now().difference(terakhir) < rateDefaultsTtl) {
      return Future<void>.value();
    }

    final berjalan = _rateDefaultsInFlight;
    if (berjalan != null) return berjalan;

    final future = _fetchRateDefaults(repo);
    _rateDefaultsInFlight = future;
    return future;
  }

  Future<void> _fetchRateDefaults(PremiRateRepository repo) async {
    state = state.copyWith(rateDefaultsLoading: true);
    try {
      final map = await repo.fetchAll();
      state = state.copyWith(
        rateDefaults: map,
        rateDefaultsLoading: false,
        rateDefaultsLoadedAt: now(),
      );
    } catch (_) {
      state = state.copyWith(rateDefaultsLoading: false);
    } finally {
      _rateDefaultsInFlight = null;
    }
  }

  /// Simpan rate default satu slot (ADMIN) lalu perbarui peta lokal. Melempar
  /// bila gagal — di sini pemanggil MEMANG perlu tahu: admin baru saja menekan
  /// "simpan", dan diam berarti ia mengira angkanya sudah tayang ke semua RM.
  Future<void> saveRateDefault(
    PremiRateRepository repo, {
    required String slotKey,
    required double ratePercent,
    double? minRatePercent,
    String? productName,
    String? riskTier,
    String? jaminan,
    String? tenor,
  }) async {
    final saved = await repo.save(
      slotKey: slotKey,
      ratePercent: ratePercent,
      minRatePercent: minRatePercent,
      productName: productName,
      riskTier: riskTier,
      jaminan: jaminan,
      tenor: tenor,
    );
    state = state.copyWith(
      rateDefaults: {...state.rateDefaults, slotKey: saved},
    );
  }

  /// Hapus rate default satu slot (ADMIN) lalu perbarui peta lokal. Melempar
  /// bila gagal, dengan alasan yang sama seperti [saveRateDefault].
  Future<void> clearRateDefault(PremiRateRepository repo, String slotKey) async {
    await repo.clear(slotKey);
    final next = {...state.rateDefaults}..remove(slotKey);
    state = state.copyWith(rateDefaults: next);
  }
}
