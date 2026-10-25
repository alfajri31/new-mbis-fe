import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/app.dart';
import '../../theme/app_theme.dart';
import '../widgets/max_width_body.dart';

/// Status persetujuan QS oleh Underwriting (UW)
enum QsApprovalStatus {
  pending,
  approved,
  approvedChange,
  rejected,
}

/// Model data item persetujuan QS
class QsApprovalItem {
  final String id;
  QsApprovalStatus status;
  String at;
  String no;
  final String sub;
  final List<String> devs;
  final String note;
  final String docs;
  List<String>? changes;
  String uwNote;

  QsApprovalItem({
    required this.id,
    required this.status,
    required this.at,
    required this.no,
    required this.sub,
    required this.devs,
    required this.note,
    required this.docs,
    this.changes,
    this.uwNote = '',
  });
}

/// Layar Persetujuan QS oleh Underwriting (REQ-02, F-016 / F-017).
/// Sesuai prototype persetujuan-qs-uw.html.
class PersetujuanQsScreen extends ConsumerStatefulWidget {
  const PersetujuanQsScreen({super.key});

  @override
  ConsumerState<PersetujuanQsScreen> createState() =>
      _PersetujuanQsScreenState();
}

class _PersetujuanQsScreenState extends ConsumerState<PersetujuanQsScreen> {
  late List<QsApprovalItem> _items;
  late String _activeRole;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errorNotes = {};

