import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';

/// Ukuran halaman awal daftar kinerja RM (server-paged, infinite scroll). Kecil
/// agar daftar terpaint hampir seketika; sisanya mengalir saat scroll. Dulu
/// `_pageSize` privat di `rm_performance_screen`.
const int kRmPerformancePageSize = 8;

const Object _keep = Object();

/// State daftar kinerja RM ("Lihat Semua RM") — cerminan 1:1 dari field
/// `setState` di layar lama. Paging, filter (wilayah/cabang/cari/connect), dan
/// agregat header (totals per filter aktif) semuanya dipindah apa adanya.
class RmPerformanceState {
  final List<ScopeOffice> offices;
  final String? regionId;
  final String? branchId;
  final String searchTerm;
  final bool connectOnly;

  /// Saringan pipeline dari rincian kartu KPI (CR-06): `NONE` | `ACTIVE` |
  /// `P3` | `P2` | `P1` | `WON` | `DECLINE`; null = tanpa saringan. Nilainya
  /// dikirim apa adanya ke server, yang menolak nilai di luar daftar itu — jadi
  /// hanya kartu yang boleh mengisinya, bukan masukan bebas.
  final String? pipelineFilter;

  final List<RmStat> items;
  final int nextPage;
  final bool last;
  final int total;

  /// Header totals untuk filter aktif (region/branch/search), dikembalikan server
  /// tiap halaman agar kartu ringkasan persis mengikuti apa yang terdaftar.
  final int filteredActivePipelines;
  final double filteredRealisasi;
  final int rmsWithoutPipeline;
  // Rincian tahap pipeline lintas seluruh RM yang cocok.
  final int p3;
  final int p2;
  final int p1;
  final int won;
  final int decline;

  final bool initialLoading;
  final bool loadingMore;
  final String? error;

  const RmPerformanceState({
    this.offices = const [],
    this.regionId,
    this.branchId,
    this.searchTerm = '',
    this.connectOnly = false,
    this.pipelineFilter,
    this.items = const [],
    this.nextPage = 0,
    this.last = false,
    this.total = 0,
    this.filteredActivePipelines = 0,
    this.filteredRealisasi = 0,
    this.rmsWithoutPipeline = 0,
    this.p3 = 0,
    this.p2 = 0,
    this.p1 = 0,
    this.won = 0,
    this.decline = 0,
    this.initialLoading = true,
    this.loadingMore = false,
    this.error,
  });

  RmPerformanceState copyWith({
    List<ScopeOffice>? offices,
    Object? regionId = _keep,
    Object? branchId = _keep,
    String? searchTerm,
    bool? connectOnly,
    Object? pipelineFilter = _keep,
    List<RmStat>? items,
    int? nextPage,
    bool? last,
    int? total,
    int? filteredActivePipelines,
    double? filteredRealisasi,
    int? rmsWithoutPipeline,
    int? p3,
    int? p2,
    int? p1,
    int? won,
    int? decline,
    bool? initialLoading,
    bool? loadingMore,
    Object? error = _keep,
  }) {
    return RmPerformanceState(
      offices: offices ?? this.offices,
      regionId: regionId == _keep ? this.regionId : regionId as String?,
      branchId: branchId == _keep ? this.branchId : branchId as String?,
      searchTerm: searchTerm ?? this.searchTerm,
      connectOnly: connectOnly ?? this.connectOnly,
      pipelineFilter: pipelineFilter == _keep
          ? this.pipelineFilter
          : pipelineFilter as String?,
      items: items ?? this.items,
      nextPage: nextPage ?? this.nextPage,
      last: last ?? this.last,
      total: total ?? this.total,
      filteredActivePipelines:
          filteredActivePipelines ?? this.filteredActivePipelines,
      filteredRealisasi: filteredRealisasi ?? this.filteredRealisasi,
      rmsWithoutPipeline: rmsWithoutPipeline ?? this.rmsWithoutPipeline,
      p3: p3 ?? this.p3,
      p2: p2 ?? this.p2,
      p1: p1 ?? this.p1,
      won: won ?? this.won,
      decline: decline ?? this.decline,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error == _keep ? this.error : error as String?,
    );
  }

  /// Region/branch pilihan (supervisor). Derivasi murni dari [offices] —
  /// menggantikan getter `_regions`/`_branches` di layar.
  List<ScopeOffice> get regions =>
      offices.where((o) => o.type == 'REGIONAL').toList();

