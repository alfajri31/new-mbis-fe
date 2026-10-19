import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import 'qs_form_state.dart';
import 'widgets/qs_step_pertanggungan.dart';
import 'widgets/qs_step_uang_pertanggungan.dart';
import 'widgets/qs_step_terms_conditions.dart';
import 'widgets/qs_preview_panel.dart';

/// Screen utama pembuatan Quotation Slip.
///
/// Mengikuti desain prototype M-BIS (Prototype_QS_M-BIS.html):
/// Header Navy terpadu dengan 3 progress bars (Pertanggungan, UP & Premi, T&C),
/// banner auto-fill, legend warna teks biru, bottom bar dengan total premi kalkulasi,
/// dan transisi penuh ke Preview QS dengan status deviasi UW.
class QsFormScreen extends StatefulWidget {
  final QsProduct product;

  /// Mock data — di implementasi nyata akan diterima dari pipeline.
  final String? customerName;
  final String? customerAddress;
  final String? customerBidangUsaha;
  final String? customerEmail;

  const QsFormScreen({
    super.key,
    this.product = QsProduct.psakdi,
    this.customerName,
    this.customerAddress,
    this.customerBidangUsaha,
    this.customerEmail,
  });

  @override
  State<QsFormScreen> createState() => _QsFormScreenState();
}

