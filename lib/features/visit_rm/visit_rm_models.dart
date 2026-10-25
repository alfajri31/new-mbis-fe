import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RmModel {
  final String id;
  final String nama;
  final String jab;
  final String cab;

  const RmModel({
    required this.id,
    required this.nama,
    required this.jab,
    required this.cab,
  });
}

class KanwilModel {
  final String id;
  final String name;
  final List<String> cab;

  const KanwilModel({
    required this.id,
    required this.name,
    required this.cab,
  });
}

class VisitModel {
  final String id;
  final String rmId;
  final String perusahaan;
  final String tanggal; // YYYY-MM-DD
  final String jam; // HH:mm
  final String stage; // 'P3', 'P2', 'P1', 'WON'
  final double nilai;
  final bool foto;
  final String lokasi;
  final String tujuan;
  final String hasil;
  final String tindakLanjut;
  final String? pipelineId;

  const VisitModel({
    required this.id,
    required this.rmId,
    required this.perusahaan,
    required this.tanggal,
    required this.jam,
    required this.stage,
    required this.nilai,
    required this.foto,
    required this.lokasi,
    required this.tujuan,
    required this.hasil,
    required this.tindakLanjut,
    this.pipelineId,
  });
}

class VisitReview {
  final String reviewer;
  final String reviewedAt;
  final String note;

  const VisitReview({
    required this.reviewer,
    required this.reviewedAt,
    required this.note,
  });
}

class StageBadgeInfo {
  final String label;
  final Color bg;
  final Color fg;

  const StageBadgeInfo({
    required this.label,
    required this.bg,
    required this.fg,
  });
}

class VisitRmHelpers {
  static const List<LinearGradient> avatarGradients = [
    LinearGradient(
      colors: [AppColors.avatarGradientBlue1, AppColors.blueFooterAskrindo],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.avatarGradientOrange1, AppColors.alertTitle],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.avatarGradientGreen1, AppColors.greenTotal],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.avatarGradientPurple1, AppColors.avatarGradientPurple2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  static LinearGradient getAvatarGradient(String visitId) {
    final numStr = visitId.replaceAll(RegExp(r'[^0-9]'), '');
    final numVal = int.tryParse(numStr) ?? 0;
    return avatarGradients[numVal % avatarGradients.length];
  }

  static StageBadgeInfo getStageInfo(String stage) {
    switch (stage.toUpperCase()) {
      case 'P2':
        return const StageBadgeInfo(
          label: 'P2 · Proses',
          bg: AppColors.badgeP2Bg,
          fg: AppColors.alertTitle,
        );
      case 'P1':
        return const StageBadgeInfo(
          label: 'P1 · Penerbitan',
          bg: AppColors.badgeP1Bg,
          fg: AppColors.greenTotal,
        );
      case 'WON':
        return const StageBadgeInfo(
          label: 'Won',
          bg: AppColors.greenTotal,
          fg: AppColors.surfaceWhite,
        );
      case 'P3':
      default:
        return const StageBadgeInfo(
          label: 'P3 · Prospek',
          bg: AppColors.blueLightBg,
          fg: AppColors.navyMbis,
        );
    }
  }

