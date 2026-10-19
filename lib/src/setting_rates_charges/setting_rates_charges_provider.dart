import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry log sederhana untuk riwayat perubahan pengaturan tarif & biaya.
class SettingRatesChargesLogEntry {
  final String at;
  final String by;
  final String txt;

  const SettingRatesChargesLogEntry({
    required this.at,
    required this.by,
    required this.txt,
  });
}

/// State untuk modul Setting Rates & Charges.
class SettingRatesChargesState {
  final Map<String, dynamic> values;
  final List<SettingRatesChargesLogEntry> logs;
  final bool isSaving;

  const SettingRatesChargesState({
    required this.values,
    this.logs = const [],
    this.isSaving = false,
  });

  SettingRatesChargesState copyWith({
    Map<String, dynamic>? values,
    List<SettingRatesChargesLogEntry>? logs,
    bool? isSaving,
  }) {
    return SettingRatesChargesState(
      values: values ?? this.values,
      logs: logs ?? this.logs,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Notifier pengelola state pengaturan tarif, biaya, dan audit log.
class SettingRatesChargesNotifier
    extends Notifier<SettingRatesChargesState> {
  // Nilai default awal (sesuai spesifikasi prototype M-BIS)
  static const Map<String, dynamic> defaultValues = {
    // Biaya Admin
    'admPolis': 20000,
    'admMaterai': 10000,
    'admE': 10000,
    // Batas & Diskon
    'upMax': 1000000000,
    'cPct': 10.0,
    'cMax': 10000000,
    'discMax': 20.0,
    'validityDays': 30,
    // Rate PA Xtra (%/tahun)
    'p_pokok': 0.10,
    'p_cacat': 0.15,
    'p_upC': 2.00,
    'p_ambulan': 2.00,
    'p_pemakaman': 0.10,
    'p_barang': 2.00,
    'p_dokumen': 2.00,
    'p_pendidikan': 0.10,
    'p_repatriasi': 0.10,
    // Batas Santunan PA Xtra (maksimal)
    'c_upC': 10000000,
    'c_ambulan': 2000000,
    'c_pemakaman': 2000000,
    'c_barang': 500000,
    'c_dokumen': 500000,
    'c_pendidikan': 5000000,
    'c_repatriasi': 5000000,
    // Rate PSAKDI [A/AB/C][0..3]
    'rA0': 0.08,
    'rA1': 0.10,
    'rA2': 0.12,
    'rA3': 0.16,
    'rAB0': 0.10,
    'rAB1': 0.13,
    'rAB2': 0.16,
    'rAB3': 0.18,
    'rC0': 2.00,
    'rC1': 2.00,
    'rC2': 2.00,
    'rC3': 2.00,
  };

  static const Map<String, String> fieldLabels = {
    'admPolis': 'Biaya Polis (cetak)',
    'admMaterai': 'Materai',
    'admE': 'Biaya e-Polis tambahan',
    'upMax': 'UP maksimal',
    'cPct': 'Batas C (% UP)',
    'cMax': 'Batas C maksimal',
    'discMax': 'Diskon maksimal',
    'validityDays': 'Masa Berlaku QS (Hari)',
    'p_pokok': 'Rate PA Xtra Kematian',
    'p_cacat': 'Rate PA Xtra Kematian + Cacat Tetap',
    'p_upC': 'Rate PA Xtra Perawatan / Pengobatan',
    'p_ambulan': 'Rate PA Xtra Ambulan',
    'p_pemakaman': 'Rate PA Xtra Pemakaman',
    'p_barang': 'Rate PA Xtra Barang Pribadi',
    'p_dokumen': 'Rate PA Xtra Dokumen',
    'p_pendidikan': 'Rate PA Xtra Biaya Pendidikan',
    'p_repatriasi': 'Rate PA Xtra Pemulangan Jenazah',
    'c_upC': 'Batas PA Xtra Perawatan',
    'c_ambulan': 'Batas PA Xtra Ambulan',
    'c_pemakaman': 'Batas PA Xtra Pemakaman',
    'c_barang': 'Batas PA Xtra Barang Pribadi',
    'c_dokumen': 'Batas PA Xtra Dokumen',
    'c_pendidikan': 'Batas PA Xtra Biaya Pendidikan',
    'c_repatriasi': 'Batas PA Xtra Pemulangan Jenazah',
    'rA0': 'Rate A Kelas 1',
    'rA1': 'Rate A Kelas 2',
    'rA2': 'Rate A Kelas 3',
    'rA3': 'Rate A Kelas 4',
    'rAB0': 'Rate A/B Kelas 1',
    'rAB1': 'Rate A/B Kelas 2',
    'rAB2': 'Rate A/B Kelas 3',
    'rAB3': 'Rate A/B Kelas 4',
    'rC0': 'Rate C Kelas 1',
    'rC1': 'Rate C Kelas 2',
    'rC2': 'Rate C Kelas 3',
    'rC3': 'Rate C Kelas 4',
  };

  @override
  SettingRatesChargesState build() {
    final now = DateTime.now();
    final initialLogs = [
      SettingRatesChargesLogEntry(
        at:
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} 09:30',
        by: 'UW',
        txt: 'Inisialisasi tarif & biaya standar M-BIS',
      ),
    ];

    return SettingRatesChargesState(
      values: Map<String, dynamic>.from(defaultValues),
      logs: initialLogs,
    );
  }


  /// Kembalikan semua konfigurasi ke nilai default
  void resetToDefaults() {
    state = state.copyWith(
      values: Map<String, dynamic>.from(defaultValues),
    );
  }

  /// Simpan pengaturan dan catat diff audit log
  List<String> save(Map<String, dynamic> submittedValues, {String by = 'UW'}) {
    final List<String> changedFields = [];
    final now = DateTime.now();
    final nowStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final entry in defaultValues.entries) {
      final key = entry.key;
      final current = state.values[key];
      final submitted = submittedValues[key] ?? current;

      if (submitted != null && submitted.toString() != current.toString()) {
        final label = fieldLabels[key] ?? key;
        changedFields.add(label);
      }
    }

    String txt;
    if (changedFields.isEmpty) {
      txt = 'Tidak ada perubahan';
    } else {
      final firstFew = changedFields.take(6).join(', ');
      final suffix = changedFields.length > 6 ? ', …' : '';
      txt = '${changedFields.length} nilai diubah: $firstFew$suffix';
    }

    final newLog = SettingRatesChargesLogEntry(at: nowStr, by: by, txt: txt);
    final newLogs = [newLog, ...state.logs];

    state = state.copyWith(
      values: Map<String, dynamic>.from(state.values)..addAll(submittedValues),
      logs: newLogs,
    );

    return changedFields;
  }

  }

/// Provider Riverpod untuk modul Setting Rates & Charges.
final settingRatesChargesProvider =
    NotifierProvider<SettingRatesChargesNotifier, SettingRatesChargesState>(
  SettingRatesChargesNotifier.new,
);
