import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/common/file_opener.dart';

/// State layar "Ekspor Kunjungan Saya" — hanya flag async `exporting` (dulu
/// `_busy` di `_ExportMyVisitsScreenState`). Rentang tanggal pilihan tetap di
/// widget (UI-ephemeral), sesuai aturan migrasi.
class ExportMyVisitsState {
  final bool exporting;

  const ExportMyVisitsState({this.exporting = false});

  ExportMyVisitsState copyWith({bool? exporting}) =>
      ExportMyVisitsState(exporting: exporting ?? this.exporting);
}

/// Hasil ekspor untuk snackbar layar (pesan + apakah error). Snackbar tetap di
/// widget (butuh BuildContext); notifier hanya mengelola flag `exporting` +
/// kerja async. Pesan & kondisi error DIPINDAH APA ADANYA dari `_download` lama.
class ExportMyVisitsResult {
  final String message;
  final bool error;

  const ExportMyVisitsResult(this.message, {this.error = false});
}

final exportMyVisitsProvider =
    NotifierProvider<ExportMyVisitsNotifier, ExportMyVisitsState>(
        ExportMyVisitsNotifier.new);

/// Menggantikan `setState(() => _busy = ...)` di `_ExportMyVisitsScreenState`.
/// Perilaku unduh (repo → bytes → downloadBytes → pesan) DIPINDAH APA ADANYA.
class ExportMyVisitsNotifier extends Notifier<ExportMyVisitsState> {
  @override
  ExportMyVisitsState build() => const ExportMyVisitsState();

  Future<ExportMyVisitsResult> download(DateTime from, DateTime to) async {
    state = state.copyWith(exporting: true);
    final repo = ref.read(exportRepoProvider);
    try {
      final f = await repo.downloadMyVisits(from, to);
      final ok = await downloadBytes(
          f.bytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          f.fileName);
      return ok
          ? ExportMyVisitsResult(
              'Data kunjungan berhasil diekspor (${f.fileName})')
          : const ExportMyVisitsResult(
              'Unduhan tidak didukung di perangkat ini',
              error: true);
    } catch (e) {
      return ExportMyVisitsResult(
          e.toString().replaceAll('Exception: ', ''),
          error: true);
    } finally {
      state = state.copyWith(exporting: false);
    }
  }
}
