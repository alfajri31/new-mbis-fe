import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../src/common/file_opener.dart';
import '../../../src/visit/visit_monitor_repository.dart';
import '../models/visit_monitor_models.dart';

/// State for Visit Monitor Screen.
/// Contains loading states, error handling (negative cases), and data models.
class VisitMonitorState {
  final bool isLoadingSummary;
  final bool isLoadingVisits;
  final bool isPaging;
  final bool isLoadingRms;
  final bool isPagingRms;
  final bool isExporting;
  final String? summaryError;
  final String? visitsError;
  final String? rmsError;
  final String? exportError;

  final VisitMonitorSummary summary;
  final VisitMonitorPage<VisitMonitorRow> visitsPage;
  final VisitMonitorPage<VisitMonitorRmRow> rmsPage;
  final VisitMonitorFilter filter;

  const VisitMonitorState({
    this.isLoadingSummary = false,
    this.isLoadingVisits = false,
    this.isPaging = false,
    this.isLoadingRms = false,
    this.isPagingRms = false,
    this.isExporting = false,
    this.summaryError,
    this.visitsError,
    this.rmsError,
    this.exportError,
    this.summary = const VisitMonitorSummary(),
    this.visitsPage = const VisitMonitorPage(),
    this.rmsPage = const VisitMonitorPage(),
    this.filter = const VisitMonitorFilter(),
  });

  /// True if initial content is loading
  bool get isInitialLoading => isLoadingVisits && visitsPage.content.isEmpty;

  /// True if there is an error preventing list rendering
  bool get hasVisitsError => visitsError != null && visitsPage.content.isEmpty;

  /// True if list is loaded and empty
  bool get isVisitsEmpty => !isLoadingVisits && visitsError == null && visitsPage.content.isEmpty;

  /// RM list getters
  bool get isInitialLoadingRms => isLoadingRms && rmsPage.content.isEmpty;
  bool get hasRmsError => rmsError != null && rmsPage.content.isEmpty;
  bool get isRmsEmpty => !isLoadingRms && rmsError == null && rmsPage.content.isEmpty;

  VisitMonitorState copyWith({
    bool? isLoadingSummary,
    bool? isLoadingVisits,
    bool? isPaging,
    bool? isLoadingRms,
    bool? isPagingRms,
    bool? isExporting,
    String? summaryError,
    bool clearSummaryError = false,
    String? visitsError,
    bool clearVisitsError = false,
    String? rmsError,
    bool clearRmsError = false,
    String? exportError,
    bool clearExportError = false,
    VisitMonitorSummary? summary,
    VisitMonitorPage<VisitMonitorRow>? visitsPage,
    VisitMonitorPage<VisitMonitorRmRow>? rmsPage,
    VisitMonitorFilter? filter,
  }) {
    return VisitMonitorState(
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
      isLoadingVisits: isLoadingVisits ?? this.isLoadingVisits,
      isPaging: isPaging ?? this.isPaging,
      isLoadingRms: isLoadingRms ?? this.isLoadingRms,
      isPagingRms: isPagingRms ?? this.isPagingRms,
      isExporting: isExporting ?? this.isExporting,
      summaryError: clearSummaryError ? null : (summaryError ?? this.summaryError),
      visitsError: clearVisitsError ? null : (visitsError ?? this.visitsError),
      rmsError: clearRmsError ? null : (rmsError ?? this.rmsError),
      exportError: clearExportError ? null : (exportError ?? this.exportError),
      summary: summary ?? this.summary,
      visitsPage: visitsPage ?? this.visitsPage,
      rmsPage: rmsPage ?? this.rmsPage,
      filter: filter ?? this.filter,
    );
  }
}



class VisitMonitorNotifier extends Notifier<VisitMonitorState> {
  int _visitsSeq = 0;
  int _rmsSeq = 0;

  @override
  VisitMonitorState build() {
    return const VisitMonitorState();
  }

  VisitMonitorRepository get _repo => ref.read(visitMonitorRepoProvider);

  /// Inisialisasi awal atau muat ulang seluruh data (Summary + Daftar Kunjungan + Daftar RM).
  Future<void> loadAll({VisitMonitorFilter? initialFilter}) async {
    if (initialFilter != null) {
      state = state.copyWith(filter: initialFilter);
    }
    await Future.wait([
      loadSummary(),
      loadVisits(page: 0),
      loadRms(page: 0),
    ]);
  }

