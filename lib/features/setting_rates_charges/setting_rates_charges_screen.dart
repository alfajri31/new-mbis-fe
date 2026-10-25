import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    _ctrls = {
      for (final key in SettingRatesChargesNotifier.fieldLabels.keys)
        key: TextEditingController(),
    };
    final initialValues = ref.read(settingRatesChargesProvider).values;
    _applyValues(initialValues);
  }

  void _applyValues(Map<String, dynamic> values) {
    for (final entry in values.entries) {
      final key = entry.key;
      final val = entry.value;
      String text;
      if (SettingRatesChargesNotifier.intFields.contains(key)) {
        final intNum =
            val is num ? val.toInt() : (int.tryParse(val.toString()) ?? 0);
        text = _thousandFmt.format(intNum).replaceAll(',', '.');
      } else if (val is num) {
        final d = val.toDouble();
        if ((d * 100).truncateToDouble() != d * 100) {
          text = d.toStringAsFixed(4);
        } else {
          text = d.toStringAsFixed(2);
        }
      } else if (val is int) {
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

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final Map<String, dynamic> submitted = {};
    for (final key in SettingRatesChargesNotifier.fieldLabels.keys) {
      final text = _cleanNumber(_ctrls[key]?.text ?? '');
      if (text.isEmpty) continue;

      if (SettingRatesChargesNotifier.intFields.contains(key)) {
        final parsed = int.tryParse(text);
        if (parsed != null) submitted[key] = parsed;
      } else {
        final parsed = double.tryParse(text);
        if (parsed != null) submitted[key] = parsed;
      }
    }

    final result =
        await ref.read(settingRatesChargesProvider.notifier).save(submitted);

    if (!mounted) return;

    if (result.success) {
      _applyValues(ref.read(settingRatesChargesProvider).values);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: result.success
            ? AppColors.successGreen
            : AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleKembalikanDefault() async {
    FocusScope.of(context).unfocus();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.restore_rounded, color: AppColors.navyMbis),
            SizedBox(width: 8),
            Text(
              'Kembalikan ke Default',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin mengembalikan semua tarif dan biaya ke nilai default sistem? Perubahan yang belum disimpan akan digantikan dengan konfigurasi default.',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textLabel,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyMbis,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Ya, Kembalikan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await ref
        .read(settingRatesChargesProvider.notifier)
        .kembalikanDefault();

    if (!mounted) return;

    if (result.success && result.data != null) {
      _applyValues(result.data!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: result.success
            ? AppColors.successGreen
            : AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingRatesChargesProvider);

    // Sinkronisasi form text controller saat data berhasil dimuat dari API
    ref.listen<SettingRatesChargesState>(settingRatesChargesProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading && next.errorMessage == null) {
        _applyValues(next.values);
      }
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgScaffold,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/kelola');
              }
            },
          ),
          titleSpacing: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pengaturan Tarif & Biaya',
                style: TextStyle(
                  fontSize: 18,
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: (state.isLoading || state.isSaving || state.isResetting)
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.navyMbis),
                  )
                : const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.borderDivider,
                  ),
          ),
        ),
        body: state.isLoading && state.values.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.navyMbis),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Memuat pengaturan tarif & biaya dari server...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sinkronisasi konfigurasi PSAKDI & PA Xtra',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : state.errorMessage != null && state.values.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.cloud_off_rounded,
                              size: 40,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Gagal Memuat Pengaturan Tarif',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref
                                  .read(settingRatesChargesProvider.notifier)
                                  .fetchPengaturanTarif();
                            },
                            icon: const Icon(Icons.refresh, size: 17),
                            label: const Text(
                              'Coba Lagi',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyMbis,
                              foregroundColor: AppColors.surfaceWhite,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                // Negative Case: Banner Error
                if (state.errorMessage != null)
                  _buildErrorBanner(state.errorMessage!),

                // Loading State Banner (ketika sedang memuat)
                if (state.isLoading)
                  _buildLoadingBanner(),

                // Resetting State Banner (ketika proses kembalikan default)
                if (state.isResetting)
                  _buildResettingBanner(),
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
                        onPressed: (state.isSaving || state.isResetting)
                            ? null
                            : _handleKembalikanDefault,
                        child: state.isResetting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.navyMbis,
                                  ),
                                ),
                              )
                            : const Text(
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
                        onPressed: (state.isSaving || state.isResetting)
                            ? null
                            : _handleSave,
                        child: state.isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.surfaceWhite,
                                  ),
                                ),
                              )
                            : const Text(
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

  // ── Widget: Banner Error (Negative Case) ──
  Widget _buildErrorBanner(String errorMessage) {
    final isResetError = errorMessage.toLowerCase().contains('default');
    final title = isResetError
        ? 'Gagal Mengembalikan ke Default'
        : 'Kendala Pengaturan Tarif';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFB91C1C),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF991B1B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ref.read(settingRatesChargesProvider.notifier).dismissError();
                },
                tooltip: 'Tutup Pesan',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (isResetError) {
                    _handleKembalikanDefault();
                  } else {
                    ref
                        .read(settingRatesChargesProvider.notifier)
                        .fetchPengaturanTarif();
                  }
                },
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text(
                  'Coba Lagi',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Widget: Banner Loading Saat Fetch Data ──
  Widget _buildLoadingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navyMbis.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.navyMbis.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyMbis),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Menghubungkan ke server untuk mengambil tarif terbaru...',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.navyMbis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget: Banner Resetting Default ──
  Widget _buildResettingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF93C5FD),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyMbis),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sedang mengembalikan pengaturan tarif & biaya ke default sistem...',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E40AF),
              ),
            ),
          ),
        ],
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
    final ctrl =
        _ctrls.putIfAbsent(item.key, () => TextEditingController());

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
                          final ctrl = _ctrls.putIfAbsent(
                              key, () => TextEditingController());
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
    final state = ref.watch(settingRatesChargesProvider);
    final riwayatList = state.riwayatList;
    final isLoading = state.isLoadingRiwayat;
    final errorMessage = state.riwayatErrorMessage;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat perubahan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.navyMbis),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Segarkan Riwayat',
                  onPressed: () {
                    ref
                        .read(settingRatesChargesProvider.notifier)
                        .fetchRiwayat();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Loading State (saat belum ada data)
          if (isLoading && riwayatList.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.navyMbis),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Memuat riwayat perubahan...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]

          // 2. Negative Case (Error State saat fetch riwayat)
          else if (errorMessage != null && riwayatList.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(settingRatesChargesProvider.notifier)
                          .fetchRiwayat();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]

          // 3. Empty State (data kosong murni)
          else if (riwayatList.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada riwayat perubahan.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          ]

          // 4. List Data Riwayat dari API
          else ...[
            if (errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: riwayatList.length,
              separatorBuilder: (context, index) => const Divider(
                color: AppColors.bgDisabled,
                height: 16,
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final item = riwayatList[index];
                final summary = item.generateSummary(
                  SettingRatesChargesNotifier.fieldLabels,
                );
                final isReset = item.action.toUpperCase() == 'RESET_DEFAULT';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${item.formattedTime} · ${item.changedRole}${item.changedBy.isNotEmpty ? ' (${item.changedBy})' : ''}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyMbis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isReset
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isReset
                                  ? const Color(0xFFFCD34D)
                                  : const Color(0xFFBFDBFE),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isReset ? 'RESET' : 'UPDATE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isReset
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF1E40AF),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
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
