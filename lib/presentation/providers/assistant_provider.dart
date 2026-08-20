import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/assistant/assistant_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';

const Object _keep = Object();

/// Peran yang boleh MENJALANKAN Tanya Dubi. Cerminan gerbang backend
/// `@PreAuthorize("hasAnyRole('RM','BM','RO')")` di `AssistantController`.
///
/// CR-17 (TNG-3) menambahkan BM dan pimpinan Kanwil (RO) di samping RM. Daftarnya
/// ditaruh di satu tempat karena aturan yang sama dipakai tiga layar (Tools, detail
/// customer, layar assistant); tiga salinan `roles.contains('RM')` yang tersebar
/// adalah cara termudah salah satunya tertinggal saat aturan berubah lagi.
///
/// KUP ikut disertakan: backend sudah meloloskannya sejak dulu lewat pewarisan
/// `ROLE_KUP > ROLE_RM`, hanya menunya yang tersembunyi — jadi ini menutup selisih
/// lama antara apa yang diizinkan server dan apa yang ditampilkan aplikasi.
const Set<String> kAssistantRoles = {'RM', 'BM', 'RO', 'KUP'};

/// True bila salah satu peran sesi boleh memakai Tanya Dubi.
bool canUseAssistant(Iterable<String> roles) => roles.any(kAssistantRoles.contains);

/// State AI Assistant — cerminan 1:1 dari field `setState` DATA/LOADING/RESULT di
/// layar lama. Yang TIDAK ikut (tetap dikelola widget dengan `setState`): controller
/// teks, nilai chip/multi-chip yang diedit user, langkah wizard (`_step`), dan
/// identitas customer terpilih (`_custId`/`_custName`) — sejalan aturan migrasi
/// (hanya state backend/async yang dipindah).
class AssistantState {
  /// Gate sesi/repo siap (dulu `_ready`); body menampilkan spinner selama false.
  final bool ready;

  /// Izin menjalankan aktivitas AI (RM, BM, RO — lihat [kAssistantRoles]).
  /// Diturunkan dari peran sesi.
  final bool canRun;

  // Customer picker (jalur masuk dari Tools).
  final List<CustomerListModel> custResults;
  final bool custLoading;

  // Daftar aktivitas.
  final List<AiActivity> activities;
  final bool activitiesLoading;
  final String? activitiesError;

  // Aktivitas terpilih + state input non-UI.
  final AiActivity? activity;
  final String? formError;
  final bool limitReached;

  // Hasil tersimpan untuk customer ini (semua aktivitas), dimuat bersama daftar
  // aktivitas. Dipakai menawarkan jawaban tersimpan alih-alih menghabiskan token.
  final List<SavedAiResult> savedResults;

  // Run + hasil.
  final bool running;
  final AiRunResult? result;
  final bool saving;
  final bool saved;

  /// True saat [result] adalah jawaban tersimpan yang ditampilkan tanpa memanggil model.
  final bool fromCache;
  final String? cachedAt;

  const AssistantState({
    this.ready = false,
    this.canRun = false,
    this.custResults = const [],
    this.custLoading = false,
    this.activities = const [],
    this.activitiesLoading = false,
    this.activitiesError,
    this.activity,
    this.formError,
    this.limitReached = false,
    this.savedResults = const [],
    this.running = false,
    this.result,
    this.saving = false,
    this.saved = false,
    this.fromCache = false,
    this.cachedAt,
  });

  AssistantState copyWith({
    bool? ready,
    bool? canRun,
    List<CustomerListModel>? custResults,
    bool? custLoading,
    List<AiActivity>? activities,
    bool? activitiesLoading,
    Object? activitiesError = _keep,
    Object? activity = _keep,
    Object? formError = _keep,
    bool? limitReached,
    List<SavedAiResult>? savedResults,
    bool? running,
    Object? result = _keep,
    bool? saving,
    bool? saved,
    bool? fromCache,
    Object? cachedAt = _keep,
  }) {
    return AssistantState(
      ready: ready ?? this.ready,
      canRun: canRun ?? this.canRun,
      custResults: custResults ?? this.custResults,
      custLoading: custLoading ?? this.custLoading,
      activities: activities ?? this.activities,
      activitiesLoading: activitiesLoading ?? this.activitiesLoading,
      activitiesError:
          activitiesError == _keep ? this.activitiesError : activitiesError as String?,
      activity: activity == _keep ? this.activity : activity as AiActivity?,
      formError: formError == _keep ? this.formError : formError as String?,
      limitReached: limitReached ?? this.limitReached,
      savedResults: savedResults ?? this.savedResults,
      running: running ?? this.running,
      result: result == _keep ? this.result : result as AiRunResult?,
      saving: saving ?? this.saving,
      saved: saved ?? this.saved,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt == _keep ? this.cachedAt : cachedAt as String?,
    );
  }
}

final assistantProvider =
    NotifierProvider<AssistantNotifier, AssistantState>(AssistantNotifier.new);

/// Menggantikan logika `setState` DATA/LOADING/RESULT di `_AssistantScreenState`.
/// Perilaku (bootstrap peran, pencarian customer, muat aktivitas + cache,
/// buka aktivitas dengan tawaran cache, jalankan, simpan + refresh cache)
/// DIPINDAH APA ADANYA. Repository legacy dipakai ulang lewat shared provider.
class AssistantNotifier extends Notifier<AssistantState> {
  @override
  AssistantState build() => const AssistantState();

