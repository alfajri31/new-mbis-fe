import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/announcement/announcement_repository.dart';

const Object _keep = Object();

/// State layar Kelola Pengumuman — cerminan 1:1 dari field `setState` di layar
/// lama (`_loading`, `_error`, `_items`). Perilaku (muat daftar + guard error)
/// DIPINDAH APA ADANYA; instansiasi repo/apiClient kini lewat provider.
class KelolaPengumumanState {
  final bool loading;
  final String? error;
  final List<Announcement> items;

  const KelolaPengumumanState({
    this.loading = true,
    this.error,
    this.items = const [],
  });

  KelolaPengumumanState copyWith({
    bool? loading,
    Object? error = _keep,
    List<Announcement>? items,
  }) {
    return KelolaPengumumanState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      items: items ?? this.items,
    );
  }
}

final kelolaPengumumanProvider =
    NotifierProvider<KelolaPengumumanNotifier, KelolaPengumumanState>(
        KelolaPengumumanNotifier.new);

/// Menggantikan logika `setState` di `_KelolaPengumumanScreenState`.
/// Hanya DATA/LOADING daftar yang dipindah; aksi tulis (buat/edit/hapus),
/// navigasi, snackbar, dan controller tetap di widget.
class KelolaPengumumanNotifier extends Notifier<KelolaPengumumanState> {
  @override
  KelolaPengumumanState build() => const KelolaPengumumanState();

  AnnouncementRepository get _repo => ref.read(announcementRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan pemuatan
  /// awal yang dulu dipicu `didChangeDependencies` (guard `_repo == null`).
  void start() {
    _fetch();
  }

  /// Muat ulang daftar pengumuman. Dipindah APA ADANYA dari `_fetch` layar lama
  /// (dipakai untuk muat awal, retry, refresh, dan setelah aksi tulis).
  Future<void> _fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.list();
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  /// Alias publik untuk memicu muat ulang dari widget (retry/refresh/pasca-tulis).
  Future<void> reload() => _fetch();
}
