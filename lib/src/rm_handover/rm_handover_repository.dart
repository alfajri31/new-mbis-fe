import 'dart:convert';
import '../network/api_client.dart';

/// Operasi pindah RM / pemindahan cabang menyentuh seluruh portofolio (nasabah +
/// pipeline + jadwal) dalam satu transaksi, jadi wajar lebih lama dari request
/// biasa. Dengan batas 30 detik bawaan, klien menyerah lebih dulu padahal server
/// masih menyelesaikan — pengguna melihat "koneksi terputus" untuk operasi yang
/// sebenarnya BERHASIL, lalu operasinya "tiba-tiba jadi" saat layar disegarkan.
const Duration _batchTimeout = Duration(seconds: 120);

/// An RM that can be picked as the source/target of a handover.
class RmCandidate {
  final String id;
  final String nip;
  final String name;
  final String? officeId;
  final String? officeName;

  RmCandidate({
    required this.id,
    required this.nip,
    required this.name,
    this.officeId,
    this.officeName,
  });

  factory RmCandidate.fromJson(Map<String, dynamic> j) => RmCandidate(
        id: j['id'] as String,
        nip: j['nip']?.toString() ?? '-',
        name: j['name']?.toString() ?? '-',
        officeId: j['officeId'] as String?,
        officeName: j['officeName'] as String?,
      );

  /// "Nama (NIP)" — convenient label for dropdowns.
  String get label => '$name ($nip)';
}

/// A pickable record in a selective handover (customer).
class RmRef {
  final String id;
  final String name;

  RmRef({required this.id, required this.name});

  factory RmRef.fromJson(Map<String, dynamic> j) =>
      RmRef(id: j['id'] as String, name: j['name']?.toString() ?? '-');
}

/// Active portfolio that would move if the whole book of an RM were handed over.
class RmTransferPreview {
  final String rmId;
  final int customerCount;
  final int pipelineCount;
  final int scheduleCount;
  final List<RmRef> customers;

  RmTransferPreview({
    required this.rmId,
    required this.customerCount,
    required this.pipelineCount,
    required this.scheduleCount,
    required this.customers,
  });

  factory RmTransferPreview.fromJson(Map<String, dynamic> j) => RmTransferPreview(
        rmId: j['rmId']?.toString() ?? '',
        customerCount: (j['customerCount'] ?? 0) as int,
        pipelineCount: (j['pipelineCount'] ?? 0) as int,
        scheduleCount: (j['scheduleCount'] ?? 0) as int,
        customers: (j['customers'] as List<dynamic>? ?? const [])
            .map((e) => RmRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isEmpty =>
      customerCount == 0 && pipelineCount == 0 && scheduleCount == 0;
}

/// A handover record (used for both the execute result and the history list).
class RmHandover {
  final String id;
  final String fromRmId;
  final String fromRmName;
  final String toRmId;
  final String toRmName;
  final String type; // PERMANENT | TEMPORARY
  final String scope; // ALL | SELECTED
  final String status; // ACTIVE | REVERTED
  final String? reason;
  final String? note;
  final String? createdAt;
  final String? revertedAt;
  final int customerCount;
  final int pipelineCount;
  final int scheduleCount;

  RmHandover({
    required this.id,
    required this.fromRmId,
    required this.fromRmName,
    required this.toRmId,
    required this.toRmName,
    required this.type,
    required this.scope,
    required this.status,
    this.reason,
    this.note,
    this.createdAt,
    this.revertedAt,
    required this.customerCount,
    required this.pipelineCount,
    required this.scheduleCount,
  });

  factory RmHandover.fromJson(Map<String, dynamic> j) => RmHandover(
        id: j['id'] as String,
        fromRmId: j['fromRmId']?.toString() ?? '',
        fromRmName: j['fromRmName']?.toString() ?? '-',
        toRmId: j['toRmId']?.toString() ?? '',
        toRmName: j['toRmName']?.toString() ?? '-',
        type: j['type']?.toString() ?? 'PERMANENT',
        scope: j['scope']?.toString() ?? 'ALL',
        status: j['status']?.toString() ?? 'ACTIVE',
        reason: j['reason'] as String?,
        note: j['note'] as String?,
        createdAt: j['createdAt'] as String?,
        revertedAt: j['revertedAt'] as String?,
        customerCount: (j['customerCount'] ?? 0) as int,
        pipelineCount: (j['pipelineCount'] ?? 0) as int,
        scheduleCount: (j['scheduleCount'] ?? 0) as int,
      );

  bool get isActive => status == 'ACTIVE';
  bool get isTemporary => type == 'TEMPORARY';
}

/// API access for the Pindah RM (RM handover) feature. Backed by /api/rm-handovers,
/// reachable only by ADMIN/BM/RO/KUP.
class RmHandoverRepository {
  final ApiClient apiClient;

  RmHandoverRepository({required this.apiClient});

  Future<List<RmCandidate>> candidateRms() async {
    final res = await apiClient.get('/api/rm-handovers/candidate-rms');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => RmCandidate.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat daftar RM'));
  }

  Future<RmTransferPreview> preview(String fromRmId) async {
    final res = await apiClient.get('/api/rm-handovers/preview?fromRmId=$fromRmId');
    if (res.statusCode == 200) {
      return RmTransferPreview.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal memuat portofolio RM'));
  }

  Future<RmHandover> execute({
    required String fromRmId,
    required String toRmId,
    required String type, // PERMANENT | TEMPORARY
    required String scope, // ALL | SELECTED
    List<String> customerIds = const [],
    String? reason,
    String? note,
  }) async {
    final res = await apiClient.post('/api/rm-handovers', timeout: _batchTimeout, body: {
      'fromRmId': fromRmId,
      'toRmId': toRmId,
      'type': type,
      'scope': scope,
      'customerIds': customerIds,
      'reason': reason,
      'note': note,
    });
    if (res.statusCode == 200) {
      return RmHandover.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal memindahkan RM'));
  }

  Future<List<RmHandover>> list() async {
    final res = await apiClient.get('/api/rm-handovers');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => RmHandover.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat riwayat pemindahan'));
  }

  Future<RmHandover> revert(String id) async {
    final res = await apiClient.post('/api/rm-handovers/$id/revert', timeout: _batchTimeout);
    if (res.statusCode == 200) {
      return RmHandover.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal mengembalikan pemindahan'));
  }

  /// Extracts a backend error message ({"message": "..."}) or falls back.
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
