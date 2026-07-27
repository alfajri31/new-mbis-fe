/// Pipeline sub-stages grouped by coarse bucket. Mirrors the backend
/// `PipelineSubStage` enum (and its bucket mapping). Single source of truth for
/// the status dropdown (detail) and the stage picker (add pipeline).
class SubStage {
  final String value; // enum value sent to backend, e.g. 'SURVEI'
  final String label; // human label, e.g. 'Survei'
  const SubStage(this.value, this.label);
}

class PipelineStages {
  PipelineStages._();

  /// Ordered bucket -> sub-stages.
  static const Map<String, List<SubStage>> byBucket = {
    'P3': [
      SubStage('INFO_AWAL', 'Baru ada Informasi'),
      SubStage('PENAWARAN_PRODUK', 'Penawaran Produk'),
      SubStage('VISITING_DEBITUR', 'Visiting Calon Debitur'),
      SubStage('MENUNGGU_SURAT_PERMOHONAN', 'Menunggu Surat Permohonan'),
    ],
    'P2': [
      SubStage('SURAT_PERMOHONAN_MASUK', 'Surat Permohonan Sudah Masuk'),
      SubStage('PEMENUHAN_ADMIN', 'Pemenuhan Persyaratan Administrasi'),
      SubStage('SURVEI', 'Survei'),
      SubStage('PROSES_ANALISA', 'Proses Analisa'),
      SubStage('NEGO_TC_RATE', 'Nego T&C / Rate'),
      SubStage('MENUNGGU_APPROVAL_MITRA', 'Menunggu Approval Mitra'),
      SubStage('MENUNGGU_BACKUP_REASURANSI', 'Menunggu Backup Reasuransi'),
    ],
    'P1': [
      SubStage('PROSES_PENERBITAN_POLIS', 'Proses Penerbitan Polis'),
    ],
    'WON': [
      SubStage('TERBIT_POLIS', 'Terbit Polis'),
    ],
    'DECLINE': [
      SubStage('DECLINE_UW', 'Decline (Dari UW)'),
      SubStage('CANCELED_CUSTOMER', 'Canceled (Customer)'),
    ],
  };

  static const Map<String, String> bucketLabel = {
    'P3': 'P3 — Prospek',
    'P2': 'P2 — Proses',
    'P1': 'P1 — Penerbitan',
    'WON': 'Won',
    'DECLINE': 'Decline',
  };

  /// All sub-stages, in bucket order.
  static List<SubStage> get all => byBucket.values.expand((e) => e).toList();

  /// The display label for a sub-stage enum value (falls back to the raw value).
  static String labelOf(String? value) {
    if (value == null || value.isEmpty) return '-';
    for (final s in all) {
      if (s.value == value) return s.label;
    }
    return value;
  }

  /// The bucket (P3/P2/P1/WON/DECLINE) a sub-stage belongs to.
  static String bucketOf(String subStageValue) {
    for (final entry in byBucket.entries) {
      if (entry.value.any((s) => s.value == subStageValue)) return entry.key;
    }
    return '';
  }
}
