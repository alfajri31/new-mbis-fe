import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../config/map_config.dart';
import 'geocoding_service.dart';
import 'location_picker_provider.dart';
import 'picked_location.dart';

export 'picked_location.dart' show PickedLocation;

/// A real map picker backed by OpenStreetMap (no API key required).
///
/// The user can either detect their current GPS position or tap anywhere on the
/// map to drop a pin. Returns a [PickedLocation] via [Navigator.pop].
class LocationPickerScreen extends ConsumerStatefulWidget {
  final PickedLocation? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  // Default to central Jakarta until we know better.
  static const LatLng _fallbackCenter = LatLng(-6.2088, 106.8456);

  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  // Editable address: pre-filled by reverse geocoding but free-text — the user
  // can correct or replace it before confirming.
  final TextEditingController _addressCtrl = TextEditingController();
  // UI-ephemeral (tetap di widget): titik terpilih & flag tangkap GPS keduanya
  // murni interaksi peta/geolokasi, bukan data async yang dimuat dari layanan.
  LatLng? _selected;
  bool _locating = false;

  // State data/loading async dikelola LocationPickerNotifier. Getter berikut
  // memproksinya agar kode build di bawah tetap memakai nama lama tanpa diubah.
  LocationPickerState get _lps => ref.read(locationPickerProvider);
  LocationPickerNotifier get _notifier =>
      ref.read(locationPickerProvider.notifier);

  bool get _geocoding => _lps.geocoding;
  bool get _searching => _lps.searching;
  List<GeoSearchResult> get _results => _lps.results;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _selected = LatLng(widget.initial!.latitude, widget.initial!.longitude);
      _addressCtrl.text = widget.initial!.address ?? '';
    } else {
      // No starting point → auto-center on the device GPS (best-effort, silent).
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoCenterToGps());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  /// Search an address (forward geocoding) and show the candidate list.
  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    // Loading + hasil pencarian dikelola notifier (logika async dipindah utuh).
    final results = await _notifier.runSearch(q);
    if (!mounted) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat tidak ditemukan')),
      );
    }
  }

  /// Move the pin (and map) to a chosen search result.
  void _pickResult(GeoSearchResult r) {
    final point = LatLng(r.lat, r.lng);
    FocusScope.of(context).unfocus();
    _mapController.move(point, 16);
    // Kosongkan hasil + matikan flag geocoding via notifier; titik terpilih &
    // teks controller (interaksi peta / editable) tetap dikelola widget.
    _notifier.pickResult();
    setState(() {
      _searchCtrl.text = r.label;
      _selected = point;
      _addressCtrl.text = r.label;
    });
  }

  /// Best-effort centering on the current GPS position; stays silent on failure.
  Future<void> _autoCenterToGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    } catch (_) {
      // Silent: user can still tap, search, or press the GPS button.
    }
  }

  /// Sets the pin and resolves its address in the background. The resolved
  /// address only pre-fills the editable field; the user can rewrite it.
  Future<void> _selectPoint(LatLng point) async {
    // Titik terpilih = interaksi peta → tetap di widget. Flag geocoding & panggilan
    // reverse-geocode dipindah ke notifier; hasil alamat ditulis ke controller
    // editable milik widget (sumber kebenaran field alamat).
    setState(() => _selected = point);
    final addr = await _notifier.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    if (addr != null && addr.isNotEmpty) _addressCtrl.text = addr;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError(
          'Layanan lokasi (GPS) tidak aktif. Aktifkan dulu di pengaturan perangkat.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Izin lokasi ditolak. Beri izin lokasi untuk memakai GPS.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      _mapController.move(point, 16);
      await _selectPoint(point);
    } catch (e) {
      _showError('Gagal mengambil lokasi: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat data/loading berubah
    // (menggantikan setState untuk pencarian & geocoding).
    ref.watch(locationPickerProvider);
    final initialCenter = _selected ?? _fallbackCenter;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: _selected != null ? 16 : 12,
              onTap: (_, point) => _selectPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.activeTileUrl,
                userAgentPackageName: 'com.askrindo.mbis.mobile',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.errorRed,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search bar — forward geocoding (type an address → results).
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.radiusMd,
                    boxShadow: const [AppShadows.level1],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.search, size: 18, color: AppColors.primaryNavy),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _runSearch(),
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Cari alamat...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                        ),
                      ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.all(11),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.grayStage),
                          tooltip: 'Hapus',
                          onPressed: () {
                            _searchCtrl.clear();
                            // Kosongkan hasil via notifier → rebuild (sembunyikan
                            // tombol hapus + dropdown), setara setState lama.
                            _notifier.clearResults();
                          },
                        )
                      else
                        const SizedBox(width: 10),
                    ],
                  ),
                ),
                // Search results dropdown.
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.radiusMd,
                      boxShadow: const [AppShadows.level1],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              size: 18, color: AppColors.secondaryOrange),
                          title: Text(r.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          onTap: () => _pickResult(r),
                        );
                      },
                    ),
                  ),
                ],
                // Selected-point address (editable free text) + coordinates.
                if (_selected != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.radiusMd,
                      boxShadow: const [AppShadows.level1],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.location_on_outlined,
                              size: 18, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _addressCtrl,
                                minLines: 1,
                                maxLines: 3,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: _geocoding
                                      ? 'Mengambil alamat...'
                                      : 'Tulis nama alamat (bisa diedit bebas)',
                                  hintStyle: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.normal),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Attribution required by the tile provider's terms of use.
          Positioned(
            bottom: 4,
            left: 6,
            child: Container(
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
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'gps',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryNavy,
              onPressed: _locating ? null : _useCurrentLocation,
              child: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryNavy,
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(
                    PickedLocation(
                      _selected!.latitude,
                      _selected!.longitude,
                      address: _addressCtrl.text.trim().isEmpty
                          ? null
                          : _addressCtrl.text.trim(),
                    ),
                  ),
            child: const Text(
              'Gunakan Lokasi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
