import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'common/rupiah_input_formatter.dart';
import '../qs_form_state.dart';
import 'uang_pertanggungan/paxtra_jaminan_pokok_card.dart';
import 'uang_pertanggungan/paxtra_jaminan_tambahan_card.dart';
import 'uang_pertanggungan/paxtra_premi_mode_card.dart';
import 'uang_pertanggungan/qs_calculation_mode_banner.dart';
import 'uang_pertanggungan/qs_diskon_biaya_admin_card.dart';
import 'uang_pertanggungan/paxtra_rincian_biaya_card.dart';
import 'uang_pertanggungan/qs_risiko_dijamin_card.dart';
import 'uang_pertanggungan/qs_uw_alert_banner.dart';

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
      final formatted = RupiahInputFormatter.formatDigits(digits);
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
      for (final s in kPaxSantunanList)
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

  double get _dasarJaminanTambahan {
    double total = widget.cacatTetap ? _up : 0;
    if (widget.perawatanPengobatan) {
      total += _getSantunanValue('pengobatan');
    }
    for (final s in kPaxSantunanList) {
      total += _getSantunanValue(s.key);
    }
    return total;
  }

  double get _sumPremiSantunanTahunan {
    double total = 0;
    if (widget.perawatanPengobatan) {
      final val = _getSantunanValue('pengobatan');
      final r = _getSantunanRate('pengobatan', 2.0);
      total += val * (r / 100);
    }
    for (final s in kPaxSantunanList) {
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

  double get _premiPokokTahunan => _up * (_ratePokok / 100);

  double get _premiPokokStandar {
    if (widget.jumlahHari <= 0 || _up <= 0) return 0;
    return _premiPokokTahunan * (widget.jumlahHari / 365) * widget.jumlahOrang;
  }

  double get _premiTambahanStandar {
    if (widget.jumlahHari <= 0 || _up <= 0) return 0;
    return _sumPremiSantunanTahunan *
        (widget.jumlahHari / 365) *
        widget.jumlahOrang;
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
        pokok = widget.premiMutlakPokokCtrl.text.isNotEmpty
            ? p
            : _premiPokokStandar;
        tambahan = widget.premiMutlakTambahanCtrl.text.isNotEmpty
            ? t
            : _premiTambahanStandar;
        break;

      case QsPremiMode.flat:
        final tarif = _parseNum(widget.tarifFlatCtrl.text);
        final eff =
            widget.tarifFlatCtrl.text.isNotEmpty ? tarif : _saranFlatPerHari;
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
    // Auto-populate flat jika kosong
    final saranCeil = _saranFlatPerHari;
    if ((widget.tarifFlatCtrl.text.isEmpty ||
            widget.tarifFlatCtrl.text == '0') &&
        saranCeil > 0 &&
        !_flatManual) {
      widget.tarifFlatCtrl.text =
          RupiahInputFormatter.formatDigits(saranCeil.round().toString());
    }

    // Auto-populate mutlak jika kosong
    final stdPokok = _premiPokokStandar;
    final stdTambahan = _premiTambahanStandar;
    if ((widget.premiMutlakPokokCtrl.text.isEmpty ||
            widget.premiMutlakPokokCtrl.text == '0') &&
        stdPokok > 0 &&
        !_mutlakManual) {
      widget.premiMutlakPokokCtrl.text =
          RupiahInputFormatter.formatDigits(stdPokok.round().toString());
    }

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
    late final bool showC;
    late final String lblC;

    switch (widget.premiMode) {
      case QsPremiMode.normal:
        lblA = 'Premi Jaminan Pokok${n > 1 ? ' (× $n orang)' : ''}';
        showC = true;
        lblC = 'Premi Jaminan Tambahan${n > 1 ? ' (× $n orang)' : ''}';
        break;

      case QsPremiMode.flat:
        final tarif = _parseNum(widget.tarifFlatCtrl.text);
        final eff = widget.tarifFlatCtrl.text.isNotEmpty
            ? tarif
            : _saranFlatPerHari;
        lblA = 'Premi Flat (Rp ${_currFmt.format(eff)} × $hari hari × $n)';
        showC = false;
        lblC = '';
        break;

      case QsPremiMode.mutlak:
        lblA = 'Premi Jaminan Pokok (mutlak)';
        showC = true;
        lblC = 'Premi Jaminan Tambahan (mutlak)';
        break;
    }

    const stdTextRisiko =
        'Meninggal Dunia / Cacat Tetap, Biaya Pengobatan dan santunan-santunan yang disebabkan karena kecelakaan.';
    if (widget.risikoDijaminCtrl.text.trim().isEmpty) {
      widget.risikoDijaminCtrl.text = stdTextRisiko;
    }

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

          // 2. Jaminan Pokok
          PaXtraJaminanPokokCard(
            upPaXtraCtrl: widget.upPaXtraCtrl,
            onFieldChanged: _onRebuild,
          ),
          const SizedBox(height: 14),

          // 3. Jaminan Tambahan & Perluasan
          PaXtraJaminanTambahanCard(
            upVal: _up,
            batasC: _batasC,
            cacatTetap: widget.cacatTetap,
            onCacatTetapChanged: widget.onCacatTetapChanged,
            perawatanPengobatan: widget.perawatanPengobatan,
            onPerawatanChanged: widget.onPerawatanChanged,
            getSantunanCtrl: _getSantunanCtrl,
            onFieldChanged: _onRebuild,
          ),
          const SizedBox(height: 14),

          // 4. Risiko Dijamin
          QsRisikoDijaminCard(
            controller: widget.risikoDijaminCtrl,
            onUseDefaultText: () {
              widget.risikoDijaminCtrl.text = stdTextRisiko;
            },
          ),
          const SizedBox(height: 14),

          // 5. Perhitungan Mode Banner
          QsCalculationModeBanner(
            premiMode: widget.premiMode,
            onJumpToStep1: widget.onJumpToStep1,
          ),
          const SizedBox(height: 14),

          // 6. Biaya Asuransi Card (Normal / Flat / Mutlak)
          PaXtraPremiModeCard(
            premiMode: widget.premiMode,
            ratePokok: _ratePokok,
            dasarJaminanTambahan: _dasarJaminanTambahan,
            rateTambahanOtomatis: _rateTambahanOtomatis,
            premiPokokStandar: _premiPokokStandar,
            premiTambahanStandar: _premiTambahanStandar,
            upVal: _up,
            jumlahHari: widget.jumlahHari,
            jumlahOrang: widget.jumlahOrang,
            tarifFlatCtrl: widget.tarifFlatCtrl,
            saranFlatPerHari: saranCeil,
            saranFlatRaw: _saranFlatRaw,
            isFlatManual: _flatManual,
            onResetFlatToSaran: () {
              widget.tarifFlatCtrl.text = RupiahInputFormatter.formatDigits(
                  saranCeil.round().toString());
              setState(() {
                _flatManual = false;
              });
            },
            premiMutlakPokokCtrl: widget.premiMutlakPokokCtrl,
            premiMutlakTambahanCtrl: widget.premiMutlakTambahanCtrl,
            isMutlakManual: _mutlakManual,
            onResetMutlakToStandar: () {
              widget.premiMutlakPokokCtrl.text =
                  RupiahInputFormatter.formatDigits(
                      stdPokok.round().toString());
              widget.premiMutlakTambahanCtrl.text =
                  RupiahInputFormatter.formatDigits(
                      stdTambahan.round().toString());
              setState(() {
                _mutlakManual = false;
              });
            },
            onFieldChanged: _onRebuild,
          ),
          const SizedBox(height: 14),

          // 7. Discount & Adm Cost Card
          QsDiskonBiayaAdminCard(
            title: 'Discount & Adm Cost',
            diskonCtrl: widget.diskonCtrl,
            diskonPersen: _diskonPersen,
            polisType: widget.polisType,
            onPolisTypeChanged: widget.onPolisTypeChanged,
            onFieldChanged: _onRebuild,
          ),
          const SizedBox(height: 14),

          // 8. Rincian Biaya Asuransi Otomatis Card
          PaXtraRincianBiayaCard(
            lblPokok: lblA,
            premiPokok: res.premiPokok,
            showTambahan: showC,
            lblTambahan: lblC,
            premiTambahan: res.premiTambahan,
            gross: gross,
            diskonAmt: diskAmt,
            diskonPercentStr: discPercentStr,
            netto: netto,
            biayaAdmin: adm.toInt(),
            total: total,
          ),
        ],
      ),
    );
  }
}
