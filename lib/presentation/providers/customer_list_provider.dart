import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/app.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';
import 'package:mbis/src/reference/reference_repository.dart';

/// Ukuran halaman daftar customer (server-paged). Dipakai notifier (request) &
/// layar (label paginasi). Dulu `_pageSize` privat di `customer_list_screen`.
const int kCustomerPageSize = 10;

const Object _keep = Object();

/// State daftar customer — cerminan 1:1 dari field `setState` di layar lama.
class CustomerListState {
  final List<CustomerListModel> items;
  final int page;
  final int totalPages;
  final int totalElements;
  final List<ParamRef> entityOptions;
  final List<ScopeOffice> offices;
  final String? regionId;
  final String? branchId;
  final String searchTerm;
  final String? entityFilter;
  final bool hvcFilter;

  /// Tahap pipeline terpilih (P3/P2/P1/WON/DECLINE); null = semua tahap.
  /// Disaring di SERVER, bukan di klien: daftarnya berhalaman, jadi menyaring
  /// satu halaman akan menampilkan "3 dari 20" padahal yang cocok ratusan.
  final String? stageFilter;
  final CustomerKpi? kpi;
  final bool initialLoading;
  final String? error;
  final bool canAddCustomer;

  // View atasan (supervisor): filter RM/COB + kartu Target/Realisasi/Visit. Hanya
  // untuk RO/BM/KUP/ADMIN/DPJ; RM/agen tetap daftar customer polos.
  final bool isSupervisor;
  final String? rmId; // RM terpilih (null = semua RM di scope)
  final String? rmName; // label tampil untuk RM terpilih
  final String? cob; // COB / kategori-target terpilih (null = semua)
  final List<DashboardCategoryStat> cobOptions; // opsi dropdown COB
  final CustomerScopedSummary? summary; // headline Target/Realisasi/Visit

  /// Panggilan `customer-summary` terakhir gagal (jaringan/404/5xx).
  ///
  /// Dibedakan dari `summary == null` yang belum sempat dimuat, supaya kartu bisa
  /// menyatakan "gagal memuat" alih-alih menggambar Rp 0 / 0% — nol yang sah dan
  /// nol karena gagal tidak boleh terlihat sama.
  final bool summaryFailed;

  /// [summary] berasal dari cadangan `/api/dashboard/summary`, bukan dari
  /// `customer-summary`.
  ///
  /// Angkanya benar untuk SELURUH scope pemakai, tetapi **tidak mengikuti filter**
  /// region/cabang/RM/COB — endpoint dashboard hanya menerima `year`. Kartu wajib
  /// menyatakan ini secara eksplisit; kalau tidak, angka yang tidak bergerak saat
  /// difilter akan disangka bug perhitungan.
  final bool summaryIsFallback;

  const CustomerListState({
    this.items = const [],
    this.page = 0,
    this.totalPages = 0,
    this.totalElements = 0,
    this.entityOptions = const [],
    this.offices = const [],
    this.regionId,
    this.branchId,
    this.searchTerm = '',
    this.entityFilter,
    this.hvcFilter = false,
    this.stageFilter,
    this.kpi,
    this.initialLoading = true,
    this.error,
    this.canAddCustomer = false,
    this.isSupervisor = false,
    this.rmId,
    this.rmName,
    this.cob,
    this.cobOptions = const [],
    this.summary,
    this.summaryFailed = false,
    this.summaryIsFallback = false,
  });

