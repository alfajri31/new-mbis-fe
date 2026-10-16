import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../qs_form_state.dart';

/// Item definisi santunan tambahan PA Xtra
class _SantunanDef {
  final String key;
  final String label;
  final double cap;
  final double defaultRate;

  const _SantunanDef({
    required this.key,
    required this.label,
    required this.cap,
    required this.defaultRate,
  });
}

const List<_SantunanDef> _kPaxSantunanList = [
  _SantunanDef(
    key: 'ambulan',
    label: 'Ambulan & Evakuasi',
    cap: 2000000,
    defaultRate: 2.00,
  ),
  _SantunanDef(
    key: 'pemakaman',
    label: 'Pemakaman / Kremasi',
    cap: 2000000,
    defaultRate: 0.10,
  ),
  _SantunanDef(
    key: 'barang',
    label: 'Kehilangan Barang Pribadi',
    cap: 500000,
    defaultRate: 2.00,
  ),
  _SantunanDef(
    key: 'dokumen',
    label: 'Pengurusan Dokumen',
    cap: 500000,
    defaultRate: 2.00,
  ),
  _SantunanDef(
    key: 'pendidikan',
    label: 'Biaya Pendidikan',
    cap: 5000000,
    defaultRate: 0.10,
  ),
  _SantunanDef(
    key: 'pemulangan',
    label: 'Biaya Pemulangan Jenazah / Repatriasi',
    cap: 5000000,
    defaultRate: 0.10,
  ),
];