  static String formatRupiah(num amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  static const List<String> indonesianMonths = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> indonesianDays = [
    'Minggu',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  static String formatIndoDate(String yyyyMmDd) {
    try {
      final parts = yyyyMmDd.split('-');
      if (parts.length != 3) return yyyyMmDd;
      final year = parts[0];
      final month = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      final mName = month >= 1 && month <= 12 ? indonesianMonths[month] : '';
      return '$day $mName $year';
    } catch (_) {
      return yyyyMmDd;
    }
  }

  static String formatDateTime(DateTime dt) {
    try {
      final mName = dt.month >= 1 && dt.month <= 12 ? indonesianMonths[dt.month] : '';
      return '${dt.day} $mName ${dt.year}';
    } catch (_) {
      return dt.toIso8601String();
    }
  }


  static String getDayName(String yyyyMmDd) {
    try {
      final dt = DateTime.parse(yyyyMmDd);
      return indonesianDays[dt.weekday % 7];
    } catch (_) {
      return '';
    }
  }

  static String getDateLabel(String yyyyMmDd, String todayStr, String yesterdayStr) {
    final formatted = formatIndoDate(yyyyMmDd);
    if (yyyyMmDd == todayStr) {
      return 'Hari ini · $formatted';
    } else if (yyyyMmDd == yesterdayStr) {
      return 'Kemarin · $formatted';
    } else {
      final day = getDayName(yyyyMmDd);
      return '$day · $formatted';
    }
  }

  static String getCompanyInitials(String company) {
    final cleaned = company.replaceAll(RegExp(r'^(PT|CV)\s+', caseSensitive: false), '').trim();
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).toList();
    if (words.isEmpty) return 'RM';
    return words.map((w) => w[0].toUpperCase()).join();
  }

  static String getKanwilName(String cab) {
    for (final k in kDefaultKanwils) {
      if (k.cab.contains(cab)) return k.name;
    }
    return '-';
  }

  static double getTsi(VisitModel v) {
    if (v.pipelineId != null && v.pipelineId == 'p1') {
      return 100000000;
    }
    return (v.nilai / 0.005 / 1e6).round() * 1e6;
  }

  static const Map<String, List<double>> cabCoordinates = {
    'Padang': [-0.9471, 100.4172],
    'Pekanbaru': [0.5071, 101.4478],
    'Medan': [3.5952, 98.6722],
    'Jakarta Selatan': [-6.2615, 106.8106],
    'Bandung': [-6.9175, 107.6191],
    'Pontianak': [-0.0263, 109.3425],
  };

  static (String, String) getCoordinates(String visitId, String cab) {
    final base = cabCoordinates[cab] ?? const [-0.9471, 100.4172];
    final numStr = visitId.replaceAll(RegExp(r'[^0-9]'), '');
    final k = int.tryParse(numStr) ?? 1;
    final lat = (base[0] + ((k * 37) % 60 - 30) / 1000).toStringAsFixed(4);
    final lng = (base[1] + ((k * 53) % 60 - 30) / 1000).toStringAsFixed(4);
    return (lat, lng);
  }

  static String getStatusKerjaSama(VisitModel v) {
    if (RegExp(r'^(PT|CV)\s', caseSensitive: false).hasMatch(v.perusahaan)) {
      return 'KORPORASI';
    }
    return 'INDIVIDU';
  }

  static VisitAttributes getAttributes(VisitModel v) {
    if (kVisitAttributes.containsKey(v.id)) {
      return kVisitAttributes[v.id]!;
    }
    final isBank = RegExp(r'bank', caseSensitive: false).hasMatch(v.perusahaan);
    return VisitAttributes(
      kat: isBank ? 'Perbankan' : 'Non Perbankan',
      ent: 'Non BUMN',
      hvc: false,
      sumber: 'DIRECT',
      cob: 'Asuransi Umum',
      lob: 'Asuransi Kecelakaan Diri',
      toc: 'PSAKDI – Personal',
    );
  }
}

class VisitAttributes {
  final String kat;
  final String ent;
  final bool hvc;
  final String sumber;
  final String cob;
  final String lob;
  final String toc;

  const VisitAttributes({
    required this.kat,
    required this.ent,
    required this.hvc,
    required this.sumber,
    required this.cob,
    required this.lob,
    required this.toc,
  });
}

const Map<String, VisitAttributes> kVisitAttributes = {
  'v1': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v2': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: true, sumber: 'BROKER', cob: 'Asuransi Umum', lob: 'Asuransi Harta Benda', toc: 'IAR / Industrial All Risk'),
  'v3': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PSAKDI – Personal'),
  'v4': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'AGEN', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PSAKDI – Personal'),
  'v5': VisitAttributes(kat: 'Non Perbankan', ent: 'BUMN', hvc: true, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v6': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: true, sumber: 'BROKER', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v7': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'AGEN', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PSAKDI – Personal'),
  'v8': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v9': VisitAttributes(kat: 'Non Perbankan', ent: 'BUMN', hvc: true, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v11': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Rekayasa', toc: 'CAR / Contractor All Risk'),
  'v12': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: true, sumber: 'BROKER', cob: 'Asuransi Umum', lob: 'Asuransi Harta Benda', toc: 'IAR / Industrial All Risk'),
  'v13': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PSAKDI – Personal'),
  'v15': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'AGEN', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PSAKDI – Personal'),
  'v16': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v17': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'AGEN', cob: 'Asuransi Umum', lob: 'Asuransi Kendaraan Bermotor', toc: 'Kendaraan Pengangkut Barang'),
  'v18': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v19': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: true, sumber: 'BROKER', cob: 'Suretyship', lob: 'Suretyship', toc: 'Surety Bond'),
  'v20': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Harta Benda', toc: 'IAR / Industrial All Risk'),
  'v21': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'AGEN', cob: 'Asuransi Umum', lob: 'Asuransi Kendaraan Bermotor', toc: 'Kendaraan Pengangkut Barang'),
  'v22': VisitAttributes(kat: 'Perbankan', ent: 'Non BUMN', hvc: true, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PA Xtra – Personal'),
  'v23': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'DIRECT', cob: 'Asuransi Umum', lob: 'Asuransi Kecelakaan Diri', toc: 'PSAKDI – Personal'),
  'v24': VisitAttributes(kat: 'Non Perbankan', ent: 'Non BUMN', hvc: false, sumber: 'BROKER', cob: 'Asuransi Umum', lob: 'Asuransi Harta Benda', toc: 'IAR / Industrial All Risk'),
};

