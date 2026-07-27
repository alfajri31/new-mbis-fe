import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/admin/account_repository.dart';

const Object _keep = Object();

/// State layar Permintaan SSO (kelola SSO) — cerminan 1:1 dari field `setState`
/// di layar lama. State async yang dulu dikelola `setState` adalah daftar
/// pending Entra + flag loading/error; di sini dipindah APA ADANYA.
class KelolaSsoState {
  final bool loading;
  final String? error;
  final List<EntraPendingModel> pending;

  const KelolaSsoState({
    this.loading = true,
    this.error,
    this.pending = const [],
  });

  KelolaSsoState copyWith({
    bool? loading,
    Object? error = _keep,
    List<EntraPendingModel>? pending,
  }) {
    return KelolaSsoState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      pending: pending ?? this.pending,
    );
  }
}

final kelolaSsoProvider =
    NotifierProvider<KelolaSsoNotifier, KelolaSsoState>(KelolaSsoNotifier.new);

/// Menggantikan logika `setState` di `_KelolaSsoScreenState`. Perilaku
/// (initial load + refresh daftar pending Entra) DIPINDAH APA ADANYA.
/// Repository legacy `AccountRepository` dipakai ulang lewat provider.
class KelolaSsoNotifier extends Notifier<KelolaSsoState> {
  @override
  KelolaSsoState build() => const KelolaSsoState();

  AccountRepository get _repo => ref.read(accountRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan
  /// inisialisasi `_repo == null → _fetch()` di `didChangeDependencies`.
  void start() {
    fetch();
  }

  /// Muat/segarkan daftar pending. Sama seperti `_fetch` lama: tandai loading,
  /// bersihkan error, ambil data, lalu simpan hasil (atau error).
  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final pending = await _repo.getEntraPending();
      state = state.copyWith(pending: pending, loading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}
