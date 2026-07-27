import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../src/config/map_config.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../providers/visit_map_provider.dart';
import '../widgets/state_views.dart';

/// Supervisory map of customer locations visited by RMs within the caller's
/// scope (KUP/BM/RO/DPJ). Filterable by office (a branch for RO, a region or
/// branch for DPJ). Shows pins + a list; tapping either focuses the location.
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

  void _focus(VisitLocation loc) {
    // Seleksi (state) → notifier; gerakan peta (UI) tetap di widget.
    _notifier.select(loc);
    try {
      _mapController.move(LatLng(loc.latitude, loc.longitude), 15);
    } catch (_) {}
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
      appBar: AppBar(
        title: const Text('Peta Kunjungan'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_offices.isNotEmpty) _buildFilterBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surfaceWhite,
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
    return Column(
      children: [
        Expanded(flex: 3, child: _buildMap()),
        Expanded(flex: 2, child: _buildList()),
      ],
    );
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
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [AppShadows.level1],
            ),
            child: Text(
              '${_locations.length} lokasi dikunjungi',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_locations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Belum ada kunjungan dengan lokasi pada cakupan ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _locations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final loc = _locations[i];
          final selected = loc.visitId == _selectedVisitId;
          return ListTile(
            dense: true,
            selected: selected,
            selectedTileColor: AppColors.navyBg,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.orangeBg,
              child: const Icon(
                Icons.place,
                size: 16,
                color: AppColors.secondaryOrange,
              ),
            ),
            title: Text(
              loc.customerName ?? 'Customer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${loc.rmName ?? '-'}'
              '${loc.officeName != null ? ' • ${loc.officeName}' : ''}'
              '${loc.activityDate != null ? ' • ${AppFormat.dateOnly(loc.activityDate)}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(
              Icons.my_location,
              size: 16,
              color: AppColors.primaryNavy,
            ),
            onTap: () => _focus(loc),
          );
        },
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
