import 'dart:convert';
import '../network/api_client.dart';

/// Satu opsi wilayah (provinsi/kota/kecamatan/kelurahan) dari proxy backend
/// `/api/regions/*`. Mirror `RegionOption` di backend ({id, name}).
class RegionOption {
  final String id;
  final String name;

  const RegionOption({required this.id, required this.name});

  factory RegionOption.fromJson(Map<String, dynamic> j) => RegionOption(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) => other is RegionOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Wilayah Indonesia untuk dropdown alamat berjenjang. Backend mem-proxy API
/// publik & meng-cache-nya (lihat RegionController). Kalau sumber down, list bisa
/// kosong — pemanggil menampilkannya sebagai dropdown kosong, bukan error fatal.
class RegionRepository {
  final ApiClient apiClient;

  RegionRepository({required this.apiClient});

  Future<List<RegionOption>> provinces() => _list('/api/regions/provinces');

  Future<List<RegionOption>> regencies(String provinceId) =>
      _list('/api/regions/regencies?provinceId=${Uri.encodeQueryComponent(provinceId)}');

  Future<List<RegionOption>> districts(String regencyId) =>
      _list('/api/regions/districts?regencyId=${Uri.encodeQueryComponent(regencyId)}');

  Future<List<RegionOption>> villages(String districtId) =>
      _list('/api/regions/villages?districtId=${Uri.encodeQueryComponent(districtId)}');

  /// Kodepos by nama kelurahan (+ kecamatan/kota untuk disambiguasi). Null bila
  /// tak ketemu / sumber tak tersedia — pemanggil biarkan field kodepos manual.
  Future<String?> postalCode(String village, {String? district, String? regency}) async {
    final q = <String, String>{
      'village': village,
      if (district != null && district.isNotEmpty) 'district': district,
      if (regency != null && regency.isNotEmpty) 'regency': regency,
    };
    final query =
        q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final res = await apiClient.get('/api/regions/postal-code?$query');
    if (res.statusCode == 200) {
      final Map<String, dynamic> j = jsonDecode(res.body);
      final code = j['postalCode'];
      return (code == null || code.toString().isEmpty) ? null : code.toString();
    }
    return null;
  }

  Future<List<RegionOption>> _list(String path) async {
    final res = await apiClient.get(path);
    if (res.statusCode == 200) {
      final List<dynamic> j = jsonDecode(res.body);
      return j.map((e) => RegionOption.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Gagal memuat data wilayah');
  }
}
