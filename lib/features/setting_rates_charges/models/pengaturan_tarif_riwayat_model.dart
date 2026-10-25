/// Model untuk item riwayat perubahan pengaturan tarif & biaya dari API
/// GET /api/qs/pengaturan-tarif/riwayat
class PengaturanTarifRiwayatModel {
  final String id;
  final String productCode;
  final String action;
  final Map<String, dynamic> beforeValues;
  final Map<String, dynamic> afterValues;
  final DateTime? changedAt;
  final String changedBy;
  final String changedRole;

  const PengaturanTarifRiwayatModel({
    required this.id,
    required this.productCode,
    required this.action,
    this.beforeValues = const {},
    this.afterValues = const {},
    this.changedAt,
    this.changedBy = '',
    this.changedRole = '',
  });

  factory PengaturanTarifRiwayatModel.fromJson(Map<String, dynamic> json) {
    return PengaturanTarifRiwayatModel(
      id: json['id']?.toString() ?? '',
      productCode: json['productCode']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      beforeValues: json['beforeValues'] is Map<String, dynamic>
          ? json['beforeValues'] as Map<String, dynamic>
          : {},
      afterValues: json['afterValues'] is Map<String, dynamic>
          ? json['afterValues'] as Map<String, dynamic>
          : {},
      changedAt: json['changedAt'] != null
          ? DateTime.tryParse(json['changedAt'].toString())
          : null,
      changedBy: json['changedBy']?.toString() ?? '',
      changedRole: json['changedRole']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productCode': productCode,
      'action': action,
      'beforeValues': beforeValues,
      'afterValues': afterValues,
      'changedAt': changedAt?.toIso8601String(),
      'changedBy': changedBy,
      'changedRole': changedRole,
    };
  }

  /// Nama produk yang mudah dibaca (mis. "PSAKDI" atau "PA Xtra")
  String get displayProductName {
    final code = productCode.toUpperCase();
    if (code.contains('PSAKDI')) return 'PSAKDI';
    if (code.contains('PAXTRA') || code.contains('PAEXTRA')) return 'PA Xtra';
    return productCode;
  }

  /// Label aksi perubahan yang mudah dipahami
  String get displayAction {
    if (action.toUpperCase() == 'RESET_DEFAULT') return 'Kembalikan Default';
    if (action.toUpperCase() == 'UPDATE') return 'Perubahan Nilai';
    return action;
  }

  /// Waktu perubahan terformat: dd/MM/yyyy HH:mm
  String get formattedTime {
    if (changedAt == null) return '-';
    final dt = changedAt!;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  /// Ringkasan teks deskripsi perubahan
  String generateSummary(Map<String, String> fieldLabels) {
    if (action.toUpperCase() == 'RESET_DEFAULT') {
      return 'Tarif & biaya $displayProductName dikembalikan ke default sistem';
    }

    // Hitung field mana saja yang nilainya berubah antara beforeValues & afterValues
    final changed = <String>[];
    beforeValues.forEach((key, beforeVal) {
      if (afterValues.containsKey(key)) {
        final afterVal = afterValues[key];
        if (beforeVal?.toString() != afterVal?.toString()) {
          final label = fieldLabels[key] ?? key;
          changed.add(label);
        }
      }
    });

    if (changed.isNotEmpty) {
      final summary = changed.take(4).join(', ');
      final suffix = changed.length > 4 ? ', …' : '';
      return '${changed.length} nilai diubah pada $displayProductName: $summary$suffix';
    }

    return 'Pembaruan konfigurasi tarif & biaya $displayProductName';
  }
}
