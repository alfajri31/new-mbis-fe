import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geocoding_service.dart';

/// State pemilih lokasi — cerminan 1:1 dari field `setState` di layar lama.
/// HANYA state DATA/LOADING async yang pindah ke sini:
///  - [searching]  : flag loading pencarian alamat (forward geocoding).
///  - [results]    : daftar kandidat hasil pencarian alamat.
///  - [geocoding]  : flag loading reverse geocoding (koordinat → alamat).
///
/// Yang TETAP di widget (bukan data async): `MapController`, titik `_selected`
/// (murni interaksi tap/geser peta), flag `_locating` (bagian alur tangkap GPS),
/// serta `TextEditingController` alamat/pencarian. Hasil reverse-geocode
/// dikembalikan oleh [LocationPickerNotifier.reverseGeocode] lalu ditulis ke
/// controller alamat yang dapat diedit bebas oleh pengguna (sumber kebenaran
/// field alamat = controller milik widget), jadi tidak disimpan di state ini.
///
/// Catatan: semua field non-nullable, sehingga sentinel `_keep` untuk `copyWith`
/// tidak diperlukan di sini (tak ada field nullable yang perlu dibedakan dari
/// "tidak diubah"). Lihat `visit_map_provider.dart` untuk pola dengan `_keep`.
class LocationPickerState {
  final bool searching;
  final List<GeoSearchResult> results;
  final bool geocoding;

  const LocationPickerState({
    this.searching = false,
    this.results = const [],
    this.geocoding = false,
  });

  LocationPickerState copyWith({
    bool? searching,
    List<GeoSearchResult>? results,
    bool? geocoding,
  }) {
    return LocationPickerState(
      searching: searching ?? this.searching,
      results: results ?? this.results,
      geocoding: geocoding ?? this.geocoding,
    );
  }
}

final locationPickerProvider =
    NotifierProvider<LocationPickerNotifier, LocationPickerState>(
  LocationPickerNotifier.new,
);

/// Menggantikan bagian `setState` async di `_LocationPickerScreenState`.
/// Logika pencarian & reverse-geocode DIPINDAH APA ADANYA; efek UI (unfocus,
/// snackbar, gerak peta, tulis ke controller) tetap di widget.
class LocationPickerNotifier extends Notifier<LocationPickerState> {
  @override
  LocationPickerState build() => const LocationPickerState();

  /// Pencarian alamat (forward geocoding) → daftar kandidat. Menggantikan bagian
  /// async `_runSearch`. Mengembalikan hasil agar widget menampilkan snackbar
  /// "tidak ditemukan" (butuh context) — perilaku tak berubah.
  Future<List<GeoSearchResult>> runSearch(String query) async {
    state = state.copyWith(searching: true);
    final results = await GeocodingService.search(query);
    state = state.copyWith(results: results, searching: false);
    return results;
  }

  /// Reverse geocoding (koordinat → alamat) di latar. Menggantikan bagian async
  /// `_selectPoint`. Titik terpilih (`_selected`) tetap dikelola widget karena
  /// murni interaksi peta; hasil alamat dikembalikan untuk ditulis ke controller
  /// alamat yang bisa diedit — perilaku tak berubah.
  Future<String?> reverseGeocode(double lat, double lng) async {
    state = state.copyWith(geocoding: true);
    final addr = await GeocodingService.reverseGeocode(lat, lng);
    state = state.copyWith(geocoding: false);
    return addr;
  }

  /// Pengguna memilih satu kandidat: kosongkan daftar hasil & matikan flag
  /// geocoding. (Dulu bagian `setState` di `_pickResult`.)
  void pickResult() {
    state = state.copyWith(results: const [], geocoding: false);
  }

  /// Kosongkan daftar hasil pencarian. (Dulu bagian `setState` tombol "Hapus".)
  void clearResults() {
    state = state.copyWith(results: const []);
  }
}
