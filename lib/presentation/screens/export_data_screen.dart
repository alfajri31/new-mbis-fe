import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../providers/export_data_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';

/// Admin "Ekspor Data" console — unduh Excel report kinerja (customer / pipeline /
/// visit) untuk rentang tanggal pilihan. Entry point-nya di hub Kelola; endpoint
/// backend (/api/admin/export/*) tetap yang menggerbang aksesnya (ADMIN only).
class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  // Rentang tanggal = pilihan UI pengguna → tetap di widget (dengan setState).
  late DateTime _from;
  late DateTime _to;

  // Flag async "sedang mengunduh" dikelola ExportDataNotifier. Getter berikut
  // memproksinya agar kode build/widget di bawah tetap memakai nama lama.
  ExportDataNotifier get _notifier => ref.read(exportDataProvider.notifier);
  String? get _busyDataset => ref.read(exportDataProvider).busyDataset;

  static const _datasets = <_Dataset>[
    _Dataset(
      key: 'customers',
      label: 'Data Customer',
      desc: 'Profil customer: kategori, entitas, HVC, NIB/NPWP, alamat, '
          'lokasi peta, dan kontak PIC. Difilter berdasarkan tanggal dibuat.',
      icon: Icons.people_outline,
      bg: AppColors.navyBg,
    ),
    _Dataset(
      key: 'pipelines',
      label: 'Data Pipeline',
      desc: 'Pipeline per RM & kantor: sumber bisnis, COB/LOB/TOC, estimasi '
          'TSI & premi, rate, proyek, dan tender. Difilter berdasarkan tanggal dibuat.',
      icon: Icons.stacked_line_chart,
      bg: AppColors.greenLight,
    ),
    _Dataset(
      key: 'visits',
      label: 'Data Kunjungan (Visit)',
      desc: 'Aktivitas kunjungan: RM, pipeline, GPS, foto, deskripsi, dan '
          'rencana follow up. Difilter berdasarkan tanggal aktivitas.',
      icon: Icons.place_outlined,
      bg: AppColors.orangeLight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1); // awal bulan berjalan
    _to = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryNavy,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<void> _download(_Dataset d) async {
    final outcome = await _notifier.download(d.key, _from, _to);
    if (!mounted) return;
    if (outcome.ok) {
      _snack('${d.label} berhasil diekspor (${outcome.fileName})');
    } else if (outcome.error != null) {
      _snack(outcome.error!, error: true);
    } else {
      _snack('Unduhan tidak didukung di perangkat ini', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.errorRed : AppColors.successGreen,
    ));
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat busy berubah (ganti setState).
    ref.watch(exportDataProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Ekspor Data', showBack: true),
      body: MaxWidthBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          children: [
            const Text(
              'Unduh report kinerja sebagai file Excel untuk rentang tanggal terpilih',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildRangeCard(),
            const SizedBox(height: AppSpacing.lg),
            for (final d in _datasets) ...[
              _buildDatasetCard(d),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rentang Tanggal',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _dateField('Dari', _from, () => _pickDate(true))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _dateField('Sampai', _to, () => _pickDate(false))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: _busyDataset != null ? null : onTap,
      borderRadius: AppRadius.radiusLg,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusLg),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 18, color: AppColors.primaryNavy),
        ),
        child: Text(_fmt(value),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildDatasetCard(_Dataset d) {
    final busy = _busyDataset == d.key;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: d.bg,
              borderRadius: AppRadius.radius2Xl,
            ),
            alignment: Alignment.center,
            child: Icon(d.icon, size: 26, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(d.desc,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5)),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _busyDataset != null ? null : () => _download(d),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(busy ? 'Mengekspor...' : 'Unduh Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusLg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dataset {
  final String key;
  final String label;
  final String desc;
  final IconData icon;
  final Color bg;

  const _Dataset({
    required this.key,
    required this.label,
    required this.desc,
    required this.icon,
    required this.bg,
  });
}
