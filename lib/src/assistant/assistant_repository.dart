import 'dart:convert';
import '../network/api_client.dart';

/// Friendly error carrying a message safe to show the user (Bahasa Indonesia).
class AssistantException implements Exception {
  final String message;
  AssistantException(this.message);
  @override
  String toString() => message;
}

/// Raised when the RM has used up their daily AI run quota (HTTP 429), so the UI can
/// show a dedicated "kuota habis" state instead of a generic error.
class AiLimitException extends AssistantException {
  AiLimitException(super.message);
}

/// One RM input field of an activity (rendered as a wizard step).
class AiField {
  final String key;
  final String label;
  final String type; // CHIPS | TEXT | TEXTAREA
  final bool required;
  final List<String> options;
  final String? help;

  AiField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.help,
  });

  factory AiField.fromJson(Map<String, dynamic> j) => AiField(
        key: j['key'] ?? '',
        label: j['label'] ?? '',
        type: (j['type'] ?? 'TEXT').toString().toUpperCase(),
        required: j['required'] == true,
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        help: j['help'],
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type,
        'required': required,
        'options': options,
        if (help != null) 'help': help,
      };
}

/// An activity available to the RM for a customer, with eligibility info.
class AiActivity {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final List<AiField> fields;
  final bool eligible;
  final String? ineligibleReason;

  AiActivity({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.fields = const [],
    this.eligible = true,
    this.ineligibleReason,
  });

  factory AiActivity.fromJson(Map<String, dynamic> j) => AiActivity(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        description: j['description'],
        icon: j['icon'],
        fields: (j['fields'] as List?)
                ?.map((e) => AiField.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        eligible: j['eligible'] != false,
        ineligibleReason: j['ineligibleReason'],
      );
}

/// One section of a standardized AI result: heading + bullet items.
class AiSection {
  final String heading;
  final List<String> items;
  AiSection({required this.heading, this.items = const []});

