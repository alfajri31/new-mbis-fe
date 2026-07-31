import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/input_formatters.dart';
import '../../src/network/api_client.dart';
import '../../src/pipeline/pipeline_repository.dart';
import '../../src/reference/reference_repository.dart';
import '../providers/tender_status_provider.dart';
import '../widgets/missing_fields_notice.dart';
import '../widgets/dispose_callback.dart';

/// Cache label PROSES_TENDER dari master data (editable admin di Kelola Master Data).
/// Diisi lewat [loadTenderLabels]; bila kosong, [tenderLabel] memakai fallback bawaan.
final Map<String, String> _tenderLabelOverrides = {};

/// Muat label langkah tender dari parameter PROSES_TENDER ke cache. Aman dipanggil
/// berulang; gagal = diam-diam pakai fallback.
Future<void> loadTenderLabels(ApiClient apiClient) async {
  try {
    final items = await ReferenceRepository(apiClient: apiClient).parameters('PROSES_TENDER');
    for (final p in items) {
      if (p.key.isNotEmpty) _tenderLabelOverrides[p.key] = p.value;
    }
  } catch (_) {/* pakai fallback */}
}

/// Human label for a PROSES_TENDER enum key (override dari master data bila ada).
String tenderLabel(String? key) {
  if (key != null) {
    final override = _tenderLabelOverrides[key];
    if (override != null && override.isNotEmpty) return override;
  }
  switch (key) {
    case 'PENGUMPULAN_INFORMASI':
      return 'Pengumpulan Informasi';
    case 'PENDAFTARAN_TENDER':
      return 'Pendaftaran Tender';
    case 'PEMENUHAN_DOKUMEN':
      return 'Pemenuhan Dokumen Penawaran Harga';
    case 'SUBMIT_DOKUMEN':
      return 'Submit Dokumen Tender & Pembukaan';
    case 'KLARIFIKASI_NEGO':
      return 'Klarifikasi Teknis & Harga/Nego';
    case 'SCORING_PENGUMUMAN':
      return 'Scoring/Pengumuman Pemenang';
    case 'WON_TENDER':
      return 'Won (Penerbitan Polis & PKS)';
    case 'LOSS_TENDER':
      return 'Loss (Evaluasi)';
    default:
      return key ?? '-';
  }
}

/// Dedicated tender status screen: advance one process at a time, or mark Lost.
class TenderStatusScreen extends ConsumerStatefulWidget {
  final PipelineDetailModel pipeline;
  final ApiClient apiClient;
  const TenderStatusScreen({super.key, required this.pipeline, required this.apiClient});

  @override
  ConsumerState<TenderStatusScreen> createState() => _TenderStatusScreenState();
}