  @override
  void initState() {
    super.initState();
    // Default initial data sesuai prototype persetujuan-qs-uw.html
    _items = [
      QsApprovalItem(
        id: 'q1',
        status: QsApprovalStatus.pending,
        at: '23 Okt 2026 · 10:42',
        no: 'XXX/QS-PA/ASK-001/X/2026',
        sub: 'PSAKDI · PT Semen Padang · Rp 54.030.000',
        devs: [
          'Rate A/B 0,10% di bawah standar 0,13%',
          'Klasifikasi Kelas 2 lebih rendah dari saran Kelas 3 (pekerjaan: Sopir)',
        ],
        note:
            'Nasabah existing 3 tahun tanpa klaim; kompetitor menawarkan 0,10%. Pekerjaan sopir hanya dalam kota.',
        docs: 'KTP ✓ (ktp-direktur.jpg)',
        uwNote: '',
      ),
      QsApprovalItem(
        id: 'q2',
        status: QsApprovalStatus.pending,
        at: '23 Okt 2026 · 09:15',
        no: 'XXX/QS-PAX/ASK-001/X/2026',
        sub: 'PA Xtra · PT Prima Kaplas · Rp 219.900',
        devs: [
          'Tarif flat Rp 1.200/hari di bawah saran sistem Rp 1.500/hari',
          'Deductible diubah menjadi "Rp 100.000 per klaim"',
        ],
        note:
            'Paket event 47 hari, peserta 1 orang. Deductible diminta nasabah untuk menekan premi.',
        docs: 'Tidak ada lampiran',
        uwNote: '',
      ),
      QsApprovalItem(
        id: 'q3',
        status: QsApprovalStatus.approvedChange,
        at: '22 Okt 2026 · 15:10',
        no: '003/QS-PA/ASK-001/X/2026',
        sub: 'PSAKDI · CV Mitra Andalas · Rp 1.050.000',
        devs: [
          'Rate A/B 0,08% di bawah standar 0,10%',
          'Diskon 15% melebihi batas 10%',
        ],
        note: 'Permintaan nasabah lama; mohon pertimbangan.',
        docs: 'KTP ✓ (ktp-pemilik.pdf)',
        changes: [
          'Rate A/B: 0,08% → 0,09%',
          'Diskon: 15% → 10%',
        ],
        uwNote:
            'Rate dinaikkan ke 0,09%, diskon mengikuti batas. QS dikembalikan ke RM.',
      ),
      QsApprovalItem(
        id: 'q4',
        status: QsApprovalStatus.approved,
        at: '22 Okt 2026 · 11:48',
        no: '002/QS-PAX/ASK-001/X/2026',
        sub: 'PA Xtra · PT Andalas Logistik · Rp 81.885.000',
        devs: [
          'Premi mutlak Rp 76.000.000 di bawah tarif standar Rp 81.885.000',
        ],
        note: 'Group 850 orang, volume besar. Selisih 7% dari standar.',
        docs: 'Tidak ada lampiran',
        uwNote: 'Disetujui',
      ),
      QsApprovalItem(
        id: 'q5',
        status: QsApprovalStatus.rejected,
        at: '21 Okt 2026 · 09:05',
        no: 'XXX/QS-PA/ASK-001/X/2026',
        sub: 'PSAKDI · PT Semen Padang · Rp 38.200.000',
        devs: [
          'Premi mutlak Rp 38.170.000 di bawah tarif standar Rp 54.020.000',
        ],
        note: 'Nasabah minta harga khusus.',
        docs: 'Tidak ada lampiran',
        uwNote:
            'Premi mutlak terlalu jauh dari standar. Ajukan ulang dengan diskon maksimal 10%.',
      ),
    ];

    for (final item in _items) {
      _controllers[item.id] = TextEditingController();
    }

    _activeRole = 'uw';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userRoles = MbisApp.of(context)?.session?.user.roles ?? const [];
    if (userRoles.contains('UW')) {
      _activeRole = 'uw';
    } else if (userRoles.contains('ADMIN')) {
      _activeRole = 'admin';
    } else if (userRoles.contains('RM')) {
      _activeRole = 'rm';
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: isError ? AppColors.redRequired : AppColors.primaryNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _decide(String id, String act) {
    final item = _items.where((x) => x.id == id).firstOrNull;
    if (item == null) return;

    final ctrl = _controllers[id];
    final note = ctrl?.text.trim() ?? '';

    if (act == 'reject' && note.isEmpty) {
      setState(() {
        _errorNotes[id] = 'Isi catatan UW untuk penolakan';
      });
      _showToast('Isi catatan UW untuk penolakan', isError: true);
      return;
    }

    setState(() {
      _errorNotes[id] = null;
      final seq = item.no.startsWith('XXX')
          ? item.no.replaceFirst('XXX', '004')
          : item.no;

      if (act == 'approve') {
        item.status = QsApprovalStatus.approved;
        item.no = seq;
        item.uwNote = note.isNotEmpty ? note : 'Disetujui';
        _showToast('QS disetujui UW · No. $seq. RM dapat menerbitkan QS.');
      } else if (act == 'reject') {
        item.status = QsApprovalStatus.rejected;
        item.uwNote = note;
        _showToast('QS ditolak UW.', isError: true);
      } else if (act == 'change') {
        item.status = QsApprovalStatus.approvedChange;
        item.no = seq;
        item.changes = ['(contoh) Rate A/B: 0,10% → 0,12%'];
        item.uwNote = note.isNotEmpty ? note : 'Disetujui dengan perubahan';
        _showToast(
            'Mode UW: ubah rate, premi, UP & batas, atau T/C lalu Simpan & Setujui.');
      }
      item.at = '23 Okt 2026 · 11:30';
    });
  }

  void _viewQs(QsApprovalItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Quotation Slip',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyMbis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No. ${item.no}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                item.sub,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Catatan Pengajuan: ${item.note}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Lampiran: ${item.docs}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showToast('Membuka PDF Quotation Slip (${item.no})...');
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Buka Dokumen PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navyMbis,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _items.where((x) => x.status == QsApprovalStatus.pending).length;
    final canDecide = _activeRole == 'uw';

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Persetujuan QS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$pendingCount menunggu keputusan',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Panel Simulasi / Selector Peran
            _buildRoleSelectorCard(),
            const SizedBox(height: 12),

            // Banner Kunci / Info Hak Akses jika bukan UW
            if (!canDecide) ...[
              _buildLockBanner(),
              const SizedBox(height: 14),
            ],

            // Daftar Kartu Persetujuan QS
            if (_items.isEmpty)
              _buildEmptyCard()
            else
              for (final item in _items) ...[
                _buildApprovalCard(item),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.orangeMbis.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peran yang membuka (untuk review desain)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.alertTitle,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildRoleChip('Underwriting (UW)', 'uw'),
              _buildRoleChip('Admin', 'admin'),
              _buildRoleChip('RM', 'rm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, String roleKey) {
    final isSelected = _activeRole == roleKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _activeRole = roleKey);
      },
      selectedColor: AppColors.navyMbis,
      backgroundColor: AppColors.surfaceWhite,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
        side: BorderSide(
          color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
          width: 1.5,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildLockBanner() {
    final text = _activeRole == 'admin'
        ? 'Admin dapat melihat, keputusan persetujuan hanya oleh UW.'
        : 'RM tidak memiliki akses persetujuan.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgDisabled,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text(
          'Belum ada QS yang diajukan ke UW.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildApprovalCard(QsApprovalItem item) {
    final canDecideThis =
        _activeRole == 'uw' && item.status == QsApprovalStatus.pending;
    final ctrl = _controllers[item.id];
    final errorText = _errorNotes[item.id];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status Pill + Waktu Pengajuan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusPill(item.status),
              Text(
                item.at,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // No. QS
          Text(
            'No. ${item.no}',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.navyMbis,
            ),
          ),
          const SizedBox(height: 2),

          // Subtitle info
          Text(
            item.sub,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Box Penyimpangan
          if (item.devs.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.alertBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.alertBorder.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Penyimpangan',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.alertTitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final d in item.devs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $d',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.alertText,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Catatan RM
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
              children: [
                const TextSpan(
                  text: 'Catatan RM: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: item.note),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Lampiran
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textLabel,
                height: 1.4,
              ),
              children: [
                const TextSpan(
                  text: 'Lampiran: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: item.docs),
              ],
            ),
          ),

          // Box Perubahan oleh UW (jika ada)
          if (item.changes != null && item.changes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perubahan oleh UW',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greenTotal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final c in item.changes!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $c',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Catatan UW (jika sudah diputuskan)
          if (item.status != QsApprovalStatus.pending && item.uwNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(
                    text: 'Catatan UW: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: item.uwNote),
                ],
              ),
            ),
          ],

          // Tombol Lihat QS
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _viewQs(item),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navyMbis,
              side: const BorderSide(color: AppColors.borderDefault, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Lihat QS',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),

          // Area Keputusan oleh UW
          if (canDecideThis) ...[
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Catatan UW (wajib bila menolak)',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.hintText),
                errorText: errorText,
                filled: true,
                fillColor: AppColors.surfaceWhite,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: errorText != null
                        ? AppColors.redRequired
                        : AppColors.borderDefault,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.orangeMbis,
                    width: 2,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => _decide(item.id, 'approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.greenTotal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Disetujui',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _decide(item.id, 'change'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.greenTotal,
                    side: const BorderSide(color: AppColors.greenTotal, width: 1.5),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Disetujui dengan Perubahan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _decide(item.id, 'reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.redRequired,
                    side: const BorderSide(color: AppColors.redRequired, width: 1.5),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ditolak',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(QsApprovalStatus status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case QsApprovalStatus.pending:
        bg = AppColors.alertBg;
        fg = AppColors.alertTitle;
        text = 'Menunggu keputusan';
        break;
      case QsApprovalStatus.approved:
        bg = AppColors.greenLight;
        fg = AppColors.greenTotal;
        text = 'Disetujui UW';
        break;
      case QsApprovalStatus.approvedChange:
        bg = AppColors.greenLight;
        fg = AppColors.greenTotal;
        text = 'Disetujui dengan Perubahan';
        break;
      case QsApprovalStatus.rejected:
        bg = AppColors.errorBannerBg;
        fg = AppColors.redRequired;
        text = 'Ditolak UW';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
