import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/src/notification/notification_api.dart';

const Object _keep = Object();

/// State inbox notifikasi — cerminan 1:1 dari field `setState` di layar lama
/// (`_NotifikasiScreenState`). Paging (infinite scroll), pull-to-refresh, dan
/// unread count sisi-server DIPINDAH APA ADANYA.
class NotifikasiState {
  final List<AppNotification> items;
  final int unreadCount;
  final int page;
  final bool last;
  final bool loading;
  final bool loadingMore;
  final String? error;

  const NotifikasiState({
    this.items = const [],
    this.unreadCount = 0,
    this.page = 0,
    this.last = false,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  NotifikasiState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    int? page,
    bool? last,
    bool? loading,
    bool? loadingMore,
    Object? error = _keep,
  }) {
    return NotifikasiState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      page: page ?? this.page,
      last: last ?? this.last,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error == _keep ? this.error : error as String?,
    );
  }
}

final notifikasiProvider =
    NotifierProvider<NotifikasiNotifier, NotifikasiState>(
        NotifikasiNotifier.new);

/// Menggantikan seluruh logika `setState` di `_NotifikasiScreenState`.
/// Perilaku (paging, mark-read optimistik, guard mounted→lifecycle notifier)
/// DIPINDAH APA ADANYA. Instance [NotificationApi] dibangun dari
/// [apiClientProvider] (dulu `NotificationApi(ApiClient(session: ...))`).
class NotifikasiNotifier extends Notifier<NotifikasiState> {
  @override
  NotifikasiState build() => const NotifikasiState();

  NotificationApi get _api => NotificationApi(ref.read(apiClientProvider));

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan
  /// `initState` yang langsung memanggil `_loadFirst()`.
  void start() {
    loadFirst();
  }

  Future<void> loadFirst() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _api.list(page: 0, size: 20);
      state = state.copyWith(
        items: page.content,
        page: page.page,
        last: page.last,
        unreadCount: page.unreadCount,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Gagal memuat notifikasi',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.last || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.list(page: state.page + 1, size: 20);
      state = state.copyWith(
        items: [...state.items, ...page.content],
        page: page.page,
        last: page.last,
        unreadCount: page.unreadCount,
      );
    } catch (_) {
      // Keep what we have; the next scroll retries.
    } finally {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> markAllRead() async {
    final hadUnread = state.unreadCount > 0;
    state = state.copyWith(
      items: [
        for (final n in state.items) n.read ? n : _copyRead(n),
      ],
      unreadCount: 0,
    );
    if (hadUnread) {
      try {
        await _api.markAllRead();
      } catch (_) {}
    }
  }

  Future<void> markOneAsRead(AppNotification item) async {
    if (item.read) return;
    final idx = state.items.indexWhere((n) => n.id == item.id);
    if (idx < 0) return;
    final newItems = List<AppNotification>.from(state.items);
    newItems[idx] = _copyRead(item);
    state = state.copyWith(
      items: newItems,
      unreadCount: state.unreadCount > 0
          ? state.unreadCount - 1
          : state.unreadCount,
    );
    try {
      await _api.markRead(item.id);
    } catch (_) {}
  }

  AppNotification _copyRead(AppNotification n) => AppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        refType: n.refType,
        refId: n.refId,
        read: true,
        createdAt: n.createdAt,
      );
}
