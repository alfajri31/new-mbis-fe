import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/src/rm_handover/rm_transfer_repository.dart';

const Object _keep = Object();

/// State layar Alokasi Portofolio (stage 2 pemindahan cabang RM) — cerminan 1:1
/// dari field `setState` DATA/LOADING di layar lama. Yang dipindah ke sini hanya
/// `future` (sumber `FutureBuilder`, dulu `_future`) dan `submitting` (dulu
/// `_submitting`, flag tombol saat mengalokasikan). Pilihan alokasi user
/// (`_defaultRm`, `_overrides`) DITAHAN di widget karena murni edit pengguna.
class RmTransferAllocationState {
  /// Data alokasi (customers + RM tujuan). Dulu `_future`.
  final Future<TransferAllocationView>? future;

  /// Sedang mengeksekusi alokasi & pindah. Dulu `_submitting`.
  final bool submitting;

  const RmTransferAllocationState({
    this.future,
    this.submitting = false,
  });

  RmTransferAllocationState copyWith({
    Object? future = _keep,
    bool? submitting,
  }) {
    return RmTransferAllocationState(
      future: future == _keep
          ? this.future
          : future as Future<TransferAllocationView>?,
      submitting: submitting ?? this.submitting,
    );
  }
}

final rmTransferAllocationProvider =
    NotifierProvider<RmTransferAllocationNotifier, RmTransferAllocationState>(
        RmTransferAllocationNotifier.new);

/// Menggantikan logika `setState` DATA/LOADING di `_RmTransferAllocationScreenState`.
/// Perilaku (muat data alokasi, retry, eksekusi alokasi) DIPINDAH APA ADANYA —
/// migrasi ini hanya memindah TEMPAT state, bukan mengubah perilaku.
///
/// Repo & transfer di-inject dari widget (layar dibangun dengan `repo`/`transfer`
/// eksplisit oleh `rm_transfer_screen`), jadi dipakai ULANG apa adanya lewat
/// [start] — bukan disumber dari `rmTransferRepoProvider` — agar instance repo
/// (dan sesi yang dibawanya) identik dengan sebelum migrasi.
class RmTransferAllocationNotifier extends Notifier<RmTransferAllocationState> {
  late RmTransferRepository _repo;
  late String _transferId;

  @override
  RmTransferAllocationState build() => const RmTransferAllocationState();

  /// Dipanggil sekali per instance layar dari `didChangeDependencies` (sinkron,
  /// sebelum frame pertama → tanpa flash). Menyimpan repo/transfer lalu memulai
  /// pemuatan. Selalu me-reset state penuh agar instance layar baru tak mewarisi
  /// `submitting`/`future` dari transfer sebelumnya. Menggantikan `initState`.
  void start({
    required RmTransferRepository repo,
    required String transferId,
  }) {
    _repo = repo;
    _transferId = transferId;
    state = RmTransferAllocationState(future: _load());
  }

  Future<TransferAllocationView> _load() {
    return _repo.allocationView(_transferId);
  }

  /// Muat ulang data alokasi (tombol "Coba lagi"). Dulu
  /// `setState(() => _future = _load())`.
  void reload() {
    state = state.copyWith(future: _load());
  }

  /// Eksekusi alokasi & pindah RM. Menahan bagian DATA/LOADING dari `_submit`
  /// lama (flag `submitting` + panggilan repo). Snackbar & navigasi DITAHAN di
  /// widget. Melempar ulang error agar widget menampilkan pesannya (sama seperti
  /// blok `catch` lama), setelah membereskan flag `submitting`.
  Future<void> submit({
    required String transferId,
    required String defaultRmId,
    required Map<String, String> overrides,
  }) async {
    state = state.copyWith(submitting: true);
    try {
      await _repo.allocate(
        transferId: transferId,
        defaultRmId: defaultRmId,
        overrides: overrides,
      );
    } catch (_) {
      state = state.copyWith(submitting: false);
      rethrow;
    }
  }
}
