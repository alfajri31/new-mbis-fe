/// Entity nasabah — data class murni (tanpa import Flutter/HTTP). Lapisan `domain`.
/// Cerminkan `CustomerListResponse` dari kontrak OpenAPI backend.
class Customer {
  final String id;
  final String name;
  final String? entityCategory;
  final String? state;
  final bool isBlacklisted;
  final int pipelineCount;

  const Customer({
    required this.id,
    required this.name,
    this.entityCategory,
    this.state,
    this.isBlacklisted = false,
    this.pipelineCount = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        entityCategory: json['entityCategory'] as String?,
        state: json['state'] as String?,
        isBlacklisted: json['isBlacklisted'] as bool? ?? false,
        pipelineCount: (json['pipelineCount'] as num?)?.toInt() ?? 0,
      );
}
