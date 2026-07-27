import 'dart:convert';
import '../network/api_client.dart';

/// Today's AI daily-quota usage for one user (ADMIN view). Mirrors AiUsageResponse on the backend.
class AiUsage {
  final String userId;
  final String date;
  final int runCount;
  final int dailyLimit;
  final int promptTokens;
  final int outputTokens;

  AiUsage({
    required this.userId,
    required this.date,
    required this.runCount,
    required this.dailyLimit,
    required this.promptTokens,
    required this.outputTokens,
  });

  factory AiUsage.fromJson(Map<String, dynamic> j) => AiUsage(
        userId: j['userId']?.toString() ?? '',
        date: j['date']?.toString() ?? '',
        runCount: (j['runCount'] as num?)?.toInt() ?? 0,
        dailyLimit: (j['dailyLimit'] as num?)?.toInt() ?? 0,
        promptTokens: (j['promptTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (j['outputTokens'] as num?)?.toInt() ?? 0,
      );

  /// True when the user has used up today's allowance.
  bool get reached => dailyLimit > 0 && runCount >= dailyLimit;
}

/// The AI daily run limit + where it comes from (admin override or env default).
class AiLimit {
  final int dailyLimit;
  final String source; // 'ADMIN' | 'ENV'
  final int envDefault;

  AiLimit({required this.dailyLimit, required this.source, required this.envDefault});

  factory AiLimit.fromJson(Map<String, dynamic> j) => AiLimit(
        dailyLimit: (j['dailyLimit'] as num?)?.toInt() ?? 1,
        source: j['source']?.toString() ?? 'ENV',
        envDefault: (j['envDefault'] as num?)?.toInt() ?? 1,
      );

  bool get isAdminSet => source == 'ADMIN';
}

/// ADMIN: inspect + reset a user's daily AI run quota, and set the shared daily limit.
/// Backed by /api/admin/ai-usage/** (ADMIN-gated server-side).
class AiUsageAdminRepository {
  final ApiClient apiClient;

  AiUsageAdminRepository({required this.apiClient});

  Future<AiLimit> getLimit() async {
    final res = await apiClient.get('/api/admin/ai-usage/settings');
    if (res.statusCode == 200) {
      return AiLimit.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal memuat batas harian.'));
  }

  Future<AiLimit> setLimit(int dailyLimit) async {
    final res = await apiClient.put('/api/admin/ai-usage/settings', body: {'dailyLimit': dailyLimit});
    if (res.statusCode == 200) {
      return AiLimit.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal menyimpan batas harian.'));
  }

  Future<AiUsage> get(String userId) async {
    final res = await apiClient.get('/api/admin/ai-usage/$userId');
    if (res.statusCode == 200) {
      return AiUsage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal memuat pemakaian AI.'));
  }

  Future<AiUsage> reset(String userId) async {
    final res = await apiClient.post('/api/admin/ai-usage/$userId/reset');
    if (res.statusCode == 200) {
      return AiUsage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal mereset kuota.'));
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
