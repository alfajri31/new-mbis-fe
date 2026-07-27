import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/admin/policy_repository.dart';

const Object _keep = Object();

/// State layar "Kelola Premi & Komisi" — hanya bagian DATA/LOADING daftar polis.
/// Cerminan field `_future` yang dulu di-`setState` di `_KelolaPremiScreenState`.
///
/// Filter UI (kata kunci pencarian + chip status) TETAP di widget: keduanya
/// murni client-side (`_applyFilters`) dan tak menyentuh backend, sesuai aturan
/// "hanya daftar + loading backend yang pindah".
class KelolaPremiState {
  /// Future daftar polis yang dikonsumsi `FutureBuilder` di layar. Di-set saat
  /// load awal (dari `didChangeDependencies`) dan tiap `reload`. Dulu `_future`.
  final Future<List<AdminPolicyModel>>? future;

  const KelolaPremiState({this.future});

  KelolaPremiState copyWith({Object? future = _keep}) {
    return KelolaPremiState(
      future: future == _keep
          ? this.future
          : future as Future<List<AdminPolicyModel>>?,
    );
  }
}

final kelolaPremiProvider =
    NotifierProvider<KelolaPremiNotifier, KelolaPremiState>(
      KelolaPremiNotifier.new,
    );

/// Memindahkan logika load daftar polis (`_repo.getPolicies()`) dari
/// `_KelolaPremiScreenState`. Repository legacy `AdminPolicyRepository` dipakai
/// ULANG apa adanya lewat [adminPolicyRepoProvider] — yang membawa sesi aktif
/// via `apiClientProvider`, setara dengan konstruksi lama
/// `AdminPolicyRepository(apiClient: ApiClient(session: MbisApp.of(context)?.session))`.
class KelolaPremiNotifier extends Notifier<KelolaPremiState> {
  @override
  KelolaPremiState build() => const KelolaPremiState();

  AdminPolicyRepository get _repo => ref.read(adminPolicyRepoProvider);

  /// Memulai load awal daftar polis. Dipanggil dari `didChangeDependencies`
  /// layar (loader ber-`FutureBuilder`, pemicu tetap di widget agar tak ada
  /// flash error). Idempotensi "sekali per kunjungan" dijaga flag di widget —
  /// meniru `_future ??= _repo.getPolicies()` yang lama.
  void start() {
    state = state.copyWith(future: _repo.getPolicies());
  }

  /// Muat ulang daftar polis. Dulu `_reload()`
  /// (`setState(() => _future = _repo!.getPolicies())`).
  void reload() {
    state = state.copyWith(future: _repo.getPolicies());
  }
}