/// Horizontal dashed divider sederhana sesuai prototype web border-top dashed
class DashedHorizontalDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedHorizontalDivider({
    super.key,
    this.height = 1.0,
    this.color = AppColors.borderDivider,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Tab 2 – Uang Pertanggungan & Biaya Asuransi Khusus PA Xtra (Prototype 1:1).
class QsStepUangPertanggunganPaXtra extends StatefulWidget {
  final QsType type;
  final QsPremiMode premiMode;
  final GlobalKey<FormState> formKey;

  final TextEditingController upPaXtraCtrl;
  final bool cacatTetap;
  final ValueChanged<bool> onCacatTetapChanged;
  final bool perawatanPengobatan;
  final ValueChanged<bool> onPerawatanChanged;
  final Map<String, TextEditingController> santunanCtrls;

  final TextEditingController risikoDijaminCtrl;
  final TextEditingController diskonCtrl;
  final QsPolisType polisType;
  final ValueChanged<QsPolisType> onPolisTypeChanged;

  final TextEditingController premiMutlakPokokCtrl;
  final TextEditingController premiMutlakTambahanCtrl;
  final TextEditingController tarifFlatCtrl;

  final int jumlahHari;
  final int jumlahOrang;
  final List<UwDeviation> deviations;
  final VoidCallback? onJumpToStep1;
  final String? pipeRate;

  const QsStepUangPertanggunganPaXtra({
    super.key,
    required this.type,
    required this.premiMode,
    required this.formKey,
    required this.upPaXtraCtrl,
    required this.cacatTetap,
    required this.onCacatTetapChanged,
    required this.perawatanPengobatan,
    required this.onPerawatanChanged,
    required this.santunanCtrls,
    required this.risikoDijaminCtrl,
    required this.diskonCtrl,
    required this.polisType,
    required this.onPolisTypeChanged,
    required this.premiMutlakPokokCtrl,
    required this.premiMutlakTambahanCtrl,
    required this.tarifFlatCtrl,
    required this.jumlahHari,
    required this.jumlahOrang,
    required this.deviations,
    this.onJumpToStep1,
    this.pipeRate = '0.10',
  });

  @override
  State<QsStepUangPertanggunganPaXtra> createState() =>
      _QsStepUangPertanggunganPaXtraState();
}

class _QsStepUangPertanggunganPaXtraState
    extends State<QsStepUangPertanggunganPaXtra> {
  final _currFmt = NumberFormat('#,##0', 'id');
  final _currFmtDec = NumberFormat('#,##0.00', 'id_ID');

  bool _flatManual = false;
  bool _mutlakManual = false;

  // Controller khusus rate santunan tambahan
  late final Map<String, TextEditingController> _rateCtrls;

  @override
  void initState() {
    super.initState();
    _formatInitialText(widget.upPaXtraCtrl);
    final ctrlC = _getSantunanCtrl('pengobatan');
    _formatInitialText(ctrlC);
    _formatInitialText(widget.tarifFlatCtrl);
    _formatInitialText(widget.premiMutlakPokokCtrl);
    _formatInitialText(widget.premiMutlakTambahanCtrl);
    _initRateControllers();
    _attachListeners();
  }

  void _formatInitialText(TextEditingController ctrl) {
    if (ctrl.text.isEmpty) return;
    final digits = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final formatted = _RupiahInputFormatter.formatDigits(digits);
      if (ctrl.text != formatted) {
        ctrl.text = formatted;
      }
    }
  }

  @override
  void didUpdateWidget(covariant QsStepUangPertanggunganPaXtra oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.upPaXtraCtrl != oldWidget.upPaXtraCtrl) {
      _detachListeners();
      _formatInitialText(widget.upPaXtraCtrl);
      _formatInitialText(widget.tarifFlatCtrl);
      _formatInitialText(widget.premiMutlakPokokCtrl);
      _formatInitialText(widget.premiMutlakTambahanCtrl);
      _attachListeners();
    }
  }

  void _initRateControllers() {
    _rateCtrls = {
      'pengobatan': TextEditingController(text: '2.00'),
      for (final s in _kPaxSantunanList)
        s.key: TextEditingController(
          text: s.defaultRate.toStringAsFixed(2),
        ),
    };
  }

  void _attachListeners() {
    widget.upPaXtraCtrl.addListener(_onRebuild);
    widget.diskonCtrl.addListener(_onRebuild);
    widget.tarifFlatCtrl.addListener(_onRebuild);
    widget.premiMutlakPokokCtrl.addListener(_onRebuild);
    widget.premiMutlakTambahanCtrl.addListener(_onRebuild);
    for (final c in widget.santunanCtrls.values) {
      c.addListener(_onRebuild);
    }
    for (final c in _rateCtrls.values) {
      c.addListener(_onRebuild);
    }
  }

  void _detachListeners() {
    widget.upPaXtraCtrl.removeListener(_onRebuild);
    widget.diskonCtrl.removeListener(_onRebuild);
    widget.tarifFlatCtrl.removeListener(_onRebuild);
    widget.premiMutlakPokokCtrl.removeListener(_onRebuild);
    widget.premiMutlakTambahanCtrl.removeListener(_onRebuild);
    for (final c in widget.santunanCtrls.values) {
      c.removeListener(_onRebuild);
    }
    for (final c in _rateCtrls.values) {
      c.removeListener(_onRebuild);
    }
  }

  @override
  void dispose() {
    _detachListeners();
    for (final c in _rateCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onRebuild() {
    if (mounted) setState(() {});
  }

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  double _parseRate(String s) =>
      double.tryParse(s.replaceAll(',', '.')) ?? 0.0;

  double get _up => _parseNum(widget.upPaXtraCtrl.text);

  double get _batasC => min(_up * 0.10, 10000000.0);

  double get _biayaAdmin => biayaAdminForPolis(widget.polisType);

  double get _diskonPersen => double.tryParse(widget.diskonCtrl.text) ?? 0;

  TextEditingController _getSantunanCtrl(String key) {
    if (widget.santunanCtrls.containsKey(key)) {
      return widget.santunanCtrls[key]!;
    }
    if (key == 'pemulangan' && widget.santunanCtrls.containsKey('repatriasi')) {
      return widget.santunanCtrls['repatriasi']!;
    }
    if (key == 'repatriasi' && widget.santunanCtrls.containsKey('pemulangan')) {
      return widget.santunanCtrls['pemulangan']!;
    }
    final c = TextEditingController();
    widget.santunanCtrls[key] = c;
    return c;
  }

  double _getSantunanValue(String key) {
    return _parseNum(_getSantunanCtrl(key).text);
  }

  double _getSantunanRate(String key, double defaultVal) {
    final c = _rateCtrls[key];
    if (c == null || c.text.trim().isEmpty) return defaultVal;
    return _parseRate(c.text);
  }

  double get _ratePokok => widget.cacatTetap
      ? defaultPaXtraRatePokokWithCacatTetap
      : defaultPaXtraRatePokokWithoutCacatTetap;

  // Dasar jaminan tambahan: jika Cacat Tetap dipilih => UP Pokok + semua santunan aktif
  double get _dasarJaminanTambahan {
    double total = widget.cacatTetap ? _up : 0;
    if (widget.perawatanPengobatan) {
      total += _getSantunanValue('pengobatan');
    }
    for (final s in _kPaxSantunanList) {
      total += _getSantunanValue(s.key);
    }
    return total;
  }

  // Premi santunan tahunan (sebelum dikali H/365 * N)
  double get _sumPremiSantunanTahunan {
    double total = 0;
    if (widget.perawatanPengobatan) {
      final val = _getSantunanValue('pengobatan');
      final r = _getSantunanRate('pengobatan', 2.0);
      total += val * (r / 100);
    }
    for (final s in _kPaxSantunanList) {
      final val = _getSantunanValue(s.key);
      final r = _getSantunanRate(s.key, s.defaultRate);
      total += val * (r / 100);
    }
    return total;
  }

  double get _rateTambahanOtomatis {
    final ds = _dasarJaminanTambahan;
    if (ds <= 0) return 0;
    return (_sumPremiSantunanTahunan / ds) * 100;
  }

  // Premi pokok tahunan
  double get _premiPokokTahunan => _up * (_ratePokok / 100);

  // Standar perhitungan normal untuk periode H hari dan N orang
  double get _premiPokokStandar {
    if (widget.jumlahHari <= 0 || _up <= 0) return 0;
    return _premiPokokTahunan * (widget.jumlahHari / 365) * widget.jumlahOrang;
  }

  double get _premiTambahanStandar {
    if (widget.jumlahHari <= 0 || _up <= 0) return 0;
    return _sumPremiSantunanTahunan * (widget.jumlahHari / 365) * widget.jumlahOrang;
  }

  double get _saranFlatRaw {
    if (_up <= 0) return 0;
    final totalTahunan = _premiPokokTahunan + _sumPremiSantunanTahunan;
    return totalTahunan / 365;
  }

  double get _saranFlatPerHari {
    if (_up <= 0) return 0;
    return (_saranFlatRaw - 1e-9).ceilToDouble();
  }

  PremiResult get _calculatedPremi {
    final hari = widget.jumlahHari;
    final n = widget.jumlahOrang;

    double pokok = 0;
    double tambahan = 0;

    switch (widget.premiMode) {
      case QsPremiMode.normal:
        pokok = _premiPokokStandar;
        tambahan = _premiTambahanStandar;
        break;

      case QsPremiMode.mutlak:
        final p = _parseNum(widget.premiMutlakPokokCtrl.text);
        final t = _parseNum(widget.premiMutlakTambahanCtrl.text);
        pokok = widget.premiMutlakPokokCtrl.text.isNotEmpty ? p : _premiPokokStandar;
        tambahan = widget.premiMutlakTambahanCtrl.text.isNotEmpty ? t : _premiTambahanStandar;
        break;

      case QsPremiMode.flat:
        final tarif = _parseNum(widget.tarifFlatCtrl.text);
        final eff = widget.tarifFlatCtrl.text.isNotEmpty ? tarif : _saranFlatPerHari;
        pokok = eff * hari * n;
        tambahan = 0;
        break;
    }

    final gross = pokok + tambahan;
    final disk = gross * (_diskonPersen / 100);
    final netto = gross - disk;
    final adm = _biayaAdmin;
    final total = netto + adm;

    return PremiResult(
      premiPokok: pokok,
      premiTambahan: tambahan,
      gross: gross,
      diskon: disk,
      netto: netto,
      biayaAdmin: adm,
      total: total,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Underwriting Deviations Banner
          if (widget.deviations.isNotEmpty) ...[
            _buildUwAlertBanner(),
            const SizedBox(height: 14),
          ],

          // 2. Jaminan Pokok
          _buildPaXtraJaminanPokokCard(),
          const SizedBox(height: 14),

          // 3. Jaminan Tambahan & Perluasan
          _buildPaXtraJaminanTambahanCard(),
          const SizedBox(height: 14),

          // 4. Risiko Dijamin
          _buildRisikoDijaminCard(),
          const SizedBox(height: 14),

          // 5. Perhitungan Mode Banner
          _buildCalculationModeBanner(),
          const SizedBox(height: 14),

          // 6. Biaya Asuransi Card (Normal / Flat / Mutlak)
          _buildBiayaAsuransiCard(),
          const SizedBox(height: 14),

          // 7. Discount & Adm Cost Card
          _buildDiscountAdmCard(),
          const SizedBox(height: 14),

          // 8. Rincian Biaya Asuransi Otomatis Card
          _buildRincianBiayaCard(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Banner Alert UW
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildUwAlertBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alertBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠ Memerlukan Approval Underwriting (UW)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.alertTitle,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.deviations.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.alertText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${d.field}: ${d.message}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.alertText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          const Text(
            'QS tetap bisa disimpan sebagai Draft (tanpa nomor) dan dilihat di Preview. Ajukan ke UW dari Preview QS, atau sesuaikan isian agar sesuai ketentuan.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Card Jaminan Pokok
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPaXtraJaminanPokokCard() {
    final upVal = _up;
    final upOver = upVal > 1000000000;

    return _buildCard(
      children: [
        const Text(
          'Jaminan Pokok',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            decoration: TextDecoration.underline,
            decorationThickness: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildPrototypeFieldRow(
          label: 'Uang Pertanggungan (Meninggal Dunia)',
          controller: widget.upPaXtraCtrl,
          isNumeric: true,
          isCurrency: true,
          hasError: upOver,
        ),
        if (upOver)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Maksimal Rp 1.000.000.000',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.redRequired,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Card Jaminan Tambahan & Perluasan
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPaXtraJaminanTambahanCard() {
    final upVal = _up;
    final hasNoUp = upVal <= 0;
    final ctrlC = _getSantunanCtrl('pengobatan');
    final cVal = _parseNum(ctrlC.text);
    final cOver =
        widget.perawatanPengobatan && widget.cacatTetap && cVal > _batasC;

    return _buildCard(
      children: [
        const Text(
          'Jaminan Tambahan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            decoration: TextDecoration.underline,
            decorationThickness: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        // Row Cacat Tetap (Grid 24px minmax(0, 1fr) 10px minmax(0, 1.1fr))
        Row(
          children: [
            InkWell(
              onTap: () {
                final nextVal = !widget.cacatTetap;
                widget.onCacatTetapChanged(nextVal);
                if (!nextVal && widget.perawatanPengobatan) {
                  widget.onPerawatanChanged(false);
                  _getSantunanCtrl('pengobatan').clear();
                }
              },
              borderRadius: BorderRadius.circular(7),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.cacatTetap ? AppColors.navyMbis : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: widget.cacatTetap
                        ? AppColors.navyMbis
                        : AppColors.borderInactive,
                    width: 1.5,
                  ),
                ),
                child: widget.cacatTetap
                    ? const Icon(Icons.check, size: 14, color: AppColors.surfaceWhite)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              flex: 10,
              child: Text(
                'Termasuk Risiko Cacat Tetap',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textDark,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 10,
              child: Text(':', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 11,
              child: Text(
                widget.cacatTetap ? '100% UP Meninggal Dunia' : 'Tidak dijamin',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: widget.cacatTetap
                      ? AppColors.blueInputText
                      : AppColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Card Perawatan & Pengobatan
        _buildPaXtraPerawatanBox(),
        // Input Biaya Perawatan / Pengobatan jika aktif (di prototype di luar box)
        if (widget.perawatanPengobatan && widget.cacatTetap) ...[
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrototypeFieldRow(
                label: 'Biaya Perawatan / Pengobatan',
                controller: ctrlC,
                isNumeric: true,
                isCurrency: true,
                hasError: cOver,
              ),
              if (cOver)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Maksimal Rp ${_currFmt.format(_batasC)} (maks. 10% UP)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.redRequired,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text:
                    'Perawatan & Pengobatan hanya bisa diambil bersama Cacat Tetap',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text:
                    ' (A tidak bisa digabung dengan C). Maks. C: 10% UP atau Rp 10.000.000.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sub-seksi Perluasan dengan garis dashed sesuai prototype web
        const DashedHorizontalDivider(
          color: AppColors.borderDivider,
          height: 1,
          dashWidth: 4,
          dashSpace: 3,
        ),
        const SizedBox(height: 10),
        const Text(
          'Perluasan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.alertTitle,
          ),
        ),
        const SizedBox(height: 8),
        if (hasNoUp)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alertBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Isi UP Meninggal Dunia terlebih dahulu. Batas tiap perluasan maks. 10% dari UP tersebut.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.alertText,
                height: 1.3,
              ),
            ),
          )
        else ...[
          ..._kPaxSantunanList.map((s) => _buildSantunanItemRow(s)),
        ],
        const SizedBox(height: 4),
        const Text(
          'Premi dihitung otomatis dari tarif standar PA Xtra. Jaminan Pokok memakai 0.10%, atau 0.15% bila termasuk Cacat Tetap.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSantunanItemRow(_SantunanDef def) {
    final key = def.key;
    final label = def.label;
    final ctrl = _getSantunanCtrl(key);
    final upVal = _up;
    final maxLimit = batasSantunan(key, upVal);
    final currentVal = _parseNum(ctrl.text);
    final isChecked = ctrl.text.isNotEmpty && currentVal > 0;
    final isOver = currentVal > maxLimit;

    /*
    final rateCtrl = _rateCtrls[key]!;
    final currentRate = _parseRate(rateCtrl.text);
    final isRateOffStd = (currentRate - def.defaultRate).abs() > 0.001;

    // Premi santunan pro-rata periode
    final premiSantunan = currentVal *
        (currentRate / 100) *
        (widget.jumlahHari / 365) *
        widget.jumlahOrang;
    */

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (isChecked) {
                    ctrl.clear();
                  } else {
                    ctrl.text = _currFmt.format(min(maxLimit, def.cap));
                  }
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isChecked ? AppColors.navyMbis : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isChecked
                          ? AppColors.navyMbis
                          : AppColors.borderInactive,
                      width: 1.5,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 14, color: AppColors.surfaceWhite)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textDark,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 10,
                child: Text(':', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 11,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isChecked ? Colors.white : AppColors.bgLightGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOver
                          ? AppColors.redRequired
                          : AppColors.borderDefault,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ctrl,
                          enabled: isChecked,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          cursorColor: AppColors.orangeMbis,
                          inputFormatters: const [
                            _RupiahInputFormatter(),
                          ],
                          onChanged: (val) {
                            setState(() {});
                          },
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isChecked
                                ? AppColors.blueInputText
                                : AppColors.textDisabled,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: '0',
                          ),
                        ),
                      ),
                      Text(
                        ',-',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isChecked
                              ? AppColors.blueInputText
                              : AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isOver)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Maksimal Rp ${_currFmt.format(maxLimit)} (maks. 10% UP)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.redRequired,
                  ),
                ),
              ),
            ),
          /*
          // Sub-baris Rate & Premi terhitung (Prototype: ri.<santunan>.show = false)
          if (isChecked) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Rate',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 32,
                    width: 78,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRateOffStd
                            ? AppColors.orangeDark
                            : AppColors.borderDefault,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.right,
                            cursorColor: AppColors.orangeMbis,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]')),
                            ],
                            onChanged: (val) {
                              setState(() {});
                            },
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blueInputText,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          '%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Premi',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 84),
                    child: Text(
                      'Rp ${_currFmt.format(premiSantunan)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                  ),
                  if (isRateOffStd) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        rateCtrl.text = def.defaultRate.toStringAsFixed(2);
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.badgeOffStdBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '≠ ${def.defaultRate.toStringAsFixed(2)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          */
        ],
      ),
    );
  }

  Widget _buildPaXtraPerawatanBox() {
    final isDisabled = !widget.cacatTetap;
    final isChecked = widget.perawatanPengobatan && !isDisabled;
    final ctrl = _getSantunanCtrl('pengobatan');

    final cardBg = isDisabled
        ? AppColors.bgDisabledCard
        : (isChecked ? AppColors.bgSelectedCard : Colors.white);
    final cardBd = isDisabled
        ? AppColors.borderDivider
        : (isChecked ? AppColors.navyMbis : AppColors.borderDefault);

    final boxBg = isDisabled
        ? AppColors.bgDisabled
        : (isChecked ? AppColors.navyMbis : Colors.white);
    final boxBd = isDisabled
        ? AppColors.borderDefault
        : (isChecked ? AppColors.navyMbis : AppColors.borderInactive);

    final textColor = isDisabled ? AppColors.textDisabled : AppColors.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBd,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: isDisabled
                    ? null
                    : () {
                        final nextVal = !widget.perawatanPengobatan;
                        widget.onPerawatanChanged(nextVal);
                        if (!nextVal) {
                          ctrl.clear();
                        } else {
                          ctrl.text = _currFmt.format(_batasC);
                        }
                      },
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: boxBd,
                      width: 1.5,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 14, color: AppColors.surfaceWhite)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Perawatan & Pengobatan',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (isDisabled)
            const Padding(
              padding: EdgeInsets.only(left: 34, top: 6),
              child: Text(
                'Centang Cacat Tetap terlebih dahulu. Perawatan & Pengobatan tidak bisa diambil tanpa Cacat Tetap.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.alertTitle,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Card Risiko Dijamin
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRisikoDijaminCard() {
    const stdText =
        'Meninggal Dunia / Cacat Tetap, Biaya Pengobatan dan santunan-santunan yang disebabkan karena kecelakaan.';
    if (widget.risikoDijaminCtrl.text.trim().isEmpty) {
      widget.risikoDijaminCtrl.text = stdText;
    }

    return _buildCard(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.blueLightBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.navyMbis,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Risiko Dijamin',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CustomPaint(
          painter: DashedRectPainter(
            color: AppColors.borderDashed,
            strokeWidth: 1.0,
            gap: 5.0,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgLightGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEKS STANDAR PA XTRA',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        stdText,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Banner Mode Perhitungan
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCalculationModeBanner() {
    final String modeText;
    switch (widget.premiMode) {
      case QsPremiMode.normal:
        modeText = 'Normal · rate × UP × hari/365';
        break;
      case QsPremiMode.flat:
        modeText = 'Flat · tarif per hari × hari × peserta';
        break;
      case QsPremiMode.mutlak:
        modeText = 'Mutlak · nominal premi diisi langsung';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blueLightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monetization_on_outlined,
            size: 18,
            color: AppColors.navyMbis,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Perhitungan: ',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textDark,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: modeText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.onJumpToStep1 != null)
            InkWell(
              onTap: widget.onJumpToStep1,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Ubah di Pertanggungan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orangeDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Card Biaya Asuransi (Normal / Flat / Mutlak)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildBiayaAsuransiCard() {
    switch (widget.premiMode) {
      case QsPremiMode.normal:
        return _buildPaXtraNormalBiayaCard();
      case QsPremiMode.flat:
        return _buildTarifFlatCard();
      case QsPremiMode.mutlak:
        return _buildPremiMutlakCard();
    }
  }

  Widget _buildPaXtraNormalBiayaCard() {
    final rateP = _ratePokok;
    final rateT = _rateTambahanOtomatis;
    final dasarT = _dasarJaminanTambahan;
    final premiP = _premiPokokStandar;
    final premiT = _premiTambahanStandar;
    final up = _up;
    final n = widget.jumlahOrang;

    final String lblA = 'Premi Jaminan Pokok${n > 1 ? ' (× $n orang)' : ''}';
    final String lblC =
        'Premi Jaminan Tambahan${n > 1 ? ' (× $n orang)' : ''}';

    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.monetization_on_outlined,
          title: 'Biaya Asuransi · Normal',
          subtitle: 'Dihitung otomatis dari tarif standar PA Xtra',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgLightGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                  'Rate Jaminan Pokok', '${rateP.toStringAsFixed(2)}%'),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Dasar Jaminan Tambahan', 'Rp ${_currFmt.format(dasarT)}'),
              const SizedBox(height: 8),
              _buildInfoRow('Rate Jaminan Tambahan (otomatis)',
                  '${rateT.toStringAsFixed(4)}%'),
              const SizedBox(height: 8),
              _buildInfoRow(lblA, 'Rp ${_currFmt.format(premiP)}'),
              const SizedBox(height: 8),
              _buildInfoRow(lblC, 'Rp ${_currFmt.format(premiT)}'),
            ],
          ),
        ),
        if (up <= 0) ...[
          const SizedBox(height: 14),
          _buildNoPremiAlert(
            message: 'Premi belum terbentuk. Isi UP Meninggal Dunia.',
          ),
        ],
      ],
    );
  }

  Widget _buildTarifFlatCard() {
    final saranCeil = _saranFlatPerHari;
    final sugRaw = _saranFlatRaw;
    final sugRp = 'Rp ${_currFmtDec.format(sugRaw)}';

    // Auto-populate saran jika field masih kosong / 0 dan saran > 0
    if ((widget.tarifFlatCtrl.text.isEmpty || widget.tarifFlatCtrl.text == '0') &&
        saranCeil > 0 &&
        !_flatManual) {
      widget.tarifFlatCtrl.text =
          _RupiahInputFormatter.formatDigits(saranCeil.round().toString());
    }

    final currentTarif = _parseNum(widget.tarifFlatCtrl.text);
    final isManual = _flatManual || (currentTarif > 0 && currentTarif != saranCeil);

    final formulaTxt =
        'Rp ${_currFmt.format(currentTarif)} × ${widget.jumlahHari} hari × ${widget.jumlahOrang} orang = Rp ${_currFmt.format(currentTarif * widget.jumlahHari * widget.jumlahOrang)}';

    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.monetization_on_outlined,
          title: 'Biaya Asuransi · Flat',
          subtitle: 'Premi = tarif per hari × hari × jumlah orang',
        ),
        const SizedBox(height: 14),
        // Box info saran sistem
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgInfoBanner,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premi Flat per-hari (sistem)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLabel,
                      height: 1.35,
                    ),
                  ),
                  Text(
                    'dari rate per jaminan ÷ 365',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              Text(
                sugRp,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navyMbis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text.rich(
              TextSpan(
                text: 'Tarif Flat per Hari',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
                ),
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AppColors.redRequired,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Rp',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: widget.tarifFlatCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [_RupiahInputFormatter()],
                      onChanged: (_) {
                        setState(() {
                          _flatManual = true;
                        });
                      },
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blueInputText,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (!isManual)
              const Text(
                'Terisi otomatis dari saran sistem (dibulatkan ke atas). Bisa diubah.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            if (isManual)
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    widget.tarifFlatCtrl.text = _RupiahInputFormatter.formatDigits(
                        saranCeil.round().toString());
                    setState(() {
                      _flatManual = false;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Kembali ke saran sistem',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orangeDark,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgLightGray,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            formulaTxt,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navyMbis,
            ),
          ),
        ),
        if (currentTarif <= 0) ...[
          const SizedBox(height: 14),
          _buildNoPremiAlert(
            message: 'Premi belum terbentuk. Isi Tarif Flat per Hari.',
          ),
        ],
      ],
    );
  }

  Widget _buildPremiMutlakCard() {
    final stdPokok = _premiPokokStandar;
    final stdTambahan = _premiTambahanStandar;

    // Auto-populate default standar jika field masih kosong dan standar > 0
    if ((widget.premiMutlakPokokCtrl.text.isEmpty ||
            widget.premiMutlakPokokCtrl.text == '0') &&
        stdPokok > 0 &&
        !_mutlakManual) {
      widget.premiMutlakPokokCtrl.text =
          _RupiahInputFormatter.formatDigits(stdPokok.round().toString());
    }
    if ((widget.premiMutlakTambahanCtrl.text.isEmpty ||
            widget.premiMutlakTambahanCtrl.text == '0') &&
        stdTambahan > 0 &&
        !_mutlakManual) {
      widget.premiMutlakTambahanCtrl.text =
          _RupiahInputFormatter.formatDigits(stdTambahan.round().toString());
    }

    final pokok = _parseNum(widget.premiMutlakPokokCtrl.text);
    final tambahan = _parseNum(widget.premiMutlakTambahanCtrl.text);
    final isManual = _mutlakManual ||
        ((pokok > 0 || tambahan > 0) &&
            (pokok != stdPokok.round() || tambahan != stdTambahan.round()));

    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.monetization_on_outlined,
          title: 'Biaya Asuransi · Mutlak',
          subtitle: 'Nominal premi diisi langsung (total seluruh peserta)',
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text.rich(
              TextSpan(
                text: 'Premi Jaminan Pokok',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
                ),
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AppColors.redRequired,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildMutlakInputField(
              widget.premiMutlakPokokCtrl,
              onChanged: () => setState(() => _mutlakManual = true),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Premi Jaminan Tambahan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 8),
            _buildMutlakInputField(
              widget.premiMutlakTambahanCtrl,
              onChanged: () => setState(() => _mutlakManual = true),
            ),
          ],
        ),
        if (pokok <= 0) ...[
          const SizedBox(height: 14),
          _buildNoPremiAlert(
            message: 'Premi belum terbentuk. Isi Premi Jaminan Pokok.',
          ),
        ],
        const SizedBox(height: 14),
        if (!isManual)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgInfoBanner,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.navyMbis),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Terisi otomatis dari rate per jaminan (tabel PA Xtra). Ubah bila ada kesepakatan premi.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.navyMbis,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (isManual)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alertBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.alertBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diubah manual · tarif standar: Rp ${_currFmt.format(stdPokok)} (Pokok) / Rp ${_currFmt.format(stdTambahan)} (Tambahan)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.alertText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      widget.premiMutlakPokokCtrl.text =
                          _RupiahInputFormatter.formatDigits(
                              stdPokok.round().toString());
                      widget.premiMutlakTambahanCtrl.text =
                          _RupiahInputFormatter.formatDigits(
                              stdTambahan.round().toString());
                      setState(() {
                        _mutlakManual = false;
                      });
                    },
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: AppColors.orangeMbis, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Kembali ke tarif standar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.alertTitle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMutlakInputField(
    TextEditingController ctrl, {
    VoidCallback? onChanged,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      child: Row(
        children: [
          const Text(
            'Rp',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: const [_RupiahInputFormatter()],
              onChanged: (_) {
                if (onChanged != null) onChanged();
              },
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.blueInputText,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPremiAlert({
    String message = 'Premi belum terbentuk. Isi UP Meninggal Dunia.',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alertBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppColors.orangeDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.alertText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 7. Card Discount & Adm Cost
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDiscountAdmCard() {
    final discOptions = [
      (0.0, 'Tanpa diskon'),
      (10.0, '10%'),
      (15.0, '15%'),
      (20.0, '20%'),
    ];

    final isEPolis = widget.polisType == QsPolisType.ePolis;
    final admDetail = isEPolis
        ? 'e-Polis: Materai Rp 10.000 (tanpa Biaya Polis)'
        : 'Biaya Polis Rp 20.000 + Materai Rp 10.000';
    final admAmount = isEPolis ? 'Rp 10.000' : 'Rp 30.000';
    final isDiscOver = _diskonPersen > 20.0;
    final isDiscEmpty = widget.diskonCtrl.text.trim().isEmpty;

    return _buildCard(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.blueLightBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.monetization_on_outlined,
                  size: 18, color: AppColors.navyMbis),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Discount & Adm Cost',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Discount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 6),
            _buildInputWithSuffix(
              controller: widget.diskonCtrl,
              suffixText: '%',
            ),
            if (isDiscEmpty) ...[
              const SizedBox(height: 4),
              const Text(
                'Wajib diisi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.redRequired,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: discOptions.map((opt) {
              final isSelected = (_diskonPersen - opt.$1).abs() < 0.001;
              return InkWell(
                onTap: () {
                  widget.diskonCtrl.text =
                      opt.$1 == 0 ? '0' : opt.$1.toStringAsFixed(0);
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.blueLightBg : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.navyMbis
                          : AppColors.borderDefault,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.navyMbis
                              : AppColors.textLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jenis Polis',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDefault, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<QsPolisType>(
                  value: widget.polisType,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blueInputText,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: QsPolisType.cetak,
                      child: Text('Cetak biasa'),
                    ),
                    DropdownMenuItem(
                      value: QsPolisType.ePolis,
                      child: Text('e-Polis (hanya Materai Rp 10.000)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) widget.onPolisTypeChanged(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgLightGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      admDetail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    admAmount,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyMbis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'e-Polis: hanya dikenakan Materai (tanpa Biaya Polis). Cetak biasa: Biaya Polis + Materai. Nominal mengikuti ketentuan UW.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.alertTitle,
                height: 1.4,
              ),
            ),
          ],
        ),
        if (isDiscOver) ...[
          const SizedBox(height: 14),
          const Text(
            'Maksimal diskon 20% (include VAT)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.redRequired,
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Text(
          'Diskon maks. 20% (include VAT). Biaya admin mengikuti Jenis Polis.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 8. Card Rincian Biaya Asuransi Otomatis
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRincianBiayaCard() {
    final res = _calculatedPremi;
    final gross = res.gross;
    final diskAmt = res.diskon;
    final netto = res.netto;
    final adm = res.biayaAdmin;
    final total = res.total;

    final discPercentStr = _diskonPersen.toStringAsFixed(2);

    final n = widget.jumlahOrang;
    final hari = widget.jumlahHari;

    late final String lblA;
    late final String premiAStr;
    late final bool showC;
    late final String lblC;
    late final String premiCStr;

    switch (widget.premiMode) {
      case QsPremiMode.normal:
        lblA = 'Premi Jaminan Pokok${n > 1 ? ' (× $n orang)' : ''}';
        premiAStr = 'Rp ${_currFmt.format(res.premiPokok)}';
        showC = true;
        lblC = 'Premi Jaminan Tambahan${n > 1 ? ' (× $n orang)' : ''}';
        premiCStr = 'Rp ${_currFmt.format(res.premiTambahan)}';
        break;

      case QsPremiMode.flat:
        final tarif = _parseNum(widget.tarifFlatCtrl.text);
        final eff = widget.tarifFlatCtrl.text.isNotEmpty ? tarif : _saranFlatPerHari;
        lblA = 'Premi Flat (Rp ${_currFmt.format(eff)} × $hari hari × $n)';
        premiAStr = 'Rp ${_currFmt.format(gross)}';
        showC = false;
        lblC = '';
        premiCStr = '';
        break;

      case QsPremiMode.mutlak:
        lblA = 'Premi Jaminan Pokok (mutlak)';
        premiAStr = 'Rp ${_currFmt.format(res.premiPokok)}';
        showC = true;
        lblC = 'Premi Jaminan Tambahan (mutlak)';
        premiCStr = 'Rp ${_currFmt.format(res.premiTambahan)}';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyMbis, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text.rich(
            TextSpan(
              text: 'Rincian Biaya Asuransi ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              children: [
                TextSpan(
                  text: '· dihitung otomatis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenTotal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(lblA, premiAStr),
          if (showC) ...[
            const SizedBox(height: 10),
            _buildInfoRow(lblC, premiCStr),
          ],
          const SizedBox(height: 10),
          _buildInfoRow('Gross Premi', 'Rp ${_currFmt.format(gross)}'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Discount ($discPercentStr%)',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '– Rp ${_currFmt.format(diskAmt)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.redRequired,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Nett Premi', 'Rp ${_currFmt.format(netto)}'),
          const SizedBox(height: 10),
          _buildInfoRow('Adm Cost', 'Rp ${_currFmt.format(adm)}'),
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: AppColors.borderDivider,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Biaya Asuransi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Rp ${_currFmt.format(total)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenTotal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeaderWithIcon({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.blueLightBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.navyMbis),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrototypeFieldRow({
    required String label,
    required TextEditingController controller,
    bool isNumeric = true,
    bool isCurrency = false,
    bool hasError = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 10,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const SizedBox(
          width: 10,
          child: Text(':', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 11,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasError
                    ? AppColors.redRequired
                    : AppColors.borderDefault,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    keyboardType: isNumeric
                        ? TextInputType.number
                        : TextInputType.text,
                    textAlign: TextAlign.right,
                    cursorColor: AppColors.orangeMbis,
                    inputFormatters: isCurrency
                        ? const [_RupiahInputFormatter()]
                        : (isNumeric
                            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))]
                            : null),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blueInputText,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0',
                    ),
                  ),
                ),
                const Text(
                  ',-',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blueInputText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputWithSuffix({
    required TextEditingController controller,
    required String suffixText,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              cursorColor: AppColors.orangeMbis,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.blueInputText,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '0.00',
              ),
            ),
          ),
          Text(
            suffixText,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Formatter angka ribuan rupiah dengan pemisah titik (.) untuk UI
class _RupiahInputFormatter extends TextInputFormatter {
  const _RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final cleanDigits = digits.replaceFirst(RegExp(r'^0+(?!$)'), '');
    final formatted = formatDigits(cleanDigits);

    final rawCursor = newValue.selection.baseOffset;
    final digitsBeforeCursor = newValue.text
        .substring(0, rawCursor.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    var newCursor = 0;
    var count = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted[i] != '.') {
        count++;
      }
      if (count == digitsBeforeCursor) {
        newCursor = i + 1;
        break;
      }
    }
    if (digitsBeforeCursor == 0) newCursor = 0;
    if (count < digitsBeforeCursor) newCursor = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursor.clamp(0, formatted.length),
      ),
    );
  }

  static String formatDigits(String digits) {
    if (digits.isEmpty) return '';
    final s = digits.replaceFirst(RegExp(r'^0+(?!$)'), '');
    final str = s.isEmpty ? '0' : s;
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(str[i]);
    }
    return buf.toString();
  }
}
