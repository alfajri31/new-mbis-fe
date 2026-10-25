import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/admin/export_repository.dart';
import 'package:mbis/src/common/file_opener.dart';

const Object _keep = Object();

/// State konsol "Ekspor Data" — cerminan flag async `setState` di layar lama.
/// Pilihan rentang tanggal (dari/sampai) TETAP di widget karena murni UI yang
/// di-toggle pengguna; hanya flag "sedang mengunduh" yang dipindah ke sini.
class ExportDataState {
  /// Dataset key yang sedang diunduh (null = idle); mengunci semua tombol
  /// supaya tidak ada unduhan ganda. (Dulu `_busyDataset` di layar.)
  final String? busyDataset;

  const ExportDataState({this.busyDataset});

  ExportDataState copyWith({Object? busyDataset = _keep}) {
    return ExportDataState(
      busyDataset:
          busyDataset == _keep ? this.busyDataset : busyDataset as String?,
    );
  }
}

/// Hasil satu unduhan, dikembalikan ke layar untuk snackbar (butuh context,
/// jadi tetap ditampilkan widget). Mempertahankan tiga cabang pesan lama:
/// tersimpan / tak didukung perangkat / gagal.
class ExportOutcome {
  final bool ok;
  final String? fileName;
  final bool unsupported;
  final String? error;

  const ExportOutcome.saved(this.fileName)
      : ok = true,
        unsupported = false,
        error = null;

  const ExportOutcome.unsupported()
      : ok = false,
        fileName = null,
        unsupported = true,
        error = null;

  const ExportOutcome.failed(this.error)
      : ok = false,
        fileName = null,
        unsupported = false;
}

final exportDataProvider =
    NotifierProvider<ExportDataNotifier, ExportDataState>(
        ExportDataNotifier.new);

/// Menggantikan flag `setState` async di `_ExportDataScreenState`. Logika unduh
/// (kunci UI → panggil repo → simpan bytes → lepas kunci) DIPINDAH APA ADANYA.
class ExportDataNotifier extends Notifier<ExportDataState> {
  @override
  ExportDataState build() => const ExportDataState();

  ExportRepository get _repo => ref.read(exportRepoProvider);

  /// Unduh satu dataset untuk rentang [from]..[to] (inklusif). Mengunci UI via
  /// [ExportDataState.busyDataset] selama proses; hasilnya dikembalikan ke layar
  /// (snackbar butuh context). Dulu `_download` di layar.
  Future<ExportOutcome> download(
    String key,
    DateTime from,
    DateTime to, {
    String? regionId,
    String? branchId,
  }) async {
    state = state.copyWith(busyDataset: key);
    try {
      final hasOfficeFilter = (regionId != null && regionId.isNotEmpty) ||
          (branchId != null && branchId.isNotEmpty);
      final f = hasOfficeFilter
          ? await _repo.downloadScoped(key, from, to,
              regionId: regionId, branchId: branchId)
          : await _repo.download(key, from, to);
      final ok = await downloadBytes(
          f.bytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          f.fileName);
      return ok
          ? ExportOutcome.saved(f.fileName)
          : const ExportOutcome.unsupported();
    } catch (e) {
      return ExportOutcome.failed(e.toString().replaceAll('Exception: ', ''));
    } finally {
      state = state.copyWith(busyDataset: null);
    }
  }
}
