import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../src/admin/account_repository.dart';
import '../../src/admin/realisasi_import_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/max_width_body.dart';

/// Admin: unggah rekap realisasi RESMI dari pusat.
///
/// Berkasnya diunggah **apa adanya** — laporan bulanan pusat dengan header tiga
/// tingkat dan ±380 kolom. Tidak ada template yang perlu diunduh dan tidak ada
/// yang perlu dirapikan dulu; server yang membaca strukturnya.
///
/// Dua hal yang sengaja ditegaskan di layar ini:
///  * **Satuan juta.** Berkas menulis 230.71 untuk Rp230.710.000. Salah tafsir
///    di sini meleset 1.000.000× dan tidak memunculkan error apa pun.
///  * **Angka WON tidak hilang.** Unggahan ini hanya mengganti angka yang
///    ditampilkan di dashboard, per bulan yang diunggah. Ekspor tetap memakai
///    realisasi dari pipeline WON.
class ImportRealisasiScreen extends ConsumerStatefulWidget {
  const ImportRealisasiScreen({super.key});

  @override
  ConsumerState<ImportRealisasiScreen> createState() =>
      _ImportRealisasiScreenState();
}

class _ImportRealisasiScreenState extends ConsumerState<ImportRealisasiScreen> {
  RealisasiImportRepository get _repo => ref.read(realisasiImportRepoProvider);

  int _year = DateTime.now().year;
  List<int>? _bytes;
  String? _fileName;
  bool _busy = false;
  RealisasiImportResult? _result;
  List<RealisasiPendingRow> _pending = const [];
  bool _loadingPending = false;
  String _pendingQuery = '';

  /// Penyuntingan pencocokan oleh admin, berkunci `sourceKey`.
  ///
  /// Disimpan di klien, bukan di server: pratinjau memang tidak menyimpan keadaan
  /// apa pun, dan berkasnya sendiri dipegang klien. Seluruh isinya dikirim ulang
  /// pada setiap Periksa maupun Terapkan, jadi yang dinilai server selalu
  /// keseluruhan rencana — bukan tambalan atas rencana sebelumnya.
  final Map<String, RealisasiMatchOverride> _overrides = {};

  /// Kartu antrean yang benar-benar dibangun. Daftarnya di-spread ke dalam
  /// `Column`, jadi SEMUA kartu jadi widget sekaligus — bukan dibangun malas
  /// seperti `ListView.builder`. Satu berkas pusat yang sebagian besar barisnya
  /// bukan RM bisa mengantre ribuan baris, dan membangun ribuan kartu sekaligus
  /// membekukan tab. Dibatasi + disaring, bukan dipaginasi: yang dicari admin
  /// adalah orang tertentu, dan mengetik namanya lebih cepat daripada
  /// membolak-balik halaman.
  static const int _pendingRenderLimit = 50;

