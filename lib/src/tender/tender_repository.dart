import 'dart:convert';
import '../network/api_client.dart';

/// One co-insurer share on a won tender.
class TenderShare {
  final String? partyType; // LEADER | MEMBER
  final String? name;
  final double? percentage;
  const TenderShare({this.partyType, this.name, this.percentage});
  factory TenderShare.fromJson(Map<String, dynamic> j) => TenderShare(
        partyType: j['partyType'],
        name: j['name'],
        percentage: j['percentage'] != null ? (j['percentage'] as num).toDouble() : null,
      );
}

/// One tender in the report (won or lost), labelled by its Nama Tender.
class TenderItem {
  final String pipelineId;
  final String? tenderNo;
  final String? tenderName;
  final String? customerName;
  final String? status; // Menang | Kalah | Berjalan
  final String? metode;
  final String? kanwil;
  final String? kc;
  final String? rmName;
  final String? pipelineName;
  final String? stage;
  final String? product;
  final double? tsi;
  final double? premi; // won
  final String? periodeMulai;
  final String? periodeSelesai;
  final String? batasPenawaran;
  final String? pengumumanPemenang;
  final double? shareAskrindo; // won, %
  final String? lossReason; // loss
  final List<TenderShare> shares; // won

  const TenderItem({
    required this.pipelineId,
    this.tenderNo,
    this.tenderName,
    this.customerName,
    this.status,
    this.metode,
    this.kanwil,
    this.kc,
    this.rmName,
    this.pipelineName,
    this.stage,
    this.product,
    this.tsi,
    this.premi,
    this.periodeMulai,
    this.periodeSelesai,
    this.batasPenawaran,
    this.pengumumanPemenang,
    this.shareAskrindo,
    this.lossReason,
    this.shares = const [],
  });

  String get title => (tenderName != null && tenderName!.isNotEmpty)
      ? tenderName!
      : (customerName ?? 'Tender tanpa nama');

