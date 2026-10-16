import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../qs_form_state.dart';

/// Tab 2 – Uang Pertanggungan & Suku Premi Khusus PSAKDI (Prototype 1:1).
class QsStepUangPertanggunganPsakdi extends StatefulWidget {
  final QsType type;
  final QsPremiMode premiMode;
  final GlobalKey<FormState> formKey;

  final TextEditingController upACtrl;
  final PsakdiRiskType riskType;
  final ValueChanged<PsakdiRiskType> onRiskTypeChanged;
  final bool risikoC;
  final ValueChanged<bool> onRisikoCChanged;
  final TextEditingController upCCtrl;
  final TextEditingController rateABCtrl;
  final TextEditingController rateCCtrl;

  final TextEditingController risikoDijaminCtrl;
  final TextEditingController diskonCtrl;
  final QsPolisType polisType;
  final ValueChanged<QsPolisType> onPolisTypeChanged;

  final TextEditingController premiMutlakPokokCtrl;
  final TextEditingController premiMutlakTambahanCtrl;
  final TextEditingController tarifFlatCtrl;

  final int jumlahHari;
  final int jumlahOrang;
  final int? klasifikasiPeserta;
  final List<UwDeviation> deviations;
  final VoidCallback? onJumpToStep1;
  final String? pipeRate;

  const QsStepUangPertanggunganPsakdi({
    super.key,
    required this.type,
    required this.premiMode,
    required this.formKey,
    required this.upACtrl,
    required this.riskType,
    required this.onRiskTypeChanged,
    required this.risikoC,
    required this.onRisikoCChanged,
    required this.upCCtrl,
    required this.rateABCtrl,
    required this.rateCCtrl,
    required this.risikoDijaminCtrl,
    required this.diskonCtrl,
    required this.polisType,
    required this.onPolisTypeChanged,
    required this.premiMutlakPokokCtrl,
    required this.premiMutlakTambahanCtrl,
    required this.tarifFlatCtrl,
    required this.jumlahHari,
    required this.jumlahOrang,
    required this.klasifikasiPeserta,
    required this.deviations,
    this.onJumpToStep1,
    this.pipeRate = '0.10',
  });

  @override
  State<QsStepUangPertanggunganPsakdi> createState() =>
      _QsStepUangPertanggunganPsakdiState();
}

