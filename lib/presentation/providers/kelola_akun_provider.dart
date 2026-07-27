import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/admin/account_repository.dart';

const Object _keep = Object();

/// State layar Kelola Akun — cerminan 1:1 dari field `setState` DATA/LOADING di
/// layar lama (`_KelolaAkunScreenState`). Filter pencarian (`_query`) TIDAK di
/// sini: itu murni UI client-side dan tetap dipegang widget.
class KelolaAkunState {
  final bool loading;
  final String? error;
  final List<AccountModel> accounts;
  final List<OfficeOption> offices;
  final String? currentUserId;

  const KelolaAkunState({
    this.loading = true,
    this.error,
    this.accounts = const [],
    this.offices = const [],
    this.currentUserId,
  });

  KelolaAkunState copyWith({
    bool? loading,
    Object? error = _keep,
    List<AccountModel>? accounts,
    List<OfficeOption>? offices,
    Object? currentUserId = _keep,
  }) {
    return KelolaAkunState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      accounts: accounts ?? this.accounts,
      offices: offices ?? this.offices,
      currentUserId:
          currentUserId == _keep ? this.currentUserId : currentUserId as String?,
    );
  }
}

final kelolaAkunProvider =
    NotifierProvider<KelolaAkunNotifier, KelolaAkunState>(
        KelolaAkunNotifier.new);

/// Menggantikan logika `setState` DATA/LOADING di `_KelolaAkunScreenState`.
/// Perilaku (offices non-kritis, mapping error) DIPINDAH APA ADANYA.
class KelolaAkunNotifier extends Notifier<KelolaAkunState> {
  @override
  KelolaAkunState build() => const KelolaAkunState();

  AccountRepository get _repo => ref.read(accountRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Ambil id user aktif
  /// (dulu dari `MbisApp.of(context).session` di `didChangeDependencies`; kini
  /// dari `sessionProvider`) lalu muat daftar. Menggantikan init `didChangeDependencies`.
  void start() {
    final session = ref.read(sessionProvider);
    state = state.copyWith(currentUserId: session?.user.id);
    fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final accounts = await _repo.getAccounts();
      // Offices are non-critical (only the form's dropdown needs them).
      List<OfficeOption> offices = const [];
      try {
        offices = await _repo.getOffices();
      } catch (_) {}
      state = state.copyWith(
        accounts: accounts,
        offices: offices,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}
