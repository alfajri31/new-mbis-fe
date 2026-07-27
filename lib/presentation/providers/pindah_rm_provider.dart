import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/rm_handover/rm_handover_repository.dart';

/// Sentinel untuk membedakan "tak diubah" dari "set ke null" pada field nullable.
const Object _keep = Object();

/// State ASYNC (data/loading/hasil) layar Pindah RM (S-130) — HANYA yang dimuat
/// dari backend atau berupa status muat/simpan. Pilihan form interaktif (RM asal/
/// pengganti, tipe, cakupan, checkbox customer, controller alasan/catatan) TETAP
/// di widget, tidak dipindah ke sini.
///
/// Yang dipindah: daftar kandidat RM, preview portofolio (hasil server), flag
/// muat preview, flag simpan (submit), serta id riwayat yang sedang di-revert.
class PindahRmState {
  final List<RmCandidate> candidates;
  final RmTransferPreview? preview;
  final bool loadingPreview;
  final bool submitting;
  final String? reverting; // id handover yang sedang dikembalikan (tab riwayat)

  const PindahRmState({
    this.candidates = const [],
    this.preview,
    this.loadingPreview = false,
    this.submitting = false,
    this.reverting,
  });

  PindahRmState copyWith({
    List<RmCandidate>? candidates,
    Object? preview = _keep,
    bool? loadingPreview,
    bool? submitting,
    Object? reverting = _keep,
  }) {
    return PindahRmState(
      candidates: candidates ?? this.candidates,
      preview: preview == _keep ? this.preview : preview as RmTransferPreview?,
      loadingPreview: loadingPreview ?? this.loadingPreview,
      submitting: submitting ?? this.submitting,
      reverting: reverting == _keep ? this.reverting : reverting as String?,
    );
  }
}

final pindahRmProvider =
    NotifierProvider<PindahRmNotifier, PindahRmState>(PindahRmNotifier.new);

/// Memindahkan logika `setState` ASYNC dari `pindah_rm_screen.dart` (dua tab:
/// form pemindahan + riwayat). Logika tiap metode DIPINDAH APA ADANYA; repository
/// legacy dipakai ulang via `rmHandoverRepoProvider`.
///
/// Loader berbasis `FutureBuilder` (kandidat RM di tab 1, riwayat di tab 2) tetap
/// dipicu di widget (initState/refresh) lewat [loadCandidates]/[listHistory] agar
/// tak ada kedip 1-frame; notifier menyimpan hasil/loading yang dibaca ulang widget.
class PindahRmNotifier extends Notifier<PindahRmState> {
  @override
  PindahRmState build() => const PindahRmState();

  RmHandoverRepository get _repo => ref.read(rmHandoverRepoProvider);

  // ── Tab 1: form pemindahan ─────────────────────────────────────────────────

  /// Dipicu FutureBuilder di initState. Muat kandidat RM + simpan ke state,
  /// kembalikan daftar untuk FutureBuilder. (Dulu `_loadCandidates`.)
  Future<List<RmCandidate>> loadCandidates() async {
    final list = await _repo.candidateRms();
    state = state.copyWith(candidates: list);
    return list;
  }

  /// Bagian ASYNC dari `_onFromChanged`: kosongkan preview lama (selalu), lalu
  /// muat preview portofolio RM asal bila ada. Error dilempar ke widget (snack).
  Future<void> onFromChanged(RmCandidate? rm) async {
    state = state.copyWith(preview: null);
    if (rm == null) return;
    state = state.copyWith(loadingPreview: true);
    try {
      final preview = await _repo.preview(rm.id);
      state = state.copyWith(preview: preview);
    } finally {
      state = state.copyWith(loadingPreview: false);
    }
  }

  /// Kosongkan preview saat form di-reset setelah submit sukses. (Bagian dari
  /// `_reset` lama; pilihan user lain di-reset di widget.)
  void resetPreview() => state = state.copyWith(preview: null);

  /// Eksekusi pemindahan. Set flag `submitting`, panggil repo, kembalikan hasil
  /// (dipakai widget untuk pesan snack). Error dilempar ke widget.
  Future<RmHandover> execute({
    required String fromRmId,
    required String toRmId,
    required String type,
    required String scope,
    required List<String> customerIds,
    String? reason,
    String? note,
  }) async {
    state = state.copyWith(submitting: true);
    try {
      return await _repo.execute(
        fromRmId: fromRmId,
        toRmId: toRmId,
        type: type,
        scope: scope,
        customerIds: customerIds,
        reason: reason,
        note: note,
      );
    } finally {
      state = state.copyWith(submitting: false);
    }
  }

  // ── Tab 2: riwayat ─────────────────────────────────────────────────────────

  /// Dipicu FutureBuilder di initState/refresh. (Dulu `widget.repo.list()`.)
  Future<List<RmHandover>> listHistory() => _repo.list();

  /// Kembalikan sebuah pemindahan. Set id `reverting` selama proses; error
  /// dilempar ke widget (snack). (Bagian async dari `_revert`.)
  Future<void> revert(String id) async {
    state = state.copyWith(reverting: id);
    try {
      await _repo.revert(id);
    } finally {
      state = state.copyWith(reverting: null);
    }
  }
}
