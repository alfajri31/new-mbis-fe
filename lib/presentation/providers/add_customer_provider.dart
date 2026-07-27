import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/reference/reference_repository.dart';

const Object _keep = Object();

/// State ASYNC (data/loading) untuk layar Tambah Customer — HANYA bagian yang
/// dimuat dari backend atau berupa status muat/simpan. Input form interaktif
/// (controller, nilai dropdown terpilih, toggle, upload map, lokasi) TETAP di
/// widget `AddCustomerScreen`, tidak dipindah ke sini.
///
/// Yang dipindah: opsi referensi (badan hukum/entitas/PIC title), daftar bank,
/// opsi BUMN (master_bumn), flag & daftar RM (jalur agent), status + hasil cek
/// blacklist, daftar similar-customer, serta flag simpan + pesan error simpan.
class AddCustomerState {
  final List<ParamRef> badanHukumOptions;
  final List<ParamRef> entitasOptions; // tanpa BUMN (BUMN lewat toggle)
  final List<BumnOption> bumnOptions; // dari master_bumn (515 entitas nyata)
  final List<BankRef> banks;
  // Dropdown berbasis parameter (editable di Kelola Master Data). Default =
  // fallback bila parameter belum termuat / kosong.
  final List<String> picTitleOptions;
  final bool isAgent;
  final bool loadingRms;
  final List<AssignableRm> rms;
  // status: 'idle' | 'checking' | 'clean' | 'warning' | 'error' | 'saveError'.
  // WARNING-ONLY — tidak ada status 'blocked'; customer selalu tersimpan.
  final String blacklistStatus;
  final BlacklistCheckResult? blacklistResult;
  final List<SimilarCustomer> similarCustomers;
  final String saveErrorMsg;
  final bool saving; // sedang menyimpan setelah RM konfirmasi

  const AddCustomerState({
    this.badanHukumOptions = const [],
    this.entitasOptions = const [],
    this.bumnOptions = const [],
    this.banks = const [],
    this.picTitleOptions = const ['Bapak', 'Ibu'],
    this.isAgent = false,
    this.loadingRms = false,
    this.rms = const [],
    this.blacklistStatus = 'idle',
    this.blacklistResult,
    this.similarCustomers = const [],
    this.saveErrorMsg = '',
    this.saving = false,
  });

  AddCustomerState copyWith({
    List<ParamRef>? badanHukumOptions,
    List<ParamRef>? entitasOptions,
    List<BumnOption>? bumnOptions,
    List<BankRef>? banks,
    List<String>? picTitleOptions,
    bool? isAgent,
    bool? loadingRms,
    List<AssignableRm>? rms,
    String? blacklistStatus,
    Object? blacklistResult = _keep,
    List<SimilarCustomer>? similarCustomers,
    String? saveErrorMsg,
    bool? saving,
  }) {
    return AddCustomerState(
      badanHukumOptions: badanHukumOptions ?? this.badanHukumOptions,
      entitasOptions: entitasOptions ?? this.entitasOptions,
      bumnOptions: bumnOptions ?? this.bumnOptions,
      banks: banks ?? this.banks,
      picTitleOptions: picTitleOptions ?? this.picTitleOptions,
      isAgent: isAgent ?? this.isAgent,
      loadingRms: loadingRms ?? this.loadingRms,
      rms: rms ?? this.rms,
      blacklistStatus: blacklistStatus ?? this.blacklistStatus,
      blacklistResult: blacklistResult == _keep
          ? this.blacklistResult
          : blacklistResult as BlacklistCheckResult?,
      similarCustomers: similarCustomers ?? this.similarCustomers,
      saveErrorMsg: saveErrorMsg ?? this.saveErrorMsg,
      saving: saving ?? this.saving,
    );
  }
}

final addCustomerProvider =
    NotifierProvider<AddCustomerNotifier, AddCustomerState>(
      AddCustomerNotifier.new,
    );

/// Memindahkan logika `setState` ASYNC dari `_AddCustomerScreenState`. Logika
/// tiap metode DIPINDAH APA ADANYA (memuat opsi, cek blacklist, cari similar,
/// simpan). Repository legacy dipakai ulang via provider di `repository_providers`.
class AddCustomerNotifier extends Notifier<AddCustomerState> {
  @override
  AddCustomerState build() => const AddCustomerState();

  /// Dipanggil sekali dari initState layar (post-frame). Deteksi peran (agent →
  /// muat daftar RM) + muat opsi referensi/BUMN. Sesi dibaca dari sessionProvider.
  /// Menggantikan initState post-frame + didChangeDependencies lama.
  void start() {
    final session = ref.read(sessionProvider);
    final roles = session?.user.roles ?? const [];
    if (roles.contains('AGENT')) {
      state = state.copyWith(isAgent: true);
      _loadAssignableRms();
    }
    _loadReference();
  }

