import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/announcement/announcement_repository.dart';
import 'package:mbis/src/dashboard/dashboard_periode.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';

const Object _keep = Object();

/// State dashboard — cerminan 1:1 dari field `setState` di `_DashboardScreenState`.
/// Hanya state DATA/LOADING/pilihan kategori yang dipindah ke sini; state UI
/// murni (expand daftar per-office) tetap di layar.
class DashboardState {
  final bool loading;
  final String? error;
  final DashboardSummary? summary;
  final List<DashboardSchedule> schedules;
  final List<Announcement> announcements;
  final DashboardDrilldown? drilldown;
  // Filter 11 target: kategori terpilih menggerakkan progress bar + Target/
  // Realisasi YTD. Default `Non Program Non Askred` (dari server).
  final DashboardCategories? categories;
  final String? selectedCategory;

  /// Realisasi per sumber bisnis (CR-03). Hanya realisasi — target di M-BIS tidak
  /// punya dimensi sumber bisnis. null = belum termuat / gagal dimuat.
  final DashboardSumberBisnis? sumberBisnis;

  /// Tahun periode terpilih (C2). null = tahun berjalan (default server).
  final int? selectedYear;

  /// Potongan periode dalam tahun terpilih (CR-02): YTD / MTD / Triwulan.
  /// Disimpan di sini, bukan di layar, supaya pilihannya bertahan saat pengguna
  /// berpindah tab dan kembali — provider ini hidup selama sesi.
  final DashboardPeriode selectedPeriode;

  const DashboardState({
    this.loading = true,
    this.error,
    this.summary,
    this.schedules = const [],
    this.announcements = const [],
    this.drilldown,
    this.categories,
    this.selectedCategory,
    this.sumberBisnis,
    this.selectedYear,
    this.selectedPeriode = DashboardPeriode.ytd,
  });