class _TenderStatusScreenState extends ConsumerState<TenderStatusScreen> {
  // Loading (`busy`) dikelola TenderStatusNotifier. Getter memproksinya agar
  // kode build/aksi di bawah tetap memakai nama lama tanpa diubah.
  TenderStatusNotifier get _notifier => ref.read(tenderStatusProvider.notifier);
  bool get _busy => ref.read(tenderStatusProvider).busy;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama: reset + muat label tender dari
    // master data (rebuild saat berhasil). Sesi dibaca notifier dari provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  List<PipelineTenderModel> get _steps {
    final s = [...widget.pipeline.tenderProcesses]..sort((a, b) => a.seq.compareTo(b.seq));
    return s;
  }

  int get _currentSeq => widget.pipeline.tenderCurrentSeq ?? 0;

  /// Langkah tender yang tanggalnya belum lengkap. Langkah wajib (Pendaftaran/
  /// Scoring/Won) ditambahkan otomatis backend TANPA tanggal bila user tidak
  /// mengisinya, jadi kondisi ini nyata dan harus terlihat — bukan tampil
  /// sebagai "- – -" yang membingungkan.
  static bool _isDateMissing(PipelineTenderModel s) =>
      (s.startDate == null || s.startDate!.isEmpty) ||
      (s.endDate == null || s.endDate!.isEmpty);

  String _dateRange(PipelineTenderModel s) {
    if (_isDateMissing(s)) return 'Tanggal belum diisi';
    final a = AppFormat.dateOnly(s.startDate);
    final b = AppFormat.dateOnly(s.endDate);
    return '$a – $b';
  }

  /// Whole days from today to the step's deadline. Negative = overdue, null when
  /// the step carries no end date (the mandatory steps are created without one).
  ///
  /// Compared date-to-date, not as a duration: endDate is a whole day, so "besok"
  /// must stay "besok" regardless of the current time of day.
  int? _daysToDeadline(PipelineTenderModel s) {
    final end = DateTime.tryParse(s.endDate ?? '');
    if (end == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(end.year, end.month, end.day).difference(today).inDays;
  }

  /// Deadline badge for the step in progress. Mirrors the reminder sweep's own
  /// thresholds (H-3 / H-1 / hari-H / terlambat) so the screen and the
  /// notification never tell the RM two different stories.
  Widget? _deadlineBadge(PipelineTenderModel s) {
    final days = _daysToDeadline(s);
    if (days == null) return null;

    final String label;
    final Color color;
    final Color bg;
    if (days < 0) {
      label = 'Terlambat ${-days} hari';
      color = AppColors.errorRed;
      bg = AppColors.redLight;
    } else if (days == 0) {
      label = 'Jatuh tempo hari ini';
      color = AppColors.errorRed;
      bg = AppColors.redLight;
    } else if (days <= 3) {
      label = days == 1 ? 'Besok' : '$days hari lagi';
      color = AppColors.secondaryOrange;
      bg = AppColors.orangeLight;
    } else {
      label = '$days hari lagi';
      color = AppColors.textSecondary;
      bg = AppColors.grayBg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Future<void> _advance() async {
    final steps = _steps;
    final nextIdx = _currentSeq + 1;
    if (nextIdx >= steps.length) {
      _snack('Sudah pada proses tender terakhir');
      return;
    }
    final nextType = steps[nextIdx].processType;
    final body = <String, dynamic>{};

    // Entering Scoring (step 6): pick role first (Leader/Member).
    if (nextType == 'SCORING_PENGUMUMAN' && widget.pipeline.tenderRole == null) {
      final role = await _pickRole();
      if (role == null) return;
      body['role'] = role;
    }
    // Entering Won (step 7): collect the WON sharing form.
    if (nextType == 'WON_TENDER') {
      // Won menutup tender. Kalau masih ada langkah yang tanggalnya kosong,
      // beri tahu DULU dengan menyebut langkahnya — backend menerima saja,
      // jadi tanpa ini riwayat tender tertutup dengan data bolong tanpa user
      // pernah tahu. Tidak diblokir: langkah wajib bisa saja memang ditambahkan
      // otomatis tanpa tanggal.
      final belum = steps.where(_isDateMissing).toList();
      if (belum.isNotEmpty) {
        final lanjut = await _confirmIncompleteSteps(belum);
        if (lanjut != true || !mounted) return;
      }
      final role = widget.pipeline.tenderRole ?? body['role'] ?? 'LEADER';
      final won = await _showWonSheet(role as String);
      if (won == null) return;
      body.addAll(won);
    }

    final err = await _notifier.advance(widget.pipeline.id, body);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      _snack(err);
    }
  }

  Future<void> _lost() async {
    final reason = await _showLostDialog();
    if (reason == null) return;
    final err = await _notifier.lost(widget.pipeline.id, reason);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      _snack(err);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _pickRole() {
    String? selected;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget option(String value, String label, String desc) {
            final isSel = selected == value;
            return InkWell(
              onTap: () => setLocal(() => selected = value),
              borderRadius: AppRadius.radiusMd,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.navyBg : AppColors.surfaceWhite,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                      color: isSel ? AppColors.primaryNavy : AppColors.border, width: isSel ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 20, color: isSel ? AppColors.primaryNavy : AppColors.grayStage),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
            // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
            scrollable: true,
            title: const Text('Peran di Tender'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pipeline berhasil maju ke Scoring / Pengumuman Pemenang. Pilih peran Anda dalam tender ini:',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                option('LEADER', 'Leader', 'Penanggung jawab utama tender'),
                option('MEMBER', 'Member', 'Anggota tim tender'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
              ElevatedButton(
                onPressed: selected == null ? null : () => Navigator.of(ctx).pop(selected),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy, disabledBackgroundColor: AppColors.border),
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _showLostDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => DisposeCallback(
        onDispose: ctrl.dispose,
        child: AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Tandai Tender Lost?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pipeline akan menjadi Decline (read-only). Beri alasan singkat.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: AppInput.fieldText,
              maxLines: 2,
              decoration: InputDecoration(
                  hintText: 'mis. kalah harga / tidak lolos scoring',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(ctrl.text.trim());
            },
            child: const Text('Tandai Lost', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      ),
    );
  }

  /// Konfirmasi sebelum menutup tender jadi Won padahal ada langkah yang
  /// tanggalnya belum diisi. Langkahnya DISEBUT satu per satu supaya user tahu
  /// persis apa yang kurang.
  Future<bool?> _confirmIncompleteSteps(List<PipelineTenderModel> belum) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Detail tender belum lengkap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tanggal pada proses berikut masih kosong:',
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            for (final s in belum)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• ${tenderLabel(s.processType)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryOrange)),
              ),
            const SizedBox(height: 10),
            const Text('Won akan menutup tender ini. Tetap lanjutkan?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lanjutkan',
                style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showWonSheet(String role) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TenderWonSheet(role: role, pipeline: widget.pipeline),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(tenderStatusProvider);
    final steps = _steps;
    final cur = _currentSeq;
    final current = (cur >= 0 && cur < steps.length) ? steps[cur] : null;
    final next = (cur + 1 < steps.length) ? steps[cur + 1] : null;
    final atLast = next == null;

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Ubah Status Pipeline',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Proses Aktif Saat Ini
          _sectionCard(
            title: 'Proses Aktif Saat Ini',
            child: current == null
                ? const Text('-', style: TextStyle(color: AppColors.textSecondary))
                : _processTile(current, active: true, icon: Icons.play_circle_outline),
          ),
          const SizedBox(height: 14),
          // Proses Selanjutnya
          if (next != null) ...[
            _sectionCard(
              title: 'Proses Selanjutnya',
              child: _processTile(next, active: false, icon: Icons.schedule),
            ),
            const SizedBox(height: 14),
          ],
          // Semua Proses
          _sectionCard(
            title: 'Semua Proses',
            child: Column(
              children: [
                for (int i = 0; i < steps.length; i++) _allProcessRow(steps[i], i, cur),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _lost,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.errorRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  ),
                  child: const Text('Lost',
                      style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_busy || atLast) ? null : _advance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(atLast ? 'Selesai' : 'Maju ke Proses',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _processTile(PipelineTenderModel s, {required bool active, required IconData icon}) {
    // Only the step in progress gets a countdown — a deadline you haven't reached
    // yet, or already passed, isn't something to act on.
    final badge = active ? _deadlineBadge(s) : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? AppColors.navyBg : AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: active ? AppColors.primaryNavy : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: active ? AppColors.primaryNavy : AppColors.grayStage),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenderLabel(s.processType),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(_dateRange(s),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isDateMissing(s) ? FontWeight.bold : FontWeight.normal,
                        color: _isDateMissing(s) ? AppColors.secondaryOrange : AppColors.textSecondary)),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            badge,
          ],
        ],
      ),
    );
  }

  Widget _allProcessRow(PipelineTenderModel s, int i, int cur) {
    final done = i < cur;
    final isActive = i == cur;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle
                : (isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            size: 22,
            color: done
                ? AppColors.successGreen
                : (isActive ? AppColors.primaryNavy : AppColors.grayStage),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. ${tenderLabel(s.processType)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: AppColors.textPrimary)),
                // Penanda langkah yang detailnya belum lengkap — supaya jelas
                // apa yang kurang sebelum menutup tender jadi Won.
                if (_isDateMissing(s))
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Tanggal belum diisi',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryOrange)),
                  ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: BorderRadius.circular(100)),
              child: const Text('aktif',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
            ),
        ],
      ),
    );
  }
}