  Future<void> _loadReference() async {
    final refRepo = ref.read(referenceRepoProvider);
    try {
      final bh = await refRepo.parameters('BADAN_HUKUM');
      final ent = await refRepo.parameters('ENTITY_CATEGORY');
      final pic = await refRepo.parameters('PIC_TITLE');
      final banks = await refRepo.banks();
      // BUMN dari pohon master_bumn (bukan dropdown parameter) — struktur relasi &
      // induk ikut di tiap node, jadi tak perlu input manual.
      final bumn = await ref.read(bumnRepoProvider).getBumnOptions();
      state = state.copyWith(
        badanHukumOptions: bh,
        entitasOptions: ent
            .where((e) => e.key.toUpperCase() != 'BUMN')
            .map((e) => ParamRef(e.key, _entitasLabel(e)))
            .toList(),
        bumnOptions: bumn,
        // Tampilkan label (paramValue); simpan label sebagai nilai. Pertahankan
        // fallback bila kategori belum di-seed.
        picTitleOptions: pic.isNotEmpty
            ? pic.map((e) => e.value).toList()
            : state.picTitleOptions,
        banks: banks,
      );
    } catch (_) {
      /* dropdowns stay empty */
    }
  }

  Future<void> _loadAssignableRms() async {
    state = state.copyWith(loadingRms: true);
    try {
      final rms = await ref.read(customerRepoProvider).getAssignableRms();
      state = state.copyWith(rms: rms, loadingRms: false);
    } catch (_) {
      state = state.copyWith(loadingRms: false);
    }
  }

  /// Expands BHMN/BLU with their full name directly in the dropdown label
  /// (shown in the closed field AND the option list) so the meaning is visible
  /// without having to pick it first.
  String _entitasLabel(ParamRef e) {
    switch (e.key.toUpperCase()) {
      case 'BHMN':
        return '${e.value} (Badan Hukum Milik Negara)';
      case 'BLU':
        return '${e.value} (Badan Layanan Umum)';
      default:
        return e.value;
    }
  }

  /// Reset ke status "checking" sebelum sheet cek blacklist dibuka.
  void beginBlacklistCheck() => state = state.copyWith(
    blacklistStatus: 'checking',
    blacklistResult: null,
    saving: false,
  );

  /// Kembalikan status ke idle (sheet ditutup tanpa menyimpan).
  void resetBlacklistStatus() =>
      state = state.copyWith(blacklistStatus: 'idle');

  /// Cek blacklist atas input (TANPA menyimpan) + cari kemungkinan duplikat.
  /// Hasil hanya peringatan untuk RM. Logika dipindah apa adanya dari layar.
  Future<void> runPreview({
    required bool isBank,
    required bool isBumn,
    required String name,
    required String npwp,
    required Map<String, dynamic> payload,
  }) async {
    final repo = ref.read(customerRepoProvider);
    // Cek duplikat lintas-cabang berjalan bareng cek blacklist. Hanya untuk
    // swasta/perorangan: bank menurunkan nama, BUMN sudah menyatu di master_bumn.
    if (!isBank && !isBumn && name.trim().isNotEmpty) {
      try {
        final npwpDigits = npwp.replaceAll(RegExp(r'[^0-9]'), '');
        final sim = await repo.similarCustomers(
          name: name,
          npwp: npwpDigits.isEmpty ? null : npwpDigits,
        );
        state = state.copyWith(similarCustomers: sim);
      } catch (_) {
        state = state.copyWith(similarCustomers: const []); // best-effort
      }
    } else {
      state = state.copyWith(similarCustomers: const []);
    }

    try {
      final result = await repo.previewBlacklist(payload);
      state = state.copyWith(
        blacklistResult: result,
        blacklistStatus: switch (result.status) {
          'WARNING' => 'warning',
          'ERROR' => 'error',
          _ => 'clean',
        },
      );
    } catch (_) {
      // Backend tak terjangkau → tetap izinkan RM menyimpan, tandai tak terverifikasi.
      state = state.copyWith(
        blacklistResult: BlacklistCheckResult(
          status: 'ERROR',
          sources: const [],
          matches: const [],
        ),
        blacklistStatus: 'error',
      );
    }
  }

  /// Simpan customer + unggah dokumen terpilih. Mengembalikan customer baru bila
  /// sukses (di-pop layar ke daftar), atau null bila gagal (state → saveError).
  /// [uploads] = daftar (docType, bytes, fileName) dari map upload di widget.
  Future<CustomerListModel?> save({
    required Map<String, dynamic> payload,
    required List<(String, List<int>, String)> uploads,
  }) async {
    state = state.copyWith(saving: true);
    final repo = ref.read(customerRepoProvider);
    try {
      final created = await repo.addCustomer(payload);
      // Upload dokumen yang dipilih setelah customer punya id.
      for (final u in uploads) {
        await repo.uploadDocument(created.customer.id, u.$1, u.$2, u.$3);
      }
      return created.customer;
    } catch (e) {
      state = state.copyWith(
        saveErrorMsg: e.toString().replaceFirst('Exception: ', ''),
        blacklistStatus: 'saveError',
      );
      return null;
    } finally {
      // Direset juga saat sukses: state notifier keepAlive (hidup lebih lama
      // dari layar), jadi `saving: true` yang tertinggal bikin tombol simpan
      // pada pembukaan sheet berikutnya macet loading.
      state = state.copyWith(saving: false);
    }
  }
}
