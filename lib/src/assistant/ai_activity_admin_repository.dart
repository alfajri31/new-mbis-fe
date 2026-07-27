import 'dart:convert';
import '../network/api_client.dart';
import 'assistant_repository.dart' show AiField, AssistantException;

/// A "Tujuan" component the admin composes activities from.
class AiComponent {
  final String key;
  final String label;
  final String description;
  final List<String> defaultSources;

  AiComponent({
    required this.key,
    required this.label,
    required this.description,
    this.defaultSources = const [],
  });

  factory AiComponent.fromJson(Map<String, dynamic> j) => AiComponent(
        key: j['key'] ?? '',
        label: j['label'] ?? '',
        description: j['description'] ?? '',
        defaultSources:
            (j['defaultSources'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// Customer eligibility rules for an activity (AND-combined).
class AiEligibilityModel {
  final bool requireNoActivePipeline;
  final List<String> allowedStates;
  final List<String> allowedEntityCategories;

  AiEligibilityModel({
    this.requireNoActivePipeline = false,
    this.allowedStates = const [],
    this.allowedEntityCategories = const [],
  });

  bool get isEmpty =>
      !requireNoActivePipeline && allowedStates.isEmpty && allowedEntityCategories.isEmpty;

  factory AiEligibilityModel.fromJson(Map<String, dynamic> j) => AiEligibilityModel(
        requireNoActivePipeline: j['requireNoActivePipeline'] == true,
        allowedStates: (j['allowedStates'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        allowedEntityCategories:
            (j['allowedEntityCategories'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'requireNoActivePipeline': requireNoActivePipeline,
        'allowedStates': allowedStates,
        'allowedEntityCategories': allowedEntityCategories,
      };
}

/// Admin create/update + read shape for an activity.
class AdminActivity {
  final String? id;
  final String name;
  final String? description;
  final String? icon;
  final bool enabled;
  final int sortOrder;
  final List<String> tasks;
  final List<String> sources;
  final List<AiField> fields;
  final AiEligibilityModel? eligibility;
  final bool builtIn;

  AdminActivity({
    this.id,
    required this.name,
    this.description,
    this.icon,
    this.enabled = true,
    this.sortOrder = 0,
    this.tasks = const [],
    this.sources = const [],
    this.fields = const [],
    this.eligibility,
    this.builtIn = false,
  });

  factory AdminActivity.fromJson(Map<String, dynamic> j) => AdminActivity(
        id: j['id'],
        name: j['name'] ?? '',
        description: j['description'],
        icon: j['icon'],
        enabled: j['enabled'] != false,
        sortOrder: j['sortOrder'] ?? 0,
        tasks: (j['tasks'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        sources: (j['sources'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        fields: (j['fields'] as List?)
                ?.map((e) => AiField.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        eligibility: j['eligibility'] == null
            ? null
            : AiEligibilityModel.fromJson(j['eligibility'] as Map<String, dynamic>),
        builtIn: j['builtIn'] == true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'enabled': enabled,
        'sortOrder': sortOrder,
        'tasks': tasks,
        'sources': sources,
        'fields': fields.map((f) => f.toJson()).toList(),
        'eligibility': eligibility?.toJson(),
        'builtIn': builtIn,
      };

  AdminActivity copyWith({bool? enabled}) => AdminActivity(
        id: id,
        name: name,
        description: description,
        icon: icon,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder,
        tasks: tasks,
        sources: sources,
        fields: fields,
        eligibility: eligibility,
        builtIn: builtIn,
      );
}

/// ADMIN create/update + read shape for a selectable Gemini model.
class AdminAiModel {
  final String code;
  final String label;
  final String? description;
  final bool enabled;
  final int sortOrder;
  final bool builtIn;

  AdminAiModel({
    required this.code,
    required this.label,
    this.description,
    this.enabled = false,
    this.sortOrder = 0,
    this.builtIn = false,
  });

  factory AdminAiModel.fromJson(Map<String, dynamic> j) => AdminAiModel(
        code: (j['code'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        description: j['description'],
        enabled: j['enabled'] == true,
        sortOrder: j['sortOrder'] ?? 0,
        builtIn: j['builtIn'] == true,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'description': description,
        'enabled': enabled,
        'sortOrder': sortOrder,
        'builtIn': builtIn,
      };

  AdminAiModel copyWith({String? label, String? description, bool? enabled, int? sortOrder}) =>
      AdminAiModel(
        code: code,
        label: label ?? this.label,
        description: description ?? this.description,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder ?? this.sortOrder,
        builtIn: builtIn,
      );
}

/// ADMIN — manage which Gemini models RMs may pick (enable/disable, add/remove).
class AiModelAdminRepository {
  final ApiClient apiClient;
  AiModelAdminRepository({required this.apiClient});

  Future<List<AdminAiModel>> list() async {
    final res = await apiClient.get('/api/admin/ai-models');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => AdminAiModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw AssistantException(_msg(res, 'Gagal memuat daftar model.'));
  }

  Future<AdminAiModel> create(AdminAiModel m) async {
    final res = await apiClient.post('/api/admin/ai-models', body: m.toJson());
    if (res.statusCode == 200) return AdminAiModel.fromJson(jsonDecode(res.body));
    throw AssistantException(_msg(res, 'Gagal menambah model.'));
  }

  Future<AdminAiModel> update(String code, AdminAiModel m) async {
    final res = await apiClient.put('/api/admin/ai-models/$code', body: m.toJson());
    if (res.statusCode == 200) return AdminAiModel.fromJson(jsonDecode(res.body));
    throw AssistantException(_msg(res, 'Gagal menyimpan model.'));
  }

  /// Makes [code] the single active model that all RM AI runs use (disables the rest).
  Future<AdminAiModel> activate(String code) async {
    final res = await apiClient.put('/api/admin/ai-models/$code/activate');
    if (res.statusCode == 200) return AdminAiModel.fromJson(jsonDecode(res.body));
    throw AssistantException(_msg(res, 'Gagal mengaktifkan model.'));
  }

  Future<void> delete(String code) async {
    final res = await apiClient.delete('/api/admin/ai-models/$code');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw AssistantException(_msg(res, 'Gagal menghapus model.'));
    }
  }

  String _msg(dynamic res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] is String && (decoded['message'] as String).isNotEmpty) {
        return decoded['message'];
      }
    } catch (_) {
      // not JSON
    }
    return fallback;
  }
}

class AiActivityAdminRepository {
  final ApiClient apiClient;
  AiActivityAdminRepository({required this.apiClient});

  Future<List<AiComponent>> getComponents() async {
    final res = await apiClient.get('/api/admin/ai-activities/components');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => AiComponent.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw AssistantException(_message(res, 'Gagal memuat komponen.'));
  }

  Future<List<AdminActivity>> list() async {
    final res = await apiClient.get('/api/admin/ai-activities');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => AdminActivity.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw AssistantException(_message(res, 'Gagal memuat aktivitas.'));
  }

  Future<AdminActivity> create(AdminActivity a) async {
    final res = await apiClient.post('/api/admin/ai-activities', body: a.toJson());
    if (res.statusCode == 200) return AdminActivity.fromJson(jsonDecode(res.body));
    throw AssistantException(_message(res, 'Gagal membuat aktivitas.'));
  }

  Future<AdminActivity> update(String id, AdminActivity a) async {
    final res = await apiClient.put('/api/admin/ai-activities/$id', body: a.toJson());
    if (res.statusCode == 200) return AdminActivity.fromJson(jsonDecode(res.body));
    throw AssistantException(_message(res, 'Gagal menyimpan aktivitas.'));
  }

  Future<void> delete(String id) async {
    final res = await apiClient.delete('/api/admin/ai-activities/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw AssistantException(_message(res, 'Gagal menghapus aktivitas.'));
    }
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