// Default static mock data matching prototype
const List<KanwilModel> kDefaultKanwils = [
  KanwilModel(
    id: 'W1',
    name: 'Kantor Wilayah 1',
    cab: ['Padang', 'Pekanbaru', 'Medan'],
  ),
  KanwilModel(
    id: 'W2',
    name: 'Kantor Wilayah 2',
    cab: ['Jakarta Selatan', 'Bandung', 'Pontianak'],
  ),
];

const List<RmModel> kDefaultRms = [
  RmModel(id: 'r1', nama: 'Mohammad Ridwan Majid', jab: 'Associate II RM', cab: 'Padang'),
  RmModel(id: 'r2', nama: 'Siti Rahmawati', jab: 'Senior RM', cab: 'Padang'),
  RmModel(id: 'r3', nama: 'Hendra Saputra', jab: 'Associate RM', cab: 'Padang'),
  RmModel(id: 'r4', nama: 'Andi Pratama', jab: 'RM', cab: 'Pekanbaru'),
  RmModel(id: 'r5', nama: 'Rina Kartika', jab: 'Associate II RM', cab: 'Pekanbaru'),
  RmModel(id: 'r6', nama: 'Dedi Kurniawan', jab: 'Senior RM', cab: 'Medan'),
  RmModel(id: 'r7', nama: 'Lina Marpaung', jab: 'Associate RM', cab: 'Medan'),
  RmModel(id: 'r8', nama: 'Rima Maharani', jab: 'Senior RM', cab: 'Jakarta Selatan'),
  RmModel(id: 'r9', nama: 'Yusuf Hidayat', jab: 'RM', cab: 'Jakarta Selatan'),
  RmModel(id: 'r10', nama: 'Fajar Nugroho', jab: 'RM', cab: 'Bandung'),
  RmModel(id: 'r11', nama: 'Maya Lestari', jab: 'Associate II RM', cab: 'Pontianak'),
  RmModel(id: 'r12', nama: 'Bagas Wicaksono', jab: 'Associate RM', cab: 'Pontianak'),
];

/// Data kunjungan kini diambil langsung dari API backend (/api/visit-monitor/**).
/// [kDefaultVisits] dikosongkan agar tidak ada fallback data dummy/mock.
const List<VisitModel> kDefaultVisits = [];

class VisitReviewStore extends ChangeNotifier {
  static final VisitReviewStore instance = VisitReviewStore._();
  VisitReviewStore._();

  final Map<String, VisitReview> _reviews = {};
  Map<String, VisitReview> get reviews => Map.unmodifiable(_reviews);

  VisitReview? getReview(String visitId) => _reviews[visitId];

  bool isReviewed(String visitId) => _reviews.containsKey(visitId);

  int get reviewedCount => _reviews.length;

  void markReviewed(String visitId, String reviewer, String note) {
    _reviews[visitId] = VisitReview(
      reviewer: reviewer,
      reviewedAt: '23 Sep 2026 · 16:00 WIB',
      note: note,
    );
    notifyListeners();
  }

  void unmarkReviewed(String visitId) {
    _reviews.remove(visitId);
    notifyListeners();
  }
}

