import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/rm_handover/rm_handover_repository.dart' show RmCandidate;
import 'package:mbis/src/rm_handover/rm_transfer_repository.dart';

const Object _keep = Object();

/// State S-131 (Pemindahan Cabang RM) — cerminan 1:1 dari field `setState` di
/// `rm_transfer_screen.dart` (layar daftar + sheet "Buat Pemindahan").
///
/// Hanya DATA/LOADING/SAVING backend yang dipindah ke sini. Kontrol UI murni
/// (pilihan RM/cabang, controller alasan, dialog, navigasi, cek peran
/// `MbisApp.of(context)`) TETAP di widget.
class RmTransferState {
  /// Daftar pemindahan untuk `FutureBuilder` layar. Dulu `_future`.
  final Future<List<RmTransfer>>? future;

  // ── Sheet "Buat Pemindahan" (PJD/Admin) ──
  /// Kandidat RM untuk picker. Dulu `_rms`.
  final List<RmCandidate> createRms;

  /// Cabang tujuan untuk picker. Dulu `_branches`.
  final List<OfficeRef> createBranches;

  /// Loading awal sheet (muat kandidat + cabang). Dulu `_loading`.
  final bool createLoading;

  /// Sedang mengirim pembuatan. Dulu `_submitting`.
  final bool createSubmitting;

  /// Error muat awal sheet. Dulu `_error`.
  final String? createError;

  const RmTransferState({
    this.future,
    this.createRms = const [],
    this.createBranches = const [],
    this.createLoading = true,
    this.createSubmitting = false,
    this.createError,
  });

  RmTransferState copyWith({
    Object? future = _keep,
    List<RmCandidate>? createRms,
    List<OfficeRef>? createBranches,
    bool? createLoading,
    bool? createSubmitting,
    Object? createError = _keep,
  }) {
    return RmTransferState(
      future:
          future == _keep ? this.future : future as Future<List<RmTransfer>>?,
      createRms: createRms ?? this.createRms,
      createBranches: createBranches ?? this.createBranches,
      createLoading: createLoading ?? this.createLoading,
      createSubmitting: createSubmitting ?? this.createSubmitting,
      createError:
          createError == _keep ? this.createError : createError as String?,
    );
  }
}

final rmTransferProvider =
    NotifierProvider<RmTransferNotifier, RmTransferState>(
        RmTransferNotifier.new);

/// Menggantikan logika `setState` (DATA/LOADING/SAVING) di `rm_transfer_screen`.
/// Perilaku dipindah APA ADANYA — repository legacy dipakai ulang lewat provider.
class RmTransferNotifier extends Notifier<RmTransferState> {
  @override
  RmTransferState build() => const RmTransferState();

  RmTransferRepository get _repo => ref.read(rmTransferRepoProvider);

  /// Muat / muat ulang daftar pemindahan. Dulu `_reload()`
  /// (`setState(() => _future = _repo!.list())`).
  void reload() {
    state = state.copyWith(future: _repo.list());
  }

  /// Batalkan pemindahan lalu muat ulang daftar. Backend call dari `_cancel`
  /// layar; dialog konfirmasi + snackbar tetap di widget. Error dilempar ulang
  /// implisit agar widget menampilkan snackbar seperti semula.
  Future<void> cancel(String id) async {
    await _repo.cancel(id);
    reload();
  }

  // ── Sheet "Buat Pemindahan" ─────────────────────────────────────────────────

  /// Bootstrap sheet: muat kandidat RM (reuse daftar handover) + daftar cabang.
  /// Dulu `_load()` di `_CreateTransferSheetState`.
  Future<void> startCreate() async {
    state = state.copyWith(
      createRms: const [],
      createBranches: const [],
      createLoading: true,
      createSubmitting: false,
      createError: null,
    );
    try {
      // Reuse the handover candidate list for the RM picker (active RMs in scope).
      final rms = await ref.read(rmHandoverRepoProvider).candidateRms();
      final branches = await _repo.branches();
      state = state.copyWith(
        createRms: rms,
        createBranches: branches,
        createLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        createError: e.toString().replaceFirst('Exception: ', ''),
        createLoading: false,
      );
    }
  }

  /// Kirim pembuatan pemindahan. Melempar ulang error agar widget menampilkan
  /// snackbar + menjaga navigasi (`Navigator.pop`) seperti semula. Bagian
  /// backend dari `_submit()` sheet.
  Future<void> submitCreate({
    required String rmId,
    required String toOfficeId,
    String? reason,
  }) async {
    state = state.copyWith(createSubmitting: true);
    try {
      await _repo.create(
        rmId: rmId,
        toOfficeId: toOfficeId,
        reason: reason,
      );
    } catch (e) {
      state = state.copyWith(createSubmitting: false);
      rethrow;
    }
  }
}
