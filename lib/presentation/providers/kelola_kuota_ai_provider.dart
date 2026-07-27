import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/admin/account_repository.dart';
import 'package:mbis/src/assistant/ai_usage_admin_repository.dart';

const Object _keep = Object();

/// State layar Kelola Kuota AI (ADMIN) — cerminan 1:1 dari field `setState` di
/// `_KelolaKuotaAiScreenState`. Hanya data/loading/list yang dipindah; input
/// edit (dialog ubah batas) & bottom sheet pemakaian tetap di widget.
class KelolaKuotaAiState {
  final bool ready;
  final bool loading;
  final String? error;
  final List<AccountModel> all;
  final AiLimit? limit;
  final String query;

  const KelolaKuotaAiState({
    this.ready = false,
    this.loading = true,
    this.error,
    this.all = const [],
    this.limit,
    this.query = '',
  });

  KelolaKuotaAiState copyWith({
    bool? ready,
    bool? loading,
    Object? error = _keep,
    List<AccountModel>? all,
    Object? limit = _keep,
    String? query,
  }) {
    return KelolaKuotaAiState(
      ready: ready ?? this.ready,
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      all: all ?? this.all,
      limit: limit == _keep ? this.limit : limit as AiLimit?,
      query: query ?? this.query,
    );
  }

  /// Daftar tersaring dari [query] — derivasi murni, menggantikan getter
  /// `_filtered` di layar lama.
  List<AccountModel> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            a.nip.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q))
        .toList();
  }
}

final kelolaKuotaAiProvider =
    NotifierProvider<KelolaKuotaAiNotifier, KelolaKuotaAiState>(
        KelolaKuotaAiNotifier.new);

/// Menggantikan logika `setState` (data/loading/list) di `_KelolaKuotaAiScreenState`.
/// Perilaku dipindah APA ADANYA. Aksi tulis (ubah batas) tetap di widget dan
/// mendorong hasilnya lewat [applyLimit]; bottom sheet pemakaian tak tersentuh.
class KelolaKuotaAiNotifier extends Notifier<KelolaKuotaAiState> {
  @override
  KelolaKuotaAiState build() => const KelolaKuotaAiState();

  AccountRepository get _accounts => ref.read(accountRepoProvider);
  AiUsageAdminRepository get _usage => ref.read(aiUsageAdminRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Repo kini dari provider
  /// (dulu dibuat dari `MbisApp.of(context)?.session`). Menggantikan `initState`.
  void start() {
    state = state.copyWith(ready: true);
    reload();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _accounts.getAccounts();
      // RMs run the assistant; surface them first, then everyone else, alphabetical.
      list.sort((a, b) {
        final ar = a.roles.contains('RM') ? 0 : 1;
        final br = b.roles.contains('RM') ? 0 : 1;
        return ar != br ? ar - br : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      AiLimit? limit;
      try {
        limit = await _usage.getLimit();
      } catch (_) {
        // Non-fatal: the user list still works if the limit read fails.
      }
      state = state.copyWith(all: list, limit: limit, loading: false);
    } catch (e) {
      state = state.copyWith(error: '$e', loading: false);
    }
  }

  /// Filter pencarian (dulu `setState(() => _query = v)` di layar).
  void onQueryChanged(String value) {
    state = state.copyWith(query: value);
  }

  /// Hasil aksi tulis "ubah batas" (dijalankan di widget) didorong ke state,
  /// menggantikan `setState(() => _limit = updated)`.
  void applyLimit(AiLimit updated) {
    state = state.copyWith(limit: updated);
  }
}
