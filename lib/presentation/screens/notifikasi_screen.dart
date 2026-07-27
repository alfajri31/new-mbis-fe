import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/notification/notification_api.dart';
import '../providers/notifikasi_provider.dart';
import '../widgets/state_views.dart';

/// The notification inbox, backed by the server (`/api/notifications`). Every push the
/// backend delivers is also stored here, so this list is the durable history with a
/// server-side unread count. Paged (infinite scroll), pull-to-refresh, tap to mark read.
class NotifikasiScreen extends ConsumerStatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  ConsumerState<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends ConsumerState<NotifikasiScreen> {
  // UI-ephemeral (tetap di widget): scroll controller + listener paging.
  final ScrollController _scroll = ScrollController();

  // State bisnis/async dikelola NotifikasiNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  NotifikasiState get _ns => ref.read(notifikasiProvider);
  NotifikasiNotifier get _notifier => ref.read(notifikasiProvider.notifier);

  List<AppNotification> get _items => _ns.items;
  int get _unreadCount => _ns.unreadCount;
  bool get _loading => _ns.loading;
  bool get _loadingMore => _ns.loadingMore;
  String? get _error => _ns.error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Bootstrap notifier setelah frame pertama (loading flag sudah tampil).
    // Sesi dibaca notifier lewat apiClientProvider — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Aksi data/loading → delegasi ke NotifikasiNotifier (logika dipindah utuh).
  Future<void> _loadFirst() => _notifier.loadFirst();

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _loadMore() => _notifier.loadMore();

  Future<void> _markAllAsRead() => _notifier.markAllRead();

  /// Marks read, then deep-links: agent notifications to the agent detail screen,
  /// commission notifications to the agent's komisi tab, visit/tender reminders to
  /// the pipeline they concern.
  void _openNotification(AppNotification item) {
    _notifier.markOneAsRead(item);
    if (item.refType == 'AGENT' && (item.refId?.isNotEmpty ?? false)) {
      context.push('/agent-detail/${item.refId}');
    } else if (item.refType == 'COMMISSION') {
      context.push('/agent/komisi');
    } else {
      // A tender reminder's refId is the process id, so the pipeline comes from
      // the data map instead.
      final pipelineId = item.data['pipelineId'];
      if (pipelineId != null && pipelineId.isNotEmpty) {
        context.push('/dashboard/pipeline/$pipelineId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(notifikasiProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount belum dibaca',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _unreadCount > 0 ? _markAllAsRead : null,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.navyBg,
                disabledBackgroundColor: AppColors.grayBg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Tandai dibaca',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _unreadCount > 0 ? AppColors.primaryNavy : AppColors.grayStage,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.border,
            height: 1.0,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ErrorStateView(message: _error!, onRetry: _loadFirst);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirst,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyStateView(
              icon: Icons.notifications_none_outlined,
              title: 'Tidak ada notifikasi',
              subtitle: 'Semua pemberitahuan akan muncul di sini.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openNotification(item),
            child: _buildNotifCard(item),
          );
        },
      ),
    );
  }

  Widget _buildNotifCard(AppNotification item) {
    Color configColor;
    Color configBg;
    IconData configIcon;
    String configLabel;

    switch (item.uiCategory) {
      case 'warning':
        configColor = AppColors.secondaryOrange;
        configBg = AppColors.orangeLight;
        configIcon = Icons.warning_amber_rounded;
        configLabel = 'Perhatian';
        break;
      case 'success':
        configColor = AppColors.successGreen;
        configBg = AppColors.greenLight;
        configIcon = Icons.check_circle_outline_rounded;
        configLabel = 'Sukses';
        break;
      case 'error':
        configColor = AppColors.errorRed;
        configBg = AppColors.redLight;
        configIcon = Icons.error_outline_rounded;
        configLabel = 'Peringatan';
        break;
      case 'info':
      default:
        configColor = AppColors.primaryNavy;
        configBg = AppColors.navyBg;
        configIcon = Icons.info_outline_rounded;
        configLabel = 'Info';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: item.read ? AppColors.border : configColor.withValues(alpha: 0.3),
        ),
        boxShadow: const [AppShadows.level1],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: configBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  configIcon,
                  color: configColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: item.read ? FontWeight.w500 : FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.body != null && item.body!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.body!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: configBg,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              configLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: configColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.timeAgo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.grayStage,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!item.read)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: configColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
