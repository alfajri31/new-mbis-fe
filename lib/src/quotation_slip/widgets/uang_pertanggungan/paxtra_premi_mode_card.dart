import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/qs_section_card.dart';
import '../common/rupiah_input_formatter.dart';
import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Card Biaya Asuransi PA Xtra (Normal, Flat, atau Mutlak) - StatelessWidget
class PaXtraPremiModeCard extends StatelessWidget {
  final QsPremiMode premiMode;
  final double ratePokok;
  final double dasarJaminanTambahan;
  final double rateTambahanOtomatis;
  final double premiPokokStandar;
  final double premiTambahanStandar;
  final double upVal;
  final int jumlahHari;
  final int jumlahOrang;

  // Flat mode
  final TextEditingController tarifFlatCtrl;
  final double saranFlatPerHari;
  final double saranFlatRaw;
  final bool isFlatManual;
  final VoidCallback onResetFlatToSaran;

  // Mutlak mode
  final TextEditingController premiMutlakPokokCtrl;
  final TextEditingController premiMutlakTambahanCtrl;
  final bool isMutlakManual;
  final VoidCallback onResetMutlakToStandar;

  final VoidCallback? onFieldChanged;

  const PaXtraPremiModeCard({
    super.key,
    required this.premiMode,
    required this.ratePokok,
    required this.dasarJaminanTambahan,
    required this.rateTambahanOtomatis,
    required this.premiPokokStandar,
    required this.premiTambahanStandar,
    required this.upVal,
    required this.jumlahHari,
    required this.jumlahOrang,
    required this.tarifFlatCtrl,
    required this.saranFlatPerHari,
    required this.saranFlatRaw,
    required this.isFlatManual,
    required this.onResetFlatToSaran,
    required this.premiMutlakPokokCtrl,
    required this.premiMutlakTambahanCtrl,
    required this.isMutlakManual,
    required this.onResetMutlakToStandar,
    this.onFieldChanged,
  });

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    switch (premiMode) {
      case QsPremiMode.normal:
        return _buildPaXtraNormalBiayaCard();
      case QsPremiMode.flat:
        return _buildTarifFlatCard();
      case QsPremiMode.mutlak:
        return _buildPremiMutlakCard();
    }
  }

  Widget _buildPaXtraNormalBiayaCard() {
    final currFmt = NumberFormat('#,##0', 'id');
    final String lblA =
        'Premi Jaminan Pokok${jumlahOrang > 1 ? ' (× $jumlahOrang orang)' : ''}';
    final String lblC =
        'Premi Jaminan Tambahan${jumlahOrang > 1 ? ' (× $jumlahOrang orang)' : ''}';

    return QsSectionCard(
      icon: Icons.monetization_on_outlined,
      title: 'Biaya Asuransi · Normal',
      subtitle: 'Dihitung otomatis dari tarif standar PA Xtra',
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgLightGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                  'Rate Jaminan Pokok', '${ratePokok.toStringAsFixed(2)}%'),
              const SizedBox(height: 8),
              _buildInfoRow('Dasar Jaminan Tambahan',
                  'Rp ${currFmt.format(dasarJaminanTambahan)}'),
              const SizedBox(height: 8),
              _buildInfoRow('Rate Jaminan Tambahan (otomatis)',
                  '${rateTambahanOtomatis.toStringAsFixed(4)}%'),
              const SizedBox(height: 8),
              _buildInfoRow(lblA, 'Rp ${currFmt.format(premiPokokStandar)}'),
              const SizedBox(height: 8),
              _buildInfoRow(lblC, 'Rp ${currFmt.format(premiTambahanStandar)}'),
            ],
          ),
        ),
        if (upVal <= 0) ...[
          const SizedBox(height: 14),
          _buildNoPremiAlert(
            message: 'Premi belum terbentuk. Isi UP Meninggal Dunia.',
          ),
        ],
      ],
    );
  }

  Widget _buildTarifFlatCard() {
    final currFmt = NumberFormat('#,##0', 'id');
    final currFmtDec = NumberFormat('#,##0.00', 'id');
    final sugRp = 'Rp ${currFmtDec.format(saranFlatRaw)}';

    final currentTarif = _parseNum(tarifFlatCtrl.text);
    final isManual = isFlatManual ||
        (currentTarif > 0 && currentTarif != saranFlatPerHari);

    final formulaTxt =
        'Rp ${currFmt.format(currentTarif)} × $jumlahHari hari × $jumlahOrang orang = Rp ${currFmt.format(currentTarif * jumlahHari * jumlahOrang)}';

    return QsSectionCard(
      icon: Icons.monetization_on_outlined,
      title: 'Biaya Asuransi · Flat',
      subtitle: 'Premi = tarif per hari × hari × jumlah orang',
      children: [
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
                      controller: tarifFlatCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [RupiahInputFormatter()],
                      onChanged: (_) {
                        onFieldChanged?.call();
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
                  onTap: onResetFlatToSaran,
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
    final currFmt = NumberFormat('#,##0', 'id');
    final currentPokok = _parseNum(premiMutlakPokokCtrl.text);
    final currentTambahan = _parseNum(premiMutlakTambahanCtrl.text);
    final isManual = isMutlakManual ||
        ((currentPokok > 0 && currentPokok != premiPokokStandar) ||
            (currentTambahan > 0 && currentTambahan != premiTambahanStandar));

    final formulaTxt =
        'Rp ${currFmt.format(currentPokok)} + Rp ${currFmt.format(currentTambahan)} = Rp ${currFmt.format(currentPokok + currentTambahan)}';

    return QsSectionCard(
      icon: Icons.monetization_on_outlined,
      title: 'Biaya Asuransi · Mutlak',
      subtitle:
          'Nominal premi langsung per polis untuk seluruh periode dan peserta',
      children: [
        // Premi Jaminan Pokok
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text.rich(
              TextSpan(
                text: 'Premi Jaminan Pokok (mutlak)',
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
            _buildMutlakInputField(premiMutlakPokokCtrl, onChanged: onFieldChanged),
          ],
        ),
        const SizedBox(height: 14),
        // Premi Jaminan Tambahan
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Premi Jaminan Tambahan (mutlak)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 8),
            _buildMutlakInputField(premiMutlakTambahanCtrl, onChanged: onFieldChanged),
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
        if (currentPokok <= 0) ...[
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: AppColors.navyMbis),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Terisi otomatis dari tarif standar: Rp ${currFmt.format(premiPokokStandar)} (Pokok) / Rp ${currFmt.format(premiTambahanStandar)} (Tambahan). Bisa diubah.',
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
                  'Diubah manual · tarif standar: Rp ${currFmt.format(premiPokokStandar)} (Pokok) / Rp ${currFmt.format(premiTambahanStandar)} (Tambahan)',
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
                    onTap: onResetMutlakToStandar,
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
              inputFormatters: const [RupiahInputFormatter()],
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
          const Icon(Icons.info_outline, size: 18, color: AppColors.orangeDark),
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