  List<ScopeOffice> get branches => offices
      .where((o) =>
          o.type == 'BRANCH' && (regionId == null || o.parentId == regionId))
      .toList();
}

final rmPerformanceProvider =
    NotifierProvider<RmPerformanceNotifier, RmPerformanceState>(
        RmPerformanceNotifier.new);

/// Menggantikan seluruh logika `setState` di `_RmPerformanceScreenState`.
/// Perilaku (paging infinite-scroll, reset+load saat filter berubah, agregat
/// header) DIPINDAH APA ADANYA. Scroll/kolom-cari/debounce tetap di layar.
class RmPerformanceNotifier extends Notifier<RmPerformanceState> {
  @override
  RmPerformanceState build() => const RmPerformanceState();

  /// Repository dashboard (via [apiClientProvider], sesi selalu terbaru). Juga
  /// dipakai layar untuk `getRmMonthly` di dialog detail. Dulu `_repo` dibuat
  /// dari `DashboardRepository(apiClient: ApiClient(session: ...))`.
  DashboardRepository get repo => ref.read(dashboardRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Pra-terapkan filter
  /// yang dibawa saat buka (dari kartu office/RM dashboard) lalu bootstrap.
  /// Menggantikan bagian state di `initState` + `_bootstrap`.
  void start({
    String? initialRegionId,
    String? initialBranchId,
    String? initialSearch,
  }) {
    state = state.copyWith(
      regionId: initialRegionId,
      branchId: initialBranchId,
      searchTerm: initialSearch ?? '',
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final offices = await repo.getScopeOffices();
      state = state.copyWith(offices: offices);
    } catch (_) {
      // Filters are optional; a failure here shouldn't block the list.
    }
    await resetAndLoad();
  }

  Future<void> resetAndLoad() async {
    state = state.copyWith(
      items: const [],
      nextPage: 0,
      last: false,
      initialLoading: true,
      error: null,
    );
    await _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      final res = await repo.getRmPerformance(
        page: state.nextPage,
        size: kRmPerformancePageSize,
        search: state.searchTerm,
        regionId: state.regionId,
        branchId: state.branchId,
        connectOnly: state.connectOnly,
        pipelineFilter: state.pipelineFilter,
      );
      state = state.copyWith(
        items: [...state.items, ...res.content],
        nextPage: res.page + 1,
        last: res.last,
        total: res.totalElements,
        filteredActivePipelines: res.totalActivePipelines,
        filteredRealisasi: res.totalRealisasi,
        rmsWithoutPipeline: res.rmsWithoutPipeline,
        p3: res.p3,
        p2: res.p2,
        p1: res.p1,
        won: res.won,
        decline: res.decline,
        initialLoading: false,
        loadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        initialLoading: false,
        loadingMore: false,
      );
    }
  }

  /// Dipicu saat layar mendeteksi scroll mendekati bawah. Guard posisi/scroll
  /// tetap di layar (butuh ScrollController); di sini hanya set flag + muat.
  /// Dulu `setState(() => _loadingMore = true); _loadPage();` di `_onScroll`.
  void loadMore() {
    state = state.copyWith(loadingMore: true);
    _loadPage();
  }

  void onSearchChanged(String value) {
    if (value.trim() == state.searchTerm) return;
    state = state.copyWith(searchTerm: value.trim());
    resetAndLoad();
  }

  void onRegionChanged(String? regionId) {
    state = state.copyWith(
      regionId: regionId,
      branchId: null, // branches depend on the chosen region
    );
    resetAndLoad();
  }

  void onBranchChanged(String? branchId) {
    state = state.copyWith(branchId: branchId);
    resetAndLoad();
  }

  void onConnectOnlyChanged(bool value) {
    state = state.copyWith(connectOnly: value);
    resetAndLoad();
  }

  /// Rincian kartu KPI (CR-06): kartu memasang saringan pipeline pada roster.
  ///
  /// Menekan kartu yang saringannya sedang aktif MEMATIKANNYA — perilaku yang
  /// sama dengan chip tahap di layar Customer, jadi jalan keluarnya selalu ada
  /// tanpa harus mencari tombol lain. Kartu "Total RM" memanggilnya dengan null,
  /// yang berarti melepas saringan apa pun.
  void onPipelineFilterChanged(String? filter) {
    final next = state.pipelineFilter == filter ? null : filter;
    if (next == state.pipelineFilter) return;
    state = state.copyWith(pipelineFilter: next);
    resetAndLoad();
  }
}