  CustomerListState copyWith({
    List<CustomerListModel>? items,
    int? page,
    int? totalPages,
    int? totalElements,
    List<ParamRef>? entityOptions,
    List<ScopeOffice>? offices,
    Object? regionId = _keep,
    Object? branchId = _keep,
    String? searchTerm,
    Object? entityFilter = _keep,
    bool? hvcFilter,
    Object? stageFilter = _keep,
    Object? kpi = _keep,
    bool? initialLoading,
    Object? error = _keep,
    bool? canAddCustomer,
    bool? isSupervisor,
    Object? rmId = _keep,
    Object? rmName = _keep,
    Object? cob = _keep,
    List<DashboardCategoryStat>? cobOptions,
    Object? summary = _keep,
    bool? summaryFailed,
    bool? summaryIsFallback,
  }) {
    return CustomerListState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      totalElements: totalElements ?? this.totalElements,
      entityOptions: entityOptions ?? this.entityOptions,
      offices: offices ?? this.offices,
      regionId: regionId == _keep ? this.regionId : regionId as String?,
      branchId: branchId == _keep ? this.branchId : branchId as String?,
      searchTerm: searchTerm ?? this.searchTerm,
      entityFilter:
          entityFilter == _keep ? this.entityFilter : entityFilter as String?,
      hvcFilter: hvcFilter ?? this.hvcFilter,
      stageFilter:
          stageFilter == _keep ? this.stageFilter : stageFilter as String?,
      kpi: kpi == _keep ? this.kpi : kpi as CustomerKpi?,
      initialLoading: initialLoading ?? this.initialLoading,
      error: error == _keep ? this.error : error as String?,
      canAddCustomer: canAddCustomer ?? this.canAddCustomer,
      isSupervisor: isSupervisor ?? this.isSupervisor,
      rmId: rmId == _keep ? this.rmId : rmId as String?,
      rmName: rmName == _keep ? this.rmName : rmName as String?,
      cob: cob == _keep ? this.cob : cob as String?,
      cobOptions: cobOptions ?? this.cobOptions,
      summary: summary == _keep ? this.summary : summary as CustomerScopedSummary?,
      summaryFailed: summaryFailed ?? this.summaryFailed,
      summaryIsFallback: summaryIsFallback ?? this.summaryIsFallback,
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

/// Angka cadangan untuk satu COB: ganti target & realisasi [base] dengan angka
/// kategori [cob] dari payload `/api/dashboard/categories`.
///
/// Ini BUKAN perhitungan baru di klien — backend menghitung
/// `customer-summary?cob=X` dari sumber yang persis sama
/// (`DashboardService.getCustomerScopedSummary`, cabang COB: `targetFullYear`,
/// `realisasiYtd`, dan realisasi bulan berjalan dari rincian bulanan kategori
/// itu). Selama tidak ada filter wilayah/cabang/RM, hasilnya identik dengan
/// endpoint yang belum ter-deploy tersebut, jadi tidak muncul "angka versi ketiga".
///
/// Hitungan visit tidak per-COB — backend pun mengembalikannya sama untuk semua
/// COB — jadi nilainya diambil apa adanya dari [base].
///
/// COB tak dikenal → [base] dikembalikan utuh. Sengaja TIDAK memakai
/// `DashboardCategories.byName`, yang jatuh ke kategori pertama saat tak ketemu:
/// menampilkan angka kategori lain di bawah label COB terpilih jauh lebih
/// berbahaya daripada menampilkan angka lingkup penuh.
CustomerScopedSummary applyCobToFallback(
  CustomerScopedSummary base,
  DashboardCategories cats,
  String? cob,
) {
  if (cob == null || cob.isEmpty) return base;
  DashboardCategoryStat? stat;
  for (final c in cats.categories) {
    if (c.category == cob) {
      stat = c;
      break;
    }
  }
  if (stat == null) return base;
  double realisasiMtd = 0;
  for (final m in stat.months) {
    if (m.month == cats.currentMonth) {
      realisasiMtd = m.realisasi;
      break;
    }
  }
  return CustomerScopedSummary(
    cob: cob,
    premiTarget: stat.targetFullYear,
    realisasi: stat.realisasiYtd,
    realisasiMtd: realisasiMtd,
    visitCountYtd: base.visitCountYtd,
    visitCountMtd: base.visitCountMtd,
  );
}

final customerListProvider =
    NotifierProvider<CustomerListNotifier, CustomerListState>(
        CustomerListNotifier.new);

/// Menggantikan seluruh logika `setState` di `_CustomerListScreenState`.
/// Perilaku (paging, filter, guard stale-load, jalur agent) DIPINDAH APA ADANYA.
class CustomerListNotifier extends Notifier<CustomerListState> {
  bool _agentScoped = false;

  /// Cache hasil cadangan `/api/dashboard/summary` (lihat [_loadSummaryFallback]).
  /// Nilainya tidak dipengaruhi filter, jadi cukup diambil sekali per sesi layar.
  CustomerScopedSummary? _fallbackSummary;

  /// Payload `/api/dashboard/categories` — sumber opsi dropdown COB SEKALIGUS
  /// sumber angka per-COB pada jalur cadangan (lihat [applyCobToFallback]).
  DashboardCategories? _cobCategories;

  /// Token load monotonik khusus kartu Target/Realisasi. Mengganti COB dua kali
  /// beruntun memulai dua panggilan; tanpa token ini yang mendarat belakangan
  /// belum tentu yang terakhir diminta, dan kartu bisa menampilkan angka COB lama
  /// di bawah label COB baru.
  int _summarySeq = 0;

  /// Token load monotonik: perubahan filter/search memulai load baru; halaman
  /// lama yang masih in-flight diabaikan saat kembali. (Dulu `_loadSeq`.)
  int _loadSeq = 0;

  /// Agent = buku kecil server-fixed (client-side); selain itu server-paginated.
  bool get _isPaged => !_agentScoped;

  @override
  CustomerListState build() => const CustomerListState();

  CustomerRepository get _repo => ref.read(customerRepoProvider);
  DashboardRepository get _dashRepo => ref.read(dashboardRepoProvider);
  ReferenceRepository get _refRepo => ref.read(referenceRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Set scope + izin
  /// tambah (berdasar peran sesi) + bootstrap data. Menggantikan `initState`.
  void start({required bool agentScoped}) {
    _agentScoped = agentScoped;
    final session = ref.read(sessionProvider);
    // RM dan ketua KUP boleh menambah customer — ketua KUP pada dasarnya RM yang
    // merangkap ketua unit, jadi ia punya portofolio sendiri. Kemampuan AGEN
    // sengaja disembunyikan (bukan dihapus): endpoint & alurnya tetap ada di
    // sistem, tinggal dimunculkan lagi bila kebijakan berubah.
    final userRoles = session?.user.roles ?? const <String>[];
    final canAdd = userRoles.contains('RM') || userRoles.contains('KUP');
    // "View atasan": peran supervisor dapat filter RM/COB + kartu monitoring.
    // Pakai daftar penyelia kanonik aplikasi (ADMIN/RO/BM/KUP — DPJ belum termasuk,
    // selaras main/profil/tools screen). Hanya bermakna di jalur paged (non-agent).
    final isSupervisor = _isPaged && MbisApp.isSupervisorRole(userRoles);
    state = state.copyWith(canAddCustomer: canAdd, isSupervisor: isSupervisor);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _loadEntityOptions(); // best-effort; chip filter entity dinamis
    if (_isPaged) {
      _loadScopeOffices(); // best-effort; supervisor dapat filter wilayah/cabang
      _loadStats(); // best-effort; gagal tak boleh menghambat daftar
      if (state.isSupervisor) {
        _loadCobOptions(); // opsi dropdown COB (pakai kategori dashboard)
        _loadSummary(); // kartu Target/Realisasi/Visit
      }
      await _resetAndLoad();
    } else {
      await _loadAgentAll();
    }
  }

  /// Opsi COB / kategori-target untuk filter supervisor (11 sama dengan dashboard).
  Future<void> _loadCobOptions() async {
    try {
      final cats = await _dashRepo.getCategories();
      _cobCategories = cats;
      state = state.copyWith(cobOptions: cats.categories);
    } catch (_) {
      // Filter COB opsional; biarkan kosong bila gagal.
    }
  }

  /// Headline Target / Realisasi / Visit untuk kartu supervisor. Mengikuti hanya
  /// filter region/branch/RM/COB (bukan pencarian nama atau chip entity), jadi
  /// tanpa filter angkanya sama dengan dashboard depan.
  Future<void> _loadSummary() async {
    if (!state.isSupervisor) return;
    final seq = ++_summarySeq; // klaim ini sbg permintaan kartu terbaru
    final cob = state.cob; // dibekukan: jalur cadangan bisa menempuh 2 await
    try {
      final s = await _dashRepo.getCustomerSummary(
        regionId: state.regionId,
        branchId: state.branchId,
        rmId: state.rmId,
        cob: cob,
      );
      if (seq != _summarySeq) return; // permintaan lebih baru sudah jalan
      state = state.copyWith(
        summary: s,
        summaryFailed: false,
        summaryIsFallback: false,
      );
    } catch (_) {
      // Kegagalan TIDAK boleh ditelan diam-diam. Sebelumnya blok ini kosong dan
      // kartu tetap menggambar Rp 0 / 0%, sehingga endpoint yang belum ter-deploy
      // (`customer-summary` membalas 404 di prod, Agustus 2026) tampak seperti
      // realisasi yang memang nol — bug data palsu yang mahal didiagnosis.
      await _loadSummaryFallback(cob, seq);
    }
  }

  /// Cadangan kartu Target/Realisasi saat `customer-summary` tak tersedia.
  ///
  /// Dirakit dari dua endpoint dashboard yang SUDAH ter-deploy:
  ///
  /// - `/api/dashboard/summary` → angka "Semua COB" + hitungan visit;
  /// - `/api/dashboard/categories` → target & realisasi saat sebuah COB dipilih
  ///   (lihat [applyCobToFallback]).
  ///
  /// Batasannya menyempit, tapi masih nyata dan tetap ditandai di UI: kedua
  /// endpoint itu **hanya menerima `year`** — tidak ada region/cabang/RM. Jadi
  /// filter COB kini ikut, sedangkan filter wilayah/cabang/RM belum, dan angkanya
  /// tetap lingkup penuh pemakai sampai `customer-summary` ter-deploy.
  ///
  /// Kedua sumber di-cache: keduanya agregat berat (mis. scope nasional DPJ) dan
  /// tak dipengaruhi filter, jadi memanggilnya ulang tiap kali filter berubah
  /// hanya membebani server tanpa mengubah angka.
  Future<void> _loadSummaryFallback(String? cob, int seq) async {
    final base = await _baseFallbackSummary();
    if (base == null) {
      if (seq != _summarySeq) return;
      // Dua-duanya gagal → nyatakan gagal, jangan menggambar Rp 0. `summary`
      // dikosongkan agar angka dari filter SEBELUMNYA tidak tertinggal di layar
      // dan disangka hasil filter yang baru.
      state = state.copyWith(
        summary: null,
        summaryFailed: true,
        summaryIsFallback: false,
      );
      return;
    }
    final mapped = await _withCobFallback(base, cob);
    if (seq != _summarySeq) return;
    state = state.copyWith(
      summary: mapped,
      summaryFailed: false,
      summaryIsFallback: true,
    );
  }

  /// Angka cadangan tanpa COB (`/api/dashboard/summary`), `null` bila gagal.
  Future<CustomerScopedSummary?> _baseFallbackSummary() async {
    final cached = _fallbackSummary;
    if (cached != null) return cached;
    try {
      final d = await _dashRepo.getSummary();
      final mapped = CustomerScopedSummary(
        premiTarget: d.premiTarget,
        realisasi: d.totalRealization,
        realisasiMtd: d.realisasiMtd,
        visitCountYtd: d.visitCountYtd,
        visitCountMtd: d.visitCountMtd,
      );
      _fallbackSummary = mapped;
      return mapped;
    } catch (_) {
      return null;
    }
  }

  /// Terapkan COB terpilih pada angka cadangan, memuat `categories` bila cache
  /// belum terisi (mis. panggilan opsi COB saat bootstrap gagal). Gagal memuat →
  /// kembalikan [base] apa adanya; kartu lebih baik menampilkan angka lingkup
  /// penuh daripada nol.
  Future<CustomerScopedSummary> _withCobFallback(
      CustomerScopedSummary base, String? cob) async {
    if (cob == null || cob.isEmpty) return base;
    var cats = _cobCategories;
    if (cats == null) {
      try {
        cats = await _dashRepo.getCategories();
        _cobCategories = cats;
      } catch (_) {
        return base;
      }
    }
    return applyCobToFallback(base, cats, cob);
  }

  /// Memuat ulang kartu Target/Realisasi saja (tombol "Coba lagi" di kartu),
  /// tanpa menyentuh daftar customer, paginasi, maupun filter yang aktif.
  /// Cache cadangan dibuang supaya tombol ini benar-benar mencoba ulang jaringan.
  Future<void> reloadSummary() {
    _fallbackSummary = null;
    _cobCategories = null;
    return _loadSummary();
  }

  Future<void> _loadEntityOptions() async {
    try {
      final opts = await _refRepo.parameters('ENTITY_CATEGORY');
      state = state.copyWith(entityOptions: opts);
    } catch (_) {
      // Chip jatuh ke "Semua" + HVC saja bila gagal.
    }
  }

  void onHvcToggle() {
    state = state.copyWith(hvcFilter: !state.hvcFilter);
    if (_isPaged) {
      _loadStats();
      _resetAndLoad();
    }
  }

  /// Pilih tahap pipeline (null = semua). Menekan tahap yang sedang aktif
  /// mematikannya — pintasan yang dipakai orang tanpa perlu membuka sheet lagi.
  void onStageChanged(String? stage) {
    final next = state.stageFilter == stage ? null : stage;
    state = state.copyWith(stageFilter: next);
    if (_isPaged) {
      _loadStats();
      _resetAndLoad();
    }
  }

  Future<void> _loadScopeOffices() async {
    try {
      final offices = await _dashRepo.getScopeOffices();
      state = state.copyWith(offices: offices);
    } catch (_) {
      // Filter opsional (RM/agent list kosong); abaikan gagal.
    }
  }

  Future<void> _loadStats() async {
    try {
      final kpi = await _repo.getCustomerKpi(
        search: state.searchTerm,
        entity: state.entityFilter,
        regionId: state.regionId,
        branchId: state.branchId,
        rmId: state.rmId,
        hvc: state.hvcFilter,
        stage: state.stageFilter,
      );
      state = state.copyWith(kpi: kpi);
    } catch (_) {
      // KPI dekoratif; biarkan "–".
    }
  }

  // ── Jalur paginated (non-agent) ─────────────────────────────────────────────
  Future<void> _resetAndLoad() async {
    state = state.copyWith(page: 0, initialLoading: true, error: null);
    await _loadPage();
  }

  Future<void> _loadPage() async {
    final seq = ++_loadSeq; // klaim ini sbg load terbaru
    try {
      final res = await _repo.getCustomersPaged(
        page: state.page,
        size: kCustomerPageSize,
        search: state.searchTerm,
        entity: state.entityFilter,
        regionId: state.regionId,
        branchId: state.branchId,
        rmId: state.rmId,
        hvc: state.hvcFilter,
        stage: state.stageFilter,
      );
      // Load lebih baru (filter/search/reset) mulai saat ini in-flight — buang
      // respons usang ini agar barisnya tak menimpa daftar baru.
      if (seq != _loadSeq) return;
      // Refresh bisa mendarat melewati halaman terakhir (data menyusut) —
      // mundur ke halaman terakhir yang masih ada.
      if (res.content.isEmpty && res.page > 0 && res.totalPages > 0) {
        state = state.copyWith(page: res.totalPages - 1);
        await _loadPage();
        return;
      }
      state = state.copyWith(
        items: res.content,
        page: res.page,
        totalPages: res.totalPages,
        totalElements: res.totalElements,
        initialLoading: false,
      );
    } catch (e) {
      if (seq != _loadSeq) return;
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        initialLoading: false,
      );
    }
  }

  /// Pindah halaman dari kontrol paging. (Scroll-ke-atas ditangani layar.)
  void goToPage(int page) {
    if (page < 0 ||
        (state.totalPages > 0 && page >= state.totalPages) ||
        page == state.page) {
      return;
    }
    state = state.copyWith(page: page, initialLoading: true, error: null);
    _loadPage();
  }

  // ── Jalur agent (client-side) ───────────────────────────────────────────────
  Future<void> _loadAgentAll() async {
    state = state.copyWith(initialLoading: true, error: null);
    try {
      final data = await _repo.getAgentCustomers();
      state = state.copyWith(items: data, initialLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        initialLoading: false,
      );
    }
  }

  Future<void> refresh() {
    if (_isPaged) {
      _loadStats(); // header KPI ikut data yang diedit di layar detail
      // Muat ulang halaman AKTIF (bukan balik ke halaman 1).
      state = state.copyWith(initialLoading: true, error: null);
      return _loadPage();
    }
    return _loadAgentAll();
  }

  void onSearchChanged(String value) {
    final v = value.trim();
    if (v == state.searchTerm) return;
    state = state.copyWith(searchTerm: v);
    if (_isPaged) {
      _resetAndLoad();
      _loadStats(); // header counts ikut filter
    }
  }

  void onEntityChanged(String? entity) {
    state = state.copyWith(entityFilter: entity);
    if (_isPaged) {
      _resetAndLoad();
      _loadStats();
    }
  }

  void onRegionChanged(String? regionId) {
    // branches bergantung region yang dipilih → reset branch. Dropdown RM ikut
    // region/branch, jadi reset juga.
    state = state.copyWith(
        regionId: regionId, branchId: null, rmId: null, rmName: null);
    _resetAndLoad();
    _loadStats(); // header counts ikut filter region/branch
    _loadSummary(); // kartu Target/Realisasi/Visit ikut filter region/branch
  }

  void onBranchChanged(String? branchId) {
    // Dropdown RM ikut region/branch, jadi reset saat cabang berubah.
    state = state.copyWith(branchId: branchId, rmId: null, rmName: null);
    _resetAndLoad();
    _loadStats();
    _loadSummary();
  }

  void onRmChanged(String? rmId, String? rmName) {
    state = state.copyWith(rmId: rmId, rmName: rmName);
    _resetAndLoad(); // daftar menyempit ke customer RM ini
    _loadStats();
    _loadSummary();
  }

  void onCobChanged(String? cob) {
    // COB hanya memengaruhi kartu Target/Realisasi, bukan daftar customer.
    state = state.copyWith(cob: cob);
    _loadSummary();
  }

  /// Bersihkan semua filter yang dikendalikan sheet sekaligus (tombol "Reset").
  void resetAllFilters() {
    state = state.copyWith(
      entityFilter: null,
      hvcFilter: false,
      stageFilter: null,
      regionId: null,
      branchId: null,
      rmId: null,
      rmName: null,
    );
    if (_isPaged) {
      _resetAndLoad();
      _loadStats();
      _loadSummary();
    }
  }
}