/// One leader/member share input row.
class _ShareInput {
  String partyType; // LEADER | MEMBER
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController pctCtrl = TextEditingController();
  String? nameErr; // inline "Harus diisi"
  String? pctErr;
  _ShareInput(this.partyType);
}

/// WON form for a tender pipeline (leader/member sharing).
class _TenderWonSheet extends StatefulWidget {
  final String role; // LEADER | MEMBER
  final PipelineDetailModel pipeline;
  const _TenderWonSheet({required this.role, required this.pipeline});

  @override
  State<_TenderWonSheet> createState() => _TenderWonSheetState();
}

class _TenderWonSheetState extends State<_TenderWonSheet> {
  final _polisCtrl = TextEditingController();
  final _shareAskrindoCtrl = TextEditingController();
  final _tsiCtrl = TextEditingController();
  final _premiCtrl = TextEditingController();
  final List<_ShareInput> _members = [];
  _ShareInput? _leader; // only for MEMBER role

  // Inline validation messages shown under each field on Save.
  String? _polisErr;
  DateTime? _polisMulai;
  DateTime? _polisSelesai;
  String? _periodeErr;
  String? _shareAskrindoErr;
  String? _premiErr;
  String? _membersErr;

  /// Ringkasan isian wajib yang kurang — dirender DI DALAM sheet.
  /// Dulu ini snackbar; lihat [_sharesErr] untuk alasannya.
  List<String> _missing = const [];

