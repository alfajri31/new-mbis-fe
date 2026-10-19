import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../quotation_slip/widgets/common/rupiah_input_formatter.dart';
import 'setting_rates_charges_provider.dart';

class SettingRatesChargesScreen extends ConsumerStatefulWidget {
  const SettingRatesChargesScreen({super.key});

  @override
  ConsumerState<SettingRatesChargesScreen> createState() =>
      _SettingRatesChargesScreenState();
}

class _SettingRatesChargesScreenState
    extends ConsumerState<SettingRatesChargesScreen> {
  // Controllers untuk semua field konfigurasi
  late final Map<String, TextEditingController> _ctrls;

  final NumberFormat _thousandFmt = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();
    _ctrls = {};
    final initialValues = ref.read(settingRatesChargesProvider).values;
    _applyValues(initialValues);
  }

  void _applyValues(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      final key = entry.key;
      final val = entry.value;
      String text;
      if (val is int) {
        text = _thousandFmt.format(val).replaceAll(',', '.');
      } else if (val is double) {
        text = val.toStringAsFixed(2);
      } else {
        text = val.toString();
      }

      if (_ctrls.containsKey(key)) {
        _ctrls[key]!.text = text;
      } else {
        _ctrls[key] = TextEditingController(text: text);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _cleanNumber(String text) => text.replaceAll(RegExp(r'[^0-9.]'), '');

  void _handleReset() {
    FocusScope.of(context).unfocus();
    ref.read(settingRatesChargesProvider.notifier).resetToDefaults();
    final defaultValues = ref.read(settingRatesChargesProvider).values;
    setState(() {
      _applyValues(defaultValues);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan dikembalikan ke nilai default.'),
        backgroundColor: AppColors.primaryNavy,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleSave() {
    FocusScope.of(context).unfocus();
    final Map<String, dynamic> submitted = {};
    for (final entry in SettingRatesChargesNotifier.defaultValues.entries) {
      final key = entry.key;
      final defaultVal = entry.value;
      final text = _cleanNumber(_ctrls[key]?.text ?? '');

      if (defaultVal is int) {
        submitted[key] = int.tryParse(text) ?? defaultVal;
      } else if (defaultVal is double) {
        submitted[key] = double.tryParse(text) ?? defaultVal;
      } else {
        submitted[key] = text;
      }
    }

    final changedFields =
        ref.read(settingRatesChargesProvider.notifier).save(submitted);

    final message = changedFields.isNotEmpty
        ? 'Pengaturan disimpan (${changedFields.length} perubahan)'
        : 'Tidak ada perubahan';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: changedFields.isNotEmpty
            ? AppColors.successGreen
            : AppColors.primaryNavy,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgScaffold,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border(bottom: BorderSide(color: AppColors.borderDivider, width: 1)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pengaturan Tarif & Biaya',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'PSAKDI & PA Xtra · UW / Admin',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Section Biaya Admin
                _buildSectionCard(
                  title: 'Biaya Admin',
                  rows: [
                    _RowItem('admPolis', 'Biaya Polis (cetak)', 'Rp'),
                    _RowItem('admMaterai', 'Materai', 'Rp'),
                    _RowItem(
                      'admE',
                      'Biaya e-Polis tambahan (belum diberlakukan)',
                      'Rp',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Section Batas & Diskon
                _buildSectionCard(
                  title: 'Batas & Diskon',
                  rows: [
                    _RowItem('upMax', 'UP maksimal (PSAKDI & PA Xtra)', 'Rp'),
                    _RowItem('cPct', 'Batas C / Pengobatan (% dari UP)', '%'),
                    _RowItem('cMax', 'Batas C / Pengobatan maksimal', 'Rp'),
                    _RowItem('discMax', 'Diskon maksimal', '%'),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Section Rate PA Xtra (%/tahun)
                _buildSectionCard(
                  title: 'Rate PA Xtra (%/tahun)',
                  rows: [
                    _RowItem('p_pokok', 'Kematian (tanpa Cacat Tetap)', '%'),
                    _RowItem('p_cacat', 'Kematian + Cacat Tetap', '%'),
                    _RowItem('p_upC', 'Biaya Perawatan / Pengobatan', '%'),
                    _RowItem('p_ambulan', 'Santunan Ambulan & Evakuasi', '%'),
                    _RowItem('p_pemakaman', 'Santunan Pemakaman / Kremasi', '%'),
                    _RowItem(
                      'p_barang',
                      'Santunan Kehilangan Barang Pribadi',
                      '%',
                    ),
                    _RowItem('p_dokumen', 'Santunan Pengurusan Dokumen', '%'),
                    _RowItem('p_pendidikan', 'Santunan Biaya Pendidikan', '%'),
                    _RowItem('p_repatriasi', 'Santunan Pemulangan Jenazah', '%'),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Section Batas santunan PA Xtra (maksimal)
                _buildSectionCard(
                  title: 'Batas santunan PA Xtra (maksimal)',
                  rows: [
                    _RowItem(
                      'c_upC',
                      'Biaya Perawatan / Pengobatan',
                      'Rp',
                    ),
                    _RowItem(
                      'c_ambulan',
                      'Santunan Ambulan & Evakuasi',
                      'Rp',
                    ),
                    _RowItem(
                      'c_pemakaman',
                      'Santunan Pemakaman / Kremasi',
                      'Rp',
                    ),
                    _RowItem(
                      'c_barang',
                      'Santunan Kehilangan Barang Pribadi',
                      'Rp',
                    ),
                    _RowItem('c_dokumen', 'Santunan Pengurusan Dokumen', 'Rp'),
                    _RowItem('c_pendidikan', 'Santunan Biaya Pendidikan', 'Rp'),
                    _RowItem('c_repatriasi', 'Santunan Pemulangan Jenazah', 'Rp'),
                  ],
                ),
                const SizedBox(height: 14),

                // 5. Section Rate PSAKDI (%/tahun) Tabel
                _buildPsakdiRateTableCard(),
                const SizedBox(height: 12),

                // Keterangan teks di bawah form
                const Text(
                  'Perubahan berlaku untuk QS baru. Di prototype, perhitungan QS yang sedang dibuka ikut menyesuaikan; di sistem nyata QS yang sudah terbit menyimpan tarif saat terbit.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Tombol Aksi
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceWhite,
                          side: const BorderSide(
                            color: AppColors.borderDefault,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _handleReset,
                        child: const Text(
                          'Kembalikan default',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textLabel,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyMbis,
                          foregroundColor: AppColors.surfaceWhite,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _handleSave,
                        child: const Text(
                          'Simpan Pengaturan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 7. Section Riwayat Perubahan
                _buildHistorySectionCard(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  // ── Widget: Card Generic Group dengan Baris 3-Kolom ──
  Widget _buildSectionCard({
    required String title,
    required List<_RowItem> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((r) => _buildRowGrid(r)),
        ],
      ),
    );
  }

  // Baris dengan layout 3-kolom persis di prototype:
  // [label: minmax(0, 1fr)] [input: 120px] [unit: 36px]
  Widget _buildRowGrid(_RowItem item) {
    final ctrl = _ctrls[item.key] ?? TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Kolom 1: Label
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textLabel,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Kolom 2: Input Text Field (lebar fixed ~120px)
          SizedBox(
            width: 135,
            height: 40,
            child: TextFormField(
              controller: ctrl,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              inputFormatters: [
                if (item.unit == 'Rp') ...[
                  FilteringTextInputFormatter.digitsOnly,
                  const RupiahInputFormatter(),
                ] else ...[
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ],
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceWhite,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderDefault, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.navyMbis, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Kolom 3: Unit (Rp atau %)
          SizedBox(
            width: 36,
            child: Text(
              item.unit,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget: Card Rate PSAKDI Matrix Table ──
  Widget _buildPsakdiRateTableCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rate PSAKDI (%/tahun)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 330),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(52),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                  4: FlexColumnWidth(),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Header Baris Kelas
                  const TableRow(
                    children: [
                      SizedBox(height: 28),
                      Center(
                        child: Text(
                          'Kelas 1',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Kelas 2',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Kelas 3',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Kelas 4',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Data Rows: A, A/B, C
                  ...['A', 'AB', 'C'].map((code) {
                    final displayCode = code == 'AB' ? 'A/B' : code;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            displayCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navyMbis,
                            ),
                          ),
                        ),
                        ...List.generate(4, (i) {
                          final key = 'r$code$i';
                          final ctrl = _ctrls[key] ?? TextEditingController();
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 4,
                            ),
                            child: SizedBox(
                              height: 40,
                              child: TextFormField(
                                controller: ctrl,
                                textAlign: TextAlign.center,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'),
                                  ),
                                ],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppColors.surfaceWhite,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 10,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderDefault,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: AppColors.navyMbis,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget: Card Riwayat Perubahan ──
  Widget _buildHistorySectionCard() {
    final logs =
        ref.watch(settingRatesChargesProvider.select((s) => s.logs));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat perubahan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Belum ada perubahan.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(
                color: AppColors.bgDisabled,
                height: 16,
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.at} · ${log.by}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      log.txt,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textLabel,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RowItem {
  final String key;
  final String label;
  final String unit;

  const _RowItem(this.key, this.label, this.unit);
}
