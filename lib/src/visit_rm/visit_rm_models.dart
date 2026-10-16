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

  VisitModel copyWith({
    String? id,
    String? rmId,
    String? perusahaan,
    String? tanggal,
    String? jam,
    String? stage,
    double? nilai,
    bool? foto,
    String? lokasi,
    String? tujuan,
    String? hasil,
    String? tindakLanjut,
    String? pipelineId,
  }) {
    return VisitModel(
      id: id ?? this.id,
      rmId: rmId ?? this.rmId,
      perusahaan: perusahaan ?? this.perusahaan,
      tanggal: tanggal ?? this.tanggal,
      jam: jam ?? this.jam,
      stage: stage ?? this.stage,
      nilai: nilai ?? this.nilai,
      foto: foto ?? this.foto,
      lokasi: lokasi ?? this.lokasi,
      tujuan: tujuan ?? this.tujuan,
      hasil: hasil ?? this.hasil,
      tindakLanjut: tindakLanjut ?? this.tindakLanjut,
      pipelineId: pipelineId ?? this.pipelineId,
    );
  }
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
}

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

const List<VisitModel> kDefaultVisits = [
  VisitModel(
    id: 'v1',
    rmId: 'r8',
    perusahaan: 'PT Futura Nusantara Sejahtera',
    tanggal: '2026-09-23',
    jam: '10:15',
    stage: 'P2',
    nilai: 9153500,
    foto: true,
    lokasi: 'Jl. TB Simatupang Kav. 18, Jakarta Selatan',
    tujuan: 'Presentasi penawaran PA Xtra untuk karyawan lapangan',
    hasil: 'PIC tertarik, minta simulasi premi untuk 120 karyawan',
    tindakLanjut: 'Kirim QS PA Xtra Group paling lambat 25 Sep',
  ),
  VisitModel(
    id: 'v2',
    rmId: 'r8',
    perusahaan: 'PT Enerco RPO International',
    tanggal: '2026-09-23',
    jam: '14:40',
    stage: 'P1',
    nilai: 394183636,
    foto: false,
    lokasi: 'Menara Kuningan Lt. 12, Jakarta Selatan',
    tujuan: 'Finalisasi dokumen penutupan',
    hasil: 'Dokumen underwriting lengkap, menunggu tanda tangan direksi',
    tindakLanjut: 'Follow-up tanda tangan SPPA',
  ),
  VisitModel(
    id: 'v3',
    rmId: 'r1',
    perusahaan: 'Darmo',
    tanggal: '2026-09-23',
    jam: '09:05',
    stage: 'P3',
    nilai: 50000000,
    foto: true,
    lokasi: 'Jl Pelangi Raya No.56, Padang',
    tujuan: 'Kunjungan perkenalan produk PSAKDI',
    hasil: 'Nasabah setuju dibuatkan QS PSAKDI Single',
    tindakLanjut: 'Terbitkan QS dan kirim via WhatsApp',
    pipelineId: 'p1',
  ),
  VisitModel(
    id: 'v4',
    rmId: 'r9',
    perusahaan: 'PT Kasmar Matano Persada',
    tanggal: '2026-09-22',
    jam: '11:20',
    stage: 'P2',
    nilai: 20412000,
    foto: false,
    lokasi: 'Jl. Fatmawati No. 22, Jakarta Selatan',
    tujuan: 'Negosiasi rate dan diskon',
    hasil: 'Nasabah minta diskon 15%',
    tindakLanjut: 'Ajukan persetujuan diskon ke Pinca',
  ),
  VisitModel(
    id: 'v5',
    rmId: 'r2',
    perusahaan: 'PT Semen Padang (Persero)',
    tanggal: '2026-09-22',
    jam: '13:30',
    stage: 'P3',
    nilai: 275000000,
    foto: true,
    lokasi: 'Indarung, Padang',
    tujuan: 'Penjajakan asuransi kecelakaan diri karyawan pabrik',
    hasil: 'Diminta proposal untuk 1.200 karyawan',
    tindakLanjut: 'Siapkan QS Group Normal',
  ),
  VisitModel(
    id: 'v6',
    rmId: 'r4',
    perusahaan: 'PT Riau Andalan Kertas',
    tanggal: '2026-09-22',
    jam: '09:45',
    stage: 'P2',
    nilai: 118500000,
    foto: true,
    lokasi: 'Pangkalan Kerinci, Pelalawan',
    tujuan: 'Review kebutuhan perluasan santunan',
    hasil: 'Butuh santunan pemulangan jenazah dan biaya pendidikan',
    tindakLanjut: 'Revisi QS PA Xtra dengan perluasan',
  ),
  VisitModel(
    id: 'v7',
    rmId: 'r10',
    perusahaan: 'PT Era Salvindo',
    tanggal: '2026-09-21',
    jam: '15:10',
    stage: 'P3',
    nilai: 15298239,
    foto: false,
    lokasi: 'Jl. Asia Afrika No. 8, Bandung',
    tujuan: 'Perkenalan produk',
    hasil: 'Menunggu data jumlah karyawan',
    tindakLanjut: 'Hubungi HRD minggu depan',
  ),
  VisitModel(
    id: 'v8',
    rmId: 'r8',
    perusahaan: 'PT Prima Jaya Sentosa',
    tanggal: '2026-09-21',
    jam: '10:00',
    stage: 'WON',
    nilai: 62081250,
    foto: true,
    lokasi: 'Jl. Gatot Subroto Kav. 52, Jakarta Selatan',
    tujuan: 'Serah terima polis',
    hasil: 'Polis diterima, premi sudah dibayar',
    tindakLanjut: 'Tawarkan perpanjangan tahun depan',
  ),
  VisitModel(
    id: 'v9',
    rmId: 'r6',
    perusahaan: 'PT Perkebunan Nusantara III',
    tanggal: '2026-09-20',
    jam: '10:30',
    stage: 'P2',
    nilai: 210000000,
    foto: true,
    lokasi: 'Jl. Sei Batang Hari No. 2, Medan',
    tujuan: 'Presentasi PA Xtra Group untuk pekerja kebun',
    hasil: 'Perlu konfirmasi klasifikasi pekerjaan',
    tindakLanjut: 'Diskusi dengan underwriting',
  ),
  VisitModel(
    id: 'v10',
    rmId: 'r1',
    perusahaan: 'Budi Santoso',
    tanggal: '2026-09-19',
    jam: '16:00',
    stage: 'P3',
    nilai: 100000000,
    foto: false,
    lokasi: 'Jl. Sudirman No. 12, Padang',
    tujuan: 'Penawaran PA Xtra perorangan',
    hasil: 'Nasabah membandingkan dengan produk lain',
    tindakLanjut: 'Kirim QS PA Xtra Single',
    pipelineId: 'p2',
  ),
  VisitModel(
    id: 'v11',
    rmId: 'r11',
    perusahaan: 'PT Kalbar Sumber Energi',
    tanggal: '2026-09-19',
    jam: '11:15',
    stage: 'P3',
    nilai: 48000000,
    foto: true,
    lokasi: 'Jl. Ahmad Yani No. 5, Pontianak',
    tujuan: 'Perkenalan dan survei kebutuhan',
    hasil: 'Tertarik untuk karyawan proyek',
    tindakLanjut: 'Jadwalkan presentasi lanjutan',
  ),
  VisitModel(
    id: 'v12',
    rmId: 'r5',
    perusahaan: 'PT Chevron Pacific Indonesia',
    tanggal: '2026-09-18',
    jam: '09:20',
    stage: 'P1',
    nilai: 530000000,
    foto: true,
    lokasi: 'Rumbai, Pekanbaru',
    tujuan: 'Klarifikasi syarat & ketentuan',
    hasil: 'Klausul tambahan disetujui',
    tindakLanjut: 'Finalisasi QS dan penerbitan',
  ),
  VisitModel(
    id: 'v13',
    rmId: 'r9',
    perusahaan: 'PT Prose Technologies Indonesia',
    tanggal: '2026-09-17',
    jam: '13:45',
    stage: 'P2',
    nilai: 33750000,
    foto: true,
    lokasi: 'SCBD Lot 9, Jakarta Selatan',
    tujuan: 'Presentasi PSAKDI Group',
    hasil: 'Butuh persetujuan manajemen',
    tindakLanjut: 'Follow-up 1 minggu',
  ),
  VisitModel(
    id: 'v14',
    rmId: 'r2',
    perusahaan: 'ACA',
    tanggal: '2026-09-16',
    jam: '10:10',
    stage: 'P3',
    nilai: 120000000,
    foto: false,
    lokasi: 'Jl. Veteran No. 3, Padang',
    tujuan: 'Diskusi kebutuhan IAR',
    hasil: 'Menunggu data aset',
    tindakLanjut: 'Survei lokasi',
    pipelineId: 'p3',
  ),
  VisitModel(
    id: 'v15',
    rmId: 'r10',
    perusahaan: 'PT Bandung Textile Mills',
    tanggal: '2026-09-15',
    jam: '14:00',
    stage: 'P2',
    nilai: 76500000,
    foto: true,
    lokasi: 'Jl. Raya Dayeuhkolot, Bandung',
    tujuan: 'Negosiasi premi Flat untuk acara gathering',
    hasil: 'Setuju skema Flat 3 hari',
    tindakLanjut: 'Kirim QS Flat',
  ),
  VisitModel(
    id: 'v16',
    rmId: 'r6',
    perusahaan: 'PT Medan Sugar Industry',
    tanggal: '2026-09-14',
    jam: '11:40',
    stage: 'WON',
    nilai: 88000000,
    foto: true,
    lokasi: 'Kawasan Industri Medan II',
    tujuan: 'Penyerahan polis',
    hasil: 'Polis diserahkan ke HRD',
    tindakLanjut: 'Monitoring klaim',
  ),
  VisitModel(
    id: 'v17',
    rmId: 'r4',
    perusahaan: 'CV Sumber Rezeki Pekanbaru',
    tanggal: '2026-09-12',
    jam: '15:30',
    stage: 'P3',
    nilai: 12500000,
    foto: false,
    lokasi: 'Jl. Riau No. 21, Pekanbaru',
    tujuan: 'Perkenalan produk',
    hasil: 'Belum ada kebutuhan saat ini',
    tindakLanjut: 'Kunjungi kembali bulan depan',
  ),
  VisitModel(
    id: 'v18',
    rmId: 'r1',
    perusahaan: 'PT Andalas Agro Industri',
    tanggal: '2026-09-10',
    jam: '10:00',
    stage: 'P2',
    nilai: 65000000,
    foto: true,
    lokasi: 'Jl. Bypass KM 9, Padang',
    tujuan: 'Presentasi PA Xtra Group',
    hasil: 'Minta tambahan santunan ambulans',
    tindakLanjut: 'Revisi QS',
  ),
  VisitModel(
    id: 'v19',
    rmId: 'r8',
    perusahaan: 'PT Jaya Konstruksi Manggala',
    tanggal: '2026-09-08',
    jam: '09:30',
    stage: 'P1',
    nilai: 410000000,
    foto: true,
    lokasi: 'Jl. Ampera Raya, Jakarta Selatan',
    tujuan: 'Klarifikasi Kelas 3 pekerja proyek',
    hasil: 'Rate disetujui',
    tindakLanjut: 'Penerbitan polis',
  ),
  VisitModel(
    id: 'v20',
    rmId: 'r11',
    perusahaan: 'PT Borneo Sawit Lestari',
    tanggal: '2026-09-05',
    jam: '13:00',
    stage: 'P3',
    nilai: 95000000,
    foto: false,
    lokasi: 'Jl. Gajah Mada, Pontianak',
    tujuan: 'Penjajakan kebutuhan',
    hasil: 'Diminta proposal',
    tindakLanjut: 'Siapkan QS',
  ),
  VisitModel(
    id: 'v21',
    rmId: 'r5',
    perusahaan: 'PT Pekanbaru Mitra Logistik',
    tanggal: '2026-09-03',
    jam: '10:45',
    stage: 'P2',
    nilai: 27000000,
    foto: true,
    lokasi: 'Jl. Soekarno-Hatta, Pekanbaru',
    tujuan: 'Negosiasi diskon',
    hasil: 'Setuju diskon 10%',
    tindakLanjut: 'Kirim QS final',
  ),
  VisitModel(
    id: 'v22',
    rmId: 'r2',
    perusahaan: 'PT Bank Nagari',
    tanggal: '2026-08-28',
    jam: '09:00',
    stage: 'P2',
    nilai: 180000000,
    foto: true,
    lokasi: 'Jl. Pemuda No. 21, Padang',
    tujuan: 'Presentasi PA untuk nasabah KUR',
    hasil: 'Diminta skema Group',
    tindakLanjut: 'Siapkan QS Group',
  ),
  VisitModel(
    id: 'v23',
    rmId: 'r9',
    perusahaan: 'PT Mitra Digital Nusantara',
    tanggal: '2026-08-25',
    jam: '14:15',
    stage: 'P3',
    nilai: 18000000,
    foto: false,
    lokasi: 'Jl. Kemang Raya, Jakarta Selatan',
    tujuan: 'Perkenalan produk',
    hasil: 'Tertarik untuk karyawan kantor',
    tindakLanjut: 'Kirim brosur',
  ),
  VisitModel(
    id: 'v24',
    rmId: 'r6',
    perusahaan: 'PT Sumatera Rubber Plantation',
    tanggal: '2026-08-20',
    jam: '10:30',
    stage: 'P3',
    nilai: 52000000,
    foto: false,
    lokasi: 'Tebing Tinggi, Sumatera Utara',
    tujuan: 'Survei kebutuhan',
    hasil: 'Menunggu rapat direksi',
    tindakLanjut: 'Follow-up bulan depan',
  ),
];

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

