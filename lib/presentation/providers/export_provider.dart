import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';

const Object _keep = Object();

/// State layar "Ekspor Data" — cerminan 1:1 dari field `setState` yang bersifat
/// backend/async di layar lama. Filter/rentang tanggal pilihan user TETAP di
/// widget; hanya opsi ter-load server + flag ekspor yang pindah ke sini.
class ExportState {
  /// Peran supervisor (RO/BM/KUP/ADMIN/DPJ) → menampilkan kartu filter + memicu
  /// muat opsi wilayah/cabang/RM. Dulu `_isSupervisor`.
  final bool isSupervisor;

  /// Opsi scope (wilayah/cabang) dari `/api/dashboard/scope-offices`. Dulu `_offices`.
  final List<ScopeOffice> offices;

  /// Dataset yang sedang diekspor ('pipelines' | 'visits'); null = idle. Dulu
  /// `_busyDataset`.
  final String? busyDataset;

  const ExportState({
    this.isSupervisor = false,
    this.offices = const [],
    this.busyDataset,
  });

  ExportState copyWith({
    bool? isSupervisor,
    List<ScopeOffice>? offices,
    Object? busyDataset = _keep,
  }) {
    return ExportState(
      isSupervisor: isSupervisor ?? this.isSupervisor,
      offices: offices ?? this.offices,
      busyDataset:
          busyDataset == _keep ? this.busyDataset : busyDataset as String?,
    );
  }
}

final exportProvider =
    NotifierProvider<ExportNotifier, ExportState>(ExportNotifier.new);

/// Memindahkan logika `setState` backend/async dari `_ExportScreenState`:
/// deteksi supervisor (dari sesi), muat opsi scope, dan flag "sedang ekspor".
/// Perilaku dipindah APA ADANYA — pemilihan filter & simpan file tetap di layar.
class ExportNotifier extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  DashboardRepository get _dashRepo => ref.read(dashboardRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Set peran supervisor
  /// dari sesi, lalu muat opsi scope bila supervisor. Menggantikan isi callback
  /// post-frame di `initState` lama.
  void start() {
    final session = ref.read(sessionProvider);
    final roles = session?.user.roles ?? const <String>[];
    final isSupervisor = roles.contains('RO') ||
        roles.contains('BM') ||
        roles.contains('KUP') ||
        roles.contains('ADMIN') ||
        roles.contains('DPJ');
    state = state.copyWith(isSupervisor: isSupervisor);
    if (isSupervisor) _loadScopeOffices();
  }

  Future<void> _loadScopeOffices() async {
    try {
      final offices = await _dashRepo.getScopeOffices();
      state = state.copyWith(offices: offices);
    } catch (_) {
      // Filter optional; ignore failures.
    }
  }

  /// Mulai ekspor: set flag busy (sinkron) + jalankan unduhan berlingkup di
  /// server. Bytes/nama file dikembalikan ke layar untuk disimpan; error dilempar
  /// balik agar layar menampilkannya. Flag di-reset layar via [doneExport] setelah
  /// simpan file — menjaga timing lama (busy tetap true sampai unduhan selesai).
  Future<({List<int> bytes, String fileName})> download(
    String dataset, {
    required DateTime from,
    required DateTime to,
    String? regionId,
    String? branchId,
    String? rmId,
  }) {
    state = state.copyWith(busyDataset: dataset);
    return ref.read(exportRepoProvider).downloadScoped(
          dataset,
          from,
          to,
          regionId: regionId,
          branchId: branchId,
          rmId: rmId,
        );
  }

  /// Reset flag ekspor. Dipanggil di `finally` layar (setelah simpan file &
  /// snackbar), menggantikan `setState(() => _busyDataset = null)`.
  void doneExport() => state = state.copyWith(busyDataset: null);
}
