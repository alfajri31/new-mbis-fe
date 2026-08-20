import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../src/config/map_config.dart';
import '../../src/app.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../../src/nav.dart';
import '../../src/network/api_client.dart';
import '../../src/network/auth_image.dart';
import '../providers/visit_map_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/kpi_drilldown_sheet.dart';
import '../widgets/state_views.dart';

/// Supervisory map of customer locations visited by RMs within the caller's
/// scope (KUP/BM/RO/DPJ). Filterable by office (a branch for RO, a region or
/// branch for DPJ).
///
/// Inilah layar berjudul "Peta Kunjungan" yang dimaksud CR-10 — bukan
/// `gps_tracking_screen.dart` yang berjudul "GPS Tracking Kunjungan". Sebelum
/// CR-10 petanya hanya menempati 3/5 layar dengan daftar di bawahnya, dan
/// menekan pin HANYA menggeser-memperbesar peta: tidak ada ringkasan, tidak ada
/// jalan ke customer-nya. Sekarang peta memenuhi layar, pin membuka ringkasan
/// berikut tautan ke halaman customer, dan daftarnya pindah ke bottom banner
/// lewat tombol di bilah judul (menekan barisnya tetap memusatkan peta ke pin
/// itu, seperti perilaku lama).
class VisitMapScreen extends ConsumerStatefulWidget {
  const VisitMapScreen({super.key});

  @override
  ConsumerState<VisitMapScreen> createState() => _VisitMapScreenState();
}

class _VisitMapScreenState extends ConsumerState<VisitMapScreen> {
  static const LatLng _fallbackCenter = LatLng(-6.2088, 106.8456); // Jakarta

  // UI-ephemeral (tetap di widget): controller peta.
  final MapController _mapController = MapController();

  // State data/loading dikelola VisitMapNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  VisitMapState get _vms => ref.read(visitMapProvider);
  VisitMapNotifier get _notifier => ref.read(visitMapProvider.notifier);

  bool get _loading => _vms.loading;
  String? get _error => _vms.error;
  List<VisitLocation> get _locations => _vms.locations;
  List<ScopeOffice> get _offices => _vms.offices;
  String? get _officeFilter => _vms.officeFilter;
  String? get _selectedVisitId => _vms.selectedVisitId;
  VisitTrackingSummary? get _summary => _vms.summary;

