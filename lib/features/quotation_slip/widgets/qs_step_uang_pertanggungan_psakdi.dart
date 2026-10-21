import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'common/rupiah_input_formatter.dart';
import '../qs_form_state.dart';
import 'uang_pertanggungan/psakdi_jenis_risiko_card.dart';
import 'uang_pertanggungan/psakdi_premi_mode_card.dart';
import 'uang_pertanggungan/qs_calculation_mode_banner.dart';
import 'uang_pertanggungan/qs_diskon_biaya_admin_card.dart';
import 'uang_pertanggungan/psakdi_rincian_premi_card.dart';
import 'uang_pertanggungan/qs_risiko_dijamin_card.dart';
import 'uang_pertanggungan/qs_uw_alert_banner.dart';

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
      final formatted = RupiahInputFormatter.formatDigits(digits);
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

  double get _saranFlatPerHari => saranFlatPsakdi(
        upA: _up,
        riskType: widget.riskType,
        upC: widget.risikoC ? _parseNum(widget.upCCtrl.text) : null,
        rateAB: double.tryParse(widget.rateABCtrl.text) ?? _stdRateAB,
        rateC: double.tryParse(widget.rateCCtrl.text) ?? _stdRateC,
      );

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

    final String noPremiShort = widget.premiMode == QsPremiMode.flat
        ? 'Isi tarif flat'
        : 'Isi premi mutlak';

    final discPercentStr = _diskonPersen.toStringAsFixed(
        _diskonPersen.truncateToDouble() == _diskonPersen ? 0 : 2);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Underwriting Deviations Banner
          if (widget.deviations.isNotEmpty) ...[
            QsUwAlertBanner(deviations: widget.deviations),
            const SizedBox(height: 14),
          ],

          // 2. Jenis Risiko PSAKDI
          PsakdiJenisRisikoCard(
            klasifikasiPeserta: widget.klasifikasiPeserta,
            upACtrl: widget.upACtrl,
            riskType: widget.riskType,
            onRiskTypeChanged: widget.onRiskTypeChanged,
            risikoC: widget.risikoC,
            onRisikoCChanged: widget.onRisikoCChanged,
            upCCtrl: widget.upCCtrl,
            stdRateA: _stdRateA,
            stdRateAB: _stdRateAB,
            stdRateC: _stdRateC,
            batasC: _batasC,
            onFieldChanged: _onRebuild,
          ),
          const SizedBox(height: 14),

          // 3. Risiko Dijamin
          QsRisikoDijaminCard(
            controller: widget.risikoDijaminCtrl,
            onUseDefaultText: () {
              final jaminan = widget.riskType == PsakdiRiskType.a
                  ? 'Meninggal Dunia'
                  : 'Meninggal Dunia / Cacat Tetap';
              final c = widget.risikoC ? ' dan Biaya Pengobatan' : '';
              widget.risikoDijaminCtrl.text =
                  '$jaminan$c yang disebabkan karena kecelakaan.';
            },
          ),
          const SizedBox(height: 14),

          // 4. Perhitungan Mode Banner
          QsCalculationModeBanner(
            premiMode: widget.premiMode,
            onJumpToStep1: widget.onJumpToStep1,
          ),
          const SizedBox(height: 14),

          // 5. Premi Mode Card (Normal / Flat / Mutlak)
          PsakdiPremiModeCard(
            premiMode: widget.premiMode,
            riskType: widget.riskType,
            risikoC: widget.risikoC,
            rateABCtrl: widget.rateABCtrl,
            rateCCtrl: widget.rateCCtrl,
            klasifikasiPeserta: widget.klasifikasiPeserta,
            stdRateA: _stdRateA,
            stdRateAB: _stdRateAB,
            stdRateC: _stdRateC,
            pipeRate: widget.pipeRate,
            upACtrl: widget.upACtrl,
            upCCtrl: widget.upCCtrl,
            tarifFlatCtrl: widget.tarifFlatCtrl,
            saranFlatPerHari: _saranFlatPerHari,
            jumlahHari: widget.jumlahHari,
            jumlahOrang: widget.jumlahOrang,
            premiMutlakPokokCtrl: widget.premiMutlakPokokCtrl,
            premiMutlakTambahanCtrl: widget.premiMutlakTambahanCtrl,
            onFieldChanged: _onRebuild,
          ),
          const SizedBox(height: 14),

          // 6. Diskon & Biaya Admin Card
          QsDiskonBiayaAdminCard(
            title: 'Diskon & Biaya Admin',
            diskonCtrl: widget.diskonCtrl,
            diskonPersen: _diskonPersen,
            polisType: widget.polisType,
            onPolisTypeChanged: widget.onPolisTypeChanged,
            onFieldChanged: _onRebuild,
          ),
          const SizedBox(height: 14),

          // 7. Rincian Premi Otomatis Card
          PsakdiRincianPremiCard(
            isCalculated: isCalculated,
            noPremiTxt: noPremiTxt,
            noPremiShort: noPremiShort,
            lblPokok: lblA,
            premiPokok: premiA,
            showTambahan: showC,
            lblTambahan: lblC,
            premiTambahan: premiC,
            showGross: showC,
            gross: premiA + premiC,
            diskonAmt: diskAmt,
            diskonPercentStr: discPercentStr,
            netto: netto,
            biayaAdmin: _biayaAdmin.toInt(),
            total: total,
          ),
        ],
      ),
    );
  }
}
