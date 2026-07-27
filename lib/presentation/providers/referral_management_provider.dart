import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/referral/referral_repository.dart';

const Object _keep = Object();

/// State layar Manajemen Referral — cerminan 1:1 dari field `setState` di layar
/// lama. Satu-satunya state async yang dulu dikelola `setState` adalah `_future`
/// (sumber `FutureBuilder`); di sini dipindah APA ADANYA.
class ReferralManagementState {
  final Future<List<ReferralPending>>? future;

  const ReferralManagementState({this.future});

  ReferralManagementState copyWith({
    Object? future = _keep,
  }) {
    return ReferralManagementState(
      future: future == _keep
          ? this.future
          : future as Future<List<ReferralPending>>?,
    );
  }
}

final referralManagementProvider =
    NotifierProvider<ReferralManagementNotifier, ReferralManagementState>(
        ReferralManagementNotifier.new);

/// Menggantikan logika `setState` di `_ReferralManagementScreenState`.
/// Perilaku (initial load + refresh daftar pending) DIPINDAH APA ADANYA.
class ReferralManagementNotifier extends Notifier<ReferralManagementState> {
  @override
  ReferralManagementState build() => const ReferralManagementState();

  ReferralRepository get _repo => ref.read(referralRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan
  /// inisialisasi `_future ??= _repo!.getPending()` di `didChangeDependencies`.
  void start() {
    if (state.future == null) {
      state = state.copyWith(future: _repo.getPending());
    }
  }

  /// Muat ulang daftar pending. Sama seperti `_refresh` lama: buat future baru,
  /// simpan ke state, lalu tunggu penyelesaiannya.
  Future<void> refresh() async {
    final f = _repo.getPending();
    state = state.copyWith(future: f);
    await f;
  }
}
