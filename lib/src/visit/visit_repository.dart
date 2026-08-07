import 'dart:convert';
import '../network/api_client.dart';

class VisitModel {
  final String id;
  final String type;
  final String? customerName;
  final String? activityDate;
  final String? notes;
  final String? nextFollowupDate;

  /// Rencana tindak lanjut, dibaca dari jadwal follow-up yang dibuat kunjungan
  /// ini. Null bila kunjungan tak berjadwal — di kasus itu rencananya sudah
  /// dilipat ke dalam [notes] oleh backend saat dicatat.
  final String? actionPlan;
  final String? gpsLatitude;
  final String? gpsLongitude;
  final String? photoUrl; // relative path served by /api/files/**

  /// True hanya bila kunjungan ini dicatat oleh pengguna yang sedang login.
  /// Server tetap memaksa aturan yang sama saat PUT — ini hanya penentu tombol.
  final bool canEdit;

  VisitModel({
    required this.id,
    required this.type,
    this.customerName,
    this.activityDate,
    this.notes,
    this.nextFollowupDate,
    this.actionPlan,
    this.gpsLatitude,
    this.gpsLongitude,
    this.photoUrl,
    this.canEdit = false,
  });

  bool get hasGps => gpsLatitude != null && gpsLongitude != null;
  bool get hasPhoto => photoUrl != null;

  double? get lat => gpsLatitude != null ? double.tryParse(gpsLatitude!) : null;
  double? get lng => gpsLongitude != null ? double.tryParse(gpsLongitude!) : null;

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      customerName: json['customerName'],
      activityDate: json['activityDate'],
      notes: json['notes'],
      nextFollowupDate: json['nextFollowupDate'],
      actionPlan: json['actionPlan'],
      gpsLatitude: json['gpsLatitude'],
      gpsLongitude: json['gpsLongitude'],
      photoUrl: json['photoUrl'],
      canEdit: json['canEdit'] == true,
    );
  }
}

/// Talks to the backend /api/visits endpoint. Activities (visits/calls) are
/// created via multipart so an optional photo can be attached alongside the
/// GPS coordinates.
class VisitRepository {
  final ApiClient apiClient;

  VisitRepository({required this.apiClient});

  Future<List<VisitModel>> getVisits(String pipelineId) async {
    final response = await apiClient.get('/api/visits?pipelineId=$pipelineId');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((j) => VisitModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load visits');
  }

  /// All visits performed by the current RM (for the GPS tracking map).
  Future<List<VisitModel>> getMyVisits() async {
    final response = await apiClient.get('/api/visits/me');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((j) => VisitModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load visits');
  }

  /// Visit history across every pipeline of one customer, newest first. Scoped
  /// like the customer detail itself, so a BM sees their branch's visits here.
  /// [ytd] false widens to the full history (server caps at 500 rows).
  Future<List<VisitModel>> getCustomerVisits(String customerId, {bool ytd = true}) async {
    final response = await apiClient.get('/api/customers/$customerId/visits?ytd=$ytd');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((j) => VisitModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load customer visits');
  }

  /// [nextFollowupDate] must be a NAIVE local ISO timestamp with a time —
  /// `2026-06-25T14:30:00.000`, no `Z` and no offset. The backend parses it with
  /// LocalDateTime.parse (which rejects both a bare date and an offset) and reads
  /// it as Asia/Jakarta. Note this is the opposite convention to the schedule
  /// endpoint, which wants `.toUtc()`.
  ///
  /// When [nextFollowupDate] is set the backend also creates an OPEN schedule;
  /// [actionPlan] (rencana tindak lanjut, max 255 chars) becomes its action plan.
  Future<Map<String, dynamic>> createVisit({
    required String pipelineId,
    required String type,
    String? notes,
    String? nextFollowupDate,
    String? actionPlan,
    String? gpsLatitude,
    String? gpsLongitude,
    List<int>? photoBytes,
    String? photoName,
  }) async {
    final fields = <String, String>{
      'pipelineId': pipelineId,
      'type': type,
    };
    if (notes != null && notes.isNotEmpty) fields['notes'] = notes;
    if (nextFollowupDate != null) fields['nextFollowupDate'] = nextFollowupDate;
    if (actionPlan != null && actionPlan.isNotEmpty) fields['actionPlan'] = actionPlan;
    if (gpsLatitude != null) fields['gpsLatitude'] = gpsLatitude;
    if (gpsLongitude != null) fields['gpsLongitude'] = gpsLongitude;

    final response = await apiClient.postMultipart(
      '/api/visits',
      fields: fields,
      fileField: photoBytes != null ? 'photo' : null,
      fileBytes: photoBytes,
      fileName: photoName,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to save activity (${response.statusCode})');
  }

  /// Perbaiki catatan kunjungan yang sudah tersimpan. Hanya RM yang mencatatnya
  /// (server menolak 403 kalau bukan), dan hanya tiga field ini — tag lokasi &
  /// foto tetap terkunci karena keduanya bukti, bukan catatan.
  ///
  /// Ketiganya dikirim apa adanya: kosong = dikosongkan, bukan "jangan diubah".
  /// [nextFollowupDate] memakai konvensi yang sama dengan [createVisit]: waktu
  /// lokal polos `2026-08-20T14:30:00.000`, tanpa `Z` dan tanpa offset.
  Future<VisitModel> updateVisit({
    required String visitId,
    String? notes,
    String? nextFollowupDate,
    String? actionPlan,
  }) async {
    final response = await apiClient.put('/api/visits/$visitId', body: {
      'notes': notes ?? '',
      'nextFollowupDate': nextFollowupDate,
      'actionPlan': actionPlan ?? '',
    });
    if (response.statusCode == 200) {
      return VisitModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    // Pesan server diteruskan apa adanya: penolakan yang mungkin muncul di sini
    // ("jadwal follow-up sudah selesai…") menjelaskan sesuatu yang tidak bisa
    // ditebak klien, jadi menggantinya dengan teks generik justru menyesatkan.
    throw Exception(_errorMessage(response.body) ?? 'Gagal menyimpan perubahan aktivitas');
  }

  String? _errorMessage(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['message'] is String) return m['message'] as String;
    } catch (_) {}
    return null;
  }
}
