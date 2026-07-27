import 'dart:convert';
import '../network/api_client.dart';
import 'rm_handover_repository.dart' show RmCandidate;

/// Operasi pindah RM / pemindahan cabang menyentuh seluruh portofolio (nasabah +
/// pipeline + jadwal) dalam satu transaksi, jadi wajar lebih lama dari request
/// biasa. Dengan batas 30 detik bawaan, klien menyerah lebih dulu padahal server
/// masih menyelesaikan — pengguna melihat "koneksi terputus" untuk operasi yang
/// sebenarnya BERHASIL, lalu operasinya "tiba-tiba jadi" saat layar disegarkan.
const Duration _batchTimeout = Duration(seconds: 120);

/// A two-stage RM branch transfer (PJD picks the branch, the old branch's Pinca
/// allocates the portfolio). Distinct from a raw handover — see RmTransferService.
class RmTransfer {
  final String id;
  final String rmId;
  final String rmName;
  final String fromOfficeId;
  final String? fromOfficeName;
  final String toOfficeId;
  final String? toOfficeName;
  final String status; // PENDING_ALLOCATION | COMPLETED | CANCELLED
  final String? reason;
  final String? note;
  final String? createdAt;
  final String? allocatedAt;

  /// True when the current viewer may allocate this (Pinca of the from-branch, or admin).
  final bool actionable;

  RmTransfer({
    required this.id,
    required this.rmId,
    required this.rmName,
    required this.fromOfficeId,
    this.fromOfficeName,
    required this.toOfficeId,
    this.toOfficeName,
    required this.status,
    this.reason,
    this.note,
    this.createdAt,
    this.allocatedAt,
    required this.actionable,
  });

  factory RmTransfer.fromJson(Map<String, dynamic> j) => RmTransfer(
        id: j['id'] as String,
        rmId: j['rmId']?.toString() ?? '',
        rmName: j['rmName']?.toString() ?? '-',
        fromOfficeId: j['fromOfficeId']?.toString() ?? '',
        fromOfficeName: j['fromOfficeName'] as String?,
        toOfficeId: j['toOfficeId']?.toString() ?? '',
        toOfficeName: j['toOfficeName'] as String?,
        status: j['status']?.toString() ?? 'PENDING_ALLOCATION',
        reason: j['reason'] as String?,
        note: j['note'] as String?,
        createdAt: j['createdAt'] as String?,
        allocatedAt: j['allocatedAt'] as String?,
        actionable: (j['actionable'] ?? false) as bool,
      );

  bool get isPending => status == 'PENDING_ALLOCATION';
  bool get isCompleted => status == 'COMPLETED';
}

/// One of the transferring RM's customers, awaiting allocation.
class TransferCustomer {
  final String id;
  final String name;
  final int activePipelines;

  TransferCustomer({required this.id, required this.name, required this.activePipelines});

  factory TransferCustomer.fromJson(Map<String, dynamic> j) => TransferCustomer(
        id: j['id'] as String,
        name: j['name']?.toString() ?? '-',
        activePipelines: (j['activePipelines'] ?? 0) as int,
      );
}

/// What the Pinca needs to allocate: the RM's customers + the old branch's RMs.
class TransferAllocationView {
  final String transferId;
  final String rmId;
  final String rmName;
  final String toOfficeName;
  final List<TransferCustomer> customers;
  final List<RmCandidate> destinationRms;

  TransferAllocationView({
    required this.transferId,
    required this.rmId,
    required this.rmName,
    required this.toOfficeName,
    required this.customers,
    required this.destinationRms,
  });

  factory TransferAllocationView.fromJson(Map<String, dynamic> j) => TransferAllocationView(
        transferId: j['transferId']?.toString() ?? '',
        rmId: j['rmId']?.toString() ?? '',
        rmName: j['rmName']?.toString() ?? '-',
        toOfficeName: j['toOfficeName']?.toString() ?? '-',
        customers: (j['customers'] as List<dynamic>? ?? const [])
            .map((e) => TransferCustomer.fromJson(e as Map<String, dynamic>))
            .toList(),
        destinationRms: (j['destinationRms'] as List<dynamic>? ?? const [])
            .map((e) => RmCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A branch office, for the target-branch picker.
class OfficeRef {
  final String id;
  final String name;
  final String type;

  OfficeRef({required this.id, required this.name, required this.type});

  factory OfficeRef.fromJson(Map<String, dynamic> j) => OfficeRef(
        id: j['id'] as String,
        name: j['name']?.toString() ?? '-',
        type: j['type']?.toString() ?? '',
      );

  String get label => name;
}

/// API access for the two-stage RM branch transfer. Backed by /api/rm-transfers.
class RmTransferRepository {
  final ApiClient apiClient;

  RmTransferRepository({required this.apiClient});

  /// Active BRANCH offices — the only valid transfer targets (server enforces this too).
  Future<List<OfficeRef>> branches() async {
    final res = await apiClient.get('/api/offices');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list
          .map((j) => OfficeRef.fromJson(j as Map<String, dynamic>))
          .where((o) => o.type == 'BRANCH')
          .toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat daftar cabang'));
  }

  /// PJD/Admin: create a transfer (RM → branch).
  Future<RmTransfer> create({
    required String rmId,
    required String toOfficeId,
    String? reason,
    String? note,
  }) async {
    final res = await apiClient.post('/api/rm-transfers', timeout: _batchTimeout, body: {
      'rmId': rmId,
      'toOfficeId': toOfficeId,
      'reason': reason,
      'note': note,
    });
    if (res.statusCode == 200) {
      return RmTransfer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal membuat pemindahan'));
  }

  Future<RmTransfer> cancel(String id) async {
    final res = await apiClient.post('/api/rm-transfers/$id/cancel', timeout: _batchTimeout);
    if (res.statusCode == 200) {
      return RmTransfer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal membatalkan pemindahan'));
  }

  /// Every transfer in the caller's scope (pending + history).
  Future<List<RmTransfer>> list() async {
    final res = await apiClient.get('/api/rm-transfers');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => RmTransfer.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat daftar pemindahan'));
  }

  Future<TransferAllocationView> allocationView(String transferId) async {
    final res = await apiClient.get('/api/rm-transfers/$transferId/allocation');
    if (res.statusCode == 200) {
      return TransferAllocationView.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal memuat data alokasi'));
  }

  /// Pinca: allocate the book and execute the move.
  Future<RmTransfer> allocate({
    required String transferId,
    required String defaultRmId,
    required Map<String, String> overrides, // customerId -> toRmId
  }) async {
    final res = await apiClient.post('/api/rm-transfers/$transferId/allocate', timeout: _batchTimeout, body: {
      'defaultRmId': defaultRmId,
      'overrides': overrides.entries
          .map((e) => {'customerId': e.key, 'toRmId': e.value})
          .toList(),
    });
    if (res.statusCode == 200) {
      return RmTransfer.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal mengalokasikan portofolio'));
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
