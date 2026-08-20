import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/broker/broker_repository.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/src/reference/reference_repository.dart';
import 'package:mbis/src/visit/visit_repository.dart';

const Object _keep = Object();

/// State detail pipeline — cerminan 1:1 dari field `setState` DATA/LOADING di
/// layar lama. Field UI/sesi murni (`_stages`, `_currentUserId`, `_apiClient`)
/// TIDAK ikut: tetap dikelola widget, sejalan aturan migrasi (hanya state
/// DATA/LOADING yang dipindah). `brokers`/`cascade`/`kerjaSamaOptions` adalah
/// referensi yang dimuat untuk edit-sheet layar — ikut pindah.
class PipelineDetailState {
  final bool isLoading;
  final String? error;
  final PipelineDetailModel? pipeline;
  final List<VisitModel> visits;
  final List<PipelineHistoryModel> history; // Log Activity timeline
  final List<PipelineDocumentModel> docs; // SPAU / Underlying
  final List<BrokerModel> brokers; // for the edit sheet's broker dropdown (P4)
  final ProductCascade cascade; // edit sheet COB/LOB/ToC
  final List<ParamRef> kerjaSamaOptions;

  PipelineDetailState({
    this.isLoading = true,
    this.error,
    this.pipeline,
    this.visits = const [],
    this.history = const [],
    this.docs = const [],
    this.brokers = const [],
    ProductCascade? cascade,
    this.kerjaSamaOptions = const [],
  }) : cascade = cascade ?? ProductCascade(const []);

  PipelineDetailState copyWith({
    bool? isLoading,
    Object? error = _keep,
    Object? pipeline = _keep,
    List<VisitModel>? visits,
    List<PipelineHistoryModel>? history,
    List<PipelineDocumentModel>? docs,
    List<BrokerModel>? brokers,
    ProductCascade? cascade,
    List<ParamRef>? kerjaSamaOptions,
  }) {
    return PipelineDetailState(
      isLoading: isLoading ?? this.isLoading,
      error: error == _keep ? this.error : error as String?,
      pipeline: pipeline == _keep
          ? this.pipeline
          : pipeline as PipelineDetailModel?,
      visits: visits ?? this.visits,
      history: history ?? this.history,
      docs: docs ?? this.docs,
      brokers: brokers ?? this.brokers,
      cascade: cascade ?? this.cascade,
      kerjaSamaOptions: kerjaSamaOptions ?? this.kerjaSamaOptions,
    );
  }
}

final pipelineDetailProvider =
    NotifierProvider<PipelineDetailNotifier, PipelineDetailState>(
      PipelineDetailNotifier.new,
    );

/// Menggantikan logika `setState` DATA/LOADING di `_PipelineDetailScreenState`.
/// Perilaku (urutan fetch, guard best-effort visits/history/docs, muat broker &
/// referensi edit-sheet, error handling) DIPINDAH APA ADANYA. Repository legacy
/// dipakai ulang lewat shared provider (bukan konstruksi `ApiClient` sendiri).
class PipelineDetailNotifier extends Notifier<PipelineDetailState> {
  /// Id pipeline yang dimuat; diisi sekali dari [start] (dulu `widget.pipelineId`).
  late String _pipelineId;

  @override
  PipelineDetailState build() => PipelineDetailState();

  PipelineRepository get _pipelineRepo => ref.read(pipelineRepoProvider);
  VisitRepository get _visitRepo => ref.read(visitRepoProvider);
  BrokerRepository get _brokerRepo => ref.read(brokerRepoProvider);
  ReferenceRepository get _referenceRepo => ref.read(referenceRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan bagian
  /// data dari `initState` lama (konstruksi repo kini via provider). Yang tetap
  /// di widget: `_currentUserId` (sesi) & `loadTenderLabels` (deferred).
  void start(String pipelineId) {
    _pipelineId = pipelineId;
    fetchData();
    _loadBrokers();
    _loadEditRefs();
  }

  /// Master broker list, used by the edit sheet when sumber bisnis = Broker.
  Future<void> _loadBrokers() async {
    try {
      final brokers = await _brokerRepo.getBrokerOptions();
      state = state.copyWith(brokers: brokers);
    } catch (_) {
      // Non-fatal: edit sheet falls back to a free-text-less dropdown.
    }
  }

  /// Products (COB/LOB/ToC) + status kerja sama options for the edit sheet.
  Future<void> _loadEditRefs() async {
    try {
      final products = await _referenceRepo.products();
      final ks = await _referenceRepo.parameters('KERJA_SAMA');
      state = state.copyWith(
        cascade: ProductCascade(products),
        kerjaSamaOptions: ks,
      );
    } catch (_) {
      /* edit sheet keeps the plain product text field */
    }
  }

  Future<void> fetchData({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final pipeline = await _pipelineRepo.getPipelineDetail(_pipelineId);
      // Visits + history are best-effort: a failure shouldn't block the view.
      List<VisitModel> visits = [];
      try {
        visits = await _visitRepo.getVisits(_pipelineId);
      } catch (_) {}
      List<PipelineHistoryModel> history = [];
      try {
        history = await _pipelineRepo.getPipelineHistory(_pipelineId);
      } catch (_) {}
      List<PipelineDocumentModel> docs = [];
      try {
        docs = await _pipelineRepo.getDocuments(_pipelineId);
      } catch (_) {}
      state = state.copyWith(
        pipeline: pipeline,
        visits: visits,
        history: history,
        docs: docs,
        isLoading: false,
      );
    } catch (e) {
      // Sama seperti CustomerDetailProvider: layar menampilkan pesan ini apa
      // adanya, jadi awalan teknisnya dibuang.
      state = state.copyWith(
          error: e.toString().replaceFirst('Exception: ', ''), isLoading: false);
    }
  }
}
