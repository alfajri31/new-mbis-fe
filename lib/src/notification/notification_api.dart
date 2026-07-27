import 'dart:convert';
import '../network/api_client.dart';

/// One notification from the server-backed inbox. Mirrors the backend
/// `NotificationResponse` record (keep field names in sync).
class AppNotification {
  final String id;
  final String type; // VISIT_REMINDER | ANNOUNCEMENT | TENDER_REMINDER | AGENT_ONBOARDING | AGENT_LICENSE_EXPIRING | GENERAL
  final String title;
  final String? body;
  final Map<String, String> data; // routing keys (refType/refId/pipelineId/...)
  final String? refType;
  final String? refId;
  final bool read;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    this.refType,
    this.refId,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final rawData = j['data'];
    final data = <String, String>{};
    if (rawData is Map) {
      rawData.forEach((k, v) {
        if (v != null) data[k.toString()] = v.toString();
      });
    }
    return AppNotification(
      id: j['id'] as String,
      type: j['type']?.toString() ?? 'GENERAL',
      title: j['title']?.toString() ?? '-',
      body: j['body'] as String?,
      data: data,
      refType: j['refType'] as String?,
      refId: j['refId'] as String?,
      read: (j['read'] ?? false) as bool,
      // Backend sends UTC (ISO-8601 with 'Z'); show it in the device's local zone.
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
    );
  }

  /// Maps the backend type to the inbox card's visual category
  /// ('info' | 'warning' | 'success' | 'error').
  String get uiCategory {
    switch (type) {
      case 'VISIT_REMINDER':
      case 'TENDER_REMINDER':
      case 'AGENT_LICENSE_EXPIRING':
      case 'PIPELINE_STAGNANT':
      case 'RM_TRANSFER':
        return 'warning';
      case 'ANNOUNCEMENT':
      case 'AGENT_ONBOARDING':
      case 'REFERRAL':
      case 'RM_HANDOVER':
      case 'SCHEDULE_ASSIGNED':
      case 'PIPELINE_WON': // dipakai untuk WON & DECLINE → netral, bukan hijau/merah
        return 'info';
      case 'COMMISSION':
        return 'success';
      default:
        return 'info';
    }
  }

  /// Short relative time in Bahasa Indonesia (e.g. "5 mnt lalu", "2 jam lalu").
  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    final d = createdAt!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

/// One page of the inbox plus the cross-page unread count for the badge.
class NotificationPage {
  final List<AppNotification> content;
  final int page;
  final bool last;
  final int unreadCount;

  NotificationPage({
    required this.content,
    required this.page,
    required this.last,
    required this.unreadCount,
  });
}

/// API access for the notification inbox (any authenticated user).
class NotificationApi {
  final ApiClient apiClient;

  NotificationApi(this.apiClient);

  Future<NotificationPage> list({int page = 0, int size = 20}) async {
    final res = await apiClient.get('/api/notifications?page=$page&size=$size');
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> content = (j['content'] as List<dynamic>?) ?? const [];
      return NotificationPage(
        content: content
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: (j['page'] ?? page) as int,
        last: (j['last'] ?? true) as bool,
        unreadCount: (j['unreadCount'] ?? 0) as int,
      );
    }
    throw Exception(_message(res.body, 'Gagal memuat notifikasi'));
  }

  Future<int> unreadCount() async {
    final res = await apiClient.get('/api/notifications/unread-count');
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return (j['count'] ?? 0) as int;
    }
    return 0;
  }

  Future<void> markRead(String id) async {
    await apiClient.post('/api/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await apiClient.post('/api/notifications/read-all');
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
