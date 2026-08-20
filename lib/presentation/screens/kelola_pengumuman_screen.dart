import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../src/network/api_client.dart';
import '../../src/announcement/announcement_repository.dart';
import '../providers/kelola_pengumuman_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/state_views.dart';
import 'announcement_form_screen.dart';
import '../../src/network/api_error.dart';

/// Kelola Pengumuman — for ADMIN/RO/BM to create, edit and delete announcements
/// shown on the home banner. Scope is enforced server-side: admins see all, a
/// supervisor sees announcements within their office subtree.
class KelolaPengumumanScreen extends ConsumerStatefulWidget {
  const KelolaPengumumanScreen({super.key});

  @override
  ConsumerState<KelolaPengumumanScreen> createState() =>
      _KelolaPengumumanScreenState();
}

class _KelolaPengumumanScreenState
    extends ConsumerState<KelolaPengumumanScreen> {
  // Data/loading daftar dikelola KelolaPengumumanNotifier. Getter berikut
  // memproksinya agar kode build di bawah tetap memakai nama lama tanpa diubah.
  KelolaPengumumanState get _ks => ref.read(kelolaPengumumanProvider);
  KelolaPengumumanNotifier get _notifier =>
      ref.read(kelolaPengumumanProvider.notifier);

  bool get _loading => _ks.loading;
  String? get _error => _ks.error;
  List<Announcement> get _items => _ks.items;

  // Aksi tulis (buat/edit/hapus) tetap di widget → repo/apiClient via provider.
  AnnouncementRepository get _repo => ref.read(announcementRepoProvider);
  ApiClient get _apiClient => ref.read(apiClientProvider);

  // Setelan "berapa banner tampil di beranda". Disimpan server (master data)
  // dan DIPAKSA di endpoint feed, jadi klien lama pun ikut aturan yang sama.
  final _maxBannerCtrl = TextEditingController();
  int? _maxBanner;
  bool _savingMaxBanner = false;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (loader berbasis flag → hindari
    // flash). Sesi dibaca repo dari sessionProvider — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
      _loadBannerSetting();
    });
  }

  @override
  void dispose() {
    _maxBannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBannerSetting() async {
    try {
      final max = await _repo.getMaxBanner();
      if (!mounted) return;
      setState(() {
        _maxBanner = max;
        _maxBannerCtrl.text = '$max';
      });
    } catch (_) {
      // Setelan opsional: daftar pengumuman tetap berguna walau ini gagal dimuat.
    }
  }

  Future<void> _saveBannerSetting() async {
    final value = int.tryParse(_maxBannerCtrl.text.trim());
    if (value == null || value < 1) {
      _snack('Isi angka minimal 1.', isError: true);
      return;
    }
    setState(() => _savingMaxBanner = true);
    try {
      final saved = await _repo.setMaxBanner(value);
      if (!mounted) return;
      setState(() {
        _maxBanner = saved;
        _maxBannerCtrl.text = '$saved';
      });
      _snack('Beranda kini menampilkan maksimal $saved banner.');
    } catch (e) {
      if (!mounted) return;
      _snack(friendlyError(e, fallback: 'Gagal menyimpan setelan banner.'), isError: true);
    } finally {
      if (mounted) setState(() => _savingMaxBanner = false);
    }
  }

  Future<void> _toggleBanner(Announcement a) async {
    try {
      await _repo.setBannerHidden(a.id, !a.bannerHidden);
      if (!mounted) return;
      _snack(a.bannerHidden
          ? '"${a.title}" ditampilkan lagi di banner.'
          : '"${a.title}" disembunyikan dari banner.');
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(friendlyError(e, fallback: 'Gagal mengubah tampilan banner.'), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
    ));
  }

  // Muat ulang daftar → delegasi ke notifier (logika dipindah utuh).
  Future<void> _fetch() => _notifier.reload();

  Future<void> _openForm({Announcement? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnnouncementFormScreen(
          repo: _repo,
          apiClient: _apiClient,
          existing: existing,
        ),
      ),
    );
    if (changed == true) _fetch();
  }

  Future<void> _confirmDelete(Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Hapus pengumuman?'),
        content: Text('"${a.title}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pengumuman dihapus'),
        backgroundColor: AppColors.successGreen,
      ));
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(kelolaPengumumanProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
          title: 'Kelola Pengumuman', showBack: true, contentMaxWidth: double.infinity),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(itemCount: 5);
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 80),
        ErrorStateView(message: _error!, onRetry: _fetch),
      ]);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(children: const [
          SizedBox(height: 120),
          EmptyStateView(
            icon: Icons.campaign_outlined,
            title: 'Belum ada pengumuman',
            subtitle: 'Buat pengumuman untuk ditampilkan di home.',
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      // Cap + centre so the list doesn't stretch edge-to-edge on desktop.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            // +1 baris: kartu setelan banner selalu di paling atas.
            itemCount: _items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                i == 0 ? _bannerSettingCard() : _buildCard(_items[i - 1]),
          ),
        ),
      ),
    );
  }

  /// Setelan "maksimal banner di beranda". Ditaruh di layar ini (bukan di master
  /// data) supaya admin mengaturnya di tempat yang sama dengan isinya.
  Widget _bannerSettingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_carousel_outlined,
                  size: 18, color: AppColors.primaryNavy),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Banner di beranda',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pengumuman terbaru yang aktif akan berputar di beranda. Atur berapa '
            'banyak yang boleh tampil, dan sembunyikan yang tak perlu lewat menu '
            'titik tiga di tiap pengumuman.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                // 90 dp membuat label "Maksimal" terpotong jadi "Maksi…".
                width: 116,
                child: TextField(
                  controller: _maxBannerCtrl,
                  style: AppInput.fieldText,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Maksimal',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bgScreen,
                    border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _maxBanner == null
                      ? 'Memuat setelan…'
                      : 'Sekarang: $_maxBanner banner',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: _savingMaxBanner ? null : _saveBannerSetting,
                child: _savingMaxBanner
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Announcement a) {
    // Satu identitas visual untuk semua pengumuman — tidak dibagi per jenis.
    const color = AppColors.primaryNavy;
    const icon = Icons.campaign_outlined;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                      ),
                      if (!a.active) _statusPill('Nonaktif', AppColors.grayStage),
                      if (a.active && a.bannerHidden)
                        _statusPill('Tak di banner', AppColors.secondaryOrange),
                    ],
                  ),
                  if (a.body != null && a.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(a.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip(a.audienceLabel, AppColors.grayStage),
                      if (a.startsAt != null || a.endsAt != null)
                        _chip(_windowLabel(a), AppColors.grayStage),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.grayStage, size: 20),
              onSelected: (v) {
                if (v == 'edit') _openForm(existing: a);
                if (v == 'banner') _toggleBanner(a);
                if (v == 'delete') _confirmDelete(a);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'banner',
                  child: Text(a.bannerHidden
                      ? 'Tampilkan lagi di banner'
                      : 'Sembunyikan dari banner'),
                ),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus', style: TextStyle(color: AppColors.errorRed))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _statusPill(String text, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );

  String _windowLabel(Announcement a) {
    final start = a.startsAt ?? '…';
    final end = a.endsAt ?? '…';
    return '$start → $end';
  }
}
