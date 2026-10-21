import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../qs_form_state.dart';

/// Panel preview dokumen Quotation Slip (QS) resmi Askrindo
/// 100% identik dengan tampilan prototype Web (Prototype_QS_M-BIS.html).
class QsPreviewPanel extends StatelessWidget {
  final QsProduct product;
  final QsStatus status;
  final QsType type;
  final QsPremiMode premiMode;

  // Identitas
  final String nomorQs;
  final String namaPolis;
  final String alamat;
  final String bidangUsaha;

  // Tertanggung
  final String namaTertanggung;
  final String noKtp;
  final DateTime? tglLahir;
  final String pekerjaan;

  // Periode
  final DateTime? tglMulai;
  final DateTime? tglAkhir;
  final int jumlahHari;
  final int jumlahOrang;
  final String? aktivitas;

  // Jaminan PSAKDI
  final PsakdiRiskType riskType;
  final double upA;
  final double upC;
  final bool risikoC;
  final int? klasifikasiPeserta;

  // Jaminan PA Xtra
  final double upPaXtra;
  final bool cacatTetap;
  final bool perawatanPengobatan;
  final Map<String, double> santunanValues;

  // Premi
  final PremiResult? premiResult;
  final String risikoDijamin;
  final double diskonPersen;
  final QsPolisType polisType;

  // Penerbitan
  final String kota;
  final DateTime? tglPenerbitan;
  final String cabang;
  final String penandatangan;
  final String jabatan;
  final DateTime? masaBerlaku;

  // Deviasi UW
  final List<UwDeviation> deviations;

  const QsPreviewPanel({
    super.key,
    required this.product,
    required this.status,
    required this.type,
    required this.premiMode,
    required this.nomorQs,
    required this.namaPolis,
    required this.alamat,
    required this.bidangUsaha,
    required this.namaTertanggung,
    required this.noKtp,
    required this.tglLahir,
    required this.pekerjaan,
    required this.tglMulai,
    required this.tglAkhir,
    required this.jumlahHari,
    required this.jumlahOrang,
    this.aktivitas,
    required this.riskType,
    required this.upA,
    required this.upC,
    required this.risikoC,
    required this.klasifikasiPeserta,
    required this.upPaXtra,
    required this.cacatTetap,
    required this.perawatanPengobatan,
    required this.santunanValues,
    required this.premiResult,
    required this.risikoDijamin,
    required this.diskonPersen,
    required this.polisType,
    required this.kota,
    required this.tglPenerbitan,
    required this.cabang,
    required this.penandatangan,
    required this.jabatan,
    required this.masaBerlaku,
    required this.deviations,
  });

  static final _curr = NumberFormat('#,##0', 'id');
  static final _curr2 = NumberFormat('#,##0.00', 'id');