  /// Total share sudah pernah diperiksa (user menekan Simpan). Sebelum itu
  /// jangan menyalakan pesan: form yang baru dibuka memang totalnya 0%.
  bool _totalChecked = false;

  bool get _isLeaderRole => widget.role == 'LEADER';

  /// TEMUAN-01 (SIT-34) — pesan "total share harus 100%" dulu dikirim lewat
  /// SnackBar. Sheet ini modal bottom sheet, sedangkan SnackBar dirender
  /// `ScaffoldMessenger` milik halaman DI BELAKANG sheet: pesannya tertutup
  /// selama sheet terbuka dan baru muncul setelah sheet ditutup — user melihat
  /// penolakan tanpa alasan, lalu alasannya datang justru saat datanya sudah
  /// benar.
  ///
  /// Sekarang pesannya diturunkan dari [_totalPct] saat build, bukan disimpan
  /// sebagai state: begitu angkanya dibetulkan sampai 100% pesan hilang sendiri
  /// (setiap field share memanggil setState di `onChanged`), tanpa perlu
  /// menekan Simpan lagi.
  String? get _sharesErr {
    if (!_totalChecked) return null;
    final selisih = _totalPct - 100;
    if (selisih.abs() <= 0.001) return null;
    final arah = selisih < 0 ? 'kurang' : 'lebih';
    return 'Total share harus 100% (sekarang ${_totalPct.toStringAsFixed(2)}%, '
        '$arah ${selisih.abs().toStringAsFixed(2)}%)';
  }

  @override
  void initState() {
    super.initState();
    if (widget.pipeline.tsiIdr > 0) {
      _tsiCtrl.text = AppFormat.thousands(widget.pipeline.tsiIdr.round());
    }
    if (_isLeaderRole) {
      _members.add(_ShareInput('MEMBER')); // leader role: minimal 1 member
    } else {
      _leader = _ShareInput('LEADER'); // member role: exactly 1 leader
    }
  }

