import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../network/api_client.dart';
import '../network/auth_image.dart';
import 'announcement_repository.dart';

/// Auto-sliding banner of announcements shown at the top of the home screen.
///
/// Renders nothing when there are no announcements, so the home layout collapses
/// cleanly. Tapping a banner opens a sheet with the full text.
///
/// The banner is full-bleed (edge-to-edge rectangle) and the page indicator dots
/// float over its lower edge. Semua pengumuman memakai satu tampilan yang sama —
/// tidak ada pembagian jenis/kategori (dulu Apresiasi vs Kebijakan).
///
/// Layar yang menumpuk kartu utamanya di atas banner (mis. beranda Agen) harus
/// memakai posisi layout NYATA (Stack + padding), bukan `Transform.translate`:
/// dengan transform, sentuhan pada bagian kartu yang naik tetap jatuh ke banner.
class AnnouncementBanner extends StatefulWidget {
  final ApiClient apiClient;
  final List<Announcement> announcements;

  /// Height of the full-bleed banner area.
  final double height;

  /// Distance of the page-indicator dots from the banner's bottom edge. When a
  /// screen pulls its main card over the banner, keep this above the overlap so
  /// the dots stay visible.
  final double dotsBottomInset;

  const AnnouncementBanner({
    super.key,
    required this.apiClient,
    required this.announcements,
    this.height = 158,
    this.dotsBottomInset = 10,
  });

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant AnnouncementBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart the timer if the set of announcements changed (e.g. after a refresh).
    if (oldWidget.announcements.length != widget.announcements.length) {
      _page = 0;
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (widget.announcements.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.announcements.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.announcements;
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _BannerCard(
                apiClient: widget.apiClient,
                announcement: items[i],
                onTap: () => _showDetail(context, items[i]),
              ),
            ),
          ),
          if (items.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.dotsBottomInset,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < items.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Announcement a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnnouncementDetailSheet(apiClient: widget.apiClient, announcement: a),
    );
  }
}

/// Warna gradien banner. Pengumuman tidak dibagi per jenis/kategori, jadi semua
/// banner memakai satu identitas visual. Steel blue — lebih terang dari top bar
/// navy beranda, supaya banner tetap terbaca sebagai pita terpisah.
const Color _bannerColor = Color(0xFF2A5C90);
const Color _bannerColorDark = Color(0xFF17416F);

class _BannerCard extends StatelessWidget {
  final ApiClient apiClient;
  final Announcement announcement;
  final VoidCallback onTap;

  const _BannerCard({
    required this.apiClient,
    required this.announcement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = announcement.imageUrl != null;
    return GestureDetector(
      onTap: onTap,
      child: hasImage ? _imageBanner(context) : _gradientBanner(context),
    );
  }

  /// Batasi lebar isi banner ke lebar konten (latar tetap full-bleed) supaya
  /// teks pengumuman sejajar dengan konten dashboard di layar lebar.
  Widget _cappedContent(BuildContext context, Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.isWide(context)
              ? Responsive.contentMaxWidthFor(context)
              : double.infinity,
        ),
        child: child,
      ),
    );
  }

  /// No image: full gradient with the content on top.
  Widget _gradientBanner(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bannerColor, _bannerColorDark],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _cappedContent(
        context,
        Padding(
          // Padding-Y disamakan dengan X (16); sedikit ekstra bawah untuk dots.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: _contentChildren(),
          ),
        ),
      ),
    );
  }

  /// With image: the photo fills the banner (dimmed so it reads as a background)
  /// and the content sits in a frosted "glass" card near the bottom.
  Widget _imageBanner(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AuthImage(
          apiClient: apiClient,
          path: announcement.imageUrl!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
        // Dim the photo so it recedes to a background rather than the focal point.
        Container(color: Colors.black.withValues(alpha: 0.3)),
        Align(
          alignment: Alignment.topCenter,
          child: _cappedContent(
            context,
            Padding(
            // Sit the glass card in the upper area: the home card overlaps the
            // banner's bottom edge, so a bottom-aligned card would collide with it.
            padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
            child: ClipRRect(
              borderRadius: AppRadius.radiusLg,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _contentChildren(),
                  ),
                ),
              ),
            ),
          ),
          ),
        ),
      ],
    );
  }

  /// Title + body (white text) — shared by both banner variants. Tanpa badge
  /// jenis/kategori: pengumuman tampil sebagai satu jenis saja.
  List<Widget> _contentChildren() {
    return [
      Text(
        announcement.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      if (announcement.body != null && announcement.body!.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          announcement.body!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.3,
          ),
        ),
      ],
    ];
  }
}

class _AnnouncementDetailSheet extends StatelessWidget {
  final ApiClient apiClient;
  final Announcement announcement;

  const _AnnouncementDetailSheet({required this.apiClient, required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grayStage.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              announcement.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (announcement.createdByName != null) announcement.createdByName!,
                announcement.audienceLabel,
              ].join(' • '),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (announcement.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: AppRadius.radiusLg,
                child: AuthImage(
                  apiClient: apiClient,
                  path: announcement.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (announcement.body != null && announcement.body!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                announcement.body!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