  factory TenderItem.fromJson(Map<String, dynamic> j) => TenderItem(
        pipelineId: j['pipelineId'] ?? j['pipe'] ?? j['id'] ?? '',
        tenderNo: j['tenderNo'] ?? j['no'],
        tenderName: j['tenderName'] ?? j['nama'] ?? j['name'],
        customerName: j['customerName'] ?? j['bumnName'] ?? j['bumn'],
        status: j['status'],
        metode: j['metode'],
        kanwil: j['kanwil'] ?? j['wil'],
        kc: j['kc'],
        rmName: j['rmName'] ?? j['rm'],
        pipelineName: j['pipelineName'] ?? j['pipeName'],
        stage: j['stage'],
        product: j['product'] ?? j['prod'],
        tsi: j['tsi'] != null ? (j['tsi'] as num).toDouble() : null,
        premi: j['premi'] != null ? (j['premi'] as num).toDouble() : null,
        periodeMulai: j['periodeMulai'] ?? j['mulai'],
        periodeSelesai: j['periodeSelesai'] ?? j['selesai'],
        batasPenawaran: j['batasPenawaran'] ?? j['batas'],
        pengumumanPemenang: j['pengumumanPemenang'] ?? j['hasil'],
        shareAskrindo:
            j['shareAskrindo'] != null ? (j['shareAskrindo'] as num).toDouble() : null,
        lossReason: j['lossReason'] ?? j['alasan'],
        shares: (j['shares'] as List<dynamic>? ?? [])
            .map((s) => TenderShare.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class TenderReport {
  final int wonCount;
  final int lossCount;
  final int activeCount; // P3/P2/P1; counted in winRate, not listed
  final List<TenderItem> won;
  final List<TenderItem> loss;

  const TenderReport({
    this.wonCount = 0,
    this.lossCount = 0,
    this.activeCount = 0,
    this.won = const [],
    this.loss = const [],
  });

  /// Tenders the report actually lists — drives the filter chips and the bar.
  int get total => wonCount + lossCount;

  /// Every tender that exists, including ones still being bid.
  int get totalWithActive => total + activeCount;

  double get winRate => totalWithActive > 0 ? wonCount / totalWithActive : 0;

  factory TenderReport.fromJson(Map<String, dynamic> j) => TenderReport(
        wonCount: j['wonCount'] ?? 0,
        lossCount: j['lossCount'] ?? 0,
        activeCount: j['activeCount'] ?? 0,
        won: (j['won'] as List<dynamic>? ?? [])
            .map((e) => TenderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        loss: (j['loss'] as List<dynamic>? ?? [])
            .map((e) => TenderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TenderRepository {
  final ApiClient apiClient;
  TenderRepository({required this.apiClient});

  Future<TenderReport> getReport() async {
    try {
      final response = await apiClient.get('/api/tenders/report');
      if (response.statusCode == 200) {
        return TenderReport.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fallback ke data prototype saat offline / dev
    }
    return _prototypeReport();
  }

  static TenderReport _prototypeReport() {
    return const TenderReport(
      wonCount: 4,
      lossCount: 2,
      activeCount: 4,
      won: [
        TenderItem(
          pipelineId: 'bp3',
          tenderNo: 'TDR/ADHI/2026/0451',
          tenderName: 'Asuransi CAR Pembangunan Gedung Kantor Pusat',
          customerName: 'PT Adhi Karya (Persero) Tbk',
          status: 'Menang',
          premi: 18000000,
          tsi: 15000000000,
          product: 'CAR / Contractor All Risk',
          periodeMulai: '2026-10-15',
          periodeSelesai: '2028-04-15',
          batasPenawaran: '2026-08-26',
          pengumumanPemenang: '2026-09-10',
          metode: 'Tender Terbuka',
          pipelineName: 'Pembangunan Gedung Kantor Pusat',
          stage: 'Won',
          kanwil: 'Kantor Wilayah 1',
          kc: 'Padang',
          rmName: 'Mohammad Ridwan Majid',
          shareAskrindo: 60.0,
          shares: [
            TenderShare(partyType: 'MEMBER', name: 'Jasindo', percentage: 40.0),
          ],
        ),
        TenderItem(
          pipelineId: 'bp5',
          tenderNo: 'TDR/ASDP/2026/0310',
          tenderName: 'Pekerjaan Perpanjangan Asuransi Kapal Penyeberangan Lintas Merak',
          customerName: 'PT ASDP Indonesia Ferry (Persero)',
          status: 'Menang',
          premi: 139900000,
          tsi: 95000000000,
          product: 'Marine Hull',
          periodeMulai: '2026-08-01',
          periodeSelesai: '2027-07-31',
          batasPenawaran: '2026-06-28',
          pengumumanPemenang: '2026-07-12',
          metode: 'Tender Terbuka',
          pipelineName: 'Perpanjangan Asuransi Kapal Merak',
          stage: 'Won',
          kanwil: 'Kantor Wilayah 1',
          kc: 'Padang',
          rmName: 'Mohammad Ridwan Majid',
        ),
        TenderItem(
          pipelineId: 'bp6',
          tenderNo: 'TDR/JASINDO/2026/0144',
          tenderName: 'Asuransi Properti Gudang & Fasilitas Operasional',
          customerName: 'PT Asuransi Jasa Indonesia (Jasindo)',
          status: 'Menang',
          premi: 59400000,
          tsi: 48000000000,
          product: 'IAR / Industrial All Risk',
          periodeMulai: '2026-07-01',
          periodeSelesai: '2027-06-30',
          batasPenawaran: '2026-05-30',
          pengumumanPemenang: '2026-06-14',
          metode: 'Tender Terbatas',
          pipelineName: 'Properti Gudang & Operasional',
          stage: 'Won',
          kanwil: 'Kantor Wilayah 1',
          kc: 'Padang',
          rmName: 'Mohammad Ridwan Majid',
        ),
        TenderItem(
          pipelineId: 'bp8',
          tenderNo: 'TDR/BNI/2026/0233',
          tenderName: 'Asuransi Kecelakaan Diri Nasabah KUR',
          customerName: 'PT Bank Negara Indonesia (Persero) Tbk',
          status: 'Menang',
          premi: 71000,
          tsi: 50000000,
          product: 'PSAKDI – Personal',
          periodeMulai: '2026-09-01',
          periodeSelesai: '2027-08-31',
          batasPenawaran: '2026-07-15',
          pengumumanPemenang: '2026-07-29',
          metode: 'Penunjukan Langsung',
          pipelineName: 'Kecelakaan Diri Nasabah KUR',
          stage: 'Won',
          kanwil: 'Kantor Wilayah 1',
          kc: 'Padang',
          rmName: 'Mohammad Ridwan Majid',
        ),
      ],
      loss: [
        TenderItem(
          pipelineId: 'bp4',
          tenderNo: 'TDR/APG/2026/0198',
          tenderName: 'Asuransi Kecelakaan Diri Pekerja Proyek',
          customerName: 'PT Adhi Persada Gedung',
          status: 'Kalah',
          premi: 2400000,
          tsi: 1600000000,
          product: 'PSAKDI – Personal (Group)',
          periodeMulai: '2026-09-01',
          periodeSelesai: '2027-08-31',
          batasPenawaran: '2026-08-07',
          pengumumanPemenang: '2026-08-21',
          metode: 'Penunjukan Langsung',
          pipelineName: 'Kecelakaan Diri Pekerja Proyek',
          stage: 'Decline',
          kanwil: 'Kantor Wilayah 1',
          kc: 'Padang',
          rmName: 'Mohammad Ridwan Majid',
          lossReason: 'Kalah harga penawaran premi dengan kompetitor',
        ),
        TenderItem(
          pipelineId: 'bp7',
          tenderNo: 'TDR/IAS/2026/0067',
          tenderName: 'Jaminan Uang Muka Pengembangan Bandara',
          customerName: 'PT Integrasi Aviasi Solusi',
          status: 'Kalah',
          premi: 3150000,
          tsi: 1050000000,
          product: 'Surety Bond',
          periodeMulai: '2026-08-15',
          periodeSelesai: '2027-02-15',
          batasPenawaran: '2026-06-20',
          pengumumanPemenang: '2026-07-18',
          metode: 'Tender Terbuka',
          pipelineName: 'Jaminan Uang Muka Bandara',
          stage: 'Decline',
          kanwil: 'Kantor Wilayah 1',
          kc: 'Padang',
          rmName: 'Mohammad Ridwan Majid',
          lossReason: 'Persyaratan administrasi tidak sesuai ketentuan panitia',
        ),
      ],
    );
  }
}
