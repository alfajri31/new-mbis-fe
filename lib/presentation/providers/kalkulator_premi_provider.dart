import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/src/reference/exchange_rate_service.dart';

/// State ASYNC (data/loading) untuk layar Kalkulator Premi.
///
/// Perhitungan premi di layar ini sepenuhnya client-only dan real-time; satu-
/// satunya bagian ASYNC adalah pengambilan kurs indikatif (FX → IDR, referensi
/// ECB via [ExchangeRateService]). Hanya FLAG loading kurs yang dipindah ke sini.
///
/// SEMUA input form interaktif TETAP di widget `KalkulatorPremiScreen`:
/// controller TSI/rate/diskon/kurs, kategori & produk/jaminan/tenor terpilih,
/// mata uang terpilih, dan checkbox kriteria risiko. Hasil kurs (rate) juga tetap
/// ditulis ke `_kursController` milik widget — provider hanya menyimpan flag muat.
class KalkulatorPremiState {
  /// True selagi kurs indikatif untuk mata uang non-IDR sedang diambil.
  final bool kursLoading;

  const KalkulatorPremiState({this.kursLoading = false});

  KalkulatorPremiState copyWith({bool? kursLoading}) {
    return KalkulatorPremiState(
      kursLoading: kursLoading ?? this.kursLoading,
    );
  }
}

final kalkulatorPremiProvider =
    NotifierProvider<KalkulatorPremiNotifier, KalkulatorPremiState>(
      KalkulatorPremiNotifier.new,
    );

/// Memindahkan logika `setState` ASYNC dari `_KalkulatorPremiScreenState`:
/// flag loading kurs + panggilan FX. Logika dipindah APA ADANYA — kurs ditulis
/// ke controller yang tetap milik widget setelah guard mounted/currency.
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
}