class _QsStepUangPertanggunganPsakdiState
    extends State<QsStepUangPertanggunganPsakdi> {
  final _currFmt = NumberFormat('#,##0', 'id');

  @override
  void initState() {
    super.initState();
    _formatInitialText(widget.upACtrl);
    _formatInitialText(widget.upCCtrl);
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
  void didUpdateWidget(covariant QsStepUangPertanggunganPsakdi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.upACtrl != oldWidget.upACtrl ||
        widget.upCCtrl != oldWidget.upCCtrl ||
        widget.rateABCtrl != oldWidget.rateABCtrl ||
        widget.rateCCtrl != oldWidget.rateCCtrl ||
        widget.diskonCtrl != oldWidget.diskonCtrl ||
        widget.tarifFlatCtrl != oldWidget.tarifFlatCtrl ||
        widget.premiMutlakPokokCtrl != oldWidget.premiMutlakPokokCtrl ||
        widget.premiMutlakTambahanCtrl != oldWidget.premiMutlakTambahanCtrl) {
      _detachListeners();
      _formatInitialText(widget.upACtrl);
      _formatInitialText(widget.upCCtrl);
      _attachListeners();
    }
  }

  void _attachListeners() {
    widget.upACtrl.addListener(_onRebuild);
    widget.upCCtrl.addListener(_onRebuild);
    widget.rateABCtrl.addListener(_onRebuild);
    widget.rateCCtrl.addListener(_onRebuild);
    widget.diskonCtrl.addListener(_onRebuild);
    widget.tarifFlatCtrl.addListener(_onRebuild);
    widget.premiMutlakPokokCtrl.addListener(_onRebuild);
    widget.premiMutlakTambahanCtrl.addListener(_onRebuild);
  }

  void _detachListeners() {
    widget.upACtrl.removeListener(_onRebuild);
    widget.upCCtrl.removeListener(_onRebuild);
    widget.rateABCtrl.removeListener(_onRebuild);
    widget.rateCCtrl.removeListener(_onRebuild);
    widget.diskonCtrl.removeListener(_onRebuild);
    widget.tarifFlatCtrl.removeListener(_onRebuild);
    widget.premiMutlakPokokCtrl.removeListener(_onRebuild);
    widget.premiMutlakTambahanCtrl.removeListener(_onRebuild);
  }

  @override
  void dispose() {
    _detachListeners();
    super.dispose();
  }

  void _onRebuild() {
    if (mounted) setState(() {});
  }

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  double get _up => _parseNum(widget.upACtrl.text);

  double get _batasC => min(_up * 0.10, 10000000.0);

  int get _kelasIndex => ((widget.klasifikasiPeserta ?? 1) - 1).clamp(0, 3);

  double get _stdRateA => defaultPsakdiRates['A']![_kelasIndex];
  double get _stdRateAB => defaultPsakdiRates['AB']![_kelasIndex];
  double get _stdRateC => defaultPsakdiRates['C']![_kelasIndex];

  double get _biayaAdmin => biayaAdminForPolis(widget.polisType);

  double get _diskonPersen =>
      double.tryParse(widget.diskonCtrl.text.replaceAll(',', '.')) ?? 0;

  PremiResult? get _calculatedPremi {
    final hari = widget.jumlahHari;
    if (hari <= 0) return null;
    final n = widget.jumlahOrang;
    final up = _parseNum(widget.upACtrl.text);
    if (up <= 0) return null;

    switch (widget.premiMode) {
      case QsPremiMode.normal:
        return hitungPsakdiNormal(
          upA: up,
          riskType: widget.riskType,
          upC: widget.risikoC ? _parseNum(widget.upCCtrl.text) : null,
          rateAB: double.tryParse(widget.rateABCtrl.text) ?? 0,
          rateC: double.tryParse(widget.rateCCtrl.text) ?? 0,
          hari: hari,
          jumlahOrang: n,
          diskonPersen: _diskonPersen,
          biayaAdmin: _biayaAdmin,
        );
      case QsPremiMode.mutlak:
        final pokok = _parseNum(widget.premiMutlakPokokCtrl.text);
        final tambahan = _parseNum(widget.premiMutlakTambahanCtrl.text);
        final gross = pokok + tambahan;
        final disk = gross * (_diskonPersen / 100);
        final netto = gross - disk;
        return PremiResult(
          premiPokok: pokok,
          premiTambahan: tambahan,
          gross: gross,
          diskon: disk,
          netto: netto,
          biayaAdmin: _biayaAdmin,
          total: netto + _biayaAdmin,
        );
      case QsPremiMode.flat:
        final tarif = _parseNum(widget.tarifFlatCtrl.text);
        final gross = tarif * hari * n;
        final disk = gross * (_diskonPersen / 100);
        final netto = gross - disk;
        return PremiResult(
          premiPokok: gross,
          premiTambahan: 0,
          gross: gross,
          diskon: disk,
          netto: netto,
          biayaAdmin: _biayaAdmin,
          total: netto + _biayaAdmin,
        );
    }
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

          // 2. Jenis Risiko PSAKDI
          _buildPsakdiJenisRisikoCard(),
          const SizedBox(height: 14),

          // 3. Risiko Dijamin
          _buildRisikoDijaminCard(),
          const SizedBox(height: 14),

          // 4. Perhitungan Mode Banner
          _buildCalculationModeBanner(),
          const SizedBox(height: 14),

          // 5. Premi Mode Card (Normal / Flat / Mutlak)
          _buildPremiModeCard(),
          const SizedBox(height: 14),

          // 6. Diskon & Biaya Admin Card
          _buildDiskonBiayaAdminCard(),
          const SizedBox(height: 14),

          // 7. Rincian Premi Otomatis Card
          _buildRincianPremiCard(),
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
  // 2. Card Jenis Risiko
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPsakdiJenisRisikoCard() {
    final upVal = _parseNum(widget.upACtrl.text);
    final upOver = upVal > 1000000000;
    final cVal = _parseNum(widget.upCCtrl.text);
    final cOver = widget.risikoC && cVal > _batasC;

    return _buildCard(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Jenis Risiko',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                decoration: TextDecoration.underline,
                decorationThickness: 1.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.blueLightBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Kelas ${widget.klasifikasiPeserta ?? 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPrototypeFieldRow(
          label: 'Uang Pertanggungan (Meninggal Dunia)',
          controller: widget.upACtrl,
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
        const SizedBox(height: 10),
        const Text(
          'Pilih salah satu:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 8),
        _buildPsakdiRadioOption(
          letter: 'A',
          title: 'Meninggal Dunia yang disebabkan karena kecelakaan (only)',
          rateText: '${_stdRateA.toStringAsFixed(2)}%',
          isSelected: widget.riskType == PsakdiRiskType.a,
          onTap: () {
            widget.onRiskTypeChanged(PsakdiRiskType.a);
            if (widget.risikoC) {
              widget.onRisikoCChanged(false);
              widget.upCCtrl.clear();
            }
          },
        ),
        const SizedBox(height: 8),
        _buildPsakdiRadioOption(
          letter: 'A/B',
          title: 'Meninggal Dunia / Cacat Tetap yang disebabkan karena kecelakaan',
          rateText: '${_stdRateAB.toStringAsFixed(2)}%',
          isSelected: widget.riskType == PsakdiRiskType.ab,
          onTap: () {
            widget.onRiskTypeChanged(PsakdiRiskType.ab);
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Tambahan:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        _buildPsakdiCheckboxCOption(),
        if (widget.risikoC && widget.riskType == PsakdiRiskType.ab) ...[
          const SizedBox(height: 10),
          _buildPrototypeFieldRow(
            label: 'Biaya Perawatan / Pengobatan',
            controller: widget.upCCtrl,
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
                  'Melebihi batas maks. Rp ${_currFmt.format(_batasC)} (10% UP, maks. Rp 10.000.000)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.redRequired,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 10),
        const Text.rich(
          TextSpan(
            text: 'A dan A/B tidak bisa dipilih bersamaan. ',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: 'A tidak bisa digabung dengan C',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ' (C hanya bersama A/B). Maks. C: 10% UP atau Rp 10.000.000.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPsakdiRadioOption({
    required String letter,
    required String title,
    required String rateText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSelectedCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.navyMbis
                      : AppColors.borderInactive,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
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
                  Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyMbis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                rateText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPsakdiCheckboxCOption() {
    final isDisabled = widget.riskType == PsakdiRiskType.a;
    final isChecked = widget.risikoC && !isDisabled;

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

    final textColor = isDisabled
        ? AppColors.textDisabled
        : AppColors.textDark;

    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              final nextVal = !widget.risikoC;
              widget.onRisikoCChanged(nextVal);
              if (!nextVal) widget.upCCtrl.clear();
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBd, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: boxBd, width: 1.5),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'C',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDisabled
                              ? AppColors.textDisabled
                              : AppColors.navyMbis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Biaya Perawatan / Pengobatan',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${_stdRateC.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDisabled
                          ? AppColors.textDisabled
                          : AppColors.navyMbis,
                    ),
                  ),
                ),
              ],
            ),
            if (isDisabled)
              const Padding(
                padding: EdgeInsets.only(left: 34, top: 6),
                child: Text(
                  'C tidak bisa digabung dengan A. Pilih A/B untuk menambahkan C.',
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
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Card Risiko Dijamin
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRisikoDijaminCard() {
    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.shield_outlined,
          title: 'Risiko Dijamin',
          subtitle: 'Teks di dokumen, terisi otomatis dari Jenis Risiko',
        ),
        const SizedBox(height: 12),
        const Text(
          'Uraian risiko *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.risikoDijaminCtrl,
          maxLines: 3,
          cursorColor: AppColors.orangeMbis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.blueInputText,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: 'Uraian risiko yang dijamin',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.hintText,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDefault, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDefault, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.orangeMbis, width: 2.0),
            ),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            final jaminan = widget.riskType == PsakdiRiskType.a
                ? 'Meninggal Dunia'
                : 'Meninggal Dunia / Cacat Tetap';
            final c = widget.risikoC ? ' dan Biaya Pengobatan' : '';
            widget.risikoDijaminCtrl.text =
                '$jaminan$c yang disebabkan karena kecelakaan.';
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Gunakan teks standar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navyMbis,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Banner Mode Perhitungan
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
  // 5. Card Suku Premi / Tarif Flat / Premi Mutlak
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPremiModeCard() {
    switch (widget.premiMode) {
      case QsPremiMode.normal:
        return _buildPsakdiSukuPremiCard();
      case QsPremiMode.flat:
        return _buildTarifFlatCard();
      case QsPremiMode.mutlak:
        return _buildPremiMutlakCard();
    }
  }

  Widget _buildPsakdiSukuPremiCard() {
    final pokokLabel = widget.riskType == PsakdiRiskType.a ? 'A' : 'A/B';
    final pokokStdRate =
        widget.riskType == PsakdiRiskType.a ? _stdRateA : _stdRateAB;
    final cPart =
        widget.risikoC ? ' · C ${_stdRateC.toStringAsFixed(2)}%' : '';
    final stdText =
        'Tarif standar Kelas ${widget.klasifikasiPeserta ?? 1}: $pokokLabel ${pokokStdRate.toStringAsFixed(2)}%$cPart';

    final rateAB =
        double.tryParse(widget.rateABCtrl.text.trim().replaceAll(',', '.')) ??
            0;
    final rateC =
        double.tryParse(widget.rateCCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final isOffStd = (rateAB - pokokStdRate).abs() > 0.0001 ||
        (widget.risikoC && (rateC - _stdRateC).abs() > 0.0001);

    final rateABEmpty = widget.rateABCtrl.text.trim().isEmpty;
    final rateCEmpty = widget.risikoC && widget.rateCCtrl.text.trim().isEmpty;

    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.monetization_on_outlined,
          title: 'Suku Premi',
          subtitle: 'Terisi otomatis dari tabel tarif, bisa disesuaikan',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgInfoBanner,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            stdText,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navyMbis,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Jaminan $pokokLabel',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLabel,
                      ),
                      children: const [
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
                  const SizedBox(height: 6),
                  _buildInputWithSuffix(
                    controller: widget.rateABCtrl,
                    suffixText: '%/thn',
                    hasError: rateABEmpty,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.risikoC
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text.rich(
                          TextSpan(
                            text: 'Jaminan C',
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
                        const SizedBox(height: 6),
                        _buildInputWithSuffix(
                          controller: widget.rateCCtrl,
                          suffixText: '%/thn',
                          hasError: rateCEmpty,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        if (isOffStd) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alertBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.alertBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.orangeDark,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Di luar tarif standar. ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.alertText,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'Pastikan sudah sesuai kewenangan.',
                          style: TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    widget.rateABCtrl.text = pokokStdRate.toStringAsFixed(2);
                    if (widget.risikoC) {
                      widget.rateCCtrl.text = _stdRateC.toStringAsFixed(2);
                    }
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                        color: AppColors.orangeMbis, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text(
                    'Pakai tarif',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.alertTitle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.pipeRate != null && widget.pipeRate!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Rate di pipeline: ${widget.pipeRate}% (pembanding)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTarifFlatCard() {
    final tarif = _parseNum(widget.tarifFlatCtrl.text);
    final saranFlat = saranFlatPsakdi(
      upA: _up,
      riskType: widget.riskType,
      upC: widget.risikoC ? _parseNum(widget.upCCtrl.text) : null,
      rateAB: double.tryParse(widget.rateABCtrl.text) ?? _stdRateAB,
      rateC: double.tryParse(widget.rateCCtrl.text) ?? _stdRateC,
    );

    final formulaTxt =
        'Rp ${_currFmt.format(tarif)} × ${widget.jumlahHari} hari × ${widget.jumlahOrang} orang = Rp ${_currFmt.format(tarif * widget.jumlahHari * widget.jumlahOrang)}';

    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.monetization_on_outlined,
          title: 'Tarif Flat',
          subtitle: 'Premi = tarif per hari × jumlah hari × jumlah peserta',
        ),
        const SizedBox(height: 12),
        const Text(
          'Tarif Flat per Hari *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDefault, width: 1.5),
          ),
          child: Row(
            children: [
              const Text(
                'Rp ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: widget.tarifFlatCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saran sistem: Rp ${_currFmt.format(saranFlat)} / hari',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            if (saranFlat > 0 && tarif != saranFlat)
              InkWell(
                onTap: () {
                  widget.tarifFlatCtrl.text = saranFlat.toStringAsFixed(0);
                  setState(() {});
                },
                child: const Text(
                  'Kembali ke saran sistem',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orangeDark,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgInfoBanner,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Jumlah hari (dari periode)', '${widget.jumlahHari} hari'),
              const SizedBox(height: 6),
              _buildInfoRow('Jumlah peserta', '${widget.jumlahOrang} orang'),
              const SizedBox(height: 8),
              Text(
                formulaTxt,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Premi Flat sudah mencakup seluruh jaminan (A/B dan C).',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiMutlakCard() {
    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.monetization_on_outlined,
          title: 'Premi Mutlak',
          subtitle: 'Nominal premi diisi langsung, tanpa suku premi',
        ),
        const SizedBox(height: 12),
        const Text(
          'Premi Jaminan Pokok (A/B) *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        _buildMutlakInputField(widget.premiMutlakPokokCtrl),
        if (widget.risikoC) ...[
          const SizedBox(height: 12),
          const Text(
            'Premi Jaminan C *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 6),
          _buildMutlakInputField(widget.premiMutlakTambahanCtrl),
        ],
      ],
    );
  }

  Widget _buildMutlakInputField(TextEditingController ctrl) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      child: Row(
        children: [
          const Text(
            'Rp ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Card Diskon & Biaya Admin
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildDiskonBiayaAdminCard() {
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
    final discOver = _diskonPersen > 20.0;
    final isDiscEmpty = widget.diskonCtrl.text.trim().isEmpty;

    return _buildCard(
      children: [
        _buildSectionHeaderWithIcon(
          icon: Icons.monetization_on_outlined,
          title: 'Diskon & Biaya Admin',
        ),
        const SizedBox(height: 12),
        const Text(
          'Diskon',
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
          hasError: isDiscEmpty || discOver,
        ),
        const SizedBox(height: 10),
        Wrap(
          direction: Axis.horizontal,
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: discOptions.map((opt) {
            final isSelected = (_diskonPersen - opt.$1).abs() < 0.001;
            return InkWell(
              onTap: () {
                widget.diskonCtrl.text = opt.$1.toStringAsFixed(0);
                setState(() {});
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.blueLightBg
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.navyMbis
                        : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  widthFactor: 1.0,
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.navyMbis
                          : AppColors.textLabel,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
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
            color: Colors.white,
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
        const SizedBox(height: 10),
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
        if (discOver) ...[
          const SizedBox(height: 6),
          const Text(
            'Maksimal diskon 20% (include VAT)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.redRequired,
            ),
          ),
        ],
        const SizedBox(height: 6),
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
  // 7. Card Rincian Premi Otomatis
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildRincianPremiCard() {
    final res = _calculatedPremi;
    final isCalculated = (res?.total ?? 0) > 0;
    final premiA = res?.premiPokok ?? 0;
    final premiC = res?.premiTambahan ?? 0;
    final diskAmt = res?.diskon ?? 0;
    final netto = res?.netto ?? 0;
    final total = res?.total ?? 0;

    final pl = widget.riskType == PsakdiRiskType.a ? 'A' : 'A/B';
    final isGroup = widget.type == QsType.group;
    final h = widget.jumlahHari;
    final n = widget.jumlahOrang;

    final String lblA;
    switch (widget.premiMode) {
      case QsPremiMode.normal:
        final rateStr = widget.rateABCtrl.text.trim().isEmpty
            ? '0.00'
            : widget.rateABCtrl.text.trim();
        final nText = isGroup ? ' × $n orang' : '';
        lblA = 'Premi $pl ($rateStr% × UP A × $h/365$nText)';
        break;
      case QsPremiMode.flat:
        final flatVal = _parseNum(widget.tarifFlatCtrl.text);
        final flatStr = _currFmt.format(flatVal);
        lblA = 'Premi Flat (Rp $flatStr × $h hari × $n)';
        break;
      case QsPremiMode.mutlak:
        lblA = 'Premi $pl (mutlak)';
        break;
    }

    final String lblC;
    switch (widget.premiMode) {
      case QsPremiMode.normal:
        final rateStr = widget.rateCCtrl.text.trim().isEmpty
            ? '0.00'
            : widget.rateCCtrl.text.trim();
        final nText = isGroup ? ' × $n orang' : '';
        lblC = 'Premi C ($rateStr% × UP C × $h/365$nText)';
        break;
      case QsPremiMode.flat:
        lblC = 'Premi C';
        break;
      case QsPremiMode.mutlak:
        lblC = 'Premi C (mutlak)';
        break;
    }

    final showC = widget.premiMode != QsPremiMode.flat && widget.risikoC;

    final String noPremiTxt = widget.premiMode == QsPremiMode.flat
        ? 'Premi belum terbentuk. Isi tarif flat per hari terlebih dahulu.'
        : 'Premi belum terbentuk. Isi nominal Premi $pl terlebih dahulu.';

    final discPercentStr = _diskonPersen.toStringAsFixed(
        _diskonPersen.truncateToDouble() == _diskonPersen ? 0 : 2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyMbis, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Rincian Premi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '· dihitung otomatis',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greenTotal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            lblA,
            'Rp ${_currFmt.format(premiA)}',
          ),
          if (showC) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              lblC,
              'Rp ${_currFmt.format(premiC)}',
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Diskon ($discPercentStr%)',
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
          _buildInfoRow(
            'Premi Netto',
            'Rp ${_currFmt.format(netto)}',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Biaya Admin',
            'Rp ${_currFmt.format(_biayaAdmin)}',
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.borderDivider),
          const SizedBox(height: 12),
          if (!isCalculated) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.alertBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.alertBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.orangeDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      noPremiTxt,
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
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Total Premi',
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
        color: Colors.white,
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
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
        ),
        const Text(':', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
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
                    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                    textAlign: TextAlign.right,
                    inputFormatters: isCurrency
                        ? [const _RupiahInputFormatter()]
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
    bool hasError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                    hintStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Wajib diisi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.redRequired,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color valueColor = AppColors.textDark,
  }) {
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
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: valueColor,
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

