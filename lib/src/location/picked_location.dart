/// Result returned by the location picker: a plain lat/lng pair plus an
/// optional reverse-geocoded address.
///
/// Deliberately kept in its own lightweight file that imports NO map packages
/// (flutter_map / latlong2). Screens that open the picker reference this type,
/// so if it lived alongside the picker they'd drag the heavy map library into
/// the initial bundle. Isolating it here lets those screens `deferred`-import
/// the picker screen (loaded on demand) while still naming its result type.
class PickedLocation {
  final double latitude;
  final double longitude;
  final String? address; // reverse-geocoded full address, if resolved

  const PickedLocation(this.latitude, this.longitude, {this.address});

  /// Short human-readable coordinate label, e.g. "-6.21150, 106.82240".
  String get label =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
