import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/network/auth_image.dart';
import '../../src/visit/visit_repository.dart';
import '../../src/config/map_config.dart';
import '../providers/gps_tracking_provider.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/state_views.dart';

/// S-108 — GPS Tracking Kunjungan.
///
/// Real visits for the current RM (from `/api/visits/me`) plotted on an
/// OpenStreetMap map. Only visits with GPS coordinates get a marker;
/// all visits still count in the stats row.
class GpsTrackingScreen extends ConsumerStatefulWidget {
  const GpsTrackingScreen({super.key});

  @override
  ConsumerState<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends ConsumerState<GpsTrackingScreen> {
  static const LatLng _fallbackCenter = LatLng(-6.2088, 106.8456); // Jakarta

  // UI-ephemeral (tetap di widget): ApiClient dipakai `AuthImage` thumbnail di
  // popup pin. Dibuat dari sesi via `MbisApp.of(context)`.
  ApiClient? _apiClient;

  // State data/loading & seleksi pin dikelola GpsTrackingNotifier. Getter berikut
  // memproksinya agar seluruh kode build/widget di bawah tetap memakai nama lama.
  GpsTrackingNotifier get _notifier => ref.read(gpsTrackingProvider.notifier);
  Future<List<VisitModel>>? get _future => ref.read(gpsTrackingProvider).future;
  VisitModel? get _selected => ref.read(gpsTrackingProvider).selected;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (memuat `/api/visits/me`). Sesi
    // dibaca notifier dari apiClientProvider — tak perlu context di sini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiClient ??= ApiClient(session: MbisApp.of(context)?.session);
  }

  Future<void> _refresh() => _notifier.refresh();

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(gpsTrackingProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'GPS Tracking Kunjungan'),
      body: FutureBuilder<List<VisitModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              message: 'Gagal memuat data kunjungan',
              onRetry: _refresh,
            );
          }
          final visits = snapshot.data ?? const <VisitModel>[];
          final gpsVisits = visits
              .where((v) => v.lat != null && v.lng != null)
              .toList();

          return Column(
            children: [
              _buildStatsRow(visits, gpsVisits.length),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildMap(gpsVisits)),
                    // Peta kosong tanpa penjelasan bikin user mengira fiturnya
                    // rusak. Katakan apa adanya: belum ada kunjungan yang
                    // menyimpan titik GPS, dan apa penyebab tersering.
                    if (gpsVisits.isEmpty)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        child: _buildNoPinNotice(visits.length),
                      ),
                    if (_selected != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildPinPopup(_selected!),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(List<VisitModel> visits, int withGps) {
    final now = DateTime.now();
    int thisMonth = 0;
    for (final v in visits) {
      final d = v.activityDate != null
          ? DateTime.tryParse(v.activityDate!)
          : null;
      if (d != null && d.year == now.year && d.month == now.month) thisMonth++;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _stat('${visits.length}', 'Total Visit'),
          _stat('$thisMonth', 'Visit Bulan Ini'),
          // Menggantikan "Dengan Foto": yang menentukan ada-tidaknya pin adalah
          // koordinat, jadi angka inilah yang menjawab "kenapa peta kosong".
          _stat('$withGps', 'Dengan Titik GPS'),
        ],
      ),
    );
  }

  /// Penjelasan saat tak ada satu pun kunjungan berkoordinat.
  Widget _buildNoPinNotice(int totalVisits) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_off_outlined,
              size: 20, color: AppColors.secondaryOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Belum ada kunjungan dengan titik GPS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalVisits == 0
                      ? 'Belum ada kunjungan tercatat.'
                      : '$totalVisits kunjungan tercatat, tapi tidak ada yang '
                          'menyimpan koordinat. Saat mencatat kunjungan, tekan '
                          '"Ambil Lokasi" dan izinkan akses lokasi.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<VisitModel> gpsVisits) {
    final points = [
      for (final v in gpsVisits) LatLng(v.lat!, v.lng!),
    ];
    final center = points.isNotEmpty ? points.first : _fallbackCenter;
    // Satu titik: zoom rapat supaya tempatnya jelas. Banyak titik: rangkum
    // semuanya dalam layar — sebelumnya peta hanya terpusat di kunjungan
    // terbaru, jadi pin lain bisa berada di luar layar dan terlihat "hilang".
    final fit = points.length > 1
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(48),
            maxZoom: 15,
          )
        : null;

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: points.isEmpty ? 11 : 15,
        initialCameraFit: fit,
        onTap: (_, _) => _notifier.clearSelection(),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.activeTileUrl,
          userAgentPackageName: 'com.askrindo.mbis.mobile',
          retinaMode: RetinaMode.isHighDensity(context),
        ),
        MarkerLayer(
          markers: [
            for (final v in gpsVisits)
              Marker(
                point: LatLng(v.lat!, v.lng!),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _notifier.select(v),
                  child: Icon(
                    Icons.location_on,
                    size: 40,
                    color: _selected?.id == v.id
                        ? AppColors.secondaryOrange
                        : AppColors.primaryNavy,
                  ),
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: Colors.white70,
            child: Text(
              MapConfig.attribution,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final t = iso.replaceFirst('T', ' ');
    return t.length >= 16 ? t.substring(0, 16) : t;
  }

  Widget _buildPinPopup(VisitModel v) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.customerName ?? 'Kunjungan',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.grayStage,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(v.activityDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => _notifier.clearSelection(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo thumbnail (real, authenticated) or placeholder
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: v.hasPhoto
                      ? ClipRRect(
                          borderRadius: AppRadius.radiusMd,
                          child: AuthImage(
                            apiClient: _apiClient!,
                            path: v.photoUrl!,
                            height: 80,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.bgScreen,
                            borderRadius: AppRadius.radiusMd,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'Tanpa foto',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.grayStage,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _badge(
                      Icons.navigation,
                      'GPS Verified',
                      AppColors.successGreen,
                      AppColors.greenLight,
                    ),
                    const SizedBox(height: 8),
                    _badge(
                      Icons.location_on,
                      '${v.gpsLatitude}, ${v.gpsLongitude}',
                      AppColors.primaryNavy,
                      AppColors.navyBg,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.radiusSm),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