class _QsFormScreenState extends State<QsFormScreen>
    with TickerProviderStateMixin {
  // Product state
  late QsProduct _product;

  // Status & Navigation
  QsStatus _status = QsStatus.draft;
  int _currentStep = 0;
  bool _isPreviewing = false;
  final _currFormat = NumberFormat('#,##0', 'id');

  // Form keys per step
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // ── Tab 1: Pertanggungan ──
  late final TextEditingController _namaPolisCtrl;
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _bidangUsahaCtrl;
  late final TextEditingController _emailCtrl;
  final _namaPicCtrl = TextEditingController();
  final _noHpPicCtrl = TextEditingController();
  QsType _type = QsType.single;
  final _jumlahOrangCtrl = TextEditingController(text: '1');
  final _aktivitasCtrl = TextEditingController();
  QsPremiMode _premiMode = QsPremiMode.normal;
  DateTime? _tglMulai;
  DateTime? _tglAkhir;
  bool _dataSamaPolis = false;
  final _namaTertanggungCtrl = TextEditingController(text: 'Suwito');
  final _noKtpCtrl = TextEditingController(text: '3202145123112');
  DateTime? _tglLahir = DateTime(2000, 2, 14);
  final _pekerjaanCtrl = TextEditingController(text: 'Karyawan');
  int? _klasifikasiPeserta = 1;

  // ── Tab 2: Uang Pertanggungan ──
  final _upACtrl = TextEditingController();
  PsakdiRiskType _riskType = PsakdiRiskType.ab;
  bool _risikoC = false;
  final _upCCtrl = TextEditingController();
  final _rateABCtrl = TextEditingController();
  final _rateCCtrl = TextEditingController();
  final _upPaXtraCtrl = TextEditingController();
  bool _cacatTetap = true;
  bool _perawatanPengobatan = false;
  final Map<String, TextEditingController> _santunanCtrls = {
    for (final key in santunanLabels.keys) key: TextEditingController(),
  };
  final _risikoDijaminCtrl = TextEditingController();
  final _diskonCtrl = TextEditingController(text: '0');
  QsPolisType _polisType = QsPolisType.cetak;
  final _premiMutlakPokokCtrl = TextEditingController();
  final _premiMutlakTambahanCtrl = TextEditingController();
  final _tarifFlatCtrl = TextEditingController();

  // ── Tab 3: T/C ──
  final _kotaCtrl = TextEditingController();
  final _cabangCtrl = TextEditingController();
  final _penandatanganCtrl = TextEditingController();
  final _jabatanCtrl = TextEditingController();
  DateTime? _tglPenerbitan;
  DateTime? _masaBerlaku;
  final _klausulTambahanCtrl = TextEditingController();
  final _kondisiTambahanCtrl = TextEditingController();
  final _warantiTambahanCtrl = TextEditingController();
  final _pengecualianTambahanCtrl = TextEditingController();
  final _deductibleCtrl = TextEditingController(text: 'Nil');
  String? _namaFile;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _namaPolisCtrl =
        TextEditingController(text: widget.customerName ?? 'PT Prima Kaplas');
    _alamatCtrl = TextEditingController(
        text: widget.customerAddress ?? 'Jl Pelangi Raya No.56 Jakarta Selatan');
    _bidangUsahaCtrl = TextEditingController(
        text: widget.customerBidangUsaha ?? 'Percetakan');
    _emailCtrl =
        TextEditingController(text: widget.customerEmail ?? '');

    // Default tanggal
    _tglMulai = DateTime.now();
    _tglAkhir = DateTime(
      DateTime.now().year + 1,
      DateTime.now().month,
      DateTime.now().day,
    );
    _tglPenerbitan = DateTime.now();
    _masaBerlaku = DateTime.now().add(const Duration(days: 14));

    // Default rate PSAKDI
    _rateABCtrl.text = '0.10';
    _rateCCtrl.text = '2.00';
  }

  @override
  void dispose() {
    _namaPolisCtrl.dispose();
    _alamatCtrl.dispose();
    _bidangUsahaCtrl.dispose();
    _emailCtrl.dispose();
    _namaPicCtrl.dispose();
    _noHpPicCtrl.dispose();
    _jumlahOrangCtrl.dispose();
    _aktivitasCtrl.dispose();
    _namaTertanggungCtrl.dispose();
    _noKtpCtrl.dispose();
    _pekerjaanCtrl.dispose();
    _upACtrl.dispose();
    _upCCtrl.dispose();
    _rateABCtrl.dispose();
    _rateCCtrl.dispose();
    _upPaXtraCtrl.dispose();
    for (final c in _santunanCtrls.values) {
      c.dispose();
    }
    _risikoDijaminCtrl.dispose();
    _diskonCtrl.dispose();
    _premiMutlakPokokCtrl.dispose();
    _premiMutlakTambahanCtrl.dispose();
    _tarifFlatCtrl.dispose();
    _kotaCtrl.dispose();
    _cabangCtrl.dispose();
    _penandatanganCtrl.dispose();
    _jabatanCtrl.dispose();
    _klausulTambahanCtrl.dispose();
    _kondisiTambahanCtrl.dispose();
    _warantiTambahanCtrl.dispose();
    _pengecualianTambahanCtrl.dispose();
    _deductibleCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Computed
  // ────────────────────────────────────────────────────────────────────────

  int get _jumlahHari {
    if (_tglMulai == null || _tglAkhir == null) return 0;
    return _tglAkhir!.difference(_tglMulai!).inDays;
  }

  int get _jumlahOrang =>
      _type == QsType.single ? 1 : (int.tryParse(_jumlahOrangCtrl.text) ?? 1);

  String get _nomorQs {
    final prod = _product == QsProduct.psakdi ? 'PSAKDI' : 'PAXTRA';
    final prefix = _status == QsStatus.draft ? 'XXX' : '001';
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '$prefix/QS-$prod/RO2-SBY/$mm/${now.year}';
  }

  List<UwDeviation> get _deviations => detectDeviations(
        product: _product,
        mode: _premiMode,
        kelasPeserta: _klasifikasiPeserta,
        saranKelasPeserta: saranKelas(_pekerjaanCtrl.text),
        rateAB: double.tryParse(_rateABCtrl.text),
        rateC: double.tryParse(_rateCCtrl.text),
        tarifFlatPerHari: double.tryParse(
            _tarifFlatCtrl.text.replaceAll('.', '').replaceAll(',', '')),
        tcTambahanDiubah: _klausulTambahanCtrl.text.isNotEmpty ||
            _kondisiTambahanCtrl.text.isNotEmpty ||
            _warantiTambahanCtrl.text.isNotEmpty ||
            _pengecualianTambahanCtrl.text.isNotEmpty,
        deductible: _deductibleCtrl.text,
      );

  double get _diskonPersen =>
      double.tryParse(_diskonCtrl.text) ?? 0;

  double get _biayaAdmin => biayaAdminForPolis(_polisType);

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  Map<String, double> get _santunanValues => {
        for (final e in _santunanCtrls.entries)
          e.key: _parseNum(e.value.text),
      };

  PremiResult? get _premiResult {
    final hari = _jumlahHari;
    if (hari <= 0) return null;
    final n = _jumlahOrang;

    if (_product == QsProduct.psakdi) {
      final up = _parseNum(_upACtrl.text);
      if (up <= 0) return null;

      switch (_premiMode) {
        case QsPremiMode.normal:
          return hitungPsakdiNormal(
            upA: up,
            riskType: _riskType,
            upC: _risikoC ? _parseNum(_upCCtrl.text) : null,
            rateAB: double.tryParse(_rateABCtrl.text) ?? 0,
            rateC: double.tryParse(_rateCCtrl.text) ?? 0,
            hari: hari,
            jumlahOrang: n,
            diskonPersen: _diskonPersen,
            biayaAdmin: _biayaAdmin,
          );
        case QsPremiMode.mutlak:
          final pokok = _parseNum(_premiMutlakPokokCtrl.text);
          final tambahan = _parseNum(_premiMutlakTambahanCtrl.text);
          final gross = pokok + tambahan;
          final disk = gross * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: pokok,
            premiTambahan: tambahan,
            gross: gross,
            diskon: disk,
            netto: gross - disk,
            biayaAdmin: _biayaAdmin,
            total: gross - disk + _biayaAdmin,
          );
        case QsPremiMode.flat:
          final tarif = _parseNum(_tarifFlatCtrl.text);
          final premi = tarif * hari * n;
          final disk = premi * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: premi,
            premiTambahan: 0,
            gross: premi,
            diskon: disk,
            netto: premi - disk,
            biayaAdmin: _biayaAdmin,
            total: premi - disk + _biayaAdmin,
          );
      }
    } else {
      // PA Xtra
      final up = _parseNum(_upPaXtraCtrl.text);
      if (up <= 0) return null;

      switch (_premiMode) {
        case QsPremiMode.normal:
          return hitungPaXtraNormal(
            up: up,
            cacatTetap: _cacatTetap,
            santunanValues: _santunanValues,
            hari: hari,
            jumlahOrang: n,
            diskonPersen: _diskonPersen,
            biayaAdmin: _biayaAdmin,
          );
        case QsPremiMode.mutlak:
          final pokok = _parseNum(_premiMutlakPokokCtrl.text);
          final tambahan = _parseNum(_premiMutlakTambahanCtrl.text);
          final gross = pokok + tambahan;
          final disk = gross * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: pokok,
            premiTambahan: tambahan,
            gross: gross,
            diskon: disk,
            netto: gross - disk,
            biayaAdmin: _biayaAdmin,
            total: gross - disk + _biayaAdmin,
          );
        case QsPremiMode.flat:
          final tarif = _parseNum(_tarifFlatCtrl.text);
          final premi = tarif * hari * n;
          final disk = premi * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: premi,
            premiTambahan: 0,
            gross: premi,
            diskon: disk,
            netto: premi - disk,
            biayaAdmin: _biayaAdmin,
            total: premi - disk + _biayaAdmin,
          );
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isPreviewing) {
      return _buildPreviewScreen();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgScaffold,
        body: Column(
          children: [
            // Header Navy sesuai prototype (lengkap dengan 3 progress bars)
            _buildHeader(),

            // Body form
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      children: [
                        // Banner auto-fill pada Langkah 1
                        if (_currentStep == 0) _buildAutoFillBanner(),

                        // Form aktif
                        _currentStepWidget(),

                        const SizedBox(height: 12),

                        // Legend teks biru
                        _buildFooterLegend(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom sticky navigation bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Responsive Header (Prototype 1:1 - Wide Desktop vs Mobile Stepper)
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1024;
        if (isWide) {
          return _buildHeaderWide();
        } else {
          return _buildHeaderMobile();
        }
      },
    );
  }

  /// Header mode Desktop / Web (lebar >= 1024px sesuai prototype isFormWide)
  Widget _buildHeaderWide() {
    final productLabel =
        _product == QsProduct.psakdi ? 'PSAKDI' : 'PA Xtra';
    final totalLbl =
        _product == QsProduct.paXtra ? 'Biaya Asuransi' : 'Total Premi';
    final totalVal = _premiResult?.total ?? 0;
    final totalTxt = 'Rp ${_currFormat.format(totalVal)}';
    final needsUw = _deviations.isNotEmpty;
    final uwBtnLabel = needsUw ? 'Minta Approval UW' : 'Terbitkan QS';

    return Container(
      color: AppColors.navyMbis,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Material(
              color: AppColors.whiteAlpha12,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _onBack,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QS Baru · $productLabel',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No. $_nomorQs',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.badgeDraftText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.whiteAlpha14,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.surfaceWhite,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalLbl,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.whiteAlpha75,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalTxt,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.badgeReadyText,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            OutlinedButton(
              onPressed: _simpanDraft,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.surfaceWhite,
                side: BorderSide(
                  color: AppColors.textWhite70,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 42),
              ),
              child: const Text(
                'Simpan Draft',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                if (needsUw) {
                  _ajukanKeUW();
                } else {
                  _finalisasi();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeMbis,
                foregroundColor: AppColors.surfaceWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 42),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 18, color: AppColors.surfaceWhite),
                  const SizedBox(width: 8),
                  Text(
                    uwBtnLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header mode Mobile (lebar < 1024px sesuai prototype isFormMobile)
  Widget _buildHeaderMobile() {
    final productLabel =
        _product == QsProduct.psakdi ? 'PSAKDI' : 'PA Xtra';
    const stepNames = [
      'Pertanggungan',
      'Uang Pertanggungan & Biaya Asuransi',
      'T/C (Syarat & Ketentuan)',
    ];
    final currentStepName = stepNames[_currentStep];

    return Container(
      color: AppColors.navyMbis,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Material(
                  color: AppColors.whiteAlpha12,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _onBack,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QS Baru · $productLabel',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surfaceWhite,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Langkah ${_currentStep + 1} dari 3 · $currentStepName',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.whiteAlpha78,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No. $_nomorQs',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.badgeDraftText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.whiteAlpha14,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepSegment(0, 'Pertanggungan', flex: 100),
                const SizedBox(width: 6),
                _buildStepSegment(
                  1,
                  'Uang Pertanggungan & Biaya Asuransi',
                  flex: 170,
                ),
                const SizedBox(width: 6),
                _buildStepSegment(2, 'T/C', flex: 55),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepSegment(int stepIndex, String label, {required int flex}) {
    final cur = _currentStep == stepIndex;
    final done = _currentStep > stepIndex;
    final barColor = cur
        ? AppColors.orangeMbis
        : (done ? AppColors.surfaceWhite : AppColors.whiteAlpha25);
    final textColor = (cur || done)
        ? AppColors.surfaceWhite
        : AppColors.whiteAlpha72;
    final fw = cur ? FontWeight.w700 : FontWeight.w500;

    return Expanded(
      flex: flex,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: double.infinity,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: fw,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Auto-Fill Banner & Footer Legend
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildAutoFillBanner() {
    final customerName = _namaPolisCtrl.text.isNotEmpty
        ? _namaPolisCtrl.text
        : (widget.customerName ?? 'Customer');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.greenLightBanner,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check,
              size: 18, color: AppColors.greenDarkText),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Data dari customer ',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.greenDarkText,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        ' dan pipeline sudah terisi otomatis. Periksa kembali sebelum lanjut.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.blueInputText,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Teks biru = isian yang akan tampil di dokumen QS',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Bottom Sticky Bar (Total Premi + Lanjut / Preview QS)
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final totalVal = _premiResult?.total ?? 0;
    final totalLabel = _product == QsProduct.paXtra
        ? 'Biaya Asuransi'
        : 'Total Premi';
    final isCalculated = totalVal > 0;
    final totalColor =
        isCalculated ? AppColors.greenTotal : AppColors.orangeDark;
    final String totalText;
    if (isCalculated) {
      totalText = 'Rp ${_currFormat.format(totalVal)}';
    } else {
      if (_product == QsProduct.paXtra) {
        totalText = 'Belum terbentuk';
      } else if (_premiMode == QsPremiMode.flat) {
        totalText = 'Isi tarif flat';
      } else if (_premiMode == QsPremiMode.mutlak) {
        totalText = 'Isi premi mutlak';
      } else {
        totalText = 'Belum terbentuk';
      }
    }
    final nextBtnText = _currentStep < 2 ? 'Lanjut' : 'Preview QS';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.borderDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    totalText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: totalColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (_currentStep > 0) ...[
              Material(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _currentStep--);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.navyMbis, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.chevron_left,
                          size: 20, color: AppColors.navyMbis),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Material(
              color: AppColors.navyMbis,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _onNextOrPreview,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nextBtnText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.surfaceWhite),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNextOrPreview() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      if (_formKey1.currentState?.validate() ?? true) {
        _showProductSelectionPopup();
      }
    } else if (_currentStep == 1) {
      if (_formKey2.currentState?.validate() ?? true) {
        _showStep3ProductSelectionPopup();
      }
    } else {
      if (_formKey3.currentState?.validate() ?? true) {
        setState(() => _isPreviewing = true);
      }
    }
  }

  void _showStep3ProductSelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDefault,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.blueLightBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.gavel_outlined,
                          size: 20, color: AppColors.navyMbis),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Pilih Produk Syarat & Ketentuan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Langkah 3: Terms & Conditions, Penerbitan & Dokumen',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProductChoiceCard(
                  title: 'PSAKDI',
                  subtitle: 'Polis Standar Asuransi Kecelakaan Diri Indonesia',
                  description:
                      '13 Klausula Standar Terkunci, Kondisi Standar, Waranti Standar, Pengecualian Standar, Form Penerbitan, Masa Berlaku, dan Dokumen Pendukung.',
                  badge: 'Standar OJK',
                  isSelected: _product == QsProduct.psakdi,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _product = QsProduct.psakdi;
                      _currentStep = 2;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildProductChoiceCard(
                  title: 'PA Xtra',
                  subtitle: 'Personal Accident Xtra',
                  description:
                      'Deductible Personal Accident, Pilihan Klausul/Kondisi/Waranti/Pengecualian Tambahan yang dapat disesuaikan, Form Penerbitan, Masa Berlaku, dan Dokumen.',
                  badge: 'Multi-Santunan',
                  isSelected: _product == QsProduct.paXtra,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _product = QsProduct.paXtra;
                      _currentStep = 2;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductSelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDefault,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.blueLightBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          size: 20, color: AppColors.navyMbis),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Pilih Produk Pertanggungan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Langkah 2: Uang Pertanggungan & Biaya Asuransi',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProductChoiceCard(
                  title: 'PSAKDI',
                  subtitle: 'Polis Standar Asuransi Kecelakaan Diri Indonesia',
                  description:
                      'Uang Pertanggungan Meninggal Dunia, Pilihan Risiko A (Meninggal Dunia) atau A/B (+ Cacat Tetap), Tambahan C (Biaya Perawatan), dan Suku Premi per Kelas.',
                  badge: 'Standar OJK',
                  isSelected: _product == QsProduct.psakdi,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _product = QsProduct.psakdi;
                      _currentStep = 1;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildProductChoiceCard(
                  title: 'PA Xtra',
                  subtitle: 'Personal Accident Xtra',
                  description:
                      'Jaminan Pokok, Risiko Cacat Tetap, Biaya Perawatan & Pengobatan, serta 6 Perluasan Santunan (Ambulan, Pemakaman, Barang Pribadi, Dokumen, Pendidikan, Repatriasi).',
                  badge: 'Multi-Santunan',
                  isSelected: _product == QsProduct.paXtra,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _product = QsProduct.paXtra;
                      _currentStep = 1;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductChoiceCard({
    required String title,
    required String subtitle,
    required String description,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSelectPipe : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.navyMbis,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.navyMbis,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyMbis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.blueLightBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyMbis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.navyMbis),
          ],
        ),
      ),
    );
  }

  void _onBack() {
    FocusScope.of(context).unfocus();
    if (_isPreviewing) {
      setState(() => _isPreviewing = false);
    } else if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.maybePop(context);
    }
  }

  String get _statusLabel {
    switch (_status) {
      case QsStatus.draft:
        return 'Draft';
      case QsStatus.menungguUw:
        return 'Menunggu UW';
      case QsStatus.ditolakUw:
        return 'Ditolak UW';
      case QsStatus.disetujuiUw:
        return 'Disetujui UW';
      case QsStatus.finalQs:
        return 'Final';
    }
  }

  Widget _currentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Screen Preview QS (Sesuai Prototype isPreview)
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildPreviewScreen() {
    final hasDeviations = _deviations.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgPreviewDoc,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          color: AppColors.navyMbis,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Material(
                  color: AppColors.whiteAlpha12,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _isPreviewing = false),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 20, color: AppColors.surfaceWhite),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Preview QS',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                      Text(
                        'No. $_nomorQs',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.whiteAlpha78,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isPreviewing = false;
                      _currentStep = 0;
                    });
                  },
                  icon: const Icon(Icons.edit, size: 14, color: AppColors.surfaceWhite),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                        color: AppColors.surfaceWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.whiteAlpha14,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDeviations) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.alertBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.alertBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠ Perlu Persetujuan Underwriting (UW)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.alertTitle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._deviations.map((d) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '• ${d.message}',
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.alertText),
                              ),
                            )),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.badgeP1Bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 18, color: AppColors.greenTotal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ketentuan tarif & batas sesuai standar UW. Siap diterbitkan.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.greenTotal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Ubah: ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLabel),
                      ),
                      const SizedBox(width: 4),
                      _jumpChip('Pertanggungan', 0),
                      const SizedBox(width: 6),
                      _jumpChip('UP & Premi', 1),
                      const SizedBox(width: 6),
                      _jumpChip('T&C', 2),
                    ],
                  ),
                ),
                _buildPreview(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          border: Border(top: BorderSide(color: AppColors.borderDivider)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _simpanDraft,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.navyMbis),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Simpan Draft',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: hasDeviations
                    ? FilledButton.icon(
                        onPressed: _ajukanKeUW,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Ajukan ke UW',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orangeMbis,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _finalisasi,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('OK',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navyMbis,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _jumpChip(String label, int step) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _isPreviewing = false;
          _currentStep = step;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderTable),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.navyMbis,
          ),
        ),
      ),
    );
  }

  void _simpanDraft() {
    setState(() => _status = QsStatus.draft);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Draft QS tersimpan di pipeline'),
        backgroundColor: AppColors.navyMbis,
      ),
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }


  // ────────────────────────────────────────────────────────────────────────
  // Step builders
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return QsStepPertanggungan(
      product: _product,
      type: _type,
      onTypeChanged: (t) => setState(() {
        _type = t;
        if (t == QsType.single) _jumlahOrangCtrl.text = '1';
      }),
      premiMode: _premiMode,
      onPremiModeChanged: (m) => setState(() => _premiMode = m),
      formKey: _formKey1,
      namaPolisCtrl: _namaPolisCtrl,
      alamatCtrl: _alamatCtrl,
      bidangUsahaCtrl: _bidangUsahaCtrl,
      emailCtrl: _emailCtrl,
      namaPicCtrl: _namaPicCtrl,
      noHpPicCtrl: _noHpPicCtrl,
      jumlahOrangCtrl: _jumlahOrangCtrl,
      aktivitasCtrl: _aktivitasCtrl,
      namaTertanggungCtrl: _namaTertanggungCtrl,
      noKtpCtrl: _noKtpCtrl,
      pekerjaanCtrl: _pekerjaanCtrl,
      tglLahir: _tglLahir,
      onTglLahirChanged: (d) => setState(() => _tglLahir = d),
      tglMulai: _tglMulai,
      onTglMulaiChanged: (d) => setState(() => _tglMulai = d),
      tglAkhir: _tglAkhir,
      onTglAkhirChanged: (d) => setState(() => _tglAkhir = d),
      dataSamaPolis: _dataSamaPolis,
      onDataSamaPolisChanged: (v) {
        setState(() {
          _dataSamaPolis = v;
          if (v) {
            _namaTertanggungCtrl.text = _namaPolisCtrl.text;
          }
        });
      },
      klasifikasiPeserta: _klasifikasiPeserta,
      onKlasifikasiChanged: (k) => setState(() => _klasifikasiPeserta = k),
    );
  }

  Widget _buildStep2() {
    return QsStepUangPertanggungan(
      product: _product,
      type: _type,
      premiMode: _premiMode,
      formKey: _formKey2,
      upACtrl: _upACtrl,
      riskType: _riskType,
      onRiskTypeChanged: (r) => setState(() {
        _riskType = r;
        if (r == PsakdiRiskType.a && _risikoC) {
          _risikoC = false;
          _upCCtrl.clear();
        }
      }),
      risikoC: _risikoC,
      onRisikoCChanged: (v) => setState(() => _risikoC = v),
      upCCtrl: _upCCtrl,
      rateABCtrl: _rateABCtrl,
      rateCCtrl: _rateCCtrl,
      upPaXtraCtrl: _upPaXtraCtrl,
      cacatTetap: _cacatTetap,
      onCacatTetapChanged: (v) => setState(() => _cacatTetap = v),
      perawatanPengobatan: _perawatanPengobatan,
      onPerawatanChanged: (v) => setState(() => _perawatanPengobatan = v),
      santunanCtrls: _santunanCtrls,
      risikoDijaminCtrl: _risikoDijaminCtrl,
      diskonCtrl: _diskonCtrl,
      polisType: _polisType,
      onPolisTypeChanged: (t) => setState(() => _polisType = t),
      premiMutlakPokokCtrl: _premiMutlakPokokCtrl,
      premiMutlakTambahanCtrl: _premiMutlakTambahanCtrl,
      tarifFlatCtrl: _tarifFlatCtrl,
      jumlahHari: _jumlahHari,
      jumlahOrang: _jumlahOrang,
      klasifikasiPeserta: _klasifikasiPeserta,
      deviations: _deviations,
      onJumpToStep1: () {
        FocusScope.of(context).unfocus();
        setState(() => _currentStep = 0);
      },
    );
  }

  Widget _buildStep3() {
    return QsStepTermsConditions(
      product: _product,
      formKey: _formKey3,
      kotaCtrl: _kotaCtrl,
      cabangCtrl: _cabangCtrl,
      penandatanganCtrl: _penandatanganCtrl,
      jabatanCtrl: _jabatanCtrl,
      tglPenerbitan: _tglPenerbitan,
      onTglPenerbitanChanged: (d) => setState(() => _tglPenerbitan = d),
      masaBerlaku: _masaBerlaku,
      onMasaBerlakuChanged: (d) => setState(() => _masaBerlaku = d),
      klausulTambahanCtrl: _klausulTambahanCtrl,
      kondisiTambahanCtrl: _kondisiTambahanCtrl,
      warantiTambahanCtrl: _warantiTambahanCtrl,
      pengecualianTambahanCtrl: _pengecualianTambahanCtrl,
      deductibleCtrl: _deductibleCtrl,
      namaFile: _namaFile,
      onPilihFile: () {
        // Mock file pick
        setState(() => _namaFile = 'KTP_contoh.pdf');
      },
      onHapusFile: _namaFile != null
          ? () => setState(() => _namaFile = null)
          : null,
    );
  }


  Widget _buildPreview() {
    return QsPreviewPanel(
      product: _product,
      status: _status,
      type: _type,
      premiMode: _premiMode,
      nomorQs: _nomorQs,
      namaPolis: _namaPolisCtrl.text,
      alamat: _alamatCtrl.text,
      bidangUsaha: _bidangUsahaCtrl.text,
      namaTertanggung: _namaTertanggungCtrl.text,
      noKtp: _noKtpCtrl.text,
      tglLahir: _tglLahir,
      pekerjaan: _pekerjaanCtrl.text,
      tglMulai: _tglMulai,
      tglAkhir: _tglAkhir,
      jumlahHari: _jumlahHari,
      jumlahOrang: _jumlahOrang,
      aktivitas: _aktivitasCtrl.text,
      riskType: _riskType,
      upA: _parseNum(_upACtrl.text),
      upC: _parseNum(_upCCtrl.text),
      risikoC: _risikoC,
      klasifikasiPeserta: _klasifikasiPeserta,
      upPaXtra: _parseNum(_upPaXtraCtrl.text),
      cacatTetap: _cacatTetap,
      perawatanPengobatan: _perawatanPengobatan,
      santunanValues: _santunanValues,
      premiResult: _premiResult,
      risikoDijamin: _risikoDijaminCtrl.text,
      diskonPersen: _diskonPersen,
      polisType: _polisType,
      kota: _kotaCtrl.text,
      tglPenerbitan: _tglPenerbitan,
      cabang: _cabangCtrl.text,
      penandatangan: _penandatanganCtrl.text,
      jabatan: _jabatanCtrl.text,
      masaBerlaku: _masaBerlaku,
      deviations: _deviations,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────────────────

  void _ajukanKeUW() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: AppRadius.radius2Xl),
        title: const Text('Ajukan ke UW',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QS memiliki penyimpangan dari ketentuan standar UW. Ajukan ke Underwriting untuk persetujuan?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan / Catatan pengajuan *',
                border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg),
                contentPadding: const EdgeInsets.all(14),
              ),
              style: AppInput.fieldText,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _status = QsStatus.menungguUw;
                _isPreviewing = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ QS berhasil diajukan ke Underwriting.'),
                  backgroundColor: AppColors.primaryNavy,
                ),
              );
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryOrange),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
  }

  void _finalisasi() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: AppRadius.radius2Xl),
        title: const Text('Terbitkan & Finalkan QS?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'Setelah OK, QS final dan terkunci. Nomor QS resmi terbentuk dan siap dikirim ke customer.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _status = QsStatus.finalQs);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✓ QS final dan terkunci · No. $_nomorQs – siap dikirim ke customer'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNavy),
            child: const Text('OK – Terbitkan'),
          ),
        ],
      ),
    );
  }
}


