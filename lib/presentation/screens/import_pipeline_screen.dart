import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../src/admin/export_repository.dart';
import '../../src/common/file_opener.dart';
import '../../theme/app_theme.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/max_width_body.dart';

/// Admin: impor excel pipeline WON ("pipeline sukses dari RM yang belum diinput").
/// Format = template diperluas (unduh via tombol). Baris valid masuk; baris
/// bermasalah dilaporkan tanpa menggagalkan sisanya.
class ImportPipelineScreen extends ConsumerStatefulWidget {
  const ImportPipelineScreen({super.key});

  @override
  ConsumerState<ImportPipelineScreen> createState() => _ImportPipelineScreenState();
}

class _ImportPipelineScreenState extends ConsumerState<ImportPipelineScreen> {
  ExportRepository get _repo => ref.read(exportRepoProvider);

  List<int>? _bytes;
  String? _fileName;
  bool _busy = false;
  PipelineImportResult? _result;

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
      final f = await _repo.downloadImportTemplate();
      final ok = await downloadBytes(
          f.bytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          f.fileName);
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? 'Template diunduh: ${f.fileName}' : 'Perangkat tidak mendukung unduh'),
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
      final result = await _repo.importPipelines(bytes, _fileName ?? 'import.xlsx');
      setState(() => _result = result);
      messenger.showSnackBar(SnackBar(
        content: Text('Impor selesai: ${result.inserted} masuk, '
            '${result.skippedDuplicate} duplikat, ${result.failed} gagal'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.failed == 0 ? AppColors.successGreen : AppColors.secondaryOrange,
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
      appBar: const BackAppBar(title: 'Impor Pipeline'),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _infoCard(),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _busy ? null : _downloadTemplate,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Unduh Template'),
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
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file, size: 18),
              label: const Text('Impor'),
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
          Text('Impor Pipeline WON',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          SizedBox(height: 8),
          Text(
            'Untuk memasukkan pipeline yang sudah sukses (WON) dari RM tapi belum '
            'diinput manual. Gunakan template: kolom wajib NIP RM, NPWP Customer, '
            'No. Polis, dan Realisasi (IDR). No. Polis dipakai untuk mencegah dobel.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(PipelineImportResult r) {
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
          const Text('Hasil Impor',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          _statRow('Total baris', '${r.total}', AppColors.textPrimary),
          _statRow('Berhasil dibuat', '${r.inserted}', AppColors.successGreen),
          _statRow('Dilewati (duplikat)', '${r.skippedDuplicate}', AppColors.secondaryOrange),
          _statRow('Gagal', '${r.failed}', AppColors.errorRed),
          if (r.errors.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Detail baris gagal',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            for (final e in r.errors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('Baris ${e.row}: ${e.message}',
                    style: const TextStyle(fontSize: 12, color: AppColors.errorRed)),
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
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
