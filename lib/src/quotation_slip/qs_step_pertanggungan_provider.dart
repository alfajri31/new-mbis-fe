import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'qs_form_state.dart';

/// State untuk Step 1 Pertanggungan di Quotation Slip.
class QsStepPertanggunganState {
  final QsProduct product;
  final QsType type;
  final QsPremiMode premiMode;
  final DateTime? tglLahir;
  final DateTime? tglMulai;
  final DateTime? tglAkhir;
  final bool dataSamaPolis;
  final int? klasifikasiPeserta;
  final bool showStd;
  final String pekerjaan;

  const QsStepPertanggunganState({
    this.product = QsProduct.psakdi,
    this.type = QsType.single,
    this.premiMode = QsPremiMode.normal,
    this.tglLahir,
    this.tglMulai,
    this.tglAkhir,
    this.dataSamaPolis = false,
    this.klasifikasiPeserta = 1,
    this.showStd = false,
    this.pekerjaan = 'Karyawan',
  });

  QsStepPertanggunganState copyWith({
    QsProduct? product,
    QsType? type,
    QsPremiMode? premiMode,
    DateTime? Function()? tglLahir,
    DateTime? Function()? tglMulai,
    DateTime? Function()? tglAkhir,
    bool? dataSamaPolis,
    int? Function()? klasifikasiPeserta,
    bool? showStd,
    String? pekerjaan,
  }) {
    return QsStepPertanggunganState(
      product: product ?? this.product,
      type: type ?? this.type,
      premiMode: premiMode ?? this.premiMode,
      tglLahir: tglLahir != null ? tglLahir() : this.tglLahir,
      tglMulai: tglMulai != null ? tglMulai() : this.tglMulai,
      tglAkhir: tglAkhir != null ? tglAkhir() : this.tglAkhir,
      dataSamaPolis: dataSamaPolis ?? this.dataSamaPolis,
      klasifikasiPeserta:
          klasifikasiPeserta != null ? klasifikasiPeserta() : this.klasifikasiPeserta,
      showStd: showStd ?? this.showStd,
      pekerjaan: pekerjaan ?? this.pekerjaan,
    );
  }

  /// Jumlah hari antara tanggal mulai dan tanggal akhir.
  int get jumlahHari {
    if (tglMulai == null || tglAkhir == null) return 0;
    return tglAkhir!.difference(tglMulai!).inDays;
  }

  /// Menandakan apakah tanggal akhir <= tanggal mulai.
  bool get isEndBad {
    if (tglMulai != null && tglAkhir != null) {
      return !tglAkhir!.isAfter(tglMulai!);
    }
    return false;
  }

  /// Pesan error validasi usia bila tidak memenuhi syarat produk.
  String? get usiaError => validasiUsia(product, tglLahir, tglMulai);

  /// Saran kelas pekerjaan otomatis.
  int? get saranKelasResult => saranKelas(pekerjaan);
}

/// Notifier pengelola state Step 1 Pertanggungan.
class QsStepPertanggunganNotifier extends Notifier<QsStepPertanggunganState> {
  @override
  QsStepPertanggunganState build() => const QsStepPertanggunganState();

  /// Sinkronisasi awal atau update menyeluruh dari props.
  void init({
    required QsProduct product,
    required QsType type,
    required QsPremiMode premiMode,
    DateTime? tglLahir,
    DateTime? tglMulai,
    DateTime? tglAkhir,
    bool dataSamaPolis = false,
    int? klasifikasiPeserta = 1,
    String pekerjaan = '',
  }) {
    state = state.copyWith(
      product: product,
      type: type,
      premiMode: premiMode,
      tglLahir: () => tglLahir,
      tglMulai: () => tglMulai,
      tglAkhir: () => tglAkhir,
      dataSamaPolis: dataSamaPolis,
      klasifikasiPeserta: () => klasifikasiPeserta,
      pekerjaan: pekerjaan,
    );
  }


  void setType(QsType type) {
    state = state.copyWith(type: type);
  }

  void setPremiMode(QsPremiMode mode) {
    state = state.copyWith(premiMode: mode);
  }

  void setTglLahir(DateTime? d) {
    state = state.copyWith(tglLahir: () => d);
  }

  void setTglMulai(DateTime? d) {
    state = state.copyWith(tglMulai: () => d);
  }

  void setTglAkhir(DateTime? d) {
    state = state.copyWith(tglAkhir: () => d);
  }

  void setDataSamaPolis(bool v) {
    state = state.copyWith(dataSamaPolis: v);
  }

  void setKlasifikasiPeserta(int? k) {
    state = state.copyWith(klasifikasiPeserta: () => k);
  }

  void toggleShowStd() {
    state = state.copyWith(showStd: !state.showStd);
  }

  void setPekerjaan(String p) {
    state = state.copyWith(pekerjaan: p);
  }
}

/// Provider Riverpod untuk state Step 1 Pertanggungan.
final qsStepPertanggunganProvider =
    NotifierProvider<QsStepPertanggunganNotifier, QsStepPertanggunganState>(
  QsStepPertanggunganNotifier.new,
);
