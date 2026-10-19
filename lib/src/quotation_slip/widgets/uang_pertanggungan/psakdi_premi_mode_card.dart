import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/input_with_suffix.dart';
import '../common/qs_section_card.dart';
import '../common/rupiah_input_formatter.dart';
import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Card Section 5 PSAKDI: Suku Premi (Normal), Tarif Flat, atau Premi Mutlak - Prototype 1:1
class PsakdiPremiModeCard extends StatelessWidget {
  final QsPremiMode premiMode;
  final PsakdiRiskType riskType;
  final bool risikoC;
  final TextEditingController rateABCtrl;
  final TextEditingController rateCCtrl;
  final int? klasifikasiPeserta;
  final double stdRateA;
  final double stdRateAB;
  final double stdRateC;
  final String? pipeRate;
  final TextEditingController? upACtrl;
  final TextEditingController? upCCtrl;
  final TextEditingController tarifFlatCtrl;
  final double saranFlatPerHari;
  final int jumlahHari;
  final int jumlahOrang;
  final TextEditingController premiMutlakPokokCtrl;
  final TextEditingController premiMutlakTambahanCtrl;
  final VoidCallback? onFieldChanged;

  const PsakdiPremiModeCard({
    super.key,
    required this.premiMode,
    required this.riskType,
    required this.risikoC,
    required this.rateABCtrl,
    required this.rateCCtrl,
    required this.klasifikasiPeserta,
    required this.stdRateA,
    required this.stdRateAB,
    required this.stdRateC,
    this.pipeRate,
    this.upACtrl,
    this.upCCtrl,
    required this.tarifFlatCtrl,
    required this.saranFlatPerHari,
    required this.jumlahHari,
    required this.jumlahOrang,
    required this.premiMutlakPokokCtrl,
    required this.premiMutlakTambahanCtrl,
    this.onFieldChanged,
  });

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    switch (premiMode) {
      case QsPremiMode.normal:
        return _buildPsakdiSukuPremiCard(context);
      case QsPremiMode.flat:
        return _buildTarifFlatCard(context);
      case QsPremiMode.mutlak:
        return _buildPremiMutlakCard(context);
    }
  }

  // ==========================================
  // 1. Suku Premi Card (Mode Normal)
  // ==========================================
  Widget _buildPsakdiSukuPremiCard(BuildContext context) {
    final pokokLabel = riskType == PsakdiRiskType.a ? 'A' : 'A/B';
    final pokokStdRate =
        riskType == PsakdiRiskType.a ? stdRateA : stdRateAB;
    final hasC = riskType == PsakdiRiskType.ab && risikoC;

    final stdText = klasifikasiPeserta != null
        ? 'Tarif standar Kelas $klasifikasiPeserta: $pokokLabel ${pokokStdRate.toStringAsFixed(2)}%${hasC ? ' · C ${stdRateC.toStringAsFixed(2)}%' : ''}'
        : 'Pilih Klasifikasi Peserta (tab Pertanggungan) untuk tarif standar';

    final rateABEmpty = rateABCtrl.text.trim().isEmpty;
    final rateCEmpty = hasC && rateCCtrl.text.trim().isEmpty;

    final rateABNum =
        double.tryParse(rateABCtrl.text.replaceAll(',', '.')) ?? 0;
    final rateCNum = double.tryParse(rateCCtrl.text.replaceAll(',', '.')) ?? 0;

    final offStd = (rateABNum > 0 && (rateABNum - pokokStdRate).abs() > 0.001) ||
        (hasC && rateCNum > 0 && (rateCNum - stdRateC).abs() > 0.001);

    return QsSectionCard(
      icon: Icons.monetization_on_outlined,
      title: 'Suku Premi',
      subtitle: 'Terisi otomatis dari tabel tarif, bisa disesuaikan',
      children: [
        // Box Tarif Standar
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
        const SizedBox(height: 14),

        // Grid Input Suku Premi (2 Kolom)
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
                          text: '*',
                          style: TextStyle(
                            color: AppColors.redRequired,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  InputWithSuffix(
                    controller: rateABCtrl,
                    suffixText: '%/thn',
                    hasError: rateABEmpty,
                    onChanged: (_) => onFieldChanged?.call(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasC
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
                                text: '*',
                                style: TextStyle(
                                  color: AppColors.redRequired,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        InputWithSuffix(
                          controller: rateCCtrl,
                          suffixText: '%/thn',
                          hasError: rateCEmpty,
                          onChanged: (_) => onFieldChanged?.call(),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),

        // Warning Banner: Di luar tarif standar
        if (offStd) ...[
          const SizedBox(height: 14),
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
                  Icons.error_outline,
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
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    rateABCtrl.text = pokokStdRate.toStringAsFixed(2);
                    if (hasC) {
                      rateCCtrl.text = stdRateC.toStringAsFixed(2);
                    }
                    onFieldChanged?.call();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.orangeMbis,
                        width: 1.5,
                      ),
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
                ),
              ],
            ),
          ),
        ],

        // Rate di pipeline (pembanding)
        if (pipeRate != null && pipeRate!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final pipeNum =
                double.tryParse(pipeRate!.replaceAll(',', '.')) ?? 0;
            final pipeFmt =
                pipeNum.toStringAsFixed(2).replaceAll('.', ',');
            return Text(
              'Rate di pipeline: $pipeFmt% (pembanding)',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            );
          }),
        ],
      ],
    );
  }

  // ==========================================
  // 2. Tarif Flat Card (Mode Flat)
  // ==========================================
  Widget _buildTarifFlatCard(BuildContext context) {
    final currFmt = NumberFormat('#,##0', 'id');
    final saranStr = currFmt.format(saranFlatPerHari.round());

    final curFlat = _parseNum(tarifFlatCtrl.text).round();
    final isManual = curFlat > 0 && curFlat != saranFlatPerHari.round();

    final flatRateVal = _parseNum(tarifFlatCtrl.text);
    final totalFlat = flatRateVal * jumlahHari * jumlahOrang;
    final flatTxt =
        'Tarif Rp ${currFmt.format(flatRateVal)} × $jumlahHari hari × $jumlahOrang orang = Rp ${currFmt.format(totalFlat)}';

    final flatEmpty = tarifFlatCtrl.text.trim().isEmpty;

    return QsSectionCard(
      icon: Icons.monetization_on_outlined,
      title: 'Tarif Flat',
      subtitle: 'Premi = tarif per hari × jumlah hari × jumlah peserta',
      children: [
        // Label Input
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
                text: '*',
                style: TextStyle(
                  color: AppColors.redRequired,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Input 52px height
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: flatEmpty
                  ? AppColors.redRequired
                  : AppColors.borderDefault,
              width: 1.5,
            ),
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
                  controller: tarifFlatCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [RupiahInputFormatter()],
                  onChanged: (_) => onFieldChanged?.call(),
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

        // Helper Saran Sistem
        Text(
          'Saran sistem: Rp $saranStr/hari (premi tahunan Normal ÷ 365, dibulatkan ke atas)',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),

        // Tombol Reset Manual ke Saran Sistem
        if (isManual) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              tarifFlatCtrl.text =
                  currFmt.format(saranFlatPerHari.round());
              onFieldChanged?.call();
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
        ],
        const SizedBox(height: 12),

        // Summary Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgInfoBanner,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                'Jumlah hari (dari periode)',
                '$jumlahHari hari',
              ),
              const SizedBox(height: 6),
              _buildSummaryRow('Jumlah peserta', '$jumlahOrang orang'),
              const SizedBox(height: 8),
              Text(
                flatTxt,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Bottom Note
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

  // ==========================================
  // 3. Premi Mutlak Card (Mode Mutlak)
  // ==========================================
  Widget _buildPremiMutlakCard(BuildContext context) {
    final currFmt = NumberFormat('#,##0', 'id');
    final pokokLabel = riskType == PsakdiRiskType.a ? 'A' : 'A/B';
    final pokokStdRate =
        riskType == PsakdiRiskType.a ? stdRateA : stdRateAB;
    final hasC = riskType == PsakdiRiskType.ab && risikoC;

    final upA = _parseNum(upACtrl?.text ?? '');
    final upC = _parseNum(upCCtrl?.text ?? '');

    final premAPokok = _parseNum(premiMutlakPokokCtrl.text);
    final premCVal = _parseNum(premiMutlakTambahanCtrl.text);

    // Hitung tarif standar mutlak
    final stdA = (upA *
            (pokokStdRate / 100) *
            (jumlahHari / 365) *
            jumlahOrang)
        .round();
    final stdC = hasC
        ? (upC *
                (stdRateC / 100) *
                (jumlahHari / 365) *
                jumlahOrang)
            .round()
        : 0;

    final isManual = (premAPokok > 0 && premAPokok.round() != stdA) ||
        (hasC && premCVal > 0 && premCVal.round() != stdC);

    final impAB = (upA > 0 && premAPokok > 0)
        ? 'setara ${(premAPokok / upA * 100).toStringAsFixed(2)}%/thn'
        : '';
    final impC = (upC > 0 && premCVal > 0)
        ? 'setara ${(premCVal / upC * 100).toStringAsFixed(2)}%/thn'
        : '';

    return QsSectionCard(
      icon: Icons.monetization_on_outlined,
      title: 'Premi Mutlak',
      subtitle: 'Nominal premi diisi langsung, tanpa suku premi',
      children: [
        // 1. Input Premi Pokok (A atau A/B)
        Text.rich(
          TextSpan(
            text: 'Premi $pokokLabel',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textLabel,
            ),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(
                  color: AppColors.redRequired,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildMutlakInput(premiMutlakPokokCtrl),
        if (impAB.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '$impAB (info, tidak tercetak)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],

        // 2. Input Premi C (jika aktif)
        if (hasC) ...[
          const SizedBox(height: 12),
          const Text.rich(
            TextSpan(
              text: 'Premi C',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: AppColors.redRequired,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildMutlakInput(premiMutlakTambahanCtrl),
          if (impC.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$impC (info, tidak tercetak)',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),

        // Catatan Dokumen QS
        const Text(
          'Di dokumen QS, Suku Premi tertulis "-".',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),

        // Banner Auto vs Manual
        if (!isManual) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgInfoBanner,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.navyMbis,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    klasifikasiPeserta != null
                        ? 'Terisi otomatis dari tarif standar Kelas $klasifikasiPeserta ($pokokLabel ${pokokStdRate.toStringAsFixed(2)}%${hasC ? ', C ${stdRateC.toStringAsFixed(2)}%' : ''}). Ubah bila ada kesepakatan premi.'
                        : 'Pilih Klasifikasi Peserta (tab Pertanggungan) agar premi terisi otomatis dari tarif standar.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.navyMbis,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
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
                  'Diubah manual · tarif standar: Rp ${currFmt.format(stdA)} ($pokokLabel)${hasC ? ' / Rp ${currFmt.format(stdC)} (C)' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.alertText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    premiMutlakPokokCtrl.text =
                        currFmt.format(stdA);
                    if (hasC) {
                      premiMutlakTambahanCtrl.text =
                          currFmt.format(stdC);
                    } else {
                      premiMutlakTambahanCtrl.clear();
                    }
                    onFieldChanged?.call();
                  },
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppColors.orangeMbis,
                        width: 1.5,
                      ),
                    ),
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
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMutlakInput(TextEditingController ctrl) {
    final empty = ctrl.text.trim().isEmpty;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: empty ? AppColors.redRequired : AppColors.borderDefault,
          width: 1.5,
        ),
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
              inputFormatters: const [RupiahInputFormatter()],
              onChanged: (_) => onFieldChanged?.call(),
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

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
