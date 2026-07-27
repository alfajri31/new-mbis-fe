import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/agent/agent_repository.dart';
import 'package:mbis/src/master_data/master_data_repository.dart';

/// State layar "Komisi" (Ajukan Komisi) — cerminan 1:1 dari field async yang
/// dulu dikelola `setState` di `_AjukanKomisiScreenState`:
///  - [future]      : komisi siap dicairkan (feed FutureBuilder). Dulu `_future`.
///  - [fintrackUrl] : link portal Fintrack (admin-editable via master parameter
///                    FINTRACK_URL); fallback konstan bila belum di-set. Dulu
///                    `_fintrackUrl`.
///
/// Controller UI (navigasi, snackbar, launchUrl) TETAP di widget — hanya data
/// backend + trigger loadnya yang dipindah ke sini.
class AjukanKomisiState {
  final Future<List<CommissionModel>>? future;
  final String fintrackUrl;

  const AjukanKomisiState({
    this.future,
    this.fintrackUrl = AjukanKomisiNotifier.fintrackUrlFallback,
  });

  AjukanKomisiState copyWith({
    Future<List<CommissionModel>>? future,
    String? fintrackUrl,
  }) {
    return AjukanKomisiState(
      // `future` hanya pernah null→value (tak pernah dikembalikan ke null),
      // jadi `??` cukup untuk menjaga nilai lama saat hanya URL yang berubah.
      future: future ?? this.future,
      fintrackUrl: fintrackUrl ?? this.fintrackUrl,
    );
  }
}

final ajukanKomisiProvider =
    NotifierProvider<AjukanKomisiNotifier, AjukanKomisiState>(
        AjukanKomisiNotifier.new);

/// Menggantikan logika `setState` async di `_AjukanKomisiScreenState`.
/// Perilaku (muat komisi, reload, muat URL Fintrack + fallback) DIPINDAH APA
/// ADANYA. Sesi dibawa `apiClientProvider` lewat repo provider — jadi tak perlu
/// membangun `ApiClient` dari context seperti versi lama.
class AjukanKomisiNotifier extends Notifier<AjukanKomisiState> {
  /// Fallback dipakai hanya bila admin belum men-set parameter FINTRACK_URL.
  /// Nilai nyata admin-editable di Kelola Master Data (kategori FINTRACK_URL).
  static const String fintrackUrlFallback = 'https://fintrack.askrindo.co.id';

  @override
  AjukanKomisiState build() => const AjukanKomisiState();

  AgentRepository get _repo => ref.read(agentRepoProvider);
  MasterDataRepository get _masterRepo => ref.read(masterDataRepoProvider);

  /// Dipanggil sekali dari `didChangeDependencies` layar (sebelum build pertama,
  /// menyamakan timing lama & menghindari kedip 1-frame FutureBuilder). Memuat
  /// komisi + URL Fintrack. Menggantikan blok `if (_repo == null)` lama.
  void start() {
    state = state.copyWith(future: _repo.getMyCommissions());
    _loadFintrackUrl();
  }

  /// Muat ulang daftar komisi (retry / pull-to-refresh). Dulu `_reload()`.
  void reload() {
    state = state.copyWith(future: _repo.getMyCommissions());
  }

  /// Link portal pencairan bersifat admin-configurable (master parameter
  /// FINTRACK_URL). Jatuh ke konstanta bila belum di-set / gagal dimuat.
  Future<void> _loadFintrackUrl() async {
    try {
      final rows = await _masterRepo.getParameters(category: 'FINTRACK_URL');
      final url = rows
          .map((p) => p.paramValue.trim())
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
      if (url.isNotEmpty) {
        state = state.copyWith(fintrackUrl: url);
      }
    } catch (_) {
      /* keep the fallback */
    }
  }
}
