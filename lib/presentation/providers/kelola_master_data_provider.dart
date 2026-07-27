import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/agent/agent_repository.dart';
import 'package:mbis/src/master_data/master_data_repository.dart';

/// Provider daftar untuk tab-tab "Kelola Master Data" yang berupa PEMUAT DAFTAR
/// bersih (load → loading/error/items, aksi tulis hanya memicu muat-ulang lewat
/// `_fetch`). Menggantikan field `setState` DATA/LOADING pada tiap tab.
///
/// PERILAKU DIPERTAHANKAN (behavior-preserving):
///  - Semua provider di sini `autoDispose`. Tab di dalam `TabBarView` di-recreate
///    tiap kali dikunjungi ulang (state per-instance), jadi state daftar harus
///    ikut mulai dari awal (`loading:true`, `items:[]`) tiap tab dibuka — persis
///    perilaku `initState → _fetch` lama. `autoDispose` menyetel state balik ke
///    awal saat tab (widget) di-dispose.
///  - Filter pencarian (`_search`), controller, dialog, snackbar, dan seluruh
///    AKSI TULIS (hapus/simpan/form) TETAP di widget — hanya daftar/loading/error
///    yang pindah ke sini.
///  - Sumber data TAK berubah: `MasterDataRepository` didapat dari
///    [masterDataRepoProvider] (membawa sesi aktif via apiClient), padanan
///    fungsional `widget.repo` yang dibuat parent dari sesi yang sama. Pemetaan
///    error (`replaceFirst('Exception: ', '')`) dan guard `mounted` dipindah apa
///    adanya (`ref.mounted`).
///
/// Tab yang SENGAJA TIDAK dimigrasi (tetap `setState`): Produk & Kategori
/// (mutasi daftar OPTIMISTIC pada aksi tulis), Template (repo berbeda +
/// pemicu `didChangeDependencies`).

const Object _keep = Object();

// ── Parameter (Dropdown & Rate) ─────────────────────────────────────────────

class MasterParameterState {
  final bool loading;
  final String? error;
  final List<ParameterItem> items;

