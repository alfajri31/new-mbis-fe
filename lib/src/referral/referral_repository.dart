import 'dart:convert';
import '../network/api_client.dart';

/// One pending referral in a Branch Manager's queue.
class ReferralPending {
  final String pipelineId;
  final String? title;
  final String? customerName;
  final String? fromOfficeId;
  final String? fromOfficeName;
  final String? toOfficeId;
  final String? toOfficeName;
  final String? fromRmName;
  final String status; // PENDING_SOURCE | PENDING_DEST | APPROVED | REJECTED
  final String? assignedRmName; // RM tujuan penerima (saat APPROVED)
  final String? rejectReason; // alasan penolakan (saat REJECTED)
  final bool actionable; // BM ini bisa approve/reject di tahap saat ini

  const ReferralPending({
    required this.pipelineId,
    this.title,
    this.customerName,
    this.fromOfficeId,
    this.fromOfficeName,
    this.toOfficeId,
    this.toOfficeName,
    this.fromRmName,
    required this.status,
    this.assignedRmName,
    this.rejectReason,
    this.actionable = false,
  });

  bool get isDestStage => status == 'PENDING_DEST';
  bool get isPending => status == 'PENDING_SOURCE' || status == 'PENDING_DEST';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory ReferralPending.fromJson(Map<String, dynamic> j) => ReferralPending(
        pipelineId: j['pipelineId'] ?? '',
        title: j['title'],
        customerName: j['customerName'],
        fromOfficeId: j['fromOfficeId'],
        fromOfficeName: j['fromOfficeName'],
        toOfficeId: j['toOfficeId'],
        toOfficeName: j['toOfficeName'],
        fromRmName: j['fromRmName'],
        status: j['status'] ?? '',
        assignedRmName: j['assignedRmName'],
        rejectReason: j['rejectReason'],
        actionable: j['actionable'] == true,
      );
}

/// A branch office option (referral destination picker).
class BranchOffice {
  final String id;
  final String name;
  const BranchOffice(this.id, this.name);
}

/// An RM candidate in the destination branch.
class BranchRm {
  final String id;
  final String? nip;
  final String name;
  const BranchRm({required this.id, this.nip, required this.name});
  factory BranchRm.fromJson(Map<String, dynamic> j) =>
      BranchRm(id: j['id'] ?? '', nip: j['nip'], name: j['name'] ?? '');
}

class ReferralRepository {
  final ApiClient apiClient;
  ReferralRepository({required this.apiClient});

  Future<List<ReferralPending>> getPending() async {
    final res = await apiClient.get('/api/referrals/pending');
    if (res.statusCode != 200) throw Exception('Failed to load referrals');
    final List<dynamic> list = jsonDecode(res.body);
    return list.map((j) => ReferralPending.fromJson(j)).toList();
  }

  Future<void> approve(String pipelineId, {String? rmId}) async {
    final body = <String, dynamic>{};
    if (rmId != null) body['rmId'] = rmId;
    final res = await apiClient.post('/api/referrals/$pipelineId/approve', body: body);
    if (res.statusCode != 200) throw Exception('Gagal menyetujui referral');
  }

  Future<void> reject(String pipelineId, String reason) async {
    final res = await apiClient.post('/api/referrals/$pipelineId/reject', body: {'reason': reason});
    if (res.statusCode != 200) throw Exception('Gagal menolak referral');
  }

  /// Active RMs in the destination branch (destination BM picks one).
  Future<List<BranchRm>> branchRms(String officeId) async {
    final res = await apiClient.get('/api/referrals/branch/$officeId/rms');
    if (res.statusCode != 200) throw Exception('Failed to load RM cabang');
    final List<dynamic> list = jsonDecode(res.body);
    return list.map((j) => BranchRm.fromJson(j)).toList();
  }

  /// All BRANCH offices (for the referral destination dropdown).
  Future<List<BranchOffice>> branchOffices() async {
    final res = await apiClient.get('/api/offices');
    if (res.statusCode != 200) throw Exception('Failed to load offices');
    final List<dynamic> list = jsonDecode(res.body);
    return list
        .where((j) => (j as Map<String, dynamic>)['type'] == 'BRANCH')
        .map((j) => BranchOffice(j['id'] ?? '', j['name'] ?? ''))
        .toList();
  }
}
