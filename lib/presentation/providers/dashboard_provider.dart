import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/announcement/announcement_repository.dart';
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

  /// Tahun periode terpilih (C2). null = tahun berjalan (default server).
  final int? selectedYear;

  const DashboardState({
    this.loading = true,
    this.error,
    this.summary,
    this.schedules = const [],
    this.announcements = const [],
    this.drilldown,
    this.categories,
    this.selectedCategory,
    this.selectedYear,
  });

  DashboardState copyWith({
    bool? loading,
    Object? error = _keep,
    Object? summary = _keep,
    List<DashboardSchedule>? schedules,
    List<Announcement>? announcements,
    Object? drilldown = _keep,
    Object? categories = _keep,
    Object? selectedCategory = _keep,
    Object? selectedYear = _keep,
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
      selectedCategory: selectedCategory == _keep
          ? this.selectedCategory
          : selectedCategory as String?,
      selectedYear:
          selectedYear == _keep ? this.selectedYear : selectedYear as int?,
    );
  }

  /// Kategori terpilih (atau default) beserta angka target/realisasinya.
  /// Derivasi murni — menggantikan getter `_selectedCat` di layar.
  DashboardCategoryStat? get selectedCat {
    final c = categories;
    if (c == null) return null;
    return c.byName(selectedCategory ?? c.defaultCategory);
  }

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
      final summary = await _repo.getSummary(year: year);
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
        drilldown = await _repo.getDrilldown(year: year);
      } catch (_) {}
      // Filter 11 target: best-effort (kartu utama tetap render kalau gagal).
      DashboardCategories? categories;
      try {
        categories = await _repo.getCategories(year: year);
      } catch (_) {}
      state = state.copyWith(
        summary: summary,
        schedules: schedules,
        announcements: announcements,
        drilldown: drilldown,
        categories: categories,
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

  /// Ganti kategori terpilih (dropdown 11 target). Tidak memicu load — hanya
  /// mengubah angka turunan ([DashboardState.selectedCat]). Dulu `setState`.
  void onCategoryChanged(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Ganti tahun periode (C2). Beda dgn kategori: angka datang dari server, jadi
  /// WAJIB fetch ulang. null = kembali ke tahun berjalan.
  void onYearChanged(int? year) {
    if (year == state.selectedYear) return;
    state = state.copyWith(selectedYear: year);
    fetch();
  }
}