  /// Memuat ringkasan metrik dari GET /api/visit-monitor/summary
  Future<void> loadSummary() async {
    state = state.copyWith(isLoadingSummary: true, clearSummaryError: true);
    try {
      final summary = await _repo.getSummary(state.filter);
      state = state.copyWith(
        isLoadingSummary: false,
        summary: summary,
        clearSummaryError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingSummary: false,
        summaryError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Memuat daftar kunjungan terpaginasi dari GET /api/visit-monitor/visits
  Future<void> loadVisits({int page = 0, bool isPaging = false}) async {
    final seq = ++_visitsSeq;
    state = state.copyWith(
      isLoadingVisits: !isPaging,
      isPaging: isPaging,
      clearVisitsError: true,
    );

    try {
      final pageResult = await _repo.getVisits(
        page: page,
        size: state.visitsPage.size,
        filter: state.filter,
      );

      // Guard terhadap respons race condition
      if (seq != _visitsSeq) return;

      state = state.copyWith(
        isLoadingVisits: false,
        isPaging: false,
        visitsPage: pageResult,
        clearVisitsError: true,
      );
    } catch (e) {
      if (seq != _visitsSeq) return;
      state = state.copyWith(
        isLoadingVisits: false,
        isPaging: false,
        visitsError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Memuat daftar RM terpaginasi dari GET /api/visit-monitor/rms
  Future<void> loadRms({int page = 0, bool isPaging = false}) async {
    final seq = ++_rmsSeq;
    state = state.copyWith(
      isLoadingRms: !isPaging,
      isPagingRms: isPaging,
      clearRmsError: true,
    );

    try {
      final pageResult = await _repo.getRms(
        page: page,
        size: state.rmsPage.size,
        filter: state.filter,
      );

      // Guard terhadap respons race condition
      if (seq != _rmsSeq) return;

      state = state.copyWith(
        isLoadingRms: false,
        isPagingRms: false,
        rmsPage: pageResult,
        clearRmsError: true,
      );
    } catch (e) {
      if (seq != _rmsSeq) return;
      state = state.copyWith(
        isLoadingRms: false,
        isPagingRms: false,
        rmsError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Pindah ke halaman tertentu (Paginasi Kunjungan)
  void goToPage(int page) {
    if (page < 0 ||
        (state.visitsPage.totalPages > 0 && page >= state.visitsPage.totalPages) ||
        page == state.visitsPage.page ||
        state.isPaging) {
      return;
    }
    loadVisits(page: page, isPaging: true);
  }

  /// Pindah ke halaman tertentu (Paginasi RM)
  void goToRmsPage(int page) {
    if (page < 0 ||
        (state.rmsPage.totalPages > 0 && page >= state.rmsPage.totalPages) ||
        page == state.rmsPage.page ||
        state.isPagingRms) {
      return;
    }
    loadRms(page: page, isPaging: true);
  }


  /// Update kueri pencarian teks
  void onSearchChanged(String query) {
    final q = query.trim();
    if (q == (state.filter.q ?? '')) return;
    state = state.copyWith(filter: state.filter.copyWith(q: q));
    loadAll();
  }

  /// Update rentang tanggal (periode)
  void onPeriodChanged(String? from, String? to) {
    state = state.copyWith(filter: state.filter.copyWith(from: from, to: to));
    loadAll();
  }

  /// Update filter wilayah, cabang, dan RM
  void onOfficeFilterChanged({
    String? regionId,
    String? branchId,
    String? rmId,
    bool clearBranch = false,
    bool clearRm = false,
  }) {
    state = state.copyWith(
      filter: state.filter.copyWith(
        regionId: regionId,
        branchId: branchId,
        rmId: rmId,
        clearBranch: clearBranch,
        clearRm: clearRm,
      ),
    );
    loadAll();
  }

  /// Mengunduh data kunjungan (Excel .xlsx) dari GET /api/export/visits
  Future<VisitExportOutcome> exportVisits({
    required String from,
    required String to,
  }) async {
    state = state.copyWith(isExporting: true, clearExportError: true);
    try {
      final fileData = await _repo.exportVisits(
        from: from,
        to: to,
        regionId: state.filter.regionId,
        branchId: state.filter.branchId,
        rmId: state.filter.rmId,
      );
      final ok = await downloadBytes(
        fileData.bytes,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fileData.fileName,
      );
      state = state.copyWith(isExporting: false, clearExportError: true);
      return ok
          ? VisitExportOutcome.saved(fileData.fileName)
          : const VisitExportOutcome.unsupported();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isExporting: false, exportError: msg);
      return VisitExportOutcome.failed(msg);
    }
  }

  /// Reset semua filter ke default
  void resetFilter({VisitMonitorFilter? defaultFilter}) {
    state = state.copyWith(
      filter: defaultFilter ?? const VisitMonitorFilter(),
      clearSummaryError: true,
      clearVisitsError: true,
      clearRmsError: true,
      clearExportError: true,
    );
    loadAll();
  }
}



final visitMonitorProvider =
    NotifierProvider<VisitMonitorNotifier, VisitMonitorState>(
  VisitMonitorNotifier.new,
);

/// Provider untuk memuat data detail kunjungan dari GET /api/visit-monitor/visits/{id}
final visitDetailProvider =
    FutureProvider.autoDispose.family<VisitMonitorDetail, String>((ref, id) async {
  final repo = ref.watch(visitMonitorRepoProvider);
  return repo.getVisitDetail(id);
});