  const MasterParameterState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterParameterState copyWith({
    bool? loading,
    Object? error = _keep,
    List<ParameterItem>? items,
  }) {
    return MasterParameterState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterParameterProvider =
    NotifierProvider.autoDispose<MasterParameterNotifier, MasterParameterState>(
        MasterParameterNotifier.new);

class MasterParameterNotifier extends Notifier<MasterParameterState> {
  @override
  MasterParameterState build() => const MasterParameterState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getParameters(activeOnly: false);
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── Komisi (per-product rate) ───────────────────────────────────────────────

class MasterKomisiState {
  final bool loading;
  final String? error;
  final List<MasterProductRate> items;

  const MasterKomisiState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterKomisiState copyWith({
    bool? loading,
    Object? error = _keep,
    List<MasterProductRate>? items,
  }) {
    return MasterKomisiState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterKomisiProvider =
    NotifierProvider.autoDispose<MasterKomisiNotifier, MasterKomisiState>(
        MasterKomisiNotifier.new);

class MasterKomisiNotifier extends Notifier<MasterKomisiState> {
  @override
  MasterKomisiState build() => const MasterKomisiState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getMasterProductRates();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── Broker ──────────────────────────────────────────────────────────────────

class MasterBrokerState {
  final bool loading;
  final String? error;
  final List<BrokerItem> items;

  const MasterBrokerState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterBrokerState copyWith({
    bool? loading,
    Object? error = _keep,
    List<BrokerItem>? items,
  }) {
    return MasterBrokerState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterBrokerProvider =
    NotifierProvider.autoDispose<MasterBrokerNotifier, MasterBrokerState>(
        MasterBrokerNotifier.new);

class MasterBrokerNotifier extends Notifier<MasterBrokerState> {
  @override
  MasterBrokerState build() => const MasterBrokerState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getBrokers();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── Bank (induk) ────────────────────────────────────────────────────────────

class MasterBankState {
  final bool loading;
  final String? error;
  final List<BankItem> items;

  const MasterBankState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterBankState copyWith({
    bool? loading,
    Object? error = _keep,
    List<BankItem>? items,
  }) {
    return MasterBankState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterBankProvider =
    NotifierProvider.autoDispose<MasterBankNotifier, MasterBankState>(
        MasterBankNotifier.new);

class MasterBankNotifier extends Notifier<MasterBankState> {
  @override
  MasterBankState build() => const MasterBankState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getBanks();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── BUMN ────────────────────────────────────────────────────────────────────

class MasterBumnState {
  final bool loading;
  final String? error;
  final List<BumnMasterItem> items;

  const MasterBumnState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterBumnState copyWith({
    bool? loading,
    Object? error = _keep,
    List<BumnMasterItem>? items,
  }) {
    return MasterBumnState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterBumnProvider =
    NotifierProvider.autoDispose<MasterBumnNotifier, MasterBumnState>(
        MasterBumnNotifier.new);

class MasterBumnNotifier extends Notifier<MasterBumnState> {
  @override
  MasterBumnState build() => const MasterBumnState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getBumns();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── Kantor (offices) ────────────────────────────────────────────────────────

class MasterOfficeState {
  final bool loading;
  final String? error;
  final List<OfficeAdminItem> items;

  const MasterOfficeState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterOfficeState copyWith({
    bool? loading,
    Object? error = _keep,
    List<OfficeAdminItem>? items,
  }) {
    return MasterOfficeState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterOfficeProvider =
    NotifierProvider.autoDispose<MasterOfficeNotifier, MasterOfficeState>(
        MasterOfficeNotifier.new);

class MasterOfficeNotifier extends Notifier<MasterOfficeState> {
  @override
  MasterOfficeState build() => const MasterOfficeState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getOfficesAdmin();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── Cabang bank (sub-layar dari tab Bank) ───────────────────────────────────
//
// Daftarnya per-bank, jadi notifier menyimpan bankId yang sedang dibuka dan
// `start()` memuat ulang saat bank yang dibuka berbeda dari sebelumnya.

class MasterBankBranchState {
  final bool loading;
  final String? error;
  final String? bankId;
  final List<BankBranchItem> items;

  const MasterBankBranchState({
    this.loading = true,
    this.error,
    this.bankId,
    this.items = const [],
  });

  MasterBankBranchState copyWith({
    bool? loading,
    Object? error = _keep,
    Object? bankId = _keep,
    List<BankBranchItem>? items,
  }) {
    return MasterBankBranchState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      bankId: bankId == _keep ? this.bankId : bankId as String?,
      items: items ?? this.items,
    );
  }
}

final masterBankBranchProvider = NotifierProvider.autoDispose<
    MasterBankBranchNotifier, MasterBankBranchState>(MasterBankBranchNotifier.new);

class MasterBankBranchNotifier extends Notifier<MasterBankBranchState> {
  @override
  MasterBankBranchState build() => const MasterBankBranchState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> start(String bankId) async {
    state = state.copyWith(bankId: bankId, items: const [], loading: true, error: null);
    await fetch();
  }

  Future<void> fetch() async {
    final bankId = state.bankId;
    if (bankId == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getBankBranches(bankId);
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── Produk ──────────────────────────────────────────────────────────────────
//
// Tab Produk memuat DUA daftar sekaligus (produk + kategorinya, untuk label &
// filter) dan memakai pembaruan OPTIMISTIK: daftar diubah lebih dulu, lalu
// dikembalikan bila server menolak. Karena itu notifier ini mengekspos
// `setItems` — widget tetap memegang keputusan optimistik/rollback, sementara
// muat/loading/error pindah ke sini.

class MasterProductState {
  final bool loading;
  final String? error;
  final List<ProductItem> items;
  final List<ProductCategoryItem> categories;

  const MasterProductState({
    this.loading = true,
    this.error,
    this.items = const [],
    this.categories = const [],
  });

  MasterProductState copyWith({
    bool? loading,
    Object? error = _keep,
    List<ProductItem>? items,
    List<ProductCategoryItem>? categories,
  }) {
    return MasterProductState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
      categories: categories ?? this.categories,
    );
  }
}

final masterProductProvider =
    NotifierProvider.autoDispose<MasterProductNotifier, MasterProductState>(
        MasterProductNotifier.new);

class MasterProductNotifier extends Notifier<MasterProductState> {
  @override
  MasterProductState build() => const MasterProductState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getProducts(activeOnly: false),
        _repo.getProductCategories(),
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        items: results[0] as List<ProductItem>,
        categories: results[1] as List<ProductCategoryItem>,
        loading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  /// Tulis daftar apa adanya — dipakai widget untuk perubahan optimistik
  /// (aktif/nonaktif, hapus, simpan) sekaligus rollback saat server menolak.
  void setItems(List<ProductItem> items) => state = state.copyWith(items: items);
}

// ── Kategori produk ─────────────────────────────────────────────────────────

class MasterCategoryState {
  final bool loading;
  final String? error;
  final List<ProductCategoryItem> items;

  const MasterCategoryState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterCategoryState copyWith({
    bool? loading,
    Object? error = _keep,
    List<ProductCategoryItem>? items,
  }) {
    return MasterCategoryState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterCategoryProvider =
    NotifierProvider.autoDispose<MasterCategoryNotifier, MasterCategoryState>(
        MasterCategoryNotifier.new);

class MasterCategoryNotifier extends Notifier<MasterCategoryState> {
  @override
  MasterCategoryState build() => const MasterCategoryState();

  MasterDataRepository get _repo => ref.read(masterDataRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getProductCategories();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  /// Lihat catatan pada [MasterProductNotifier.setItems] — kategori juga
  /// memakai pembaruan optimistik saat menghapus.
  void setItems(List<ProductCategoryItem> items) =>
      state = state.copyWith(items: items);
}

// ── Template dokumen agen ───────────────────────────────────────────────────
//
// Satu-satunya daftar di layar ini yang datanya dari AgentRepository, bukan
// MasterDataRepository.

class MasterTemplateState {
  final bool loading;
  final String? error;
  final List<AgentTemplateItem> items;

  const MasterTemplateState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  MasterTemplateState copyWith({
    bool? loading,
    Object? error = _keep,
    List<AgentTemplateItem>? items,
  }) {
    return MasterTemplateState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final masterTemplateProvider =
    NotifierProvider.autoDispose<MasterTemplateNotifier, MasterTemplateState>(
        MasterTemplateNotifier.new);

class MasterTemplateNotifier extends Notifier<MasterTemplateState> {
  @override
  MasterTemplateState build() => const MasterTemplateState();

  AgentRepository get _repo => ref.read(agentRepoProvider);

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.getAgentTemplates();
      if (!ref.mounted) return;
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}

// ── Jumlah data per bagian (untuk hub "Kelola Master Data") ──────────────────
//
// Hub menampilkan angka di tiap kartu supaya admin tahu isi sebuah bagian tanpa
// membukanya. Angka diambil sekali lalu DI-CACHE (provider ini sengaja BUKAN
// autoDispose): keluar-masuk hub tidak menembak 9 endpoint berulang kali.
// `load(force: true)` dipakai saat pull-to-refresh.

class MasterDataCountsState {
  final Map<String, int> counts;
  final bool loading;

  const MasterDataCountsState({this.counts = const {}, this.loading = false});
}

final masterDataCountsProvider =
    NotifierProvider<MasterDataCountsNotifier, MasterDataCountsState>(
        MasterDataCountsNotifier.new);

class MasterDataCountsNotifier extends Notifier<MasterDataCountsState> {
  @override
  MasterDataCountsState build() => const MasterDataCountsState();

  Future<void> load({bool force = false}) async {
    if (state.loading) return;
    if (!force && state.counts.isNotEmpty) return;
    state = MasterDataCountsState(counts: state.counts, loading: true);

    final repo = ref.read(masterDataRepoProvider);
    final agentRepo = ref.read(agentRepoProvider);
    final jobs = <String, Future<int>>{
      'parameter': repo.getParameters(activeOnly: false).then((v) => v.length),
      'produk': repo.getProducts(activeOnly: false).then((v) => v.length),
      'kategori': repo.getProductCategories().then((v) => v.length),
      'komisi': repo.getMasterProductRates().then((v) => v.length),
      'broker': repo.getBrokers().then((v) => v.length),
      'bank': repo.getBanks().then((v) => v.length),
      'bumn': repo.getBumns().then((v) => v.length),
      'kantor': repo.getOfficesAdmin().then((v) => v.length),
      'template': agentRepo.getAgentTemplates().then((v) => v.length),
    };

    final result = <String, int>{};
    // Satu bagian gagal (mis. hak akses) tidak boleh menggagalkan seluruh hub:
    // kartunya hanya tampil tanpa angka.
    await Future.wait(jobs.entries.map((e) async {
      try {
        result[e.key] = await e.value;
      } catch (_) {
        // sengaja diabaikan
      }
    }));
    if (!ref.mounted) return;
    state = MasterDataCountsState(counts: result, loading: false);
  }
}