  bool get _isDraft => status == QsStatus.draft;
  bool get _isGroup => type == QsType.group;
  bool get _isPax => product == QsProduct.paXtra;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '[belum diisi]';
    return formatTglIndo(dt, longMonth: true);
  }

  String _formatCurr(num? val) {
    if (val == null || val == 0) return '0';
    return _curr.format(val);
  }

  String _formatCurr2(num? val) {
    if (val == null || val == 0) return '0,00';
    return _curr2.format(val);
  }

  static const _skalaBenefit = [
    ['1', 'Lengan kanan mulai dari sendi bahu', '60%'],
    ['2', 'Lengan kiri mulai dari sendi bahu', '50%'],
    ['3', 'Lengan kanan mulai dari atasnya sendi siku', '50%'],
    ['4', 'Lengan kiri mulai dari atasnya sendi siku', '40%'],
    ['5', 'Tangan kanan mulai dari atasnya pergelangan tangan', '40%'],
    ['6', 'Tangan kiri mulai dari atasnya pergelangan tangan', '30%'],
    ['7', 'Satu kaki mulai dari lutut sampai pangkal paha', '50%'],
    ['8', 'Satu kaki mulai dari mata kaki sampai lutut', '25%'],
    ['9', 'Ibu jari tangan kanan', '15%'],
    ['10', 'Ibu jari tangan kiri', '10%'],
    ['11', 'Jari telunjuk tangan kanan', '10%'],
    ['12', 'Jari telunjuk tangan kiri', '8%'],
    ['13', 'Jari kelingking tangan kanan', '8%'],
    ['14', 'Jari kelingking tangan kiri', '6%'],
    ['15', 'Jari tengah atau manis tangan kanan', '5%'],
    ['16', 'Jari tengah atau manis tangan kiri', '4%'],
    ['17', 'Satu ibu jari kaki', '8%'],
    ['18', 'Satu jari kaki lainnya', '5%'],
    ['19', 'Sebelah mata', '50%'],
    ['20', 'Pendengaran pada kedua belah telinga', '50%'],
    ['21', 'Pendengaran pada sebelah telinga', '25%'],
    ['22', 'Sebelah daun telinga secara keseluruhan', '5%'],
  ];

  static const _klausulaStandar = [
    'Cyber Risk Exclusion Clause - NMA 2915',
    'Industries, Seepage, Pollution and Contamination Clause – NMA 1685 (Sudden and Accidental)',
    'Information Technology Hazards Clarification Clause - NMA 2912',
    'Transmission and Distribution Line Exclusion Clause',
    'Sanction Limitation and Exclusion Clause',
    'War and Civil War Exclusion Clause - NMA 464',
    'Electronic Date Recognition Endorsement A - NMA 2800 11/12/1997',
    'Nuclear Energy Risk Exclusion Clause 1994 - NMA 1975',
    'Terrorism and Sabotage Exclusion Clause',
    'Extra Contractual Obligations Exclusion Endorsement',
    'LMA 5396 Communicable Disease Exclusion Clause',
    'Klausula Risiko Mengendarai Sepeda Motor dan Sejenisnya',
    'Premium Payment Warranty Clause',
  ];

  static const _kondisiStandar = [
    'Klaim wajib dilaporkan kepada Penanggung dalam jangka waktu yang ditentukan dalam polis.',
    'Setiap penambahan atau pengurangan peserta wajib diinformasikan kepada Penanggung.',
    'Premi harus terlebih dahulu dilunasi dengan jatuh tempo sebagaimana yang tercantum dalam polis sebelum pertanggungan aktif berlaku.',
  ];

  static const _warantiStandar = [
    'Tidak melakukan aktivitas/olahraga yang berisiko tinggi.',
    'Tidak melakukan pekerjaan dengan tingkat risiko yang lebih tinggi dari yang telah diinformasikan dan disetujui.',
  ];

  static const _santunanDefs = [
    {
      'key': 'ambulan',
      'no': '2.',
      'title': 'Biaya Ambulan',
      'desc':
          'Santunan biaya transportasi ambulan darat/laut/udara ke fasilitas medis terdekat.',
      'max': false,
    },
    {
      'key': 'pemakaman',
      'no': '3.',
      'title': 'Biaya Pemakaman',
      'desc':
          'Santunan biaya penyelenggaraan pemakaman/kremasi bagi Tertanggung yang meninggal dunia akibat kecelakaan.',
      'max': false,
    },
    {
      'key': 'barang',
      'no': '4.',
      'title': 'Penggantian Biaya Barang Pribadi',
      'desc':
          'Penggantian atas kehilangan/kerusakan barang pribadi akibat kecelakaan lalu lintas.',
      'max': true,
    },
    {
      'key': 'dokumen',
      'no': '5.',
      'title': 'Kerusakan Dokumen Pribadi',
      'desc':
          'Penggantian biaya pengurusan kembali dokumen penting (KTP, SIM, Paspor) yang rusak/hilang akibat kecelakaan.',
      'max': true,
    },
    {
      'key': 'pendidikan',
      'no': '6.',
      'title': 'Biaya Pendidikan Anak',
      'desc':
          'Santunan biaya pendidikan anak yang sah dari Tertanggung yang meninggal dunia atau cacat tetap total akibat kecelakaan.',
      'max': false,
    },
    {
      'key': 'repatriasi',
      'no': '7.',
      'title': 'Repatriasi Jenazah',
      'desc': 'Santunan biaya pemulangan jenazah ke daerah asal.',
      'max': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPreviewDoc,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowDoc1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: AppColors.shadowDoc2,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildIdentitasUtama(),
                _buildRincianPertanggungan(),
                _buildRisikoSendiriDanKlausula(),
                _buildPremiSection(),
                _buildKlaimSection(),
                _buildCatatanDanTandaTangan(),
                _buildLampiranKlausula(),
                _buildFooterAskrindo(),
              ],
            ),
          ),
          if (_isDraft) _draftWatermark(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Watermark
  // ──────────────────────────────────────────────────────────────────────────

  Widget _draftWatermark() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            maxHeight: double.infinity,
            maxWidth: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                8,
                (_) => Transform.rotate(
                  angle: -0.5236, // -30 degrees
                  child: const Text(
                    'DRAFT',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: AppColors.watermarkDraft,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Header (Logo & No. Quotation)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/askrindo-logo.png',
            height: 46,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const Text(
              'ASKRINDO INSURANCE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.navyMbis,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              const Text(
                'QUOTATION',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 5.0,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'No. $nomorQs',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Garis pemisah ganda kop surat
        Column(
          children: const [
            Divider(height: 3, thickness: 3, color: AppColors.textDark),
            SizedBox(height: 2),
            Divider(height: 1, thickness: 1, color: AppColors.textDark),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Identitas Utama
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildIdentitasUtama() {
    final wordingText = _isPax
        ? 'Personal Accident Xtra Insurance'
        : 'Polis Standar Asuransi Kecelakaan Diri Indonesia';

    final risikoText = risikoDijamin.trim().isNotEmpty
        ? risikoDijamin
        : (_isPax
            ? 'Meninggal Dunia / Cacat Tetap, Biaya Pengobatan dan santunan-santunan yang disebabkan karena kecelakaan.'
            : 'Meninggal Dunia / Cacat Tetap dan Biaya Pengobatan yang disebabkan karena kecelakaan.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _docRow('Jenis Pertanggungan', 'Asuransi Kecelakaan Diri'),
        _docRow('Wording', wordingText),
        _docRow('Risiko dijamin', risikoText),
        _docRow('Pemegang Polis', namaPolis.isNotEmpty ? namaPolis : namaTertanggung),
        _docRow('Alamat Tertanggung', alamat),
        _docRow('Bidang Usaha', bidangUsaha),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Rincian Pertanggungan
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRincianPertanggungan() {
    final effectiveUpA = _isPax ? upPaXtra : upA;
    final luasLabel = _isGroup ? 'Luas Jaminan per-orang' : 'Luas Jaminan';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionRibbon('RINCIAN PERTANGGUNGAN'),
        const SizedBox(height: 4),
        _docRow(
          'Jangka Waktu Pertanggungan',
          'Mulai dari tanggal ${_formatDate(tglMulai)} sampai dengan ${_formatDate(tglAkhir)} kedua tanggal tersebut pada pukul 12.00 siang waktu setempat dimana orang yang dipertanggungkan berada.',
          isJustify: true,
        ),
        if (_isGroup) ...[
          _docRow('Aktivitas/Kegiatan', aktivitas ?? '-'),
        ],
        const SizedBox(height: 6),
        const Text(
          'Orang yang dipertanggungkan',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        if (_isGroup)
          _docRow('Jumlah', '$jumlahOrang orang', indent: 16),
        _docRow('Nama', namaTertanggung, indent: 16),
        _docRow('Nomor KTP', noKtp.isNotEmpty ? noKtp : (_isGroup ? 'TBA' : '[belum diisi]'), indent: 16),
        _docRow('Tanggal Lahir', tglLahir != null ? _formatDate(tglLahir) : (_isGroup ? 'TBA' : '[belum diisi]'), indent: 16),
        _docRow('Pekerjaan', pekerjaan, indent: 16),

        const SizedBox(height: 4),
        _docRow(
          luasLabel,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cedera badan akibat kecelakaan yang secara langsung mengakibatkan Kematian dan/atau Cacat atau timbulnya Biaya Pengobatan pada Tertanggung yang terjadi saat menjalankan aktivitas maupun saat bepergian.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.45,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 4),

              if (!_isPax) ...[
                // PSAKDI Luas Jaminan
                _buildPsakdiLuasJaminan(effectiveUpA),
              ] else ...[
                // PA Xtra Luas Jaminan
                _buildPaXtraLuasJaminan(effectiveUpA),
              ],
            ],
          ),
        ),

        const SizedBox(height: 4),
        _docRow('Pengecualian', 'Sesuai klausula standar polis'),
      ],
    );
  }

  Widget _buildPsakdiLuasJaminan(double effectiveUpA) {
    final hasB = riskType == PsakdiRiskType.ab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              flex: 64,
              child: Text(
                'A  Kematian akibat kecelakaan.',
                style: TextStyle(fontSize: 10.5, color: AppColors.textDark),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 36,
              child: Text(
                'IDR ${_formatCurr(effectiveUpA)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        if (hasB) ...[
          const Text(
            'B  Cacat Tetap',
            style: TextStyle(fontSize: 10.5, color: AppColors.textDark),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(
                      flex: 64,
                      child: Text('1. Cacat Tetap Keseluruhan',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 36,
                      child: Text('100% Uang Pertanggungan A',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _buildCacatTetapKeseluruhanKeterangan(),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(
                      flex: 64,
                      child: Text('2. Cacat Tetap Sebagian',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 36,
                      child: Text(
                        'Prosentase Uang Pertanggungan A sesuai Tabel Skala Benefit',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Cacat Tetap Sebagian berupa hilang atau tidak berfungsinya sebagian dari anggota tubuh. Hak atas santunan ini berlaku setelah dokter menetapkan keadaan cacat tetap yang diderita.',
                  style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.textDark),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 6),
                _buildTabelSkalaBenefit(),
                const SizedBox(height: 4),
                _buildSkalaKeterangan(),
              ],
            ),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                flex: 64,
                child: Text('B  Cacat Tetap', style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
              ),
              SizedBox(width: 6),
              Expanded(
                flex: 36,
                child: Text('Tidak dijamin', style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              flex: 64,
              child: Text('C  Biaya Pengobatan',
                  style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 36,
              child: Text(
                risikoC ? 'IDR ${_formatCurr(upC)} (Maksimum)' : 'Tidak dijamin',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textDark),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaXtraLuasJaminan(double effectiveUpA) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A  Jaminan Pokok',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 64,
                child: Text('Kematian akibat kecelakaan.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 36,
                child: Text(
                  'IDR ${_formatCurr(effectiveUpA)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'B  Jaminan Tambahan',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        if (cacatTetap) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Cacat Tetap',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Expanded(
                            flex: 64,
                            child: Text('a. Cacat Tetap Keseluruhan',
                                style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            flex: 36,
                            child: Text('100% Uang Pertanggungan A',
                                style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _buildCacatTetapKeseluruhanKeterangan(),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Expanded(
                            flex: 64,
                            child: Text('b. Cacat Tetap Sebagian',
                                style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            flex: 36,
                            child: Text(
                              'Prosentase Uang Pertanggungan A sesuai Tabel Skala Benefit',
                              style: TextStyle(fontSize: 10.5, color: AppColors.textDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Cacat Tetap Sebagian berupa hilang atau tidak berfungsinya sebagian dari anggota tubuh. Hak atas santunan ini berlaku setelah dokter menetapkan keadaan cacat tetap yang diderita.',
                        style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.textDark),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 6),
                      _buildTabelSkalaBenefit(),
                      const SizedBox(height: 4),
                      _buildSkalaKeterangan(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  flex: 64,
                  child: Text('1. Cacat Tetap', style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 36,
                  child: Text('Tidak diasuransikan',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                ),
              ],
            ),
          ),
        ],

        // Santunan-santunan PA Xtra
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Column(
            children: _santunanDefs.map((cfg) {
              final key = cfg['key'] as String;
              final no = cfg['no'] as String;
              final title = cfg['title'] as String;
              final desc = cfg['desc'] as String;
              final isMax = cfg['max'] as bool;
              final val = santunanValues[key] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 64,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$no $title',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark)),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text(
                              desc,
                              style: const TextStyle(
                                  fontSize: 9.5, height: 1.35, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 36,
                      child: Text(
                        val > 0
                            ? 'IDR ${_formatCurr(val)}${isMax ? '\n(Maksimum)' : ''}'
                            : 'Tidak diasuransikan',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: val > 0 ? FontWeight.w600 : FontWeight.normal,
                          color: val > 0 ? AppColors.blueInputText : AppColors.textMuted,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCacatTetapKeseluruhanKeterangan() {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cacat Tetap Keseluruhan meliputi :',
              style: TextStyle(fontSize: 10, color: AppColors.textDark)),
          const SizedBox(height: 1),
          _subBulletItem('a.', 'kehilangan penglihatan kedua belah mata, atau'),
          _subBulletItem('b.', 'hilang atau tidak berfungsinya kedua lengan, atau'),
          _subBulletItem('c.', 'hilang atau tidak berfungsinya kedua tungkai kaki, atau'),
          _subBulletItem(
            'd.',
            'hilang atau tidak berfungsinya: penglihatan satu mata dan satu lengan; penglihatan satu mata dan satu tungkai kaki; atau satu tungkai kaki dan satu lengan.',
          ),
          const SizedBox(height: 2),
          const Text(
            'Dapat diartikan pula sebagai Cacat Tetap Keseluruhan, dalam hal kegilaan atau kelumpuhan total yang diderita Tertanggung sebagai akibat langsung dari suatu kecelakaan yang dijamin polis.',
            style: TextStyle(fontSize: 10, height: 1.35, color: AppColors.textDark),
            textAlign: TextAlign.justify,
          ),
          const Text(
            'Cacat Tetap ini harus terjadi dalam waktu 12 (dua belas) bulan sejak terjadinya kecelakaan.',
            style: TextStyle(fontSize: 10, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTabelSkalaBenefit() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.textDark)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.textDark)),
            ),
            child: const Text('Tabel Skala Benefit',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.textDark)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 22,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text('No',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.textDark),
                        right: BorderSide(color: AppColors.textDark),
                      ),
                    ),
                    child: const Text('Uraian',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(
                  width: 62,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text('Prosentase',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
          ..._skalaBenefit.map((row) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderTable)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
                      child: Text(row[0],
                          style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.center),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.textDark),
                          right: BorderSide(color: AppColors.textDark),
                        ),
                      ),
                      child: Text(row[1],
                          style: const TextStyle(fontSize: 9.5, color: AppColors.textDark)),
                    ),
                  ),
                  SizedBox(
                    width: 62,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
                      child: Text(row[2],
                          style: const TextStyle(fontSize: 9.5, color: AppColors.textDark),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSkalaKeterangan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keterangan :',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 1),
        _subBulletItem(
          'a.',
          'Jumlah persentase dari seluruh cacat tetap yang diderita selama jangka waktu pertanggungan tidak melebihi 100% Nilai Pertanggungan untuk Jaminan B',
        ),
        _subBulletItem(
          'b.',
          'Bagi orang kidal pengertian kata ”kanan” dibaca ”kiri” dan sebaliknya',
        ),
        _subBulletItem(
          'c.',
          'Dalam hal kehilangan atas sebagian dari salah satu yang disebutkan di dalam tabel diatas, maka akan diberikan jumlah santunan secara berbanding (menurut perbandingan) dalam angka persentase yang lebih kecil dari skala persentase yang bersangkutan dengan bagian yang hilang itu',
        ),
        _subBulletItem(
          'd.',
          'Dalam hal kehilangan atau tidak berfungsinya lebih dari satu jari, maka santunan yang diberikan untuk itu tidak melebihi yang telah ditetapkan untuk kehilangan tangan dari pergelangan tangan',
        ),
        _subBulletItem(
          'e.',
          'Dalam hal tidak berfungsinya anggota badan yang tercantum dalam tabel, santunan diberikan apabila tidak berfungsinya anggota badan tersebut mencapai 50% (lima puluh persen) atau lebih berdasarkan Surat Keterangan Dokter yang melakukan perawatan.',
        ),
        const SizedBox(height: 3),
        const Text(
          'Apabila Tertanggung telah menerima santunan dalam hal Cacat Tetap, kemudian akibat kecelakaan yang sama itu Tertanggung meninggal dunia maka hak atas santunan dalam hal Kematian akan diberikan setelah dikurangi dengan jumlah santunan Cacat Tetap yang telah dibayarkan. Jika santunan Cacat Tetap yang telah dibayar lebih besar daripada santunan Kematian, maka Tertanggung tidak berhak atas santunan Kematian',
          style: TextStyle(fontSize: 9.5, height: 1.35, color: AppColors.textDark),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  Widget _subBulletItem(String prefix, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Text(prefix, style: const TextStyle(fontSize: 9.5, color: AppColors.textDark)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 9.5, height: 1.35, color: AppColors.textDark),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Risiko Sendiri, Klausula, Kondisi & Waranti
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRisikoSendiriDanKlausula() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionRibbon('RISIKO SENDIRI , KLAUSULA, KONDISI & WARANTI'),
        const SizedBox(height: 4),
        _docRow('Risiko Sendiri', _isPax ? 'Sesuai ketentuan' : 'Nil'),
        _docRow('Klausula, Kondisi & Waranti', 'Terlampir'),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Premi
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPremiSection() {
    final p = premiResult;
    final sukuPremiStr = _getSukuPremiString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionRibbon('PREMI'),
        const SizedBox(height: 4),
        _docRow('Suku Premi', sukuPremiStr),
        _docRow('Perhitungan Premi', ''),
        const SizedBox(height: 2),

        // Perhitungan Baris
        if (p != null) ...[
          _buildCalculationRows(p),
        ] else ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Premi belum dihitung.',
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.textMuted),
            ),
          ),
        ],
      ],
    );
  }

  double _getRateAB() {
    if (_isPax) {
      return cacatTetap
          ? defaultPaXtraRatePokokWithCacatTetap
          : defaultPaXtraRatePokokWithoutCacatTetap;
    }
    final kIdx = ((klasifikasiPeserta ?? 1) - 1).clamp(0, 3);
    final key = riskType == PsakdiRiskType.ab ? 'AB' : 'A';
    return defaultPsakdiRates[key]![kIdx];
  }

  double _getRateC() {
    final kIdx = ((klasifikasiPeserta ?? 1) - 1).clamp(0, 3);
    return defaultPsakdiRates['C']![kIdx];
  }

  String _getSukuPremiString() {
    if (premiMode == QsPremiMode.mutlak) return '-';
    if (premiMode == QsPremiMode.flat) {
      final days = jumlahHari > 0 ? jumlahHari : 1;
      final persons = jumlahOrang > 0 ? jumlahOrang : 1;
      final flatPerDay = (premiResult?.premiPokok ?? 0) / (days * persons);
      return 'FLAT : IDR ${_formatCurr2(flatPerDay)} per-hari';
    }
    final rateAB = _getRateAB();
    if (product == QsProduct.psakdi && risikoC) {
      final rateC = _getRateC();
      return '${riskType == PsakdiRiskType.ab ? "AB" : "A"} : ${rateAB.toStringAsFixed(2)} % per-tahun\nC : ${rateC.toStringAsFixed(2)} % per-tahun';
    }
    return '${_isPax ? "Pokok" : (riskType == PsakdiRiskType.ab ? "AB" : "A")} : ${rateAB.toStringAsFixed(2)} % per-tahun';
  }

  Widget _buildCalculationRows(PremiResult p) {
    final effectiveUpA = _isPax ? upPaXtra : upA;
    final rateAB = _getRateAB();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (premiMode == QsPremiMode.normal) ...[
          _calcRow(
            'IDR ${_formatCurr(effectiveUpA)} x ${rateAB.toStringAsFixed(2)} % x $jumlahHari/365',
            'IDR ${_formatCurr2(p.premiPokok)}',
          ),
          if (product == QsProduct.psakdi && risikoC && p.premiTambahan > 0) ...[
            _calcRow(
              'IDR ${_formatCurr(upC)} x ${_getRateC().toStringAsFixed(2)} % x $jumlahHari/365',
              'IDR ${_formatCurr2(p.premiTambahan)}',
            ),
          ],
        ] else if (premiMode == QsPremiMode.mutlak) ...[
          _calcRow('Premi Pokok', 'IDR ${_formatCurr2(p.premiPokok)}'),
          if (p.premiTambahan > 0)
            _calcRow('Premi Jaminan Tambahan', 'IDR ${_formatCurr2(p.premiTambahan)}'),
        ] else if (premiMode == QsPremiMode.flat) ...[
          _calcRow(
            'IDR ${_formatCurr2(p.premiPokok / ((jumlahHari > 0 ? jumlahHari : 1) * (jumlahOrang > 0 ? jumlahOrang : 1)))} x $jumlahHari x $jumlahOrang',
            'IDR ${_formatCurr2(p.premiPokok)}',
          ),
        ],

        if (diskonPersen > 0) ...[
          _calcRow(
            'Disc ${diskonPersen.toStringAsFixed(diskonPersen.truncateToDouble() == diskonPersen ? 0 : 2)} %',
            'IDR ${_formatCurr2(p.diskon)}',
          ),
          _calcRow('Premi Netto', 'IDR ${_formatCurr2(p.netto)}'),
        ],
        if (p.biayaAdmin > 0) ...[
          _calcRow('Biaya Admin', 'IDR ${_formatCurr2(p.biayaAdmin)}'),
        ],
        const SizedBox(height: 2),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.textDark, width: 1.0)),
          ),
          padding: const EdgeInsets.only(top: 2),
          child: _calcRow(
            'Total',
            'IDR ${_formatCurr2(p.total)}',
            isBold: true,
          ),
        ),
      ],
    );
  }

  Widget _calcRow(String leftText, String rightText, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              leftText,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(
            width: 10,
            child: Text(':', style: TextStyle(fontSize: 10.5, color: AppColors.textDark), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 110,
            child: Text(
              rightText,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Klaim
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildKlaimSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionRibbon('KLAIM'),
        const SizedBox(height: 4),
        _docRow(
          'Pengajuan Klaim',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _BulletItem(
                  'Tertanggung / Ahli waris melaporkan kejadian yang dijamin polis kepada perusahaan asuransi paling lambat 30 (tiga puluh) hari kalender setelah kejadian.'),
              _BulletItem(
                  'Formulir pengajuan klaim yang telah diisi dan ditandatangani oleh Tertanggung / Ahli Waris'),
              _BulletItem('Kronologis Kejadian'),
            ],
          ),
          showColon: false,
        ),
        const SizedBox(height: 4),
        _docRow(
          'Dokumen Klaim',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('A.  Dokumen Utama',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
              _BulletItem('Fotokopi identitas tertanggung.'),
              _BulletItem('Fotokopi kartu keluarga.'),
              _BulletItem('Fotokopi sertifikat/polis asuransi.'),
              SizedBox(height: 3),
              Text('B.  Dokumen Khusus',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
              Text('Klaim Meninggal Dunia',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline)),
              _BulletItem('Surat keterangan kematian.'),
              _BulletItem(
                  'Surat keterangan dokter atau rumah sakit mengenai penyebab kematian.'),
              _BulletItem(
                  'Surat keterangan kepolisian/berita acara kecelakaan apabila meninggal dunia akibat kecelakaan lalu lintas atau kecelakaan lainnya.'),
              _BulletItem(
                  'Dokumen identitas dan bukti hubungan ahli waris/penerima manfaat.'),
              SizedBox(height: 2),
              Text('Klaim Cacat Tetap',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline)),
              _BulletItem(
                  'Surat keterangan dokter yang menjelaskan kondisi dan tingkat cacat tetap.'),
              _BulletItem('Resume medis atau rekam medis.'),
              _BulletItem(
                  'Hasil pemeriksaan medis atau pemeriksaan penunjang, jika diperlukan.'),
              _BulletItem(
                  'Surat keterangan kepolisian apabila cacat tetap disebabkan oleh kecelakaan yang perlu dilaporkan kepada pihak berwenang.'),
              SizedBox(height: 2),
              Text('Klaim Biaya Pengobatan',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline)),
              _BulletItem(
                  'Kwitansi asli biaya pengobatan atau dokumen pembayaran yang sah.'),
              _BulletItem(
                  'Rincian biaya/perincian tagihan dari rumah sakit atau klinik.'),
              _BulletItem('Surat keterangan dokter.'),
              _BulletItem(
                  'Resep obat dan/atau bukti pembelian obat, apabila relevan.'),
              _BulletItem(
                  'Hasil pemeriksaan medis atau dokumen medis pendukung.'),
              _BulletItem(
                  'Surat keterangan kepolisian apabila diperlukan berdasarkan jenis kecelakaan.'),
              SizedBox(height: 3),
              Text('C.  Dokumen Tambahan',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
              _BulletItem(
                  'Surat Keterangan Ahli Waris (Jika Klaim diajukan oleh Ahli Waris)'),
              _BulletItem(
                  'Dokumen pendukung lain sesuai permintaan perusahaan asuransi'),
            ],
          ),
          showColon: false,
        ),
        const SizedBox(height: 4),
        _docRow(
          'Pembayaran Klaim',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _BulletItem(
                  'Pembayaran klaim maksimal 30 (tiga puluh) hari kalender sejak dokumen lengkap diterima dan disetujui atau sejak tanggal persetujuan klaim oleh Penanggung.'),
              _BulletItem(
                  'Pembayaran klaim akan ditransfer ke Nomor Rekening Tertanggung / Ahli Waris yang ditunjuk.'),
            ],
          ),
          showColon: false,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 7. Catatan, Tanda Tangan & Konfirmasi
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCatatanDanTandaTangan() {
    final validDateStr = _formatDate(masaBerlaku ?? tglPenerbitan?.add(const Duration(days: 14)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 52,
              child: Text(
                'Catatan',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(
              width: 10,
              child: Text(':', style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
            ),
            Expanded(
              child: Text(
                'Penawaran ini dimaksudkan untuk memberikan gambaran atas risiko, tarif, serta syarat & ketentuan dari asuransi yang akan diberlakukan sehingga tidak dapat dijadikan sebagai bukti bahwa risiko telah dijamin. Penawaran ini valid sampai dengan tanggal $validDateStr',
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.45,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Tanda tangan 2 kolom
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kolom Askrindo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${kota.isNotEmpty ? kota : "Padang"}, ${_formatDate(tglPenerbitan)}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textDark),
                  ),
                  const Text(
                    'PT ASURANSI KREDIT INDONESIA',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  Text(
                    'CABANG ${cabang.isNotEmpty ? cabang.toUpperCase() : "PADANG"}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 52),
                  Text(
                    penandatangan.isNotEmpty ? penandatangan : 'Sarno',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    jabatan.isNotEmpty ? jabatan : 'Pemimpin Cabang',
                    style: const TextStyle(fontSize: 10, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Kolom Konfirmasi Saudara
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Konfirmasi Saudara',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                  const Text('Tanggal :',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textDark)),
                  const SizedBox(height: 70),
                  Text(
                    '( ${namaTertanggung.isNotEmpty ? namaTertanggung : namaPolis} )',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 8. Lampiran Klausula, Kondisi & Waranti
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLampiranKlausula() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: AppColors.borderUploadDashed),
        const SizedBox(height: 10),
        _docRow(
          'Klausula',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _klausulaStandar.map((t) => _BulletItem(t)).toList(),
          ),
          flexLabel: 22,
          flexValue: 78,
        ),
        const SizedBox(height: 6),
        _docRow(
          'Kondisi',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _kondisiStandar.map((t) => _BulletItem(t)).toList(),
          ),
          flexLabel: 22,
          flexValue: 78,
        ),
        const SizedBox(height: 6),
        _docRow(
          'Waranti',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _warantiStandar.map((t) => _BulletItem(t)).toList(),
          ),
          flexLabel: 22,
          flexValue: 78,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 9. Footer Resmi Askrindo
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildFooterAskrindo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.textDark, width: 3.0),
            ),
          ),
          padding: const EdgeInsets.only(left: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'PT. Asuransi Kredit Indonesia (Persero)',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Graha Askrindo, Jl. Angkasa Blok B-9, Kav.8, Kota Baru Bandar Kemayoran, Jakarta 10610, INDONESIA\nP: +6221 6546471 / 72, F: +6221 6546483 / 84, E: askrindo@askrindo.co.id, W : www.askrindo.co.id, Call Center : 1500-405',
                style: TextStyle(
                  fontSize: 8.5,
                  height: 1.35,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(height: 6, color: AppColors.blueFooterAskrindo),
            ),
            Expanded(
              flex: 1,
              child: Container(height: 6, color: AppColors.orangeMbis),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper Widgets
  // ──────────────────────────────────────────────────────────────────────────

  Widget _sectionRibbon(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      decoration: const BoxDecoration(
        color: AppColors.ribbonBlue,
        border: Border(top: BorderSide(color: AppColors.textDark, width: 1.0)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _docRow(
    String label,
    dynamic value, {
    int flexLabel = 36,
    int flexValue = 64,
    double indent = 0,
    bool showColon = true,
    bool isJustify = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: flexLabel,
            child: Padding(
              padding: EdgeInsets.only(left: indent),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textDark,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (showColon)
            const SizedBox(
              width: 10,
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textDark,
                  height: 1.45,
                ),
              ),
            ),
          Expanded(
            flex: flexValue,
            child: value is Widget
                ? value
                : Text(
                    (value == null || value.toString().trim().isEmpty)
                        ? '[belum diisi]'
                        : value.toString(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textDark,
                      height: 1.45,
                    ),
                    textAlign: isJustify ? TextAlign.justify : TextAlign.left,
                  ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 12,
            child: Text('-', style: TextStyle(fontSize: 10, color: AppColors.textDark)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                height: 1.35,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
}
