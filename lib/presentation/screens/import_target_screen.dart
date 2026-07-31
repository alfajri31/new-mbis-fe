import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../src/admin/target_import_repository.dart';
import '../../src/common/file_opener.dart';
import '../../theme/app_theme.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/max_width_body.dart';

/// Admin: unggah massal target bulanan RM lewat excel. Sebelumnya target hanya
/// bisa diisi lewat seeding SQL. Satu baris = satu RM untuk satu bulan, tiap
/// kategori target jadi satu kolom (unduh template untuk bentuk pastinya).
class ImportTargetScreen extends ConsumerStatefulWidget {
  const ImportTargetScreen({super.key});

  @override
  ConsumerState<ImportTargetScreen> createState() => _ImportTargetScreenState();
}

class _ImportTargetScreenState extends ConsumerState<ImportTargetScreen> {
  TargetImportRepository get _repo => ref.read(targetImportRepoProvider);

  int _year = DateTime.now().year;
  bool _syncYearly = true;
  List<int>? _bytes;
  String? _fileName;
  bool _busy = false;
  TargetImportResult? _result;

  /// Tahun berjalan ± 1: target biasanya disusun untuk tahun depan menjelang
  /// akhir tahun, dan koreksi tahun lalu sesekali masih perlu.
  List<int> get _years {
    final now = DateTime.now().year;
    return [now - 1, now, now + 1];
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    setState(() {
      _bytes = res.files.first.bytes;
      _fileName = res.files.first.name;
      _result = null;
    });
  }

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final f = await _repo.downloadTemplate(_year);
      final ok = await downloadBytes(
          f.bytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          f.fileName);
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? 'Template diunduh: ${f.fileName}'
            : 'Perangkat tidak mendukung unduh'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorRed,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _repo.importTargets(
        bytes,
        _fileName ?? 'target.xlsx',
        year: _year,
        syncYearly: _syncYearly,
      );
      setState(() => _result = result);
      messenger.showSnackBar(SnackBar(
        content: Text('Impor selesai: ${result.upserted} target tersimpan '
            'untuk ${result.rmCount} RM, ${result.failed} baris gagal'),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            result.failed == 0 ? AppColors.successGreen : AppColors.secondaryOrange,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorRed,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Impor Target RM'),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _infoCard(),
            const SizedBox(height: AppSpacing.lg),
            _optionsCard(),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _busy ? null : _downloadTemplate,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text('Unduh Template $_year'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side: const BorderSide(color: AppColors.primaryNavy, width: 1.4),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(_fileName ?? 'Pilih File .xlsx'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border, width: 1.4),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: (_busy || _bytes == null) ? null : _import,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file, size: 18),
              label: const Text('Impor Target'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                disabledBackgroundColor: AppColors.grayBg,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _resultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Impor Target Bulanan RM',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy)),
          SizedBox(height: 8),
          Text(
            'Satu baris = satu RM untuk satu bulan; kategori target (AKK, AKM, SB, '
            'CB, KBG, ASUM, Premi Non Program, Non Program Non AKK, Non Program Non '
            'Askred) jadi kolom. Kolom wajib: NIP RM dan Bulan. Sel yang dikosongkan '
            'tidak mengubah target yang sudah tersimpan; isi 0 untuk menolkan. '
            'Unggah ulang akan memperbarui, bukan menggandakan.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _optionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Tahun target',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _year,
                  borderRadius: BorderRadius.circular(8),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy),
                  items: [
                    for (final y in _years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _year = v ?? _year),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _syncYearly,
            activeThumbColor: AppColors.primaryNavy,
            onChanged: _busy ? null : (v) => setState(() => _syncYearly = v),
            title: const Text('Sinkronkan target tahunan',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            subtitle: const Text(
              'Isi juga target setahun per RM (dipakai kartu Manajemen RM) dari '
              'jumlah 12 bulan kategori Total, atau Non Program Non Askred bila '
              'Total tidak diisi.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(TargetImportResult r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hasil Impor ${r.year}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          _statRow('Baris diproses', '${r.rows}', AppColors.textPrimary),
          _statRow('Target tersimpan', '${r.upserted}', AppColors.successGreen),
          _statRow('RM tersentuh', '${r.rmCount}', AppColors.textPrimary),
          _statRow('Target tahunan disinkronkan', '${r.yearlyUpdated}',
              AppColors.textSecondary),
          _statRow('Baris gagal', '${r.failed}', AppColors.errorRed),
          if (r.errors.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Detail baris gagal',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            for (final e in r.errors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('Baris ${e.row}: ${e.message}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.errorRed)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