  AssistantRepository get _repo => ref.read(assistantRepoProvider);
  CustomerRepository get _custRepo => ref.read(customerRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Set izin (dari peran sesi)
  /// + bootstrap data. Menggantikan bagian data dari `initState` lama (konstruksi
  /// repo kini via provider; peran dibaca dari [sessionProvider], bukan context).
  void start({String? customerId}) {
    final session = ref.read(sessionProvider);
    final roles = session?.user.roles ?? const [];
    state = state.copyWith(canRun: canUseAssistant(roles));
    if (customerId != null) {
      loadActivities(customerId);
    } else {
      searchCustomers('');
    }
    state = state.copyWith(ready: true);
  }

  Future<void> searchCustomers(String q) async {
    state = state.copyWith(custLoading: true);
    try {
      final page = await _custRepo.getCustomersPaged(search: q, size: 20);
      state = state.copyWith(custResults: page.content, custLoading: false);
    } catch (_) {
      state = state.copyWith(custLoading: false);
    }
  }

  Future<void> loadActivities(String custId) async {
    state = state.copyWith(activitiesLoading: true, activitiesError: null);
    try {
      final list = await _repo.getActivities(custId);
      // Best-effort: a failure here just means no cache is offered, never blocks.
      List<SavedAiResult> saved = const [];
      try {
        saved = await _repo.getSavedResults(custId);
      } catch (_) {}
      state = state.copyWith(
        activities: list,
        savedResults: saved,
        activitiesLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        activitiesError: e is AssistantException ? e.message : '$e',
        activitiesLoading: false,
      );
    }
  }

  /// Membuka aktivitas: pilih aktivitas + (bila ada) tawarkan jawaban tersimpan
  /// alih-alih menjalankan — inti "hemat token". Pengelolaan controller/chip input
  /// tetap di widget; di sini hanya state aktivitas + hasil/cache.
  void openActivity(AiActivity a) {
    // If this activity already has a stored answer on this customer, show it
    // instead of running — the whole point of "hemat token". The RM opts into a
    // fresh call with "Jalankan ulang". savedResults is newest-first (server order).
    SavedAiResult? cached;
    for (final s in state.savedResults) {
      if (s.activityId == a.id) {
        cached = s;
        break;
      }
    }

    if (cached != null) {
      state = state.copyWith(
        activity: a,
        formError: null,
        limitReached: false,
        result: AiRunResult(
          activityId: cached.activityId,
          activityName: cached.activityName,
          result: cached.result,
          sources: cached.sources,
          model: cached.model,
        ),
        fromCache: true,
        cachedAt: cached.generatedAt,
        saved: true, // a cached result is, by definition, already saved
      );
    } else {
      state = state.copyWith(
        activity: a,
        formError: null,
        limitReached: false,
        result: null,
        fromCache: false,
        cachedAt: null,
        saved: false,
      );
    }
  }

  /// Leaves the cached view to run a fresh call — this is where tokens are spent.
  void rerunFromCache() {
    state = state.copyWith(
      result: null,
      fromCache: false,
      cachedAt: null,
      saved: false,
    );
  }

  /// Pesan error validasi field (dulu `setState(_formError=...)` sebelum run).
  void setFormError(String message) {
    state = state.copyWith(formError: message);
  }

  /// Menjalankan aktivitas dengan [inputs] yang sudah dibangun widget dari
  /// controller/chip-nya. Mengembalikan true bila sukses (widget lalu pindah ke
  /// langkah hasil); false bila limit/error (formError terisi, tetap di form).
  Future<bool> run({
    required String custId,
    required AiActivity activity,
    required Map<String, String> inputs,
  }) async {
    state = state.copyWith(running: true, formError: null, limitReached: false);
    try {
      final result = await _repo.runActivity(custId, activity.id, inputs);
      state = state.copyWith(
        result: result,
        running: false,
        saved: false,
        fromCache: false,
        cachedAt: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        running: false,
        limitReached: e is AiLimitException,
        formError: e is AssistantException ? e.message : 'Terjadi kesalahan: $e',
      );
      return false;
    }
  }

  /// Menyimpan hasil aktif ke customer, lalu refresh cache (best-effort) agar
  /// membuka ulang aktivitas menawarkan yang baru disimpan. Mengembalikan `null`
  /// bila sukses, atau pesan error untuk ditampilkan widget (snackbar = UI).
  Future<String?> save(String custId) async {
    final r = state.result!;
    state = state.copyWith(saving: true);
    try {
      await _repo.saveResult(
        custId,
        activityId: r.activityId,
        result: r.result,
        sources: r.sources,
        model: r.model,
      );
      state = state.copyWith(saving: false, saved: true);
      // Refresh the cache so re-opening this activity offers what was just saved
      // instead of forcing another run. Best-effort.
      try {
        final saved = await _repo.getSavedResults(custId);
        state = state.copyWith(savedResults: saved);
      } catch (_) {}
      return null;
    } catch (e) {
      state = state.copyWith(saving: false);
      return e is AssistantException ? e.message : '$e';
    }
  }
}