  DashboardState copyWith({
    bool? loading,
    Object? error = _keep,
    Object? summary = _keep,
    List<DashboardSchedule>? schedules,
    List<Announcement>? announcements,
    Object? drilldown = _keep,
    Object? categories = _keep,
    Object? sumberBisnis = _keep,
    Object? selectedCategory = _keep,
    Object? selectedYear = _keep,
    DashboardPeriode? selectedPeriode,
  }) {
    return DashboardState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      summary: summary == _keep ? this.summary : summary as DashboardSummary?,
      schedules: schedules ?? this.schedules,
      announcements: announcements ?? this.announcements,
      drilldown: drilldown == _keep
          ? this.drilldown
          : drilldown as DashboardDrilldown?,
      categories: categories == _keep
          ? this.categories
          : categories as DashboardCategories?,
      sumberBisnis: sumberBisnis == _keep
          ? this.sumberBisnis
          : sumberBisnis as DashboardSumberBisnis?,
      selectedCategory: selectedCategory == _keep
          ? this.selectedCategory
          : selectedCategory as String?,
      selectedYear:
          selectedYear == _keep ? this.selectedYear : selectedYear as int?,
      selectedPeriode: selectedPeriode ?? this.selectedPeriode,
    );
  }

  /// Kategori terpilih (atau default) beserta angka target/realisasinya.
  /// Derivasi murni — menggantikan getter `_selectedCat` di layar.
  DashboardCategoryStat? get selectedCat {
    final c = categories;
    if (c == null) return null;
    return c.byName(selectedCategory ?? c.defaultCategory);
  }

  /// Bulan terakhir yang punya data pada tahun terpilih: bulan berjalan untuk tahun
  /// ini, 12 untuk tahun yang sudah lewat. Diambil dari server, bukan dihitung ulang
  /// di klien, supaya batas periode tidak pernah berbeda dari sumber angkanya.
  int get currentMonth => categories?.currentMonth ?? DateTime.now().month;

  /// Target & realisasi kategori terpilih untuk periode terpilih. null bila data
  /// kategori belum termuat — di situ layar tetap memakai angka ringkasan lama.
  AngkaPeriode? get angkaPeriode {
    final cat = selectedCat;
    if (cat == null) return null;
    return hitungPeriode(cat, selectedPeriode, currentMonth);
  }

  /// Realisasi tiap sumber bisnis untuk periode terpilih, dalam URUTAN TETAP.
  ///
  /// Sengaja tidak diurutkan dari terbesar: warnanya melekat pada kanal, bukan pada
  /// peringkat. Kalau urutannya ikut nilai, sebuah kanal akan berganti warna hanya
  /// karena bulan berganti — dan pembaca kehilangan kemampuan mengenalinya sekilas.
  ///
  /// Kanal di luar tiga utama (Bancassurance, TPM, tipe tak dikenal) dilipat jadi
  /// "Lainnya": lima warna kategorikal tidak bisa dibedakan dengan aman oleh mata
  /// buta warna, sedangkan empat bisa. Nilainya tidak hilang, hanya digabung.
  ///
  /// Kanal bernilai nol TETAP disertakan — baris yang lenyap terbaca sebagai "belum
  /// diukur", padahal artinya "belum ada". Kosong bila datanya belum termuat.
  List<({String kunci, String label, double realisasi})> get realisasiPerSumber {
    final sb = sumberBisnis;
    if (sb == null) return const [];
    final bulan = selectedPeriode.months(currentMonth);
    double direct = 0;
    double agen = 0;
    double broker = 0;
    double lainnya = 0;
    for (final row in sb.sumber) {
      final nilai = row.realisasiUntuk(bulan);
      switch (row.sourceType) {
        case 'DIRECT':
          direct += nilai;
        case 'AGENT':
          agen += nilai;
        case 'BROKER':
          broker += nilai;
        default:
          lainnya += nilai;
      }
    }
    return [
      (kunci: 'DIRECT', label: 'Direct', realisasi: direct),
      (kunci: 'AGENT', label: 'Agen', realisasi: agen),
      (kunci: 'BROKER', label: 'Broker', realisasi: broker),
      (kunci: 'LAINNYA', label: 'Lainnya', realisasi: lainnya),
    ];
  }

  /// Total realisasi seluruh kanal pada periode terpilih (dasar porsi & angka total).
  double get totalRealisasiSumber =>
      realisasiPerSumber.fold<double>(0, (a, b) => a + b.realisasi);

  /// Total pipeline aktif (P1+P2+P3). Menggantikan getter `_activePipelines`.
  int get activePipelines {
    final s = summary;
    if (s == null) return 0;
    return s.pipelinesP1 + s.pipelinesP2 + s.pipelinesP3;
  }

  /// Success rate (%) = won / (won + decline + aktif). Menggantikan `_successRate`.
  int get successRate {
    final s = summary;
    if (s == null) return 0;
    final total = s.pipelinesWon + s.pipelinesDecline + activePipelines;
    if (total == 0) return 0;
    return ((s.pipelinesWon / total) * 100).round();
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

/// Menggantikan seluruh logika `setState` di `_DashboardScreenState`.
/// Perilaku (urutan fetch, guard best-effort per sumber, gating RM untuk jadwal,
/// jalur silent refresh) DIPINDAH APA ADANYA.
class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardState();

  DashboardRepository get _repo => ref.read(dashboardRepoProvider);
  AnnouncementRepository get _announcementRepo =>
      ref.read(announcementRepoProvider);

  /// Jadwal = fitur RM saja. Sama seperti gating `_isRm` di layar, tapi sesi
  /// dibaca dari [sessionProvider] (Notifier tak punya context).
  bool get _isRm =>
      (ref.read(sessionProvider)?.user.roles ?? const []).contains('RM');

  /// Dipanggil sekali dari initState layar (post-frame). Bootstrap data dashboard.
  /// Menggantikan konstruksi repo + `_fetch()` di `initState`.
  void start() {
    fetch();
  }

  Future<void> fetch({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, error: null);
    }
    try {
      final year = state.selectedYear; // null = tahun berjalan (default server)
      final summary = await _repo.getSummary(
          year: year, category: state.selectedCategory);
      // Schedules are RM-only and non-blocking: a failure shouldn't sink the page.
      // (Supervisors/admin don't have a personal visit schedule, so skip the call.)
      List<DashboardSchedule> schedules = const [];
      if (_isRm) {
        try {
          schedules = await _repo.getSchedules();
        } catch (_) {}
      }
      // Announcements are non-critical: never let a banner error block the dashboard.
      List<Announcement> announcements = const [];
      try {
        announcements = await _announcementRepo.feed();
      } catch (_) {}
      // Drill-down is best-effort: cards still render, drill-down sheet shows '-'.
      DashboardDrilldown? drilldown;
      try {
        drilldown = await _repo.getDrilldown(
            year: year, category: state.selectedCategory);
      } catch (_) {}
      // Filter 11 target: best-effort (kartu utama tetap render kalau gagal).
      DashboardCategories? categories;
      try {
        categories = await _repo.getCategories(year: year);
      } catch (_) {}
      // Sumber bisnis: best-effort juga — bagian pelengkap, tidak boleh menjatuhkan
      // dashboard kalau endpointnya belum ada (mis. aplikasi baru vs server lama).
      DashboardSumberBisnis? sumberBisnis;
      try {
        sumberBisnis = await _repo.getSumberBisnis(
            year: year,
            category: state.selectedCategory ?? categories?.defaultCategory);
      } catch (_) {}
      state = state.copyWith(
        summary: summary,
        schedules: schedules,
        announcements: announcements,
        drilldown: drilldown,
        categories: categories,
        sumberBisnis: sumberBisnis,
        selectedCategory: state.selectedCategory ?? categories?.defaultCategory,
        loading: false,
      );
    } catch (e) {
      // On a silent background refresh, keep the currently-displayed dashboard
      // rather than replacing it with a full-screen error for a transient blip.
      if (silent) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  /// Ganti kategori terpilih (dropdown 11 target).
  ///
  /// Target & realisasi tidak perlu fetch: payload kategori sudah memuat seluruh
  /// kategori sekaligus. Yang disaring DI SERVER ada dua — sumber bisnis, dan
  /// (sejak CR-09) hitungan kunjungan pada drill-down — jadi keduanya diambil
  /// ulang di sini.
  void onCategoryChanged(String category) {
    state = state.copyWith(selectedCategory: category);
    _muatSumberBisnis(category);
    _muatDrilldown(category);
    _muatSummary(category);
  }

  /// Ambil ulang angka headline agar funnel pipeline, potensi premi, dan
  /// Success Rate ikut kategori.
  ///
  /// Best-effort seperti dua pemuat di atas: gagal berarti angka lama bertahan,
  /// bukan dashboard kosong. Hasil yang datang setelah kategori berganti lagi
  /// dibuang — angka berlabel kategori yang salah lebih buruk daripada angka lama.
  Future<void> _muatSummary(String category) async {
    try {
      final summary = await _repo.getSummary(
          year: state.selectedYear, category: category);
      if (state.selectedCategory == category) {
        state = state.copyWith(summary: summary);
      }
    } catch (_) {}
  }

  /// Ambil ulang sumber bisnis untuk kategori terpilih. Best-effort: kegagalan
  /// membiarkan angka lama tetap tampil, bukan mengosongkan bagian itu.
  Future<void> _muatSumberBisnis(String category) async {
    try {
      final sb = await _repo.getSumberBisnis(
          year: state.selectedYear, category: category);
      // Kategori bisa sudah berganti lagi selama permintaan berjalan; hasil yang
      // kedaluwarsa dibuang supaya layar tak menampilkan kategori yang salah.
      if (state.selectedCategory == category) {
        state = state.copyWith(sumberBisnis: sb);
      }
    } catch (_) {}
  }

  /// Ambil ulang drill-down agar hitungan kunjungan ikut kategori (CR-09).
  ///
  /// Best-effort dan tidak mengosongkan apa pun saat gagal: angka kunjungan lama
  /// masih lebih berguna daripada tanda hubung, dan kartu lain tidak bergantung
  /// pada permintaan ini.
  Future<void> _muatDrilldown(String category) async {
    try {
      final d = await _repo.getDrilldown(
          year: state.selectedYear, category: category);
      if (state.selectedCategory == category) {
        state = state.copyWith(drilldown: d);
      }
    } catch (_) {}
  }

  /// Ganti tahun periode (C2). Beda dgn kategori: angka datang dari server, jadi
  /// WAJIB fetch ulang. null = kembali ke tahun berjalan.
  void onYearChanged(int? year) {
    if (year == state.selectedYear) return;
    state = state.copyWith(selectedYear: year);
    fetch();
  }

  /// Ganti potongan periode (CR-02). Sekelompok dengan kategori, bukan dengan tahun:
  /// server sudah mengirim 12 bulan sekaligus, jadi cukup menghitung ulang angka
  /// turunan tanpa fetch — pergantian filter terasa seketika.
  void onPeriodeChanged(DashboardPeriode periode) {
    if (periode == state.selectedPeriode) return;
    state = state.copyWith(selectedPeriode: periode);
  }
}
