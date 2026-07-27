import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/broker/broker_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/reference/exchange_rate_service.dart';
import 'package:mbis/src/reference/reference_repository.dart';
import 'package:mbis/src/referral/referral_repository.dart';

/// Fallback opsi Sumber Bisnis (param SUMBER_BISNIS belum termuat). ParamRef
/// tidak punya const constructor, jadi disimpan sebagai list top-level (bukan
/// default const di konstruktor state) — nilainya persis fallback layar lama.
final List<ParamRef> _fallbackSumberOptions = [
  ParamRef('DIRECT', 'Direct'),
  ParamRef('AGENT', 'Agen'),
  ParamRef('BROKER', 'Broker'),
  ParamRef('BANCASSURANCE', 'Bancassurance'),
  ParamRef('TPM', 'TPM'),
];

/// State ASYNC (data/loading/saving) untuk layar Tambah Pipeline — HANYA bagian
/// yang dimuat dari backend atau berupa status muat/simpan/kurs. Input form
/// interaktif (controller, nilai dropdown terpilih, toggle, daftar parties &
/// tender, tanggal) TETAP di widget `AddPipelineScreen`, tidak dipindah ke sini.
///
/// Yang dipindah: peran sesi (isAgent/isRm), daftar broker + flag muat, cascade
/// produk (COB/LOB/ToC), opsi referensi (kerja sama, badan hukum, proses tender,
/// sumber bisnis, currency), daftar agen, daftar customer + flag muat, daftar
/// cabang tujuan referral, flag muat kurs, dan flag simpan.
class AddPipelineState {
  final bool isAgent;
  final bool isRm;
  final List<BrokerModel> brokers;
  final bool brokersLoading;
  // Cascade produk (backend). null sebelum termuat; widget meng-coalesce ke
  // ProductCascade(const []) — ProductCascade tak punya const constructor.
  final ProductCascade? cascade;
  final List<ParamRef> kerjaSamaOptions;
  final List<ParamRef> badanHukumOptions;
  final List<ParamRef> tenderStepOptions;
  final List<AgentRef> agents;
  final List<CustomerListModel> customers;
  final bool customersLoading;
  final List<BranchOffice> branchOffices;
  // Dropdown berbasis parameter (admin-editable). Default = fallback bila param
  // belum termuat / kosong.
  final List<ParamRef> sumberOptions;
  final List<String> currencyOptions;
  final bool kursLoading; // sedang mengambil kurs indikatif (FX) non-IDR
  final bool saving;

  const AddPipelineState({
    this.isAgent = false,
    this.isRm = false,
    this.brokers = const [],
    this.brokersLoading = false,
    this.cascade,
    this.kerjaSamaOptions = const [],
    this.badanHukumOptions = const [],
    this.tenderStepOptions = const [],
    this.agents = const [],
    this.customers = const [],
    this.customersLoading = false,
    this.branchOffices = const [],
    this.sumberOptions = const [],
    this.currencyOptions = const [
      'IDR',
      'USD',
      'EUR',
      'SGD',
      'CNY',
      'MYR',
      'KRW',
      'AUD',
    ],
    this.kursLoading = false,
    this.saving = false,
  });

  AddPipelineState copyWith({
    bool? isAgent,
    bool? isRm,
    List<BrokerModel>? brokers,
    bool? brokersLoading,
    ProductCascade? cascade,
    List<ParamRef>? kerjaSamaOptions,
    List<ParamRef>? badanHukumOptions,
    List<ParamRef>? tenderStepOptions,
    List<AgentRef>? agents,
    List<CustomerListModel>? customers,
    bool? customersLoading,
    List<BranchOffice>? branchOffices,
    List<ParamRef>? sumberOptions,
    List<String>? currencyOptions,
    bool? kursLoading,
    bool? saving,
  }) {
    return AddPipelineState(
      isAgent: isAgent ?? this.isAgent,
      isRm: isRm ?? this.isRm,
      brokers: brokers ?? this.brokers,
      brokersLoading: brokersLoading ?? this.brokersLoading,
      // cascade hanya pernah di-set ke nilai non-null (saat referensi termuat),
      // jadi tak butuh sentinel _keep.
      cascade: cascade ?? this.cascade,
      kerjaSamaOptions: kerjaSamaOptions ?? this.kerjaSamaOptions,
      badanHukumOptions: badanHukumOptions ?? this.badanHukumOptions,
      tenderStepOptions: tenderStepOptions ?? this.tenderStepOptions,
      agents: agents ?? this.agents,
      customers: customers ?? this.customers,
      customersLoading: customersLoading ?? this.customersLoading,
      branchOffices: branchOffices ?? this.branchOffices,
      sumberOptions: sumberOptions ?? this.sumberOptions,
      currencyOptions: currencyOptions ?? this.currencyOptions,
      kursLoading: kursLoading ?? this.kursLoading,
      saving: saving ?? this.saving,
    );
  }
}

final addPipelineProvider =
    NotifierProvider<AddPipelineNotifier, AddPipelineState>(
      AddPipelineNotifier.new,
    );