  // ApiClient dipakai AuthImage untuk thumbnail foto kunjungan di popup pin —
  // bawaan dari layar GPS Tracking yang dilebur ke sini.
  ApiClient? _apiClient;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiClient ??= ApiClient(session: MbisApp.of(context)?.session);
  }

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Sesi
    // dibawa `dashboardRepoProvider` (via sessionProvider) — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  // Aksi data/loading → delegasi ke VisitMapNotifier (logika dipindah utuh).
  Future<void> _fetchLocations() => _notifier.fetchLocations();

  /// Pusatkan peta ke lokasi pertama — efek UI (butuh MapController) tetap di
  /// widget. Dipicu reaktif dari build() saat daftar `_locations` berubah.
  void _fitToLocations() {
    if (_locations.isEmpty) return;
    final first = _locations.first;
    // Center on the first location; a full bounds-fit needs a post-layout pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(LatLng(first.latitude, first.longitude), 11);
      } catch (_) {}
    });
  }

  /// Pilih satu kunjungan: ringkasannya muncul di bawah DAN peta dipusatkan ke
  /// pin itu.
  ///
  /// Zoom sengaja TIDAK dipaksa ke 15 lagi. Dulu setiap ketukan pin melompatkan
  /// zoom, dan karena tak ada ringkasan yang muncul, satu-satunya efek yang
  /// terlihat pemakai adalah peta membesar sendiri — persis keluhan yang memicu
  /// CR-10. Sekarang tingkat zoom pemakai dihormati; yang berubah cuma titik
  /// tengahnya.
  void _focus(VisitLocation loc) {
    // Seleksi (state) → notifier; gerakan peta (UI) tetap di widget.
    _notifier.select(loc);
    try {
      _mapController.move(
        LatLng(loc.latitude, loc.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {}
  }

  /// Pin → halaman customer (CR-10). `go`, bukan `push`, mengikuti idiom layar
  /// lain yang menautkan ke customer (Broker/BUMN): lokasi berpindah ke tab
  /// Customer sehingga URL-nya utuh dan tombol kembali mendarat di daftar
  /// customer. Seleksi dibersihkan dulu karena state-nya hidup di notifier —
  /// tanpa itu ringkasan lama sudah terbuka lagi saat peta dibuka berikutnya.
  void _openCustomer(String customerId) {
    _notifier.clearSelection();
    context.go('/customer/$customerId');
  }

  /// Daftar kunjungan, kini sebagai bottom banner (peta memakai seluruh layar).
  /// Menekan baris memusatkan peta ke pin-nya — perilaku daftar yang lama —
  /// lalu ringkasannya muncul, dan dari situ ada tautan ke halaman customer.
  void _openListSheet() {
    showKpiDrilldownSheet(
      context,
      title: 'Kunjungan pada cakupan ini',
      subtitle: 'Tekan satu baris untuk memusatkan petanya',
      emptyMessage: 'Belum ada kunjungan dengan lokasi pada cakupan ini.',
      rows: [
        for (final loc in _locations)
          KpiDrilldownRow(
            title: loc.customerName ?? 'Customer',
            subtitle: '${loc.rmName ?? '-'}'
                '${loc.officeName != null ? ' • ${loc.officeName}' : ''}'
                '${loc.activityDate != null ? ' • ${AppFormat.dateOnly(loc.activityDate)}' : ''}',
            onTap: () => _focus(loc),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(visitMapProvider);
    // Pemusatan peta dulu dipanggil di ujung `_fetchLocations`; kini reaktif —
    // tiap `locations` di-load ulang (instance baru) map difit ke lokasi pertama.
    ref.listen<VisitMapState>(visitMapProvider, (prev, next) {
      if (!identical(prev?.locations, next.locations)) {
        _fitToLocations();
      }
    });
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      // Peta memenuhi layar, termasuk di belakang bilah judul (CR-10).
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Peta Kunjungan',
        // Peta memenuhi layar (Positioned.fill) dan kartu melayangnya menempel di
        // left/right 12, jadi tidak ada kolom konten yang di-cap. Tanpa baris ini judul
        // dihitung terhadap cap responsif 1200/1440/1800 dan melayang jauh ke tengah.
        contentMaxWidth: double.infinity,
        // Peta memenuhi layar (Positioned.fill) dan kartu melayangnya menempel di
        // left/right 12, jadi tidak ada kolom konten yang di-cap. Tanpa baris ini judul
        // dihitung terhadap cap responsif 1200/1440/1800 dan melayang jauh ke tengah.
        // safePop, bukan Navigator.pop bawaan: layar ini bisa dibuka langsung
        // lewat URL di web, dan di situ tak ada apa pun untuk di-pop.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => safePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined,
                color: AppColors.textPrimary),
            tooltip: 'Daftar kunjungan',
            onPressed: _openListSheet,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      // Kartu melayang, bukan pita selebar layar: peta di belakangnya tetap terlihat.
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _officeFilter,
                hint: const Text(
                  'Semua cakupan',
                  style: TextStyle(fontSize: 13),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Semua cakupan',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  ..._offices.map(
                    (o) => DropdownMenuItem<String?>(
                      value: o.id,
                      child: Text(
                        '${_typeLabel(o.type)} • ${o.name}',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => _notifier.onFilterChanged(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          ErrorStateView(message: _error!, onRetry: _fetchLocations),
        ],
      );
    }
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final selected = _selectedLocation;
    return Stack(
      children: [
        // Peta seluas layar; penyaring kantor & jumlah lokasi melayang di atasnya
        // alih-alih memakan pita tersendiri seperti sebelumnya.
        Positioned.fill(child: _buildMap()),
        Positioned(
          left: 12,
          right: 12,
          top: topInset + 8,
          child: Column(
            children: [
              // Penyaring kantor hanya ada untuk penyelia: `getScopeOffices`
              // mengembalikan daftar kosong untuk RM, jadi kartunya hilang sendiri
              // tanpa perlu pengecekan peran di layar.
              if (_offices.isNotEmpty) _buildFilterBar(),
              if (_offices.isNotEmpty) const SizedBox(height: 8),
              _buildStatsCard(),
            ],
          ),
        ),
        if (_locations.isEmpty)
          Positioned(
            left: 24,
            right: 24,
            top: topInset + 108,
            child: _buildEmptyNotice(),
          ),
        if (selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSelectedCard(selected),
          ),
      ],
    );
  }

  /// Kunjungan terpilih, dicari dari id yang disimpan notifier. Dicari ulang tiap
  /// build (bukan disimpan sebagai objek) supaya pemuatan ulang daftar tidak
  /// meninggalkan ringkasan yang menunjuk baris yang sudah tidak ada.
  VisitLocation? get _selectedLocation {
    final id = _selectedVisitId;
    if (id == null) return null;
    for (final loc in _locations) {
      if (loc.visitId == id) return loc;
    }
    return null;
  }

  Widget _buildMap() {
    final center = _locations.isNotEmpty
        ? LatLng(_locations.first.latitude, _locations.first.longitude)
        : _fallbackCenter;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: _locations.isNotEmpty ? 11 : 5,
          ),
          children: [
            TileLayer(
              urlTemplate: MapConfig.activeTileUrl,
              fallbackUrl: MapConfig.osmUrl,
              userAgentPackageName: 'com.askrindo.mbis.mobile',
              retinaMode: RetinaMode.isHighDensity(context),
            ),
            MarkerLayer(
              markers: _locations.map((loc) {
                final selected = loc.visitId == _selectedVisitId;
                return Marker(
                  point: LatLng(loc.latitude, loc.longitude),
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _focus(loc),
                    child: Icon(
                      Icons.location_on,
                      color: selected
                          ? AppColors.primaryNavy
                          : AppColors.errorRed,
                      size: selected ? 46 : 36,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  /// Kartu statistik melayang — bawaan layar GPS Tracking yang dilebur ke sini.
  ///
  /// "Dengan Titik GPS" sengaja diambil dari panjang daftar, bukan dihitung ulang
  /// di server: itu persis jumlah pin yang tergambar, jadi angka dan peta mustahil
  /// bertentangan. "Total Visit" datang dari endpoint ringkasan karena kunjungan
  /// tanpa koordinat memang tidak pernah sampai ke klien.
  Widget _buildStatsCard() {
    final s = _summary;
    String n(int? v) => v?.toString() ?? '–';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Row(
        children: [
          _stat(n(s?.totalVisits), 'Total Visit'),
          _stat(n(s?.thisMonth), 'Visit Bulan Ini'),
          _stat('${_locations.length}', 'Dengan Titik GPS'),
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
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Peta kosong tanpa keterangan bikin pemakai mengira fiturnya rusak — maka
  /// dua keadaan yang sama-sama berpeta kosong dibedakan di sini: belum ada
  /// kunjungan sama sekali, atau ada tapi tak satu pun menyimpan koordinat.
  Widget _buildEmptyNotice() {
    final total = _summary?.totalVisits ?? 0;
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
                  total == 0
                      ? 'Belum ada kunjungan tercatat pada cakupan ini.'
                      : '$total kunjungan tercatat, tapi tidak ada yang '
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

  /// Ringkasan kunjungan yang pin-nya baru ditekan, berikut tautan ke halaman
  /// customer (CR-10). Sebelum ini menekan pin sama sekali tidak memunculkan apa
  /// pun — hanya menggeser peta.
  Widget _buildSelectedCard(VisitLocation loc) {
    final customerId = loc.customerId;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
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
                      loc.customerName ?? 'Customer',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${loc.rmName ?? '-'}'
                      '${loc.officeName != null ? ' • ${loc.officeName}' : ''}'
                      '${loc.activityDate != null ? ' • ${AppFormat.dateOnly(loc.activityDate)}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (loc.customerAddress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        loc.customerAddress!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
                tooltip: 'Tutup',
                onPressed: _notifier.clearSelection,
              ),
            ],
          ),
          // Bukti kunjungan: foto (bila ada) + koordinatnya. Ini isi popup layar
          // GPS Tracking yang dilebur ke sini; tanpa keduanya RM kehilangan cara
          // memverifikasi kunjungan dari peta.
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: loc.hasPhoto && _apiClient != null
                      ? ClipRRect(
                          borderRadius: AppRadius.radiusMd,
                          child: AuthImage(
                            apiClient: _apiClient!,
                            path: loc.photoUrl!,
                            height: 72,
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
                                  fontSize: 11, color: AppColors.grayStage),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _badge(Icons.navigation, 'GPS Verified',
                          AppColors.successGreen, AppColors.greenLight),
                      const SizedBox(height: 8),
                      _badge(
                        Icons.location_on,
                        '${loc.latitude.toStringAsFixed(5)}, '
                            '${loc.longitude.toStringAsFixed(5)}',
                        AppColors.primaryNavy,
                        AppColors.navyBg,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tautan disembunyikan — bukan dimatikan — bila kunjungan tak membawa
          // id customer: tombol mati tanpa sebab yang terlihat hanya bikin
          // pemakai menekannya berulang kali.
          if (customerId != null && customerId.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _openCustomer(customerId),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  backgroundColor: AppColors.navyBg,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape:
                      RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text(
                  'Buka halaman customer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
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
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'REGIONAL':
        return 'Wilayah';
      case 'BRANCH':
        return 'Cabang';
      case 'KUP':
        return 'KUP';
      default:
        return type;
    }
  }
}
