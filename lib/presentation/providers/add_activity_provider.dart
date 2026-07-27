import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';

const Object _keep = Object();

/// State async layar "Tambah Aktivitas".
///
/// Ini FORM, jadi HANYA state data-loading/penyimpanan yang dipindah ke
/// notifier — sisanya (controller teks, validator, toggle, GPS/foto picker,
/// date/time picker, flag error follow-up) tetap di widget karena diedit user.
/// Yang pindah: flag `saving` (proses simpan ke backend) + pesan `error` hasil
/// simpan. Perilaku (validasi, snackbar, navigasi) tetap dipegang widget.
class AddActivityState {
  final bool saving;
  final String? error;

  const AddActivityState({this.saving = false, this.error});

  AddActivityState copyWith({bool? saving, Object? error = _keep}) {
    return AddActivityState(
      saving: saving ?? this.saving,
      error: error == _keep ? this.error : error as String?,
    );
  }
}

final addActivityProvider =
    NotifierProvider<AddActivityNotifier, AddActivityState>(
      AddActivityNotifier.new,
    );

/// Mengelola HANYA logika async simpan aktivitas (dulu bagian `_handleSubmit`
/// yang menyetel `_saving` + memanggil repo). Validasi form, penyusunan payload
/// (termasuk `followupIso` dari tanggal/jam), snackbar, dan navigasi tetap di
/// widget — di sini hanya panggilan jaringan + flag/hasil simpan.
class AddActivityNotifier extends Notifier<AddActivityState> {
  @override
  AddActivityState build() => const AddActivityState();

  /// Kirim aktivitas ke backend. Mengembalikan `true` bila sukses (widget lalu
  /// menampilkan snackbar sukses + pop), `false` bila gagal (widget membaca
  /// [AddActivityState.error] untuk pesan snackbar). `saving` selalu direset di
  /// `finally`, termasuk saat sukses: state notifier ini keepAlive dan hidup
  /// lebih lama dari layar, jadi flag yang tertinggal akan membuat tombol Simpan
  /// pada pembukaan layar berikutnya macet loading + nonaktif.
  Future<bool> submit({
    required String pipelineId,
    required String type,
    required String notes,
    String? nextFollowupDate,
    String? actionPlan,
    String? gpsLatitude,
    String? gpsLongitude,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    state = state.copyWith(saving: true, error: null);
    final repo = ref.read(visitRepoProvider);
    try {
      await repo.createVisit(
        pipelineId: pipelineId,
        type: type,
        // Rencana tindak lanjut is no longer folded in here — it goes to the
        // schedule's action plan instead, which is also the column the Excel
        // export reads (it had always come out blank).
        notes: notes,
        nextFollowupDate: nextFollowupDate,
        actionPlan: actionPlan,
        gpsLatitude: gpsLatitude,
        gpsLongitude: gpsLongitude,
        photoBytes: photoBytes,
        photoName: photoName,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(saving: false);
    }
  }
}
