import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reverse geocoding (coordinate → address) via OpenStreetMap Nominatim.
///
/// Free, no API key, and works on web (Nominatim sends CORS headers). The usage
/// policy asks for a descriptive User-Agent and max ~1 request/second — fine for
/// interactive picking. On web the browser sets its own User-Agent/Referer, which
/// Nominatim also accepts.
/// A single forward-geocoding (address → coordinate) hit.
class GeoSearchResult {
  final double lat;
  final double lng;
  final String label; // full display name

  const GeoSearchResult(this.lat, this.lng, this.label);
}

class GeocodingService {
  /// Forward geocoding: free-text address → candidate coordinates (Nominatim).
  /// Restricted to Indonesia and capped to a handful of results.
  static Future<List<GeoSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?format=jsonv2&q=${Uri.encodeQueryComponent(q)}'
      '&limit=6&addressdetails=0&accept-language=id&countrycodes=id',
    );
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'MBIS-App/1.0 (transformation@askrindo.co.id)',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .map((e) {
                if (e is! Map) return null;
                final lat = double.tryParse(e['lat']?.toString() ?? '');
                final lon = double.tryParse(e['lon']?.toString() ?? '');
                final name = e['display_name']?.toString() ?? '';
                if (lat == null || lon == null || name.isEmpty) return null;
                return GeoSearchResult(lat, lon, name);
              })
              .whereType<GeoSearchResult>()
              .toList();
        }
      }
    } catch (_) {
      // Network/parsing failure → caller shows "tidak ditemukan".
    }
    return const [];
  }

  static Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=0&accept-language=id',
    );
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'MBIS-App/1.0 (transformation@askrindo.co.id)',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final name = data['display_name'];
        if (name is String && name.isNotEmpty) return name;
      }
    } catch (_) {
      // Network/parsing failure → caller keeps coordinates only.
    }
    return null;
  }
}
