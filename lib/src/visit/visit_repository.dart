import 'dart:convert';
import '../network/api_client.dart';

class VisitModel {
  final String id;
  final String type;
  final String? customerName;
  final String? activityDate;
  final String? notes;
  final String? nextFollowupDate;
  final String? gpsLatitude;
  final String? gpsLongitude;
  final String? photoUrl; // relative path served by /api/files/**

  VisitModel({
    required this.id,
    required this.type,
    this.customerName,
    this.activityDate,
    this.notes,
    this.nextFollowupDate,
    this.gpsLatitude,
    this.gpsLongitude,
    this.photoUrl,
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
      gpsLatitude: json['gpsLatitude'],
      gpsLongitude: json['gpsLongitude'],
      photoUrl: json['photoUrl'],
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
}
