class QsProductClassification {
  final String id;
  final String tocCode;
  final String code;
  final String name;
  final String description;
  final bool manualOnly;
  final int sortOrder;

  const QsProductClassification({
    required this.id,
    required this.tocCode,
    required this.code,
    required this.name,
    required this.description,
    required this.manualOnly,
    required this.sortOrder,
  });

  int get classValue => int.tryParse(code) ?? sortOrder;

  factory QsProductClassification.fromJson(Map<String, dynamic> json) {
    return QsProductClassification(
      id: json['id']?.toString() ?? '',
      tocCode: json['tocCode']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      manualOnly: json['manualOnly'] == true,
      sortOrder: json['sortOrder'] is num
          ? (json['sortOrder'] as num).toInt()
          : int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tocCode': tocCode,
    'code': code,
    'name': name,
    'description': description,
    'manualOnly': manualOnly,
    'sortOrder': sortOrder,
  };
}
