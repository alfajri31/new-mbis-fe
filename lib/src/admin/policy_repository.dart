import 'dart:convert';
import '../network/api_client.dart';

/// A policy row on the admin "Kelola Premi & Komisi" screen.
class AdminPolicyModel {
  final String id;
  final String policyNumber;
  final String customerName;
  final String? agentName;
  final double premiGross;
  final double totalPaid;
  final bool lunas;
  final String? wonDate;

  AdminPolicyModel({
    required this.id,
    required this.policyNumber,
    required this.customerName,
    this.agentName,
    required this.premiGross,
    required this.totalPaid,
    required this.lunas,
    this.wonDate,
  });

  double get remaining =>
      (premiGross - totalPaid) <= 0 ? 0 : (premiGross - totalPaid);
  double get progress =>
      premiGross <= 0 ? 0 : (totalPaid / premiGross).clamp(0, 1).toDouble();

  factory AdminPolicyModel.fromJson(Map<String, dynamic> json) {
    return AdminPolicyModel(
      id: json['id'] ?? '',
      policyNumber: json['policyNumber'] ?? '-',
      customerName: json['customerName'] ?? '-',
      agentName: json['agentName'],
      premiGross: (json['premiGross'] ?? 0).toDouble(),
      totalPaid: (json['totalPaid'] ?? 0).toDouble(),
      lunas: json['lunas'] ?? false,
      wonDate: json['wonDate'],
    );
  }
}

/// A recorded premi payment (installment).
class PremiPaymentModel {
  final String id;
  final double amount;
  final String? paidDate;
  final String? note;
  final double? commissionAmount;

  PremiPaymentModel({
    required this.id,
    required this.amount,
    this.paidDate,
    this.note,
    this.commissionAmount,
  });

  factory PremiPaymentModel.fromJson(Map<String, dynamic> json) {
    return PremiPaymentModel(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paidDate: json['paidDate'],
      note: json['note'],
      commissionAmount: json['commissionAmount'] != null
          ? (json['commissionAmount'] as num).toDouble()
          : null,
    );
  }
}

/// Admin/PJD premium management API (ADMIN role only on the backend).
class AdminPolicyRepository {
  final ApiClient apiClient;

  AdminPolicyRepository({required this.apiClient});

  Future<List<AdminPolicyModel>> getPolicies() async {
    final res = await apiClient.get('/api/admin/policies');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => AdminPolicyModel.fromJson(j)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat daftar polis'));
  }

  Future<List<PremiPaymentModel>> getPayments(String policyId) async {
    final res = await apiClient.get('/api/admin/policies/$policyId/payments');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => PremiPaymentModel.fromJson(j)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat riwayat pembayaran'));
  }

  Future<AdminPolicyModel> recordPayment(
    String policyId, {
    required double amount,
    String? paidDate,
    String? note,
  }) async {
    final body = <String, dynamic>{'amount': amount};
    if (paidDate != null) body['paidDate'] = paidDate;
    if (note != null && note.isNotEmpty) body['note'] = note;
    final res = await apiClient.post('/api/admin/policies/$policyId/payments', body: body);
    if (res.statusCode == 200) {
      return AdminPolicyModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal mencatat pembayaran'));
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
