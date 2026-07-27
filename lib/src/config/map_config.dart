/// Map provider configuration.
///
/// Uses plain OpenStreetMap raster tiles — free, no API key, and no signup.
/// Nothing to configure or forward via --dart-define.
class MapConfig {
  /// OpenStreetMap tiles (no key required).
  static const String osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// The tile URL to actually use.
  static String get activeTileUrl => osmUrl;

  static String get attribution => '© OpenStreetMap';
}