  /// Berkas pusat tidak memuat tahun; admin memilihnya. Tahun berjalan ± 1 sudah
  /// cukup — koreksi tahun lalu sesekali masih perlu.
  List<int> get _years {
    final now = DateTime.now().year;
    return [now - 1, now, now + 1];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPending());
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    try {
      final rows = await _repo.pending(year: _year);
      if (mounted) setState(() => _pending = rows);
    } catch (_) {
      // Antrean gagal dimuat tidak boleh menghalangi unggahan; biarkan kosong.
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
      return;
    }
    setState(() {
      _bytes = res.files.first.bytes;
      _fileName = res.files.first.name;
      _result = null; // berkas ganti → pratinjau lama tidak berlaku lagi
      // Suntingan menunjuk baris berkas LAMA. Membiarkannya berarti pemetaan
      // diam-diam berpindah ke baris lain yang kebetulan ber-NIP sama.
      _overrides.clear();
    });
  }

  /// Fase 1: periksa. Server membaca & mencocokkan, tapi belum menulis apa pun.
  Future<void> _periksa() => _kirim(apply: false);

  /// Fase 2: terapkan. Berkas yang SAMA dikirim ulang, kali ini untuk disimpan.
  Future<void> _terapkan() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Terapkan rekap ini?'),
            content: Text(
                'Angka realisasi ${_result?.rmMatched ?? 0} RM untuk tahun $_year '
                'akan diperbarui dan langsung tampil di dashboard mereka.\n\n'
                '${_overrides.isEmpty ? '' : '${_overrides.length} pencocokan yang Anda ubah ikut diterapkan.\n\n'}'
                'Realisasi dari pipeline WON tidak dihapus.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Terapkan')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await _kirim(apply: true);
  }

  Future<void> _kirim({required bool apply}) async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _repo.upload(
        bytes: bytes,
        filename: _fileName ?? 'realisasi.xlsx',
        year: _year,
        apply: apply,
        overrides: _overrides.values.toList(),
      );
      setState(() => _result = result);
      if (apply) {
        // Sudah tertulis; suntingannya habis masa berlaku. Menyimpannya membuat
        // unggahan berikutnya diam-diam membawa keputusan dari berkas lama.
        _overrides.clear();
        await _loadPending();
      }
      messenger.showSnackBar(SnackBar(
        content: Text(apply
            ? 'Diterapkan: ${result.cellsSaved} angka tersimpan untuk '
                '${result.rmMatched} RM'
                '${result.pendingRows > 0 ? ', ${result.pendingRows} baris perlu dipetakan' : ''}'
            : 'Berkas terbaca. Periksa rinciannya di bawah, lalu tekan Terapkan.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            apply ? AppColors.successGreen : AppColors.primaryNavy,
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

  /// Alihkan satu baris pratinjau ke akun lain — berlaku untuk baris yang sudah
  /// cocok maupun yang belum. Belum menulis apa pun: baru tersimpan saat Terapkan.
  Future<void> _alihkan({
    required String sourceKey,
    required String judul,
    required String asal,
  }) async {
    final account = await showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RmPicker(judul: judul, asal: asal),
    );
    if (account == null || !mounted) return;
    setState(() {
      _overrides[sourceKey] = RealisasiMatchOverride(
        sourceKey: sourceKey,
        userId: account.id,
        targetName: '${account.name} (${account.nip})',
      );
    });
  }

  /// Lewati baris: tidak ditulis ke siapa pun, tidak masuk antrean.
  void _lewati(String sourceKey, String judul) {
    setState(() {
      _overrides[sourceKey] =
          RealisasiMatchOverride(sourceKey: sourceKey, userId: null, targetName: judul);
    });
  }

  void _batalkanSuntingan(String sourceKey) {
    setState(() => _overrides.remove(sourceKey));
  }

  /// Menu aksi satu baris pratinjau.
  void _menuBaris({
    required String sourceKey,
    required String judul,
    required String asal,
  }) {
    final disunting = _overrides.containsKey(sourceKey);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(judul,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppColors.primaryNavy),
              title: const Text('Alihkan ke akun lain'),
              subtitle: const Text('Pilih sendiri akun RM tujuan baris ini'),
              onTap: () {
                Navigator.pop(ctx);
                _alihkan(sourceKey: sourceKey, judul: judul, asal: asal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.secondaryOrange),
              title: const Text('Lewati baris ini'),
              subtitle: const Text('Tidak ditulis ke siapa pun, tidak diantrekan'),
              onTap: () {
                Navigator.pop(ctx);
                _lewati(sourceKey, judul);
              },
            ),
            if (disunting)
              ListTile(
                leading: const Icon(Icons.undo, color: AppColors.textSecondary),
                title: const Text('Batalkan penyuntingan'),
                subtitle: const Text('Kembali ke hasil pencocokan otomatis'),
                onTap: () {
                  Navigator.pop(ctx);
                  _batalkanSuntingan(sourceKey);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _assign(RealisasiPendingRow row) async {
    final account = await showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RmPicker(
        judul: 'Petakan "${row.nama ?? row.nip ?? '-'}"',
        asal: row.asal,
      ),
    );
    if (account == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final saved = await _repo.assign(row.id, account.id);
      await _loadPending();
      messenger.showSnackBar(SnackBar(
        content: Text('$saved angka diterapkan ke ${account.name}. '
            'Pemetaan disimpan, unggahan berikutnya cocok sendiri.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.successGreen,
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

  Future<void> _dismiss(RealisasiPendingRow row) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Abaikan baris ini?'),
            content: Text(
                'Angka untuk "${row.nama ?? row.nip ?? '-'}" tidak akan dipakai. '
                'Baris ini akan muncul lagi kalau berkas yang sama diunggah ulang.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abaikan',
                      style: TextStyle(color: AppColors.errorRed))),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    try {
      await _repo.dismiss(row.id);
      await _loadPending();
    } catch (_) {
      // gagal menghapus antrean: baris tetap tampil, tidak ada data yang rusak
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Impor Target & Realisasi'),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _infoCard(),
            const SizedBox(height: AppSpacing.lg),
            _uploadCard(),
            _templateLamaLink(),
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _resultCard(_result!),
            ],
            const SizedBox(height: AppSpacing.lg),
            _pendingSection(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.navyBg,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unggah berkas rekap dari pusat apa adanya',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 6),
            Text(
              'Tidak perlu dirapikan atau disalin ke template. Kolom Target dan '
              'Realisasi bulan Januari–Desember dibaca sekaligus dari berkas yang '
              'sama, jadi cukup satu unggahan untuk keduanya. Kolom %, YTD, dan '
              'Full Year dilewati.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
            SizedBox(height: 10),
            Text('Angka dibaca dalam satuan JUTA rupiah',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            SizedBox(height: 4),
            Text(
              'Sesuai berkas pusat: 230,71 berarti Rp230.710.000.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
            SizedBox(height: 10),
            Text('Realisasi dari pipeline WON tidak dihapus',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            SizedBox(height: 4),
            Text(
              'Unggahan ini mengganti angka yang tampil di dashboard untuk bulan '
              'yang diunggah saja. Ekspor data tetap memakai angka dari pipeline WON, '
              'dan keduanya bisa dibandingkan dengan menekan kartu Realisasi YTD.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      );

  /// Jalur lama: template target terpisah.
  ///
  /// Menu tersendirinya dihapus karena rekap pusat sudah memuat kolom Target,
  /// tapi kemampuannya TIDAK dibuang — sebagian target disusun manual di luar
  /// rekap pusat, dan menghapus jalurnya berarti pekerjaan itu tak punya pintu
  /// sama sekali. Ditaruh di sini sebagai jalur sekunder, bukan menu setara.
  Widget _templateLamaLink() => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.push('/kelola/import-target'),
          icon: const Icon(Icons.description_outlined,
              size: 16, color: AppColors.primaryNavy),
          label: const Text(
            'Punya berkas template target lama? Impor lewat sini',
            style: TextStyle(fontSize: 12, color: AppColors.primaryNavy),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );

  Widget _uploadCard() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tahun rekap',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'Berkas pusat tidak memuat tahun — kolomnya hanya Jan sampai Des.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _years
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _year = v);
                      _loadPending();
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_fileName ?? 'Pilih berkas rekap (.xlsx)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Dua fase. Tombol Terapkan baru hidup setelah berkasnya diperiksa,
            // dan mati lagi begitu diterapkan — supaya tidak ada jalan pintas
            // dari "pilih berkas" langsung ke "tertulis".
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy || _bytes == null ? null : _periksa,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fact_check_outlined),
                label: Text(_busy ? 'Memproses…' : '1. Periksa berkas'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _terapkanIfReady,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('2. Terapkan'),
              ),
            ),
            if (_result != null && !_result!.applied)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Belum ada yang tersimpan. Periksa rincian di bawah sebelum menerapkan.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.secondaryOrange),
                ),
              ),
          ],
        ),
      );

  /// Sudah diperiksa, belum diterapkan, dan ada yang bisa ditulis.
  bool get _siapDiterapkan =>
      _result != null && !_result!.applied && _result!.rmMatched > 0;

  VoidCallback? get _terapkanIfReady =>
      _busy || !_siapDiterapkan ? null : _terapkan;

  Widget _resultCard(RealisasiImportResult r) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.applied
                        ? 'Sudah diterapkan — ${r.year}'
                        : 'Hasil pemeriksaan — ${r.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (r.applied
                            ? AppColors.successGreen
                            : AppColors.secondaryOrange)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r.applied ? 'Tersimpan' : 'Belum disimpan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: r.applied
                          ? AppColors.successGreen
                          : AppColors.secondaryOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _stat('Baris terbaca', '${r.rowsRead}'),
            _stat('Cocok ke akun RM', '${r.rmMatched}'),
            if (r.matchedByAlias > 0)
              _stat('  di antaranya lewat pemetaan tersimpan', '${r.matchedByAlias}'),
            _stat(r.applied ? 'Realisasi tersimpan' : 'Realisasi yang akan tersimpan',
                '${r.cellsSaved}'),
            // Dilaporkan terpisah: kalau berkasnya ternyata tidak memuat kolom
            // Target, angka nol di sini yang memberitahu — bukan target lama yang
            // diam-diam dibiarkan sementara admin mengira sudah memperbaruinya.
            _stat(r.applied ? 'Target tersimpan' : 'Target yang akan tersimpan',
                '${r.targetCellsSaved}',
                warn: r.targetCellsSaved == 0),
            _stat(
                r.applied ? 'Perlu dipetakan' : 'Akan masuk antrean pemetaan',
                '${r.pendingRows}',
                warn: r.pendingRows > 0),
            if (r.rowsSkipped > 0)
              _stat('Dilewati atas permintaan Anda', '${r.rowsSkipped}',
                  warn: true),
            if (_overrides.isNotEmpty && !r.applied)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_overrides.length} pencocokan Anda ubah. Angka di atas belum '
                  'memperhitungkannya — tekan Periksa lagi untuk melihat hasilnya, '
                  'atau langsung Terapkan.',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.primaryNavy),
                ),
              ),
            if (r.perRm.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Rincian per RM',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 2),
              const Text(
                'Periksa kewajaran totalnya — angka yang meleset sejuta kali lipat '
                'karena salah satuan paling cepat terlihat di sini. Ketuk satu baris '
                'untuk mengalihkannya ke akun lain atau melewatinya.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              ...r.perRm.map(_rmPreviewTile),
              if (r.perRm.length < r.rmMatched)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Menampilkan ${r.perRm.length} nominal terbesar dari '
                    '${r.rmMatched} RM. Sisanya tetap ikut diterapkan, tapi '
                    'pencocokannya tidak bisa diubah dari sini.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.secondaryOrange),
                  ),
                ),
            ],
            if (!r.applied && r.pendingPreview.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Belum ketemu akun RM-nya',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 2),
              const Text(
                'Ketuk untuk memetakannya sekarang. Yang tidak dipetakan tidak akan '
                'hilang: setelah diterapkan ia masuk antrean di bawah, lengkap '
                'dengan angkanya.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              ...r.pendingPreview.map(_pendingPreviewTile),
              if (r.pendingPreview.length < r.pendingRows)
                Text(
                  'Menampilkan ${r.pendingPreview.length} dari ${r.pendingRows} baris. '
                  'Semuanya akan masuk antrean saat diterapkan.',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
            if (r.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Catatan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              const SizedBox(height: 4),
              ...r.warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $w',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  )),
            ],
          ],
        ),
      );

  /// Satu RM di pratinjau: dari baris berkas mana ke akun mana, berapa sel, dan
  /// totalnya dalam rupiah. Totalnya ditampilkan penuh (bukan disingkat) justru
  /// supaya jumlah digitnya terbaca — itulah yang membongkar salah satuan.
  ///
  /// Bisa disunting: pencocokan otomatis lewat NIP bisa benar secara teknis tapi
  /// salah orangnya, dan setelah Terapkan angkanya sudah telanjur ada di dashboard
  /// orang lain. Yang tampil di sini adalah suntingan admin bila ada, kalau tidak
  /// hasil pencocokan server.
  Widget _rmPreviewTile(RealisasiImportRm rm) {
    final ov = _overrides[rm.sourceKey];
    final dilewati = ov != null && ov.skip;
    final tujuan = ov == null
        ? (rm.userName ?? '-')
        : (dilewati ? 'DILEWATI' : (ov.targetName ?? '-'));
    final judul = rm.sourceName ?? rm.sourceNip ?? '(tanpa nama)';

    return InkWell(
      onTap: rm.sourceKey.isEmpty
          ? null
          : () => _menuBaris(
                sourceKey: rm.sourceKey,
                judul: judul,
                asal: 'NIP berkas ${rm.sourceNip ?? '-'}',
              ),
      borderRadius: AppRadius.radiusLg,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ov == null ? AppColors.bgScreen : AppColors.navyBg,
          borderRadius: AppRadius.radiusLg,
          border: ov == null
              ? null
              : Border.all(
                  color: dilewati
                      ? AppColors.secondaryOrange
                      : AppColors.primaryNavy),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$judul → $tujuan',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: dilewati
                          ? AppColors.secondaryOrange
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (ov != null)
                  _tag(dilewati ? 'dilewati' : 'diubah',
                      dilewati ? AppColors.secondaryOrange : AppColors.primaryNavy)
                else if (rm.viaAlias)
                  _tag('via pemetaan', AppColors.primaryNavy),
                const SizedBox(width: 4),
                const Icon(Icons.more_horiz,
                    size: 16, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'NIP berkas ${rm.sourceNip ?? '-'} → akun ${ov == null ? (rm.userNip ?? '-') : (dilewati ? '-' : 'pilihan Anda')}'
              '  •  ${rm.cellCount} angka',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            Text(
              'Non Program Non Askred: ${AppFormat.rupiah(rm.totalRealisasiYtd)}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                decoration: dilewati ? TextDecoration.lineThrough : null,
                color: dilewati ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
      );

  /// Baris pratinjau yang belum ketemu akunnya — bisa langsung dipetakan di sini,
  /// tanpa menunggu Terapkan lalu mengurusnya lagi dari antrean.
  Widget _pendingPreviewTile(RealisasiImportPendingPreview p) {
    final ov = _overrides[p.sourceKey];
    final dilewati = ov != null && ov.skip;
    final judul = p.nama ?? p.nip ?? '(tanpa nama)';

    return InkWell(
      onTap: p.sourceKey.isEmpty
          ? null
          : () => _menuBaris(sourceKey: p.sourceKey, judul: judul, asal: p.asal),
      borderRadius: AppRadius.radiusLg,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ov == null ? AppColors.bgScreen : AppColors.navyBg,
          borderRadius: AppRadius.radiusLg,
          border: ov == null
              ? null
              : Border.all(
                  color: dilewati
                      ? AppColors.secondaryOrange
                      : AppColors.primaryNavy),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ov == null
                        ? judul
                        : '$judul → ${dilewati ? 'DILEWATI' : (ov.targetName ?? '-')}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${p.nip == null || p.nip!.isEmpty ? 'NIP tidak terbaca' : 'NIP ${p.nip}'}'
                    '${p.asal.isEmpty ? '' : ' • ${p.asal}'}'
                    '  •  ${p.cellCount} angka',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (ov != null)
              _tag(dilewati ? 'dilewati' : 'dipetakan',
                  dilewati ? AppColors.secondaryOrange : AppColors.primaryNavy),
            const SizedBox(width: 4),
            const Icon(Icons.more_horiz, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool warn = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary))),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: warn ? AppColors.secondaryOrange : AppColors.textPrimary)),
          ],
        ),
      );

  Widget _pendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Belum cocok ke akun RM',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: _loadingPending ? null : _loadPending,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        const Text(
          'Angkanya sudah tersimpan di sini dan tinggal dipetakan — berkasnya '
          'tidak perlu diunggah ulang. Sekali dipetakan, unggahan bulan '
          'berikutnya cocok sendiri.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loadingPending)
          const Center(child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ))
        else if (_pending.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: AppRadius.radiusLg,
            ),
            child: const Text('Semua baris berkas sudah cocok ke akun RM.',
                style: TextStyle(fontSize: 13)),
          )
        else
          ..._pendingList(),
      ],
    );
  }

  /// Antrean yang cocok dengan kotak cari. Menyaring di sisi klien: seluruh
  /// antrean sudah ada di memori, jadi menanyakannya ulang ke server tiap
  /// ketikan hanya menambah beban tanpa menambah informasi.
  List<RealisasiPendingRow> get _pendingTerfilter {
    final q = _pendingQuery.trim().toLowerCase();
    if (q.isEmpty) return _pending;
    return _pending.where((r) {
      final bahan = [r.nip, r.nama, r.kanwil, r.kc]
          .whereType<String>()
          .join(' ')
          .toLowerCase();
      return bahan.contains(q);
    }).toList();
  }

  List<Widget> _pendingList() {
    final cocok = _pendingTerfilter;
    final tampil = cocok.take(_pendingRenderLimit).toList();
    final sisa = cocok.length - tampil.length;
    return [
      if (_pending.length > _pendingRenderLimit) ...[
        TextField(
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Cari NIP, nama, kanwil, atau KC',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (v) => setState(() => _pendingQuery = v),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (cocok.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text('Tidak ada yang cocok dengan pencarian itu.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        )
      else ...[
        ...tampil.map(_pendingTile),
        if (sisa > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Menampilkan $_pendingRenderLimit dari ${cocok.length} baris. '
              'Pakai kotak cari di atas untuk menemukan orang tertentu — '
              'yang tidak ditampilkan tetap tersimpan dan tetap menunggu dipetakan.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ),
      ],
    ];
  }

  Widget _pendingTile(RealisasiPendingRow row) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          title: Text(row.nama ?? '(tanpa nama)',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.nip == null || row.nip!.isEmpty
                    ? 'NIP tidak terbaca di berkas'
                    : 'NIP berkas: ${row.nip}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (row.asal.isNotEmpty)
                Text(row.asal,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              Text('${row.valueCount} angka menunggu',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.secondaryOrange)),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _assign(row),
                child: const Text('Petakan'),
              ),
              IconButton(
                tooltip: 'Abaikan',
                onPressed: _busy ? null : () => _dismiss(row),
                icon: const Icon(Icons.close, size: 18, color: AppColors.grayStage),
              ),
            ],
          ),
        ),
      );
}