  factory AiSection.fromJson(Map<String, dynamic> j) => AiSection(
        heading: (j['heading'] ?? '').toString(),
        items: (j['items'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {'heading': heading, 'items': items};
}

/// One product recommendation: catalog product name + short reason. Rendered as an
/// expandable card that deep-searches Product Knowledge by [produk].
class AiRecommendation {
  final String produk;

  /// Optional specific type/variant of [produk] (e.g. "Bid Bond"). Tapping still opens the
  /// parent product's detail (where the "Jenis Produk" section lives).
  final String jenis;
  final String alasan;

  /// Catalog product id (resolved server-side) → deep-link straight to the product detail.
  /// Null when the recommended product could not be matched to the catalog (falls back to search).
  final String? productId;

  AiRecommendation({required this.produk, this.jenis = '', this.alasan = '', this.productId});

  factory AiRecommendation.fromJson(Map<String, dynamic> j) => AiRecommendation(
        produk: (j['produk'] ?? '').toString(),
        jenis: (j['jenis'] ?? '').toString(),
        alasan: (j['alasan'] ?? '').toString(),
        productId: (j['productId'] as String?)?.trim().isNotEmpty == true
            ? (j['productId'] as String).trim()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'produk': produk,
        if (jenis.isNotEmpty) 'jenis': jenis,
        'alasan': alasan,
        if (productId != null) 'productId': productId,
      };
}

/// Standardized AI output — same shape for every activity, so it always renders neatly.
class AiStructuredResult {
  final String? judul;
  final List<AiSection> sections;
  final List<AiRecommendation> recommendations;
  AiStructuredResult({this.judul, this.sections = const [], this.recommendations = const []});

  factory AiStructuredResult.fromJson(Map<String, dynamic>? j) {
    if (j == null) return AiStructuredResult();
    return AiStructuredResult(
      judul: j['judul'],
      sections: (j['sections'] as List?)
              ?.map((e) => AiSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      // Additive field — absent on results saved before product cards existed.
      recommendations: (j['recommendations'] as List?)
              ?.map((e) => AiRecommendation.fromJson(e as Map<String, dynamic>))
              .where((r) => r.produk.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'judul': judul,
        'sections': sections.map((s) => s.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
      };

  /// Plain-text flatten (for snippets/search).
  String get plainText =>
      sections.expand((s) => [s.heading, ...s.items]).where((t) => t.isNotEmpty).join(' • ');
}

/// A real source link from Google Search grounding.
class AiSource {
  final String judul;
  final String url;
  AiSource({required this.judul, required this.url});

  factory AiSource.fromJson(Map<String, dynamic> j) =>
      AiSource(judul: (j['judul'] ?? '').toString(), url: (j['url'] ?? '').toString());

  Map<String, dynamic> toJson() => {'judul': judul, 'url': url};
}

/// The AI's answer for a single run + sources. Not yet saved.
class AiRunResult {
  final String activityId;
  final String activityName;
  final AiStructuredResult result;
  final List<AiSource> sources;
  final String? model;

  AiRunResult({
    required this.activityId,
    required this.activityName,
    required this.result,
    this.sources = const [],
    this.model,
  });

  factory AiRunResult.fromJson(Map<String, dynamic> j) => AiRunResult(
        activityId: j['activityId'] ?? '',
        activityName: j['activityName'] ?? '',
        result: AiStructuredResult.fromJson(j['result'] as Map<String, dynamic>?),
        sources: (j['sources'] as List?)
                ?.map((e) => AiSource.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        model: j['model'],
      );
}

/// A saved AI result on a customer. The server keeps the full history — the same activity can
/// have multiple entries (newest first); [generatedAt] distinguishes them.
class SavedAiResult {
  final String id;
  final String activityId;
  final String activityName;
  final AiStructuredResult result;
  final List<AiSource> sources;
  final String? model;
  final String? generatedAt;

  SavedAiResult({
    required this.id,
    required this.activityId,
    required this.activityName,
    required this.result,
    this.sources = const [],
    this.model,
    this.generatedAt,
  });

  factory SavedAiResult.fromJson(Map<String, dynamic> j) => SavedAiResult(
        id: j['id'] ?? '',
        activityId: j['activityId'] ?? '',
        activityName: j['activityName'] ?? '',
        result: AiStructuredResult.fromJson(j['result'] as Map<String, dynamic>?),
        sources: (j['sources'] as List?)
                ?.map((e) => AiSource.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        model: j['model'],
        generatedAt: j['generatedAt'],
      );
}

class AssistantRepository {
  final ApiClient apiClient;
  AssistantRepository({required this.apiClient});

  Future<List<AiActivity>> getActivities(String customerId) async {
    final res = await apiClient.get('/api/assistant/customers/$customerId/activities');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => AiActivity.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (res.statusCode == 503) {
      throw AssistantException('Fitur AI Assistant belum diaktifkan di server.');
    }
    if (res.statusCode == 403) return const [];
    throw AssistantException(_message(res, 'Gagal memuat aktivitas AI.'));
  }

  /// Runs an activity. The model isn't chosen here — the server uses the admin-selected
  /// active model and echoes it back in [AiRunResult.model].
  Future<AiRunResult> runActivity(
      String customerId, String activityId, Map<String, String> inputs) async {
    final res = await apiClient.post(
      '/api/assistant/customers/$customerId/activities/$activityId/run',
      body: {'inputs': inputs},
    );
    if (res.statusCode == 200) {
      return AiRunResult.fromJson(jsonDecode(res.body));
    }
    if (res.statusCode == 503) {
      throw AssistantException('Fitur AI Assistant belum diaktifkan di server.');
    }
    if (res.statusCode == 429) {
      throw AiLimitException(_message(res, 'Batas pemakaian AI harian Anda sudah tercapai.'));
    }
    throw AssistantException(_message(res, 'Gagal menjalankan aktivitas.'));
  }

  Future<SavedAiResult> saveResult(
    String customerId, {
    required String activityId,
    required AiStructuredResult result,
    List<AiSource> sources = const [],
    String? model,
  }) async {
    final res = await apiClient.post(
      '/api/assistant/customers/$customerId/results',
      body: {
        'activityId': activityId,
        'result': result.toJson(),
        'sources': sources.map((s) => s.toJson()).toList(),
        if (model != null && model.isNotEmpty) 'model': model,
      },
    );
    if (res.statusCode == 200) {
      return SavedAiResult.fromJson(jsonDecode(res.body));
    }
    throw AssistantException(_message(res, 'Gagal menyimpan hasil.'));
  }

  Future<List<SavedAiResult>> getSavedResults(String customerId) async {
    final res = await apiClient.get('/api/assistant/customers/$customerId/results');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => SavedAiResult.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (res.statusCode == 403) return const [];
    throw AssistantException(_message(res, 'Gagal memuat hasil tersimpan.'));
  }

  String _message(dynamic res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map &&
          decoded['message'] is String &&
          (decoded['message'] as String).isNotEmpty) {
        return decoded['message'];
      }
    } catch (_) {
      // not JSON
    }
    return fallback;
  }
}