/// Memindahkan logika `setState` ASYNC dari `_AddPipelineScreenState`. Logika
/// tiap metode DIPINDAH APA ADANYA (muat broker/referensi/customer/cabang,
/// ambil kurs, simpan pipeline). Repository legacy dipakai ulang via provider
/// di `repository_providers`; sesi dibaca dari `sessionProvider`.
class AddPipelineNotifier extends Notifier<AddPipelineState> {
  @override
  AddPipelineState build() =>
      AddPipelineState(sumberOptions: _fallbackSumberOptions);

  /// Dipanggil sekali dari initState layar (post-frame). Deteksi peran (agent/RM)
  /// + muat broker/referensi/customer, dan cabang referral bila RM. Menggantikan
  /// `didChangeDependencies` lama (guard `_apiClient == null` sekali jalan).
  void start() {
    final session = ref.read(sessionProvider);
    final roles = session?.user.roles ?? const [];
    final isAgent = roles.contains('AGENT');
    final isRm = roles.contains('RM');
    // Provider ini keepAlive (NotifierProvider bukan autoDispose), jadi state-nya
    // TETAP HIDUP setelah layar ditutup. Mulai dari state bersih tiap kali layar
    // dibuka; kalau tidak, flag sementara (`saving`, `kursLoading`) dari
    // pengisian sebelumnya ikut terbawa dan tombol Simpan langsung tampil
    // loading + nonaktif padahal belum ada yang disimpan.
    state = AddPipelineState(
      isAgent: isAgent,
      isRm: isRm,
      sumberOptions: _fallbackSumberOptions,
    );
    _loadBrokers();
    _loadReference();
    _loadCustomers();
    if (isRm) {
      _loadBranchOffices(); // referral is an RM-only action
    }
  }

  Future<void> _loadBranchOffices() async {
    try {
      final offices = await ref.read(referralRepoProvider).branchOffices();
      final myOfficeId = ref.read(sessionProvider)?.user.officeId;
      state = state.copyWith(
        branchOffices: offices.where((o) => o.id != myOfficeId).toList(),
      );
    } catch (_) {
      /* referral dropdown stays empty */
    }
  }

  Future<void> _loadCustomers() async {
    state = state.copyWith(customersLoading: true);
    try {
      final customers = await ref.read(customerRepoProvider).getCustomers();
      state = state.copyWith(customers: customers, customersLoading: false);
    } catch (_) {
      state = state.copyWith(customersLoading: false);
    }
  }

  Future<void> _loadBrokers() async {
    state = state.copyWith(brokersLoading: true);
    try {
      final brokers = await ref.read(brokerRepoProvider).getBrokerOptions();
      state = state.copyWith(brokers: brokers, brokersLoading: false);
    } catch (_) {
      state = state.copyWith(brokersLoading: false);
    }
  }

  Future<void> _loadReference() async {
    final refRepo = ref.read(referenceRepoProvider);
    try {
      final products = await refRepo.products();
      final ks = await refRepo.parameters('KERJA_SAMA');
      final bh = await refRepo.parameters('BADAN_HUKUM');
      final tnd = await refRepo.parameters('PROSES_TENDER');
      final sb = await refRepo.parameters('SUMBER_BISNIS');
      final cur = await refRepo.parameters('CURRENCY');
      final agents = await refRepo.agents();
      state = state.copyWith(
        cascade: ProductCascade(products),
        kerjaSamaOptions: ks,
        badanHukumOptions: bh,
        tenderStepOptions: tnd,
        sumberOptions: sb.isNotEmpty ? sb : state.sumberOptions,
        currencyOptions: cur.isNotEmpty
            ? cur.map((p) => p.key).toList()
            : state.currencyOptions,
        agents: agents,
      );
    } catch (_) {
      /* dropdowns stay empty; user sees that nothing loaded */
    }
  }

  /// Ambil kurs indikatif (FX) untuk [cur] & tandai sedang memuat. Staleness
  /// (currency berubah saat menunggu) & penulisan hasil ke controller ditangani
  /// widget karena bergantung pada input user (`_currency` + `_kursController`).
  Future<double?> loadKurs(String cur) async {
    state = state.copyWith(kursLoading: true);
    return ExchangeRateService.rateToIdr(cur);
  }

  void clearKursLoading() {
    state = state.copyWith(kursLoading: false);
  }

  /// Simpan pipeline. Mengembalikan `null` bila sukses (widget menutup layar),
  /// atau pesan error (`e.toString()`) bila gagal. Body dibangun di widget dari
  /// input form; di sini hanya panggilan async.
  Future<String?> save(Map<String, dynamic> body) async {
    state = state.copyWith(saving: true);
    try {
      await ref.read(pipelineRepoProvider).addPipeline(body);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      // `saving` HARUS ikut direset saat sukses. Dulu tidak, karena versi
      // setState lama mati bersama widget — sedangkan state notifier ini hidup
      // lebih lama dari layar, jadi `saving: true` yang tertinggal membuat
      // tombol Simpan pada pembukaan layar BERIKUTNYA macet loading selamanya.
      state = state.copyWith(saving: false);
    }
  }
}