  @override
  void dispose() {
    _polisCtrl.dispose();
    _shareAskrindoCtrl.dispose();
    _tsiCtrl.dispose();
    _premiCtrl.dispose();
    _leader?.nameCtrl.dispose();
    _leader?.pctCtrl.dispose();
    for (final m in _members) {
      m.nameCtrl.dispose();
      m.pctCtrl.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
  double _money(TextEditingController c) {
    final d = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return d.isEmpty ? 0 : double.parse(d);
  }

  double get _totalPct {
    double t = _num(_shareAskrindoCtrl);
    if (_leader != null) t += _num(_leader!.pctCtrl);
    for (final m in _members) {
      t += _num(m.pctCtrl);
    }
    return t;
  }

  Future<void> _save() async {
    // Semua penolakan di sheet ini WAJIB inline — jangan pakai SnackBar /
    // ScaffoldMessenger di sini, pesannya tertutup sheet (TEMUAN-01).

    // Reset, then validate semua field sekaligus supaya hint "Harus diisi"
    // muncul di bawah setiap field yang kosong (bukan satu-satu via snackbar).
    _polisErr = _shareAskrindoErr = _premiErr = _membersErr = _periodeErr = null;
    _missing = const [];
    if (_leader != null) {
      _leader!.nameErr = null;
      _leader!.pctErr = null;
    }
    for (final m in _members) {
      m.nameErr = null;
      m.pctErr = null;
    }

    // Kumpulkan NAMA field yang kurang, bukan cuma menandainya merah — pop-up
    // bawah lalu menyebutkannya, sama seperti form Tambah Pipeline. Sebelumnya
    // pesannya cuma "Lengkapi field yang ditandai", padahal tanda itu bisa ada
    // di bagian sheet yang sedang tergulung.
    final missing = <String>[];
    if (_polisCtrl.text.trim().isEmpty) {
      _polisErr = 'Harus diisi';
      missing.add('No. Polis');
    }
    if (_shareAskrindoCtrl.text.trim().isEmpty) {
      _shareAskrindoErr = 'Harus diisi';
      missing.add('Share Askrindo (%)');
    }
    if (_money(_premiCtrl) <= 0) {
      _premiErr = 'Harus diisi';
      missing.add('Premi');
    }
    if (_leader != null) {
      if (_leader!.nameCtrl.text.trim().isEmpty) {
        _leader!.nameErr = 'Harus diisi';
        missing.add('Nama Leader');
      }
      if (_num(_leader!.pctCtrl) <= 0) {
        _leader!.pctErr = 'Harus diisi';
        missing.add('Persentase Leader');
      }
    }
    for (int i = 0; i < _members.length; i++) {
      final m = _members[i];
      if (m.nameCtrl.text.trim().isEmpty) {
        m.nameErr = 'Harus diisi';
        missing.add('Nama Member ${i + 1}');
      }
      if (_num(m.pctCtrl) <= 0) {
        m.pctErr = 'Harus diisi';
        missing.add('Persentase Member ${i + 1}');
      }
    }
    if (_polisMulai == null || _polisSelesai == null) {
      _periodeErr = 'Periode polis harus diisi';
      missing.add('Periode Polis');
    } else if (_polisSelesai!.isBefore(_polisMulai!)) {
      _periodeErr = 'Tanggal selesai tidak boleh sebelum tanggal mulai';
      missing.add('Periode Polis');
    }
    if (_isLeaderRole && _members.isEmpty) {
      _membersErr = 'Tambahkan minimal 1 member';
      missing.add('Member (minimal 1)');
    }

    if (missing.isNotEmpty) {
      setState(() => _missing = missing);
      return;
    }

    // Total share ≠ 100% → tolak, dan tandai supaya [_sharesErr] menyala di
    // dekat indikator "Total: xx%". Datanya tidak ikut dikirim.
    if ((_totalPct - 100).abs() > 0.001) {
      setState(() => _totalChecked = true);
      return;
    }

    // Konfirmasi kalau premi WON berbeda dari nilai premi awal (estimasi saat
    // pipeline dibuat). Mencegah salah ketik nominal saat penerbitan polis.
    final baseline = widget.pipeline.premi ?? widget.pipeline.potensiPremi;
    final enteredPremi = _money(_premiCtrl);
    if (baseline != null && baseline > 0 && enteredPremi.round() != baseline.round()) {
      final ok = await _confirmPremiChanged(baseline, enteredPremi);
      if (ok != true) return;
      if (!mounted) return;
    }

    final shares = <Map<String, dynamic>>[];
    if (_leader != null) {
      shares.add({'partyType': 'LEADER', 'name': _leader!.nameCtrl.text.trim(), 'percentage': _num(_leader!.pctCtrl)});
    }
    for (final m in _members) {
      shares.add({'partyType': 'MEMBER', 'name': m.nameCtrl.text.trim(), 'percentage': _num(m.pctCtrl)});
    }

    Navigator.of(context).pop(<String, dynamic>{
      'policyNumber': _polisCtrl.text.trim(),
      'policyStart': _isoDate(_polisMulai!),
      'policyEnd': _isoDate(_polisSelesai!),
      'shareAskrindo': _num(_shareAskrindoCtrl),
      'tsiIdr': _money(_tsiCtrl),
      'premi': enteredPremi,
      'shares': shares,
    });
  }

  /// Dialog konfirmasi saat premi WON beda dari nilai awal.
  Future<bool?> _confirmPremiChanged(double baseline, double entered) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Nilai premi berubah?'),
        content: Text(
          'Premi yang Anda masukkan (${AppFormat.rupiah(entered)}) berbeda dengan '
          'nilai awal (${AppFormat.rupiah(baseline)}).\n\n'
          'Apakah Anda yakin nilainya berubah?',
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, lanjutkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Won — ${_isLeaderRole ? 'Leader' : 'Member'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Total share (Askrindo + pihak lain) harus 100%.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              _field(_polisCtrl, 'No. Polis', errorText: _polisErr, onEdited: () => _polisErr = null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _tanggalPolis('Mulai Polis', _polisMulai,
                    (d) => setState(() { _polisMulai = d; _periodeErr = null; }))),
                const SizedBox(width: 8),
                Expanded(child: _tanggalPolis('Selesai Polis', _polisSelesai,
                    (d) => setState(() { _polisSelesai = d; _periodeErr = null; }))),
              ]),
              if (_periodeErr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_periodeErr!,
                      style: const TextStyle(fontSize: 12, color: AppColors.errorRed)),
                ),
              const SizedBox(height: 10),
              _field(_shareAskrindoCtrl, 'Share Askrindo (%)',
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  suffix: '%',
                  errorText: _shareAskrindoErr,
                  onEdited: () => _shareAskrindoErr = null),
              const SizedBox(height: 10),
              _field(_tsiCtrl, 'TSI', money: true, prefix: 'Rp '),
              const SizedBox(height: 10),
              _field(_premiCtrl, 'Premi',
                  money: true, prefix: 'Rp ', errorText: _premiErr, onEdited: () => _premiErr = null),
              const SizedBox(height: 16),
              // Leader (only for MEMBER role)
              if (_leader != null) ...[
                const Text('Leader', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                _shareRow(_leader!, removable: false),
                const SizedBox(height: 12),
              ],
              // Members
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('Total: ${_totalPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (_totalPct - 100).abs() < 0.001 ? AppColors.successGreen : AppColors.errorRed)),
                ],
              ),
              // Pesan total share, tepat di bawah indikator "Total: xx%" —
              // inline supaya terlihat selama sheet terbuka (TEMUAN-01).
              if (_sharesErr != null) ...[
                const SizedBox(height: 8),
                InlineErrorNotice(
                  child: Text(_sharesErr!,
                      style: const TextStyle(fontSize: 12, color: AppColors.errorRed)),
                ),
              ],
              const SizedBox(height: 8),
              for (int i = 0; i < _members.length; i++) _shareRow(_members[i], removable: true, index: i),
              if (_membersErr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(_membersErr!, style: const TextStyle(fontSize: 12, color: AppColors.errorRed)),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => setState(() => _members.add(_ShareInput('MEMBER'))),
                icon: const Icon(Icons.add, size: 16, color: AppColors.primaryNavy),
                label: const Text('Tambah Member',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primaryNavy)),
              ),
              const SizedBox(height: 16),
              // Ringkasan isian wajib yang kurang — inline tepat di atas tombol
              // Simpan. Versi snackbar-nya tertutup sheet, sama seperti pesan
              // total share (TEMUAN-01).
              if (_missing.isNotEmpty) ...[
                InlineErrorNotice(
                  child: missingFieldsContent(_missing, color: AppColors.errorRed),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg)),
                  child: const Text('Simpan Won', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard,
      bool money = false,
      String? prefix,
      String? suffix,
      String? errorText,
      VoidCallback? onEdited}) {
    return TextField(
      controller: c,
      keyboardType: money ? TextInputType.number : (keyboard ?? TextInputType.text),
      inputFormatters: money ? [ThousandsInputFormatter()] : null,
      onChanged: (_) => setState(() {
        onEdited?.call();
        _missing = const []; // ringkasan ikut hilang begitu user membetulkan
      }),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixText: prefix,
        suffixText: suffix,
        isDense: true,
        errorText: errorText,
        border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
      ),
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Isian tanggal periode polis. Nomor dan masa berlaku polis sama-sama berasal
  /// dari sistem penerbitan di luar aplikasi, jadi keduanya diminta sekaligus.
  Widget _tanggalPolis(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      borderRadius: AppRadius.radiusMd,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          isDense: true,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
        ),
        child: Text(value == null ? 'Pilih tanggal' : _isoDate(value),
            style: TextStyle(
                fontSize: 14,
                color: value == null ? AppColors.grayStage : AppColors.textPrimary)),
      ),
    );
  }

  Widget _shareRow(_ShareInput s, {required bool removable, int index = 0}) {
    // Kedua field di baris ini tak bisa dibedakan lewat teksnya: hint '%' sama
    // dengan suffix field Share Askrindo. Key-nya dipakai test (dan otomasi
    // bukti UAT) untuk menunjuk field yang tepat.
    final slot = '${s.partyType.toLowerCase()}-$index';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: ValueKey('share-name-$slot'),
              controller: s.nameCtrl,
              onChanged: (_) => setState(() {
                s.nameErr = null;
                _missing = const [];
              }),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                  hintText: 'Nama',
                  isDense: true,
                  errorText: s.nameErr,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              key: ValueKey('share-pct-$slot'),
              controller: s.pctCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {
                s.pctErr = null;
                _missing = const [];
              }),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                  hintText: '%',
                  suffixText: '%',
                  isDense: true,
                  errorText: s.pctErr,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
            ),
          ),
          if (removable)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 8),
              child: InkWell(
                onTap: () => setState(() {
                  _members[index].nameCtrl.dispose();
                  _members[index].pctCtrl.dispose();
                  _members.removeAt(index);
                }),
                child: const Icon(Icons.delete_outline, size: 20, color: AppColors.errorRed),
              ),
            ),
        ],
      ),
    );
  }
}
