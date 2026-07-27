import 'dart:convert';
import 'package:http/http.dart' as http;

/// Indicative FX reference (currency -> IDR) for auto-filling the pipeline kurs.
///
/// Uses the free, key-less Frankfurter API (ECB reference rates). This is an
/// *indicative* rate, NOT Bank Indonesia's official JISDOR — the kurs field
/// stays editable so the RM can override it. Falls back to null (manual input)
/// on any network/parse failure. Works on web (the API sends CORS headers).
class ExchangeRateService {
  /// Latest rate of 1 [currency] in IDR, or null when unavailable.
  static Future<double?> rateToIdr(String currency) async {
    final cur = currency.toUpperCase();
    if (cur == 'IDR') return 1.0;
    final uri = Uri.parse('https://api.frankfurter.dev/v1/latest?base=$cur&symbols=IDR');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        final idr = rates?['IDR'];
        if (idr is num) return idr.toDouble();
      }
    } catch (_) {
      // Network/parse failure → caller keeps manual kurs entry.
    }
    return null;
  }
}