/// Pemilih akun RM untuk satu baris berkas — baris antrean maupun baris yang
/// sudah cocok tapi ingin dialihkan admin. Pencarian sisi klien atas daftar
/// akun — jumlah akun M-BIS ratusan, bukan ribuan.
///
/// Sengaja menerima [judul]/[asal] sebagai teks, bukan objek barisnya: pemilih
/// ini dipakai dua jenis baris yang tidak sebangun, dan menyeret salah satunya
/// ke sini hanya akan memaksa yang lain berpura-pura jadi baris antrean.
class _RmPicker extends ConsumerStatefulWidget {
  final String judul;
  final String asal;
  const _RmPicker({required this.judul, required this.asal});

  @override
  ConsumerState<_RmPicker> createState() => _RmPickerState();
}

class _RmPickerState extends ConsumerState<_RmPicker> {
  List<AccountModel> _all = const [];
  String _q = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(accountRepoProvider).getAccounts();
      if (mounted) {
        setState(() {
          _all = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AccountModel> get _filtered {
    if (_q.isEmpty) return _all;
    final q = _q.toLowerCase();
    return _all
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            (a.nip).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(widget.judul,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (widget.asal.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.asal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama atau NIP akun M-BIS',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: controller,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final a = _filtered[i];
                        return ListTile(
                          title: Text(a.name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text('NIP ${a.nip}',
                              style: const TextStyle(fontSize: 12)),
                          onTap: () => Navigator.pop(context, a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
