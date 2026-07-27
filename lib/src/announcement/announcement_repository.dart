import 'dart:convert';
import '../network/api_client.dart';

/// A home-banner announcement (pengumuman).
class Announcement {
  final String id;
  final String title;
  final String? body;
  final String type; // POLICY | RECOGNITION

  /// Kategori bebas-ketik (huruf besar), terpisah dari [type]. Null bila tak diisi.
  final String? category;
  final String? imageUrl; // /api/files/... or null
  final bool national;
  final String? officeId;
  final String? officeName;
  final bool active;

  /// Disembunyikan dari banner beranda (tetap tampil di daftar & Notifikasi).
  final bool bannerHidden;
  final String? startsAt; // yyyy-MM-dd
  final String? endsAt;
  final String? createdBy;
  final String? createdByName;
  final String? createdAt;

  Announcement({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    this.category,
    this.imageUrl,
    required this.national,
    this.officeId,
    this.officeName,
    required this.active,
    this.bannerHidden = false,
    this.startsAt,
    this.endsAt,
    this.createdBy,
    this.createdByName,
    this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        title: j['title']?.toString() ?? '-',
        body: j['body'] as String?,
        type: j['type']?.toString() ?? 'POLICY',
        category: j['category'] as String?,
        imageUrl: j['imageUrl'] as String?,
        national: (j['national'] ?? false) as bool,
        officeId: j['officeId'] as String?,
        officeName: j['officeName'] as String?,
        active: (j['active'] ?? true) as bool,
        bannerHidden: (j['bannerHidden'] ?? false) as bool,
        startsAt: j['startsAt'] as String?,
        endsAt: j['endsAt'] as String?,
        createdBy: j['createdBy'] as String?,
        createdByName: j['createdByName'] as String?,
        createdAt: j['createdAt'] as String?,
      );

  bool get isRecognition => type == 'RECOGNITION';

  /// Human label for the announcement type.
  String get typeLabel => isRecognition ? 'Apresiasi' : 'Kebijakan';

  /// Who can see this — for the management list.
  String get audienceLabel =>
      national ? 'Nasional' : (officeName ?? 'Kantor');
}

/// API access for the Pengumuman (announcement) feature. The feed is reachable by
/// any authenticated user; management endpoints require ADMIN/RO/BM.
class AnnouncementRepository {
  final ApiClient apiClient;

  AnnouncementRepository({required this.apiClient});

  /// Banner feed for the current user (national + announcements covering their office).
  Future<List<Announcement>> feed() async {
    final res = await apiClient.get('/api/announcements/feed');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => Announcement.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat pengumuman'));
  }

  /// Management list within the caller's scope.
  Future<List<Announcement>> list() async {
    final res = await apiClient.get('/api/announcements');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => Announcement.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat daftar pengumuman'));
  }

  Future<Announcement> create({
    required String title,
    String? body,
    required String type, // POLICY | RECOGNITION
    String? category,
    bool active = true,
    String? startsAt,
    String? endsAt,
  }) async {
    final res = await apiClient.post('/api/announcements', body: {
      'title': title,
      'body': body,
      'type': type,
      'category': category,
      'active': active,
      'startsAt': startsAt,
      'endsAt': endsAt,
    });
    if (res.statusCode == 200) {
      return Announcement.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal membuat pengumuman'));
  }

  Future<Announcement> update(
    String id, {
    required String title,
    String? body,
    required String type,
    String? category,
    required bool active,
    String? startsAt,
    String? endsAt,
  }) async {
    final res = await apiClient.put('/api/announcements/$id', body: {
      'title': title,
      'body': body,
      'type': type,
      // '' (bukan null) berarti hapus kategori; null berarti biarkan apa adanya.
      'category': category,
      'active': active,
      'startsAt': startsAt,
      'endsAt': endsAt,
    });
    if (res.statusCode == 200) {
      return Announcement.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal memperbarui pengumuman'));
  }

  Future<void> uploadImage(String id, List<int> bytes, String fileName) async {
    final res = await apiClient.postMultipart(
      '/api/announcements/$id/image',
      fileField: 'file',
      fileBytes: bytes,
      fileName: fileName,
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_message(res.body, 'Gagal mengunggah gambar'));
    }
  }

  Future<void> delete(String id) async {
    final res = await apiClient.delete('/api/announcements/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus pengumuman'));
    }
  }

  /// Extracts a backend error message ({"message": "..."}) or falls back.
  /// Batas jumlah banner yang tampil di beranda (setelan global admin).
  Future<int> getMaxBanner() async {
    final res = await apiClient.get('/api/announcements/banner-settings');
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return (j['maxBanner'] as num?)?.toInt() ?? 3;
    }
    throw Exception(_message(res.body, 'Gagal memuat setelan banner'));
  }

  /// Menyimpan batas jumlah banner (ADMIN).
  Future<int> setMaxBanner(int max) async {
    final res = await apiClient.put('/api/announcements/banner-settings',
        body: {'maxBanner': max});
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return (j['maxBanner'] as num?)?.toInt() ?? max;
    }
    throw Exception(_message(res.body, 'Gagal menyimpan setelan banner'));
  }

  /// Sembunyikan / tampilkan kembali satu pengumuman di banner beranda.
  Future<Announcement> setBannerHidden(String id, bool hidden) async {
    final res = await apiClient.put('/api/announcements/$id/banner',
        body: {'hidden': hidden});
    if (res.statusCode == 200) {
      return Announcement.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal mengubah tampilan banner'));
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return fallback;
  }
}
