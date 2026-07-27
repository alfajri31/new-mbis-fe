import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/assistant/assistant_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/src/visit/visit_repository.dart';

const Object _keep = Object();

/// State detail customer — cerminan 1:1 dari field `setState` DATA/LOADING di
/// layar lama. `_activeTab` TIDAK ikut: itu murni navigasi tab (UI-ephemeral) &
/// tetap dikelola widget dengan `setState`, sejalan aturan migrasi (hanya
/// state DATA/LOADING yang dipindah).
class CustomerDetailState {
  final bool isLoading;
  final String? error;
  final CustomerDetailModel? customer;
  final List<PipelineListModel> pipelines;
  final List<SavedAiResult> aiResults;
  final List<VisitModel> visits;
  final bool visitsAllTime; // false = tahun berjalan (default)
  final bool visitsLoading;

  const CustomerDetailState({
    this.isLoading = true,
    this.error,
    this.customer,
    this.pipelines = const [],
    this.aiResults = const [],
    this.visits = const [],
    this.visitsAllTime = false,
    this.visitsLoading = false,
  });

  CustomerDetailState copyWith({
    bool? isLoading,
    Object? error = _keep,
    Object? customer = _keep,
    List<PipelineListModel>? pipelines,
    List<SavedAiResult>? aiResults,
    List<VisitModel>? visits,
    bool? visitsAllTime,
    bool? visitsLoading,
  }) {
    return CustomerDetailState(
      isLoading: isLoading ?? this.isLoading,
      error: error == _keep ? this.error : error as String?,
      customer: customer == _keep
          ? this.customer
          : customer as CustomerDetailModel?,
      pipelines: pipelines ?? this.pipelines,
      aiResults: aiResults ?? this.aiResults,
      visits: visits ?? this.visits,
      visitsAllTime: visitsAllTime ?? this.visitsAllTime,
      visitsLoading: visitsLoading ?? this.visitsLoading,
    );
  }
}

final customerDetailProvider =
    NotifierProvider<CustomerDetailNotifier, CustomerDetailState>(
      CustomerDetailNotifier.new,
    );

/// Menggantikan logika `setState` DATA/LOADING di `_CustomerDetailScreenState`.
/// Perilaku (urutan fetch, guard best-effort AI/visit, error handling, reload
/// riwayat kunjungan) DIPINDAH APA ADANYA. Repository legacy dipakai ulang lewat
/// shared provider (bukan konstruksi `ApiClient` sendiri).
class CustomerDetailNotifier extends Notifier<CustomerDetailState> {
  /// Id customer yang dimuat; diisi sekali dari [start] (dulu `widget.customerId`).
  late String _customerId;

  @override
  CustomerDetailState build() => const CustomerDetailState();

  CustomerRepository get _customerRepo => ref.read(customerRepoProvider);
  PipelineRepository get _pipelineRepo => ref.read(pipelineRepoProvider);
  AssistantRepository get _assistantRepo => ref.read(assistantRepoProvider);
  VisitRepository get _visitRepo => ref.read(visitRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan bagian
  /// data dari `initState` lama (konstruksi repo kini via provider).
  void start(String customerId) {
    _customerId = customerId;
    fetchData();
  }

  Future<void> fetchData({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final customer = await _customerRepo.getCustomerDetail(_customerId);
      // Difilter di server: pipeline milik customer ini plus pipeline kerja sama
      // di mana customer ini jadi mitra (muncul & bisa dibuka, tapi tidak ikut
      // dihitung — lihat wonCount).
      final customerPipelines = await _pipelineRepo.getPipelines(
        customerId: _customerId,
      );

      // Saved AI results (optional — never blocks the screen if it fails/absent).
      List<SavedAiResult> aiResults = const [];
      try {
        aiResults = await _assistantRepo.getSavedResults(_customerId);
      } catch (_) {
        aiResults = const [];
      }

      // Riwayat kunjungan lintas pipeline — best-effort, sama seperti AI results:
      // gagal memuatnya tidak boleh mengosongkan seluruh detail customer.
      List<VisitModel> visits = const [];
      try {
        visits = await _visitRepo.getCustomerVisits(
          _customerId,
          ytd: !state.visitsAllTime,
        );
      } catch (_) {
        visits = const [];
      }

      state = state.copyWith(
        customer: customer,
        pipelines: customerPipelines,
        aiResults: aiResults,
        visits: visits,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Reloads just the visit list when the period toggle flips, so switching to
  /// the full history doesn't re-fetch the whole customer.
  Future<void> reloadVisits({required bool allTime}) async {
    state = state.copyWith(visitsAllTime: allTime, visitsLoading: true);
    try {
      final visits = await _visitRepo.getCustomerVisits(
        _customerId,
        ytd: !allTime,
      );
      state = state.copyWith(visits: visits, visitsLoading: false);
    } catch (_) {
      state = state.copyWith(visitsLoading: false);
    }
  }
}
